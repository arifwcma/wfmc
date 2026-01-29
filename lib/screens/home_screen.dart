import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/wms_models.dart';
import '../services/boundary_service.dart';
import '../services/settings_store.dart';
import '../services/wms_capabilities_service.dart';
import '../services/wms_feature_info_service.dart';
import '../services/wms_tile_provider.dart';
import '../utils/epsg_utils.dart';
import '../widgets/study_list.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final http.Client _httpClient;
  late final SettingsStore _settings;
  late final WmsCapabilitiesService _capsService;
  late final WmsFeatureInfoService _featureInfoService;
  late final BoundaryService _boundaryService;
  final MapController _mapController = MapController();

  WmsCapabilities? _caps;
  List<WmsLayer> _studies = [];
  Map<String, String> _layerToStudy = {};
  Object? _capsError;
  bool _loadingCaps = true;
  bool _identifying = false;
  bool _mapReady = false;

  final Set<String> _enabledStudies = <String>{};
  final Set<String> _enabledLayers = <String>{};
  BasemapType _basemap = BasemapType.cartographic;

  @override
  void initState() {
    super.initState();
    _httpClient = http.Client();
    _settings = SettingsStore(widget.prefs);
    _capsService = WmsCapabilitiesService(
      httpClient: _httpClient,
      prefs: widget.prefs,
    );
    _featureInfoService = WmsFeatureInfoService(httpClient: _httpClient);
    _boundaryService = BoundaryService();
    _loadBoundary();
    _loadCapabilities();
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }

  Uri get _baseEndpointUri => Uri.parse(_settings.baseEndpoint);
  String get _mapPath => _settings.mapPath;

  List<String> get _activeLayers {
    final effective = <String>[];
    for (final layerName in _enabledLayers) {
      final studyName = _layerToStudy[layerName];
      if (studyName != null && _enabledStudies.contains(studyName)) {
        effective.add(layerName);
      }
    }
    effective.sort();
    return effective;
  }

  Future<void> _loadBoundary() async {
    await _boundaryService.load();
    if (mounted) {
      setState(() {});
      _zoomToBoundary();
    }
  }

  void _zoomToBoundary() {
    final bounds = _boundaryService.bounds;
    if (bounds != null && _mapReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(32),
          ),
        );
      });
    }
  }

  Future<void> _loadCapabilities({bool forceRefresh = false}) async {
    setState(() {
      _loadingCaps = true;
      _capsError = null;
    });
    try {
      final uri = WmsCapabilitiesService.buildCapabilitiesUri(
        baseEndpoint: _baseEndpointUri,
        mapPath: _mapPath,
      );
      final caps = await _capsService.load(
        capabilitiesUri: uri,
        forceRefresh: forceRefresh,
      );
      final studies = _extractStudies(caps.rootLayer);
      final layerToStudy = <String, String>{};
      for (final study in studies) {
        if (study.name == null) continue;
        for (final layer in study.children) {
          if (layer.name != null) {
            layerToStudy[layer.name!] = study.name!;
          }
        }
      }

      setState(() {
        _caps = caps;
        _studies = studies;
        _layerToStudy = layerToStudy;
        if (_enabledStudies.isEmpty) {
          _enabledStudies.addAll(AppConfig.defaultEnabledStudies);
        }
        if (_enabledLayers.isEmpty) {
          _enabledLayers.addAll(AppConfig.defaultEnabledLayers);
        }
      });
    } catch (e) {
      setState(() => _capsError = e);
    } finally {
      setState(() => _loadingCaps = false);
    }
  }

  List<WmsLayer> _extractStudies(WmsLayer root) {
    WmsLayer? depthGroup;

    void findDepth(WmsLayer layer) {
      if (layer.name == AppConfig.depthGroupName) {
        depthGroup = layer;
        return;
      }
      for (final child in layer.children) {
        findDepth(child);
        if (depthGroup != null) return;
      }
    }

    findDepth(root);
    return depthGroup?.children ?? [];
  }

  void _toggleStudy(String studyName, bool enabled) {
    setState(() {
      if (enabled) {
        _enabledStudies.add(studyName);
      } else {
        _enabledStudies.remove(studyName);
      }
    });
  }

  void _toggleLayer(String layerName, bool enabled) {
    setState(() {
      if (enabled) {
        _enabledLayers.add(layerName);
      } else {
        _enabledLayers.remove(layerName);
      }
    });
  }

  void _zoomTo(WmsLayer layer) {
    final bbox = layer.bbox3857;
    if (bbox == null) return;
    final sw = EpsgUtils.epsg3857ToLatLng(bbox.minx, bbox.miny);
    final ne = EpsgUtils.epsg3857ToLatLng(bbox.maxx, bbox.maxy);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(sw, ne),
        padding: const EdgeInsets.all(20),
      ),
    );
  }

  void _showBasemapSelector() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Select Basemap',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              for (final type in BasemapType.values)
                ListTile(
                  leading: Icon(
                    type == _basemap ? Icons.check_circle : Icons.circle_outlined,
                    color: type == _basemap
                        ? Theme.of(ctx).colorScheme.primary
                        : null,
                  ),
                  title: Text(type.label),
                  onTap: () {
                    setState(() => _basemap = type);
                    Navigator.pop(ctx);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _identify(TapPosition tapPosition, LatLng latLng) async {
    final active = _activeLayers;
    if (active.isEmpty) return;

    setState(() => _identifying = true);

    final size = MediaQuery.sizeOf(context);
    final width = size.width.round().clamp(256, 4096);
    final height = (size.height - kToolbarHeight).round().clamp(256, 4096);

    final bounds = _mapController.camera.visibleBounds;
    final sw = EpsgUtils.latLngToEpsg3857(bounds.southWest);
    final ne = EpsgUtils.latLngToEpsg3857(bounds.northEast);

    final i = tapPosition.relative?.dx.round() ?? (width ~/ 2);
    final j = tapPosition.relative?.dy.round() ?? (height ~/ 2);

    try {
      final json = await _featureInfoService.getFeatureInfo(
        baseEndpoint: _baseEndpointUri,
        mapPath: _mapPath,
        layerNames: active,
        bboxMinx: sw.$1,
        bboxMiny: sw.$2,
        bboxMaxx: ne.$1,
        bboxMaxy: ne.$2,
        width: width,
        height: height,
        i: i.clamp(0, width - 1),
        j: j.clamp(0, height - 1),
      );

      final pretty = WmsCapabilitiesService.toPrettyJson(json);

      if (!mounted) return;
      setState(() => _identifying = false);

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Feature Info',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: MediaQuery.of(ctx).size.height * 0.5,
                    child: SingleChildScrollView(
                      child: SelectableText(pretty),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _identifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Identify failed: $e')),
      );
    }
  }

  bool get _hasActiveLayers => _activeLayers.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final activeLayers = _activeLayers;
    final boundaryPolygons = _boundaryService.polygons;

    return Scaffold(
      appBar: AppBar(
        title: Text(_caps?.serviceTitle ?? 'Wimmera Flood Maps'),
        actions: [
          IconButton(
            tooltip: 'Select basemap',
            onPressed: _showBasemapSelector,
            icon: const Icon(Icons.layers),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Flood Studies',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${activeLayers.length} active',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: _buildDrawerContent()),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(-36.7, 142.2),
              initialZoom: 7,
              onTap: _identify,
              onMapReady: () {
                _mapReady = true;
                _zoomToBoundary();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _basemap.urlTemplate,
                userAgentPackageName: 'au.gov.vic.wcma.wfmc',
              ),
              if (activeLayers.isNotEmpty)
                TileLayer(
                  tileProvider: WmsTileProvider(
                    httpClient: _httpClient,
                    baseEndpoint: _baseEndpointUri,
                    mapPath: _mapPath,
                    layerNames: activeLayers,
                    imageFormat: 'image/png',
                    transparent: true,
                  ),
                  urlTemplate: 'wms://tile',
                  tileDimension: 256,
                ),
              if (boundaryPolygons.isNotEmpty)
                PolygonLayer(
                  polygons: boundaryPolygons
                      .map((points) => Polygon(
                            points: points,
                            color: Colors.transparent,
                            borderColor: Colors.black,
                            borderStrokeWidth: 2,
                          ))
                      .toList(),
                ),
            ],
          ),
          if (_hasActiveLayers)
            Positioned(
              top: 12,
              right: 12,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.asset('assets/legend.png'),
                ),
              ),
            ),
          if (_identifying)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Identifying...'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDrawerContent() {
    if (_loadingCaps) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_capsError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Failed to load layers',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SelectableText('$_capsError'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _loadCapabilities(forceRefresh: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    return StudyList(
      studies: _studies,
      enabledStudies: _enabledStudies,
      enabledLayers: _enabledLayers,
      onStudyToggled: _toggleStudy,
      onLayerToggled: _toggleLayer,
      onZoomTo: _zoomTo,
    );
  }
}
