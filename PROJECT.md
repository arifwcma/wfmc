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

### Layer panel (drawer)
- Show **studies** (children of "Depth" group) at the first level
- Show **layers** (children of each study) at the second level
- All studies **expanded by default**
- Support **multi-select** (multiple layers can be active simultaneously)
- Checkbox on study toggles all its child layers

### Default selected layers (on startup)
One 100-year layer per study:
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
- WMS overlay for selected layers (EPSG:3857)
- Tap to identify (GetFeatureInfo)
- Legend panel (toggle visibility)

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
│   └── app_config.dart        (default layers, constants)
├── models/
│   └── wms_models.dart        (WmsLayer, WmsBBox, WmsCapabilities)
├── screens/
│   └── home_screen.dart       (main UI)
├── services/
│   ├── settings_store.dart    (endpoint configuration)
│   ├── wms_capabilities_service.dart
│   ├── wms_feature_info_service.dart
│   └── wms_tile_provider.dart
├── utils/
│   └── epsg_utils.dart        (coordinate conversions)
└── widgets/
    ├── legend_card.dart
    ├── status_chip.dart
    └── study_list.dart        (layer selection UI)
```
