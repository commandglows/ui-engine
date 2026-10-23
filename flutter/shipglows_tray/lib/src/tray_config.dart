import 'package:flutter/widgets.dart';
import 'package:shipglows_menu/shipglows_menu_model.dart';

import 'tray_items.dart';
import 'tray_store.dart';

/// What closing the main window (title bar X, Alt+F4) does while the tray
/// runs. Quitting from the tray menu or with `ShipglowsTray.quit` always
/// quits.
enum ShipglowsTrayCloseBehavior {
  /// Asks each time (« Réduire dans la zone de notification » or « Quitter »,
  /// with « Ne plus me demander »). Hides to the tray when no dialog can be
  /// shown.
  ask,

  /// Hides the window; the app keeps running in the tray. Falls back to
  /// [minimize] while the icon is missing (no taskbar).
  hideToTray,

  /// Minimizes to the taskbar.
  minimize,

  /// Quits, through `ShipglowsTrayConfig.onQuitRequested` when given.
  quit,
}

/// How the main window starts when Windows launches the app at sign-in
/// (`ShipglowsTray.setLaunchAtStartup`). A normal launch always shows it.
enum ShipglowsTrayStartupWindow {
  /// Hidden in the tray until the user opens it; minimized while the icon is
  /// missing. Show it with `ShipglowsTray.showMainWindow`: other ways of
  /// showing it are ignored until then.
  hidden,

  /// Minimized in the taskbar.
  minimized,

  /// Shown as usual.
  shown,
}

/// What a click on the icon (or Enter on it from the keyboard) does. The
/// right click always opens the menu.
@immutable
sealed class ShipglowsTrayClick {
  const ShipglowsTrayClick();

  /// Brings the main window to the front, then emits `ShipglowsTrayClicked`.
  static const openMainWindow = _OpenMainWindowClick();

  /// Opens the menu.
  static const menu = _MenuClick();

  /// Only emits `ShipglowsTrayClicked`.
  static const event = _EventClick();

  /// Acts as choosing the menu entry [id] (with its `showsMainWindow`).
  const factory ShipglowsTrayClick.item(String id) = _ItemClick;

  Map<String, Object?> toMap();
}

final class _OpenMainWindowClick extends ShipglowsTrayClick {
  const _OpenMainWindowClick();

  @override
  Map<String, Object?> toMap() => const {'primaryClick': 'openMainWindow'};
}

final class _MenuClick extends ShipglowsTrayClick {
  const _MenuClick();

  @override
  Map<String, Object?> toMap() => const {'primaryClick': 'menu'};
}

final class _EventClick extends ShipglowsTrayClick {
  const _EventClick();

  @override
  Map<String, Object?> toMap() => const {'primaryClick': 'event'};
}

final class _ItemClick extends ShipglowsTrayClick {
  const _ItemClick(this.id);

  final String id;

  @override
  Map<String, Object?> toMap() => {'primaryClick': 'item', 'primaryItem': id};
}

/// The tray icon image. Defaults to the executable's icon.
@immutable
sealed class ShipglowsTrayImage {
  const ShipglowsTrayImage();

  /// The executable's icon (the runner's `IDI_APP_ICON`, resource 101).
  static const app = _AppImage();

  /// An `.ico` file declared in the app's pubspec assets.
  const factory ShipglowsTrayImage.asset(String path) = _AssetImage;

  /// An `.ico` file at an absolute path.
  const factory ShipglowsTrayImage.file(String path) = _FileImage;

  Map<String, Object?> toMap();
}

final class _AppImage extends ShipglowsTrayImage {
  const _AppImage();

  @override
  Map<String, Object?> toMap() => const {'kind': 'app'};
}

final class _AssetImage extends ShipglowsTrayImage {
  const _AssetImage(this.path);

  final String path;

  @override
  Map<String, Object?> toMap() => {'kind': 'asset', 'path': path};
}

