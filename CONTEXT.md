# Project ecosystem and current status

Companion to `PROJECT.md`. PROJECT.md = what wfmc is. This file = how it fits with the other repos and where things stand today.

## 1. Repos and their roles

1. **`wfmc`** (this repo, branch `master`) — production Flutter app shipped to users. Read-only flood-map viewer.
2. **`wfmc_dev`** (separate working folder, same GitHub remote, branch `wfmc_dev`) — scratch branch for experiments. After every successful change-set we merge `wfmc_dev` → `master` and force the two to be identical. Today both branches sit at the same commit.
3. **`pozi_base`** (QGIS desktop project) — source of truth for layer styling and grouping. Published as `pozi_base.qgs` on the QGIS Server container at `https://pozi.wcma.work/ows/`. wfmc consumes this via WMS.
4. **`base_layers`** (separate repo, server at `https://baselayers.wcma.work/`) — static PMTiles host. Vector base layers (`rivers_and_streams`, `wetlands`, `wparcel`, `river_gauges`) are exported once via tippecanoe + go-pmtiles and served as static `.pmtiles` files. Replaces live WMS for these heavy layers.
5. **`wimmera_parcels`** (QGIS project) — desktop project used to prepare the Wimmera parcels source data that feeds `base_layers/data/wparcel/`.
6. **`playground_details`** — unrelated to wfmc. Out of scope here.

## 2. Server stack (single EC2 box, `13.55.191.184`)

1. `qgis-server` container — runs the WMS for `pozi_base.qgs`. 2 FCGI workers (custom `start-xvfb-nginx.sh` bind-mounted, see `agent.md`).
2. `baselayers` container — nginx serving `tiles/*.pmtiles` with CORS + Range. Reverse-proxied at `https://baselayers.wcma.work`.
3. `xyz` container — already deployed Next.js XYZ tile server. Currently unused by wfmc. Reserved for future raster-XYZ pre-rendering.
4. `nginx-reverse-proxy` — terminates TLS for `pozi.wcma.work`, `baselayers.wcma.work`, `xyz.wcma.work`.

SSH: `ssh -i C:\Users\m.rahman\assets\keys\Playground1.pem ubuntu@13.55.191.184`. App data lives under `/home/ssm-user/apps/`, needs `sudo` from `ubuntu`.

## 3. Base-layer migration — current status

Goal: bring `Rivers and Streams`, `Wetlands`, `Parcels` back into the app without slowing the flood layers.

History (most recent last):
1. Originally these three rendered live via WMS from `pozi_base`. Too slow — each tile is ~1 s of CPU.
2. Hidden in the app via `AppConfig.hiddenBaseLayerNames` (WMS-derived layer name filter).
3. Re-exported as PMTiles into the new `base_layers` repo and pointed wfmc at `https://baselayers.wcma.work` via `vector_map_tiles_pmtiles`.
4. Performance still poor on device. Diagnosed root cause: not the server. Range works correctly. The Flutter package `vector_map_tiles_pmtiles` calls `archive.tile()` one tile at a time (no batching), and the on-device vector renderer is CPU-bound for `wparcel`.
5. **Today**: the three PMTiles layers are hidden again, this time via the new `AppConfig.hiddenPmtilesLayerIds = {'rivers_and_streams','wetlands','wparcel'}`. `PmTilesBaseLayers.visible` is the filtered list both consumers in `home_screen.dart` use. The PMTiles plumbing stays in place, the layers are simply not surfaced.

## 4. Open follow-ups

1. Decide between two proper fixes for the heavy base layers:
   1. Pre-render to static raster XYZ tiles via QGIS, serve from the existing `xyz.wcma.work`. Lowest app-side risk — just a `flutter_map` `TileLayer` with a `urlTemplate`. Same widget already used for WMS.
   2. Migrate the whole map widget from `flutter_map` to the `maplibre` package (native MapLibre SDK, GPU vector rendering, parallel tile fetch). Higher reward, much higher rewrite cost — touches WMS depth layers, gestures, controls.
2. Once #1 lands and is verified, remove the relevant ID from `hiddenPmtilesLayerIds` (or stop loading PMTiles for that layer entirely).
3. Stale entries in `hiddenBaseLayerNames` (`Wetlands`, `Rivers and Streams`, `Parcels`) are harmless leftovers from the WMS era; clean up only if unrelated WMS work touches that file.

## 5. Conventions

1. Edits flow on `wfmc_dev` → merge to `master` → push both branches to the same commit.
2. wfmc and wfmc_dev folders should sit at the same git commit at end of every session.
3. `pozi_base`, `base_layers`, `wimmera_parcels` are owned out-of-band by the GIS workflow, not by app changes.
