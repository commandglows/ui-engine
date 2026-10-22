# UI Engine Tasks

## Open

- [ ] `shipglows_tray`: wire DreamGlows (`windows_app` runner + `packages/path_flutter` agenda), run through `s`, prove icon, menu, close-to-tray, quit with orderly shutdown, second launch. Waiting on the DreamGlows command bar session, which edits the same files.
- [ ] `shipglows_tray`: wire CommandGlows after its command bar migration; operator to decide whether closing hides to the tray (it quits today).
- [ ] `shipglows_tray`: wire ContentGlows after its command bar migration; remove the tray part of `resident_shell` and `resident_shell_menu_test.cpp`, keep the hotkeys and the Auth0/shell-task gate.
- [ ] `shipglows_tray`: first compile on Windows (package not built yet).
- [ ] `shipglows_hotkeys`: no consumer yet.

## Done

- [x] 2026-10-22: `shipglows_tray` package (5a49efe, 7f2fbd3) and decision record `technical/contracts/tray-native-decision.md`.
