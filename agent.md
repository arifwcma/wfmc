# Handoff — Base Layer Performance Work (`wfmc_dev` branch)

You are picking up performance work on the Wimmera Flood Maps Flutter app. Goal of this branch: **gracefully bring back Wetlands, Rivers and Streams, and ideally Parcels as base layers without compromising flood-layer loading speed.** They are currently hidden in the app because live WMS rendering of those layers is too slow on the current server.

Read `.cursor/rules/instructions.mdc`, `.cursor/rules/server-config.mdc`, `.cursor/for_next_agent.md`, `PROJECT.md`, `todo.md` first. This file is supplementary context for the base-layer task specifically.

## 1. The problem we just diagnosed

Symptom Arif reported: when a user enables a base layer (especially Wetlands or Rivers and Streams), and then enables a flood-depth layer, the flood layer takes very long to load. Sometimes it doesn't appear until all base tiles finish.

Diagnosed root causes (live SSH measurements on `pozi.wcma.work`):

1. **Server: only 1 FCGI worker** by default in the `qgis-server` container. Every WMS GetMap is processed serially by that one process. A heavy Wetlands tile (~1.1s cold render) blocks every subsequent tile request.
2. **Client: shared `Pool(2)` was FIFO** — base tiles enqueued first starved later flood tiles.
3. **Bundled `LAYERS=`** — the previous code joined all enabled depth layers into a single `LAYERS=a,b,c` GetMap, and same for base layers. This made every tile a multi-layer render.

Per-layer cold-render times measured today (single tile, Wimmera bbox):

| Layer | Time |
|---|---|
| Wetlands | 1.15 s |
| Rivers and Streams | 0.89 s |
| Flood Investigation Study Areas | 0.024 s |
| River Gauges | 0.020 s |
| Concongella 1% (1 in 100yr) flood | 0.018 s |

Same tile cached: ~7 ms (nginx `fastcgi_cache` is on, 30-min TTL, 400 MB).

## 2. What was changed today (already on `master`, pulled into this branch)

Commits in chronological order:

