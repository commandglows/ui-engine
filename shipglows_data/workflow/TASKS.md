# UI Engine Tasks

## Open

- [ ] `shipglows_tray` in DreamGlows: add `ShipglowsTrayCloseSetting` to the settings panel once its pending rework is committed.
- [ ] `shipglows_tray`: wire CommandGlows after its command bar migration; operator to decide whether closing hides to the tray (it quits today).
- [ ] `shipglows_tray`: wire ContentGlows after its command bar migration; remove the tray part of `resident_shell` and `resident_shell_menu_test.cpp`, keep the hotkeys and the Auth0/shell-task gate.
- [ ] `shipglows_hotkeys`: no consumer yet.
- [ ] `shipglows_window` frame theme: in BeatGlows, CommandGlows, ContentGlows and the ShipGlows app, drop the template `UpdateTheme` on `WM_DWMCOLORIZATIONCOLORCHANGED` in `win32_window.cpp` (the frame already follows the app theme through `ShipglowsWindowFrame`).
- [ ] `shipglows_diagnostics`: migrate DreamGlows (`path_flutter/lib/src/crash_log.dart`, engine labels main/capture), then ContentGlows, CommandGlows, ReplayGlows (Sentry through `onReport`) and the ShipGlows app; add a « Copier le diagnostic » entry where the app has none.
- [ ] `shipglows_guide`: widget tests (progress, first-visit trigger, target placement); more ReplayGlows screens (Notes, Play) once the Feed pilot is validated.

## Done

- [x] 2026-10-23: `shipglows_guide` package (extracted from the ContentGlows guided tour): targets with spotlight and pulsing halo, card placed below, above or beside the target and never cut, one-step tips, first-visit trigger, app or scope routing. ContentGlows (4 steps, managed Windows session, demo mode) and ReplayGlows (Feed, managed web session, signed in) checked on screen.

- [x] 2026-10-22: `shipglows_window` frame follows the app theme (audit candidate 3): DWM dark mode, caption and text colors from `ShipglowsWindowFrame`, resent on theme change. DreamGlows pilot drops `ApplyWindowChrome` and `setWindowTheme` (the capture overlay keeps `setCaptureTheme`). Checked through `s` with Windows in dark: app light gives `DWMWA_USE_IMMERSIVE_DARK_MODE` 0 and a light frame, app dark gives 1 and a dark frame. Windows in light not tested (system setting).

- [x] 2026-10-22: `shipglows_diagnostics` package; BeatGlows pilot replaces `lib/core/diagnostics/crash_log.dart` (same `crash.log`), launched through `s start -FlutterDevice windows` (running, debug).

- [x] 2026-10-22: `shipglows_flutter_zoom` moved from `shipglows-email-engine/packages` to `flutter/`, same package name; the 6 consumers point to the new path. Ctrl+= / Ctrl+- added, `keyboardZoomStep` 0.05 (CommunityGlows reference).

- [x] 2026-10-22: DreamGlows on `shipglows_tray` (dreamglows d353882, ui-engine 3321ace): compiled and run through `s`, icon « DreamGlows » in the notification area, a second launch exits in 0.2 s and leaves one instance; menu checked by the operator; Quitter closes cleanly after the shutdown crash fix (2d88ef7), checked by the operator; the X opens the close-or-hide dialog (c27961e, dreamglows 8d700e8), checked by the operator.

- [x] 2026-10-22: `shipglows_tray` package (5a49efe, 7f2fbd3) and decision record `technical/contracts/tray-native-decision.md`.
