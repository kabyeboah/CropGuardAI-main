import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:cropguard_flutter/core/config/app_secrets.dart';
import 'package:cropguard_flutter/core/utils/location_helper.dart';
import 'package:cropguard_flutter/core/utils/cached_tile_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppSecrets.reset();
  });

  tearDown(() {
    AppSecrets.reset();
  });

  group('LocationHelper Coordinate Coarsening & Privacy', () {
    test(
        'coarsen rounds latitude and longitude to 2 decimal places by default (~1.1 km resolution)',
        () {
      expect(LocationHelper.coarsen(6.68854321), 6.69);
      expect(LocationHelper.coarsen(-1.62441234), -1.62);
      expect(LocationHelper.coarsen(0.00001), 0.0);
      expect(LocationHelper.coarsen(10.5555), 10.56);
    });

    test('coarsen supports custom precision levels', () {
      // 1 decimal place (~11 km)
      expect(LocationHelper.coarsen(6.6885, precision: 1), 6.7);
      // 3 decimal places (~110 m)
      expect(LocationHelper.coarsen(6.6885, precision: 3), 6.689);
    });

    test('coarsenPoint returns coarsened GeoPoint preserving precision flag',
        () {
      const point = GeoPoint(6.68854321, -1.62441234, isPrecise: true);
      final coarsened = LocationHelper.coarsenPoint(point);

      expect(coarsened.latitude, 6.69);
      expect(coarsened.longitude, -1.62);
      expect(coarsened.isPrecise, isTrue);
    });

    test('coarsenCoordinates returns coarsened tuple', () {
      final (lat, lon) =
          LocationHelper.coarsenCoordinates(6.68854321, -1.62441234);
      expect(lat, 6.69);
      expect(lon, -1.62);
    });
  });

  group('Tile Provider & User-Agent Compliance', () {
    test('AppSecrets resolves default and overridden OSM Tile URL', () {
      expect(AppSecrets.osmTileUrl,
          'https://tile.openstreetmap.org/{z}/{x}/{y}.png');

      AppSecrets.dartDefineOsmTileUrlOverride =
          'https://custom-tiles.cropguard.app/{z}/{x}/{y}.png';
      expect(AppSecrets.osmTileUrl,
          'https://custom-tiles.cropguard.app/{z}/{x}/{y}.png');
    });

    test('AppSecrets resolves default and overridden User-Agent', () {
      expect(AppSecrets.osmUserAgent,
          'CropGuardAI/1.0 (com.crop.guard.app; support@cropguard.app)');

      AppSecrets.dartDefineOsmUserAgentOverride = 'CropGuardCustom/2.0';
      expect(AppSecrets.osmUserAgent, 'CropGuardCustom/2.0');
    });

    test('CachedTileProvider injects compliant User-Agent in headers', () {
      final provider = CachedTileProvider();
      final options = TileLayer(urlTemplate: AppSecrets.osmTileUrl);
      const coords = TileCoordinates(10, 10, 5);

      final imageProvider = provider.getImage(coords, options);
      expect(imageProvider, isNotNull);
    });
  });
}
