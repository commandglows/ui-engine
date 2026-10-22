import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shipglows_command_bar/shipglows_command_bar.dart';
import 'package:shipglows_overlay_window/shipglows_overlay_window.dart';

import 'protocol.dart';
import 'snapshot.dart';

/// A value of the bar that depends on its language (sections, filters,
/// texts).
typedef ShipglowsCommandBarLocalized<T> = T Function(Locale locale);

/// Runs the floating command bar in this engine. Call it from the overlay's
/// entry point, the `entrypoint` given to [ShipglowsCommandBarWindow]:
///
/// ```dart
/// @pragma('vm:entry-point')
/// void commandBarMain() => runShipglowsCommandBarOverlay(
///   sections: (locale) => mySections(locale),
///   iconFor: myIconFor,
/// );
/// ```
///
/// The parameters are those of [ShipglowsCommandBarOverlayApp], plus
/// [iconFor] (code point → constant icon, so release builds keep
/// tree-shaking the icon fonts) and [initialEntries] (listed before the app
/// published its first snapshot).
void runShipglowsCommandBarOverlay({
  required ShipglowsCommandBarLocalized<List<CommandBarSection>> sections,
  ShipglowsCommandBarLocalized<List<CommandBarFilter>>? filters,
  ShipglowsCommandBarLocalized<CommandBarStrings>? strings,
  ShipglowsCommandBarLocalized<List<CommandBarEntry>>? initialEntries,
  IconData? Function(int codePoint)? iconFor,
  ThemeData? theme,
  ThemeData? darkTheme,
  List<Locale> supportedLocales = const <Locale>[Locale('en'), Locale('fr')],
  List<LocalizationsDelegate<Object?>> localizationsDelegates =
      const <LocalizationsDelegate<Object?>>[],
  CommandBarBehavior behavior = const CommandBarBehavior(),
}) {
  WidgetsFlutterBinding.ensureInitialized();
  // Attached before ready(): the first opening may arrive right after it.
  final controller = ShipglowsCommandBarOverlayController(
    iconFor: iconFor,
    initialEntries: initialEntries,
    supportedLocales: supportedLocales,
  );
  runApp(
    ShipglowsCommandBarOverlayApp(
      controller: controller,
      sections: sections,
      filters: filters,
      strings: strings,
      theme: theme,
      darkTheme: darkTheme,
      localizationsDelegates: localizationsDelegates,
      behavior: behavior,
    ),
  );
  unawaited(controller.host.ready());
}

