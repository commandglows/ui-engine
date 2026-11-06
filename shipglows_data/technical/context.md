---
artifact: technical_context
metadata_schema_version: "1.0"
artifact_version: "2.0.0"
project: ShipGlows App Engine
created: "2026-10-22"
updated: "2026-11-06"
status: active
source_skill: sg-docs
scope: package-map
owner: Diane
confidence: high
risk_level: low
security_impact: none
docs_impact: yes
linked_systems:
  - ../../README.md
  - ../../flutter/
depends_on: []
supersedes: []
evidence:
  - "2026-10-22: package list from flutter/, consumers from the apps' pubspec.yaml path dependencies."
  - "2026-10-23: shipglows_onboarding added (eef4566, 5390abd), ReplayGlows consumer (5711efc)."
  - "2026-10-23: shipglows_sync added (2b6f624, 61a6d87); CommandGlows recorded as consumer of shipglows_sync, shipglows_settings and shipglows_settings_firestore (f0f6eeb9)."
  - "2026-10-31: shipglows_settings_firestore removed (suite auth lot 8, Firebase retired); CommandGlows uses shipglows_settings_convex since 2026-10-27."
  - "2026-10-23: ContentGlows (8f47c303, REST remote over /api/settings) and BeatGlows (15824f2, no account yet) consume shipglows_settings."
  - "2026-10-23: DreamGlows (6ba8566, PathTheme preset, mode and calendar zone) consumes shipglows_settings."
  - "2026-10-25: shipglows_updater added (WinSparkle on Windows from ContentGlows, verified sideloaded APK on Android, releases in a public shipglows-releases repository); no consumer yet, not run on a device."
  - "2026-10-23: shipglows_zoom added after its move from shipglows-email-engine (ea6ec1a); Ctrl+= / Ctrl+- / Ctrl+0 checked by the operator in CommandGlows."
  - "2026-10-26: shipglows_clerk_auth added from the CommandGlows Clerk OIDC spike (proven by the operator on Android and Windows); decision: Clerk is the single auth provider, one Clerk application per product."
  - "2026-10-26: shipglows_convex added (ConvexHttpClient over the HTTP API, no SDK); wire format checked against the installed convex 1.47.0 browser HTTP client (convex_encoded_json, args in a list, HTTP 560 for failed functions); no consumer yet, not run against a deployment."
  - "2026-10-27: shipglows_reviews added (6cfef27, 7e833aa, 1ca99e1); CommandGlows Windows sends reviews to Convex reviews:submit (commandglows ef9a3f31), a review sent from the app read back with reviews:listRecent on the dev deployment. Same pass: rows added for calendar, contact, demo, menu, metrics, organize, settings_convex, storage and xml (descriptions from their pubspec.yaml, consumers from path dependencies), shipglows_convex and shipglows_notification_center consumers refreshed."
  - "2026-10-31: shipglows_capture added (camera first: `camera` 0.12.2, `camera_windows` 0.3.0+1); ContentGlows camera screen compiled and running in the managed Windows debug session; recording not yet checked on a camera, Android not run."
  - "2026-10-31: shipglows_capture on a Galaxy S21 (ContentGlows managed Android debug session): preview, 720p video with sound, take handed to the app. Impeller Vulkan showed no camera preview there; consumers set `ImpellerBackend` `opengles` in the Android manifest."
  - "2026-10-31: Windows recording crashed the app in the AMD hardware H.264 encoder (division by zero, minidump) when camera_windows set no bitrate; the controller now passes `videoBitrate` on Windows. Then checked in ContentGlows with the Windows virtual camera of a phone: photo, 6.6 s 1280x720 H.264 at 6 Mb/s + AAC, no crash. No physical webcam tried yet."
  - "2026-11-06: packages moved to layers under a Dart workspace, repository renamed app-engine, sync and settings split into pure core packages, package list moved to the generated flutter/CATALOG.md. Layers checked by tool/check_layers.dart; every consumer resolved with flutter pub get."
next_review: "2027-01-22"
next_step: "Rerun tool/gen_catalog.dart when a package, or an app's use of one, changes."
---

# App Engine Context

Shared packages of the ShipGlows Flutter apps (Windows first).
Each package keeps its own dependencies, so an app pulls only what it uses.
Native code lives in the package's `windows/` plugin; elsewhere the packages
do nothing or fall back to plain Flutter.

## Packages

[`flutter/CATALOG.md`](../../flutter/CATALOG.md) is the generated list of packages, with their role, dependencies and consumers; each package has its own README. The layers and the rules between them are in the [root README](../../README.md).

## Cross-Package Contracts

`shipglows_rituals_core` and `shipglows_rituals` (2026-11-01) share human
rituals, separate from the background-job `shipglows_routines` scheduler.
The core is pure Dart with no dependencies: templates, snapshot pages,
questions/checklists, generic reference IDs, civil periods and JSON v1. Flutter
adds embeddable fields, cards, model/page dialogs, locale copy and shared-theme
spacing. DreamGlows is the first consumer; its Path adapter preserves existing
v1 reflection metadata and owns all storage, revisions, goals and Journal
behavior. Each app supplies content and persistence; no network or AI is
introduced. ContentGlows was inspected (five narrative categories plus synthesis
and approval) but is not migrated. Other apps are potential consumers, not
implemented integrations. See the two package READMEs for APIs and proof limits.

- Foreground handoff: `shipglows_tray` and `shipglows_hotkeys` events carry
  `previousForeground` (HWND), read natively before Dart runs;
  `ShipglowsCommandBarWindow.open(previousForeground:)` gives the keyboard
  back to that window when the bar closes.
- `WM_CLOSE`: `shipglows_tray` decides through Flutter's top-level window
  delegate; a runner's own shutdown handling must run after it.
- Window frame theme: `ShipglowsWindowFrame` (`followAppTheme`, on by
  default) sends the app brightness and title bar colors to DWM
  (`DWMWA_USE_IMMERSIVE_DARK_MODE`, `CAPTION_COLOR`, `TEXT_COLOR`) and
  resends them on a theme change. The runner must not reset them: drop the
  Flutter template's `UpdateTheme` on `WM_DWMCOLORIZATIONCOLORCHANGED`
  (done in DreamGlows); until then the frame reapplies after a Windows
  light/dark switch.
- Zoom: `ShipglowsWindowSession` owns the bounds (`minimumZoom`,
  `maximumZoom`) and the saved zoom; apps pass them to `FlutterZoomViewport`
  with `onZoomChanged: session.saveZoom`.

## Decisions

- 2026-11-06: one consumption mode, a path dependency on the sibling checkout, with `tool/provide-engines.sh` on single-repository hosts. Git dependencies and vendored copies are gone.
- 2026-11-06: `shipglows_ai` stays without consumer. The apps reach OpenRouter through their backend, so it duplicates nothing; it serves a future client-side use.
- 2026-11-06: an app's own diagnostics journal stays (scopes, product report). `shipglows_diagnostics` wraps its global handlers and adds the masked buffer and `crash.log`.

- `technical/contracts/tray-native-decision.md`: native Win32 tray instead of
  `tray_manager`.