final class _FileImage extends ShipglowsTrayImage {
  const _FileImage(this.path);

  final String path;

  @override
  Map<String, Object?> toMap() => {'kind': 'file', 'path': path};
}

/// Labels of the tray: its standard entries ([menu], shared with the
/// Flutter menu), « Ouvrir » and the close dialog. `{app}` stands for the
/// app name and `{version}` for its version.
@immutable
class ShipglowsTrayStrings {
  const ShipglowsTrayStrings({
    required this.menu,
    required this.open,
    required this.closeTitle,
    required this.closeMessage,
    required this.closeToTray,
    required this.closeToTrayHint,
    required this.closeQuitHint,
    required this.closeRemember,
    required this.cancel,
    required this.closeSetting,
    required this.closeAsk,
    required this.closeMinimize,
    required this.launchAtStartup,
    required this.startupWindow,
    required this.startupHidden,
    required this.startupMinimized,
    required this.startupShown,
  });

  static const fr = ShipglowsTrayStrings(
    menu: ShipglowsMenuStrings.fr,
    open: 'Ouvrir {app}',
    closeTitle: 'Fermer {app} ?',
    closeMessage: 'Choisissez ce qui se passe quand vous fermez la fenêtre.',
    closeToTray: 'Réduire dans la zone de notification',
    closeToTrayHint:
        '{app} reste actif dans la zone de notification. Cliquez sur son icône '
        'pour le rouvrir.',
    closeQuitHint: 'Ferme complètement l’application.',
    closeRemember: 'Ne plus me demander',
    cancel: 'Annuler',
    closeSetting: 'Quand je ferme la fenêtre',
    closeAsk: 'Me demander',
    closeMinimize: 'Réduire dans la barre des tâches',
    launchAtStartup: 'Lancer {app} au démarrage de Windows',
    startupWindow: 'Au démarrage, la fenêtre est',
    startupHidden: 'Cachée dans la zone de notification',
    startupMinimized: 'Réduite dans la barre des tâches',
    startupShown: 'Ouverte',
  );

  static const en = ShipglowsTrayStrings(
    menu: ShipglowsMenuStrings.en,
    open: 'Open {app}',
    closeTitle: 'Close {app}?',
    closeMessage: 'Choose what happens when you close the window.',
    closeToTray: 'Minimize to tray',
    closeToTrayHint:
        'Keeps {app} running in the system tray. Click the tray icon to '
        'reopen it.',
    closeQuitHint: 'Closes the app completely.',
    closeRemember: 'Don’t ask again',
    cancel: 'Cancel',
    closeSetting: 'When I close the window',
    closeAsk: 'Ask me',
    closeMinimize: 'Minimize to the taskbar',
    launchAtStartup: 'Launch {app} when Windows starts',
    startupWindow: 'At startup, the window is',
    startupHidden: 'Hidden in the system tray',
    startupMinimized: 'Minimized to the taskbar',
    startupShown: 'Open',
  );

  /// Labels of the shared standard entries.
  final ShipglowsMenuStrings menu;

  final String open;
  String get settings => menu.settings;
  String get version => menu.version;
  String get checkForUpdates => menu.checkForUpdates;

  /// Also the quit choice of the close dialog.
  String get quit => menu.quit;
  final String closeTitle;
  final String closeMessage;
  final String closeToTray;
  final String closeToTrayHint;
  final String closeQuitHint;
  final String closeRemember;
  final String cancel;

  /// Label of `ShipglowsTrayCloseSetting`; its choices are [closeAsk],
  /// [closeToTray], [closeMinimize] and [quit].
  final String closeSetting;
  final String closeAsk;
  final String closeMinimize;

  /// Labels of `ShipglowsTrayStartupSetting`: the switch, then the choice
  /// [startupWindow] among [startupHidden], [startupMinimized] and
  /// [startupShown].
  final String launchAtStartup;
  final String startupWindow;
  final String startupHidden;
  final String startupMinimized;
  final String startupShown;

