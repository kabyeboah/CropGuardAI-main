import 'package:cropguard_flutter/core/utils/connectivity_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConnectivityService', () {
    late ConnectivityService service;

    setUp(() {
      service = ConnectivityService();
    });

    tearDown(() {
      service.dispose();
    });

    test('initializes with base poll interval of 60 seconds', () {
      expect(service.currentPollInterval, const Duration(seconds: 60));
    });

    test('exposes connection status stream and defaults to online', () {
      expect(service.currentStatus, ConnectionStatus.online);
      expect(service.statusStream, isNotNull);
      expect(service.offlineStream, isNotNull);
    });

    test(
        'didChangeAppLifecycleState resets poll interval on resume and stops on pause',
        () {
      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(service.currentPollInterval, const Duration(seconds: 60));
    });
  });
}
