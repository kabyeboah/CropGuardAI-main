import Flutter
import UIKit
import BackgroundTasks

/// Identifier must match BGTaskSchedulerPermittedIdentifiers in Info.plist
/// and the Dart constant BackgroundTaskHelper.kIosBgTaskId.
private let kSyncTaskId = "com.cropguard.ai.sync"

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  // Weak ref to the Flutter channel so the BG handler can invoke Dart
  // without retaining the engine.
  private weak var syncChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    registerBGSyncTask()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Wire up the method channel that Dart uses to ask iOS to schedule/cancel
    // the next BGAppRefreshTask wake-up.
    let messenger = engineBridge.binaryMessenger
    syncChannel = FlutterMethodChannel(
      name: "com.cropguard.ai/bg_sync",
      binaryMessenger: messenger
    )
    syncChannel?.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "scheduleBGSync":
        self?.scheduleBGAppRefresh()
        result(nil)
      case "cancelBGSync":
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: kSyncTaskId)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // ─── BGTaskScheduler ─────────────────────────────────────────────────────

  /// Called once at launch to register the task handler with the OS.
  /// The handler itself is a lightweight trigger: it posts a method-channel
  /// call to Dart so the existing PendingSyncQueue drain logic runs without
  /// duplicating any sync logic in Swift.
  private func registerBGSyncTask() {
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: kSyncTaskId,
      using: nil
    ) { [weak self] task in
      guard let refreshTask = task as? BGAppRefreshTask else {
        task.setTaskCompleted(success: false)
        return
      }
      self?.handleBGSync(task: refreshTask)
    }
  }

  /// Fires when iOS grants a background execution slot.
  private func handleBGSync(task: BGAppRefreshTask) {
    // Immediately schedule the *next* wake-up so the chain continues even if
    // this execution is cut short by the OS.
    scheduleBGAppRefresh()

    // Expiry handler — OS has decided we've run long enough.
    task.expirationHandler = {
      task.setTaskCompleted(success: false)
    }

    // Ask the Flutter engine to drain the pending-sync queue via the channel.
    // If the engine is not running (app fully killed), complete with success=false
    // and let the next scheduled task retry.
    guard let channel = syncChannel else {
      task.setTaskCompleted(success: false)
      return
    }

    DispatchQueue.main.async {
      channel.invokeMethod("triggerSync", arguments: nil) { response in
        let success = (response as? Bool) ?? false
        task.setTaskCompleted(success: success)
      }
    }
  }

  /// Requests iOS to wake the app for a background refresh within ~15 minutes.
  private func scheduleBGAppRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: kSyncTaskId)
    // iOS respects this as a *hint* — the actual delay is system-determined
    // (battery, usage patterns, connectivity). 15 min is the practical minimum.
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    do {
      try BGTaskScheduler.shared.submit(request)
    } catch {
      // Non-fatal: submission fails in the Simulator and when the app is in
      // the foreground — both are expected and harmless.
      NSLog("CropGuard BGSync schedule failed: \(error)")
    }
  }
}

