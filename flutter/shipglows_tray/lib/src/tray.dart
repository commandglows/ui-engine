import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'tray_close_dialog.dart';
import 'tray_config.dart';
import 'tray_events.dart';
import 'tray_items.dart';
import 'tray_store.dart';

/// The app's notification area icon and menu.
///
/// ```dart
/// await ShipglowsTray.instance.start(ShipglowsTrayConfig(
///   appName: 'ContentGlows',
///   items: const [
///     ShipglowsTrayAction('commandBar', 'Barre de commandes',
///         glyph: ShipglowsTrayGlyph.commandBar),
///   ],
///   standard: ShipglowsTrayStandardMenu(onSettings: openSettings),
/// ));
/// ShipglowsTray.instance.events.listen((event) { … });
/// ```
///
/// The standard entries (settings, check for updates, quit) are handled
/// here and not emitted on [events]; « Ouvrir » is emitted
/// (`ShipglowsTrayStandardIds.open`) once the window is in front.
///
/// Windows only; elsewhere every call does nothing, [start] returns false
/// and [events] stays empty.
class ShipglowsTray {
  ShipglowsTray._();

  static final instance = ShipglowsTray._();

  static const _channel = MethodChannel('shipglows_tray');

  final _events = StreamController<ShipglowsTrayEvent>.broadcast();
  final _iconVisible = ValueNotifier(false);
  final _closeBehavior = ValueNotifier(ShipglowsTrayCloseBehavior.ask);
  final _sessionStore = ShipglowsTrayMemoryStore();

  ShipglowsTrayConfig? _config;
  ShipglowsTrayStore? _store;
  String? _exeVersion;
  bool _quitting = false;
  bool _askingToClose = false;

  /// Whether the tray exists on this platform.
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// Whether the icon is in the notification area. False before [start],
  /// and while Windows has no taskbar (the icon comes back with it).
  ValueListenable<bool> get iconVisible => _iconVisible;

  Stream<ShipglowsTrayEvent> get events => _events.stream;

  ShipglowsTrayConfig? get config => _config;

  /// What closing the main window does now: the user's saved choice, else
  /// `ShipglowsTrayConfig.closeBehavior`.
  ValueListenable<ShipglowsTrayCloseBehavior> get closeBehavior =>
      _closeBehavior;

  /// Shows the icon with [config]; calling it again replaces the whole
  /// configuration. Returns whether the icon is visible.
  Future<bool> start(ShipglowsTrayConfig config) async {
    if (!isSupported) return false;
    _channel.setMethodCallHandler(_onCall);
    _config = config;
    final folder = config.appFolder;
    _store =
        config.store ??
        (folder == null ? _sessionStore : ShipglowsTrayFileStore(folder));
    _closeBehavior.value = await _store!.load() ?? config.closeBehavior;
    _exeVersion ??= await _invoke<String>('version');
    final visible =
        await _invoke<bool>('start', {
          ..._payload(config),
          'closeBehavior': _closeBehavior.value.name,
          'secondInstanceShowsMainWindow': config.secondInstanceShowsMainWindow,
          'hasQuitHandler': config.onQuitRequested != null,
          ...config.primaryClick.toMap(),
        }) ??
        false;
    _iconVisible.value = visible;
    return visible;
  }

  /// Changes part of the running configuration, for example a tooltip or
  /// menu entries that follow the app's data.
  Future<void> update({
    String? tooltip,
    ShipglowsTrayImage? icon,
    List<ShipglowsTrayItem>? items,
    ShipglowsTrayStandardMenu? standard,
  }) async {
    final current = _config;
    if (!isSupported || current == null) return;
    final next = ShipglowsTrayConfig(
      appName: current.appName,
      tooltip: tooltip ?? current.tooltip,
      icon: icon ?? current.icon,
      items: items ?? current.items,
      standard: standard ?? current.standard,
      closeBehavior: current.closeBehavior,
      appFolder: current.appFolder,
      store: current.store,
      closeDialogContext: current.closeDialogContext,
      primaryClick: current.primaryClick,
      secondInstanceShowsMainWindow: current.secondInstanceShowsMainWindow,
      onQuitRequested: current.onQuitRequested,
    );
    _config = next;
    await _invoke<void>('update', _payload(next));
  }

  /// Changes what closing the main window does, for example from a setting,
  /// and keeps it in the store unless [save] is false. Returns false when
  /// it could not be saved (it still applies until the app quits).
  Future<bool> setCloseBehavior(
    ShipglowsTrayCloseBehavior behavior, {
    bool save = true,
  }) async {
    if (!isSupported || _config == null) return false;
    _closeBehavior.value = behavior;
    await _invoke<void>('setCloseBehavior', {'closeBehavior': behavior.name});
    if (!save) return true;
    return await _store?.save(behavior) ?? false;
  }

  /// Hides the main window to the tray (minimizes it while the icon is
  /// missing).
  Future<void> hideMainWindow() async {
    if (!isSupported) return;
    await _invoke<void>('hideMainWindow');
  }

  /// Shows the main window (even hidden to the tray) and brings it to the
  /// front when Windows allows it.
  Future<void> showMainWindow() async {
    if (!isSupported) return;
    await _invoke<void>('showMainWindow');
  }

