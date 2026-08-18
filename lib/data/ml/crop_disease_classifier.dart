import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../core/di/service_locator.dart';
import '../../core/utils/analytics_service.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/classifier_health_service.dart';
import '../../core/utils/image_quality_analyzer.dart';
import 'disease_info.dart';

/// A single entry in the top-N candidate list returned by inference.
typedef TopCandidate = ({String label, double confidence});

/// Classification result returned from the TFLite model.
class ClassificationResult {
  final String label;
  final double confidence;
  final bool isHealthy;
  final DiseaseInfoEntry diseaseInfo;
  final ImageQualityResult? qualityResult;
  final bool isDegraded;
  final bool engineUnavailable;
  final bool isOutOfDistribution;
  /// Top-3 predictions from the model in descending confidence order.
  /// Empty on degraded / fallback paths — we never fabricate candidates.
  final List<TopCandidate> topCandidates;

  const ClassificationResult({
    required this.label,
    required this.confidence,
    required this.isHealthy,
    required this.diseaseInfo,
    this.qualityResult,
    this.isDegraded = false,
    this.engineUnavailable = false,
    this.isOutOfDistribution = false,
    this.topCandidates = const [],
  });
}

// ── Isolate data transfer objects for Preprocessing ──────────────────────────
// Must be top-level so compute() can serialize them across isolate boundaries.

class _PreprocessingInput {
  final Uint8List? imageFileBytes;
  final Uint8List? rgbaBytes;
  final int width;
  final int height;

  const _PreprocessingInput({
    this.imageFileBytes,
    this.rgbaBytes,
    this.width = 0,
    this.height = 0,
  });
}

class _PreprocessingResult {
  final Float32List? inputTensor;
  final ImageQualityResult qualityResult;
  final double greenRatio;

  const _PreprocessingResult({
    this.inputTensor,
    required this.qualityResult,
    this.greenRatio = 0.0,
  });
}

/// Runs inside a `compute()` isolate — decodes, performs quality checks, and resizes.
_PreprocessingResult _preprocessImageIsolate(_PreprocessingInput input) {
  img.Image? raw;
  if (input.imageFileBytes != null) {
    raw = img.decodeImage(input.imageFileBytes!);
  } else if (input.rgbaBytes != null && input.width > 0 && input.height > 0) {
    raw = img.Image.fromBytes(
      width: input.width,
      height: input.height,
      bytes: input.rgbaBytes!.buffer,
      format: img.Format.uint8,
      numChannels: 4,
    );
  }
  if (raw == null) {
    return const _PreprocessingResult(
      inputTensor: null,
      qualityResult: ImageQualityResult(
        false,
        ImageQualityIssue.blurry,
      ),
    );
  }

  // Quality checks before model resizing/inference
  final qualityCheck = ImageQualityAnalyzer.analyze(raw);
  if (!qualityCheck.isAcceptable) {
    return _PreprocessingResult(
      inputTensor: null,
      qualityResult: qualityCheck,
    );
  }

  const inputSize = CropDiseaseClassifier.inputSize;
  final resized = img.copyResize(raw, width: inputSize, height: inputSize);

  int plantPixels = 0;
  int totalPixels = 0;
  final step = max(1, inputSize ~/ 50);
  for (var y = 0; y < inputSize; y += step) {
    for (var x = 0; x < inputSize; x += step) {
      final pixel = resized.getPixel(x, y);
      totalPixels++;
      final r = pixel.r;
      final g = pixel.g;
      final b = pixel.b;
      
      // 1. Green leaf tissue
      final isGreen = g > r && g > b && g > 25;
      // 2. Yellowing leaf / Chlorosis (high R & G, lower B)
      final isYellow = r >= 40 && g >= 40 && b < min(r, g) * 0.95;
      // 3. Brown necrosis / leaf spot / pod / tuber / wood
      final isBrown = r > 35 && g > 20 && b < r * 0.85 && (r - b) > 10;
      // 4. Red/orange rust / rot
      final isRust = r > 50 && r > g * 1.1 && r > b * 1.3;

      if (isGreen || isYellow || isBrown || isRust) {
        plantPixels++;
      }
    }
  }
  final greenRatio = totalPixels > 0 ? plantPixels / totalPixels : 0.0;

  // Build contiguous [1 * 224 * 224 * 3] float tensor normalised to [0, 1].
  final inputTensor = Float32List(1 * inputSize * inputSize * 3);
  var idx = 0;
  for (var y = 0; y < inputSize; y++) {
    for (var x = 0; x < inputSize; x++) {
      final pixel = resized.getPixel(x, y);
      inputTensor[idx++] = pixel.r / 255.0;
      inputTensor[idx++] = pixel.g / 255.0;
      inputTensor[idx++] = pixel.b / 255.0;
    }
  }

  return _PreprocessingResult(
    inputTensor: inputTensor,
    qualityResult: qualityCheck,
    greenRatio: greenRatio,
  );
}

