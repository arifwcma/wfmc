import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';

class PmTilesBaseLayer {
  const PmTilesBaseLayer({
    required this.id,
    required this.title,
    required this.url,
    required this.kind,
  });

  final String id;
  final String title;
  final String url;
  final PmTilesLayerKind kind;
}

enum PmTilesLayerKind { line, fill, outline }

class PmTilesBaseLayers {
  PmTilesBaseLayers._();

  static const String baseUrl = 'https://baselayers.wcma.work';

  static const List<PmTilesBaseLayer> all = [
    PmTilesBaseLayer(
      id: 'rivers_and_streams',
      title: 'Rivers and Streams',
      url: '$baseUrl/rivers_and_streams.pmtiles',
      kind: PmTilesLayerKind.line,
    ),
    PmTilesBaseLayer(
      id: 'wetlands',
      title: 'Wetlands',
      url: '$baseUrl/wetlands.pmtiles',
      kind: PmTilesLayerKind.fill,
    ),
    PmTilesBaseLayer(
      id: 'wparcel',
      title: 'Parcels',
      url: '$baseUrl/wparcel.pmtiles',
      kind: PmTilesLayerKind.outline,
    ),
  ];

  static Theme themeFor(PmTilesBaseLayer layer) {
    return ThemeReader().read(_styleJson(layer));
  }

  static TileProviders providersFor(
    PmTilesBaseLayer layer,
    VectorTileProvider provider,
  ) {
    return TileProviders({layer.id: provider});
  }

  static Map<String, dynamic> _styleJson(PmTilesBaseLayer layer) {
    final paint = _paintFor(layer.kind);
    final type = _typeFor(layer.kind);
    return <String, dynamic>{
      'version': 8,
      'sources': <String, dynamic>{
        layer.id: <String, dynamic>{'type': 'vector'},
      },
      'layers': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': '${layer.id}-$type',
          'type': type,
          'source': layer.id,
          'source-layer': layer.id,
          'paint': paint,
        },
      ],
    };
  }

  static String _typeFor(PmTilesLayerKind kind) {
    switch (kind) {
      case PmTilesLayerKind.line:
      case PmTilesLayerKind.outline:
        return 'line';
      case PmTilesLayerKind.fill:
        return 'fill';
    }
  }

  static Map<String, dynamic> _paintFor(PmTilesLayerKind kind) {
    switch (kind) {
      case PmTilesLayerKind.line:
        return <String, dynamic>{
          'line-color': '#2D6CDF',
          'line-width': 1.4,
        };
      case PmTilesLayerKind.fill:
        return <String, dynamic>{
          'fill-color': 'rgba(96,156,255,0.35)',
          'fill-outline-color': '#3A7ACE',
        };
      case PmTilesLayerKind.outline:
        return <String, dynamic>{
          'line-color': '#666666',
          'line-width': 0.6,
        };
    }
  }
}

