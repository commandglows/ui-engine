import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'hotkey.dart';
import 'store.dart';

/// Where the keyboard was when a hotkey was pressed.
enum ShipglowsHotkeyForeground {
  /// Another application.
  otherApp,

  /// The app's main window, shown.
  app,

  /// Another window of the app, such as an overlay.
  ownWindow,

  /// No window, or the app's main window hidden or minimized.
  none,
}

/// A press of one of the app's hotkeys.
@immutable
class ShipglowsHotkeyEvent {
  const ShipglowsHotkeyEvent({
    required this.id,
    required this.foreground,
    this.previousForeground,
  });

  /// [ShipglowsHotkeyBinding.id] of the hotkey.
  final String id;

  final ShipglowsHotkeyForeground foreground;

  /// Handle (HWND) of the window in front when the hotkey was pressed, read
  /// before any Dart code ran: the window to give the keyboard back to, or
  /// to paste into. Null with [ShipglowsHotkeyForeground.none].
  final int? previousForeground;
}

/// A hotkey the app offers. The user's choice, once saved, replaces
/// [candidates].
@immutable
class ShipglowsHotkeyBinding {
  const ShipglowsHotkeyBinding({required this.id, this.candidates = const []});

  /// Stable name, also the key of the saved choice.
  final String id;

  /// Combinations by preference: the first one free is registered (the
  /// usual one may belong to a launcher such as PowerToys). Empty: none
  /// until the user picks one.
  final List<ShipglowsHotkey> candidates;
}

/// Why a hotkey is not active.
enum ShipglowsHotkeyConflict {
  /// Another application owns the combination.
  alreadyRegistered,

  /// Another hotkey of the app already uses it.
  duplicate,

  /// Not a usable combination ([ShipglowsHotkey.isValid]), or an id the app
  /// did not declare.
  invalid,

  /// Windows refused it for another reason.
  failed,

  /// It worked but the choice could not be saved, so it was undone.
  persistFailed,
}

/// The app's hotkeys right now.
@immutable
class ShipglowsHotkeyState {
  const ShipglowsHotkeyState({
    this.active = const {},
    this.conflicts = const {},
  });

  /// Registered hotkeys by id.
  final Map<String, ShipglowsHotkey> active;

  /// Hotkeys that are not active, and why. An id the user left unassigned
  /// is in neither map.
  final Map<String, ShipglowsHotkeyConflict> conflicts;

  ShipglowsHotkey? operator [](String id) => active[id];
}

/// Outcome of [ShipglowsHotkeys.setAll].
@immutable
class ShipglowsHotkeyResult {
  const ShipglowsHotkeyResult({
    required this.applied,
    this.conflicts = const {},
    this.restored = true,
  });

  /// Whether every change is registered and saved. Otherwise none is, and
  /// the previous hotkeys are back.
  final bool applied;

  /// Why changes were refused, by id.
  final Map<String, ShipglowsHotkeyConflict> conflicts;

  /// False when a previous hotkey could not be registered again (another
  /// app took it meanwhile); [ShipglowsHotkeys.state] reports it.
  final bool restored;
}

/// System-wide hotkeys of the app: they fire whether the app is in front, in
/// the background or hidden in the tray.
///
/// The app declares its hotkeys with [apply] once at startup, listens to
/// [events], and lets the user change them with [set] / [setAll] (saved in
/// [store]). One instance per engine, in the app's main engine.
///
/// Windows only; elsewhere nothing registers and [events] stays silent.
class ShipglowsHotkeys {
  /// [appFolder] keeps the user's choices in
  /// `%APPDATA%\<appFolder>\hotkeys.json`; without it (and without [store])
  /// they last until the app quits.
  ///
  /// With [hookFallback], a hotkey Windows refuses for another reason than
  /// an owner is caught with a low-level keyboard hook. Never used against
  /// another app's hotkey.
  ShipglowsHotkeys({
    String? appFolder,
    ShipglowsHotkeyStore? store,
    this.hookFallback = false,
  }) : store =
           store ??
           (appFolder == null
               ? ShipglowsHotkeyMemoryStore()
               : ShipglowsHotkeyFileStore(appFolder)) {
    _current = this;
    if (isSupported) _channel.setMethodCallHandler(_onCall);
  }

  static const _channel = MethodChannel('shipglows_hotkeys');
  static ShipglowsHotkeys? _current;

