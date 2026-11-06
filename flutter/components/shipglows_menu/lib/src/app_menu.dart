import 'package:meta/meta.dart';

import 'menu_icon.dart';
import 'menu_items.dart';

/// Labels of the standard entries and of the Flutter menu. `{app}` stands
/// for the app name and `{version}` for its version.
@immutable
class ShipglowsMenuStrings {
  const ShipglowsMenuStrings({
    required this.settings,
    required this.version,
    required this.checkForUpdates,
    required this.quit,
    required this.feedback,
    required this.manual,
    required this.whatsNew,
    required this.about,
    required this.searchHint,
    required this.noResults,
    required this.back,
    required this.dismiss,
    required this.button,
  });

  static const fr = ShipglowsMenuStrings(
    settings: 'Paramètres…',
    version: 'Version {version}',
    checkForUpdates: 'Rechercher une mise à jour',
    quit: 'Quitter {app}',
    feedback: 'Envoyer un avis…',
    manual: 'Manuel',
    whatsNew: 'Nouveautés',
    about: 'À propos de {app}',
    searchHint: 'Rechercher une action…',
    noResults: 'Aucune action trouvée',
    back: 'Retour',
    dismiss: 'Fermer le menu',
    button: 'Actions',
  );

  static const en = ShipglowsMenuStrings(
    settings: 'Settings…',
    version: 'Version {version}',
    checkForUpdates: 'Check for updates',
    quit: 'Quit {app}',
    feedback: 'Send feedback…',
    manual: 'Manual',
    whatsNew: 'What’s new',
    about: 'About {app}',
    searchHint: 'Search for actions…',
    noResults: 'No matching action',
    back: 'Back',
    dismiss: 'Close the menu',
    button: 'Actions',
  );

  final String settings;
  final String version;
  final String checkForUpdates;
  final String quit;
  final String feedback;
  final String manual;
  final String whatsNew;
  final String about;

  /// Placeholder of the search field.
  final String searchHint;

  /// Shown when the search matches nothing.
  final String noResults;

  /// The row going back up from a submenu.
  final String back;

  /// Screen reader label of the area around the menu.
  final String dismiss;

  /// Tooltip of `ShipglowsMenuButton`.
  final String button;

  ShipglowsMenuStrings copyWith({
    String? settings,
    String? version,
    String? checkForUpdates,
    String? quit,
    String? feedback,
    String? manual,
    String? whatsNew,
    String? about,
    String? searchHint,
    String? noResults,
    String? back,
    String? dismiss,
    String? button,
  }) => ShipglowsMenuStrings(
    settings: settings ?? this.settings,
    version: version ?? this.version,
    checkForUpdates: checkForUpdates ?? this.checkForUpdates,
    quit: quit ?? this.quit,
    feedback: feedback ?? this.feedback,
    manual: manual ?? this.manual,
    whatsNew: whatsNew ?? this.whatsNew,
    about: about ?? this.about,
    searchHint: searchHint ?? this.searchHint,
    noResults: noResults ?? this.noResults,
    back: back ?? this.back,
    dismiss: dismiss ?? this.dismiss,
    button: button ?? this.button,
  );
}

/// Reserved ids of the standard entries.
abstract final class ShipglowsMenuStandardIds {
  /// Tray only: « Ouvrir <app> ».
  static const open = 'shipglows.open';
  static const settings = 'shipglows.settings';
  static const version = 'shipglows.version';
  static const checkForUpdates = 'shipglows.checkForUpdates';
  static const quit = 'shipglows.quit';
  static const feedback = 'shipglows.feedback';
  static const manual = 'shipglows.manual';
  static const whatsNew = 'shipglows.whatsNew';
  static const about = 'shipglows.about';
}

/// `1.2.3+4` (Flutter's product version, the pubspec `version`) as
/// `1.2.3 (4)`; any other text unchanged.
String formatShipglowsVersion(String raw) {
  final parts = raw.split('+');
  return parts.length == 2 && parts[1].isNotEmpty
      ? '${parts[0]} (${parts[1]})'
      : raw;
}

/// The entries every ShipGlows app shares, declared once and shown both in
/// the tray menu (`ShipglowsTrayStandardMenu.app`) and in Flutter menus
/// ([menu]):
///
/// ```text
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
/// An entry whose callback is null is left out; the version without a
/// [version] too.
@immutable
class ShipglowsAppMenu {
  const ShipglowsAppMenu({
    required this.appName,
    this.version,
    this.showVersion = true,
    this.onSettings,
    this.onCheckForUpdates,
    this.onFeedback,
    this.onManual,
    this.onWhatsNew,
    this.onAbout,
    this.onQuit,
    this.help = const [],
    this.shortcuts = const {},
    this.strings = ShipglowsMenuStrings.fr,
  });

  final String appName;

  /// Shown version, for example `formatShipglowsVersion(packageVersion)`.
  /// The tray reads the executable's when null.
  final String? version;

  final bool showVersion;

