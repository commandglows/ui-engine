---
artifact: technical_context
metadata_schema_version: "1.0"
artifact_version: "1.3.0"
project: ShipGlows UI Engine
created: "2026-10-22"
updated: "2026-10-23"
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
  - "2026-10-23: ContentGlows (8f47c303, REST remote over /api/settings) and BeatGlows (15824f2, no account yet) consume shipglows_settings."
  - "2026-10-23: DreamGlows (6ba8566, PathTheme preset, mode and calendar zone) consumes shipglows_settings."
  - "2026-10-23: shipglows_flutter_zoom added after its move from shipglows-email-engine (ea6ec1a); Ctrl+= / Ctrl+- / Ctrl+0 checked by the operator in CommandGlows."
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
| `shipglows_window` | Custom title bar and window chrome (`window_manager`); the Windows frame (dark mode, caption and text colors) follows the app theme through DWM FFI | via plugin dep, DWM FFI | BeatGlows, CommandGlows, ContentGlows, DreamGlows, ShipGlows app |
| `shipglows_overlay_window` | Independent always-on-top windows with their own engine | Win32 | ContentGlows (direct), the command bar window |
| `shipglows_command_bar_window` | The command bar in a floating overlay window | through overlay | BeatGlows, CommandGlows, ContentGlows, DreamGlows |
| `shipglows_hotkeys` | System-wide hotkeys, saved choices, conflicts reported | Win32 | none yet |
| `shipglows_tray` | Notification area icon, standard menu, close-or-hide dialog, launch at sign-in, single instance | Win32 | DreamGlows |
| `shipglows_diagnostics` | Crash net: `FlutterError.onError` + `PlatformDispatcher.onError` chained, masked event buffer (repeats merged), report with app sections (`addSection`), optional `crash.log` (256 KB, `.1` rotation, engine label); widgets `ShipglowsDiagnosticsButton` (header/error view), `ShipglowsDiagnosticsPanel` (settings: copy, view, open log folder, clear), preview dialog; version from `appBuildName`/`appBuildNumber`; Sentry stays in the app via `onReport` | no | BeatGlows |
| `shipglows_sync` | Device-to-account sync ported from CommunityGlows: `SyncStatus` (needsReview, unreachable…), `reconcileSnapshots` (union, conflicts chosen device/account), `SyncRecovery` copies, `SyncProgress`, widgets (chip, issue banner, review dialog/prompt, progress overlay, recovery panel), `SyncStrings` FR/EN; `rewriteSyncIds` / `holdsTemporaryId` for records created offline | no | CommandGlows, ContentGlows (settings) |
| `shipglows_settings` | Typed user settings (`SettingKey`, `SettingsSchema` + migrations), device-first `SettingsController`, per-field push, per-account device copies, retry with backoff, first-sync review and recovery copies through `shipglows_sync`, nested map fields merged one by one (`SettingKey.map`, `setField`), fields waiting for an offline record's server id (`isTemporaryId`, `rewriteIds`), `SecretStore`, several windows on watched files (`WatchableSettingsStorage`, `reload`); remote and storage are ports | no | BeatGlows (local only), CommandGlows, ContentGlows, DreamGlows (local only, all windows) |
| `shipglows_settings_firestore` | `SettingsRemote` over one Firestore document per account (`users/{uid}/settings/profile`) | via plugin dep | CommandGlows |
| `shipglows_guide` | In-app guidance: tours across routes, coach marks on a `GuideTarget` (spotlight, « try it »), one-step tips, first-visit `GuideTrigger`, progress in a `GuideStore`, navigation through app or scope callbacks; extracted from the ContentGlows guided tour | no | ContentGlows (publish tour, legacy `inapp_tour_*` keys), ReplayGlows (Feed coach marks) |
| `shipglows_onboarding` | First-run introduction: two-column card of `OnboardingPage`s (language, welcome, features, access) with previews, segmented progress bar, narrow single-column layout, per-account `OnboardingGate` over an `OnboardingCompletionStore`, `OnboardingThemeData`; extracted from the ReplayGlows introduction | no | ReplayGlows (web; key `onboarding_completed:v1:<user>`) |

## Cross-Package Contracts

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

- `technical/contracts/tray-native-decision.md`: native Win32 tray instead of
  `tray_manager`.
