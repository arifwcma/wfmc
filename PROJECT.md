# WFMC — Wimmera Flood Map Client

## Purpose
WFMC is a **read-only** Flutter app (iOS / Android / Web) for viewing Wimmera flood maps served from the QGIS Server project in `wfma/wfma.qgs`.

## Source map service (WFMA / QGIS Server)
- **WMS GetCapabilities (public)**: `https://wimmera.xyz/qgis/?MAP=/var/www/qgis/wfma/wfma.qgs&SERVICE=WMS&REQUEST=GetCapabilities`
- **Service title**: "Wimmera Flood Maps"

### Layer structure
```
wfma (root)
└── Depth (group)
    ├── Concongella_2015 (study)
    │   ├── Concongella_100y_d_Max
    │   ├── Concongella_10y_d_Max
    │   └── ...
    ├── Dunmunkle_2017 (study)
    ├── HallsGap_2017 (study)
    ├── HorshamWartook_2017 (study)
    ├── MountWilliam_2014 (study)
    ├── Natimuk_2013 (study)
    ├── Stawell_2024 (study)
    ├── UpperWimmera_2014 (study)
    ├── WarracknabealBrim_2016 (study)
    └── WimmeraRiverYarriambiackCreek_2010 (study)
```

## UI Specification

### Startup behavior
- Load WCMA boundary from `assets/wcma_boundary.geojson`
- Zoom to fit WCMA boundary
- Display boundary as black border with transparent fill

### Layer panel (drawer)
- Show **studies** (children of "Depth" group) at the first level
- Show **layers** (children of each study) at the second level
- All studies **expanded by default**
- **GIS-style visibility**: A layer is only visible on the map if BOTH:
  - The layer checkbox is checked
  - The parent study checkbox is checked
- Study checkbox controls study visibility (not child layers)

### Default selections (on startup)
**Studies enabled:**
- All 10 studies enabled by default

**Layers enabled (one 100-year layer per study):**
- Concongella_100y_d_Max
- Dunm17RvDepthARI100
- HGAP17RvDepthARI100
- Hors19RvDepthARI100
- MTW_E01_100Y_050_D_MAX
- dep_100y
- Stawell24RvDepthARI100
- StawellG24RvDepthARI100
- UW_E01_100y_052_D_Max_g007.50
- WaBr15Dep100
- 100y_existing_flood_depths

### Map view
- OpenStreetMap basemap
- WCMA boundary overlay (black border, transparent fill)
- WMS overlay for active layers (EPSG:3857)
- Tap to identify (GetFeatureInfo)
- Legend panel (toggle visibility)
- Home button to zoom back to WCMA boundary

## Technical details

### WMS parameters
- VERSION: 1.3.0
- CRS: EPSG:3857
- FORMAT: image/png
- TRANSPARENT: TRUE

### Dependencies
- flutter_map (map rendering)
- http (network requests)
- xml (capabilities parsing)
- shared_preferences (caching)
- latlong2 (coordinates)

## File structure
```
lib/
├── main.dart
├── config/
│   └── app_config.dart        (default studies/layers, constants)
├── models/
│   └── wms_models.dart        (WmsLayer, WmsBBox, WmsCapabilities)
├── screens/
│   └── home_screen.dart       (main UI)
├── services/
│   ├── boundary_service.dart  (WCMA boundary GeoJSON loader)
│   ├── settings_store.dart    (endpoint configuration)
│   ├── wms_capabilities_service.dart
│   ├── wms_feature_info_service.dart
│   └── wms_tile_provider.dart
├── utils/
│   └── epsg_utils.dart        (coordinate conversions)
└── widgets/
    ├── legend_card.dart
    ├── status_chip.dart
    └── study_list.dart        (GIS-style layer selection UI)

assets/
└── wcma_boundary.geojson      (WCMA catchment boundary)
```
