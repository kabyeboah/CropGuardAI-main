import 'package:cropguard_flutter/core/config/app_secrets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    AppSecrets.reset();
    dotenv.clean();
  });

  tearDown(() {
    AppSecrets.reset();
    dotenv.clean();
  });

  group('AppSecrets Precedence Resolution Order', () {
    group('Ghana NLP Subscription Key', () {
      test('1. Prefer dart-define over .env and Remote Config', () async {
        // Arrange
        AppSecrets.dartDefineGhanaNlpKeyOverride = 'dart-define-key';
        dotenv.loadFromString(envString: 'GHANA_NLP_SUBSCRIPTION_KEY=env-key');
        AppSecrets.setGhanaNlpSubscriptionKey('remote-key');

        // Act & Assert
        expect(AppSecrets.ghanaNlpSubscriptionKey, equals('dart-define-key'));
      });

      test('2. Prefer .env over Remote Config when dart-define is absent',
          () async {
        // Arrange
        dotenv.loadFromString(envString: 'GHANA_NLP_SUBSCRIPTION_KEY=env-key');
        AppSecrets.setGhanaNlpSubscriptionKey('remote-key');

        // Act & Assert
        expect(AppSecrets.ghanaNlpSubscriptionKey, equals('env-key'));
      });

      test(
          '3. Fallback to Remote Config when both dart-define and .env are absent',
          () async {
        // Arrange
        AppSecrets.setGhanaNlpSubscriptionKey('remote-key');

        // Act & Assert
        expect(AppSecrets.ghanaNlpSubscriptionKey, equals('remote-key'));
      });

      test('4. Return null if none of the three are present', () {
        // Act & Assert
        expect(AppSecrets.ghanaNlpSubscriptionKey, isNull);
      });
    });

    group('Cloudinary Configuration', () {
      test('1. Prefer dart-define over .env and Remote Config', () async {
        // Arrange
        AppSecrets.dartDefineCloudinaryCloudNameOverride = 'dart-define-cloud';
        AppSecrets.dartDefineCloudinaryUploadPresetOverride =
            'dart-define-preset';
        dotenv.loadFromString(envString: '''
CLOUDINARY_CLOUD_NAME=env-cloud
CLOUDINARY_UPLOAD_PRESET=env-preset
''');
        AppSecrets.setCloudinaryConfig(
          cloudName: 'remote-cloud',
          uploadPreset: 'remote-preset',
        );

        // Act & Assert
        expect(AppSecrets.cloudinaryCloudName, equals('dart-define-cloud'));
        expect(AppSecrets.cloudinaryUploadPreset, equals('dart-define-preset'));
      });

      test('2. Prefer .env over Remote Config when dart-define is absent',
          () async {
        // Arrange
        dotenv.loadFromString(envString: '''
CLOUDINARY_CLOUD_NAME=env-cloud
CLOUDINARY_UPLOAD_PRESET=env-preset
''');
        AppSecrets.setCloudinaryConfig(
          cloudName: 'remote-cloud',
          uploadPreset: 'remote-preset',
        );

        // Act & Assert
        expect(AppSecrets.cloudinaryCloudName, equals('env-cloud'));
        expect(AppSecrets.cloudinaryUploadPreset, equals('env-preset'));
      });

      test(
          '3. Fallback to Remote Config when both dart-define and .env are absent',
          () async {
        // Arrange
        AppSecrets.setCloudinaryConfig(
          cloudName: 'remote-cloud',
          uploadPreset: 'remote-preset',
        );

        // Act & Assert
        expect(AppSecrets.cloudinaryCloudName, equals('remote-cloud'));
        expect(AppSecrets.cloudinaryUploadPreset, equals('remote-preset'));
      });

      test('4. Return empty strings if none are present', () {
        // Act & Assert
        expect(AppSecrets.cloudinaryCloudName, equals(''));
        expect(AppSecrets.cloudinaryUploadPreset, equals(''));
      });
    });

    group('Deep-link/Password Reset URL Configurations', () {
      test('1. Prefer dart-define over .env, Remote Config, and Default',
          () async {
        // Arrange
        AppSecrets.dartDefinePasswordResetUrlOverride = 'dart-define-url';
        AppSecrets.dartDefineAndroidPackageOverride = 'dart-define-android';
        AppSecrets.dartDefineIosBundleIdOverride = 'dart-define-ios';

        dotenv.loadFromString(envString: '''
PASSWORD_RESET_CONTINUE_URL=env-url
ANDROID_PACKAGE_NAME=env-android
IOS_BUNDLE_ID=env-ios
''');

        AppSecrets.setPasswordResetConfig(
          continueUrl: 'remote-url',
          androidPackage: 'remote-android',
          iosBundleId: 'remote-ios',
        );

        // Act & Assert
        expect(AppSecrets.passwordResetContinueUrl, equals('dart-define-url'));
        expect(AppSecrets.androidPackageName, equals('dart-define-android'));
        expect(AppSecrets.iosBundleId, equals('dart-define-ios'));
      });

      test('2. Prefer .env over Remote Config when dart-define is absent',
          () async {
        // Arrange
        dotenv.loadFromString(envString: '''
PASSWORD_RESET_CONTINUE_URL=env-url
ANDROID_PACKAGE_NAME=env-android
IOS_BUNDLE_ID=env-ios
''');

        AppSecrets.setPasswordResetConfig(
          continueUrl: 'remote-url',
          androidPackage: 'remote-android',
          iosBundleId: 'remote-ios',
        );

        // Act & Assert
        expect(AppSecrets.passwordResetContinueUrl, equals('env-url'));
        expect(AppSecrets.androidPackageName, equals('env-android'));
        expect(AppSecrets.iosBundleId, equals('env-ios'));
      });

      test(
          '3. Fallback to Remote Config when both dart-define and .env are absent',
          () async {
        // Arrange
        AppSecrets.setPasswordResetConfig(
          continueUrl: 'remote-url',
          androidPackage: 'remote-android',
          iosBundleId: 'remote-ios',
        );

        // Act & Assert
        expect(AppSecrets.passwordResetContinueUrl, equals('remote-url'));
        expect(AppSecrets.androidPackageName, equals('remote-android'));
        expect(AppSecrets.iosBundleId, equals('remote-ios'));
      });

      test('4. Fallback to default constants if all sources are absent', () {
        // Act & Assert
        expect(AppSecrets.passwordResetContinueUrl,
            equals('https://cropguardai.app/reset-password'));
        expect(AppSecrets.androidPackageName, equals('com.cropguard.ai.app'));
        expect(AppSecrets.iosBundleId, equals('com.cropguard.ai.app'));
      });
    });
  });
}
