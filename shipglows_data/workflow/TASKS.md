# UI Engine Tasks

## Open

- [ ] `shipglows_tray` in DreamGlows: add `ShipglowsTrayCloseSetting` to the settings panel once its pending rework is committed.
- [ ] `shipglows_tray`: wire CommandGlows after its command bar migration; operator to decide whether closing hides to the tray (it quits today).
- [ ] `shipglows_tray`: wire ContentGlows after its command bar migration; remove the tray part of `resident_shell` and `resident_shell_menu_test.cpp`, keep the hotkeys and the Auth0/shell-task gate.
- [ ] `shipglows_hotkeys`: no consumer yet.

## Done

- [x] 2026-10-22: DreamGlows on `shipglows_tray` (dreamglows d353882, ui-engine 3321ace): compiled and run through `s`, icon « DreamGlows » in the notification area, a second launch exits in 0.2 s and leaves one instance; menu checked by the operator; Quitter closes cleanly after the shutdown crash fix (2d88ef7), checked by the operator; the X opens the close-or-hide dialog (c27961e, dreamglows 8d700e8), checked by the operator.

- [x] 2026-10-22: `shipglows_tray` package (5a49efe, 7f2fbd3) and decision record `technical/contracts/tray-native-decision.md`.