  /// Quits the app, after `ShipglowsTrayConfig.onQuitRequested` agreed.
  /// Returns false when it refused or failed.
  Future<bool> quit() async {
    if (!isSupported || _quitting) return false;
    _quitting = true;
    try {
      final handler = _config?.onQuitRequested;
      if (handler != null && !await handler()) return false;
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'shipglows_tray',
          context: ErrorDescription('while asking to quit'),
        ),
      );
      return false;
    } finally {
      _quitting = false;
    }
    await _invoke<void>('quit');
    return true;
  }

  /// Removes the icon and restores the normal close behavior.
  Future<void> dispose() async {
    if (!isSupported) return;
    _config = null;
    _iconVisible.value = false;
    await _invoke<void>('dispose');
  }

  Map<String, Object?> _payload(ShipglowsTrayConfig config) => {
    'tooltip': config.tooltip ?? config.appName,
    'icon': config.icon.toMap(),
    'items': [for (final item in _menu(config)) item.toMap()],
  };

  List<ShipglowsTrayItem> _menu(ShipglowsTrayConfig config) {
    final standard = config.standard;
    final strings = standard.strings;
    String fill(String template) => template
        .replaceAll('{app}', config.appName)
        .replaceAll('{version}', _version(standard) ?? '');
    final version = _version(standard);
    return normalizeTraySeparators([
      if (standard.open)
        ShipglowsTrayAction(
          ShipglowsTrayStandardIds.open,
          fill(strings.open),
          glyph: ShipglowsTrayGlyph.open,
          showsMainWindow: true,
          isDefault: true,
        ),
      const ShipglowsTraySeparator(),
      ...config.items,
      const ShipglowsTraySeparator(),
      ...standard.help,
      const ShipglowsTraySeparator(),
      if (standard.showVersion && version != null && version.isNotEmpty)
        ShipglowsTrayAction(
          ShipglowsTrayStandardIds.version,
          fill(strings.version),
          glyph: ShipglowsTrayGlyph.info,
          enabled: false,
        ),
      if (standard.onCheckForUpdates != null)
        ShipglowsTrayAction(
          ShipglowsTrayStandardIds.checkForUpdates,
          fill(strings.checkForUpdates),
          glyph: ShipglowsTrayGlyph.update,
        ),
      if (standard.onSettings != null)
        ShipglowsTrayAction(
          ShipglowsTrayStandardIds.settings,
          fill(strings.settings),
          glyph: ShipglowsTrayGlyph.settings,
          showsMainWindow: true,
        ),
      const ShipglowsTraySeparator(),
      ShipglowsTrayAction(
        ShipglowsTrayStandardIds.quit,
        fill(strings.quit),
        glyph: ShipglowsTrayGlyph.quit,
      ),
    ]);
  }

  /// `1.2.3+4` (Flutter's product version) as `1.2.3 (4)`.
  String? _version(ShipglowsTrayStandardMenu standard) {
    final raw = standard.version ?? _exeVersion;
    if (raw == null || standard.version != null) return raw;
    final parts = raw.split('+');
    return parts.length == 2 && parts[1].isNotEmpty
        ? '${parts[0]} (${parts[1]})'
        : raw;
  }

  Future<void> _onCall(MethodCall call) async {
    if (call.method != 'event') return;
    final data = Map<Object?, Object?>.from(call.arguments as Map);
    final previous = (data['previousForeground'] as num?)?.toInt();
    switch (data['type']) {
      case 'selected':
        _onSelected(data['id'] as String, previous);
      case 'clicked':
        _events.add(ShipglowsTrayClicked(previousForeground: previous));
      case 'secondInstance':
        _events.add(
          ShipglowsTraySecondInstance([
            for (final argument in data['arguments'] as List) '$argument',
          ]),
        );
      case 'quitRequested':
        await quit();
      case 'closeRequested':
        await _askToClose();
      case 'iconVisible':
        _iconVisible.value = data['visible'] == true;
    }
  }

  /// The window's X with [ShipglowsTrayCloseBehavior.ask].
  Future<void> _askToClose() async {
    final config = _config;
    if (config == null || _askingToClose) return;
    final context = config.closeDialogContext?.call();
    if (context == null || !context.mounted) {
      await hideMainWindow();
      return;
    }
    _askingToClose = true;
    try {
      final decision = await showShipglowsTrayCloseDialog(
        context,
        appName: config.appName,
        strings: config.standard.strings,
      );
      if (decision == null) return;
      if (decision.remember) await setCloseBehavior(decision.behavior);
      if (decision.behavior == ShipglowsTrayCloseBehavior.quit) {
        await quit();
      } else {
        await hideMainWindow();
      }
    } finally {
      _askingToClose = false;
    }
  }

  void _onSelected(String id, int? previousForeground) {
    final standard = _config?.standard;
    switch (id) {
      case ShipglowsTrayStandardIds.open:
        // The window is already in front; the app may refresh it.
        _events.add(
          ShipglowsTrayItemSelected(id, previousForeground: previousForeground),
        );
      case ShipglowsTrayStandardIds.settings:
        standard?.onSettings?.call();
      case ShipglowsTrayStandardIds.checkForUpdates:
        standard?.onCheckForUpdates?.call();
      case ShipglowsTrayStandardIds.quit:
        unawaited(quit());
      default:
        _events.add(
          ShipglowsTrayItemSelected(id, previousForeground: previousForeground),
        );
    }
  }

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    }
  }
}
