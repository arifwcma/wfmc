# Handoff for the next agent

You are picking up the **Wimmera Flood Maps** Flutter project mid-flight. Read this once, then start. Estimated 5 min.

## 0. Read these first (in order)

1. `.cursor/rules/instructions.mdc` — Arif's standing rules. Non-negotiable. Highlights:
   - Be brief. Wrong answers worse than slow.
   - No comments in code (no inline, no block, no docstrings).
   - Minimal parameters; hard-code constants over parameterising.
   - Readability > cleverness.
   - Suggest one option, not multiple — ask if more wanted.
   - Address him as **Arif**, **Boss**, or **Ostad**.
   - He likes responses prefixed `R1, R2, ...` (I did not in this session and he didn't push back; use your judgment).
2. `.cursor/rules/server-config.mdc` — full server architecture, IPs, paths, container layout, layer hierarchy on `pozi_base.qgs`, rate-limit notes, CORS, TLS. **Keep this file updated** every time a new server fact is learned (Arif explicitly asked for this).
3. `PROJECT.md` — app architecture, runtime defaults, file structure.
4. `todo.md` — Google Play publishing checklist + post-launch backlog.

## 1. Standing operational rules Arif gave me

1. **`commit always followed by push`** — never commit and stop. Always push to `origin/master` afterwards.
2. **Update server-config.mdc automatically** whenever a useful new server fact surfaces. Don't ask permission, just do it.
3. **Brief by default.** Long explanations only when asked.
4. **Single recommendation** — propose one path, ask before listing alternatives.
5. **Never write code in Ask mode.** Tell him to switch to Agent and stop.

## 2. Server access (works, tested)

```powershell
ssh -i C:\Users\m.rahman\assets\keys\Playground1.pem ubuntu@16.176.28.146
```

`ubuntu` for SSH; everything app-related lives under `/home/ssm-user/apps/` (owned by `ssm-user`, requires `sudo` from the `ubuntu` shell). Docker is invoked via `sudo docker ...` from `ubuntu`. Reverse-proxy and QGIS-server are containers; see `server-config.mdc` for the full layout.

I have direct SSH from this workstation; you can run patches on the live server through the shell tool.

## 3. What we shipped today (current `master`, all pushed)

1. **Migration from old `wimmera.xyz` WMS to new `pozi.wcma.work`** with new `MAP=/var/www/qgis_projects/pozi_base/pozi_base.qgs`.
2. **Capabilities cache key bumped to `v3`** (`wms_capabilities_service.dart`) — old `v2` cached the typo'd `Mitigtion` layer and a flat tree.
3. **Recursive layer extraction** — server now wraps everything under a `WCMA` group; studies are at depth 2. `_extractStudies` and `_extractBaseLayers` walk the tree.
4. **Per-layer `TileLayer` ("Option A")** — replaced the single combined GetMap with one `TileLayer` per active layer. Toggling now adds/removes one layer; cache hits stick across toggles. `WmsTileProvider` now takes `layerName: String` (singular).
5. **`AppConfig.hiddenBaseLayerNames`** is a `Set<String>` of base layers we deliberately hide from the UI: `Wimmera CMA Boundary`, `Parcels`, `Historic River Gauges`. To hide more, just add to the Set.
6. **Server-side**: rate limit on `qgis` zone disabled (was `20r/m` typo, killing tile traffic); CORS header added (`Access-Control-Allow-Origin: *`) on both `:80` and `:443` `pozi.wcma.work` blocks. Backups at `/home/ssm-user/apps/reverse-proxy/nginx/conf.d/default.conf.bak.*`.

## 4. Gotchas I tripped over — don't repeat

1. **Never percent-encode `/` in the WMS `MAP=` parameter.** Dart's `Uri.replace(queryParameters:)` does this and the upstream WAF returns `403`. Always build URIs through `lib/utils/wms_uri.dart::buildWmsUri()` which un-encodes `%2F` back to `/`.
2. **Never set `tileDimension` and `tileSizePx` to 512.** `flutter_map`'s tile-coordinate addressing desyncs from our BBOX builder and you'll request tiles for the North Atlantic. Both stay at `256`. Note in `server-config.mdc`'s "Client expectations" section.
3. **Capabilities are cached in `SharedPreferences`.** When server-side layer names change, bump the cache key (`v3 → v4`) in `wms_capabilities_service.dart`, otherwise existing installs use stale layer names.
4. **`hiddenBaseLayerName` is a `Set` now**, not a single string. Old Read tool searches for the singular form will mislead you.
5. **GetMap with multiple layers** fails entire-request if any one layer name doesn't exist server-side (`HTTP 400 LayerNotDefined`). With Option A this is moot per-layer, but worth knowing for `GetFeatureInfo` (which still bundles).
6. **Server has only 1 FCGI worker** (`spawn-fcgi` default), with 2 parallel render threads. Client-side `_requestPool = Pool(2)` matches that. Don't push concurrency much higher without bumping the server.

## 5. What's next on Arif's list

`todo.md` is authoritative. The big remaining publish blockers:

1. Generate upload keystore + `android/key.properties`, build signed AAB.
2. Confirm `targetSdkVersion = 35`.
3. Verify `https://arifwcma.github.io/wfmc/privacy-policy.html` is reachable.
4. Data Safety form, App Content declarations, Government-app verification in Play Console.
5. Backlog: `Parcels` re-incorporation (XYZ pyramid / vector tiles / cached WMS), `Historic River Gauges` decision.

## 6. Useful sanity commands

Live tile log:

```bash
sudo docker logs -f --tail 0 nginx-reverse-proxy 2>&1 | grep --line-buffered "pozi.wcma.work"
```

Status-code roll-up over recent traffic:

```bash
sudo docker logs --tail 1000 nginx-reverse-proxy 2>&1 | grep "pozi.wcma.work" | awk '{print $9}' | sort | uniq -c | sort -rn
```

Hammer test (rate-limit / health):

```bash
URL='https://pozi.wcma.work/ows/?MAP=/var/www/qgis_projects/pozi_base/pozi_base.qgs&SERVICE=WMS&REQUEST=GetCapabilities'
for i in $(seq 1 30); do curl -ks -o /dev/null -w '%{http_code}\n' "$URL" & done | sort | uniq -c
```

Smoke-launch the app on Pixel 9a (already booted as `emulator-5554`):

```powershell
flutter run -d emulator-5554 --no-pub
```

Stop a backgrounded Flutter run:

```powershell
taskkill /PID <pid> /T /F
```

## 7. Final note

Arif moves fast and trusts you to act. He prefers you SSH and patch the server live over giving him commands to copy-paste, **once you've explained the diagnosis and proposed change in one short paragraph**. He confirms with one word ("go") and then expects it done — backup, validate, reload, verify, update `server-config.mdc`. Don't break that loop.

Good luck, Boss.