/// Runs inference on one model and returns the top label + confidence
/// plus the top-3 candidates in descending order.
({
  String label,
  double confidence,
  List<TopCandidate> top3,
}) _runSingleModelOnMainThread(
  Interpreter interpreter,
  List<String> labels,
  Float32List inputTensor,
) {
  if (labels.isEmpty) {
    return (label: 'Unknown', confidence: 0.0, top3: const []);
  }

  final outputShape = interpreter.getOutputTensor(0).shape;
  final numClasses = outputShape.last;

  assert(
    numClasses == labels.length,
    'CropDiseaseClassifier: label count (${labels.length}) does not match '
    'model output classes ($numClasses). Restore the correct labels file.',
  );

  final outputBuffer = [List.filled(numClasses, 0.0)];
  final reshapedInput = inputTensor.reshape(
      [1, CropDiseaseClassifier.inputSize, CropDiseaseClassifier.inputSize, 3]);
  interpreter.run(reshapedInput, outputBuffer);

  final scores = outputBuffer[0];

  // Apply Softmax normalization if raw logits are returned.
  List<double> probabilities = scores;
  final maxLogit = scores.reduce((a, b) => a > b ? a : b);
  final isRawLogits = maxLogit > 1.0 || scores.any((s) => s < 0.0);
  if (isRawLogits) {
    var expSum = 0.0;
    final exps = List<double>.filled(scores.length, 0.0);
    for (var i = 0; i < scores.length; i++) {
      exps[i] = exp(scores[i] - maxLogit);
      expSum += exps[i];
    }
    probabilities = exps.map((e) => expSum > 0 ? e / expSum : 0.0).toList();
  }

  // Build index list sorted by probability descending.
  final indices = List<int>.generate(probabilities.length, (i) => i);
  indices.sort((a, b) => probabilities[b].compareTo(probabilities[a]));

  final topIndex = indices[0];
  final topScore = probabilities[topIndex];
  final topLabel = topIndex < labels.length ? labels[topIndex] : 'Unknown';

  // Top-3 candidates (skip 'Unknown' entries).
  final top3 = indices
      .take(3)
      .where((i) => i < labels.length && labels[i] != 'Unknown')
      .map<TopCandidate>((i) => (label: labels[i], confidence: probabilities[i]))
      .toList();

  return (label: topLabel, confidence: topScore, top3: top3);
}

// ── Classifier ────────────────────────────────────────────────────────────────

/// Wraps tflite_flutter.
///
/// Images are preprocessed off the main thread via [compute()] so decoding and
/// resizing do not cause UI jank. Model inference then runs on the main thread
/// using cached persistent interpreter instances, preventing memory leaks and
/// reload overhead.
class CropDiseaseClassifier {
  static const int inputSize = 224;
  static const double confidenceThreshold = 0.60;
  static String? modelVersion;

  List<String> _labels = [];
  List<String> _labelsV2 = [];
  Interpreter? _interpreterV1;
  Interpreter? _interpreterV2;
  bool _isLoaded = false;
  bool _engineAvailable = true;
  Future<void>? _loading;

  static List<String> _parseLabels(String raw) =>
      raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  /// Initialise both models and their label files. Concurrent calls share a
  /// single in-flight load so two simultaneous scans don't double-load.
  Future<void> loadModel() {
    if (_isLoaded || !_engineAvailable) return Future.value();
    return _loading ??= _loadModelImpl().whenComplete(() => _loading = null);
  }

