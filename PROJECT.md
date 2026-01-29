# WFMC — Wimmera Flood Map Client

## Purpose
WFMC is a **read-only** Flutter app (iOS / Android / Web) for viewing Wimmera flood maps served from the QGIS Server project in `wfma/wfma.qgs`.

## Source map service (WFMA / QGIS Server)
- **WMS GetCapabilities (public)**: `http://wimmera.xyz/?MAP=/var/www/qgis/wfma/wfma.qgs&SERVICE=WMS&REQUEST=GetCapabilities`
- **WMS base endpoint (per capabilities)**: `http://wimmera.xyz/qgis/?MAP=/var/www/qgis/wfma/wfma.qgs&...`
- **Service title**: “Wimmera Flood Maps”

### Verified capabilities (WMS 1.3.0)
From the live `GetCapabilities` response:
- **Operations**
  - **GetMap** formats: `image/png`, `image/jpeg` (plus png modes)
  - **GetLegendGraphic**: `image/png` supported
  - **GetFeatureInfo** formats include `application/json` / `application/geo+json` (plus html/text/xml)
- **CRS advertised**: `EPSG:3857`, `EPSG:4326`, `EPSG:7854`, `CRS:84`
- **Published layer tree shape**
  - `wfma` (root project layer)
  - `Depth` (group)
  - `{Area}` (group) e.g. `Concongella_2015`, `Dunmunkle_2017`, `HallsGap_2017`, `HorshamWartook_2017`, `MountWilliam_2014`, `Natimuk_2013`, `Stawell_2024`, `UpperWimmera_2014`, `WarracknabealBrim_2016`, `WimmeraRiverYarriambiackCreek_2010`, …
  - `{Raster}` (leaf) e.g. `Concongella_100y_d_Max`, `Dunm17RvDepthARI10`, etc.

## Key decisions (locked)
- **Map consumption**: **WMS raster** (read-only viewing).
- **Layer selection UX**: **Dynamic discovery** (fetch + parse `GetCapabilities` at runtime; build layer tree UI automatically).
- **iOS**: **No HTTP “hacks” / exceptions**. Boss will provide an **HTTPS** WMS base URL for iOS development.

## Technical approach (one best option)
### Map engine
Use **`flutter_map`** (cross-platform iOS/Android/Web) with:
- **Basemap** (optional but recommended): a standard Web Mercator basemap.
- **WMS overlay**: render selected WMS layer(s) as a tile overlay using **EPSG:3857**.

**Why EPSG:3857?**
- Aligns with common tiled basemaps.
- Avoids WMS 1.3.0 axis-order pitfalls with `EPSG:4326`.

### WMS request templates (to implement)
All requests include:
- `SERVICE=WMS`
- `VERSION=1.3.0`
- `MAP=/var/www/qgis/wfma/wfma.qgs`

**GetMap (tiled)**
- `REQUEST=GetMap`
- `LAYERS=<comma-separated layer names>`
- `STYLES=<matching styles or empty>`
- `FORMAT=image/png`
- `TRANSPARENT=true`
- `CRS=EPSG:3857`
- `WIDTH=256&HEIGHT=256`
- `BBOX=<tile bbox in EPSG:3857>`

**GetLegendGraphic**
- `REQUEST=GetLegendGraphic`
- `LAYER=<layer name>`
- `FORMAT=image/png`
- `STYLE=default`

**GetFeatureInfo (identify on tap)**
- `REQUEST=GetFeatureInfo`
- `INFO_FORMAT=application/geo+json` (or `application/json` if needed)
- `QUERY_LAYERS=<active layer(s)>`
- plus the usual `GetMap` params and click params (`I/J` for 1.3.0, sized to request image).

## UX scope
### Must-have screens / behaviors
- **Main map view**
  - Pan/zoom; show scale/coords optional
  - Toggle overlay visibility
- **Layer drawer**
  - Render the WMS layer tree (Depth → Area → Raster)
  - Search/filter by layer name
  - Default to **single active raster** (to protect server + keep UI simple); allow multi-select only if performance is acceptable
- **Zoom-to**
  - Use BoundingBox from capabilities for “zoom to layer/area”
- **Legend**
  - Show GetLegendGraphic for selected layer(s)
- **Identify**
  - Tap to query GetFeatureInfo; show results in a bottom sheet (read-only)

### Non-goals (for now)
- Editing, drawing, saving features
- Offline caching of map tiles
- Authentication / user accounts

## Performance constraints & guardrails
- Debounce map movement requests (avoid flooding WMS).
- Prefer PNG for transparency; allow JPEG toggle if performance requires.
- Cache `GetCapabilities` response locally with a “refresh” button.

## Development notes
- Expect two base URLs:
  - Android can use HTTP if needed
  - iOS development must use **HTTPS** endpoint provided by Boss
- Keep base URL configurable (e.g., build-time flavor or a simple settings screen), but avoid any iOS networking exceptions.

## Next step checklist (after Flutter scaffold exists)
1. Add `flutter_map` and required dependencies.
2. Implement WMS tiled overlay (EPSG:3857).
3. Implement capabilities fetch + XML parse into a layer tree model.
4. Build layer tree UI + selection state.
5. Add legend + identify.

