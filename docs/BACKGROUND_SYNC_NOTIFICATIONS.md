# CropGuard AI — Notifications, Background Work & Sync Architecture

This document describes the design, execution lifecycle, and operational constraints for push notifications, background tasks, and offline synchronization in the CropGuard AI mobile application. [CURRENT] [CURRENT]

---

## 1. Push Notification Architecture (FCM)

CropGuard AI uses Firebase Cloud Messaging (FCM) along with Apple Push Notification service (APNs) and Android FCM channels to deliver outbreak alerts, disease warnings, and reminders. [CURRENT] [CURRENT]

### 1.1 Token Lifecycle
- **Acquisition & Sync**: On application startup or user authentication (`authStateChanges`), `PushNotificationService.syncFcmToken(userId)` retrieves the device FCM token and persists it to Cloud Firestore:
  ```json
  // Firestore document: users/{userId}
  {
    "fcmToken": "cE3z...",
    "fcmTokenUpdatedAt": "<SERVER_TIMESTAMP>",
    "platform": "android | iOS"
  }
  ```
- **Token Refresh**: The `_fcm.onTokenRefresh` stream automatically captures newly rotated tokens and syncs them to Firestore without requiring user interaction.
- **Sign-Out & Account Deletion**: When a user logs out or deletes their profile, `PushNotificationService.clearFcmToken(userId)` explicitly deletes the token from Firestore (`FieldValue.delete()`) and calls `_fcm.deleteToken()` on the client to prevent stale notification leakage.

### 1.2 Message Handling Across States

| App State | Handling Mechanism | User Presentation | [CURRENT]
| :--- | :--- | :--- | [CURRENT]
| **Foreground** | `FirebaseMessaging.onMessage` | Displays a local heads-up banner via `FlutterLocalNotificationsPlugin` (`NotificationHelper.showRiskAlert` / `showScanReminder`) and inserts the alert into SQLite `notifications` inbox. [CURRENT] [CURRENT] | [CURRENT]
| **Background (Awake/Paused)** | System Notification Tray + `FirebaseMessaging.onMessageOpenedApp` | System tray notification displayed natively by OS. [CURRENT] [CURRENT] Tapping executes route handler (`_onNotificationTap`). [CURRENT] | [CURRENT]
| **Background (Isolate)** | `@pragma('vm:entry-point') _firebaseMessagingBackgroundHandler` | Initializes minimal Firebase instance to log background message metadata. [CURRENT] [CURRENT] | [CURRENT]
| **Terminated / Cold Start** | `FirebaseMessaging.instance.getInitialMessage()` | App boots up and immediately consumes the launch message payload to deep-link to the target screen. [HISTORICAL] [HISTORICAL] | [CURRENT]

---

## 2. Notification Permissions Lifecycle

- **Android 13+ (API 33+)**: Explicit runtime permission prompt (`POST_NOTIFICATIONS`) requested via `PermissionHelper.requestNotificationsWithRecovery()`.
- **iOS / iPadOS**: Darwin notification permissions requested at startup with alert, badge, and sound entitlements.
- **Recovery Navigation**: If notifications are permanently denied or restricted, `PermissionHelper.showPermissionRecoveryDialog` opens system App Settings directly rather than repeatedly presenting dead dialogs.
- **Settings Sync**: User toggle in `SettingsScreen` coordinates with `SharedPreferences` (`notifications_enabled`) and cancels periodic outbreak polling tasks when disabled.

---

## 3. Deep-Linked Notifications & In-App Routing

Push notification payloads carry structured data for routing: [CURRENT]
```json
{
  "route": "/outbreak_map",
  "type": "outbreak_alert",
  "disease": "Black Pod Rot",
  "region": "Ashanti"
}
```
- **Execution Flow**:
1. [CURRENT] [CURRENT] User taps notification (from tray, banner, or cold start). [HISTORICAL]
2. [CURRENT] [CURRENT] `PushNotificationService._handleMessageClick` extracts the `route` property (falling back safely to `/outbreak_map`). [CURRENT]
3. [CURRENT] [CURRENT] GoRouter executes `AppRouter.router.push(route)`. [CURRENT]
- **App Links & Universal Links**: Handled by `DeepLinkService` with strict HTTPS scheme checks, authorized domain whitelisting (`AppSecrets.passwordResetContinueUrl`), and parameter sanitization for action codes (`oobCode`).

---

## 4. Background Execution & Mobile OS Realities

CropGuard AI is engineered to operate reliably within the strict power-management regimes of modern mobile operating systems. [CURRENT] [CURRENT]

