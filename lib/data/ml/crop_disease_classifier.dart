import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../core/utils/app_logger.dart';
import '../../core/utils/image_quality_analyzer.dart';
import '../../core/utils/image_safety_utils.dart';
import 'disease_info.dart';

// ── Explicit ML Exceptions ───────────────────────────────────────────────────

/// Base class for all ML-related operational exceptions.
class MLException implements Exception {
  final String message;
  final String code;
  const MLException(this.message, {this.code = 'ML_FAILURE'});

  @override
  String toString() => '$code: $message';
}

/// Thrown when asset loading or TFLite interpreter initialization fails.
class ModelLoadException extends MLException {
  const ModelLoadException(super.message) : super(code: 'MODEL_LOAD_FAILED');
}

/// Thrown when tensor dimensions, shapes, or types violate the metadata contract.
class ModelContractException extends MLException {
  const ModelContractException(super.message)
      : super(code: 'MODEL_CONTRACT_FAILED');
}

/// Thrown when image data cannot be read, decoded, or preprocessed.
class ModelInputException extends MLException {
  const ModelInputException(super.message) : super(code: 'MODEL_INPUT_INVALID');
}

/// Thrown when TFLite inference fails during interpreter runtime execution.
class ModelInferenceException extends MLException {
  const ModelInferenceException(super.message)
      : super(code: 'MODEL_INFERENCE_FAILED');
}

/// Thrown when label definitions mismatch the model output class count.
class LabelContractException extends MLException {
  const LabelContractException(super.message)
      : super(code: 'LABEL_CONTRACT_FAILED');
}

/// A single entry in the top-N candidate list returned by inference.
typedef TopCandidate = ({String label, double confidence});

/// Classification result returned from the TFLite model.
class ClassificationResult {
  final String label;
  final double confidence;
  final bool isHealthy;
  final DiseaseInfoEntry diseaseInfo;
  final ImageQualityResult? qualityResult;

  /// Indicates confidence abstention (true when topScore < confidenceThreshold,
  /// meaning the real model ran successfully but confidence was insufficient for
  /// standalone diagnosis, triggering multi-angle or cloud escalation).
  final bool isDegraded;
  final bool engineUnavailable;
  final String? modelVersion;

  /// Authentic top-N predictions from the model in descending confidence order.
  final List<TopCandidate> topCandidates;

