---
artifact: technical_context
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: ShipGlows UI Engine
created: "2026-10-22"
updated: "2026-10-22"
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
next_review: "2027-01-22"
next_step: "Update the consumer column when an app adopts or drops a package."
---

# UI Engine Context

Shared interface components for the ShipGlows Flutter apps (Windows first).
Each package keeps its own dependencies, so an app pulls only what it uses.
Native code lives in the package's `windows/` plugin; elsewhere the packages
do nothing or fall back to plain Flutter.

## Packages

| Package | Role | Native | Consumers (2026-10-22) |
| --- | --- | --- | --- |
| `shipglows_command_bar` | Command palette widget (`CommandBarView`, sections, filters, recents) | no | BeatGlows, CommandGlows, ContentGlows, DreamGlows, ReplayGlows |
| `shipglows_flutter_zoom` | App-wide zoom (`FlutterZoomViewport`): Ctrl+wheel, pinch, Ctrl+= / Ctrl+- / Ctrl+0; moved from `shipglows-email-engine` | no | BeatGlows, CommandGlows, ContentGlows, DreamGlows, ShipGlows app, email-engine `source_sidebar_flutter` |
| `shipglows_window` | Custom title bar and window chrome (`window_manager`) | via plugin dep | BeatGlows, CommandGlows, ContentGlows, DreamGlows, ShipGlows app |
| `shipglows_overlay_window` | Independent always-on-top windows with their own engine | Win32 | ContentGlows (direct), the command bar window |
| `shipglows_command_bar_window` | The command bar in a floating overlay window | through overlay | BeatGlows, CommandGlows, ContentGlows, DreamGlows |
| `shipglows_hotkeys` | System-wide hotkeys, saved choices, conflicts reported | Win32 | none yet |
| `shipglows_tray` | Notification area icon, standard menu, close-to-tray, single instance | Win32 | none yet |
| `shipglows_diagnostics` | Crash net: `FlutterError.onError` + `PlatformDispatcher.onError` chained, masked event buffer, « Copier le diagnostic » report, optional `crash.log` (256 KB, `.1` rotation, engine label); Sentry stays in the app via `onReport` | no | BeatGlows |

## Cross-Package Contracts

- Foreground handoff: `shipglows_tray` and `shipglows_hotkeys` events carry
  `previousForeground` (HWND), read natively before Dart runs;
  `ShipglowsCommandBarWindow.open(previousForeground:)` gives the keyboard
  back to that window when the bar closes.
- `WM_CLOSE`: `shipglows_tray` decides through Flutter's top-level window
  delegate; a runner's own shutdown handling must run after it.
- Zoom: `ShipglowsWindowSession` owns the bounds (`minimumZoom`,
  `maximumZoom`) and the saved zoom; apps pass them to `FlutterZoomViewport`
  with `onZoomChanged: session.saveZoom`.

## Decisions

- `technical/contracts/tray-native-decision.md`: native Win32 tray instead of
  `tray_manager`.