  /// Creates an [Interpreter] for [modelBytes] using hardware acceleration if
  /// available, with a transparent CPU-only fallback.
  ///
  /// On iOS, `tflite_flutter` bundles the Metal and CoreML delegates and
  /// attempts to use them by default. On the Simulator (or devices where the
  /// Metal delegate cannot be initialised) this throws
  /// "Invalid argument(s): Unable to create interpreter". We catch that and
  /// retry with a plain CPU-only interpreter so the app keeps working.
  /// Creates an [Interpreter] for [modelBytes] using hardware acceleration if
  /// available, with transparent CPU options and zero-option fallbacks.
  Interpreter _createInterpreter(Uint8List modelBytes) {
    // Attempt 1: Hardware acceleration default (Metal/CoreML on iOS, NNAPI on Android)
    try {
      final opts = InterpreterOptions()..threads = 2;
      return Interpreter.fromBuffer(modelBytes, options: opts);
    } catch (e) {
      AppLogger.w(
        'CropDiseaseClassifier: hardware delegate options failed ($e); retrying with CPU options.',
      );
      try {
        unawaited(FirebaseCrashlytics.instance.recordError(
          e,
          null,
          reason: 'TFLite hardware delegate failed — falling back to CPU options',
          fatal: false,
        ));
      } catch (_) {}
    }

    // Attempt 2: Explicit CPU options (disable NNAPI)
    try {
      final cpuOpts = InterpreterOptions()..threads = 2;
      if (Platform.isAndroid) {
        cpuOpts.useNnApiForAndroid = false;
      }
      return Interpreter.fromBuffer(modelBytes, options: cpuOpts);
    } catch (e) {
      AppLogger.w(
        'CropDiseaseClassifier: CPU options failed ($e); retrying default Interpreter.fromBuffer.',
      );
      try {
        unawaited(FirebaseCrashlytics.instance.recordError(
          e,
          null,
          reason: 'TFLite CPU options failed — falling back to raw Interpreter.fromBuffer',
          fatal: false,
        ));
      } catch (_) {}
    }

    // Attempt 3: Minimal default Interpreter.fromBuffer with no options object
    return Interpreter.fromBuffer(modelBytes);
  }

  Future<void> _loadModelImpl() async {
    ByteData? v1Data;
    Uint8List? v1Bytes;

    // Stage 1: Load V1 asset files
    try {
      v1Data = await rootBundle.load('assets/cropguard_plant_disease.tflite');
      _labels = _parseLabels(await rootBundle.loadString('assets/labels.txt'));
      v1Bytes = Uint8List.fromList(
        v1Data.buffer.asUint8List(v1Data.offsetInBytes, v1Data.lengthInBytes),
      );
    } catch (e, stack) {
      _isLoaded = false;
      _engineAvailable = false;
      AppLogger.e('CropDiseaseClassifier: V1 asset load failed', e, stack);
      try {
        await FirebaseCrashlytics.instance.recordError(
          e, stack,
          reason: 'TFLite model load failure (Stage 1: asset load) — engine marked unavailable',
          fatal: false,
        );
      } catch (_) {}
      return;
    }

    // Stage 2: Create V1 interpreter
    try {
      _interpreterV1 = _createInterpreter(v1Bytes);
    } catch (e, stack) {
      _isLoaded = false;
      _engineAvailable = false;
      AppLogger.e('CropDiseaseClassifier: V1 interpreter creation failed', e, stack);
      try {
        await FirebaseCrashlytics.instance.recordError(
          e, stack,
          reason: 'TFLite model load failure (Stage 2: interpreter creation) — engine marked unavailable',
          fatal: false,
        );
      } catch (_) {}
      return;
    }

    // Stage 3: Allocate V1 tensors & align labels
    try {
      _interpreterV1!.allocateTensors();
      final numClassesV1 = _interpreterV1!.getOutputTensor(0).shape.last;
      if (_labels.length != numClassesV1) {
        AppLogger.w(
          'CropDiseaseClassifier: V1 label count (${_labels.length}) does not match model output classes ($numClassesV1). Truncating/adjusting.',
        );
        if (_labels.length > numClassesV1) {
          _labels = _labels.sublist(0, numClassesV1);
        } else {
          while (_labels.length < numClassesV1) {
            _labels.add('Unknown_Class_${_labels.length}');
          }
        }
      }
    } catch (e, stack) {
      _isLoaded = false;
      _engineAvailable = false;
      AppLogger.e('CropDiseaseClassifier: V1 tensor allocation failed', e, stack);
      try {
        await FirebaseCrashlytics.instance.recordError(
          e, stack,
          reason: 'TFLite model load failure (Stage 3: tensor allocation) — engine marked unavailable',
          fatal: false,
        );
      } catch (_) {}
      return;
    }

    // V2 Model is optional (extended dataset)
    try {
      final v2Data = await rootBundle.load('assets/cropguard_plant_disease_v2.tflite');
      _labelsV2 = _parseLabels(await rootBundle.loadString('assets/labels_v2.txt'));
      final v2Bytes = Uint8List.fromList(
        v2Data.buffer.asUint8List(v2Data.offsetInBytes, v2Data.lengthInBytes),
      );
      _interpreterV2 = _createInterpreter(v2Bytes);
      _interpreterV2!.allocateTensors();
      final numClassesV2 = _interpreterV2!.getOutputTensor(0).shape.last;
      if (_labelsV2.length != numClassesV2) {
        if (_labelsV2.length > numClassesV2) {
          _labelsV2 = _labelsV2.sublist(0, numClassesV2);
        } else {
          while (_labelsV2.length < numClassesV2) {
            _labelsV2.add('Unknown_V2_Class_${_labelsV2.length}');
          }
        }
      }
    } catch (e) {
      AppLogger.w('CropDiseaseClassifier: V2 model optional load skipped ($e)');
      _interpreterV2 = null;
    }

    // Load metadata version
    try {
      final jsonStr = await rootBundle.loadString('assets/model_metadata.json');
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      modelVersion = map['version']?.toString() ?? '2.1';
    } catch (_) {
      modelVersion = '2.1';
    }

    _isLoaded = true;
    _engineAvailable = true;
  }

