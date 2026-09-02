# CropGuard AI — Remediation & Firebase→Supabase Migration Brief

**For: an agentic coding assistant (Claude Code / Cursor / Windsurf) working in the CropGuardAI repo.**

Paste this whole document as your task brief. Read it end to end before touching a single file.

---

## 0. Who you are and how you must behave

You are working on a **Flutter final-year university project** (KNUST) that is already substantially built and largely well-architected. Your job is **repair and migration**, not redesign. The person who wrote this code did a good job on structure; the failures are at the integration seams.

### Hard rules — violating any of these is worse than not doing the task

1. **Never invent an API.** If you are unsure whether a method exists on `SupabaseClient`, `supabase_flutter`, `go_router`, or any package, open `pubspec.lock`, find the resolved version, and check the actual package source in `~/.pub-cache/hosted/pub.dev/<pkg>-<version>/`. Do not guess from memory — several of these packages had breaking changes recently (`google_sign_in` 6→7, `firebase_core` 3→4, `go_router` 14→17).

2. **Verify before you assert.** Every claim in this brief is marked `[CONFIRMED]` (I traced it in the code) or `[VERIFY]` (you must confirm it yourself before acting). Treat `[VERIFY]` items as hypotheses.

3. **One phase per commit.** Do not batch phases. After each phase run the gate in §11 and stop if it fails.

4. **Run the gate after every phase:**
   ```bash
   flutter analyze --no-fatal-infos
   flutter test
   ```
   If either regresses relative to the baseline you captured in Phase 0, fix it before continuing. Do not proceed with a red suite.

5. **Do not reformat, re-order imports, rename, or "tidy" code you were not asked to change.** Diff noise makes this unreviewable. If `dart format` wants to reflow a file you touched, that's fine; do not run it repo-wide.

6. **Do not delete anything without asking.** Several things in this repo look dead but are load-bearing (see §1.3). When you believe something is dead, list it and ask.

7. **Ask at every DECISION GATE.** They are marked `🚦 DECISION`. Do not pick for the user. These are product/cost decisions, not code decisions.

8. **Never commit secrets.** No API keys, no service-role keys, no `.env`, no `google-services.json`. If you need a value, add it to `.env.example` as a named placeholder and tell the user to fill it.

9. **When a fix changes on-device data, write a migration.** The local SQLite DB is at version 17. Any schema change bumps to 18 and adds an `if (oldVersion < 18)` block. Never edit `_onCreate` without a matching `_onUpgrade` branch — existing installs never re-run `_onCreate`.

10. **Preserve the offline-first behaviour.** This app is for farmers in rural Ghana on poor connectivity. Every network path must keep its timeout, its retry, and its `PendingSyncQueue` fallback. If a refactor removes an offline path, you have broken the product.

---

## 1. Context you need before you start

### 1.1 What the app is

CropGuard AI: an offline-first Flutter app that classifies crop diseases from leaf photos using an on-device TensorFlow Lite model (MobileNetV2, 128×128 input, 51 classes), then shows treatment guidance, tracks treatments, maps community-reported outbreaks, and supports Ghanaian languages (Twi, Ewe, Dagbani).

**Stack:** Flutter 3.35+, Dart 3.6+, `provider` + `get_it`, `go_router`, `sqflite` (local), Supabase (auth/DB/storage), Firebase (functions/messaging/analytics/crashlytics/remote config/app check), `tflite_flutter`, `flutter_map` + OpenStreetMap.

### 1.2 The root cause of nearly every bug

**The Flutter client was migrated from Firebase to Supabase. The backend was not.** [CONFIRMED]

- Auth, database, and storage are **Supabase**.
- Cloud Functions, push triggers, and the account-deletion cascade are **Firebase/Firestore**.
- They do not talk to each other, and nothing in the codebase bridges them.

Everything in §2 (Critical) is a symptom of this single split. Fixing it properly *is* the migration.

### 1.3 Things that look wrong but are NOT — do not "fix" these

- `lib/core/di/service_locator.dart:93` — `GhanaNlpService(functions: sl<CloudFunctionsService>());` with no assignment. This looks like a dropped registration. **It is not.** `GhanaNlpService` has a factory constructor that mutates a static singleton, so the bare call is a deliberate injection side-effect. [CONFIRMED] You may add a clarifying comment. Do not "fix" it without changing the class too.
- `assets/cropguard_plant_disease_verified.tflite` is a **symlink**, not a 30-byte corrupt file. [CONFIRMED]
- The `tw`/`ee`/`dag` generated localization files contain English strings. That is the intended fallback, not a bug. [CONFIRMED] See §9.3.
- `test/data/remote/gemini_live_e2e_test.dart` hits a live API by design. Leave it; just make sure it's excluded from CI or skipped without credentials.

---

## 2. CRITICAL defects — all confirmed by code trace

### C1 — Every Cloud Function call resolves to a non-existent project [CONFIRMED]

`lib/data/remote/cloud_functions_service.dart` defaults to:
```dart
String projectId = 'cropguard-ai',
```
and `service_locator.dart` constructs it with **no arguments**. The real project (per `.firebaserc`, `firebase.json`, `lib/firebase_options.dart`) is **`cropguard-6ada8`**.

Result: every call goes to `https://us-central1-cropguard-ai.cloudfunctions.net/...` → 404 → `ServerFailure('Backend function X not found.')`.

`test/data/remote/cloud_functions_service_test.dart` injects `projectId: 'test-project'`, so the suite can never catch this.

### C2 — Even at the right URL, auth would fail [CONFIRMED]

`_getAuthToken()` returns `Supabase.instance.client.auth.currentSession?.accessToken` and sends it as `Authorization: Bearer …` to Firebase `onCall` functions. Firebase validates that header as a **Firebase ID token**; a Supabase JWT (signed with the Supabase project secret) will never verify. All five callables begin with `if (!request.auth || !request.auth.uid) throw HttpsError("unauthenticated")`.

