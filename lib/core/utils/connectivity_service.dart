import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

/// Real connection quality, not just whether a network interface exists.
enum ConnectionStatus {
  /// Reachable and responsive.
  online,

  /// Reachable but slow to respond (weak signal, congested network).
  poor,

  /// No network interface, or an interface that can't reach the internet
  /// (dead WiFi router, captive portal, no mobile data throughput).
  offline,
}

/// Detects connectivity automatically. `connectivity_plus` alone only reports
/// whether a network *interface* is present — it cannot tell a working WiFi
/// from one whose router has no internet, nor a strong signal from a crawling
/// one. So on top of the interface signal we run a lightweight TCP reachability
/// probe and time it, which lets us distinguish online / poor / offline.
class ConnectivityService with WidgetsBindingObserver {
  final _connectivity = Connectivity();
  final _controller = StreamController<ConnectionStatus>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _interfaceSub;
  Timer? _pollTimer;
  bool _probing = false;
  ConnectionStatus _last = ConnectionStatus.online;

  // Probe target: Cloudflare's public DNS resolver. A TCP connect to port 53
  // is fast, globally reachable, sends no data, and does not depend on DNS
  // resolution itself (we dial an IP directly).
  static const _probeHost = '1.1.1.1';
  static const _probePort = 53;
  static const _probeTimeout = Duration(seconds: 4);

  // Connect slower than this (but within the timeout) → treat as a poor link.
  static const _poorLatency = Duration(milliseconds: 1500);

  // How often to re-probe while the app is in use. Interface-change events do
  // not fire when the *same* WiFi silently loses internet or degrades, so a
  // modest poll is the only way to notice that.
  static const _pollInterval = Duration(seconds: 30);

  ConnectivityService() {
    // Re-probe whenever the OS reports an interface change (wifi <-> mobile <->
    // none) and, while the app is in the foreground, on a steady interval to
    // catch silent degradation.
    _interfaceSub =
        _connectivity.onConnectivityChanged.listen((_) => _refresh());
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
    _refresh();
  }

  /// Full connection status, emitted whenever it changes.
  Stream<ConnectionStatus> get statusStream => _controller.stream;

  /// One-shot status check (also broadcasts if the status changed).
  Future<ConnectionStatus> checkStatus() async {
    final status = await _probe();
    if (status != _last) {
      _last = status;
      if (!_controller.isClosed) _controller.add(status);
    }
    return status;
  }

  // ── Backwards-compatible boolean API ──────────────────────────────────────
  // Existing callers that only care about hard-offline keep working.

  Stream<bool> get offlineStream =>
      statusStream.map((s) => s == ConnectionStatus.offline);

  Future<bool> checkIsOffline() async =>
      (await checkStatus()) == ConnectionStatus.offline;

  // ── App lifecycle ─────────────────────────────────────────────────────────
  // Polling only earns its keep while the user can see the banner. Pause it
  // when the app leaves the foreground so the probe isn't dialing every 30s in
  // the background, and resume with an immediate check on return.

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _refresh();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _stopPolling();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _refresh());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  Future<void> _refresh() async {
    if (_probing) return;
    _probing = true;
    try {
      await checkStatus();
    } finally {
      _probing = false;
    }
  }

  Future<ConnectionStatus> _probe() async {
    // No interface at all → definitely offline, skip the network round-trip.
    final interfaces = await _connectivity.checkConnectivity();
    if (interfaces.every((r) => r == ConnectivityResult.none)) {
      return ConnectionStatus.offline;
    }

    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(
        _probeHost,
        _probePort,
        timeout: _probeTimeout,
      );
      socket.destroy();
      stopwatch.stop();
      return stopwatch.elapsed > _poorLatency
          ? ConnectionStatus.poor
          : ConnectionStatus.online;
    } catch (_) {
      // Interface present but the probe could not be reached — connected to a
      // network with no usable internet.
      return ConnectionStatus.offline;
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _interfaceSub?.cancel();
    _pollTimer?.cancel();
    _controller.close();
  }
}
