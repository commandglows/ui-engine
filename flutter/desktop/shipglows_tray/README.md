# shipglows_tray

Notification area (tray) icon for desktop apps (Windows; no-op on mobile,
web, macOS and Linux). Native Win32, no third-party plugin.

- Icon (the executable's by default, or an `.ico` asset or file), tooltip
  (127 characters), both changeable while running (`update`).
- Standard menu every app completes, with separators and monochrome glyphs
  (Segoe Fluent Icons, Segoe MDL2 Assets on Windows 10) in the light or dark
  theme of Windows apps: Ouvrir <app> (bold) │ app entries │ Envoyer un
  avis… · Manuel · Nouveautés · help entries │ Version (greyed, read from
  the executable) · À propos de <app> · Rechercher une mise à jour ·
  Paramètres… │ Quitter <app>. Entries without a callback are left out;
  labels in French or English (`ShipglowsTrayStrings`, whose `menu` labels
  are the shared `ShipglowsMenuStrings`).
- Entries are the action menu model of
  [`shipglows_menu`](../../components/shipglows_menu/README.md), re-exported:
  `ShipglowsMenuAction` (icon, disabled, check mark, shortcut text,
  `showsMainWindow`, `onSelected` called after the event),
  `ShipglowsMenuHeader` (greyed section title), `ShipglowsMenuSubmenu`,
  `ShipglowsMenuSeparator`. The former `ShipglowsTray*` names
  (`ShipglowsTrayAction`, `ShipglowsTrayGlyph`, `ShipglowsTrayHeader`,
  `ShipglowsTrayStandardIds`…) remain as aliases, and `glyph:` as a
  deprecated name of `icon:`.
- Shared standard entries: declare a `ShipglowsAppMenu` once and pass
  `ShipglowsTrayStandardMenu.app(appMenu)`; the same object gives the
  Flutter menu (`appMenu.menu(actions: …)`). The tray quits itself
  (`onQuitRequested`), whatever the app menu's `onQuit`.
- Click (or Enter on the icon): open the main window (default), the menu,
  an event, or a menu entry (`ShipglowsTrayClick`). Right click: the menu.
- Every event carries `previousForeground`, the HWND of the last window in
  front before the click (taskbar and menus ignored), for
  `ShipglowsCommandBarWindow.open(previousForeground:)`.
- Closing the main window (`ShipglowsTrayCloseBehavior`): ask (default), hide
  to the tray (minimize while the icon is missing), minimize, or quit.
  « Ask » shows a dialog (Réduire dans la zone de notification / Quitter /
  Annuler, « Ne plus me demander ») on `closeDialogContext`, a context below
  the app's `MaterialApp`; without one the window hides to the tray. A
  remembered choice is kept in `%APPDATA%\<appFolder>\tray.json` (or a
  `ShipglowsTrayStore`) and wins over the configured default.
  `ShipglowsTrayCloseSetting` is the settings row to change it back;
  `closeBehavior` / `setCloseBehavior` for a custom one. Quitting goes
  through `onQuitRequested` (false keeps the app running).
- Launch at Windows sign-in (`setLaunchAtStartup`, `launchAtStartup`): an
  entry `<appName>` under `HKCU\…\CurrentVersion\Run` starting this
  executable with `--launched-at-startup` (a dev build, run from
  `<project>\build\windows\…\runner\Debug` or `Profile`, registers
  `shipglows-dev start -ProjectPath <project> -FlutterDevice windows`
  instead, since its exe lacks the hot reloads; a stale entry of this
  executable is rewritten at the next start); turned off in Task Manager reads
  as off, and turning it on again clears that. After such a launch the main
  window starts as the user chose (`ShipglowsTrayStartupWindow`): hidden in
  the tray until opened (default; minimized while the icon is missing),
  minimized in the taskbar, or open. The choice is kept with the close
  behavior (`startupWindow` / `setStartupWindow`, default from the config);
  `launchedAtStartup` tells the app. `ShipglowsTrayStartupSetting` is the
  settings switch plus that choice.
- Icon back after an Explorer restart, retried for a minute when the
  taskbar is not ready at sign-in.
- Single instance: a later launch hands its command line to the running app
  (`ShipglowsTraySecondInstance`) and exits; the running app comes to the
  front.
- Jump List of the taskbar button (right click on it), like the
  « Épinglé » / « Récent » of document apps: `ShipglowsJumpListRecents`
  keeps the last opened items (`opened(ShipglowsJumpListItem(id, title))`,
  10 by default, in `%APPDATA%\<appFolder>\jump_list.json`, `items` for an
  in-app menu) and shows them under « Récent ». Windows lets the user pin
  each one (« Épingler à cette liste », kept by Windows even once the app
  forgets it) or remove it (the app forgets it at the next update). Fixed
  tasks (`ShipglowsJumpListTask`) go below. Choosing an item starts the app
  with `--shipglows-open=<id>`: `ShipglowsJumpList.itemIdFrom(args)` at
  launch, `ShipglowsTraySecondInstance.openedItemId` while it runs (needs
  `ShipglowsTrayForwardToPrimary`). A pinned id can point to a deleted
  item. « Récent » stays empty while Windows hides recently opened items
  (Paramètres › Personnalisation › Démarrer). The list replaces any list
  the runner commits itself (move its tasks to `tasks`), and a runner that
  sets an explicit AppUserModelID passes it as `appUserModelId`.
  `ShipglowsJumpList.instance.update(recent:, categories:, tasks:)` for an
  app that derives its lists from its data (« Publiés récemment »,
  « Brouillons en cours »: `ShipglowsJumpListCategory`); the 10 default
  slots are shared between categories, and with `appFolder` the items the
  user removed stay out of later updates.

```yaml
dependencies:
  shipglows_tray:
    path: ../../shipglows-app-engine/flutter/desktop/shipglows_tray
```

```dart
await ShipglowsTray.instance.start(ShipglowsTrayConfig(
  appName: 'ContentGlows',
  items: const [
    ShipglowsMenuAction('capture.screenshot', 'Capture d’écran',
        icon: ShipglowsMenuIcon.screenshot),
    ShipglowsMenuAction('commandBar', 'Barre de commandes',
        icon: ShipglowsMenuIcon.commandBar),
  ],
  standard: ShipglowsTrayStandardMenu(
    onSettings: () => router.go('/settings'),
    onCheckForUpdates: () => autoUpdater.checkForUpdates(inBackground: false),
  ),
  appFolder: 'ContentGlows',
  closeDialogContext: () => homeKey.currentContext,
  onQuitRequested: () async => saveEverything(),
));

ShipglowsTray.instance.events.listen((event) {
  switch (event) {
    case ShipglowsTrayItemSelected(id: 'commandBar', :final previousForeground):
      commandBar.open(previousForeground: previousForeground);
    case ShipglowsTrayItemSelected(:final id):
      runCommand(id);
    case ShipglowsTraySecondInstance(openedItemId: final id?):
      openDocument(id); // untrusted: look it up
    case ShipglowsTraySecondInstance(:final arguments):
      handleArguments(arguments); // untrusted: validate
    case ShipglowsTrayClicked():
      break;
  }
});

// Jump List: recent items the user can pin from the taskbar.
final recents = ShipglowsJumpListRecents(appFolder: 'ContentGlows');
await recents.load();
if (ShipglowsJumpList.itemIdFrom(args) case final id?) openDocument(id);
// Each time a document opens:
await recents.opened(ShipglowsJumpListItem(doc.id, doc.title,
    description: doc.path));
```

Single instance, in `windows/runner/main.cpp` before the window is created:

```cpp
#include <shipglows_tray/single_instance.h>

if (ShipglowsTrayForwardToPrimary(L"contentglows")) return EXIT_SUCCESS;
```

The plugin decides on `WM_CLOSE` through Flutter's top-level window delegate
(`HandleTopLevelWindowProc`). A runner drops its own tray icon, and runs any
`WM_CLOSE` handling of its own (an orderly shutdown) after that call: the
message only reaches it when the app really quits. The icon stays until the
engine goes away, so a shutdown the runner cancels keeps it.
