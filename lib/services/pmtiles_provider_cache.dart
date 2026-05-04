import 'package:flutter/foundation.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';

class PmTilesProviderCache {
  final Map<String, Future<PmTilesVectorTileProvider>> _providersByUrl = {};

  Future<PmTilesVectorTileProvider> provider(String url) {
    return _providersByUrl.putIfAbsent(url, () => _load(url));
  }

  Future<PmTilesVectorTileProvider> _load(String url) async {
    try {
      return await PmTilesVectorTileProvider.fromSource(url);
    } catch (e, st) {
      debugPrint('PmTilesProviderCache: failed to load $url: $e\n$st');
      _providersByUrl.remove(url);
      rethrow;
    }
  }
}
