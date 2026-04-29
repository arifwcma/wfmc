# Google Play Publishing Todo

## Current state
- [x] App namespace `au.gov.vic.wcma.wfm`, version `1.0.3+4`
- [x] AndroidManifest permissions clean (INTERNET, FINE/COARSE LOCATION)
- [x] Launcher icon + adaptive icon + splash configured
- [x] Privacy policy HTML written
- [x] Store listing text drafted
- [x] `signingConfigs.release` block in `build.gradle.kts`

## To do

1. [ ] Set up **Google Play Developer account as Organisation (Wimmera CMA)** — USD $25, exempts us from 12-tester closed test
   - [ ] Linked Google payments profile (org legal name + address)
   - [ ] Authorised representative photo ID
   - [ ] D-U-N-S number for Wimmera CMA
2. [ ] Confirm `targetSdkVersion = 35` (Android 15) — mandatory since 31 Aug 2025
3. [ ] Generate upload keystore `.jks` and create `android/key.properties`
   - [ ] Back up keystore offline (losing it = can't update app)
4. [ ] Build signed App Bundle: `flutter build appbundle --release`
   - [ ] Enrol in Play App Signing on first upload
5. [ ] Store listing graphics
   - [x] App icon 512×512 PNG — `assets/app_icon_512.png`
   - [ ] Feature graphic 1024×500 PNG — open `assets/feature_graphic.png` and confirm it's exactly 1024×500. If not, we'll resize.
   - [x] Phone screenshots — `modified_screenshots/phone/` (6 files)
   - [x] 7" tablet screenshots — `modified_screenshots/tab_7_inch/` (4 files)
   - [x] 10" tablet screenshots — `modified_screenshots/tab_10_inch/` (5 files)
6. [ ] Data Safety form in Play Console
   - [ ] Declare device location (used in-app, not shared, optional)
   - [ ] Declare search text sent to Nominatim
   - [ ] Confirm no analytics, no PII
7. [ ] App content declarations
   - [ ] Privacy policy URL — verify `https://arifwcma.github.io/wfmc/privacy-policy.html` is live and reachable
   - [ ] Ads = none
   - [ ] Target age group
   - [ ] Content rating (IARC questionnaire)
   - [ ] News app = no
   - [ ] Government app = yes
   - [ ] COVID / financial / health = no
8. [ ] Government-app verification (evidence we represent Wimmera CMA — letterhead or `.gov.au` email)
9. [ ] Release track: internal test → production
10. [ ] iOS publishing (Apple Developer Program USD $99/year) — separate, out of scope here

## Backlog (post-launch / nice-to-have)

- [ ] Decide what to do with the **Historic River Gauges** base layer. Currently dropped (hidden via `AppConfig.hiddenBaseLayerNames`). Options to evaluate: keep dropped, surface only in an "advanced" toggle group, restyle to deprioritise visually vs current `River Gauges`, or merge with `River Gauges` server-side and indicate status (active/historic) by symbology.
- [ ] Re-incorporate the **Parcels** base layer efficiently. Currently dropped (hidden via `AppConfig.hiddenBaseLayerNames`) because rendering hundreds of thousands of parcel polygons through QGIS Server WMS is slow and produces huge tiles. Options to evaluate:
  - Pre-rendered raster XYZ pyramid for parcels (cheap to serve, no per-tile QGIS render).
  - Vector tiles (MVT) with client-side styling — flutter_map_vector or similar — far smaller payloads and crisp at any zoom.
  - Server-side caching (e.g. nginx `proxy_cache` or MapProxy) of the existing WMS tiles, given parcels rarely change.
  - Show parcels only above a minimum zoom level (e.g. z >= 14) so the heavy render only happens when the user is zoomed in.
