import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../core/utils/app_logger.dart';
import '../../core/utils/image_quality_analyzer.dart';
import 'disease_info.dart';

/// Classification result returned from the TFLite model.
class ClassificationResult {
  final String label;
  final double confidence;
  final bool isHealthy;
  final DiseaseInfoEntry diseaseInfo;
  final ImageQualityResult? qualityResult;
  final bool isDegraded;
  final bool engineUnavailable;

  const ClassificationResult({
    required this.label,
    required this.confidence,
    required this.isHealthy,
    required this.diseaseInfo,
    this.qualityResult,
    this.isDegraded = false,
    this.engineUnavailable = false,
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

  const _PreprocessingResult({
    this.inputTensor,
    required this.qualityResult,
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
  );
}

/// Runs inference on one model and returns the top label + confidence.
({String label, double confidence}) _runSingleModelOnMainThread(
  Interpreter interpreter,
  List<String> labels,
  Float32List inputTensor,
) {
  if (labels.isEmpty) return (label: 'Unknown', confidence: 0.0);

  final outputShape = interpreter.getOutputTensor(0).shape;
  final numClasses = outputShape.last;

  assert(
    numClasses == labels.length,
    'CropDiseaseClassifier: label count (${labels.length}) does not match '
    'model output classes ($numClasses). Restore the correct labels file.',
  );

  final outputBuffer = [List.filled(numClasses, 0.0)];
  final reshapedInput = inputTensor.reshape([1, CropDiseaseClassifier.inputSize, CropDiseaseClassifier.inputSize, 3]);
  interpreter.run(reshapedInput, outputBuffer);

  final scores = outputBuffer[0];

  // Apply Softmax normalization if raw logits are returned
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

  var topIndex = 0;
  var topScore = probabilities[0];
  for (var i = 1; i < probabilities.length; i++) {
    if (probabilities[i] > topScore) {
      topScore = probabilities[i];
      topIndex = i;
    }
  }
  final topLabel = topIndex < labels.length ? labels[topIndex] : 'Unknown';
  return (label: topLabel, confidence: topScore);
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
  Interpreter _createInterpreter(Uint8List modelBytes) {
    // First attempt: let tflite_flutter use its default (Metal/CoreML on iOS,
    // NNAPI on Android) with a reasonable thread count.
    try {
      final opts = InterpreterOptions()..threads = 2;
      return Interpreter.fromBuffer(modelBytes, options: opts);
    } catch (e) {
      AppLogger.w(
        'CropDiseaseClassifier: hardware delegate unavailable ($e); '
        'retrying with CPU-only interpreter.',
      );
    }

    // Fallback: explicit CPU-only — no Metal/CoreML/NNAPI delegate.
    final cpuOpts = InterpreterOptions()
      ..threads = 2
      ..useNnApiForAndroid = false;
    return Interpreter.fromBuffer(modelBytes, options: cpuOpts);
  }

  Future<void> _loadModelImpl() async {
    ByteData? v1Data;
    Uint8List? v1Bytes;

    // Stage 1: Load V1 asset files
    try {
      v1Data = await rootBundle.load('assets/cropguard_plant_disease.tflite');
      _labels = _parseLabels(await rootBundle.loadString('assets/labels.txt'));
      v1Bytes = v1Data.buffer.asUint8List(v1Data.offsetInBytes, v1Data.lengthInBytes);
    } catch (e, stack) {
      _isLoaded = false;
      _engineAvailable = false;
      AppLogger.e('CropDiseaseClassifier: V1 asset load failed', e, stack);
      return;
    }

    // Stage 2: Create V1 interpreter
    try {
      _interpreterV1 = _createInterpreter(v1Bytes);
    } catch (e, stack) {
      _isLoaded = false;
      _engineAvailable = false;
      AppLogger.e('CropDiseaseClassifier: V1 interpreter creation failed', e, stack);
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
      return;
    }

    // V2 Model is optional (extended dataset)
    try {
      final v2Data = await rootBundle.load('assets/cropguard_plant_disease_v2.tflite');
      _labelsV2 = _parseLabels(await rootBundle.loadString('assets/labels_v2.txt'));
      final v2Bytes = v2Data.buffer.asUint8List(v2Data.offsetInBytes, v2Data.lengthInBytes);
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

    _isLoaded = true;
    _engineAvailable = true;
  }

  bool get isLoaded => _isLoaded;
  bool get isEngineAvailable => _engineAvailable;

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
          final r1 = _runSingleModelOnMainThread(_interpreterV1!, _labels, prepResult.inputTensor!);
          final r2 = _interpreterV2 != null
              ? _runSingleModelOnMainThread(_interpreterV2!, _labelsV2, prepResult.inputTensor!)
              : null;

          // Use adjusted-score comparison so the smaller V2 model (16 classes)
          // gets a fair chance against V1 (93 classes). Without this adjustment,
          // V2's more-concentrated softmax always loses to V1's flatter distribution.
          final adj1 = r1.confidence - (1.0 / (_labels.isNotEmpty ? _labels.length : 1));
          final adj2 = (r2 != null && _labelsV2.isNotEmpty)
              ? (r2.confidence - (1.0 / _labelsV2.length))
              : double.negativeInfinity;

          final String topLabel;
          final double topScore;
          if (adj2 > adj1 && r2 != null) {
            topLabel = r2.label;
            topScore = r2.confidence;
          } else {
            topLabel = r1.label;
            topScore = r1.confidence;
          }

          // Confidence gate restored to 0.60 (matches model_metadata.json).
          // Below this threshold we fall through to the degraded fallback so
          // the UI can display a "low confidence — retake photo" warning.
          if (topScore >= confidenceThreshold && topLabel != 'Unknown') {
            final info = DiseaseDatabase.getInfo(topLabel);
            return ClassificationResult(
              label: topLabel,
              confidence: topScore,
              isHealthy: info.isHealthy,
              diseaseInfo: info,
              qualityResult: prepResult.qualityResult,
            );
          }
        }
      } catch (e) {
        AppLogger.w('CropDiseaseClassifier: TFLite inference exception ($e), using visual fallback');
      }
    }

    // Fallback: Smart Visual Feature & Multi-crop Keyword Classification
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
          final r1 = _runSingleModelOnMainThread(_interpreterV1!, _labels, prepResult.inputTensor!);
          final r2 = _interpreterV2 != null
              ? _runSingleModelOnMainThread(_interpreterV2!, _labelsV2, prepResult.inputTensor!)
              : null;

          // Same adjusted-score comparison as classifyFromPath.
          final adj1 = r1.confidence - (1.0 / (_labels.isNotEmpty ? _labels.length : 1));
          final adj2 = (r2 != null && _labelsV2.isNotEmpty)
              ? (r2.confidence - (1.0 / _labelsV2.length))
              : double.negativeInfinity;

          final String topLabel;
          final double topScore;
          if (adj2 > adj1 && r2 != null) {
            topLabel = r2.label;
            topScore = r2.confidence;
          } else {
            topLabel = r1.label;
            topScore = r1.confidence;
          }

          final info = DiseaseDatabase.getInfo(topLabel);
          return ClassificationResult(
            label: topLabel,
            confidence: topScore,
            isHealthy: info.isHealthy,
            diseaseInfo: info,
            qualityResult: prepResult.qualityResult,
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
    );
  }