/// State of the floating bar in its engine: the snapshot the app published,
/// and the opening it belongs to. Also the bar's [CommandBarSource].
///
/// Create it before `runApp` and call [ShipglowsOverlayHost.ready] after,
/// as [runShipglowsCommandBarOverlay] does.
class ShipglowsCommandBarOverlayController extends ChangeNotifier
    implements CommandBarSource {
  ShipglowsCommandBarOverlayController({
    ShipglowsOverlayHost? host,
    this.iconFor,
    this.initialEntries,
    this.supportedLocales = const <Locale>[Locale('en'), Locale('fr')],
  }) : host = host ?? ShipglowsOverlayHost.instance {
    // The bar handles Escape itself (filter first, then close).
    this.host
      ..closeOnEscape = false
      ..onShow = _onShow
      ..onHide = _onHide;
    _subscription = this.host.messages.listen(_onMessage);
  }

  final ShipglowsOverlayHost host;

  /// Maps an icon code point of the snapshot back to a constant icon.
  final IconData? Function(int codePoint)? iconFor;

  /// Entries listed before the app published its first snapshot.
  final ShipglowsCommandBarLocalized<List<CommandBarEntry>>? initialEntries;

  /// Languages the bar can show; the snapshot's is matched against them.
  final List<Locale> supportedLocales;

  late final StreamSubscription<ShipglowsOverlayMessage> _subscription;
  ShipglowsCommandBarSnapshot? _snapshot;
  (Locale, List<CommandBarEntry>)? _initial;
  bool _visible = false;
  int _session = 0;
  (bool, Color, Color)? _frame;

  /// Last snapshot received, null before the first one.
  ShipglowsCommandBarSnapshot? get snapshot => _snapshot;

  /// Whether the bar is on screen. The search field takes focus only then.
  bool get visible => _visible;

  /// Changes at every opening and closing, so the bar starts with an empty
  /// query and no filter.
  int get session => _session;

  /// Language of the snapshot, else of the system, among [supportedLocales].
  Locale get locale {
    final wanted = [
      ?_snapshot?.locale,
      ...ui.PlatformDispatcher.instance.locales,
    ];
    for (final candidate in wanted) {
      for (final supported in supportedLocales) {
        if (supported.languageCode == candidate.languageCode) return supported;
      }
    }
    return supportedLocales.isEmpty ? const Locale('en') : supportedLocales.first;
  }

  /// Theme of the snapshot, else of the system.
  Brightness get brightness =>
      _snapshot?.brightness ?? ui.PlatformDispatcher.instance.platformBrightness;

  @override
  List<CommandBarEntry> get entries {
    if (_snapshot case final snapshot?) return snapshot.entries;
    final locale = this.locale;
    if (_initial case (final cachedLocale, final cached)
        when cachedLocale == locale) {
      return cached;
    }
    final built = initialEntries?.call(locale) ?? const <CommandBarEntry>[];
    _initial = (locale, built);
    return built;
  }

  @override
  List<String> get recentIds => _snapshot?.recentIds ?? const <String>[];

  /// Hides the bar, reports [choice] to the app and lets it run the entry.
  /// A disabled entry never runs; its secondary action runs if it has one.
  Future<void> choose(CommandBarChoice choice) async {
    CommandBarEntry? entry;
    for (final candidate in entries) {
      if (candidate.id == choice.id) {
        entry = candidate;
        break;
      }
    }
    if (entry == null) return;
    final allowed = choice.secondary ? entry.hasSecondary : entry.enabled;
    if (!allowed) return;
    final previous = host.previousForeground;
    final opensApp = _snapshot?.appWindowIds.contains(entry.id) ?? false;
    await host.hide(
      focus: opensApp ? OverlayHideFocus.app : OverlayHideFocus.previous,
    );
    await host.send(selectMessage, <String, Object?>{
      'id': entry.id,
      'secondary': choice.secondary,
      'previousForeground': previous,
    });
  }

  /// Hides the bar; focus goes back to the window in front before it.
  Future<void> close() => host.hide();

  /// Gives the window frame the bar's colors (dark frame, border, the color
  /// a resize step may expose), when they changed.
  void syncFrame({
    required bool dark,
    required Color border,
    required Color background,
  }) {
    final frame = (dark, border, background);
    if (frame == _frame) return;
    _frame = frame;
    unawaited(
      host.setFrame(
        darkFrame: dark,
        borderColor: border,
        backgroundColor: background,
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    host
      ..onShow = null
      ..onHide = null;
    super.dispose();
  }

  void _apply(Object? data) {
    final snapshot = ShipglowsCommandBarSnapshot.fromJson(
      data,
      iconFor: iconFor,
    );
    if (snapshot != null) _snapshot = snapshot;
  }

  void _onShow(Object? data) {
    _apply(data);
    _visible = true;
    _session++;
    notifyListeners();
  }

  void _onHide() {
    _visible = false;
    _session++;
    notifyListeners();
  }

  void _onMessage(ShipglowsOverlayMessage message) {
    if (message.method != snapshotMessage) return;
    _apply(message.arguments);
    notifyListeners();
  }
}

/// App of the floating bar's engine: the shared [CommandBarView] on the
/// bar's surface, inside [ShipglowsOverlayFrame] (drag to move, edges to
/// resize). Escape and a click outside close it.
class ShipglowsCommandBarOverlayApp extends StatelessWidget {
  const ShipglowsCommandBarOverlayApp({
    super.key,
    required this.controller,
    required this.sections,
    this.filters,
    this.strings,
    this.theme,
    this.darkTheme,
    this.localizationsDelegates = const <LocalizationsDelegate<Object?>>[],
    this.behavior = const CommandBarBehavior(),
  });

  final ShipglowsCommandBarOverlayController controller;

  /// Section titles, in display order.
  final ShipglowsCommandBarLocalized<List<CommandBarSection>> sections;

  /// Categories reachable with a one-letter prefix.
  final ShipglowsCommandBarLocalized<List<CommandBarFilter>>? filters;

  /// Texts of the bar. Defaults to [CommandBarStrings.fr] for French,
  /// [CommandBarStrings.en] otherwise.
  final ShipglowsCommandBarLocalized<CommandBarStrings>? strings;

  /// Light and dark themes; the snapshot's brightness picks one. A
  /// [CommandBarThemeData] extension styles the bar.
  final ThemeData? theme;
  final ThemeData? darkTheme;

  /// Localizations of the app's own texts, and `flutter_localizations` for
  /// Material's, if the bar needs them.
  final List<LocalizationsDelegate<Object?>> localizationsDelegates;

  /// Optional search and listing behaviours.
  final CommandBarBehavior behavior;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final locale = controller.locale;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme ?? ThemeData(brightness: Brightness.light),
          darkTheme: darkTheme ?? ThemeData(brightness: Brightness.dark),
          themeMode: controller.brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          locale: locale,
          supportedLocales: controller.supportedLocales,
          localizationsDelegates: localizationsDelegates,
          home: _CommandBarSurface(
            controller: controller,
            sections: sections(locale),
            filters: filters?.call(locale) ?? const <CommandBarFilter>[],
            strings:
                strings?.call(locale) ??
                (locale.languageCode == 'fr'
                    ? CommandBarStrings.fr
                    : CommandBarStrings.en),
            behavior: behavior,
          ),
        );
      },
    );
  }
}

