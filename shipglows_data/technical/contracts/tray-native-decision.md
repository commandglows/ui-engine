---
artifact: technical_decision_record
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: ShipGlows UI Engine
created: "2026-10-22"
updated: "2026-10-22"
status: active
source_skill: sg-docs
scope: tray-implementation-route
owner: Diane
confidence: medium
risk_level: medium
security_impact: none
docs_impact: yes
linked_systems:
  - ../../../flutter/shipglows_tray/
  - ../../../README.md
  - ../context.md
  - ../../workflow/TASKS.md
depends_on: []
supersedes: []
evidence:
  - "2026-10-22: read-only inventory of contentglows/app, commandglows/commandglows_app, dreamglows/windows_app, shipglows_app/app, beatglows/app_flutter and gocharbon runners."
  - "2026-10-22: tray_manager 0.8.0 source read on GitHub (nativeapi core: WinUI 3 menus through the Windows App SDK, legacy icon events, no foreground capture)."
  - "Operator decision, 2026-10-22: « Bah évidemment, on va faire du natif. »"
  - "Package committed 5a49efe and 7f2fbd3; not compiled nor run yet."
next_review: "2027-01-22"
next_step: "Wire DreamGlows first, run it through s and prove icon, menu, close-to-tray, quit and second launch."
---

# Decision: a native Win32 tray, shared in `shipglows_tray`

## Status

Selected by the operator on 2026-10-22. Package written; no app wired yet,
nothing compiled or run.

## Decision

The notification area icon of every ShipGlows desktop app comes from
`flutter/shipglows_tray`, a Win32 plugin written in house, not from
`tray_manager` (pub.dev, community package).

Why:

1. The command bar needs the window that was in front before the click.
   Only native code reading it at the click can provide it; `tray_manager`
   does not expose it.
2. Each click goes through Dart in `tray_manager`, and its Windows 11 style
   menu needs the Windows App SDK runtime.
3. `tray_manager` is pre-1.0 and rewrote its API in 0.7.
4. Keyboard selection on the icon, close-to-tray and single instance are not
   covered by it.
5. The three apps that have a tray already use native code; the package
   factors the most complete one (ContentGlows' `resident_shell`).

The Dart API stays platform-neutral: macOS or Linux can later be implemented
behind it, possibly on `tray_manager`.

## Inventory before migration (2026-10-22)

| | ContentGlows | CommandGlows | DreamGlows |
| --- | --- | --- | --- |
| Code | `windows/runner/resident_shell.cpp` | tray part of `windows/runner/windows_overlay_host.cpp` | `windows/runner/flutter_window.cpp` |
| Menu | captures, command bar, open, captures hub, settings, quit; FR/EN | shortcuts sheet, show app; no quit | agenda sections (headers, check marks), open, capture an idea, quit |
| Close (X) | hides | quits | hides, else orderly native shutdown |
| Explorer restart | icon restored | icon restored | icon lost |
| Single instance | mutex + Auth0 pipe + shell tasks (`WM_COPYDATA`) | none | none |
| Window before the click | captured (`tray_previous_foreground`) | n/a | n/a |

ShipGlows app, BeatGlows and GoCharbon have no tray.

## Package promises

Icon and tooltip; standard menu (Ouvrir, Version greyed, Rechercher une mise à
jour, Paramètres…, Quitter) completed by the app, with Segoe Fluent glyphs in
the Windows light or dark menu theme; close behavior (hide to tray by default,
minimize, quit); `onQuitRequested`; icon restored after an Explorer restart
and retried at sign-in; single instance through `ShipglowsTrayForwardToPrimary`
in `main.cpp`; `previousForeground` on every event. No-op on mobile, web,
macOS and Linux.

## Known limits

- The dark menu uses two undocumented `uxtheme.dll` exports (ordinals 135 and
  136); without them menus stay light.
- A runner with its own `WM_CLOSE` handling must run it after Flutter's
  top-level delegates (see `../context.md`).
- Command lines forwarded by a second launch come from any local process and
  must be validated by the app.

## Migration order

1. DreamGlows (agenda → `update(items:)`, orderly shutdown kept in the runner
   after the delegate, `ShipglowsTrayForwardToPrimary(L"dreamglows")`).
2. CommandGlows, after its command bar migration (close behavior to decide:
   it quits today).
3. ContentGlows, after its command bar migration; keep its Auth0 and shell
   task gate first, move them to `ShipglowsTraySecondInstance` later.
4. ShipGlows app, BeatGlows, GoCharbon on request.
