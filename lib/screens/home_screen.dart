import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/wms_models.dart';
import '../services/settings_store.dart';
import '../services/wms_capabilities_service.dart';
import '../services/wms_feature_info_service.dart';
import '../services/wms_tile_provider.dart';
import '../utils/epsg_utils.dart';
import '../widgets/legend_card.dart';
import '../widgets/status_chip.dart';
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
  final MapController _mapController = MapController();

  WmsCapabilities? _caps;
  List<WmsLayer> _studies = [];
  Object? _capsError;
  bool _loadingCaps = true;
  bool _identifying = false;

  final Set<String> _enabledLayerNames = <String>{};
  bool _showLegend = false;

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
    _loadCapabilities();
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }

  Uri get _baseEndpointUri => Uri.parse(_settings.baseEndpoint);
  String get _mapPath => _settings.mapPath;
  List<String> get _activeLayers => _enabledLayerNames.toList()..sort();

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
      
      setState(() {
        _caps = caps;
        _studies = studies;
        if (_enabledLayerNames.isEmpty) {
          _enabledLayerNames.addAll(AppConfig.defaultSelectedLayers);
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

  void _toggleLayer(String layerName, bool enabled) {
    setState(() {
      if (enabled) {
        _enabledLayerNames.add(layerName);
      } else {
        _enabledLayerNames.remove(layerName);
      }
    });
  }

  void _zoomTo(WmsLayer layer) {
    final bbox = layer.bbox3857;
    if (bbox == null) return;
    final (cx, cy) = bbox.center;
    final center = EpsgUtils.epsg3857ToLatLng(cx, cy);
    final zoom = EpsgUtils.zoomFromSpanMeters(bbox.span);
    _mapController.move(center, zoom);
  }

  Future<void> _openSettings() async {
    final baseCtrl = TextEditingController(text: _settings.baseEndpoint);
    final mapCtrl = TextEditingController(text: _settings.mapPath);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Settings',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: baseCtrl,
                decoration: const InputDecoration(
                  labelText: 'WMS base endpoint',
                  hintText: 'https://wimmera.xyz/qgis/',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mapCtrl,
                decoration: const InputDecoration(
                  labelText: 'MAP path',
                  hintText: '/var/www/qgis/wfma/wfma.qgs',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () async {
                    await _settings.setBaseEndpoint(baseCtrl.text.trim());
                    await _settings.setMapPath(mapCtrl.text.trim());
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _loadCapabilities(forceRefresh: true);
                  },
                  child: const Text('Save & refresh'),
                ),
              ),
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

  @override
  Widget build(BuildContext context) {
    final activeLayers = _activeLayers;

    return Scaffold(
      appBar: AppBar(
        title: Text(_caps?.serviceTitle ?? 'Wimmera Flood Maps'),
        actions: [
          IconButton(
            tooltip: 'Refresh layers',
            onPressed: _loadingCaps
                ? null
                : () => _loadCapabilities(forceRefresh: true),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
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
                      '${activeLayers.length} selected',
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
              initialCenter: const LatLng(-36.7, 142.6),
              initialZoom: 8,
              onTap: _identify,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
            ],
          ),
          if (activeLayers.isNotEmpty && _showLegend)
            Positioned(
              right: 12,
              bottom: 12,
              child: LegendCard(
                title: 'Legend',
                layers: activeLayers,
                legendUrlFor: (layerName) =>
                    WmsCapabilitiesService.buildLegendUri(
                      baseEndpoint: _baseEndpointUri,
                      mapPath: _mapPath,
                      layerName: layerName,
                    ).toString(),
                onClose: () => setState(() => _showLegend = false),
              ),
            ),
          Positioned(
            left: 12,
            bottom: 12,
            child: StatusChip(
              text: activeLayers.isEmpty
                  ? 'No layers selected'
                  : '${activeLayers.length} layer${activeLayers.length == 1 ? '' : 's'} active',
              icon: activeLayers.isEmpty ? Icons.layers_clear : Icons.layers,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => setState(() => _showLegend = !_showLegend),
        label: Text(_showLegend ? 'Hide legend' : 'Show legend'),
        icon: const Icon(Icons.map),
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
      enabledLayerNames: _enabledLayerNames,
      onLayerToggled: _toggleLayer,
      onZoomTo: _zoomTo,
    );
  }
}
