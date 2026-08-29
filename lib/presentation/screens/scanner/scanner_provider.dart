import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../domain/models/detection_result.dart';
import '../../../domain/repositories/i_auth_repository.dart';
import '../../../domain/repositories/i_classifier_repository.dart';
import '../../../domain/usecases/scanner/scan_crop_usecase.dart';
import '../../../domain/usecases/scanner/scan_batch_usecase.dart';
import '../../../core/utils/image_quality_analyzer.dart';
import '../../../core/utils/analytics_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/error/failures.dart';
import '../../../data/ml/crop_disease_classifier.dart';
import '../../../data/repositories/classifier_repository_impl.dart';
import '../../../core/di/service_locator.dart';
import '../../l10n/ui_message.dart';

enum ScanMode { camera, gallery }

class ImageQuality {
  final double focusScore;
  final double brightnessScore;
  final bool acceptable;

  const ImageQuality({
    this.focusScore = 1,
    this.brightnessScore = 1,
    this.acceptable = true,
  });
}

class ScannerProvider extends ChangeNotifier {
  final ScanCropUseCase _scanCropUseCase;
  final ScanBatchUseCase _scanBatchUseCase;
  final IAuthRepository _authRepository;
  final AnalyticsService _analytics;
  final IClassifierRepository _classifierRepository;

  ScannerProvider(
    this._scanCropUseCase,
    this._authRepository,
    this._analytics, [
    IClassifierRepository? classifierRepository,
    ScanBatchUseCase? scanBatchUseCase,
  ])  : _classifierRepository = classifierRepository ?? _safeGetClassifier(),
        _scanBatchUseCase = scanBatchUseCase ?? ScanBatchUseCase(_scanCropUseCase);

  static IClassifierRepository _safeGetClassifier() {
    try {
      if (sl.isRegistered<IClassifierRepository>()) {
        return sl<IClassifierRepository>();
      }
    } catch (_) {}
    return ClassifierRepositoryImpl(CropDiseaseClassifier());
  }

  CameraController? cameraController;
  List<CameraDescription> cameras = [];
  bool cameraInitialized = false;
  bool torchOn = false;
  bool isAnalysing = false;
  String? capturedImagePath;
  ScanMode mode = ScanMode.camera;
  ImageQuality quality = const ImageQuality();
  ScanPreviewQuality? previewQuality;
  UiMessage? errorMessageCode;
  UiMessage? get errorCode => errorMessageCode;
  String? errorMessage;
  List<String> batchImagePaths = [];
  bool batchMode = false;

  // Frame-analysis throttle state.
  bool _isStreamingFrames = false;
  DateTime? _lastFrameProcessedAt;

  // Guards against re-entrant initialisation. initCamera is now called from
  // the screen's lifecycle observer (app resume) and on return from the
  // analysing route, so it must not build a second controller and leak the
  // first one if a previous init is already in flight or complete.
  bool _initializing = false;