  bool get isLoaded => _isLoaded;
  bool get isEngineAvailable => _engineAvailable;

  ({String label, double confidence, List<TopCandidate> top3}) _selectBestFromEnsemble(
    Float32List inputTensor,
  ) {
    final r1 = _runSingleModelOnMainThread(_interpreterV1!, _labels, inputTensor);
    final r2 = _interpreterV2 != null
        ? _runSingleModelOnMainThread(_interpreterV2!, _labelsV2, inputTensor)
        : null;

    final adj1 = r1.confidence - (1.0 / (_labels.isNotEmpty ? _labels.length : 1));
    final adj2 = (r2 != null && _labelsV2.isNotEmpty)
        ? (r2.confidence - (1.0 / _labelsV2.length))
        : double.negativeInfinity;

    if (adj2 > adj1 && r2 != null) {
      return r2;
    } else {
      return r1;
    }
  }

  /// Classify an image from a file path.
  Future<ClassificationResult?> classifyFromPath(String imagePath) async {
    Uint8List? bytes;
    try {
      bytes = await File(imagePath).readAsBytes();
    } catch (e, stack) {
      AppLogger.e('CropDiseaseClassifier: failed to read image file at $imagePath', e, stack);
    }

    if (!_isLoaded && _engineAvailable) await loadModel();

    if (_isLoaded && _interpreterV1 != null && bytes != null) {
      try {
        final prepResult = await compute(
          _preprocessImageIsolate,
          _PreprocessingInput(imageFileBytes: bytes),
        );

        if (prepResult.inputTensor != null) {
          final best = _selectBestFromEnsemble(prepResult.inputTensor!);
          final topLabel = best.label;
          final topScore = best.confidence;
          final topCandidates = best.top3;

          final info = DiseaseDatabase.getInfo(topLabel);

          final numClasses = _labels.isNotEmpty ? _labels.length : 38;
          final isOod = prepResult.greenRatio < 0.05 || topScore < (2.0 / numClasses);

          if (topScore >= confidenceThreshold && topLabel != 'Unknown' && !isOod) {
            return ClassificationResult(
              label: topLabel,
              confidence: topScore,
              isHealthy: info.isHealthy,
              diseaseInfo: info,
              qualityResult: prepResult.qualityResult,
              isDegraded: false,
              isOutOfDistribution: false,
              topCandidates: topCandidates,
            );
          }

          // Below threshold or OOD — real model ran and produced a candidate.
          // Return the real model's output marked as degraded so UI can handle low confidence / OOD.
          return ClassificationResult(
            label: topLabel,
            confidence: topScore,
            isHealthy: info.isHealthy,
            diseaseInfo: info,
            qualityResult: prepResult.qualityResult,
            isDegraded: true,
            isOutOfDistribution: isOod,
            topCandidates: topCandidates,
          );
        }
      } catch (e) {
        AppLogger.w('CropDiseaseClassifier: TFLite inference exception ($e), using visual fallback');
      }
    }

    // Fallback: Engine unavailable or exception during prep/inference
    return _fallbackVisualClassification(
      imagePath,
      bytes,
      engineUnavailable: !_engineAvailable || !_isLoaded,
    );
  }