### 4.1 Android Background Scheduling (`WorkManager`)
- **Engine**: Backed by Android Jetpack `WorkManager` via `workmanager` Flutter plugin.
- **Constraints**:
  - `NetworkType.connected` (tasks will not wake when the device is completely offline).
  - `requiresBatteryNotLow: true` (respects Android battery saver and power tiers).
- **Execution Safeguards**:
  - Tasks running in the background isolate are wrapped with `.timeout(const Duration(minutes: 2))` to strictly prevent battery drain or wakelock leaks.
  - Background isolates refresh the Firebase Auth ID token (`getIdToken(true)`) prior to Firestore writes to prevent stale session permission denials.
- **Cadence**: Android WorkManager enforces a **minimum periodic interval of 15 minutes**. Periodic tasks may be delayed further by Doze mode or Android App Standby buckets.

### 4.2 iOS Background Scheduling (`BGTaskScheduler`)
> [!IMPORTANT] [CURRENT]
> **iOS Background Scheduling Non-Determinism**: [CURRENT]
> iOS does **NOT** execute background tasks at exact or fixed intervals. [CURRENT] [CURRENT]
> [CURRENT]
> When the app calls `BGTaskScheduler.shared.submit(request)` with `earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)`, the 15-minute interval is treated by iOS as a **non-binding suggestion (hint)**. [CURRENT] [CURRENT]
> [CURRENT]
> The actual time of execution is determined entirely by iOS based on: [CURRENT]
> 1. [CURRENT] [CURRENT] Battery level and charging status (e.g., connected to AC power). [CURRENT]
> 2. [CURRENT] [CURRENT] Device usage habits (e.g., times of day the user typically opens CropGuard AI). [CURRENT]
> 3. [CURRENT] [CURRENT] Network availability and Low Data Mode. [CURRENT]
> 4. [CURRENT] [CURRENT] Thermal and low-power conditions. [CURRENT]
> [CURRENT]
> Tasks can be deferred for hours or omitted if the user has disabled "Background App Refresh" in iOS Settings. [CURRENT] [CURRENT]

- **Implementation**:
  - `AppDelegate.swift` registers `com.cropguard.ai.sync` with `BGTaskScheduler`.
  - When the system allocates an execution slot, `handleBGSync` calls Dart via method channel `com.cropguard.ai/bg_sync`.
  - The Dart isolate executes `CommunityRepositoryImpl.drainPendingSync()` to sync any pending queue operations.
  - An `expirationHandler` is attached to immediately yield and call `setTaskCompleted(success: false)` if iOS terminates the execution window.
  - As a fallback, an immediate foreground queue drain is triggered on iOS whenever the user brings the app back to the foreground (`scheduleIosForegroundSync()`).

---

## 5. Offline Synchronization & Retry Engine

To support Ghanaian farmers in low-connectivity rural environments, writes are staged in a durable SQLite-backed queue (`PendingSyncQueue`). [CURRENT] [CURRENT]

```
  [ Offline Action ]
          │
          ▼
   PendingSyncQueue
  (SQLite: 'pending')
          │
  ┌───────┴────────────────────────────┐
  │ On Connectivity Restored (Online)  │
  │ Or Background Worker Wake-up       │
  └───────┬────────────────────────────┘
          ▼
   Replay Operation
          │
     ┌────┴────────────┐
     ▼                 ▼
 [Success]         [Failure]
     │                 │
 Delete from       Increment retry_count
    Queue          (RetryUtils Exponential Backoff)
                       │
             ┌─────────┴─────────┐
             ▼                   ▼
      retries < 5          retries >= 5
     (status: 'failed')   (status: 'abandoned')
```

### 5.1 Retry Semantics & Exponential Backoff
- `RetryUtils.retry<T>` provides automated retries for transient cloud errors (e.g. `unavailable`, network sockets):
  - `maxAttempts`: default 3
  - `initialDelay`: 1 second
  - `factor`: 2.0 (exponential multiplier)
  - `timeout`: 10 seconds per attempt
  - Error logs automatically sanitize and redact sensitive tokens and credentials.

### 5.2 Dead-Letter / Abandoned Queue Handling
- If an operation fails 5 consecutive times across drain attempts, its status is transitioned to `'abandoned'`.
- Abandoned operations do not block other pending operations in the queue and are excluded from unread sync badges (`pendingCount`).
- `PendingSyncQueue.clear(userId: ...)` allows targeted cleanup of synced or stale records while preserving un-synced scans during sign-out.
