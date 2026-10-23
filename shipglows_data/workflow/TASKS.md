# UI Engine Tasks

## Open

- [ ] `shipglows_tray` in DreamGlows: add `ShipglowsTrayCloseSetting` to the settings panel once its pending rework is committed.
- [ ] `shipglows_tray`: wire CommandGlows after its command bar migration; operator to decide whether closing hides to the tray (it quits today).
- [ ] `shipglows_tray`: wire ContentGlows after its command bar migration; remove the tray part of `resident_shell` and `resident_shell_menu_test.cpp`, keep the hotkeys and the Auth0/shell-task gate.
- [ ] `shipglows_hotkeys`: no consumer yet.
- [ ] `shipglows_window` frame theme: in BeatGlows, CommandGlows, ContentGlows and the ShipGlows app, drop the template `UpdateTheme` on `WM_DWMCOLORIZATIONCOLORCHANGED` in `win32_window.cpp` (the frame already follows the app theme through `ShipglowsWindowFrame`).
- [ ] `shipglows_diagnostics`: migrate DreamGlows (`path_flutter/lib/src/crash_log.dart`, engine labels main/capture), then ContentGlows, CommandGlows, ReplayGlows (Sentry through `onReport`, their Sentry/auth/backend lines through `addSection`) and the ShipGlows app; put `ShipglowsDiagnosticsPanel` in each settings page and `ShipglowsDiagnosticsButton` in error views.
- [ ] `shipglows_diagnostics` in BeatGlows: operator to check the header bug button (copy, check mark) and the « Voir le diagnostic » command.
- [ ] `shipglows_guide`: widget tests (progress, first-visit trigger, target placement); more ReplayGlows screens (Notes, Play) once the Feed pilot is validated.
- [ ] `shipglows_onboarding`: push ui-engine (operator approval), then pin ReplayGlows `app/pubspec.lock` on that commit and drop its local `pubspec_overrides.yaml`.
- [ ] `shipglows_onboarding`: migrate the CommunityGlows Flutter introduction (`communityglows/flutter/lib/features/onboarding/`, language → welcome → account → access; keep its `communityglows.ios.onboarding.v1` state or map it to the gate); widget tests (gate scope/replay, skip to last page, narrow layout).
- [ ] `shipglows_sync` in CommandGlows: check on screen the review dialog (first sign-in on a device whose settings differ from the account), the progress overlay and a recovery restore. The account page panel was checked on 2026-10-23 (signed-in account, « Synchronisé », French tooltip date, manual sync from the chip).
- [ ] `shipglows_sync`: adopt it in the other apps using account settings (CommunityGlows Flutter `features/sync/cloud_sync.dart`, ContentGlows, DreamGlows), then for business data through `SyncSnapshot.collections`.
- [ ] `shipglows_sync`: unit tests of `reconcileSnapshots`, `SyncProgress` and the controller review/recovery (on operator request).

## Done

- [x] 2026-10-23: `shipglows_sync` package ported from CommunityGlows (review of device vs account at first sync, recovery copies, `needsReview` / `unreachable`, first-sync progress, shared widgets FR/EN); `shipglows_settings` builds on it. CommandGlows wired (account page panel, review prompt and progress above the routes); managed Windows debug session running.

- [x] 2026-10-23: `shipglows_onboarding` package (eef4566), extracted from the ReplayGlows introduction; progress bar shrinks to the card on phones (5390abd). ReplayGlows (5711efc) checked in the managed web session, signed in, at 1440 px and 375 px: replay from Preferences, language pick, skip, finish, completion key kept. Android and Windows not run.

- [x] 2026-10-23: `shipglows_guide` package (extracted from the ContentGlows guided tour): targets with spotlight and pulsing halo, card placed below, above or beside the target and never cut, one-step tips, first-visit trigger, app or scope routing. ContentGlows (4 steps, managed Windows session, demo mode) and ReplayGlows (Feed, managed web session, signed in) checked on screen.

- [x] 2026-10-22: `shipglows_window` frame follows the app theme (audit candidate 3): DWM dark mode, caption and text colors from `ShipglowsWindowFrame`, resent on theme change. DreamGlows pilot drops `ApplyWindowChrome` and `setWindowTheme` (the capture overlay keeps `setCaptureTheme`). Checked through `s` with Windows in dark: app light gives `DWMWA_USE_IMMERSIVE_DARK_MODE` 0 and a light frame, app dark gives 1 and a dark frame. Windows in light not tested (system setting).

- [x] 2026-10-22: `shipglows_diagnostics` package; BeatGlows pilot replaces `lib/core/diagnostics/crash_log.dart` (same `crash.log`), launched through `s start -FlutterDevice windows` (running, debug). 2026-10-23: copy button, settings panel and preview dialog added after a survey of the 6 apps; BeatGlows gets a header button and two command-bar entries (Aide).

- [x] 2026-10-22: `shipglows_flutter_zoom` moved from `shipglows-email-engine/packages` to `flutter/`, same package name; the 6 consumers point to the new path. Ctrl+= / Ctrl+- added, `keyboardZoomStep` 0.05 (CommunityGlows reference); Ctrl+= / Ctrl+- / Ctrl+0 checked by the operator in CommandGlows run through `s`.

- [x] 2026-10-22: DreamGlows on `shipglows_tray` (dreamglows d353882, ui-engine 3321ace): compiled and run through `s`, icon « DreamGlows » in the notification area, a second launch exits in 0.2 s and leaves one instance; menu checked by the operator; Quitter closes cleanly after the shutdown crash fix (2d88ef7), checked by the operator; the X opens the close-or-hide dialog (c27961e, dreamglows 8d700e8), checked by the operator.

- [x] 2026-10-22: `shipglows_tray` package (5a49efe, 7f2fbd3) and decision record `technical/contracts/tray-native-decision.md`.