  final ShipglowsHotkeyStore store;
  final bool hookFallback;

  final _events = StreamController<ShipglowsHotkeyEvent>.broadcast();
  final ValueNotifier<ShipglowsHotkeyState> _state = ValueNotifier(
    const ShipglowsHotkeyState(),
  );

  List<ShipglowsHotkeyBinding> _bindings = const [];
  Map<String, ShipglowsHotkey?> _choices = {};
  bool _loaded = false;
  final Map<String, int> _slots = {};
  final Map<int, String> _ids = {};
  Future<void> _queue = Future.value();

  /// Whether system-wide hotkeys exist on this platform.
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// Presses of the app's hotkeys.
  Stream<ShipglowsHotkeyEvent> get events => _events.stream;

  /// Active hotkeys and conflicts, for a settings screen.
  ValueListenable<ShipglowsHotkeyState> get state => _state;

  /// The declared hotkeys.
  List<ShipglowsHotkeyBinding> get bindings => List.unmodifiable(_bindings);

  /// Registers [bindings], replacing any declared before: each id gets the
  /// user's saved choice, else its first free candidate.
  Future<ShipglowsHotkeyState> apply(List<ShipglowsHotkeyBinding> bindings) =>
      _serial(() => _apply(bindings));

  /// Gives hotkey [id] the combination [hotkey]; null leaves it unassigned.
  Future<ShipglowsHotkeyResult> set(String id, ShipglowsHotkey? hotkey) =>
      setAll({id: hotkey});

  /// Changes several hotkeys at once, all or none: two of them can swap
  /// combinations. Saved when applied.
  Future<ShipglowsHotkeyResult> setAll(Map<String, ShipglowsHotkey?> hotkeys) =>
      _serial(() => _setAll(hotkeys));

  /// Forgets the user's choice for [id]: its candidates apply again.
  Future<ShipglowsHotkeyState> reset(String id) => _serial(() async {
    if (!_choices.containsKey(id)) return _state.value;
    final choices = {..._choices}..remove(id);
    if (!await store.save(choices)) return _state.value;
    _choices = choices;
    return _apply(_bindings);
  });

  /// Unregisters every hotkey and stops [events].
  Future<void> dispose() => _serial(() async {
    if (isSupported) await _invoke<void>('unregisterAll');
    if (identical(_current, this)) {
      _current = null;
      if (isSupported) _channel.setMethodCallHandler(null);
    }
    await _events.close();
    _state.dispose();
  });

  Future<ShipglowsHotkeyState> _apply(
    List<ShipglowsHotkeyBinding> bindings,
  ) async {
    _bindings = List.of(bindings);
    if (!isSupported) return _state.value;
    if (!_loaded) {
      _choices = await store.load();
      _loaded = true;
    }
    await _invoke<void>('unregisterAll');
    final active = <String, ShipglowsHotkey>{};
    final conflicts = <String, ShipglowsHotkeyConflict>{};
    for (final binding in bindings) {
      final List<ShipglowsHotkey> wanted;
      if (_choices.containsKey(binding.id)) {
        final chosen = _choices[binding.id];
        if (chosen == null) continue;
        wanted = [chosen];
      } else {
        wanted = binding.candidates;
      }
      ShipglowsHotkeyConflict? conflict;
      for (final hotkey in wanted) {
        if (!hotkey.isValid) {
          conflict ??= ShipglowsHotkeyConflict.invalid;
          continue;
        }
        if (active.containsValue(hotkey)) {
          conflict ??= ShipglowsHotkeyConflict.duplicate;
          continue;
        }
        conflict = await _register(binding.id, hotkey);
        if (conflict == null) {
          active[binding.id] = hotkey;
          break;
        }
      }
      if (conflict != null) conflicts[binding.id] = conflict;
    }
    return _state.value = ShipglowsHotkeyState(
      active: active,
      conflicts: conflicts,
    );
  }

