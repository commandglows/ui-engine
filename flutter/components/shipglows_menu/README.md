# shipglows_menu

Action menu used everywhere in an app, modelled on Raycast's ≡ menu: the
same entries in the native tray menu and in a floating Flutter list
anchored to a button, a right click or a « ⋯ » menu. Not tied to the
command bar.

- Model, pure Dart (`package:shipglows_menu/shipglows_menu_model.dart`):
  `ShipglowsMenuAction` (id, label, icon, shortcut text such as
  `Ctrl+Alt+K`, checked, disabled, search `keywords`, `onSelected`),
  `ShipglowsMenuSeparator`, `ShipglowsMenuHeader` (a titled group runs to
  the next separator or header; `ShipglowsMenuItem.group(title, items)`),
  `ShipglowsMenuSubmenu`, and `ShipglowsMenu` (title, subtitle, items).
  Everything but the callbacks round-trips through `toJson` / `fromJson`.
- Icons: `ShipglowsMenuIcon` carries a Segoe Fluent / MDL2 glyph (drawn by
  the tray) and a name (drawn by Flutter). Named constants (`settings`,
  `feedback`, `manual`, `whatsNew`, `info`, `quit`…) map to Material icons
  (`ShipglowsMenuIcons.material`, extended by `ShipglowsMenuTheme.icons`);
  an icon with only a glyph is drawn with the Segoe font on Windows;
  `ShipglowsMenuIcon.named('myapp.icon')` is for Flutter-only icons.
- Standard entries declared once (`ShipglowsAppMenu`): Envoyer un avis… ·
  Manuel · Nouveautés · help entries │ Version · À propos de <app> ·
  Rechercher une mise à jour · Paramètres… │ Quitter <app>. Entries without
  a callback are left out; reserved ids in `ShipglowsMenuStandardIds`;
  labels in `ShipglowsMenuStrings.fr` / `.en`; `formatShipglowsVersion`
  turns `1.2.3+4` into `1.2.3 (4)`.
- Flutter list (`showShipglowsMenu`, `ShipglowsMenuButton`,
  `ShipglowsMenuAnchor`, or `ShipglowsMenuPanel` to embed): title line (app
  name and version), group titles, shortcuts as keys on the right,
  « Rechercher une action… » filtering as you type (accents and case
  ignored, keywords and group titles included, submenus searched too).
  Keyboard: ↑/↓, Enter, → / ← into and out of submenus, Escape closes only
  the menu (the key never reaches the window). Opens below its anchor, or
  above with `preferAbove` (a bar's bottom-left ≡), on the side with room.
  Returns the chosen id and calls the action's `onSelected` once closed.
- Theme from the app's `ColorScheme`, customised with the
  `ShipglowsMenuTheme` extension (colours, width, height, radius, row
  height, shadows, label style, icons). Rows are 44 px minimum, with
  button, header, selected and checked semantics; reduced motion removes
  the fade.

```yaml
dependencies:
  shipglows_menu:
    path: ../../shipglows-app-engine/flutter/components/shipglows_menu
```

```dart
final appMenu = ShipglowsAppMenu(
  appName: 'ContentGlows',
  version: formatShipglowsVersion(packageInfo.version),
  onSettings: () => router.go('/settings'),
  onFeedback: openFeedback,
  onManual: () => launchUrl(manualUrl),
  onWhatsNew: showWhatsNew,
  onAbout: showAbout,
  onQuit: () => ShipglowsTray.instance.quit(),
  shortcuts: {ShipglowsMenuStandardIds.settings: 'Ctrl+,'},
);

// Tray: the same standard entries.
ShipglowsTray.instance.start(ShipglowsTrayConfig(
  appName: 'ContentGlows',
  standard: ShipglowsTrayStandardMenu.app(appMenu),
));

// In the app: a ≡ button at the bottom left of a bar.
ShipglowsMenuButton(
  preferAbove: true,
  menu: appMenu.menu(actions: [
    ...ShipglowsMenuItem.group('Capture', const [
      ShipglowsMenuAction('capture.screenshot', 'Capture d’écran',
          icon: ShipglowsMenuIcon.screenshot, shortcut: 'Ctrl+Shift+S'),
    ]),
  ]),
  onSelected: runCommand,
);

// Or on a right click.
ShipglowsMenuAnchor(
  menu: rowMenu,
  openOnSecondaryTap: true,
  builder: (context, open) => ListTile(title: Text(row.title), onTap: open),
);
```