class _CommandBarSurface extends StatefulWidget {
  const _CommandBarSurface({
    required this.controller,
    required this.sections,
    required this.filters,
    required this.strings,
    required this.behavior,
  });

  final ShipglowsCommandBarOverlayController controller;
  final List<CommandBarSection> sections;
  final List<CommandBarFilter> filters;
  final CommandBarStrings strings;
  final CommandBarBehavior behavior;

  @override
  State<_CommandBarSurface> createState() => _CommandBarSurfaceState();
}

class _CommandBarSurfaceState extends State<_CommandBarSurface> {
  final _barFocus = FocusNode(debugLabel: 'command bar', skipTraversal: true);

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _barFocus.dispose();
    super.dispose();
  }

  // The bar's own Escape needs the keyboard inside it. When the focus is
  // elsewhere (parked on the root after the window was reactivated), a plain
  // Escape still closes.
  bool _handleKey(KeyEvent event) {
    if (!widget.controller.visible ||
        _barFocus.hasFocus ||
        event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return false;
    }
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isShiftPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed) {
      return false;
    }
    unawaited(widget.controller.close());
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final style = CommandBarThemeData.of(context);
    controller.syncFrame(
      dark: Theme.of(context).brightness == Brightness.dark,
      border: style.borderColor,
      background: style.backgroundColor,
    );
    return Material(
      color: style.backgroundColor,
      child: ShipglowsOverlayFrame(
        host: controller.host,
        gripColor: style.mutedColor,
        child: Semantics(
          container: true,
          label: widget.strings.dialogLabel,
          child: Focus(
            focusNode: _barFocus,
            child: CommandBarView(
              key: ValueKey<int>(controller.session),
              source: controller,
              refresh: controller,
              sections: widget.sections,
              filters: widget.filters,
              strings: widget.strings,
              behavior: widget.behavior,
              autofocus: controller.visible,
              onChoose: (choice) => unawaited(controller.choose(choice)),
              onClose: () => unawaited(controller.close()),
            ),
          ),
        ),
      ),
    );
  }
}