  ShipglowsTrayStrings copyWith({
    ShipglowsMenuStrings? menu,
    String? open,
    String? settings,
    String? version,
    String? checkForUpdates,
    String? quit,
    String? closeTitle,
    String? closeMessage,
    String? closeToTray,
    String? closeToTrayHint,
    String? closeQuitHint,
    String? closeRemember,
    String? cancel,
    String? closeSetting,
    String? closeAsk,
    String? closeMinimize,
    String? launchAtStartup,
    String? startupWindow,
    String? startupHidden,
    String? startupMinimized,
    String? startupShown,
  }) => ShipglowsTrayStrings(
    menu: (menu ?? this.menu).copyWith(
      settings: settings,
      version: version,
      checkForUpdates: checkForUpdates,
      quit: quit,
    ),
    open: open ?? this.open,
    closeTitle: closeTitle ?? this.closeTitle,
    closeMessage: closeMessage ?? this.closeMessage,
    closeToTray: closeToTray ?? this.closeToTray,
    closeToTrayHint: closeToTrayHint ?? this.closeToTrayHint,
    closeQuitHint: closeQuitHint ?? this.closeQuitHint,
    closeRemember: closeRemember ?? this.closeRemember,
    cancel: cancel ?? this.cancel,
    closeSetting: closeSetting ?? this.closeSetting,
    closeAsk: closeAsk ?? this.closeAsk,
    closeMinimize: closeMinimize ?? this.closeMinimize,
    launchAtStartup: launchAtStartup ?? this.launchAtStartup,
    startupWindow: startupWindow ?? this.startupWindow,
    startupHidden: startupHidden ?? this.startupHidden,
    startupMinimized: startupMinimized ?? this.startupMinimized,
    startupShown: startupShown ?? this.startupShown,
  );
}

/// The standard entries of the tray menu, laid out around the app's own:
///
/// ```text
/// Ouvrir <app>                 (bold)
/// ───
/// <app entries>
/// ───
/// Envoyer un avis… · Manuel · Nouveautés · <help entries>
/// ───
/// Version 1.2.3 (4)            (greyed)
/// À propos de <app>
/// Rechercher une mise à jour
/// Paramètres…
/// ───
/// Quitter <app>
/// ```
///
/// An entry whose callback is null is left out. To show the same entries
/// in a Flutter menu, declare a `ShipglowsAppMenu` once and pass it to
/// [ShipglowsTrayStandardMenu.app].
@immutable
class ShipglowsTrayStandardMenu {
  const ShipglowsTrayStandardMenu({
    this.open = true,
    this.onSettings,
    this.onCheckForUpdates,
    this.onFeedback,
    this.onManual,
    this.onWhatsNew,
    this.onAbout,
    this.showVersion = true,
    this.version,
    this.help = const [],
    this.strings = ShipglowsTrayStrings.fr,
  }) : app = null;

  /// The entries of [app], labelled by its own strings; the tray quits
  /// itself, so its `onQuit` is unused. The other entry fields stay null and
  /// [strings] only labels « Ouvrir » and the close dialog.
  const ShipglowsTrayStandardMenu.app(
    ShipglowsAppMenu this.app, {
    this.open = true,
    this.strings = ShipglowsTrayStrings.fr,
  }) : onSettings = null,
       onCheckForUpdates = null,
       onFeedback = null,
       onManual = null,
       onWhatsNew = null,
       onAbout = null,
       showVersion = true,
       version = null,
       help = const [];

  /// « Ouvrir <app> »: brings the main window to the front.
  final bool open;

  /// The shared standard entries, given with [ShipglowsTrayStandardMenu.app].
  final ShipglowsAppMenu? app;

  /// Called after the main window came to the front.
  final VoidCallback? onSettings;

  final VoidCallback? onCheckForUpdates;

  /// « Envoyer un avis… », called after the main window came to the front.
  final VoidCallback? onFeedback;

