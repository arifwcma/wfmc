import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../config/study_metadata.dart';
import '../models/bookmark.dart';
import '../models/wms_models.dart';
import '../screens/about_screen.dart';
import '../services/bookmark_service.dart';
import '../services/boundary_service.dart';
import '../services/geocoding_service.dart';
import '../services/http_client_factory.dart';
import '../services/location_service.dart';
import '../services/settings_store.dart';
import '../services/wms_capabilities_service.dart';
import '../services/wms_feature_info_service.dart';
import '../services/wms_tile_provider.dart';
import '../utils/epsg_utils.dart';
import '../widgets/place_search_delegate.dart';
import '../widgets/study_list.dart';

// ---------------------------------------------------------------------------
// Helper: parsed result from GetFeatureInfo
// ---------------------------------------------------------------------------

class _IdentifyResult {
  const _IdentifyResult({
    required this.layerName,
    this.studyName,
    this.studyInfo,
    this.depth,
  });

  final String layerName;
  final String? studyName;
  final StudyInfo? studyInfo;
  final double? depth;
}

// ---------------------------------------------------------------------------
// Home screen
// ---------------------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ---- Services ----------------------------------------------------------
  late final http.Client _httpClient;
  late final SettingsStore _settings;
  late final WmsCapabilitiesService _capsService;
  late final WmsFeatureInfoService _featureInfoService;
  late final BoundaryService _boundaryService;
  late final BookmarkService _bookmarkService;
  late final GeocodingService _geocodingService;
  final LocationService _locationService = LocationService();
  final MapController _mapController = MapController();

  // ---- State -------------------------------------------------------------
  WmsCapabilities? _caps;
  List<WmsLayer> _studies = [];
  Map<String, String> _layerToStudy = {};
  Object? _capsError;
  bool _loadingCaps = true;
  bool _identifying = false;
  bool _mapReady = false;

  Set<String> _enabledStudies = <String>{};
  Set<String> _enabledLayers = <String>{};
  BasemapType _basemap = BasemapType.cartographic;

  LatLng? _userLocation;
  bool _locating = false;
  double _sheetPixelHeight = 0;
  int _cameraSettleCount = 0;
  bool _showHint = true;

  // ---- Lifecycle ---------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _httpClient = createHttpClient();
    _settings = SettingsStore(widget.prefs);
    _capsService = WmsCapabilitiesService(
      httpClient: _httpClient,
      prefs: widget.prefs,
    );
    _featureInfoService = WmsFeatureInfoService(httpClient: _httpClient);
    _boundaryService = BoundaryService();
    _bookmarkService = BookmarkService(widget.prefs);
    _geocodingService = GeocodingService(httpClient: _httpClient);
    _loadBoundary();
    _loadCapabilities();
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }

  // ---- Getters -----------------------------------------------------------

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

  bool get _hasActiveLayers => _activeLayers.isNotEmpty;

  // ---- Data loading ------------------------------------------------------

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
        if (mounted) setState(() => _cameraSettleCount++);
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
        _cameraSettleCount++;
        if (_enabledStudies.isEmpty) {
          _enabledStudies = Set<String>.from(AppConfig.defaultEnabledStudies);
        }
        if (_enabledLayers.isEmpty) {
          _enabledLayers = Set<String>.from(AppConfig.defaultEnabledLayers);
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

  // ---- Layer management --------------------------------------------------

  void _toggleStudy(String studyName, bool enabled) {
    final newSet = Set<String>.from(_enabledStudies);
    if (enabled) {
      newSet.add(studyName);
    } else {
      newSet.remove(studyName);
    }
    setState(() => _enabledStudies = newSet);
  }

  void _toggleLayer(String layerName, bool enabled) {
    final newSet = Set<String>.from(_enabledLayers);
    if (enabled) {
      newSet.add(layerName);
    } else {
      newSet.remove(layerName);
    }
    setState(() => _enabledLayers = newSet);
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
                    type == _basemap
                        ? Icons.check_circle
                        : Icons.circle_outlined,
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

  // ---- Feature info (reworked) -------------------------------------------

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

      if (!mounted) return;
      setState(() => _identifying = false);

      final features =
          (json['features'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      if (features.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No flood data at this location')),
        );
        return;
      }

      // Parse each feature into a structured result.
      final results = <_IdentifyResult>[];
      for (final feature in features) {
        final id = feature['id'] as String? ?? '';
        final layerName =
            id.contains('.') ? id.substring(0, id.lastIndexOf('.')) : id;
        final props = feature['properties'] as Map<String, dynamic>? ?? {};

        double? depth;
        for (final entry in props.entries) {
          double? parsed;
          if (entry.value is num) {
            parsed = (entry.value as num).toDouble();
          } else if (entry.value is String) {
            parsed = double.tryParse(entry.value as String);
          }
          if (parsed != null && parsed > 0) {
            depth = parsed;
            break;
          }
        }

        final studyName = _layerToStudy[layerName];
        final studyInfo =
            studyName != null ? StudyMetadata.studies[studyName] : null;

        if (depth == null) continue;

        results.add(_IdentifyResult(
          layerName: layerName,
          studyName: studyName,
          studyInfo: studyInfo,
          depth: depth,
        ));
      }

      await _showIdentifyResults(results, latLng);
    } catch (e) {
      if (!mounted) return;
      setState(() => _identifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Identify failed: $e')),
      );
    }
  }

  Future<void> _showIdentifyResults(
      List<_IdentifyResult> results, LatLng latLng) async {
    // Group results by study so report link appears once per study.
    final grouped = <String, List<_IdentifyResult>>{};
    final ungrouped = <_IdentifyResult>[];
    for (final r in results) {
      if (r.studyName != null) {
        (grouped[r.studyName!] ??= []).add(r);
      } else {
        ungrouped.add(r);
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Flood Information',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final entry in grouped.entries) ...[
                          if (entry.value.first.studyInfo != null) ...[
                            Text(
                              '${entry.value.first.studyInfo!.displayName} '
                              '${entry.value.first.studyInfo!.completionYear}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            for (final r in entry.value)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${r.layerName}: ${r.depth!.toStringAsFixed(2)} m',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => launchUrl(
                                Uri.parse(
                                    entry.value.first.studyInfo!.reportUrl),
                                mode: LaunchMode.externalApplication,
                              ),
                              child: Text(
                                'For more info see Final Report',
                                style: TextStyle(
                                  color: Theme.of(ctx).colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                          const Divider(),
                        ],
                        for (final r in ungrouped) ...[
                          Text(
                            r.layerName,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                              'Flood depth: ${r.depth!.toStringAsFixed(2)} m'),
                          const Divider(),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _saveBookmark(latLng);
                  },
                  icon: const Icon(Icons.bookmark_add),
                  label: const Text('Save this location'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---- Location (Locate Me) ---------------------------------------------

  Future<void> _locateMe() async {
    setState(() => _locating = true);
    try {
      final location = await _locationService.getCurrentLocation();
      if (!mounted) return;

      if (location == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Could not get your location. Check permissions & GPS.')),
        );
        return;
      }

      setState(() => _userLocation = location);
      _mapController.move(location, 14);
      _autoSelectClosestStudy(location);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location error: $e')),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _autoSelectClosestStudy(LatLng userLocation) {
    if (_studies.isEmpty) return;

    String? closestStudy;
    final closestLayers = <String>{};
    double closestDist = double.infinity;

    for (final study in _studies) {
      if (study.name == null || study.bbox3857 == null) continue;
      final center = study.bbox3857!.center;
      final centerLatLng = EpsgUtils.epsg3857ToLatLng(center.$1, center.$2);
      final dist = _distanceSq(userLocation, centerLatLng);
      if (dist < closestDist) {
        closestDist = dist;
        closestStudy = study.name;
        closestLayers.clear();
        final meta = StudyMetadata.studies[study.name!];
        if (meta != null) {
          closestLayers.addAll(meta.layers100yr);
        }
      }
    }

    if (closestStudy != null && closestLayers.isNotEmpty) {
      setState(() {
        _enabledStudies = {closestStudy!};
        _enabledLayers = Set<String>.from(closestLayers);
      });
    }
  }

  double _distanceSq(LatLng a, LatLng b) {
    final dLat = a.latitude - b.latitude;
    final dLng = a.longitude - b.longitude;
    return dLat * dLat + dLng * dLng;
  }

  // ---- Bookmarks ---------------------------------------------------------

  Future<void> _saveBookmark(LatLng location) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Location'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'e.g. My house',
          ),
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;

    final bookmark = Bookmark(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      latitude: location.latitude,
      longitude: location.longitude,
      zoom: _mapController.camera.zoom,
      createdAt: DateTime.now(),
    );
    await _bookmarkService.save(bookmark);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved "${bookmark.name}"')),
    );
  }

  void _showBookmarks() {
    final bookmarks = _bookmarkService.getAll();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Saved Locations',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (bookmarks.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No saved locations yet'),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.4,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: bookmarks.length,
                    itemBuilder: (_, i) {
                      final b = bookmarks[i];
                      return Dismissible(
                        key: ValueKey(b.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          color: Colors.red,
                          padding: const EdgeInsets.only(right: 16),
                          child:
                              const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          _bookmarkService.delete(b.id);
                        },
                        child: ListTile(
                          leading: const Icon(Icons.bookmark),
                          title: Text(b.name),
                          subtitle: Text(
                            '${b.latitude.toStringAsFixed(4)}, '
                            '${b.longitude.toStringAsFixed(4)}',
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _mapController.move(
                              LatLng(b.latitude, b.longitude),
                              b.zoom,
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ---- Share -------------------------------------------------------------

  void _shareView() {
    final center = _mapController.camera.center;
    final zoom = _mapController.camera.zoom.toStringAsFixed(1);
    final text = 'Check out flood risk in the Wimmera region!\n\n'
        'Location: ${center.latitude.toStringAsFixed(5)}, '
        '${center.longitude.toStringAsFixed(5)} (zoom $zoom)\n'
        'https://www.google.com/maps/@${center.latitude},${center.longitude},${zoom}z';
    Share.share(text);
  }

  // ---- Search ------------------------------------------------------------

  Future<void> _openSearch() async {
    final location = await showSearch<LatLng?>(
      context: context,
      delegate: PlaceSearchDelegate(geocodingService: _geocodingService),
    );
    if (location != null) {
      _mapController.move(location, 14);
    }
  }

  // ---- Build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_sheetPixelHeight == 0) {
      _sheetPixelHeight =
          MediaQuery.sizeOf(context).height * _sheetInitial;
    }
    final activeLayers = _activeLayers;
    final boundaryPolygons = _boundaryService.polygons;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Wimmera Flood Maps',
          style: TextStyle(
            fontSize: MediaQuery.sizeOf(context).width < 400 ? 16 : 20,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Search location',
            onPressed: _openSearch,
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Share',
            onPressed: _shareView,
            icon: const Icon(Icons.share),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'basemap':
                  _showBasemapSelector();
                case 'bookmarks':
                  _showBookmarks();
                case 'about':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AboutScreen()),
                  );
                case 'feedback':
                  launchUrl(
                    Uri.parse(
                      'mailto:${AppConfig.contactEmail}'
                      '?subject=${Uri.encodeComponent(AppConfig.feedbackSubject)}',
                    ),
                  );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'basemap', child: Text('Select basemap')),
              PopupMenuItem(
                  value: 'bookmarks', child: Text('Saved locations')),
              PopupMenuDivider(),
              PopupMenuItem(
                  value: 'about', child: Text('About Wimmera CMA')),
              PopupMenuItem(
                  value: 'feedback', child: Text('Send feedback')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(-36.7, 142.2),
              initialZoom: 7,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: _identify,
              onMapReady: () {
                _mapReady = true;
                _zoomToBoundary();
              },
            ),
            children: [
              TileLayer(
                key: ValueKey('${_basemap}_$_cameraSettleCount'),
                urlTemplate: _basemap.urlTemplate,
                userAgentPackageName: 'au.gov.vic.wcma.wfm',
              ),
              if (activeLayers.isNotEmpty)
                TileLayer(
                  key: ValueKey('${activeLayers.join(",")}_$_cameraSettleCount'),
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
              if (_userLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userLocation!,
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(
                                blurRadius: 4, color: Colors.black26),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          // Legend card
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
          // Identifying overlay
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
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
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
          // Locate me button
          Positioned(
            right: 12,
            bottom: _sheetPixelHeight + (_showHint ? 52 : 8),
            child: ElevatedButton.icon(
              onPressed: _locating ? null : _locateMe,
              icon: _locating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, size: 18),
              label: Text(
                'Show my location',
                style: TextStyle(
                  fontSize: MediaQuery.sizeOf(context).width < 400 ? 11 : 13,
                ),
              ),
            ),
          ),
          // First-use hint
          if (_showHint)
            Positioned(
              left: 16,
              right: 16,
              bottom: _sheetPixelHeight + 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Select the flood map you would like to view from the list below',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: MediaQuery.sizeOf(context).width < 400 ? 12 : 14,
                  ),
                ),
              ),
            ),
          // Persistent layers sheet
          _buildPersistentSheet(),
        ],
      ),
    );
  }

  // ---- Persistent layers sheet (UI1) --------------------------------------

  static const double _sheetInitial = 0.25;
  static const double _sheetMin = 0.05;
  static const double _sheetMax = 0.70;

  Widget _buildPersistentSheet() {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _sheetPixelHeight =
                  notification.extent * MediaQuery.sizeOf(context).height;
              _showHint = false;
            });
          }
        });
        return false;
      },
      child: DraggableScrollableSheet(
        initialChildSize: _sheetInitial,
        minChildSize: _sheetMin,
        maxChildSize: _sheetMax,
        snap: true,
        snapSizes: const [_sheetMin, _sheetInitial, 0.45],
        builder: (ctx, scrollController) {
          return Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.58),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              boxShadow: const [
                BoxShadow(blurRadius: 10, color: Colors.black26),
              ],
            ),
            child: _buildLayerContent(scrollController),
          );
        },
      ),
    );
  }

  Widget _buildLayerContent(ScrollController scrollController) {
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
      scrollController: scrollController,
    );
  }
}
