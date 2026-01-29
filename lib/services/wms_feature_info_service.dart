import 'dart:convert';

import 'package:http/http.dart' as http;

class WmsFeatureInfoService {
  WmsFeatureInfoService({required this.httpClient});

  final http.Client httpClient;

  Future<Map<String, dynamic>> getFeatureInfo({
    required Uri baseEndpoint,
    required String mapPath,
    required List<String> layerNames,
    required double bboxMinx,
    required double bboxMiny,
    required double bboxMaxx,
    required double bboxMaxy,
    required int width,
    required int height,
    required int i,
    required int j,
  }) async {
    final bbox =
        '${bboxMinx.toStringAsFixed(3)},${bboxMiny.toStringAsFixed(3)},${bboxMaxx.toStringAsFixed(3)},${bboxMaxy.toStringAsFixed(3)}';

    final params = <String, String>{
      'MAP': mapPath,
      'SERVICE': 'WMS',
      'VERSION': '1.3.0',
      'REQUEST': 'GetFeatureInfo',
      'CRS': 'EPSG:3857',
      'BBOX': bbox,
      'WIDTH': '$width',
      'HEIGHT': '$height',
      'LAYERS': layerNames.join(','),
      'QUERY_LAYERS': layerNames.join(','),
      'STYLES': '',
      'INFO_FORMAT': 'application/geo+json',
      'I': '$i',
      'J': '$j',
      'FEATURE_COUNT': '10',
    };

    final uri = baseEndpoint.replace(queryParameters: params);
    final res = await httpClient.get(uri);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('GetFeatureInfo failed: HTTP ${res.statusCode}');
    }

    final decoded = json.decode(res.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return {'raw': decoded};
  }
}
