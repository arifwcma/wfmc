import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:pool/pool.dart';

import '../utils/wms_uri.dart';
import 'tile_cache.dart';

export 'tile_cache.dart' show TileCache;

final _requestPool = Pool(6);
final _jitterRng = math.Random();

const _retryStatusCodes = <int>{429, 502, 503, 504};
const _retryBackoffs = <Duration>[
  Duration(milliseconds: 800),
  Duration(milliseconds: 2000),
  Duration(milliseconds: 4500),
];

Duration _jittered(Duration base) {
  final factor = 0.75 + _jitterRng.nextDouble() * 0.5;
  return Duration(milliseconds: (base.inMilliseconds * factor).round());
}

String _bodyExcerpt(List<int> bytes, {int max = 240}) {
  try {
    final text = String.fromCharCodes(bytes.take(max));
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  } catch (_) {
    return '<${bytes.length} bytes, non-text>';
  }
}

class WmsTileProvider extends TileProvider {
  WmsTileProvider({
    required this.httpClient,
    required this.baseEndpoint,
    required this.mapPath,
    required this.layerName,
    this.imageFormat = 'image/png',
    this.transparent = true,
  });

  final http.Client httpClient;
  final Uri baseEndpoint;
  final String mapPath;
  final String layerName;
  final String imageFormat;
  final bool transparent;

  static const int tileSizePx = 256;
  static const double earthRadius = 6378137.0;
  static final double originShift = 2 * math.pi * earthRadius / 2.0;
  static final double initialResolution =
      2 * math.pi * earthRadius / tileSizePx;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = _buildGetMapUrl(coordinates);
    return WmsNetworkImage(url: url, httpClient: httpClient);
  }

  Uri _buildGetMapUrl(TileCoordinates coords) {
    final z = coords.z.round();
    final x = coords.x.round();
    final y = coords.y.round();

    final res = initialResolution / (1 << z);

    final minx = x * tileSizePx * res - originShift;
    final maxx = (x + 1) * tileSizePx * res - originShift;
    final maxy = originShift - y * tileSizePx * res;
    final miny = originShift - (y + 1) * tileSizePx * res;

    final bbox =
        '${minx.toStringAsFixed(3)},${miny.toStringAsFixed(3)},${maxx.toStringAsFixed(3)},${maxy.toStringAsFixed(3)}';

    final params = <String, String>{
      'MAP': mapPath,
      'SERVICE': 'WMS',
      'VERSION': '1.3.0',
      'REQUEST': 'GetMap',
      'LAYERS': layerName,
      'STYLES': '',
      'FORMAT': imageFormat,
      'TRANSPARENT': transparent ? 'TRUE' : 'FALSE',
      'CRS': 'EPSG:3857',
      'WIDTH': '$tileSizePx',
      'HEIGHT': '$tileSizePx',
      'BBOX': bbox,
    };

    return buildWmsUri(base: baseEndpoint, params: params);
  }
}

@immutable
class WmsNetworkImage extends ImageProvider<WmsNetworkImage> {
  const WmsNetworkImage({required this.url, required this.httpClient});

  final Uri url;
  final http.Client httpClient;

  @override
  Future<WmsNetworkImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(
      WmsNetworkImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      informationCollector: () sync* {
        yield ErrorDescription('WMS tile: $url');
      },
    );
  }

  Future<ui.Codec> _loadAsync(
      WmsNetworkImage key, ImageDecoderCallback decode) async {
    return _requestPool.withResource(() async {
      final cacheKey = TileCache.keyFor(key.url);

      try {
        final bytes = await _fetchWithRetry(key.url);
        TileCache.putFile(cacheKey, bytes);
        final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        return decode(buffer);
      } catch (e, st) {
        final cached = TileCache.getFile(cacheKey);
        if (cached != null) {
          debugPrint('WMS tile: serving from cache ($cacheKey)');
          final bytes = await cached.readAsBytes();
          final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
          return decode(buffer);
        }
        debugPrint('WMS tile error (no cache): $e\n$st');
        rethrow;
      }
    });
  }

  Future<Uint8List> _fetchWithRetry(Uri url) async {
    int attempt = 0;
    while (true) {
      final res = await httpClient.get(url);
      final shouldRetry = _retryStatusCodes.contains(res.statusCode) &&
          attempt < _retryBackoffs.length;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        if (res.bodyBytes.isEmpty) {
          throw Exception('Tile fetch returned empty body');
        }
        return res.bodyBytes;
      }
      if (!shouldRetry) {
        final excerpt = _bodyExcerpt(res.bodyBytes);
        debugPrint(
          'WMS tile HTTP ${res.statusCode} (no retry) for $url\n  body: $excerpt',
        );
        throw Exception('Tile fetch failed: HTTP ${res.statusCode}');
      }
      await Future<void>.delayed(_jittered(_retryBackoffs[attempt]));
      attempt++;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WmsNetworkImage && other.url == url;
  }

  @override
  int get hashCode => url.hashCode;
}
