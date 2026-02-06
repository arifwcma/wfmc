import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:pool/pool.dart';

final _requestPool = Pool(4);

class WmsTileProvider extends TileProvider {
  WmsTileProvider({
    required this.httpClient,
    required this.baseEndpoint,
    required this.mapPath,
    required this.layerNames,
    this.imageFormat = 'image/png',
    this.transparent = true,
  });

  final http.Client httpClient;
  final Uri baseEndpoint;
  final String mapPath;
  final List<String> layerNames;
  final String imageFormat;
  final bool transparent;

  static const int tileSizePx = 256;
  static const double earthRadius = 6378137.0;
  static final double originShift = 2 * math.pi * earthRadius / 2.0;
  static final double initialResolution = 2 * math.pi * earthRadius / tileSizePx;

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

    final bbox = '${minx.toStringAsFixed(3)},${miny.toStringAsFixed(3)},${maxx.toStringAsFixed(3)},${maxy.toStringAsFixed(3)}';

    final params = <String, String>{
      'MAP': mapPath,
      'SERVICE': 'WMS',
      'VERSION': '1.3.0',
      'REQUEST': 'GetMap',
      'LAYERS': layerNames.join(','),
      'STYLES': '',
      'FORMAT': imageFormat,
      'TRANSPARENT': transparent ? 'TRUE' : 'FALSE',
      'CRS': 'EPSG:3857',
      'WIDTH': '$tileSizePx',
      'HEIGHT': '$tileSizePx',
      'BBOX': bbox,
    };

    return baseEndpoint.replace(queryParameters: params);
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
  ImageStreamCompleter loadImage(WmsNetworkImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      informationCollector: () sync* {
        yield ErrorDescription('WMS tile: $url');
      },
    );
  }

  Future<ui.Codec> _loadAsync(WmsNetworkImage key, ImageDecoderCallback decode) async {
    return _requestPool.withResource(() async {
      try {
        debugPrint('WMS tile request: ${key.url}');
        final res = await httpClient.get(key.url);
        debugPrint('WMS tile response: ${res.statusCode}, ${res.bodyBytes.length} bytes');
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw Exception('Tile fetch failed: HTTP ${res.statusCode}');
        }
        final bytes = res.bodyBytes;
        if (bytes.isEmpty) {
          throw Exception('Tile fetch returned empty body');
        }
        final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        return decode(buffer);
      } catch (e, st) {
        debugPrint('WMS tile error: $e\n$st');
        rethrow;
      }
    });
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WmsNetworkImage && other.url == url;
  }

  @override
  int get hashCode => url.hashCode;
}

