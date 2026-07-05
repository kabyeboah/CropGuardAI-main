import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cropguard_flutter/core/utils/result.dart';
import 'package:cropguard_flutter/domain/models/detection_result.dart';
import 'package:cropguard_flutter/domain/repositories/i_community_repository.dart';
import 'package:cropguard_flutter/domain/repositories/i_detection_repository.dart';
import 'package:cropguard_flutter/domain/usecases/weather/get_weather_usecase.dart';
import 'package:cropguard_flutter/presentation/screens/result/result_provider.dart';

class _MockDetectionRepo extends Mock implements IDetectionRepository {}

class _MockCommunityRepo extends Mock implements ICommunityRepository {}

class _MockGetWeather extends Mock implements GetWeatherUseCase {}

void main() {
  test('disposing during an in-flight load does not notify or throw', () async {
    final repo = _MockDetectionRepo();
    final completer = Completer<Result<DetectionResult?>>();
    when(() => repo.getDetection(any())).thenAnswer((_) => completer.future);

    final provider =
        ResultProvider(repo, _MockCommunityRepo(), _MockGetWeather());

    var notifyCount = 0;
    provider.addListener(() => notifyCount++);

    final loadFuture = provider.load(1); // pre-await notify (count -> 1)
    provider.dispose(); // _disposed = true

    // Completing after dispose must NOT trigger a post-await notify, and must
    // not throw "notifyListeners() called after dispose".
    completer.complete(Result.success(null));
    await loadFuture;

    expect(notifyCount, 1);
  });
}