**So C1 and C2 are independent breaks on the same path.** Fixing the project ID alone changes a 404 into a 401.

Affected features: Gemini cloud diagnosis fallback, Khaya TTS, Khaya ASR, Khaya translation, outbreak verification.

### C3 — Outbreak push notifications can never fire [CONFIRMED]

`functions/index.js` → `onOutbreakReportCreatedOrUpdated` is an `onDocumentWritten` trigger on the **Firestore** path `outbreak_reports/{reportId}`. The app writes outbreak reports to the **Supabase** `outbreaks` table. The trigger has no data source and will never execute.

`PushNotificationService` subscribes every device to the `outbreak_alerts` topic that nothing publishes to.

**Mitigating:** `lib/core/utils/outbreak_alert_service.dart` polls Supabase from a WorkManager periodic task and fires a *local* notification for reports within 25 km. **That path works.** So the feature is degraded (Android-only, ≥15 min latency), not absent.

### C4 — "Delete Account" does not delete the account [CONFIRMED]

`SupabaseAuthService.deleteAccount()` (line ~276) only calls `signOut()`. The `functions/index.js` `onUserDeleted` cascade is a **Firebase Auth** trigger that will never fire for a Supabase user.

Consequences:
- The row in `auth.users` survives forever. The user can sign back in to an emptied account.
- `SupabaseDatabaseService.deleteUserData()` skips `outbreaks`, `training_candidates`, and `reported_posts`, so `user_id` persists in those tables.

This is a **Google Play data-deletion policy violation** and a GDPR problem, not just a bug.

### C5 — Cross-user data corruption in scan sync [CONFIRMED]

`ScanCropUseCase.saveResolvedScan()` calls:
```dart
_communityRepository.upsertScan(savedDetection.id.toString(), savedDetection.toMap());
```
`savedDetection.id` is the **local SQLite `AUTOINCREMENT` integer**. `SupabaseDatabaseService.upsertScan` writes it as the `scans.id` primary key.

**Every user's first scan is `id = "1"`.** Users overwrite each other's rows.

Same method, two more silent breaks:
- `'disease_name': scanData['diseaseName'] ?? scanData['disease']` — `DetectionResult.toMap()` emits `diseaseLabel` and `displayName`. Neither key exists → `disease_name` is **always NULL**.
- `'image_url': … ?? scanData['imagePath']` — stores a local device file path in a URL column.

The `data` jsonb blob preserves everything, and nothing in the app reads `scans` back, which is why this went unnoticed.

### C6 — No security rules exist, anywhere [CONFIRMED]

- `firebase.json` references `firestore.rules`, `firestore.indexes.json`, `storage.rules`. **None of the three files are in the repo.** `firebase deploy` fails.
- There is **no SQL file, no migration, and no RLS policy** checked in for Supabase.
- `AppSecrets` hardcodes the Supabase project URL and anon key.

Without RLS, that anon key grants full read/write on `profiles`, `scans`, `posts`, `outbreaks`, `treatments`, `feedback`, `missing_crops`, `expert_requests`, `reported_posts`, `training_candidates`.

**This is the single largest live exposure. Treat it as priority one.**

`test/security/firestore_rules_validation_test.dart` is a Dart class called `SecurityRulesEvaluator` that reimplements rules and then tests itself. It is green and validates nothing, for a database the app no longer uses.

### C7 — Google Sign-In is broken by an OAuth project mismatch [CONFIRMED — matches user's screenshots]

Screenshots show:
- Register: `PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10:, null, null)`
- Login: "Google sign-in configuration error. Please ensure SHA-1 fingerprint and OAuth Client IDs match."

`ApiException: 10` is `DEVELOPER_ERROR` — the calling app's package name + signing certificate SHA-1 do not match any registered OAuth client, **or** the `serverClientId` belongs to a different project.

In `lib/core/config/app_secrets.dart`:
```dart
static const defaultGoogleServerClientId =
    '859024066310-53gprmgbm38q8r84mpqcn74aqapritfu.apps.googleusercontent.com';
static const defaultGoogleIosClientId =
    '395929072901-k4ou5rm47r7ikaa30bsqtu3rikft9tgs.apps.googleusercontent.com';
```
In `lib/firebase_options.dart`, `messagingSenderId` is **`395929072901`**, and the web `appId` cites a third number, **`229730630873`**.

**Three different Google Cloud project numbers are in play.** The Android `serverClientId` (`859024066310`) is not the project that owns the app. See §8 for the full fix.

---

## 3. SERIOUS defects

### S1 — Outbreak voting is client-side read-modify-write [CONFIRMED]

`CloudFunctionsService.verifyOutbreak` — the "trusted server transaction that prevents forging and race conditions" — is **never called from anywhere in `lib/`**.

The live path is `SupabaseDatabaseService.verifyOutbreak` (line ~205): SELECT the row, mutate the `verified_by` / `refuted_by` arrays in Dart, UPDATE the whole array back. Two concurrent votes silently drop each other, and with no RLS a client can `PATCH` the arrays to arbitrary values.

### S2 — Gemini and Khaya keys are resolvable from Remote Config [CONFIRMED]

`AppSecrets.geminiApiKey` and `AppSecrets.ghanaNlpSubscriptionKey` fall back to Firebase Remote Config, and the direct-HTTP fallbacks in `GhanaNlpService` are **not** debug-gated. Remote Config is readable by anyone holding the app's Firebase config, so this effectively publishes both keys.

The file's own header comment says secrets must never reach the client. The `--dart-define` path honours that; the Remote Config path does not.

### S3 — `topCandidates` is never persisted [CONFIRMED]

