import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cropguard_flutter/core/utils/result.dart';
import 'package:cropguard_flutter/core/utils/connectivity_service.dart';
import 'package:cropguard_flutter/domain/repositories/i_profile_repository.dart';
import 'package:cropguard_flutter/domain/repositories/i_auth_repository.dart';
import 'package:cropguard_flutter/data/remote/image_upload_service.dart';
import 'package:cropguard_flutter/presentation/screens/profile/profile_provider.dart';

class _MockProfileRepo extends Mock implements IProfileRepository {}
class _MockAuthRepo extends Mock implements IAuthRepository {}
class _MockConnectivityService extends Mock implements ConnectivityService {}
class _MockImageUploadService extends Mock implements ImageUploadService {}

void main() {
  late _MockProfileRepo mockProfileRepo;
  late _MockAuthRepo mockAuthRepo;
  late _MockConnectivityService mockConnectivity;
  late _MockImageUploadService mockUploader;
  late ProfileProvider provider;

  setUp(() {
    mockProfileRepo = _MockProfileRepo();
    mockAuthRepo = _MockAuthRepo();
    mockConnectivity = _MockConnectivityService();
    mockUploader = _MockImageUploadService();

    when(() => mockConnectivity.statusStream).thenAnswer((_) => Stream.value(ConnectionStatus.online));
    when(() => mockConnectivity.checkStatus()).thenAnswer((_) async => ConnectionStatus.online);
    when(() => mockProfileRepo.getLocalProfilePhotoPath()).thenReturn(null);
    when(() => mockProfileRepo.getFarmStats()).thenAnswer((_) async => Result.success({'total': 50, 'healthy': 40, 'diseased': 10}));
    when(() => mockProfileRepo.getAlertsEnabled()).thenReturn(true);
    when(() => mockProfileRepo.getHighQualityScans()).thenReturn(true);

    provider = ProfileProvider(
      mockProfileRepo,
      mockAuthRepo,
      mockConnectivity,
      mockUploader,
    );
  });

  group('ProfileProvider - load & getters', () {
    test('load populates farm stats and preferences', () async {
      await provider.load();

      expect(provider.stats.totalScans, 50);
      expect(provider.stats.healthyScans, 40);
      expect(provider.stats.diseasedScans, 10);
      expect(provider.isPro, isFalse);
    });

    test('sets isPro to true if totalScans >= 100', () async {
      when(() => mockProfileRepo.getFarmStats()).thenAnswer((_) async => Result.success({'total': 120, 'healthy': 100, 'diseased': 20}));

      await provider.load();

      expect(provider.isPro, isTrue);
    });
  });

  group('ProfileProvider - saveProfile', () {
    test('fails if display name is empty', () async {
      final success = await provider.saveProfile(displayName: '   ');
      expect(success, isFalse);
      expect(provider.profileError, 'Display name cannot be empty.');
    });

    test('succeeds when updateDisplayName in auth repository succeeds', () async {
      when(() => mockAuthRepo.updateDisplayName('Kofi')).thenAnswer((_) async => Result.success(null));

      final success = await provider.saveProfile(displayName: 'Kofi');

      expect(success, isTrue);
      expect(provider.profileError, isNull);
    });
  });
}
