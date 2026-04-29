# WFMC — Wimmera Flood Maps Client

## Purpose
WFMC is a **read-only** Flutter app (iOS / Android / Web) for viewing Wimmera flood maps served from the QGIS Server project `pozi_base.qgs`.

## Source map service (Pozi Base / QGIS Server)
- **Endpoint**: `https://pozi.wcma.work/ows/`
- **Map path**: `/var/www/qgis_projects/pozi_base/pozi_base.qgs`
- **WMS GetCapabilities (public)**: `https://pozi.wcma.work/ows/?MAP=/var/www/qgis_projects/pozi_base/pozi_base.qgs&SERVICE=WMS&REQUEST=GetCapabilities`
- **Service title / root layer Name**: `WCMA`

### Layer structure (server is source of truth)
```
WCMA (root)
├── <Study> Flood Depths            ← any child whose Name ends with " Flood Depths"
│   ├── <Study> 0.5% (1 in 200yr)
│   ├── <Study> 1% (1 in 100yr)     ← default-on (substring "1% (1 in 100")
│   ├── <Study> 2% (1 in 50yr)
│   ├── ...
│   └── <Study> 20% (1 in 5yr)
└── Base Layers (group)
    ├── Flood Investigation Study Areas   ← keyword visible=true → default-on
    ├── Rivers and Streams
    ├── Wetlands
    ├── River Gauges
    ├── Historic River Gauges
    ├── Parcels
    └── Wimmera CMA Boundary              ← hidden in UI; rendered locally from GeoJSON
```

### Studies present today
- Concongella 2015 Flood Depths
- Dunmunkle 2017 Flood Depths
- Halls Gap 2017 Flood Depths
- Horsham Wartook 2019 Flood Depths
- Lower Wimmera 2016 Flood Depths
- Mt William 2014 Flood Depths
- Natimuk 2013 Flood Depths
- Stawell 2024 Flood Depths
- Upper Wimmera 2014 Flood Depths
- Warracknabeal Brim 2015 Flood Depths
- Wimmera River Yarriambiack Creek 2010 Flood Depths

## UI Specification

### Startup behavior
- Load WCMA boundary from `assets/wcma_boundary.geojson`
- Zoom to fit WCMA boundary
- Display boundary as black border with transparent fill
- Fetch WMS Capabilities, derive studies and base layers, apply runtime defaults

### Layer panel (bottom sheet)
- Show **studies** at the first level (display name = Server Name minus ` Flood Depths`)
- Show **layers** under each study at the second level (collapsed by default)
- A separate **Base Layers** section follows the studies (also collapsed by default)
- **GIS-style visibility** for studies: a child layer is only visible on the map if BOTH:
  - The layer checkbox is checked
  - The parent study checkbox is checked
- Base layers are independent toggles (no parent gating)

### Default selections (computed at runtime)
- **All studies enabled**
- For each study, every child layer whose Name contains `1% (1 in 100` is enabled
- Base layers: only those marked with the `visible=true` keyword on the server (currently just `Flood Investigation Study Areas`)

### Map view
- OpenStreetMap basemap (or ArcGIS World Imagery via basemap selector)
- WCMA boundary overlay (black border, transparent fill) from local GeoJSON
- WMS overlay for active layers (EPSG:3857)
- Tap to identify (GetFeatureInfo)
- Legend panel — only shown when at least one depth layer is active
- Home button to zoom back to WCMA boundary

### Identify panel
- Features whose layer belongs to a study: grouped under the study, shows depth in metres + "For more info see Final Report" link
- Features from base layers: grouped per layer, shows generic key/value attributes

## Technical details

### WMS parameters
- VERSION: 1.3.0
- CRS: EPSG:3857
- FORMAT: image/png
- TRANSPARENT: TRUE
- INFO_FORMAT (identify): application/geo+json

### Dependencies
- flutter_map (map rendering)
- http (network requests)
- xml (capabilities parsing)
- shared_preferences (caching, settings)
- latlong2 (coordinates)
- geolocator (GPS)
- url_launcher, share_plus (external links / share)
- path_provider (tile cache directory)

## File structure
```
lib/
├── main.dart
├── config/
│   ├── app_config.dart        (server convention constants, basemap, org info)
│   └── study_metadata.dart    (StudyReports: study Name → report URL + display-name helper)
├── models/
│   ├── bookmark.dart
│   └── wms_models.dart        (WmsLayer, WmsBBox, WmsCapabilities)
├── screens/
│   ├── home_screen.dart       (main UI)
│   └── about_screen.dart
├── services/
│   ├── boundary_service.dart  (WCMA boundary GeoJSON loader)
│   ├── settings_store.dart    (WMS endpoint defaults)
│   ├── wms_capabilities_service.dart
│   ├── wms_feature_info_service.dart
│   ├── wms_tile_provider.dart
│   ├── tile_cache.dart        (+ _io / _stub conditional imports)
│   ├── http_client_factory.dart (+ _io / _stub)
│   ├── geocoding_service.dart (Nominatim)
│   ├── location_service.dart  (geolocator wrapper)
│   └── bookmark_service.dart
├── utils/
│   └── epsg_utils.dart        (coordinate conversions)
└── widgets/
    ├── study_list.dart        (studies + base-layers UI)
    └── place_search_delegate.dart

assets/
└── wcma_boundary.geojson      (WCMA catchment boundary)
```