  const ClassificationResult({
    required this.label,
    required this.confidence,
    required this.isHealthy,
    required this.diseaseInfo,
    this.qualityResult,
    this.isDegraded = false,
    this.engineUnavailable = false,
    this.modelVersion,
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

  const _PreprocessingResult({
    this.inputTensor,
    required this.qualityResult,
  });
}

/// Runs inside a `compute()` isolate — decodes, performs quality checks, and resizes.
_PreprocessingResult _preprocessImageIsolate(_PreprocessingInput input) {
  img.Image? raw;
  try {
    if (input.imageFileBytes != null) {
      raw = ImageSafetyUtils.safeDecodeAndOrient(input.imageFileBytes!);
    } else if (input.rgbaBytes != null && input.width > 0 && input.height > 0) {
      raw = img.Image.fromBytes(
        width: input.width,
        height: input.height,
        bytes: input.rgbaBytes!.buffer,
        format: img.Format.uint8,
        numChannels: 4,
      );
    }
  } catch (e) {
    AppLogger.w('CropDiseaseClassifier: safeDecodeAndOrient failed: $e');
    return const _PreprocessingResult(
      inputTensor: null,
      qualityResult: ImageQualityResult(
        false,
        ImageQualityIssue.blurry,
      ),
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

  // Build contiguous [1 * 128 * 128 * 3] float tensor — RAW [0, 255].
  // The V3 model has an internal Rescaling layer (x/127.5 - 1).
  // Dart must NOT divide by 255 here — doing so produces inputs in
  // roughly [-1, -0.992], the confirmed failure mode for this model.
  final inputTensor = Float32List(1 * inputSize * inputSize * 3);
  var idx = 0;
  for (var y = 0; y < inputSize; y++) {
    for (var x = 0; x < inputSize; x++) {
      final pixel = resized.getPixel(x, y);
      inputTensor[idx++] = pixel.r.toDouble();
      inputTensor[idx++] = pixel.g.toDouble();
      inputTensor[idx++] = pixel.b.toDouble();
    }
  }

  return _PreprocessingResult(
    inputTensor: inputTensor,
    qualityResult: qualityCheck,
  );
}

/// Runs inference on one model and returns the top label + confidence
/// plus the top-3 candidates in descending order.
///
/// [calibrationTemperature] is loaded from `model_metadata.json`
/// (`calibration_temperature` key). The model outputs raw logits; this
/// function applies temperature scaling then softmax unconditionally.
({
  String label,
  double confidence,
  List<TopCandidate> top3,
}) _runSingleModelOnMainThread(
  Interpreter interpreter,
  List<String> labels,
  Float32List inputTensor,
  double calibrationTemperature,
) {
  if (labels.isEmpty) {
    throw const LabelContractException('Labels list is empty.');
  }

  final outputShape = interpreter.getOutputTensor(0).shape;
  final numClasses = outputShape.last;

  if (numClasses != labels.length) {
    throw LabelContractException(
      'CropDiseaseClassifier: label count (${labels.length}) does not match '
      'model output classes ($numClasses).',
    );
  }

  final outputBuffer = [List.filled(numClasses, 0.0)];
  final reshapedInput = inputTensor.reshape(
      [1, CropDiseaseClassifier.inputSize, CropDiseaseClassifier.inputSize, 3]);

  try {
    interpreter.run(reshapedInput, outputBuffer);
  } catch (e) {
    throw ModelInferenceException(
        'TFLite interpreter.run execution failed: $e');
  }

  final logits = outputBuffer[0];
  if (logits.length != labels.length) {
    throw ModelContractException(
      'Output logits count (${logits.length}) does not match labels count (${labels.length}).',
    );
  }

  // Unconditional temperature-scaled softmax.
  // scaled_i = logit_i / calibrationTemperature  →  probabilities = softmax(scaled)
  // calibrationTemperature = 1.3409 (from model_metadata.json).
  final temp = calibrationTemperature > 0 ? calibrationTemperature : 1.0;
  final scaled = logits.map((l) => l / temp).toList();
  final maxScaled = scaled.reduce((a, b) => a > b ? a : b);
  var expSum = 0.0;
  final exps = List<double>.filled(scaled.length, 0.0);
  for (var i = 0; i < scaled.length; i++) {
    exps[i] =
        exp(scaled[i] - maxScaled); // subtract max for numerical stability
    expSum += exps[i];
  }
  final probabilities = exps.map((e) => expSum > 0 ? e / expSum : 0.0).toList();

  // Build index list sorted by probability descending.
  final indices = List<int>.generate(probabilities.length, (i) => i);
  indices.sort((a, b) => probabilities[b].compareTo(probabilities[a]));

  final topIndex = indices[0];
  final topScore = probabilities[topIndex];
  final topLabel = labels[topIndex];

  // Top-3 candidates.
  final top3 = indices
      .take(3)
      .where((i) => i < labels.length)
      .map<TopCandidate>(
          (i) => (label: labels[i], confidence: probabilities[i]))
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
  /// Input spatial dimension — must match the compiled model binary.
  /// V3 model: [1, 128, 128, 3]  (verified via tf.lite.Interpreter in Python).
  static const int inputSize = 128;
  static const double confidenceThreshold = 0.60;
  static String? modelVersion;

  List<String> _labels = [];
  Interpreter? _interpreter;
  bool _isLoaded = false;
  bool _engineAvailable = true;
  Future<void>? _loading;

  /// Temperature loaded from `model_metadata.json` (`calibration_temperature`).
  /// Applied unconditionally: scaled = logit / _calibrationTemperature → softmax.
  double _calibrationTemperature = 1.3409;

  static List<String> _parseLabels(String raw) =>
      raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  /// Initialise the model and its label file. Concurrent calls share a
  /// single in-flight load so two simultaneous scans don't double-load.
  Future<void> loadModel() {
    if (_isLoaded || !_engineAvailable) return Future.value();
    return _loading ??= _loadModelImpl().whenComplete(() => _loading = null);
  }

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
          reason:
              'TFLite hardware delegate failed — falling back to CPU options',
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
          reason:
              'TFLite CPU options failed — falling back to raw Interpreter.fromBuffer',
          fatal: false,
        ));
      } catch (_) {}
    }