  Future<ShipglowsHotkeyResult> _setAll(
    Map<String, ShipglowsHotkey?> hotkeys,
  ) async {
    final previous = _state.value;
    final declared = {for (final binding in _bindings) binding.id};
    final next = {...previous.active}
      ..removeWhere((id, _) => hotkeys.containsKey(id));
    final conflicts = <String, ShipglowsHotkeyConflict>{};
    for (final MapEntry(key: id, value: hotkey) in hotkeys.entries) {
      if (!declared.contains(id) || (hotkey != null && !hotkey.isValid)) {
        conflicts[id] = ShipglowsHotkeyConflict.invalid;
      } else if (hotkey == null) {
        continue;
      } else if (next.containsValue(hotkey)) {
        conflicts[id] = ShipglowsHotkeyConflict.duplicate;
      } else {
        next[id] = hotkey;
      }
    }
    if (conflicts.isNotEmpty || !isSupported) {
      return ShipglowsHotkeyResult(applied: false, conflicts: conflicts);
    }

    // The old combinations go first, so two hotkeys can swap.
    for (final id in hotkeys.keys) {
      if (previous.active.containsKey(id)) await _unregister(id);
    }
    final registered = <String>[];
    for (final MapEntry(key: id, value: hotkey) in hotkeys.entries) {
      if (hotkey == null) continue;
      final conflict = await _register(id, hotkey);
      if (conflict != null) {
        conflicts[id] = conflict;
        break;
      }
      registered.add(id);
    }
    if (conflicts.isEmpty) {
      final choices = {..._choices, ...hotkeys};
      if (await store.save(choices)) {
        _choices = choices;
        _state.value = ShipglowsHotkeyState(
          active: next,
          conflicts: {...previous.conflicts}
            ..removeWhere((id, _) => hotkeys.containsKey(id)),
        );
        return const ShipglowsHotkeyResult(applied: true);
      }
      for (final id in hotkeys.keys) {
        conflicts[id] = ShipglowsHotkeyConflict.persistFailed;
      }
    }

    // Undo: the previous combinations back in place.
    for (final id in registered) {
      await _unregister(id);
    }
    final active = {...previous.active};
    final lost = <String, ShipglowsHotkeyConflict>{};
    for (final id in hotkeys.keys) {
      final old = previous.active[id];
      if (old == null) continue;
      final conflict = await _register(id, old);
      if (conflict != null) {
        active.remove(id);
        lost[id] = conflict;
      }
    }
    if (lost.isNotEmpty) {
      _state.value = ShipglowsHotkeyState(
        active: active,
        conflicts: {...previous.conflicts, ...lost},
      );
    }
    return ShipglowsHotkeyResult(
      applied: false,
      conflicts: conflicts,
      restored: lost.isEmpty,
    );
  }

  /// Null once registered.
  Future<ShipglowsHotkeyConflict?> _register(
    String id,
    ShipglowsHotkey hotkey,
  ) async {
    final outcome = await _invoke<String>('register', {
      'slot': _slotFor(id),
      'modifiers': hotkey.modifiers,
      'key': hotkey.key,
      'hookFallback': hookFallback,
    });
    return switch (outcome) {
      'registered' || 'hook' => null,
      'alreadyRegistered' => ShipglowsHotkeyConflict.alreadyRegistered,
      'invalid' => ShipglowsHotkeyConflict.invalid,
      _ => ShipglowsHotkeyConflict.failed,
    };
  }

  Future<void> _unregister(String id) =>
      _invoke<void>('unregister', {'slot': _slotFor(id)});

  /// The `RegisterHotKey` id of [id], stable for the life of the instance.
  int _slotFor(String id) => _slots.putIfAbsent(id, () {
    final slot = _slots.length + 1;
    _ids[slot] = id;
    return slot;
  });

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    }
  }

  /// Runs [task] after the ones before it, so registrations never interleave.
  Future<T> _serial<T>(Future<T> Function() task) {
    final result = _queue.then((_) => task());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  static Future<void> _onCall(MethodCall call) async {
    final hotkeys = _current;
    final arguments = call.arguments;
    if (hotkeys == null || call.method != 'onHotkey' || arguments is! Map) {
      return;
    }
    final slot = arguments['slot'];
    final id = slot is int ? hotkeys._ids[slot] : null;
    if (id == null || hotkeys._events.isClosed) return;
    final previous = arguments['previousForeground'];
    hotkeys._events.add(
      ShipglowsHotkeyEvent(
        id: id,
        foreground: ShipglowsHotkeyForeground.values.asNameMap()[
                arguments['foreground']] ??
            ShipglowsHotkeyForeground.none,
        previousForeground: previous is int && previous != 0 ? previous : null,
      ),
    );
  }
}