  /// « Manuel ».
  final VoidCallback? onManual;

  /// « Nouveautés », called after the main window came to the front.
  final VoidCallback? onWhatsNew;

  /// « À propos de <app> », called after the main window came to the front.
  final VoidCallback? onAbout;

  final bool showVersion;

  /// Shown version; defaults to the executable's product version (the
  /// pubspec `version`, as `1.2.3 (4)`).
  final String? version;

  /// Help entries (troubleshooting…) placed above the version.
  final List<ShipglowsTrayItem> help;

  final ShipglowsTrayStrings strings;

  /// The shared standard entries these stand for, [executableVersion]
  /// (`1.2.3+4`) filling a missing version.
  ShipglowsAppMenu appMenu(String appName, {String? executableVersion}) {
    final menu =
        app ??
        ShipglowsAppMenu(
          appName: appName,
          version: version,
          showVersion: showVersion,
          onSettings: onSettings,
          onCheckForUpdates: onCheckForUpdates,
          onFeedback: onFeedback,
          onManual: onManual,
          onWhatsNew: onWhatsNew,
          onAbout: onAbout,
          help: help,
          strings: strings.menu,
        );
    if (menu.version != null || executableVersion == null) return menu;
    return menu.copyWith(version: formatShipglowsVersion(executableVersion));
  }
}

/// Reserved ids of the standard entries.
typedef ShipglowsTrayStandardIds = ShipglowsMenuStandardIds;

@immutable
class ShipglowsTrayConfig {
  const ShipglowsTrayConfig({
    required this.appName,
    this.tooltip,
    this.icon = ShipglowsTrayImage.app,
    this.items = const [],
    this.standard = const ShipglowsTrayStandardMenu(),
    this.closeBehavior = ShipglowsTrayCloseBehavior.ask,
    this.appFolder,
    this.store,
    this.closeDialogContext,
    this.primaryClick = ShipglowsTrayClick.openMainWindow,
    this.secondInstanceShowsMainWindow = true,
    this.startupWindow = ShipglowsTrayStartupWindow.hidden,
    this.onQuitRequested,
  });

  final String appName;

  /// Text shown when hovering the icon (127 characters at most); defaults
  /// to [appName].
  final String? tooltip;

  final ShipglowsTrayImage icon;

  /// The app's own entries, between « Ouvrir » and the help entries.
  final List<ShipglowsTrayItem> items;

  final ShipglowsTrayStandardMenu standard;

  /// Used until the user saves a choice (« Ne plus me demander », or
  /// `ShipglowsTray.setCloseBehavior`), which wins from then on.
  final ShipglowsTrayCloseBehavior closeBehavior;

  /// Keeps the user's choices (closing, startup window) in
  /// `%APPDATA%\<appFolder>\tray.json`; without it (and without [store])
  /// they last until the app quits.
  final String? appFolder;

  /// Replaces the file store of [appFolder].
  final ShipglowsTrayStore? store;

  /// A context below the app's `MaterialApp` (or `Navigator`) where the
  /// close dialog shows, for example the home screen's. Null, or a context
  /// no longer mounted: the window hides to the tray without asking.
  final BuildContext? Function()? closeDialogContext;

  final ShipglowsTrayClick primaryClick;

  /// Whether launching the app again brings the running one to the front
  /// (with the runner's `ShipglowsTrayForwardToPrimary`).
  final bool secondInstanceShowsMainWindow;

  /// Used until the user saves a choice (`ShipglowsTrayStartupSetting`, or
  /// `ShipglowsTray.setStartupWindow`), which wins from then on.
  final ShipglowsTrayStartupWindow startupWindow;

  /// Called before quitting (menu, `ShipglowsTray.quit`, or closing with
  /// [ShipglowsTrayCloseBehavior.quit]) to save or tear down; false keeps
  /// the app running. The app bounds its own wait.
  final Future<bool> Function()? onQuitRequested;
}
