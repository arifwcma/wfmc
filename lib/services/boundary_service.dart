import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class BoundaryService {
  static const _assetPath = 'assets/wcma_boundary.geojson';

  List<List<LatLng>>? _polygons;
  LatLngBounds? _bounds;

  List<List<LatLng>> get polygons => _polygons ?? [];
  LatLngBounds? get bounds => _bounds;

  Future<void> load() async {
    final jsonStr = await rootBundle.loadString(_assetPath);
    final geojson = json.decode(jsonStr) as Map<String, dynamic>;

    final features = geojson['features'] as List<dynamic>;
    if (features.isEmpty) return;

    final feature = features[0] as Map<String, dynamic>;
    final geometry = feature['geometry'] as Map<String, dynamic>;
    final type = geometry['type'] as String;
    final coordinates = geometry['coordinates'] as List<dynamic>;

    final allPolygons = <List<LatLng>>[];
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;

    if (type == 'MultiPolygon') {
      for (final polygon in coordinates) {
        for (final ring in polygon as List<dynamic>) {
          final points = <LatLng>[];
          for (final coord in ring as List<dynamic>) {
            final lng = (coord[0] as num).toDouble();
            final lat = (coord[1] as num).toDouble();
            points.add(LatLng(lat, lng));
            if (lat < minLat) minLat = lat;
            if (lat > maxLat) maxLat = lat;
            if (lng < minLng) minLng = lng;
            if (lng > maxLng) maxLng = lng;
          }
          allPolygons.add(points);
        }
      }
    } else if (type == 'Polygon') {
      for (final ring in coordinates) {
        final points = <LatLng>[];
        for (final coord in ring as List<dynamic>) {
          final lng = (coord[0] as num).toDouble();
          final lat = (coord[1] as num).toDouble();
          points.add(LatLng(lat, lng));
          if (lat < minLat) minLat = lat;
          if (lat > maxLat) maxLat = lat;
          if (lng < minLng) minLng = lng;
          if (lng > maxLng) maxLng = lng;
        }
        allPolygons.add(points);
      }
    }

    _polygons = allPolygons;
    _bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
  }
}