`DetectionResult.topCandidates` is populated at inference and consumed by `LowConfidenceScreen`, but `toMap()` drops it and the `detections` table has no column for it. Reopen any scan from History and the alternative candidates are gone.

### S4 — Local-language support is 89% English [CONFIRMED]

Across `l10n/app_tw.arb`, `app_ee.arb`, `app_dag.arb`: **456 of 515 keys are byte-identical to English**, and identical to each other. Only 59 keys differ.

`l10n/TRANSLATIONS.md` is honest about the scaffold status, and its warning against machine-translating dosage instructions is correct and must be respected. Runtime is safe — the generated Dart carries English values, so nothing crashes.

---

## 4. MODERATE issues

| ID | Issue | Evidence |
|----|-------|----------|
| M1 | Disease Library shows **149** diseases; the model knows **51**. `DiseaseDatabase.getAllDiseases()` returns everything including Cocoa, Cowpea, Oil Palm, Millet and the legacy PlantVillage set (Apple, Grape, Blueberry). A farmer browses Cocoa Swollen Shoot, scans a cocoa leaf, and gets a confident *maize* label — the model has no cocoa class. | [CONFIRMED] All 51 labels do have entries; the extra 98 are the problem. |
| M2 | Model accuracy is **63.9% validation / 62.7% field** (`assets/model_metadata.json`). With a 0.60 threshold, heavy traffic goes through the low-confidence escalation path — which is exactly the path broken by C1/C2. | [CONFIRMED] Not a bug; a risk. |
| M3 | `LogoutUseCase` is registered in DI but **never resolved**. `ProfileScreen` → `ProfileProvider` → repository directly, bypassing the use-case layer every other flow respects. | [CONFIRMED] |
| M4 | `ClassifierHealthService` is registered, never read, never written. The classifier's `_engineAvailable = false` state has no UI surface. | [CONFIRMED] |
| M5 | Android manifest has no `default_notification_channel_id` or `default_notification_icon` meta-data for FCM. Android 8+ uses a generic icon and the default channel. | [CONFIRMED] |
| M6 | App Link host `cropguardai.app` requires a live `/.well-known/assetlinks.json`. `docs/assetlinks.json` exists in the repo; deployment unverified. If it isn't live, password-reset emails open a browser instead of the app. | [VERIFY] |
| M7 | `assets/cropguard_plant_disease_verified.tflite` is a symlink, not in `pubspec.yaml` assets, referenced by nothing. Symlinks break on Windows checkouts. | [CONFIRMED] |
| M8 | `AppRouter.router` is a `static final` that resolves `sl<AnalyticsService>()`, `sl<AppLockController>()`, `sl<AuthStateNotifier>()` at first access. If `setupServiceLocator()` throws (it's wrapped in a `try/catch` in `main.dart`), first router access throws too. | [CONFIRMED] Low likelihood, high blast radius. |

---

## 5. 🚦 DECISION GATES — ask the user, do not choose

Stop and get an answer to each of these before writing migration code.

### 🚦 D1 — Push notifications

**Supabase has no push service.** "Deprecate Firebase completely" has a hard edge here. Three options:

| Option | Firebase remaining | Effort | Notes |
|---|---|---|---|
| **A. Drop push entirely** | None | Lowest | Rely on the existing `OutbreakAlertService` WorkManager polling (already works) + Supabase Realtime while foregrounded. Loses iOS background alerts and instant delivery. |
| **B. Keep `firebase_messaging` as pure transport** | `firebase_core` + `firebase_messaging` only | Low | FCM is the only route to Android push and handles APNs relay for iOS. You'd trigger it from a Supabase Edge Function calling the FCM HTTP v1 API with a service account. Pragmatic; "Firebase-free backend, FCM as a delivery pipe." |
| **C. OneSignal / Expo-style third party** | None | Medium | Genuinely zero Firebase, but adds a vendor and an SDK. |

**My recommendation for a final-year project: Option A.** The local polling path already works, it removes Firebase 100%, and it is defensible in a viva ("we chose an offline-first polling design appropriate to intermittent rural connectivity"). Option B is the right answer for a commercial launch.

**Do not proceed past Phase 4 without an answer.**

### 🚦 D2 — Crashlytics replacement

Options: **Sentry** (`sentry_flutter`, generous free tier, drop-in), **Supabase table** (`crash_reports`, DIY, no symbolication), or **none** (debug logging only). Sentry is the low-effort correct answer. Ask.

### 🚦 D3 — Analytics replacement

`AnalyticsService` has ~20 typed event methods. Options: **PostHog**, a **Supabase `analytics_events` table** (trivially easy, and honest for a research project since the data stays in your own DB), or **remove**. Ask.

### 🚦 D4 — Gemini fallback: keep or drop?

The low-confidence path calls Gemini via Cloud Functions. Migrating it means writing a Supabase Edge Function holding `GEMINI_API_KEY` as a secret. Ask whether the project still wants a cloud AI fallback at all, given M2 (a 63% model leans on it heavily) versus the cost/complexity.

### 🚦 D5 — Is there production data in Supabase or Firebase today?

If **yes**, every SQL change in Phase 2 needs a backfill plan and the `scans.id` change (C5) needs a data migration. If **no** (likely for a student project), you can drop and recreate freely. **Ask before running any destructive SQL.**

---

## 6. PHASE 0 — Baseline (do this first, always)

```bash
flutter --version
flutter pub get
flutter analyze --no-fatal-infos 2>&1 | tee /tmp/baseline_analyze.txt
flutter test 2>&1 | tee /tmp/baseline_test.txt
```

Record: number of analyzer issues, number of passing/failing tests. **This is your regression baseline.** Report it to the user before continuing.

Also confirm and report:
- Resolved versions from `pubspec.lock` for: `supabase_flutter`, `google_sign_in`, `go_router`, `firebase_core`.
- Whether `android/app/google-services.json` exists locally (it is gitignored; the build will fail without it while Firebase remains).
- Which Supabase project the user actually controls (the hardcoded `xrjltpchcssztitswjvm` may not be theirs).

**Then create a branch:** `git checkout -b fix/audit-and-supabase-migration`

---

## 7. PHASE 1 — Emergency correctness fixes

These are self-contained, valuable regardless of the migration decision, and safe to ship first.

### 1.1 Fix the Cloud Functions project ID (C1)

`lib/data/remote/cloud_functions_service.dart`: change the default `projectId` from `'cropguard-ai'` to `'cropguard-6ada8'`.

Better: read it from `AppSecrets` with a `--dart-define` override rather than hardcoding, so it can never drift from `firebase_options.dart` again.

Then **fix the test that hid this**: `test/data/remote/cloud_functions_service_test.dart` should include a case asserting the *default-constructed* service builds a URL containing the real project ID. A test that only exercises injected values cannot catch a bad default.

> Note: this alone does not make Cloud Functions work (C2 still applies). It is here because it is a one-line correctness fix and a prerequisite for any interim debugging.

### 1.2 Fix scan ID collision (C5) — **highest-value fix in this phase**

Replace the local integer ID used as the remote primary key with a UUID. `uuid: ^4.5.1` is already a dependency.

Approach:
1. Add a `remoteId TEXT` column to the `detections` table. Bump `_dbVersion` 17 → 18 and add an `if (oldVersion < 18)` migration using the existing `_addColumnIfMissing` helper.
2. Generate `remoteId` with `const Uuid().v4()` at insert time in `DetectionRepositoryImpl.saveDetection` (or in `DetectionResult`'s construction — your call, but do it in exactly one place).
3. Backfill: in the same migration, `UPDATE detections SET remoteId = <uuid> WHERE remoteId IS NULL` — SQLite cannot generate UUIDs, so either backfill in Dart after the migration, or generate lazily on first sync. **Lazy generation on first sync is simpler and safer.**
4. `ScanCropUseCase.saveResolvedScan` passes `savedDetection.remoteId` (not `id.toString()`) to `upsertScan`.
5. Keep `markDetectionSynced(int)` working on the local integer `id` — do not change local keys.

**Test:** add a case in `test/data/repositories/detection_repository_impl_test.dart` asserting two detections saved on a fresh DB have distinct, non-empty `remoteId` values.

### 1.3 Fix `upsertScan` field mapping (C5)

In `SupabaseDatabaseService.upsertScan` and `uploadScan`, the lookups must match the keys `DetectionResult.toMap()` actually emits:

- `disease_name` ← `scanData['displayName'] ?? scanData['diseaseLabel']`
- `crop_type` ← `scanData['cropType']` (already correct)
- `image_url` ← only set it when the value is a real `http(s)` URL. A local path (`imagePath`) must **not** go into a URL column — either upload the image via `ImageUploadService` first and store the returned URL, or leave `image_url` NULL and keep the local path inside the `data` jsonb.

🚦 Ask the user whether scan images should be uploaded to Supabase Storage at all — it has real bandwidth cost for rural users and may not be wanted.

### 1.4 Persist `topCandidates` (S3)

Add a `topCandidates TEXT` column in the same v18 migration. Serialize as JSON (`jsonEncode` of `[{"label":…,"confidence":…}, …]`), not the `||` delimiter used for `treatments` — labels are safe but confidences are doubles and deserve a real format.

Update `DetectionResult.toMap()` / `.fromMap()` symmetrically. Add a round-trip test in `test/domain/models/detection_result_test.dart`.

### 1.5 Delete the security theatre (C6, partial)

`test/security/firestore_rules_validation_test.dart` tests a Dart reimplementation of rules that do not exist, for a database the app no longer uses. **Delete it** once Phase 2 lands real RLS with real tests. Do not delete it before then — ask first, and replace rather than remove.

**Gate:** run §11. Commit as `fix: scan id collision, field mapping, topCandidates persistence`.

---

## 8. PHASE 2 — Fix Google Sign-In (C7)

This is mostly **console configuration**, not code. Do the code part; give the user a precise checklist for the console part.

### 8.1 Diagnose first

Have the user run and report:
```bash
cd android && ./gradlew signingReport
```
Capture the **SHA-1 and SHA-256** for both the `debug` and `release` variants.

### 8.2 Establish one project

All of these must live in **one** Google Cloud project — the one linked to the Supabase Google provider:

1. An **Android** OAuth 2.0 Client ID with package name `com.cropguard.ai.app` and **both** SHA-1 fingerprints (debug + release, and the Play App Signing SHA-1 if using Play Signing).
2. A **Web** OAuth 2.0 Client ID. Its client ID is what goes in `serverClientId`, and its **client secret** goes into Supabase.
3. An **iOS** OAuth 2.0 Client ID with bundle ID `com.cropguard.ai.app`.

### 8.3 Wire Supabase

Supabase Dashboard → Authentication → Providers → Google:
- Enable it.
- **Client ID / Secret** = the **Web** client from 8.2.2.
- **Authorized Client IDs** = add the **Android** and **iOS** client IDs. This is the step people miss; without it `signInWithIdToken` rejects the native token.

### 8.4 Code changes

In `lib/core/config/app_secrets.dart`, replace the two hardcoded defaults. Do not hardcode the new ones either — make them **required** via `--dart-define` with an empty default, and fail loudly with a clear message when missing rather than silently attempting a broken sign-in.

Add to `.env.example`:
```
GOOGLE_SERVER_CLIENT_ID=      # Web OAuth client ID (same project as Supabase Google provider)
GOOGLE_IOS_CLIENT_ID=         # iOS OAuth client ID
```

In `SupabaseAuthService._createGoogleSignIn()`, add a guard: if `serverClientId` is empty, throw an `AuthFailure` with a message naming the missing dart-define. A clear config error beats `ApiException: 10`.

**Also improve the error surfacing.** The current login screen shows the raw `PlatformException` string (see screenshot 2). Map `ApiException: 10` / `sign_in_failed` to a localized, human message and log the raw string via `AppLogger` only.

### 8.5 iOS

Confirm `ios/Runner/Info.plist` has the reversed-client-ID URL scheme for the iOS OAuth client. `GoogleService-Info.plist` is gitignored and absent — the user must supply it while Firebase remains; after full migration, only the URL scheme matters.

**Gate:** the user must be able to complete Google sign-in on a real Android device before you continue.

---

## 9. PHASE 3 — Supabase backend foundation (fixes C6, S1)

### 9.1 Create a migrations directory

```
supabase/
  migrations/
    0001_schema.sql
    0002_rls.sql
    0003_storage.sql
    0004_functions.sql
  functions/            # Edge Functions, Phase 4
  config.toml
```

**This must be checked into git.** The absence of any schema-as-code is one of the most serious findings — right now the database shape exists only in one person's dashboard.

### 9.2 Derive the schema from the code, not from this document

The tables and columns below are what I extracted from `lib/data/remote/supabase_database_service.dart`. **[VERIFY] every one against the live database** (`select * from information_schema.columns`) before writing migrations — the live DB is the source of truth for what already exists.

Tables in use: `profiles`, `scans`, `posts`, `outbreaks`, `treatments`, `feedback`, `missing_crops`, `expert_requests`, `reported_posts`, `training_candidates`.

Observed columns:

- **profiles**: `id` (uuid, = `auth.users.id`), `updated_at`, plus whatever `ProfileRepositoryImpl` writes — **[VERIFY]**
- **scans**: `id`, `user_id`, `disease_name`, `crop_type`, `confidence`, `image_url`, `data` (jsonb), `created_at`
- **posts**: `id`, `user_id`, `author_name`, `crop_type`, `title`, `content`, `image_url`, `created_at`
- **outbreaks**: `id`, `user_id`, `disease_name`, `crop_type`, `confidence`, `latitude`, `longitude`, `district`, `region`, `verified_by` (text[]), `refuted_by` (text[]), `created_at`
- **treatments**: `id`, `user_id`, `completed`, + free-form from `TreatmentTrackerProvider` — **[VERIFY]**
- **feedback**: `id`, `user_id`, `detection_id`, `original_label`, `corrected_label`, `image_path`, `confidence`, `model_version`
- **missing_crops**: `id`, `user_id`, `suggested_crop`, `observed_symptoms`, `image_path`, `status`
- **expert_requests**: `id`, `user_id`, `detection_id`, `message`, `disease_name`, `status`
- **reported_posts**: `id`, `post_id`, `reporter_id`, `user_id`, `reason`, `status`
- **training_candidates**: free-form map — **[VERIFY]**

Note `scans.id` becomes **uuid/text** after Phase 1.2 (🚦 see D5 — if live data exists, this needs a migration, not an `ALTER TYPE`).

### 9.3 Write the RLS policies — the actual priority-one fix

Enable RLS on **every** table. Nothing is public by default.

Policy shape by table:

| Table | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| `profiles` | own row, plus a **public view** exposing only `id` + display name for post authorship | own row | own row | own row |
| `scans` | `user_id = auth.uid()` | own | own | own |
| `treatments` | own | own | own | own |
| `feedback` | own | own | none | none |
| `missing_crops` | own | own | none | none |
| `expert_requests` | own | own | none | none |
| `training_candidates` | none (service role only) | own | none | none |
| `posts` | all authenticated | own (`user_id = auth.uid()`) | own | own |
| `reported_posts` | none (service role only) | authenticated, `reporter_id = auth.uid()` | none | none |
| `outbreaks` | all authenticated | own | **NONE — see below** | own |

**Critical:** `outbreaks` must have **no client UPDATE policy.** Voting goes exclusively through the RPC in 9.4. This is what closes S1.

Include column-level validation in the INSERT policies where Postgres allows it, and enforce the rest with `CHECK` constraints on the table: `confidence between 0 and 1`, `latitude between -90 and 90`, `longitude between -180 and 180`, `length(content) <= 500`, etc. The Dart file `test/security/firestore_rules_validation_test.dart` documents the intended validation rules — **mine it for constraints before deleting it.**

### 9.4 Atomic outbreak voting (fixes S1)

Replace the client read-modify-write with a `SECURITY DEFINER` Postgres function:

```sql
create or replace function public.verify_outbreak(report_id uuid, confirm boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare uid text := auth.uid()::text;
begin
  if uid is null then
    raise exception 'unauthenticated';
  end if;
  update outbreaks set
    verified_by = case when confirm
      then array(select distinct unnest(verified_by || array[uid]))
      else array_remove(verified_by, uid) end,
    refuted_by  = case when confirm
      then array_remove(refuted_by, uid)
      else array(select distinct unnest(refuted_by || array[uid])) end
  where id = report_id;
  if not found then
    raise exception 'report not found';
  end if;
end;
$$;

revoke all on function public.verify_outbreak(uuid, boolean) from public;
grant execute on function public.verify_outbreak(uuid, boolean) to authenticated;
```

**[VERIFY]** the `outbreaks.id` type (uuid vs bigint vs text) and adjust. **[VERIFY]** that `verified_by`/`refuted_by` are `text[]` and not `jsonb` — my read of the Dart says `List<String>`, which maps to either.

Then change `SupabaseDatabaseService.verifyOutbreak` to a single `_client.rpc('verify_outbreak', params: {...})` call, preserving the existing retry/timeout wrapper. Delete the read-modify-write.

**Test:** add a test asserting the repository calls the RPC and no longer issues a bare `update` on `outbreaks`.

### 9.5 Storage policies

Bucket `cropguard-media` (from `SupabaseStorageService.defaultBucket`). Paths observed: `community_posts/<userId>/<ts>.<ext>` and a profile-image path — **[VERIFY]**.

Policies: authenticated users may INSERT/UPDATE/DELETE only under a prefix matching their own `auth.uid()`. Public SELECT only if community images are genuinely meant to be public (they are — `getPublicUrl` is used). Set a size limit and an allowed MIME list on the bucket to match `ImageUploadService`'s 10 MB / jpg-png-webp rules.

**Gate:** RLS on, policies applied, and a manual check that an anon key cannot read another user's `scans`. Commit as `feat: supabase schema, rls, and atomic outbreak voting`.

---

## 10. PHASE 4 — Migrate the backend off Firebase

### 10.1 Port the five callables to Supabase Edge Functions (fixes C1, C2)

Edge Functions verify Supabase JWTs natively, which is exactly what the client already sends. This is the smaller change and it removes the split-brain permanently.

Create under `supabase/functions/`:

| Firebase callable | Edge Function | Secret needed |
|---|---|---|
| `verifyOutbreak` | **Do not port** — replaced by the RPC in 9.4 | — |
| `analyzeCropWithGemini` | `analyze-crop` | `GEMINI_API_KEY` (🚦 D4) |
| `synthesizeGhanaNlp` | `khaya-tts` | `GHANA_NLP_SUBSCRIPTION_KEY` |
| `transcribeGhanaNlp` | `khaya-asr` | `GHANA_NLP_SUBSCRIPTION_KEY` |
| `translateGhanaNlp` | `khaya-translate` | `GHANA_NLP_SUBSCRIPTION_KEY` |

For each function:
- Verify the JWT (`Authorization: Bearer <supabase access token>`) with `supabase.auth.getUser(token)`; reject with 401 when absent or invalid.
- Read the key from `Deno.env.get(...)` — set via `supabase secrets set`. **Never** from the request.
- Port `sanitizeServerLog()` from `functions/index.js` verbatim. It redacts API keys and base64 blobs from logs and it is genuinely good; do not lose it.
- Preserve the Khaya API version constants: **ASR v3, TTS v2, Translation v2**. `KhayaApiVersions` in `ghana_nlp_service.dart` and the comments in `functions/index.js` both stress that v1/v2 ASR and v1 TTS are deprecated. Keep the constants as the single source of truth in both client and function.
- Add per-user rate limiting (a `rate_limits` table or an in-function counter). The Firebase versions had none; Gemini and Khaya both cost money per call.

Then rewrite `lib/data/remote/cloud_functions_service.dart`:
- Rename to something honest — `EdgeFunctionsService` — and update the DI registration and all call sites.
- Replace the hand-rolled `http.post` to `cloudfunctions.net` with `Supabase.instance.client.functions.invoke('<name>', body: {...})`. That handles auth headers for you.
- **Keep** the existing `RetryUtils.retry` wrapper, timeouts, and `Failure` mapping. Do not simplify these away.
- Drop the `FirebaseAppCheck` header.

Update `test/data/remote/cloud_functions_service_test.dart` accordingly, and add the default-value test from 7.1.

### 10.2 Kill the client-side key fallbacks (fixes S2)

Once the Edge Functions work, in `GhanaNlpService`:
- Gate the direct-HTTP fallback behind `kDebugMode`, **or** remove it entirely.
- Remove `ghanaNlpSubscriptionKey` and `geminiApiKey` from Remote Config resolution in `AppSecrets` (they're leaving with Remote Config anyway — see 10.3).

The client should have **no path** to either key in a release build. Verify with:
```bash
flutter build apk --release
unzip -p build/app/outputs/flutter-apk/app-release.apk | strings | grep -i "<key-prefix>"
```

### 10.3 Replace Firebase Remote Config

Remote Config is used in four files [CONFIRMED]:
- `lib/core/utils/app_bootstrap.dart` — keys: `ghana_nlp_subscription_key`, `gemini_api_key`, `cloudinary_cloud_name`, `cloudinary_upload_preset`, `password_reset_continue_url`, `android_package_name`, `ios_bundle_id`
- `lib/core/utils/version_check_service.dart` — `min_required_app_version`, `latest_model_version`
- `lib/core/utils/ghana_seasonal_tip.dart` — `rainy_major_start/end`, `rainy_minor_start/end`, `rainy_major_msg`, `rainy_minor_msg`

Replace with a Supabase `app_config` table: `key text primary key, value text, updated_at timestamptz`. RLS: **public SELECT, no client write.** Fetch once at startup into the same in-memory cache `AppSecrets` already uses, so the setter API (`setGhanaNlpSubscriptionKey`, `setOsmConfig`, etc.) stays unchanged and the blast radius stays small.

**The two secret keys do not move to `app_config`.** They stay server-side in Edge Function secrets. Only non-secret config migrates.

Keep the existing behaviour where this runs **after** the first frame (`AppBootstrap.runStartupTasks()` is already `unawaited` post-`runApp` — that's deliberate and correct; preserve it).

### 10.4 Replace Crashlytics (🚦 D2)

Used in: `main.dart`, `app_logger.dart`, `crop_disease_classifier.dart`, `analytics_service.dart` [CONFIRMED].

`AppLogger` already has an `isCrashlyticsEnabled` gate and `DiagnosticSanitizer` already scrubs errors and stack traces before reporting. **Keep both.** Swap only the sink. If Sentry: `Sentry.captureException(cleanErr, stackTrace: cleanStack)`.

The `runZonedGuarded` + `FlutterError.onError` + `PlatformDispatcher.instance.onError` structure in `main.dart` is correct — change what it calls, not its shape.

### 10.5 Replace Analytics (🚦 D3)

`AnalyticsService` has a clean typed surface (~20 `logX()` methods) and a `setEnabled` consent gate that `main.dart` honours from `SharedPreferences`. **Keep the whole public API.** Replace only `_log()`'s implementation and `observer`.

If going the Supabase route: an `analytics_events` table (`user_id`, `event`, `params jsonb`, `created_at`), insert-only RLS. For `observer`, write a small `NavigatorObserver` subclass — `go_router` takes any `NavigatorObserver`, so `AppRouter`'s `observers: [...]` line needs no structural change.

**Do not lose the consent gate.** Analytics defaults to `false` (`prefs.getBool('analytics_enabled') ?? false`) — that's a deliberate privacy choice.

### 10.6 App Check

`firebase_app_check` is used only to attach an `X-Firebase-AppCheck` header in `CloudFunctionsService`. Once that class becomes `EdgeFunctionsService`, App Check has no purpose. Remove it. The replacement control is RLS + JWT verification in Edge Functions, plus per-user rate limiting from 10.1.

### 10.7 Push (🚦 D1 — depends on the decision)

**If Option A (drop push):**
- Delete `lib/core/utils/push_notification_service.dart` and its test.
- Remove the `syncFcmToken` listener in `service_locator.dart`.
- Remove FCM token storage from `SupabaseDatabaseService` — **[VERIFY]** which table holds it.
- Keep `flutter_local_notifications`, `NotificationHelper`, `BackgroundTaskHelper`, and `OutbreakAlertService` **entirely intact** — this is now the only alert path and it works.
- Consider shortening the WorkManager period and adding a Supabase Realtime subscription on `outbreaks` for foreground immediacy.

**If Option B (keep FCM as transport):**
- Keep `firebase_core` + `firebase_messaging` only.
- Replace the dead Firestore trigger with a Postgres trigger on `outbreaks` → `pg_net`/webhook → Edge Function → FCM HTTP v1 API (service-account JWT, key held as an Edge Function secret).
- Port the duplicate-suppression logic from `onOutbreakReportCreatedOrUpdated` (the `previouslyNotified` / `previousConfidence` / `previousVerifiedCount` checks) — it's careful work and worth keeping.
- Add the missing manifest meta-data from M5.

### 10.8 Proper account deletion (fixes C4)

Create an Edge Function `delete-account`:
1. Verify the caller's JWT → get `uid`.
2. Delete rows across **all ten tables**, including the three the current code misses: `outbreaks`, `training_candidates`, `reported_posts`. 🚦 Ask whether outbreak reports should be **deleted** or **anonymized** — the Firebase version anonymized them to preserve the community map, which is arguably the better product behaviour.
3. Delete the user's Storage objects under their prefix.
4. Call `supabaseAdmin.auth.admin.deleteUser(uid)` using the **service-role key** (Edge Function secret only — this key must never touch the client).
5. Return success; client signs out and routes to `/login`.

Alternative: a `SECURITY DEFINER` Postgres function plus a scheduled job. The Edge Function is cleaner because it can also delete Storage objects.

Then update `SupabaseAuthService.deleteAccount()` to invoke it, and `SettingsProvider.deleteAccount()` to keep its existing reauthentication flow (which is correct) and its existing `UiMessage` error mapping.

**Test it end to end**: create a user, scan, post, report an outbreak, delete the account, then confirm (a) `auth.users` has no row and (b) sign-in with the same credentials fails.

### 10.9 Strip Firebase

Only after everything above is green:
- Remove from `pubspec.yaml`: `firebase_core`, `firebase_remote_config`, `firebase_app_check`, `firebase_crashlytics`, `firebase_analytics`, and `firebase_messaging` (unless D1 = Option B).
- Delete `lib/firebase_options.dart`.
- Delete the `functions/` directory (**archive it in git history first** — `git rm` keeps it recoverable; do not just `rm`).
- Delete `firebase.json` and `.firebaserc`, or strip them down to nothing but what Option B needs.
- Remove the Google Services Gradle plugin from `android/build.gradle.kts` and `android/app/build.gradle.kts`.
- Remove Firebase pods from `ios/Podfile`, then `pod install`.
- Remove the `google-services.json` / `GoogleService-Info.plist` lines from `.gitignore` if fully gone.
- **`google_sign_in` stays.** It is a Google Identity dependency, not Firebase, and Supabase's `signInWithIdToken` needs it.
- Update `README.md`, `SYSTEM_ARCHITECTURE.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, `docs/APP_CHECK.md`, `docs/FIRESTORE_DEPLOY.md`, and the CI workflow. **Several of these describe a Firebase architecture that will no longer exist** — leaving them is how the next person reintroduces the split.

**Gate:** `grep -ri "firebase\|firestore" lib/ android/ ios/ --include="*.dart" --include="*.kts" --include="*.gradle"` returns only intentional hits. Full suite green. App builds and runs on a real device.

---

## 11. PHASE 5 — Product-level fixes

### 11.1 Filter the Disease Library (M1)

`DiseaseDatabase.getAllDiseases()` returns 149 entries; the model knows 51. Add:
```dart
static Set<String> get modelSupportedLabels => /* parsed from assets/labels.txt */;
static List<DiseaseInfoEntry> getSupportedDiseases() => ...;
```
Use the filtered list in `DiseaseLibraryScreen` by default. 🚦 Ask whether the remaining 98 should be **hidden** or shown in a clearly-labelled "Reference only — not yet detectable by the scanner" section. Hiding is safer; a labelled section is more useful. Either is defensible; guessing is not.

The `disease_info.dart` header comment says the extras are "documented future expansion targets" — that intent is fine, but the UI must not present them as scannable.

### 11.2 Surface classifier health (M4)

Either wire `ClassifierHealthService` into `ClassifierRepositoryImpl` (it already checks `result.engineUnavailable` at two sites) and show a banner when the engine is down, **or** delete the service. Do not leave it registered and inert. 🚦 Ask.

### 11.3 Fix the use-case bypass (M3)

`ProfileScreen` → `ProfileProvider` → repository, skipping `LogoutUseCase`. Either route logout through the use case (consistent with every other flow) or delete `LogoutUseCase`. Consistency matters here because this is a graded architecture project. 🚦 Ask, and recommend routing through the use case.

### 11.4 Harden router initialization (M8)

In `main.dart`, `setupServiceLocator()` failure is caught and logged, then `runApp` proceeds and `AppRouter.router` immediately resolves three services from `sl`. Make DI failure fatal-with-a-message (show an error screen) rather than proceeding into a guaranteed crash.

### 11.5 Housekeeping

- Delete the `assets/cropguard_plant_disease_verified.tflite` symlink (M7) — confirm nothing references it first.
- Add FCM manifest meta-data (M5) if D1 = Option B.
- Confirm `docs/assetlinks.json` is actually served at `https://cropguardai.app/.well-known/assetlinks.json` (M6). If the domain isn't live, either register it or change the deep-link strategy to a custom scheme, and update `docs/PASSWORD_RESET_DEEPLINK.md`.

### 11.6 Translations (S4) — **do not automate**

`l10n/TRANSLATIONS.md` explicitly forbids machine translation, and it is right: a mistranslated pesticide dosage can cause crop loss or injury.

**Your job is not to translate.** It is to:
1. Generate a coverage report — for each of `tw`, `ee`, `dag`, list which of the 515 keys are still English.
2. Prioritize: safety-critical strings first (`safetyPrecautions`, dosage, PPE, treatment instructions), then navigation, then the rest.
3. Produce a clean handoff spreadsheet/CSV for a human agricultural-extension speaker.
4. Flag in the UI (or in `TRANSLATIONS.md`) which locales are incomplete.

Update `TRANSLATIONS.md`, which currently says the files contain "only `@@locale`" — 59 keys are in fact translated.

---

## 12. Verification gate — run after EVERY phase

```bash
flutter analyze --no-fatal-infos          # must not regress vs baseline
flutter test                              # must not regress vs baseline
flutter build apk --debug                 # must succeed
```

Plus, per phase:

- [ ] No new `TODO`, `FIXME`, or commented-out code introduced. (The repo currently has **zero** — [CONFIRMED]. Keep it that way.)
- [ ] Every network call still has its timeout, retry, and offline-queue fallback.
- [ ] No secret added to any file that git tracks.
- [ ] Any local DB schema change has a matching `_onUpgrade` branch and a migration test in `test/data/local/database_migration_test.dart`.
- [ ] Any new Supabase table has RLS enabled and policies written **in the same commit**.
- [ ] Changed behaviour has a test. Changed *broken* behaviour has a test that would have failed before.

**Manual smoke test on a real Android device before declaring any phase done:**
register → verify email → login → Google sign-in → scan a leaf → view result → view history → reopen the result → report an outbreak → verify someone's outbreak → post to community → change language → toggle dark mode → enable biometric lock → background and resume → go airplane-mode and scan → come back online and confirm the queue drains → delete the account.

---

## 13. Suggested order and rough sizing

| Phase | Content | Size | Blocking? |
|---|---|---|---|
| 0 | Baseline + branch | 30 min | — |
| 1 | Emergency fixes (§7) | half a day | No |
| 2 | Google Sign-In (§8) | half a day + console work | No |
| 3 | Schema + RLS + voting RPC (§9) | 1–2 days | **Yes — do this before any public use** |
| 4 | Edge Functions + Firebase strip (§10) | 3–5 days | Needs 🚦 D1–D5 |
| 5 | Product fixes (§11) | 1–2 days | No |

If time is short, **Phase 3 alone** delivers the most value: it closes the open database and fixes vote forging. Phase 1 is the cheapest real win. Phase 4 is the big one and the one the user explicitly asked for.

---

## 14. What is already good — do not break it

Worth stating, because it is most of the codebase and a refactor can easily destroy it:

- The DI graph is clean. I cross-checked **every** `sl<T>()` call site against every registration: **zero unregistered resolutions**.
- **Zero** `TODO`/`FIXME`/`UnimplementedError`/empty `onPressed` handlers in `lib/`.
- The classifier enforces real tensor-shape, dtype, and label-count contracts at load time and fails loudly with typed exceptions (`ModelContractException`, `LabelContractException`, …) rather than degrading silently. All 51 labels have `DiseaseInfoEntry` records.
- Image preprocessing runs in a `compute()` isolate — no UI jank.
- The TFLite interpreter has a three-tier fallback (hardware delegate → explicit CPU → bare buffer).
- `DatabaseHelper` uses a shared `Completer` to prevent double-init races, and has one migration block per version bump.
- `PendingSyncQueue` with a connectivity-triggered drain is genuinely well-built offline-first work.
- The camera stream is stopped before `takePicture()` and restarted in `finally` — a bug most Flutter apps ship with.
- `DiagnosticSanitizer` scrubs errors and stack traces before they reach any crash reporter, and `sanitizeServerLog()` does the same server-side.
- 92 test files with real coverage of use cases, repositories, providers, and migrations.

**Preserve all of it.** If a migration step would remove one of these properties, stop and flag it instead.

---

## 15. Reporting back

After each phase, report:
1. What changed (files + one line each).
2. Analyzer/test delta vs. baseline.
3. Anything marked `[VERIFY]` that turned out different from this brief — **this matters; the brief is a static read, the running system is the truth.**
4. Any 🚦 decision you are now blocked on.
5. Anything you found that isn't in this document.

Do not report a phase as complete if the gate in §12 is red.
