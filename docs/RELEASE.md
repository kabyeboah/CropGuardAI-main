# Release Guide (Android — Google Play)

App id: `com.crop.guard.app` · version is in `pubspec.yaml` (`version: x.y.z+build`).

## Prerequisites (one-time)
- Release keystore (`cropguard-release.jks`) — keep it OUT of git.
- Local signing: create `android/key.properties` (gitignored) with
  `keyAlias`, `keyPassword`, `storeFile=../cropguard-release.jks`, `storePassword`.
- CI signing: add GitHub Secrets `KEYSTORE_BASE64` (base64 of the .jks),
  `KEY_ALIAS`, `KEY_PASSWORD`, `STORE_PASSWORD`,
  `GOOGLE_SERVICES_JSON_BASE64` (base64 of android/app/google-services.json), plus
  `GHANA_NLP_SUBSCRIPTION_KEY`, `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_UPLOAD_PRESET`.
- Firebase: register the release SHA-256 for App Check (Play Integrity) and
  enable App Check enforcement per service.

## Build locally
```bash
flutter pub get
flutter gen-l10n
flutter analyze && flutter test
flutter build appbundle --release \
  --dart-define=GHANA_NLP_SUBSCRIPTION_KEY=*** \
  --dart-define=CLOUDINARY_CLOUD_NAME=*** \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=***
# output: build/app/outputs/bundle/release/app-release.aab
```
(Secrets can instead come from Firebase Remote Config; see `docs/SECURITY.md`.)

## CI build
Pushing to `main` runs `.github/workflows/flutter.yml` → analyze + test, then a
**signed** release AAB (artifact `app-release-aab`).

## Pre-submission checklist
- [ ] Bump `version:` in `pubspec.yaml`.
- [ ] `flutter analyze` clean, `flutter test` green.
- [ ] Smoke-test a release build on a low-end Android: app starts (no bundled
      `.env`), Ghana NLP/Cloudinary work via dart-define/Remote Config, scan →
      result → treatment → community flows survive rapid back-navigation.
- [ ] Firestore/Storage rules deployed (`firebase deploy --only firestore:rules,storage`).
- [ ] App Check enforcement on; release SHA-256 registered.
- [ ] Play Console: Data Safety form, privacy policy URL, store listing, screenshots.
- [ ] Deep links: host `assetlinks.json` for `com.crop.guard.app` (see
      `docs/PASSWORD_RESET_DEEPLINK.md`).

## Model accuracy
Before release, produce/refresh `docs/MODEL_ACCURACY.md` via the harness
(`integration_test/model_eval_test.dart`).