1. `a0f5c50` — tagged as **`good_version`** (pre-experiment baseline; safe rollback target).
2. `9a8f717` — un-bundled base layers into one `TileLayer` per layer, set `Pool(6)` → `Pool(2)`.
3. `777ce5d` — split client request pool: `_depthPool = Pool(2)`, `_basePool = Pool(1)`. Flood layers always have dedicated client slots.
4. `da430ac` — server-config doc update for 2-FCGI-worker change (see #5 below).
5. `1bdd34c` — added `Wetlands` and `Rivers and Streams` to `AppConfig.hiddenBaseLayerNames` (current state — those layers are hidden in the app).

Server-side change applied live (not in git, see backups under `/home/ssm-user/apps/qgis-server/`):

- Replaced container's baked-in `/usr/local/bin/start-xvfb-nginx.sh` via bind-mount to a custom version that uses `spawn-fcgi -F 2`. Two FCGI workers now run in parallel.
- Verified: while a 1.1 s Wetlands render is in flight on worker 1, a parallel flood tile completes on worker 2 in 27 ms.
- Memory: ~2.4 GiB free, healthy.
- Backups: `compose.yaml.bak.20260504-001202`, `start-xvfb-nginx.sh.bak.20260504-001202`.

## 3. Why the heavy layers are still hidden

Even with all of the above, base-layer loading was still painful for the user:

- `_basePool = Pool(1)` serialises base tiles client-side → 12 visible Wetlands tiles × ~1.1 s = ~13 s wall time to fully render the screen.
- Bumping `_basePool` to `Pool(2)` would halve that, but at the cost of up to a 1.1 s wait for any flood tile when both server workers are busy on base.

Arif's call: hide them for now, fix gracefully on this branch. Flood-layer responsiveness is non-negotiable.

## 4. What "gracefully" means here

The user wants Wetlands, Rivers and Streams, and probably Parcels back in the app, **fast**, **without** any visible regression in flood-layer loading. Live QGIS WMS rendering of those layers on this 2-CPU box can never be fast enough — they are CPU-bound vector renders. The fix is architectural.

### Recommended path (single, in priority order)

**Pre-render the heavy layers as a static XYZ tile pyramid and serve them from `xyz.wcma.work`.** Already a deployed Next.js XYZ tile server in your stack, currently unused by WFMC. Take Wetlands/Rivers/Parcels from ~1.1 s/tile down to ~10 ms/tile. No recurring cost.

Steps the next agent should consider:

1. Generate the tile pyramid offline (zoom 7–18 over WCMA boundary). Two viable tools:
   - QGIS desktop "Generate XYZ tiles (Directory)" processing tool — uses the same styling as the live `pozi_base.qgs`.
   - `gdal2tiles.py` if rendering from raw raster.
2. Output structure: `<layer>/{z}/{x}/{y}.png` — standard XYZ.
3. Push the directory tree to the `xyz` container's served path (inspect `/home/ssm-user/apps/xyz/` to confirm it can be a passthrough static file server, or extend it).
4. In the Flutter app, treat the pre-rendered layer differently from a live WMS layer: a normal `flutter_map` `TileLayer` with `urlTemplate: 'https://xyz.wcma.work/wetlands/{z}/{x}/{y}.png'` rather than a `WmsTileProvider`.
5. Remove the layer name from `AppConfig.hiddenBaseLayerNames` once it is wired through `xyz.wcma.work`.
6. Keep `Wimmera CMA Boundary` and `Historic River Gauges` handling unchanged — they are different concerns.

### Alternative paths (less recommended, but documented)

- **Vector tiles (MVT) with client-side styling.** Smaller payloads, crisp at every zoom, but requires `flutter_map_vector_tile` or similar and more code.
- **Server-side caching only.** Bumping `fastcgi_cache_valid 30m` → `7d` and `max_size 400m` → `2g`. Helps repeat traffic, but the first user to view any tile still waits ~1.1 s. Better as a complement to pre-rendering, not a replacement.
- **EC2 upgrade.** A `c7i.xlarge` (4 vCPU, 8 GiB) lets you run 4 FCGI workers and cuts each render time by ~30%. Costs ~US$130/month and only buys ~2× speed-up for the heavy layers. Pre-rendering gives ~100× for free.

## 5. Code map

Files you will care about:

- `lib/config/app_config.dart` — `hiddenBaseLayerNames`, study/base group names, default-on substring.
- `lib/screens/home_screen.dart` — `_extractBaseLayers` (line ~245), the two TileLayer blocks for base/depth (line ~924), how toggling drives state.
- `lib/services/wms_tile_provider.dart` — top-level `_depthPool` / `_basePool`, `WmsTileProvider`, `WmsNetworkImage`, retry policy.
- `lib/services/wms_capabilities_service.dart` — capabilities cache key (`v3`); bump if server layer names change.
- `lib/utils/wms_uri.dart` — keep `MAP=` un-encoded.

## 6. Server quick reference

```powershell
ssh -i C:\Users\m.rahman\assets\keys\Playground1.pem ubuntu@16.176.28.146
```

- App data lives under `/home/ssm-user/apps/` — needs `sudo` from `ubuntu`.
- QGIS-server compose: `/home/ssm-user/apps/qgis-server/`.
- XYZ container compose: `/home/ssm-user/apps/xyz/`.
- Reverse-proxy nginx vhosts: `/home/ssm-user/apps/reverse-proxy/nginx/conf.d/default.conf`.

Useful one-liners:

```bash
sudo docker exec qgis-server ps -ef | grep fcgi
sudo docker logs --tail 200 nginx-reverse-proxy 2>&1 | grep pozi.wcma.work
```

Time a single layer render (replace LAYER as needed):

```bash
URL='https://pozi.wcma.work/ows/?MAP=/var/www/qgis_projects/pozi_base/pozi_base.qgs&SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&STYLES=&FORMAT=image/png&TRANSPARENT=TRUE&CRS=EPSG:3857&WIDTH=256&HEIGHT=256&BBOX=15829000,-4406000,15848000,-4387000&LAYERS=Wetlands'
curl -sk -o /dev/null -w 'time=%{time_total}s code=%{http_code}\n' "$URL"
```

## 7. Standing rules from Arif

Repeating from `instructions.mdc` so you do not have to context-switch:

1. Be brief. Wrong answers worse than slow.
2. No comments in code (none, including docstrings).
3. Minimal parameters; hard-code constants.
4. One recommendation at a time, ask before listing alternatives.
5. Prefix replies `R1, R2, ...`.
6. Address him as **Arif**, **Boss**, or **Ostad**.
7. Commit per atomic change, always followed by `git push`.
8. Update `.cursor/rules/server-config.mdc` automatically when a new server fact surfaces.
9. Never write code in Ask mode — tell him to switch to Agent and stop.

## 8. Rollback

Pre-experiment baseline tag: `good_version` (commit `a0f5c50`). To wipe everything from this base-layer work:

```powershell
git reset --hard good_version
git push --force-with-lease
```

Server rollback (revert to single FCGI worker):

```bash
cd /home/ssm-user/apps/qgis-server
sudo cp start-xvfb-nginx.sh.bak.20260504-001202 start-xvfb-nginx.sh
sudo docker compose up -d --force-recreate
```

Good luck, Boss.