  final void Function()? onSettings;
  final void Function()? onCheckForUpdates;
  final void Function()? onFeedback;
  final void Function()? onManual;
  final void Function()? onWhatsNew;
  final void Function()? onAbout;

  /// Flutter menus only; the tray always shows « Quitter » and quits
  /// itself (through `ShipglowsTrayConfig.onQuitRequested`).
  final void Function()? onQuit;

  /// Help entries (troubleshooting, community…) placed after the manual.
  final List<ShipglowsMenuItem> help;

  /// Shortcut text by standard id, for example
  /// `{ShipglowsMenuStandardIds.settings: 'Ctrl+,'}`.
  final Map<String, String> shortcuts;

  final ShipglowsMenuStrings strings;

  /// [template] with `{app}` and `{version}` filled in.
  String fill(String template) => template
      .replaceAll('{app}', appName)
      .replaceAll('{version}', version ?? '');

  /// The standard entries, laid out as described on [ShipglowsAppMenu],
  /// separators normalised. [includeVersion] false leaves the version out,
  /// for a menu whose title already shows it.
  List<ShipglowsMenuItem> items({bool includeVersion = true}) {
    ShipglowsMenuAction? entry(
      String id,
      String label,
      ShipglowsMenuIcon icon,
      void Function()? onSelected, {
      bool showsMainWindow = false,
    }) => onSelected == null
        ? null
        : ShipglowsMenuAction(
            id,
            fill(label),
            icon: icon,
            shortcut: shortcuts[id],
            showsMainWindow: showsMainWindow,
            onSelected: onSelected,
          );

    final shownVersion = version;
    return normalizeShipglowsMenuSeparators([
      ?entry(
        ShipglowsMenuStandardIds.feedback,
        strings.feedback,
        ShipglowsMenuIcon.feedback,
        onFeedback,
        showsMainWindow: true,
      ),
      ?entry(
        ShipglowsMenuStandardIds.manual,
        strings.manual,
        ShipglowsMenuIcon.manual,
        onManual,
      ),
      ?entry(
        ShipglowsMenuStandardIds.whatsNew,
        strings.whatsNew,
        ShipglowsMenuIcon.whatsNew,
        onWhatsNew,
        showsMainWindow: true,
      ),
      ...help,
      const ShipglowsMenuSeparator(),
      if (includeVersion &&
          showVersion &&
          shownVersion != null &&
          shownVersion.isNotEmpty)
        ShipglowsMenuAction(
          ShipglowsMenuStandardIds.version,
          fill(strings.version),
          icon: ShipglowsMenuIcon.info,
          enabled: false,
        ),
      ?entry(
        ShipglowsMenuStandardIds.about,
        strings.about,
        ShipglowsMenuIcon.info,
        onAbout,
        showsMainWindow: true,
      ),
      ?entry(
        ShipglowsMenuStandardIds.checkForUpdates,
        strings.checkForUpdates,
        ShipglowsMenuIcon.update,
        onCheckForUpdates,
      ),
      ?entry(
        ShipglowsMenuStandardIds.settings,
        strings.settings,
        ShipglowsMenuIcon.settings,
        onSettings,
        showsMainWindow: true,
      ),
      const ShipglowsMenuSeparator(),
      ?entry(
        ShipglowsMenuStandardIds.quit,
        strings.quit,
        ShipglowsMenuIcon.quit,
        onQuit,
      ),
    ]);
  }

  /// A Flutter menu titled with the app name and version: the app's
  /// [actions] first, then the standard entries.
  ShipglowsMenu menu({List<ShipglowsMenuItem> actions = const []}) =>
      ShipglowsMenu(
        title: appName,
        subtitle: showVersion ? version : null,
        items: normalizeShipglowsMenuSeparators([
          ...actions,
          const ShipglowsMenuSeparator(),
          ...items(includeVersion: false),
        ]),
      );

  ShipglowsAppMenu copyWith({
    String? appName,
    String? version,
    bool? showVersion,
    void Function()? onSettings,
    void Function()? onCheckForUpdates,
    void Function()? onFeedback,
    void Function()? onManual,
    void Function()? onWhatsNew,
    void Function()? onAbout,
    void Function()? onQuit,
    List<ShipglowsMenuItem>? help,
    Map<String, String>? shortcuts,
    ShipglowsMenuStrings? strings,
  }) => ShipglowsAppMenu(
    appName: appName ?? this.appName,
    version: version ?? this.version,
    showVersion: showVersion ?? this.showVersion,
    onSettings: onSettings ?? this.onSettings,
    onCheckForUpdates: onCheckForUpdates ?? this.onCheckForUpdates,
    onFeedback: onFeedback ?? this.onFeedback,
    onManual: onManual ?? this.onManual,
    onWhatsNew: onWhatsNew ?? this.onWhatsNew,
    onAbout: onAbout ?? this.onAbout,
    onQuit: onQuit ?? this.onQuit,
    help: help ?? this.help,
    shortcuts: shortcuts ?? this.shortcuts,
    strings: strings ?? this.strings,
  );
}
