import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'action.dart';
import 'hotkey.dart';
import 'store.dart';
import 'trigger.dart';

/// Where the keyboard was when a trigger fired.
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

/// A trigger of one of the app's bindings firing: a hotkey pressed, a key
/// pressed twice, or a mouse gesture done.
@immutable
class ShipglowsHotkeyEvent {
  const ShipglowsHotkeyEvent({
    required this.id,
    required this.foreground,
    this.previousForeground,
    this.window,
    this.x,
    this.y,
    this.startX,
    this.startY,
  });

  /// [ShipglowsHotkeyBinding.id] of the binding.
  final String id;

  final ShipglowsHotkeyForeground foreground;

  /// Handle (HWND) of the window in front when the trigger fired, read
  /// before any Dart code ran: the window to give the keyboard back to, or
  /// to paste into. Null with [ShipglowsHotkeyForeground.none].
  final int? previousForeground;

  /// Handle (HWND) of the top-level window the trigger is about: the one under
  /// the pointer for a mouse trigger, the one in front for a key trigger.
  /// Null when there is none.
  final int? window;

  /// Where the pointer was, in screen pixels. Null for a key trigger.
  final int? x;
  final int? y;

  /// Where a [ShipglowsMouseGesture.drag] or a hold started.
  final int? startX;
  final int? startY;
}

/// What a binding does: one action, one trigger. The user's choice, once
/// saved, replaces [trigger].
///
/// Give it a [trigger] (or the keyboard-only [hotkey]); leave both null for
/// an action that stays off until the user picks one.
@immutable
class ShipglowsHotkeyBinding {
  const ShipglowsHotkeyBinding({
    required this.id,
    this.hotkey,
    this.trigger,
    this.action,
    this.excludeProcesses = const {},
  }) : assert(
         hotkey == null || trigger == null,
         'Give a hotkey or a trigger, not both',
       );

  /// Stable name, also the key of the saved choice.
  final String id;

  /// Default key combination; same as `trigger: ShipglowsTrigger.key(hotkey)`.
  /// When another application owns it, it is reported as
  /// [ShipglowsHotkeyConflict.alreadyRegistered] and no other combination is
  /// tried: the app says so and offers to change it.
  final ShipglowsHotkey? hotkey;

  /// Default trigger. Null with a null [hotkey]: none until the user picks
  /// one.
  final ShipglowsTrigger? trigger;

  /// What the package does by itself when the trigger fires. The event is
  /// still sent on [ShipglowsHotkeys.events].
  final ShipglowsWindowAction? action;

  /// Executable names (`code.exe`) in which a mouse trigger or a double key
  /// does nothing and passes through. Ignored by key combinations, which
  /// Windows takes before any application sees them.
  final Set<String> excludeProcesses;

  /// [trigger], or [hotkey] as a trigger.
  ShipglowsTrigger? get defaultTrigger =>
      trigger ?? (hotkey == null ? null : ShipglowsKeyTrigger(hotkey!));
}

/// Why a trigger is not active.
enum ShipglowsHotkeyConflict {
  /// Another application owns the combination. Show it to the user
  /// ([ShipglowsHotkeyConflictTexts]) and offer to change it.
  alreadyRegistered,

  /// Another binding of the app already uses it.
  duplicate,

  /// Not a usable trigger ([ShipglowsTrigger.isValid]), or an id the app did
  /// not declare.
  invalid,

  /// Windows refused it for another reason, or a hook could not be installed.
  failed,

  /// It worked but the choice could not be saved, so it was undone.
  persistFailed,
}

/// What to tell the user about a [ShipglowsHotkeyConflict].
@immutable
class ShipglowsHotkeyConflictTexts {
  const ShipglowsHotkeyConflictTexts({
    this.alreadyRegistered =
        'Already used by another application. Choose another combination.',
    this.duplicate = 'Already used by another shortcut of this app.',
    this.invalid = 'This shortcut or gesture cannot be used.',
    this.failed = 'Windows refused this shortcut.',
    this.persistFailed = 'The shortcut could not be saved.',
  });

  static const en = ShipglowsHotkeyConflictTexts();