  Future<void> initCamera() async {
    if (_initializing || cameraInitialized) return;
    _initializing = true;
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final cam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      cameraController = CameraController(
        cam,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup:
            defaultTargetPlatform == TargetPlatform.iOS
                ? ImageFormatGroup.bgra8888
                : ImageFormatGroup.yuv420,
      );
      await cameraController!.initialize();
      cameraInitialized = true;
      notifyListeners();
      await _startFrameAnalysis();
    } catch (e, st) {
      AppLogger.e('ScannerProvider.initCamera failed: $e', e, st);
      errorMessageCode = UiMessage.cameraUnavailable;
      errorMessage = 'Camera unavailable. Please check permissions and try again.';
      notifyListeners();
    } finally {
      _initializing = false;
    }
  }

  Future<void> _startFrameAnalysis() async {
    if (cameraController == null || !cameraInitialized) return;
    if (_isStreamingFrames) return;

    try {
      _isStreamingFrames = true;
      await cameraController!.startImageStream((image) {
        // Timestamp gate — analyse at most once every 150 ms (~6 fps).
        // Using the CameraImage immediately (not caching it) avoids the
        // stale-buffer risk of storing a reference for later use.
        final now = DateTime.now();
        final last = _lastFrameProcessedAt;
        if (last != null && now.difference(last).inMilliseconds < 150) return;
        _lastFrameProcessedAt = now;
        previewQuality = ImageQualityAnalyzer.previewFromCameraImage(image);
        notifyListeners();
      });
    } catch (_) {
      _isStreamingFrames = false;
    }
  }

  Future<void> _stopFrameAnalysis() async {
    _isStreamingFrames = false;
    _lastFrameProcessedAt = null;

    final controller = cameraController;
    if (controller == null || !controller.value.isStreamingImages) return;

    try {
      await controller.stopImageStream();
    } catch (_) {
      // Driver already stopped the stream — continue.
    }
  }

  Future<void> toggleTorch() async {
    if (cameraController == null || !cameraInitialized) return;
    final next = !torchOn;
    try {
      // Devices without a flash unit throw here — keep torchOn in sync with
      // the real hardware state instead of optimistically flipping it.
      await cameraController!.setFlashMode(
        next ? FlashMode.torch : FlashMode.off,
      );
      torchOn = next;
    } catch (e, st) {
      AppLogger.w('ScannerProvider.toggleTorch failed: $e', e, st);
      errorMessageCode = UiMessage.torchUnavailable;
      errorMessage = 'Torch is not available on this device.';
    }
    notifyListeners();
  }

  Future<String?> captureImage() async {
    if (cameraController == null || !cameraInitialized) return null;

    final controller = cameraController!;
    await _stopFrameAnalysis();

    try {
      final file = await controller.takePicture();
      capturedImagePath = file.path;
      notifyListeners();
      return file.path;
    } catch (e, st) {
      AppLogger.e('ScannerProvider.captureImage failed: $e', e, st);
      errorMessageCode = UiMessage.captureFailed;
      errorMessage = 'Failed to capture image.';
      notifyListeners();
      return null;
    } finally {
      await _startFrameAnalysis();
    }
  }

  Future<String?> pickFromGallery() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (file == null) return null;

    capturedImagePath = file.path;
    notifyListeners();
    return file.path;
  }

  Future<String?> downloadFromUrl(String url) async {
    errorMessageCode = null;
    errorMessage = null;
    notifyListeners();
    try {
      final uri = Uri.parse(url);
      final response =
          await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        AppLogger.w('ScannerProvider.downloadFromUrl HTTP error ${response.statusCode}');
        errorMessageCode = UiMessage.downloadFailed(response.statusCode);
        errorMessage = 'Could not download image (HTTP ${response.statusCode}).';
        notifyListeners();
        return null;
      }
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.startsWith('image/')) {
        AppLogger.w('ScannerProvider.downloadFromUrl non-image contentType: $contentType');
        errorMessageCode = UiMessage.urlNotImage;
        errorMessage = 'URL does not point to an image.';
        notifyListeners();
        return null;
      }
      final dir = await getTemporaryDirectory();
      final ext = contentType.contains('png') ? 'png' : 'jpg';
      final file = File(
          '${dir.path}/url_scan_${DateTime.now().millisecondsSinceEpoch}.$ext');
      await file.writeAsBytes(response.bodyBytes);
      capturedImagePath = file.path;
      notifyListeners();
      return file.path;
    } catch (e, st) {
      AppLogger.e('ScannerProvider.downloadFromUrl failed: $e', e, st);
      errorMessageCode = UiMessage.urlLoadFailed;
      errorMessage = 'Failed to load image from URL.';
      notifyListeners();
      return null;
    }
  }

  Future<void> addToBatch() async {
    final path = await pickFromGallery();
    if (path != null) {
      addCapturedToBatch(path);
    }
  }

  void addCapturedToBatch(String path) {
    batchImagePaths.add(path);
    notifyListeners();
  }

  void setBatchMode(bool v) {
    batchMode = v;
    batchImagePaths.clear();
    notifyListeners();

    if (v) {
      unawaited(_startFrameAnalysis());
    }
  }

  Future<List<DetectionResult>> analyseBatch() async {
    if (batchImagePaths.isEmpty) return [];

    isAnalysing = true;
    errorMessageCode = null;
    errorMessage = null;
    notifyListeners();

    final userId = _authRepository.currentUser?.id ?? 'guest';
    final batchResult = await _scanBatchUseCase(List<String>.from(batchImagePaths), userId);
    final results = batchResult.data ?? <DetectionResult>[];
    final failures = batchImagePaths.length - results.length;

    isAnalysing = false;
    if (results.isEmpty) {
      errorMessageCode = failures > 0
          ? UiMessage.batchAllFailed
          : UiMessage.noImagesToAnalyse;
      errorMessage = failures > 0
          ? 'Batch analysis failed for all images.'
          : 'No images to analyse.';
    } else if (failures > 0) {
      errorMessageCode =
          UiMessage.batchPartial(results.length, batchImagePaths.length);
      errorMessage =
          'Analysed ${results.length} of ${batchImagePaths.length} images.';
    }
    batchImagePaths.clear();
    batchMode = false;
    notifyListeners();
    return results;
  }

  Future<void> releaseCamera() async {
    await _stopFrameAnalysis();
    final controllerToDispose = cameraController;
    cameraController = null;
    cameraInitialized = false;
    torchOn = false;
    notifyListeners();
    await controllerToDispose?.dispose();
  }

  /// Runs inference on [imagePath] and returns the [ClassificationResult]
  /// via the repository layer (enforcing OODGate and image quality checks)
  /// without saving to the database or logging analytics events.
  ///
  /// Used by the multi-angle retry flow in [LowConfidenceScreen] so the farmer
  /// can capture extra photos of the same leaf; results are averaged before any
  /// database write happens.
  Future<ClassificationResult?> classifyOnly(String imagePath) async {
    final result = await _classifierRepository.classifyFromPath(imagePath);
    if (result.isError || result.data == null) {
      return null;
    }
    final c = result.data!;
    return ClassificationResult(
      label: c.label,
      confidence: c.confidence,
      isHealthy: c.isHealthy,
      diseaseInfo: c.diseaseInfo,
      isDegraded: c.isDegraded,
      topCandidates: c.topCandidates,
      modelVersion: c.modelVersion,
    );
  }

  /// Persists a multi-angle merged diagnosis or user-confirmed candidate result
  /// without re-running inference or discarding prior angle data.
  Future<DetectionResult?> saveMergedScan({
    required String imagePath,
    required String diseaseLabel,
    required double confidence,
    required List<TopCandidate> topCandidates,
    bool isDegraded = false,
    String? modelVersion,
  }) async {
    isAnalysing = true;
    errorMessageCode = null;
    errorMessage = null;
    notifyListeners();

    try {
      final userId = _authRepository.currentUser?.id ?? 'guest';
      final result = await _scanCropUseCase.saveResolvedScan(
        imagePath: imagePath,
        userId: userId,
        diseaseLabel: diseaseLabel,
        confidence: confidence,
        topCandidates: topCandidates,
        isDegraded: isDegraded,
        modelVersion: modelVersion,
      );

      if (result.isError) {
        AppLogger.e('ScannerProvider.saveMergedScan error: ${result.failure?.message}');
        errorMessageCode = UiMessage.genericError;
        errorMessage = result.failure?.message ?? 'Failed to save scan';
        isAnalysing = false;
        notifyListeners();
        return null;
      }

      isAnalysing = false;
      notifyListeners();
      final detection = result.data;
      if (detection != null) {
        if (detection.confidence < CropDiseaseClassifier.confidenceThreshold) {
          unawaited(_analytics.logLowConfidence(
            confidence: detection.confidence,
            disease: detection.diseaseLabel,
            modelVersion: detection.modelVersion,
          ));
        }
        unawaited(_analytics.logScanCompleted(
          disease: detection.diseaseLabel,
          confidence: detection.confidence,
          isHealthy: detection.isHealthy,
          modelVersion: detection.modelVersion,
          topCandidates: detection.topCandidates,
        ));
      }
      return detection;
    } catch (e, st) {
      AppLogger.e('ScannerProvider.saveMergedScan exception: $e', e, st);
      errorMessageCode = UiMessage.genericError;
      errorMessage = 'Failed to save scan';
      isAnalysing = false;
      notifyListeners();
      return null;
    }
  }

  Future<DetectionResult?> analyseAndSave(String imagePath) async {
    isAnalysing = true;
    errorMessageCode = null;
    errorMessage = null;
    notifyListeners();
    unawaited(_analytics.logScanStarted(source: mode == ScanMode.gallery ? 'gallery' : 'camera'));

    try {
      final userId = _authRepository.currentUser?.id ?? 'guest';
      final result = await _scanCropUseCase(imagePath, userId);

      if (result.isError) {
        final failure = result.failure;
        if (failure is QualityFailure) {
          errorMessageCode = _getQualityUiMessage(failure.issue);
          errorMessage = _getQualityErrorMessage(failure.issue);
          unawaited(_analytics.logScanFailed(reason: 'quality_${failure.issue?.name ?? 'unknown'}'));
        } else {
          errorMessageCode = UiMessage.analysisFailed;
          errorMessage = failure?.message ?? 'Analysis failed';
          unawaited(_analytics.logScanFailed(reason: 'inference'));
        }
        isAnalysing = false;
        notifyListeners();
        return null;
      }

      isAnalysing = false;
      notifyListeners();
      final detection = result.data;
      if (detection != null) {
        if (detection.confidence < CropDiseaseClassifier.confidenceThreshold) {
          unawaited(_analytics.logLowConfidence(
            confidence: detection.confidence,
            disease: detection.diseaseLabel,
            modelVersion: detection.modelVersion,
          ));
        }
        unawaited(_analytics.logScanCompleted(
          disease: detection.diseaseLabel,
          confidence: detection.confidence,
          isHealthy: detection.isHealthy,
          modelVersion: detection.modelVersion,
          topCandidates: detection.topCandidates,
        ));
      }
      return detection;
    } catch (e, st) {
      AppLogger.e('ScannerProvider.analyseAndSave exception: $e', e, st);
      errorMessageCode = UiMessage.analysisFailed;
      errorMessage = 'Analysis failed';
      isAnalysing = false;
      notifyListeners();
      return null;
    }
  }

  UiMessage _getQualityUiMessage(ImageQualityIssue? issue) {
    switch (issue) {
      case ImageQualityIssue.blurry:
        return UiMessage.qualityBlurry;
      case ImageQualityIssue.tooDark:
        return UiMessage.qualityTooDark;
      case ImageQualityIssue.tooBright:
        return UiMessage.qualityTooBright;
      case ImageQualityIssue.tooSmall:
        return UiMessage.qualityTooSmall;
      default:
        return UiMessage.qualityPoor;
    }
  }

  String _getQualityErrorMessage(ImageQualityIssue? issue) {
    switch (issue) {
      case ImageQualityIssue.blurry:
        return 'Image is too blurry. Please hold the camera steady.';
      case ImageQualityIssue.tooDark:
        return 'Image is too dark. Please use more light or the torch.';
      case ImageQualityIssue.tooBright:
        return 'Image is too bright. Please avoid direct glare.';
      case ImageQualityIssue.tooSmall:
        return 'Image resolution is too low.';
      default:
        return 'Poor image quality detected.';
    }
  }

  @override
  void dispose() {
    // Stop the image stream before tearing down the controller so no frame
    // callback fires against a disposed controller.
    unawaited(_stopFrameAnalysis());
    cameraController?.dispose();
    super.dispose();
  }
}
