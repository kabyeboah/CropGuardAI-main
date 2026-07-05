import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../core/utils/app_logger.dart';
import 'disease_info.dart';

/// Classification result returned from the TFLite model.
class ClassificationResult {
  final String label;
  final double confidence;
  final bool isHealthy;
  final DiseaseInfoEntry diseaseInfo;

  const ClassificationResult({
    required this.label,
    required this.confidence,
    required this.isHealthy,
    required this.diseaseInfo,
  });
}

// ── Isolate data transfer objects ─────────────────────────────────────────────
// Must be top-level so compute() can serialize them across isolate boundaries.

class _InferenceInput {
  final Uint8List modelBytes;
  final List<String> labels;
  final Uint8List modelBytesV2;
  final List<String> labelsV2;
  // One of the two image sources will be set:
  final Uint8List? imageFileBytes; // from classifyFromPath
  final Uint8List? rgbaBytes;      // from classifyFromBytes
  final int width;
  final int height;

  const _InferenceInput({
    required this.modelBytes,
    required this.labels,
    required this.modelBytesV2,
    required this.labelsV2,
    this.imageFileBytes,
    this.rgbaBytes,
    this.width = 0,
    this.height = 0,
  });
}

/// Runs inference on one model and returns the top label + confidence.
///
/// The output buffer is sized from the model's own output tensor shape so that
/// a stale or truncated label file cannot cause a buffer underrun / heap
/// corruption. A hard [assert] then verifies that the label list agrees with
/// the model's reported output dimension; any mismatch surfaces immediately
/// during debug builds rather than silently producing wrong predictions.
({String label, double confidence}) _runSingleModel(
  Uint8List modelBytes,
  List<String> labels,
  List<List<List<List<double>>>> inputTensor,
) {
  if (labels.isEmpty) return (label: 'Unknown', confidence: 0.0);

  final interpreter = Interpreter.fromBuffer(modelBytes);
  interpreter.allocateTensors();
  // Derive output dimension from the model itself, not from the label list.
  // Output tensor shape is [1, numClasses].
  final outputShape = interpreter.getOutputTensor(0).shape;
  final numClasses = outputShape.last;

  assert(
    numClasses == labels.length,
    'CropDiseaseClassifier: label count (${labels.length}) does not match '
    'model output classes ($numClasses). Restore the correct labels file.',
  );

  final outputBuffer = [List.filled(numClasses, 0.0)];
  try {
    interpreter.run(inputTensor, outputBuffer);
  } finally {
    interpreter.close();
  }

  final scores = outputBuffer[0];
  var topIndex = 0;
  var topScore = scores[0];
  for (var i = 1; i < scores.length; i++) {
    if (scores[i] > topScore) {
      topScore = scores[i];
      topIndex = i;
    }
  }
  final topLabel = topIndex < labels.length ? labels[topIndex] : 'Unknown';
  return (label: topLabel, confidence: topScore);
}

/// Runs inside a `compute()` isolate — no platform channels, no shared state.
/// Both models run and the result with the higher confidence score is returned.
ClassificationResult? _runInferenceIsolate(_InferenceInput input) {
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
  if (raw == null) return null;

  const inputSize = CropDiseaseClassifier.inputSize;
  final resized = img.copyResize(raw, width: inputSize, height: inputSize);

  // Build [1, 224, 224, 3] float tensor normalised to [0, 1].
  final inputTensor = List.generate(
    1,
    (_) => List.generate(
      inputSize,
      (y) => List.generate(
        inputSize,
        (x) {
          final pixel = resized.getPixel(x, y);
          return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
        },
      ),
    ),
  );

  final r1 = _runSingleModel(input.modelBytes, input.labels, inputTensor);
  final r2 = _runSingleModel(input.modelBytesV2, input.labelsV2, inputTensor);

  // Normalise by class count so a smaller model's softer softmax doesn't win
  // by default (v2 has 16 classes vs v1's 54, so raw v2 confidence is higher).
  final adj1 = r1.confidence - 1.0 / input.labels.length;
  final adj2 = r2.confidence - 1.0 / input.labelsV2.length;
  final topLabel = adj1 >= adj2 ? r1.label : r2.label;
  final topScore = adj1 >= adj2 ? r1.confidence : r2.confidence;

  final info = DiseaseDatabase.getInfo(topLabel);
  return ClassificationResult(
    label: topLabel,
    confidence: topScore,
    isHealthy: info.isHealthy,
    diseaseInfo: info,
  );
}

// ── Classifier ────────────────────────────────────────────────────────────────

/// Equivalent of CropDiseaseClassifier.kt — wraps tflite_flutter.
///
/// Inference is pushed off the main thread via [compute()] so long pixel-list
/// generation and interpreter execution do not cause UI jank on slow devices.
class CropDiseaseClassifier {
  static const int inputSize = 224;
  static const double confidenceThreshold = 0.60;

  List<String> _labels = [];
  Uint8List? _modelBytes;
  List<String> _labelsV2 = [];
  Uint8List? _modelBytesV2;
  bool _isLoaded = false;
  Future<void>? _loading;

  static List<String> _parseLabels(String raw) =>
      raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  /// Initialise both models and their label files. Concurrent calls share a
  /// single in-flight load so two simultaneous scans don't double-load.
  Future<void> loadModel() {
    if (_isLoaded) return Future.value();
    return _loading ??= _loadModelImpl().whenComplete(() => _loading = null);
  }

  Future<void> _loadModelImpl() async {
    try {
      final v1Data = await rootBundle.load('assets/cropguard_plant_disease.tflite');
      _modelBytes = v1Data.buffer.asUint8List();
      _labels = _parseLabels(await rootBundle.loadString('assets/labels.txt'));

      final v2Data = await rootBundle.load('assets/cropguard_plant_disease_v2.tflite');
      _modelBytesV2 = v2Data.buffer.asUint8List();
      _labelsV2 = _parseLabels(await rootBundle.loadString('assets/labels_v2.txt'));

      _isLoaded = true;
    } catch (e, stack) {
      _isLoaded = false;
      AppLogger.e('CropDiseaseClassifier: failed to load model', e, stack);
    }
  }

  bool get isLoaded => _isLoaded;

  /// Classify an image from a file path.
  /// Runs in a background isolate — does not block the UI thread.
  Future<ClassificationResult?> classifyFromPath(String imagePath) async {
    if (!_isLoaded) await loadModel();
    if (!_isLoaded || _modelBytes == null) return null;

    final bytes = await File(imagePath).readAsBytes();
    return compute(
      _runInferenceIsolate,
      _InferenceInput(
        modelBytes: _modelBytes!,
        labels: _labels,
        modelBytesV2: _modelBytesV2!,
        labelsV2: _labelsV2,
        imageFileBytes: bytes,
      ),
    );
  }

  /// Classify from raw RGBA bytes (used for live camera frames).
  /// Runs in a background isolate — does not block the UI thread.
  Future<ClassificationResult?> classifyFromBytes(
      Uint8List rgbaBytes, int width, int height) async {
    if (!_isLoaded) await loadModel();
    if (!_isLoaded || _modelBytes == null) return null;

    return compute(
      _runInferenceIsolate,
      _InferenceInput(
        modelBytes: _modelBytes!,
        labels: _labels,
        modelBytesV2: _modelBytesV2!,
        labelsV2: _labelsV2,
        rgbaBytes: rgbaBytes,
        width: width,
        height: height,
      ),
    );
  }

  void close() {
    _modelBytes = null;
    _modelBytesV2 = null;
    _isLoaded = false;
  }
}
