import 'dart:math' as math;

import 'package:flutter/foundation.dart';

@immutable
class WmsLayer {
  const WmsLayer({
    required this.name,
    required this.title,
    required this.children,
    required this.queryable,
    required this.bbox3857,
  });

  final String? name;
  final String title;
  final List<WmsLayer> children;
  final bool queryable;
  final WmsBBox? bbox3857;

  bool get isLeaf => children.isEmpty;
  bool get isRequestable => (name ?? '').isNotEmpty;
}

@immutable
class WmsBBox {
  const WmsBBox({
    required this.minx,
    required this.miny,
    required this.maxx,
    required this.maxy,
  });

  final double minx;
  final double miny;
  final double maxx;
  final double maxy;

  double get width => (maxx - minx).abs();
  double get height => (maxy - miny).abs();
  double get span => math.max(width, height);
  (double, double) get center => ((minx + maxx) / 2, (miny + maxy) / 2);
}

@immutable
class WmsCapabilities {
  const WmsCapabilities({
    required this.serviceTitle,
    required this.rootLayer,
  });

  final String serviceTitle;
  final WmsLayer rootLayer;
}
