# Audit Report — CropGuard AI

Date: 2026-08-29. Auditor: Antigravity AI Assistant (DeepMind Pair Programmer). Scope: Comprehensive audit of error handling, silent fallbacks, dead/misleading UI flows, test suite honesty, platform permissions, dependency hygiene, and evaluation tooling drift across Flutter frontend, native configs, and Python ML tooling. Physical hardware camera/mic execution on physical iOS/Android devices was not performed.

---

## Findings

### 1. Missing Microphone Permissions in Android and iOS Native Manifests
Severity: High  
[VERIFIED-CODE]  
The application introduces a `VoiceDictationButton` component (`lib/presentation/components/voice_dictation_button.dart`) that requests microphone permissions and captures `.wav` audio. However, neither `android/app/src/main/AndroidManifest.xml` nor `ios/Runner/Info.plist` declares the mandatory microphone permissions. On iOS devices, invoking `Permission.microphone.request()` or starting an `AudioRecorder` session without `NSMicrophoneUsageDescription` triggers an immediate hard crash by `launchd` / iOS security sandbox. On Android, recording audio without `RECORD_AUDIO` throws a security exception.

Evidence:
`lib/presentation/components/voice_dictation_button.dart:66`:
```dart
final status = await Permission.microphone.request();
```
`ios/Runner/Info.plist:39-46` (Microphone keys absent):
```xml
<key>NSCameraUsageDescription</key>
<string>CropGuard AI uses the camera to scan crops and detect diseases in real time.</string>
<key>NSFaceIDUsageDescription</key>
<string>CropGuard AI uses Face ID to unlock the app and protect your farm data.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>CropGuard AI uses your location to show nearby disease outbreak reports and provide localised weather advice.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>CropGuard AI accesses your photo library so you can select crop images for disease analysis.</string>
```
`android/app/src/main/AndroidManifest.xml:1-24` (`RECORD_AUDIO` absent):
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
<uses-permission android:name="android.permission.USE_FINGERPRINT"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

Fix:
1. Add `RECORD_AUDIO` permission to `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <uses-permission android:name="android.permission.RECORD_AUDIO"/>
   ```
2. Add `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` to `ios/Runner/Info.plist`:
   ```xml
   <key>NSMicrophoneUsageDescription</key>
   <string>CropGuard AI uses the microphone for voice dictation in Twi.</string>
   <key>NSSpeechRecognitionUsageDescription</key>
   <string>CropGuard AI uses speech recognition for transcribing farm notes.</string>
   ```

---

### 2. Double-Normalization and Input Dimension Drift in Model Evaluation Script
Severity: High  
[VERIFIED-CODE]  
The offline model evaluation tool `tools/evaluate_model.py` has drifted from the production model's tensor specification. It defaults `--input-size` to `224` (instead of `128`) and divides image pixel arrays by `255.0` (`img / 255.0`). Because the verified TFLite model `cropguard_plant_disease_verified.tflite` contains internal Keras `Rescaling(scale=1./127.5, offset=-1)` layers, feeding pre-divided `[0, 1]` values causes double normalization into `[-1.0, -0.992]`, suppressing activations and distorting benchmark accuracy and ECE calculation.

Evidence:
`tools/evaluate_model.py:71-75`:
```python
parser.add_argument(
    "--input-size",
    type=int,
    default=224,
    help="Model input width/height in pixels (default: 224)",
)
```
`tools/evaluate_model.py:160-162`:
```python
img = img.resize((self.input_size, self.input_size))
input_data = np.expand_dims(img, axis=0).astype(np.float32) / 255.0
```

Fix:
Change `--input-size` default to `128` and pass raw `[0, 255]` float values without division:
```python
parser.add_argument(
    "--input-size",
    type=int,
    default=128,
    help="Model input width/height in pixels (default: 128)",
)
```
and:
```python
input_data = np.expand_dims(img, axis=0).astype(np.float32)
```

---

### 3. Silent Lockup on Empty Camera List in ScannerProvider
Severity: Medium  
[VERIFIED-CODE]  
In `ScannerProvider.initCamera()`, if `availableCameras()` returns an empty list (e.g. running on an emulator without a virtual camera, or on a restricted device), the method silently returns on line 93. It does not set `errorMessageCode`, does not set `errorMessage`, and does not notify listeners. As a result, `cameraInitialized` remains `false` indefinitely and `isAnalysing` remains unset, leaving the user interface stuck on a black container or infinite loading indicator with no feedback or retry action.

Evidence:
`lib/presentation/screens/scanner/scanner_provider.dart:91-94`:
```dart
try {
  cameras = await availableCameras();
  if (cameras.isEmpty) return;
```

Fix:
Set `errorMessageCode = UiMessage.cameraUnavailable;` and notify listeners when `cameras.isEmpty`:
```dart
cameras = await availableCameras();
if (cameras.isEmpty) {
  errorMessageCode = UiMessage.cameraUnavailable;
  errorMessage = 'No camera devices found on this device.';
  notifyListeners();
  return;
}
```

---

### 4. Synthetic "Check for Updates" Flow in Settings
Severity: Medium  
[VERIFIED-CODE]  
In `SettingsProvider.checkForModelUpdates()`, the "Check for Updates" button triggers a synthetic delay (`await Future.delayed(const Duration(milliseconds: 600));`) and re-reads the local bundled asset file `assets/model_metadata.json` from `rootBundle`. It does not perform a network call to Firebase Remote Config, GitHub releases, or a remote backend to inspect if a new model version is available. The UI immediately displays `UiMessage.modelUpToDate` regardless of whether updates exist.

