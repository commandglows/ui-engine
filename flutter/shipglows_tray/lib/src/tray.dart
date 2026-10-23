import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shipglows_menu/shipglows_menu_model.dart';

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
///         icon: ShipglowsMenuIcon.commandBar),
///   ],
///   standard: ShipglowsTrayStandardMenu(onSettings: openSettings),
/// ));
/// ShipglowsTray.instance.events.listen((event) { … });
/// ```
///
/// The standard entries (settings, check for updates, quit) are handled
/// here and not emitted on [events]; « Ouvrir » is emitted
/// (`ShipglowsMenuStandardIds.open`) once the window is in front.
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
  final _launchAtStartup = ValueNotifier(false);
  final _startupWindow = ValueNotifier(ShipglowsTrayStartupWindow.hidden);
  final _sessionStore = ShipglowsTrayMemoryStore();

  ShipglowsTrayConfig? _config;
  ShipglowsTrayStore? _store;
  String? _exeVersion;
  List<ShipglowsMenuItem> _items = const [];
  bool _quitting = false;
  bool _askingToClose = false;
  bool _launchedAtStartup = false;

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

  /// Whether Windows launches the app when the user signs in: its entry
  /// exists for this executable and is not turned off in Task Manager.
  /// Read by [start].
  ValueListenable<bool> get launchAtStartup => _launchAtStartup;

  /// How the main window starts after a launch at sign-in: the user's saved
  /// choice, else `ShipglowsTrayConfig.startupWindow`.
  ValueListenable<ShipglowsTrayStartupWindow> get startupWindow =>
      _startupWindow;

  /// Whether Windows launched this process at sign-in, known after [start].
  bool get launchedAtStartup => _launchedAtStartup;

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
    _startupWindow.value =
        await _store!.loadStartupWindow() ?? config.startupWindow;
    _exeVersion ??= await _invoke<String>('version');
    _readLaunchAtStartup(
      await _invoke<Map<Object?, Object?>>('launchAtStartup', {
        'name': config.appName,
      }),
    );
    final visible =
        await _invoke<bool>('start', {
          ..._payload(config),
          'closeBehavior': _closeBehavior.value.name,
          'secondInstanceShowsMainWindow': config.secondInstanceShowsMainWindow,
          'hasQuitHandler': config.onQuitRequested != null,
          'startupWindow': _startupWindow.value.name,
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
      startupWindow: current.startupWindow,
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

  /// Turns the launch at Windows sign-in on or off for the current user,
  /// under the app's name (one entry per app: the last copy that turned it
  /// on wins). Returns false when it could not be written.
  Future<bool> setLaunchAtStartup(bool enabled) async {
    final config = _config;
    if (!isSupported || config == null) return false;
    final state = await _invoke<Map<Object?, Object?>>('setLaunchAtStartup', {
      'name': config.appName,
      'enabled': enabled,
    });
    _readLaunchAtStartup(state);
    return state?['written'] == true;
  }

  /// Changes how the main window starts after the next launch at sign-in,
  /// and keeps it in the store. Returns false when it could not be saved
  /// (it still applies until the app quits).
  Future<bool> setStartupWindow(ShipglowsTrayStartupWindow window) async {
    if (!isSupported || _config == null) return false;
    _startupWindow.value = window;
    return await _store?.saveStartupWindow(window) ?? false;
  }

  void _readLaunchAtStartup(Map<Object?, Object?>? state) {
    if (state == null) return;
    _launchAtStartup.value =
        state['registered'] == true && state['approved'] != false;
    _launchedAtStartup = state['launched'] == true;
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

  Map<String, Object?> _payload(ShipglowsTrayConfig config) {
    _items = _menu(config);
    return {
      'tooltip': config.tooltip ?? config.appName,
      'icon': config.icon.toMap(),
      'items': [for (final item in _items) trayNativeItem(item)],
    };
  }

  List<ShipglowsMenuItem> _menu(ShipglowsTrayConfig config) {
    final standard = config.standard;
    final shared = standard
        .appMenu(config.appName, executableVersion: _exeVersion)
        .copyWith(onQuit: () => unawaited(quit()));
    return normalizeShipglowsMenuSeparators([
      if (standard.open)
        ShipglowsMenuAction(
          ShipglowsMenuStandardIds.open,
          standard.strings.open.replaceAll('{app}', config.appName),
          icon: ShipglowsMenuIcon.open,
          showsMainWindow: true,
          isDefault: true,
        ),
      const ShipglowsMenuSeparator(),
      ...config.items,
      const ShipglowsMenuSeparator(),
      ...shared.items(),
    ]);
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
    final action = findShipglowsMenuAction(_items, id);
    switch (id) {
      case ShipglowsMenuStandardIds.settings ||
          ShipglowsMenuStandardIds.checkForUpdates ||
          ShipglowsMenuStandardIds.feedback ||
          ShipglowsMenuStandardIds.manual ||
          ShipglowsMenuStandardIds.whatsNew ||
          ShipglowsMenuStandardIds.about ||
          ShipglowsMenuStandardIds.quit:
        // Standard entries carry their callback (quit: the tray's own).
        action?.onSelected?.call();
      default:
        // « Ouvrir »: the window is already in front; the app may refresh it.
        _events.add(
          ShipglowsTrayItemSelected(id, previousForeground: previousForeground),
        );
        action?.onSelected?.call();
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
