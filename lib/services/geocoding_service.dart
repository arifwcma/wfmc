import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class GeocodingResult {
  const GeocodingResult({
    required this.displayName,
    required this.location,
  });

  final String displayName;
  final LatLng location;
}

class GeocodingService {
  GeocodingService({required this.httpClient});

  final http.Client httpClient;

  /// Wimmera-region bounding box for Nominatim search bias.
  static const _viewbox = '141.0,-37.5,144.0,-35.5';

  Future<List<GeocodingResult>> search(String query) async {
    if (query.trim().length < 3) return [];

    final uri =
        Uri.parse('https://nominatim.openstreetmap.org/search').replace(
      queryParameters: {
        'q': query,
        'format': 'json',
        'limit': '5',
        'viewbox': _viewbox,
        'bounded': '0',
        'countrycodes': 'au',
      },
    );

    final res = await httpClient.get(
      uri,
      headers: {'User-Agent': 'WimmeraFloodMaps/1.0'},
    );

    if (res.statusCode != 200) return [];

    final list = json.decode(res.body) as List;
    return list.map((item) {
      return GeocodingResult(
        displayName: item['display_name'] as String,
        location: LatLng(
          double.parse(item['lat'] as String),
          double.parse(item['lon'] as String),
        ),
      );
    }).toList();
  }
}