  /// Classify from raw RGBA bytes (used for live camera frames).
  Future<ClassificationResult?> classifyFromBytes(
      Uint8List rgbaBytes, int width, int height) async {
    if (!_isLoaded && _engineAvailable) await loadModel();

    if (_isLoaded && _interpreterV1 != null) {
      try {
        final prepResult = await compute(
          _preprocessImageIsolate,
          _PreprocessingInput(
            rgbaBytes: rgbaBytes,
            width: width,
            height: height,
          ),
        );

        if (prepResult.inputTensor != null) {
          final best = _selectBestFromEnsemble(prepResult.inputTensor!);
          final topLabel = best.label;
          final topScore = best.confidence;
          final topCandidates = best.top3;

          final info = DiseaseDatabase.getInfo(topLabel);
          final isBelow = topScore < confidenceThreshold || topLabel == 'Unknown';
          return ClassificationResult(
            label: topLabel,
            confidence: topScore,
            isHealthy: info.isHealthy,
            diseaseInfo: info,
            qualityResult: prepResult.qualityResult,
            isDegraded: isBelow,
            topCandidates: topCandidates,
          );
        }
      } catch (e) {
        AppLogger.w('CropDiseaseClassifier: classifyFromBytes exception ($e)');
      }
    }

    return _fallbackVisualClassification(
      'camera_frame.jpg',
      rgbaBytes,
      engineUnavailable: !_engineAvailable || !_isLoaded,
      isRgbaRaw: true,
      width: width,
      height: height,
    );
  }

  void close() {
    _interpreterV1?.close();
    _interpreterV1 = null;
    _interpreterV2?.close();
    _interpreterV2 = null;
    _isLoaded = false;
  }

  /// Test seam: calls [_fallbackVisualClassification] directly so unit tests
  /// can exercise the 0.30 / 0.45 heuristic confidence paths without needing
  /// TFLite to be available.
  ///
  /// Pass [isRgbaRaw] = true with valid [width] and [height] to test the raw
  /// RGBA branch (green-pixel ratio → 0.45). Pass [engineUnavailable] = true
  /// to test the engine-absent path (confidence → 0.0).
  @visibleForTesting
  static Future<ClassificationResult> fallbackForTest(
    Uint8List? bytes, {
    bool engineUnavailable = false,
    bool isRgbaRaw = false,
    int width = 0,
    int height = 0,
  }) =>
      _fallbackVisualClassification(
        'test_path',
        bytes,
        engineUnavailable: engineUnavailable,
        isRgbaRaw: isRgbaRaw,
        width: width,
        height: height,
      );

  /// The label used whenever the app cannot actually identify a crop or
  /// disease from the image pixels. [DiseaseDatabase.getInfo] has no entry
  /// for this key, so it falls through to its own honest default (cropType
  /// 'Unknown', a generic "consult an extension officer" treatment) — see
  /// disease_info.dart.
  static const String _unidentifiedLabel = 'Unidentified';

