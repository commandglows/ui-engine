import 'package:flutter/foundation.dart';

import 'tray_items.dart';

/// What closing the main window (title bar X, Alt+F4) does while the tray
/// runs. Quitting from the tray menu or with `ShipglowsTray.quit` always
/// quits.
enum ShipglowsTrayCloseBehavior {
  /// Hides the window; the app keeps running in the tray. Falls back to
  /// [minimize] while the icon is missing (no taskbar).
  hideToTray,

  /// Minimizes to the taskbar.
  minimize,

  /// Quits, through `ShipglowsTrayConfig.onQuitRequested` when given.
  quit,
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

/// Labels of the standard entries. `{app}` stands for the app name and
/// `{version}` for its version.
@immutable
class ShipglowsTrayStrings {
  const ShipglowsTrayStrings({
    required this.open,
    required this.settings,
    required this.version,
    required this.checkForUpdates,
    required this.quit,
  });

  static const fr = ShipglowsTrayStrings(
    open: 'Ouvrir {app}',
    settings: 'Paramètres…',
    version: 'Version {version}',
    checkForUpdates: 'Rechercher une mise à jour',
    quit: 'Quitter {app}',
  );

  static const en = ShipglowsTrayStrings(
    open: 'Open {app}',
    settings: 'Settings…',
    version: 'Version {version}',
    checkForUpdates: 'Check for updates',
    quit: 'Quit {app}',
  );

  final String open;
  final String settings;
  final String version;
  final String checkForUpdates;
  final String quit;

  ShipglowsTrayStrings copyWith({
    String? open,
    String? settings,
    String? version,
    String? checkForUpdates,
    String? quit,
  }) => ShipglowsTrayStrings(
    open: open ?? this.open,
    settings: settings ?? this.settings,
    version: version ?? this.version,
    checkForUpdates: checkForUpdates ?? this.checkForUpdates,
    quit: quit ?? this.quit,
  );
}

/// The entries every ShipGlows app shares, laid out around the app's own:
///
/// ```text
/// Ouvrir <app>                 (bold)
/// ───
/// <app entries>
/// ───
/// <help entries>
/// ───
/// Version 1.2.3 (4)            (greyed)
/// Rechercher une mise à jour
/// Paramètres…
/// ───
/// Quitter <app>
/// ```
///
/// An entry whose callback is null is left out.
@immutable
class ShipglowsTrayStandardMenu {
  const ShipglowsTrayStandardMenu({
    this.open = true,
    this.onSettings,
    this.onCheckForUpdates,
    this.showVersion = true,
    this.version,
    this.help = const [],
    this.strings = ShipglowsTrayStrings.fr,
  });

  /// « Ouvrir <app> »: brings the main window to the front.
  final bool open;

  /// Called after the main window came to the front.
  final VoidCallback? onSettings;

  final VoidCallback? onCheckForUpdates;

  final bool showVersion;

  /// Shown version; defaults to the executable's product version (the
  /// pubspec `version`, as `1.2.3 (4)`).
  final String? version;

  /// Help entries (send feedback, manual, troubleshooting…) placed above
  /// the version.
  final List<ShipglowsTrayItem> help;

  final ShipglowsTrayStrings strings;
}

/// Reserved ids of the standard entries.
abstract final class ShipglowsTrayStandardIds {
  static const open = 'shipglows.open';
  static const settings = 'shipglows.settings';
  static const version = 'shipglows.version';
  static const checkForUpdates = 'shipglows.checkForUpdates';
  static const quit = 'shipglows.quit';
}

@immutable
class ShipglowsTrayConfig {
  const ShipglowsTrayConfig({
    required this.appName,
    this.tooltip,
    this.icon = ShipglowsTrayImage.app,
    this.items = const [],
    this.standard = const ShipglowsTrayStandardMenu(),
    this.closeBehavior = ShipglowsTrayCloseBehavior.hideToTray,
    this.primaryClick = ShipglowsTrayClick.openMainWindow,
    this.secondInstanceShowsMainWindow = true,
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
  final ShipglowsTrayCloseBehavior closeBehavior;
  final ShipglowsTrayClick primaryClick;

  /// Whether launching the app again brings the running one to the front
  /// (with the runner's `ShipglowsTrayForwardToPrimary`).
  final bool secondInstanceShowsMainWindow;

  /// Called before quitting (menu, `ShipglowsTray.quit`, or closing with
  /// [ShipglowsTrayCloseBehavior.quit]) to save or tear down; false keeps
  /// the app running. The app bounds its own wait.
  final Future<bool> Function()? onQuitRequested;
}
