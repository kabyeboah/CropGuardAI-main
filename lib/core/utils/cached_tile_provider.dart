import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_map/flutter_map.dart';

/// Dedicated on-disk cache for map tiles, separate from the default image
/// cache. Sized generously (the default 200-object limit evicts tiles almost
/// immediately) so a usefully large area stays available offline.
class MapTileCacheManager {
  MapTileCacheManager._();

  static const _key = 'cropguardMapTiles';

  static final CacheManager instance = CacheManager(
    Config(
      _key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 3000,
    ),
  );
}

/// A [flutter_map] tile provider that caches map tiles to disk via
/// cached_network_image + flutter_cache_manager.
///
/// Tiles fetched once stay available offline (until evicted by the cache),
/// so the outbreak map keeps working without a network for areas the user has
/// already viewed. This uses dependencies the app already ships, with no API
/// key, billing, or restrictively-licensed packages.
///
/// [TileLayer] injects the `User-Agent` (from `userAgentPackageName`) into
/// [headers] after construction, and [getImage] forwards those headers — this
/// keeps requests compliant with OpenStreetMap's tile usage policy.
class CachedTileProvider extends TileProvider {
  CachedTileProvider({super.headers});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return CachedNetworkImageProvider(
      getTileUrl(coordinates, options),
      headers: headers,
      cacheManager: MapTileCacheManager.instance,
    );
  }
}