  /// Fallback path used ONLY when the TFLite engine could not be initialised on
  /// this device or an unrecoverable inference error occurred.
  ///
  /// This version never invents a crop or disease name. It always returns
  /// "Unidentified" with a confidence score below [confidenceThreshold] so it
  /// routes safely to the low-confidence or abstain UI.
  static Future<ClassificationResult> _fallbackVisualClassification(
    String imagePath,
    Uint8List? bytes, {
    bool engineUnavailable = false,
    List<TopCandidate> belowThresholdCandidates = const [],
    bool isRgbaRaw = false,
    int width = 0,
    int height = 0,
  }) async {
    double fallbackConfidence = engineUnavailable ? 0.0 : 0.30;

    if (!engineUnavailable && bytes != null && bytes.isNotEmpty) {
      try {
        img.Image? raw;
        if (isRgbaRaw && width > 0 && height > 0) {
          raw = img.Image.fromBytes(
            width: width,
            height: height,
            bytes: bytes.buffer,
            format: img.Format.uint8,
            numChannels: 4,
          );
        } else {
          raw = img.decodeImage(bytes);
        }

        if (raw != null) {
          int greenPixels = 0;
          int totalPixels = 0;

          final stepX = max(1, raw.width ~/ 100);
          final stepY = max(1, raw.height ~/ 100);

          for (var y = 0; y < raw.height; y += stepY) {
            for (var x = 0; x < raw.width; x += stepX) {
              final pixel = raw.getPixel(x, y);
              totalPixels++;
              if (pixel.g > pixel.r && pixel.g > pixel.b && pixel.g > 40) {
                greenPixels++;
              }
            }
          }

          if (totalPixels > 0 && greenPixels / totalPixels > 0.35) {
            fallbackConfidence = 0.45;
          }
        }
      } catch (e) {
        AppLogger.w('CropDiseaseClassifier: visual feature extraction exception ($e)');
      }
    }

    try {
      if (sl.isRegistered<AnalyticsService>()) {
        unawaited(sl<AnalyticsService>().logModelFallbackUsed(
          reason: engineUnavailable ? 'engine_unavailable' : 'inference_exception',
        ));
      }
      if (sl.isRegistered<ClassifierHealthService>()) {
        sl<ClassifierHealthService>().updateHealth(
          isHealthy: !engineUnavailable,
          usedFallback: true,
        );
      }
    } catch (_) {}

    return _makeDegradedResult(
      _unidentifiedLabel,
      fallbackConfidence,
      engineUnavailable: engineUnavailable,
      topCandidates: belowThresholdCandidates,
    );
  }

  /// Averages a list of [ClassificationResult]s from multi-angle captures.
  ///
  /// Picks the label from the single highest-confidence individual result
  /// and sets the returned confidence to the arithmetic mean across all
  /// inputs. Marks the result as [isDegraded] if any input was degraded.
  static ClassificationResult averageResults(List<ClassificationResult> results) {
    assert(results.isNotEmpty, 'averageResults called with an empty list');
    if (results.length == 1) return results.first;

    final best = results.reduce(
        (a, b) => a.confidence >= b.confidence ? a : b);
    final avgConfidence =
        results.map((r) => r.confidence).reduce((a, b) => a + b) /
            results.length;
    final anyDegraded = results.any((r) => r.isDegraded);

    // Merge top candidates: union across all results, deduplicate by label,
    // sort by max individual confidence, take top 3.
    final seen = <String>{};
    final merged = <TopCandidate>[];
    for (final r in results) {
      for (final c in r.topCandidates) {
        if (seen.add(c.label)) merged.add(c);
      }
    }
    merged.sort((a, b) => b.confidence.compareTo(a.confidence));

    return ClassificationResult(
      label: best.label,
      confidence: avgConfidence,
      isHealthy: best.isHealthy,
      diseaseInfo: best.diseaseInfo,
      qualityResult: best.qualityResult,
      isDegraded: anyDegraded,
      engineUnavailable: best.engineUnavailable,
      topCandidates: merged.take(3).toList(),
    );
  }

  /// Creates a [ClassificationResult] for the fallback heuristic classifier.
  /// Results are marked [isDegraded] so the UI can display a
  /// "Low confidence — retake photo" banner instead of showing full confidence.
  static ClassificationResult _makeDegradedResult(
    String label,
    double confidence, {
    bool engineUnavailable = false,
    List<TopCandidate> topCandidates = const [],
  }) {
    final info = DiseaseDatabase.getInfo(label);
    return ClassificationResult(
      label: label,
      confidence: confidence,
      isHealthy: info.isHealthy,
      diseaseInfo: info,
      isDegraded: true,
      engineUnavailable: engineUnavailable,
      topCandidates: topCandidates,
    );
  }
}