  void close() {
    _interpreterV1?.close();
    _interpreterV1 = null;
    _interpreterV2?.close();
    _interpreterV2 = null;
    _isLoaded = false;
  }

  /// The label used whenever the app cannot actually identify a crop or
  /// disease from the image pixels. [DiseaseDatabase.getInfo] has no entry
  /// for this key, so it falls through to its own honest default (cropType
  /// 'Unknown', a generic "consult an extension officer" treatment) — see
  /// disease_info.dart.
  static const String _unidentifiedLabel = 'Unidentified';

  /// Fallback path used when either (a) the TFLite engine could not be
  /// initialised on this device, or (b) the real model's top prediction
  /// fell below [confidenceThreshold].
  ///
  /// This used to guess a *specific* disease by matching keywords in the
  /// image filename (e.g. a file named "tomato_blight.jpg" would return
  /// "Tomato Early Blight" at 55% confidence). That was misleading: real
  /// camera captures are never named that way, so in practice this path
  /// always produced the same fabricated "Cassava Mosaic Disease" result —
  /// and because `isDegraded` was never read outside this file, that
  /// specific-but-fake label was saved to scan history next to a real
  /// confidence percentage, indistinguishable from a genuine diagnosis.
  ///
  /// This version never invents a crop or disease it hasn't detected. It
  /// always returns the same honest "Unidentified" result and leaves the
  /// confidence value + [isDegraded]/[engineUnavailable] flags to drive the
  /// UI's abstain / low-confidence flow.
  static Future<ClassificationResult> _fallbackVisualClassification(
    String imagePath,
    Uint8List? bytes, {
    bool engineUnavailable = false,
  }) async {
    return _makeDegradedResult(
      _unidentifiedLabel,
      // Engine failures get 0.0 (never even attempted); a real inference
      // that just missed the confidence bar keeps a value in the
      // 0.40–0.60 "uncertain" band so the existing UI-level abstain gate
      // still routes it correctly.
      engineUnavailable ? 0.0 : 0.42,
      engineUnavailable: engineUnavailable,
    );
  }

  /// Creates a [ClassificationResult] for the fallback heuristic classifier.
  /// Results are marked [isDegraded] so the UI can display a
  /// "Low confidence — retake photo" banner instead of showing full confidence.
  static ClassificationResult _makeDegradedResult(
    String label,
    double confidence, {
    bool engineUnavailable = false,
  }) {
    final info = DiseaseDatabase.getInfo(label);
    return ClassificationResult(
      label: label,
      confidence: confidence,
      isHealthy: info.isHealthy,
      diseaseInfo: info,
      isDegraded: true,
      engineUnavailable: engineUnavailable,
    );
  }
}

