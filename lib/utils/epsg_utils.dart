import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../services/wms_tile_provider.dart';

class EpsgUtils {
  EpsgUtils._();

  static LatLng epsg3857ToLatLng(double x, double y) {
    final lon = (x / WmsTileProvider.originShift) * 180.0;
    final latRad = (y / WmsTileProvider.originShift) * math.pi;
    final lat = (180.0 / math.pi) * (2.0 * math.atan(math.exp(latRad)) - math.pi / 2.0);
    return LatLng(lat, lon);
  }

  static (double x, double y) latLngToEpsg3857(LatLng ll) {
    final x = ll.longitude * WmsTileProvider.originShift / 180.0;
    final latRad = math.log(math.tan((90.0 + ll.latitude) * math.pi / 360.0));
    final y = (latRad / (math.pi / 180.0)) * WmsTileProvider.originShift / 180.0;
    return (x, y);
  }

  static double zoomFromSpanMeters(double spanMeters) {
    final world = WmsTileProvider.originShift * 2;
    final frac = (spanMeters / world).clamp(1e-9, 1.0);
    final z = math.log(1 / frac) / math.ln2;
    return z.clamp(3.0, 16.0);
  }
}
