import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:cropguard_flutter/core/utils/image_quality_analyzer.dart';

void main() {
  test('ImageQualityAnalyzer identifies image that is too small', () {
    final tinyImage = img.Image(width: 100, height: 100);
    final result = ImageQualityAnalyzer.analyze(tinyImage);
    expect(result.isAcceptable, isFalse);
    expect(result.issue, equals(ImageQualityIssue.tooSmall));
  });

  test('ImageQualityAnalyzer identifies image that is too dark', () {
    final darkImage = img.Image(width: 300, height: 300);
    // All black pixels
    final result = ImageQualityAnalyzer.analyze(darkImage);
    expect(result.isAcceptable, isFalse);
    expect(result.issue, equals(ImageQualityIssue.tooDark));
  });

  test('ImageQualityAnalyzer accepts high contrast / sharp leaf texture image',
      () {
    final sharpImage = img.Image(width: 300, height: 300);
    // Draw high-contrast checkerboard pattern to simulate sharp leaf texture edges
    for (var y = 0; y < 300; y++) {
      for (var x = 0; x < 300; x++) {
        final val = ((x ~/ 10) + (y ~/ 10)) % 2 == 0 ? 255 : 50;
        sharpImage.setPixelRgb(x, y, val, val, val);
      }
    }

    final result = ImageQualityAnalyzer.analyze(sharpImage);
    expect(result.isAcceptable, isTrue);
    expect(result.issue, isNull);
  });

  test('ImageQualityAnalyzer configurable threshold tuning', () {
    final softImage = img.Image(width: 300, height: 300);
    for (var y = 0; y < 300; y++) {
      for (var x = 0; x < 300; x++) {
        final val = 120 + ((x ~/ 40) * 10);
        softImage.setPixelRgb(x, y, val, val, val);
      }
    }

    // High threshold rejects it
    final strictResult =
        ImageQualityAnalyzer.analyze(softImage, minBlurThreshold: 100.0);
    expect(strictResult.isAcceptable, isFalse);
    expect(strictResult.issue, equals(ImageQualityIssue.blurry));

    // Lower threshold accepts soft texture
    final relaxedResult =
        ImageQualityAnalyzer.analyze(softImage, minBlurThreshold: 1.0);
    expect(relaxedResult.isAcceptable, isTrue);
  });
}