  static const fr = ShipglowsHotkeyConflictTexts(
    alreadyRegistered:
        'Déjà utilisé par une autre application. Choisis une autre '
        'combinaison.',
    duplicate: 'Déjà utilisé par un autre raccourci de l’app.',
    invalid: 'Ce raccourci ou ce geste n’est pas utilisable.',
    failed: 'Windows a refusé ce raccourci.',
    persistFailed: 'Le raccourci n’a pas pu être enregistré.',
  );

  final String alreadyRegistered;
  final String duplicate;
  final String invalid;
  final String failed;
  final String persistFailed;

  String of(ShipglowsHotkeyConflict conflict) => switch (conflict) {
    ShipglowsHotkeyConflict.alreadyRegistered => alreadyRegistered,
    ShipglowsHotkeyConflict.duplicate => duplicate,
    ShipglowsHotkeyConflict.invalid => invalid,
    ShipglowsHotkeyConflict.failed => failed,
    ShipglowsHotkeyConflict.persistFailed => persistFailed,
  };
}

/// The app's triggers right now.
@immutable
class ShipglowsHotkeyState {
  const ShipglowsHotkeyState({
    this.triggers = const {},
    this.conflicts = const {},
  });

  /// Registered triggers by id.
  final Map<String, ShipglowsTrigger> triggers;

  /// Triggers that are not active, and why. An id the user left unassigned
  /// is in neither map.
  final Map<String, ShipglowsHotkeyConflict> conflicts;

  /// Registered key combinations by id (the key triggers of [triggers]).
  Map<String, ShipglowsHotkey> get active => {
    for (final MapEntry(:key, :value) in triggers.entries)
      if (value is ShipglowsKeyTrigger) key: value.hotkey,
  };

  /// The key combination of [id]; null for another kind of trigger.
  ShipglowsHotkey? operator [](String id) {
    final trigger = triggers[id];
    return trigger is ShipglowsKeyTrigger ? trigger.hotkey : null;
  }

  ShipglowsTrigger? trigger(String id) => triggers[id];
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
  /// the previous triggers are back.
  final bool applied;

  /// Why changes were refused, by id.
  final Map<String, ShipglowsHotkeyConflict> conflicts;

  /// False when a previous trigger could not be registered again (another
  /// app took it meanwhile); [ShipglowsHotkeys.state] reports it.
  final bool restored;
}

