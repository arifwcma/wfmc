import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';

class PmTilesProviderCache {
  final Map<String, Future<PmTilesVectorTileProvider>> _providersByUrl = {};

  Future<PmTilesVectorTileProvider> provider(String url) {
    return _providersByUrl.putIfAbsent(
      url,
      () => PmTilesVectorTileProvider.fromSource(url),
    );
  }
}
