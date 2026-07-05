# Security & Secrets

## Secret handling

- **Never commit real secrets and never bundle them as assets.** `.env` is
  `.gitignore`d and is **not** a Flutter asset (see `pubspec.yaml`), so it is not
  packaged into release binaries.
- Secret resolution order (`lib/core/config/app_secrets.dart`):
  1. `--dart-define=KEY=value` at build time (release path)
  2. a local `.env` (debug-only convenience; loaded in `main.dart` under `kDebugMode`)
  3. Firebase Remote Config (fetched at startup by `AppBootstrap`)
- Genuine secrets in this app: `GHANA_NLP_SUBSCRIPTION_KEY`,
  `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_UPLOAD_PRESET`. Provide them via
  `--dart-define` (CI) or Remote Config keys `ghana_nlp_subscription_key`,
  `cloudinary_cloud_name`, `cloudinary_upload_preset`.

### Not secrets (safe in the binary)
Firebase **mobile** API keys / app IDs (`firebase_options.dart`,
`google-services.json`, `GoogleService-Info.plist`) are identifiers, not secrets.
They are protected by **Firebase App Check** + API-key restrictions in the
Console, not by hiding them.

## Rotate these (they shipped in earlier builds that bundled `.env`)
1. **Ghana NLP** subscription key — regenerate in the Ghana NLP dashboard.
2. **Cloudinary** unsigned upload preset — rotate/replace in Cloudinary.
3. **Release keystore password** — `android/key.properties` currently uses a weak
   password; set a strong one and store it only in CI secrets.

## Platform hardening already in place
- **App Check**: Play Integrity / App Attest in release (`app_bootstrap.dart`).
  Enable **enforcement** per service in the Firebase Console (`docs/APP_CHECK.md`).
- **Firestore/Storage rules**: default-deny, user-scoped; uploads capped to 5 MB
  images (`firestore.rules`, `storage.rules`).
- **Crashlytics** user id is set on auth changes for crash attribution.
- Root/jailbreak + screenshot helpers exist (`core/utils/`) — enforcement is a
  product decision (currently opt-in).

## Deferred / follow-up
- Store last-known GPS via `flutter_secure_storage` instead of `SharedPreferences`
  (low severity; coordinates are coarse).