/// System-wide triggers of the app: key combinations, a key pressed twice and
/// mouse gestures (with modifier keys for « mouse + keyboard »). They fire
/// whether the app is in front, in the background or hidden in the tray, and
/// each one is tied to an id, so the user chooses what starts each action.
///
/// The app declares its bindings with [apply] once at startup, listens to
/// [events] (or gives a binding an [ShipglowsHotkeyBinding.action] the package
/// runs by itself), and lets the user change triggers with [set] / [setAll] /
/// [setTrigger] / [setAllTriggers] (saved in [store]). One instance per
/// engine, in the app's main engine.
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
  final _actionEvents = StreamController<ShipglowsActionEvent>.broadcast();
  final ValueNotifier<ShipglowsHotkeyState> _state = ValueNotifier(
    const ShipglowsHotkeyState(),
  );

  List<ShipglowsHotkeyBinding> _bindings = const [];
  Map<String, ShipglowsTrigger?> _choices = {};
  bool _loaded = false;
  final Map<String, int> _slots = {};
  final Map<int, String> _ids = {};
  Future<void> _queue = Future.value();

  /// Whether system-wide triggers exist on this platform.
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// Firings of the app's triggers.
  Stream<ShipglowsHotkeyEvent> get events => _events.stream;

  /// Actions the package ran for bindings that declared one.
  Stream<ShipglowsActionEvent> get actionEvents => _actionEvents.stream;

  /// Active triggers and conflicts, for a settings screen.
  ValueListenable<ShipglowsHotkeyState> get state => _state;

  /// The declared bindings.
  List<ShipglowsHotkeyBinding> get bindings => List.unmodifiable(_bindings);

  /// Registers [bindings], replacing any declared before: each id gets the
  /// user's saved choice, else its default. A combination another
  /// application owns is reported in [ShipglowsHotkeyState.conflicts], never
  /// replaced by another one.
  Future<ShipglowsHotkeyState> apply(List<ShipglowsHotkeyBinding> bindings) =>
      _serial(() => _apply(bindings));

  /// Gives binding [id] the key combination [hotkey]; null leaves it
  /// unassigned.
  Future<ShipglowsHotkeyResult> set(String id, ShipglowsHotkey? hotkey) =>
      setAll({id: hotkey});

  /// Changes several key combinations at once, all or none: two of them can
  /// swap combinations. Saved when applied.
  Future<ShipglowsHotkeyResult> setAll(Map<String, ShipglowsHotkey?> hotkeys) =>
      setAllTriggers({
        for (final MapEntry(:key, :value) in hotkeys.entries)
          key: value == null ? null : ShipglowsKeyTrigger(value),
      });

  /// Gives binding [id] the trigger [trigger]; null leaves it unassigned.
  Future<ShipglowsHotkeyResult> setTrigger(
    String id,
    ShipglowsTrigger? trigger,
  ) => setAllTriggers({id: trigger});

  /// Changes several triggers at once, all or none. Saved when applied.
  Future<ShipglowsHotkeyResult> setAllTriggers(
    Map<String, ShipglowsTrigger?> triggers,
  ) => _serial(() => _setAll(triggers));

  /// Forgets the user's choice for [id]: its default applies again.
  Future<ShipglowsHotkeyState> reset(String id) => _serial(() async {
    if (!_choices.containsKey(id)) return _state.value;
    final choices = {..._choices}..remove(id);
    if (!await store.save(choices)) return _state.value;
    _choices = choices;
    return _apply(_bindings);
  });

  /// Runs [action] on [window] (an HWND; for volume actions none is needed).
  /// [x] and [y] are screen pixels for [ShipglowsWindowAction.snapToPointer].
  /// Returns the outcome of [ShipglowsActionEvent.outcome].
  Future<String> run(
    ShipglowsWindowAction action, {
    int? window,
    int? x,
    int? y,
  }) async {
    if (!isSupported) return 'failed';
    final outcome = await _invoke<String>('windowAction', {
      'action': action.name,
      'window': window ?? 0,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
    });
    return outcome ?? 'failed';
  }

  /// Unregisters every trigger and stops [events].
  Future<void> dispose() => _serial(() async {
    if (isSupported) await _invoke<void>('unregisterAll');
    if (identical(_current, this)) {
      _current = null;
      if (isSupported) _channel.setMethodCallHandler(null);
    }
    await _events.close();
    await _actionEvents.close();
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
    final active = <String, ShipglowsTrigger>{};
    final conflicts = <String, ShipglowsHotkeyConflict>{};
    for (final binding in bindings) {
      final trigger = _choices.containsKey(binding.id)
          ? _choices[binding.id]
          : binding.defaultTrigger;
      if (trigger == null) continue;
      final conflict = !trigger.isValid
          ? ShipglowsHotkeyConflict.invalid
          : active.containsValue(trigger)
          ? ShipglowsHotkeyConflict.duplicate
          : await _register(binding, trigger);
      if (conflict == null) {
        active[binding.id] = trigger;
      } else {
        conflicts[binding.id] = conflict;
      }
    }
    return _state.value = ShipglowsHotkeyState(
      triggers: active,
      conflicts: conflicts,
    );
  }

  Future<ShipglowsHotkeyResult> _setAll(
    Map<String, ShipglowsTrigger?> triggers,
  ) async {
    final previous = _state.value;
    final declared = {for (final binding in _bindings) binding.id: binding};
    final next = {...previous.triggers}
      ..removeWhere((id, _) => triggers.containsKey(id));
    final conflicts = <String, ShipglowsHotkeyConflict>{};
    for (final MapEntry(key: id, value: trigger) in triggers.entries) {
      if (!declared.containsKey(id) ||
          (trigger != null && !trigger.isValid)) {
        conflicts[id] = ShipglowsHotkeyConflict.invalid;
      } else if (trigger == null) {
        continue;
      } else if (next.containsValue(trigger)) {
        conflicts[id] = ShipglowsHotkeyConflict.duplicate;
      } else {
        next[id] = trigger;
      }
    }
    if (conflicts.isNotEmpty || !isSupported) {
      return ShipglowsHotkeyResult(applied: false, conflicts: conflicts);
    }

    // The old triggers go first, so two bindings can swap.
    for (final id in triggers.keys) {
      if (previous.triggers.containsKey(id)) await _unregister(id);
    }
    final registered = <String>[];
    for (final MapEntry(key: id, value: trigger) in triggers.entries) {
      if (trigger == null) continue;
      final conflict = await _register(declared[id]!, trigger);
      if (conflict != null) {
        conflicts[id] = conflict;
        break;
      }
      registered.add(id);
    }
    if (conflicts.isEmpty) {
      final choices = {..._choices, ...triggers};
      if (await store.save(choices)) {
        _choices = choices;
        _state.value = ShipglowsHotkeyState(
          triggers: next,
          conflicts: {...previous.conflicts}
            ..removeWhere((id, _) => triggers.containsKey(id)),
        );
        return const ShipglowsHotkeyResult(applied: true);
      }
      for (final id in triggers.keys) {
        conflicts[id] = ShipglowsHotkeyConflict.persistFailed;
      }
    }

    // Undo: the previous triggers back in place.
    for (final id in registered) {
      await _unregister(id);
    }
    final active = {...previous.triggers};
    final lost = <String, ShipglowsHotkeyConflict>{};
    for (final id in triggers.keys) {
      final old = previous.triggers[id];
      if (old == null) continue;
      final conflict = await _register(declared[id]!, old);
      if (conflict != null) {
        active.remove(id);
        lost[id] = conflict;
      }
    }
    if (lost.isNotEmpty) {
      _state.value = ShipglowsHotkeyState(
        triggers: active,
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
    ShipglowsHotkeyBinding binding,
    ShipglowsTrigger trigger,
  ) async {
    final slot = _slotFor(binding.id);
    final String? outcome;
    switch (trigger) {
      case ShipglowsKeyTrigger(:final hotkey):
        outcome = await _invoke<String>('register', {
          'slot': slot,
          'modifiers': hotkey.modifiers,
          'key': hotkey.key,
          'hookFallback': hookFallback,
        });
      case ShipglowsDoubleKeyTrigger() || ShipglowsMouseTrigger():
        outcome = await _invoke<String>('registerTrigger', {
          'slot': slot,
          ...trigger.toJson(),
          'exclude': [
            for (final name in binding.excludeProcesses) name.toLowerCase(),
          ],
        });
    }
    return switch (outcome) {
      'registered' || 'hook' => null,
      'alreadyRegistered' => ShipglowsHotkeyConflict.alreadyRegistered,
      'invalid' => ShipglowsHotkeyConflict.invalid,
      _ => ShipglowsHotkeyConflict.failed,
    };
  }

  Future<void> _unregister(String id) =>
      _invoke<void>('unregister', {'slot': _slotFor(id)});

  /// The native slot of [id] (the `RegisterHotKey` id), stable for the life of
  /// the instance.
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
    int? number(String key) {
      final value = arguments[key];
      return value is int ? value : null;
    }

    final previous = number('previousForeground');
    final window = number('window');
    final event = ShipglowsHotkeyEvent(
      id: id,
      foreground:
          ShipglowsHotkeyForeground.values.asNameMap()[arguments['foreground']] ??
          ShipglowsHotkeyForeground.none,
      previousForeground: previous != null && previous != 0 ? previous : null,
      window: window != null && window != 0 ? window : null,
      x: number('x'),
      y: number('y'),
      startX: number('startX'),
      startY: number('startY'),
    );
    hotkeys._events.add(event);
    final action = hotkeys._actionOf(id);
    if (action != null) unawaited(hotkeys._runBound(id, action, event));
  }

  ShipglowsWindowAction? _actionOf(String id) {
    for (final binding in _bindings) {
      if (binding.id == id) return binding.action;
    }
    return null;
  }

  Future<void> _runBound(
    String id,
    ShipglowsWindowAction action,
    ShipglowsHotkeyEvent event,
  ) async {
    final outcome = await run(
      action,
      window: event.window,
      x: event.x,
      y: event.y,
    );
    if (!_actionEvents.isClosed) {
      _actionEvents.add(
        ShipglowsActionEvent(id: id, action: action, outcome: outcome),
      );
    }
  }
}

/// [ShipglowsHotkeys] holds every kind of trigger; this name says so.
typedef ShipglowsTriggers = ShipglowsHotkeys;