    // Attempt 3: Minimal default Interpreter.fromBuffer with no options object
    return Interpreter.fromBuffer(modelBytes);
  }

  Future<void> _loadModelImpl() async {
    ByteData? modelData;
    Uint8List? modelBytes;

    int expectedInputSize = inputSize;
    int expectedNumClasses = 51;

    // Stage 1: Load metadata
    try {
      final jsonStr = await rootBundle.loadString('assets/model_metadata.json');
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      modelVersion = map['version']?.toString() ?? '2026.08.28';
      expectedInputSize = (map['input_size'] as num?)?.toInt() ?? inputSize;
      expectedNumClasses = (map['num_classes'] as num?)?.toInt() ?? 51;
      final rawTemp = map['calibration_temperature'];
      if (rawTemp != null) {
        _calibrationTemperature = (rawTemp as num).toDouble();
        AppLogger.d(
          'CropDiseaseClassifier: calibration_temperature=$_calibrationTemperature',
        );
      }
    } catch (e, stack) {
      _isLoaded = false;
      _engineAvailable = false;
      AppLogger.e('CropDiseaseClassifier: metadata load failed', e, stack);
      throw ModelContractException(
          'Failed to load assets/model_metadata.json: $e');
    }

    // Stage 2: Load asset files
    try {
      modelData =
          await rootBundle.load('assets/cropguard_plant_disease.tflite');
      _labels = _parseLabels(await rootBundle.loadString('assets/labels.txt'));
      modelBytes = Uint8List.fromList(
        modelData.buffer
            .asUint8List(modelData.offsetInBytes, modelData.lengthInBytes),
      );
    } catch (e, stack) {
      _isLoaded = false;
      _engineAvailable = false;
      AppLogger.e(
          'CropDiseaseClassifier: verified asset load failed', e, stack);
      try {
        await FirebaseCrashlytics.instance.recordError(
          e,
          stack,
          reason:
              'TFLite model load failure (asset load) — engine marked unavailable',
          fatal: false,
        );
      } catch (_) {}
      throw ModelLoadException('Failed to load model or label assets: $e');
    }

    if (_labels.isEmpty) {
      _isLoaded = false;
      _engineAvailable = false;
      throw const LabelContractException('Loaded labels file is empty');
    }
    if (_labels.toSet().length != _labels.length) {
      _isLoaded = false;
      _engineAvailable = false;
      throw const LabelContractException(
          'Duplicate labels found in labels file');
    }

    // Stage 3: Create interpreter
    try {
      _interpreter = _createInterpreter(modelBytes);
    } catch (e, stack) {
      _isLoaded = false;
      _engineAvailable = false;
      AppLogger.e(
          'CropDiseaseClassifier: interpreter creation failed', e, stack);
      try {
        await FirebaseCrashlytics.instance.recordError(
          e,
          stack,
          reason:
              'TFLite model load failure (interpreter creation) — engine marked unavailable',
          fatal: false,
        );
      } catch (_) {}
      throw ModelLoadException('Failed to create TFLite interpreter: $e');
    }

    // Stage 4: Allocate tensors & strictly enforce contracts
    try {
      _interpreter!.allocateTensors();

      // Input tensor shape & type validation
      final inputTensors = _interpreter!.getInputTensors();
      if (inputTensors.isEmpty) {
        throw const ModelContractException('Model has no input tensors');
      }
      final inputTensor = inputTensors[0];
      final inShape = inputTensor.shape;
      if (inShape.length != 4 ||
          inShape[0] != 1 ||
          inShape[1] != expectedInputSize ||
          inShape[2] != expectedInputSize ||
          inShape[3] != 3) {
        throw ModelContractException(
          'Model input tensor shape $inShape does not match metadata contract [1, $expectedInputSize, $expectedInputSize, 3]',
        );
      }
      if (inputTensor.type != TensorType.float32) {
        throw ModelContractException(
          'Model input tensor type ${inputTensor.type} does not match expected float32',
        );
      }

      // Output tensor shape & type validation
      final outputTensors = _interpreter!.getOutputTensors();
      if (outputTensors.isEmpty) {
        throw const ModelContractException('Model has no output tensors');
      }
      final outputTensor = outputTensors[0];
      final outShape = outputTensor.shape;
      final numClasses = outShape.last;
      if (outShape.length != 2 ||
          outShape[0] != 1 ||
          numClasses != expectedNumClasses) {
        throw ModelContractException(
          'Model output tensor shape $outShape does not match metadata contract [1, $expectedNumClasses]',
        );
      }
      if (outputTensor.type != TensorType.float32) {
        throw ModelContractException(
          'Model output tensor type ${outputTensor.type} does not match expected float32',
        );
      }

      // Exact label count match — NEVER silently truncate, NEVER synthesize synthetic labels
      if (_labels.length != numClasses) {
        throw LabelContractException(
          'Label count (${_labels.length}) does not match model output classes ($numClasses).',
        );
      }
    } catch (e, stack) {
      _isLoaded = false;
      _engineAvailable = false;
      _interpreter?.close();
      _interpreter = null;
      AppLogger.e(
          'CropDiseaseClassifier: tensor contract validation failed', e, stack);
      try {
        await FirebaseCrashlytics.instance.recordError(
          e,
          stack,
          reason:
              'TFLite tensor contract validation failure — engine marked unavailable',
          fatal: false,
        );
      } catch (_) {}
      if (e is MLException) rethrow;
      throw ModelContractException('TFLite tensor contract error: $e');
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
      final file = File(imagePath);
      if (!await file.exists()) {
        throw ModelInputException('Image file does not exist at $imagePath');
      }
      bytes = await file.readAsBytes();
    } catch (e, stack) {
      AppLogger.e(
          'CropDiseaseClassifier: failed to read image file at $imagePath',
          e,
          stack);
      if (e is MLException) rethrow;
      throw ModelInputException('Failed to read image file: $e');
    }

    if (!_isLoaded) {
      await loadModel();
    }

    if (!_isLoaded || _interpreter == null) {
      throw const ModelLoadException(
          'ML model is not loaded or engine is unavailable');
    }

    final prepResult = await compute(
      _preprocessImageIsolate,
      _PreprocessingInput(imageFileBytes: bytes),
    );

    if (!prepResult.qualityResult.isAcceptable) {
      return ClassificationResult(
        label: 'Unknown',
        confidence: 0.0,
        isHealthy: false,
        diseaseInfo: DiseaseDatabase.getInfo('Unknown'),
        qualityResult: prepResult.qualityResult,
        isDegraded: true,
        modelVersion: modelVersion,
      );
    }

    if (prepResult.inputTensor == null) {
      throw const ModelInputException(
          'Failed to decode or preprocess image tensor');
    }

    final singleResult = _runSingleModelOnMainThread(
      _interpreter!,
      _labels,
      prepResult.inputTensor!,
      _calibrationTemperature,
    );

    final topLabel = singleResult.label;
    final topScore = singleResult.confidence;
    final topCandidates = singleResult.top3;
    final info = DiseaseDatabase.getInfo(topLabel);
    final isAbstained = topScore < confidenceThreshold || topLabel == 'Unknown';

    return ClassificationResult(
      label: topLabel,
      confidence: topScore,
      isHealthy: info.isHealthy,
      diseaseInfo: info,
      qualityResult: prepResult.qualityResult,
      isDegraded: isAbstained,
      modelVersion: modelVersion,
      topCandidates: topCandidates,
    );
  }

  /// Classify from raw RGBA bytes (used for live camera frames).
  Future<ClassificationResult?> classifyFromBytes(
    Uint8List rgbaBytes,
    int width,
    int height,
  ) async {
    if (rgbaBytes.isEmpty || width <= 0 || height <= 0) {
      throw const ModelInputException(
          'Invalid raw byte dimensions for classification');
    }

    if (!_isLoaded) {
      await loadModel();
    }

    if (!_isLoaded || _interpreter == null) {
      throw const ModelLoadException(
          'ML model is not loaded or engine is unavailable');
    }

    final prepResult = await compute(
      _preprocessImageIsolate,
      _PreprocessingInput(
        rgbaBytes: rgbaBytes,
        width: width,
        height: height,
      ),
    );

    if (!prepResult.qualityResult.isAcceptable) {
      return ClassificationResult(
        label: 'Unknown',
        confidence: 0.0,
        isHealthy: false,
        diseaseInfo: DiseaseDatabase.getInfo('Unknown'),
        qualityResult: prepResult.qualityResult,
        isDegraded: true,
        modelVersion: modelVersion,
      );
    }

    if (prepResult.inputTensor == null) {
      throw const ModelInputException(
          'Failed to decode or preprocess raw image bytes');
    }

    final singleResult = _runSingleModelOnMainThread(
      _interpreter!,
      _labels,
      prepResult.inputTensor!,
      _calibrationTemperature,
    );

    final topLabel = singleResult.label;
    final topScore = singleResult.confidence;
    final topCandidates = singleResult.top3;
    final info = DiseaseDatabase.getInfo(topLabel);
    final isAbstained = topScore < confidenceThreshold || topLabel == 'Unknown';

    return ClassificationResult(
      label: topLabel,
      confidence: topScore,
      isHealthy: info.isHealthy,
      diseaseInfo: info,
      qualityResult: prepResult.qualityResult,
      isDegraded: isAbstained,
      modelVersion: modelVersion,
      topCandidates: topCandidates,
    );
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }

  /// Computes fused soft-voting candidates across multiple photo candidate distributions.
  static List<TopCandidate> computeSoftVotingCandidates(
    List<List<TopCandidate>> candidateLists,
  ) {
    if (candidateLists.isEmpty || candidateLists.every((l) => l.isEmpty)) {
      return const [];
    }

    final scoreMap = <String, double>{};
    int count = 0;

    for (final list in candidateLists) {
      if (list.isEmpty) continue;
      count++;
      for (final candidate in list) {
        scoreMap[candidate.label] =
            (scoreMap[candidate.label] ?? 0.0) + candidate.confidence;
      }
    }

    if (count == 0 || scoreMap.isEmpty) {
      return const [];
    }

    final merged = scoreMap.entries.map((e) {
      return (label: e.key, confidence: e.value / count);
    }).toList();

    merged.sort((a, b) => b.confidence.compareTo(a.confidence));
    return merged.take(3).toList();
  }

  /// Averages a list of authentic [ClassificationResult]s from multi-angle captures.
  ///
  /// Combines candidate probabilities using soft-voting across angles,
  /// selects the top-scoring disease label, and computes the arithmetic mean
  /// confidence across inputs. Marks the result as [isDegraded] if any input was degraded.
  static ClassificationResult averageResults(
      List<ClassificationResult> results) {
    assert(results.isNotEmpty, 'averageResults called with an empty list');
    if (results.length == 1) return results.first;

    final candidateLists = results.map((r) => r.topCandidates).toList();
    final merged = computeSoftVotingCandidates(candidateLists);

    final best = results.reduce((a, b) => a.confidence >= b.confidence ? a : b);
    final avgConfidence = merged.isNotEmpty
        ? merged.first.confidence
        : results.map((r) => r.confidence).reduce((a, b) => a + b) /
            results.length;
    final anyDegraded = results.any((r) => r.isDegraded);
    final topLabel = merged.isNotEmpty ? merged.first.label : best.label;
    final info = DiseaseDatabase.getInfo(topLabel);

    return ClassificationResult(
      label: topLabel,
      confidence: avgConfidence,
      isHealthy: info.isHealthy,
      diseaseInfo: info,
      qualityResult: best.qualityResult,
      isDegraded: anyDegraded,
      engineUnavailable: best.engineUnavailable,
      modelVersion: best.modelVersion ?? CropDiseaseClassifier.modelVersion,
      topCandidates: merged,
    );
  }
}