Evidence:
`lib/presentation/screens/settings/settings_provider.dart:261-273`:
```dart
Future<void> checkForModelUpdates() async {
  if (isCheckingUpdates) return;
  isCheckingUpdates = true;
  updateMessageCode = null;
  notifyListeners();

  await _loadModelVersion();
  await Future.delayed(const Duration(milliseconds: 600));

  isCheckingUpdates = false;
  updateMessageCode = UiMessage.modelUpToDate;
  notifyListeners();
```

Fix:
Either connect `checkForModelUpdates()` to `VersionCheckService` / Firebase Remote Config parameter `latest_model_version`, or clarify the UI label to show "Installed Model Info" rather than a misleading active update search.

---

### 5. Silent Failure in Submissions History Screen
Severity: Low  
[VERIFIED-CODE]  
In `MySubmissionsScreen._loadSubmissions()`, exceptions thrown by `_firestore.getUserExpertRequests(userId)` or `_firestore.getUserMissingCrops(userId)` are caught with an empty `catch (_) {}` block. If the device is offline or the request encounters a Firestore timeout, the screen silently finishes loading and displays an empty state ("No submissions yet"), misleading the user into thinking their past consultations do not exist rather than signaling a network connectivity error.

Evidence:
`lib/presentation/screens/submissions/my_submissions_screen.dart:42-48`:
```dart
if (userId.isNotEmpty && userId != 'guest') {
  try {
    final expertReqs = await _firestore.getUserExpertRequests(userId);
    final missingCrops = await _firestore.getUserMissingCrops(userId);
    items.addAll(expertReqs);
    items.addAll(missingCrops);
  } catch (_) {}
}
```

Fix:
Introduce an `_errorMessage` state in `MySubmissionsScreen` and display an error banner with a "Retry" button when `_loadSubmissions()` encounters a network or Firestore exception.

---

### 6. Deprecated Swift Package Manager Compatibility Across 5 iOS Plugins
Severity: Low  
[VERIFIED-CMD]  
Running `flutter analyze` and `flutter test` outputs warnings for 5 native iOS plugin dependencies that do not support Swift Package Manager (SPM): `workmanager_apple`, `tflite_flutter`, `record_darwin`, `flutter_tts`, and `flutter_jailbreak_detection`. Flutter tooling notes that non-SPM plugin architectures will be deprecated and treated as build errors in future Flutter framework releases.

Evidence:
Command: `flutter analyze`
Output:
```
The following plugins do not support Swift Package Manager for ios:
  - workmanager_apple
  - tflite_flutter
  - record_darwin
  - flutter_tts
  - flutter_jailbreak_detection
This will become an error in a future version of Flutter. Please contact the plugin maintainers to request Swift Package Manager adoption.
No issues found! (ran in 5.4s)
```

Fix:
Track upstream plugin releases for SPM migration and schedule updates when `tflite_flutter` (or Google `ai_edge_litert` Flutter plugin) and `workmanager` publish SPM-compliant podspecs.

---

## Areas checked and found clean

1. **Transient vs Permanent Failure Retry Segregation** [VERIFIED-CODE]
   - `FirestoreService` and `FirebaseStorageService` explicitly distinguish transient retryable errors (`unavailable`, `deadline-exceeded`, `internal`, `SocketException`, `TimeoutException`) from permanent client errors (`permission-denied`, `not-found`, `invalid-argument`) using `_isFirestoreTransientError` ([firestore_service.dart:15-27](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/data/remote/firestore_service.dart#L15-L27)) and `_isStorageTransientError` ([firebase_storage_service.dart:15-31](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/data/remote/firebase_storage_service.dart#L15-L31)).

2. **Offline Queue Idempotency & Error Recovery** [VERIFIED-CODE]
   - `PendingSyncQueue` and `FirestoreService.upsertScan()` use deterministic document IDs (`docId`) with `.set()` rather than `.add()` ([firestore_service.dart:88-99](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/data/remote/firestore_service.dart#L88-L99)), ensuring replay idempotency without duplicate record creation during offline reconciliation.

3. **Label-to-Database 1:1 Invariant Alignment** [VERIFIED-CMD]
   - Unit test `every label in assets/labels_verified.txt aligns with DiseaseDatabase` ([crop_disease_classifier_test.dart:253-272](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/test/data/ml/crop_disease_classifier_test.dart#L253-L272)) executed and passed across all 51 labels. No orphan labels or missing treatment records exist.

4. **Static Code Analysis (Flutter Linter)** [VERIFIED-CMD]
   - Command: `flutter analyze`
   - Output: `No issues found! (ran in 5.4s)`

5. **Full Unit & Widget Test Suite Execution** [VERIFIED-CMD]
   - Command: `flutter test`
   - Output: `00:48 +397: All tests passed!`

---

## Areas not covered

1. **Physical Hardware Camera & Microphone Captures**: Real-time sensor captures were tested via automated mock frames and unit test harnesses; tests on physical iPhone / Android microphones and cameras were not executed in this environment.
2. **Empirical Precision/Recall Benchmark on Real Ghanaian Farmer Dataset**: The model has not been evaluated against a large held-out field dataset of Ghanaian farm photos, as no such dataset is bundled in the repository.
3. **Live Firebase Backend Integration**: Live Firestore / Firebase Auth / Storage interactions were verified via offline mocking and local SQLite sync queue tests rather than live cloud transactions.

---

## Self-check

- **VERIFIED-CMD count**: 4 (`flutter analyze`, `flutter test`, `flutter pub outdated`, Python TFLite execution)
- **VERIFIED-CODE count**: 7 (Permission manifests, `tools/evaluate_model.py`, `ScannerProvider`, `SettingsProvider`, `MySubmissionsScreen`, `FirestoreService`, `PendingSyncQueue`)
- **UNVERIFIED count**: 0
- Total findings: 6 (2 High, 2 Medium, 2 Low). Every finding contains verified file:line citations and exact code/command evidence.
