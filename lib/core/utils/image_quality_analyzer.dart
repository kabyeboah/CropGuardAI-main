import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class ImageQualityAnalyzer {
  static const int _analysisMaxSide = 320;
  static const int _minShortSidePx = 160;
  static const double _minLaplacianVariance = 38.0;
  static const double _minMeanLuminance = 0.11;
  static const double _maxMeanLuminance = 0.90;

  static ImageQualityResult analyze(img.Image image) {
    final shortSide = min(image.width, image.height);
    if (shortSide < _minShortSidePx) {
      return const ImageQualityResult(false, ImageQualityIssue.tooSmall);
    }

    final grayscale = _analyzeImage(image);
    final meanLum = _meanLuminance(grayscale);
    if (meanLum < _minMeanLuminance) {
      return const ImageQualityResult(false, ImageQualityIssue.tooDark);
    }
    if (meanLum > _maxMeanLuminance) {
      return const ImageQualityResult(false, ImageQualityIssue.tooBright);
    }

    final lapVar = _laplacianVariance(grayscale);
    if (lapVar < _minLaplacianVariance) {
      return const ImageQualityResult(false, ImageQualityIssue.blurry);
    }

    return const ImageQualityResult(true, null);
  }

  static ScanPreviewQuality previewScanQuality(img.Image image) {
    final grayscale = _analyzeImage(image);
    final shortSide = min(image.width, image.height);
    return _qualityFromMetrics(
      meanLum: _meanLuminance(grayscale),
      lapVar: _laplacianVariance(grayscale),
      shortSide: shortSide,
    );
  }

  static ScanPreviewQuality previewFromCameraImage(CameraImage cameraImage) {
    final grayscale = _grayscaleFromCameraImage(cameraImage);
    if (grayscale.isEmpty || grayscale.first.isEmpty) {
      return const ScanPreviewQuality(
        PreviewQualityBand.poor,
        PreviewQualityBand.poor,
        PreviewQualityBand.poor,
      );
    }

    return _qualityFromMetrics(
      meanLum: _meanLuminance(grayscale),
      lapVar: _laplacianVariance(grayscale),
      shortSide: min(cameraImage.width, cameraImage.height),
    );
  }

  static ScanPreviewQuality _qualityFromMetrics({
    required double meanLum,
    required double lapVar,
    required int shortSide,
  }) {
    final lighting = _bandFromRange(meanLum, 0.12, 0.92, 0.15, 0.82);
    final focus = _focusBand(lapVar);
    final placement = _coverageBand(shortSide);
    return ScanPreviewQuality(lighting, focus, placement);
  }

  static PreviewQualityBand _bandFromRange(
    double val,
    double minPoor,
    double maxPoor,
    double minGood,
    double maxGood,
  ) {
    if (val < minPoor || val > maxPoor) return PreviewQualityBand.poor;
    if (val >= minGood && val <= maxGood) return PreviewQualityBand.good;
    return PreviewQualityBand.fair;
  }

  static PreviewQualityBand _focusBand(double lapVar) {
    if (lapVar < 28.0) return PreviewQualityBand.poor;
    if (lapVar >= 65.0) return PreviewQualityBand.good;
    return PreviewQualityBand.fair;
  }

  static PreviewQualityBand _coverageBand(int shortSide) {
    if (shortSide < 280) return PreviewQualityBand.poor;
    if (shortSide < 480) return PreviewQualityBand.fair;
    return PreviewQualityBand.good;
  }

  static List<List<int>> _analyzeImage(img.Image image) {
    final scaled = _scaleForAnalysis(image);
    return _toGrayscale(scaled);
  }

  static img.Image _scaleForAnalysis(img.Image image) {
    final longest = max(image.width, image.height);
    if (longest <= _analysisMaxSide) return image;
    return img.copyResize(
      image,
      width: image.width > image.height ? _analysisMaxSide : null,
      height: image.height >= image.width ? _analysisMaxSide : null,
    );
  }

  static List<List<int>> _toGrayscale(img.Image image) {
    final width = image.width;
    final height = image.height;
    final gray = List.generate(height, (_) => List.filled(width, 0));

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        gray[y][x] = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b)
            .round()
            .clamp(0, 255);
      }
    }

    return gray;
  }

  static List<List<int>> _grayscaleFromCameraImage(CameraImage cameraImage) {
    const targetSide = 96;
    final width = cameraImage.width;
    final height = cameraImage.height;
    final stepX = max(1, width ~/ targetSide);
    final stepY = max(1, height ~/ targetSide);
    final outWidth = max(1, width ~/ stepX);
    final outHeight = max(1, height ~/ stepY);
    final gray = List.generate(outHeight, (_) => List.filled(outWidth, 0));

    if (cameraImage.format.group == ImageFormatGroup.bgra8888 ||
        (Platform.isIOS && cameraImage.planes.length == 1)) {
      final plane = cameraImage.planes.first;
      final bytes = plane.bytes;
      final bytesPerRow = plane.bytesPerRow;
      for (var oy = 0; oy < outHeight; oy++) {
        final sy = min(height - 1, oy * stepY);
        final rowOffset = sy * bytesPerRow;
        for (var ox = 0; ox < outWidth; ox++) {
          final sx = min(width - 1, ox * stepX);
          final index = rowOffset + sx * 4;
          if (index + 3 >= bytes.length) continue;
          final b = bytes[index];
          final g = bytes[index + 1];
          final r = bytes[index + 2];
          gray[oy][ox] = ((0.299 * r) + (0.587 * g) + (0.114 * b))
              .round()
              .clamp(0, 255);
        }
      }
      return gray;
    }

    final yPlane = cameraImage.planes.first;
    final yBytes = yPlane.bytes;
    final bytesPerRow = yPlane.bytesPerRow;
    final bytesPerPixel = yPlane.bytesPerPixel ?? 1;
    for (var oy = 0; oy < outHeight; oy++) {
      final sy = min(height - 1, oy * stepY);
      final rowOffset = sy * bytesPerRow;
      for (var ox = 0; ox < outWidth; ox++) {
        final sx = min(width - 1, ox * stepX);
        final index = rowOffset + sx * bytesPerPixel;
        if (index >= yBytes.length) continue;
        gray[oy][ox] = yBytes[index];
      }
    }
    return gray;
  }

  static double _meanLuminance(List<List<int>> gray) {
    var sum = 0.0;
    var count = 0;
    for (final row in gray) {
      for (final value in row) {
        sum += value / 255.0;
        count++;
      }
    }
    return count == 0 ? 0.0 : sum / count;
  }

  static double _laplacianVariance(List<List<int>> gray) {
    if (gray.length < 3 || gray.first.length < 3) return 0.0;

    var sum = 0.0;
    var sumSq = 0.0;
    var count = 0;

    for (var y = 1; y < gray.length - 1; y++) {
      for (var x = 1; x < gray[y].length - 1; x++) {
        final center = gray[y][x];
        final lap = (gray[y - 1][x] +
                gray[y + 1][x] +
                gray[y][x - 1] +
                gray[y][x + 1] -
                4 * center)
            .toDouble();
        sum += lap;
        sumSq += lap * lap;
        count++;
      }
    }

    if (count == 0) return 0.0;
    final mean = sum / count;
    return (sumSq / count) - mean * mean;
  }
}

class ImageQualityResult {
  final bool isAcceptable;
  final ImageQualityIssue? issue;

  const ImageQualityResult(this.isAcceptable, this.issue);
}

enum ImageQualityIssue { blurry, tooDark, tooBright, tooSmall }

enum PreviewQualityBand { good, fair, poor }

class ScanPreviewQuality {
  final PreviewQualityBand lighting;
  final PreviewQualityBand focus;
  final PreviewQualityBand placement;

  const ScanPreviewQuality(this.lighting, this.focus, this.placement);

  PreviewQualityBand get coverage => placement;
}
