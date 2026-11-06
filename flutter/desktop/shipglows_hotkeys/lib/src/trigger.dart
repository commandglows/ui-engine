import 'package:flutter/foundation.dart';

import 'hotkey.dart';

/// A mouse button a [ShipglowsMouseTrigger] reacts to.
enum ShipglowsMouseButton { left, right, middle, x1, x2 }

/// What the user does with the mouse.
enum ShipglowsMouseGesture {
  /// A press of [ShipglowsMouseTrigger.button]. The click is swallowed: the
  /// application under the pointer does not see it.
  click,

  /// A press kept still for [ShipglowsMouseTrigger.delayMs]. The press goes
  /// through, so a normal drag or click keeps working; moving more than a few
  /// pixels cancels the hold.
  hold,

  /// A press moved at least [ShipglowsMouseTrigger.distance] pixels before the
  /// release. Reports where it started and where it ended; nothing is
  /// swallowed.
  drag,

  /// A turn of the wheel away from the user. Swallowed.
  wheelUp,

  /// A turn of the wheel towards the user. Swallowed.
  wheelDown,

  /// The pointer rests in a screen corner ([ShipglowsZone.cornerTopLeft]…)
  /// for [ShipglowsMouseTrigger.delayMs].
  touch,
}

/// Where the pointer must be for a [ShipglowsMouseTrigger] to match.
enum ShipglowsZone {
  /// Over any window or the desktop. Needs a modifier key for every gesture
  /// but [ShipglowsMouseGesture.touch], or it would hijack the plain mouse.
  anywhere,

  /// The title bar of a window (also the top strip of frameless Electron
  /// windows whose menu bar is hidden).
  titleBar,

  /// The taskbar, on the main screen or a secondary one.
  taskbar,

  /// The minimize, maximize or close button of a window.
  minimizeButton,
  maximizeButton,
  closeButton,

  /// A screen corner, a few pixels wide. For [ShipglowsMouseGesture.touch].
  cornerTopLeft,
  cornerTopRight,
  cornerBottomLeft,
  cornerBottomRight;

  bool get isCorner => index >= ShipglowsZone.cornerTopLeft.index;
}

/// Words of a trigger's label ([ShipglowsTrigger.label]).
@immutable
class ShipglowsTriggerLabels {
  const ShipglowsTriggerLabels({
    this.keys = ShipglowsHotkeyLabels.en,
    this.twice = '×2',
    this.left = 'Left click',
    this.right = 'Right click',
    this.middle = 'Middle click',
    this.x1 = 'Back button',
    this.x2 = 'Forward button',
    this.hold = 'hold',
    this.drag = 'drag',
    this.wheelUp = 'Wheel up',
    this.wheelDown = 'Wheel down',
    this.touch = 'Touch',
    this.on = 'on',
    this.anywhere = 'anywhere',
    this.titleBar = 'title bar',
    this.taskbar = 'taskbar',
    this.minimizeButton = 'minimize button',
    this.maximizeButton = 'maximize button',
    this.closeButton = 'close button',
    this.cornerTopLeft = 'top-left corner',
    this.cornerTopRight = 'top-right corner',
    this.cornerBottomLeft = 'bottom-left corner',
    this.cornerBottomRight = 'bottom-right corner',
  });

  static const en = ShipglowsTriggerLabels();

  static const fr = ShipglowsTriggerLabels(
    keys: ShipglowsHotkeyLabels.fr,
    left: 'Clic gauche',
    right: 'Clic droit',
    middle: 'Clic molette',
    x1: 'Bouton précédent',
    x2: 'Bouton suivant',
    hold: 'maintenu',
    drag: 'glisser',
    wheelUp: 'Molette vers le haut',
    wheelDown: 'Molette vers le bas',
    touch: 'Toucher',
    on: 'sur',
    anywhere: 'partout',
    titleBar: 'la barre de titre',
    taskbar: 'la barre des tâches',
    minimizeButton: 'le bouton Réduire',
    maximizeButton: 'le bouton Agrandir',
    closeButton: 'le bouton Fermer',
    cornerTopLeft: 'le coin haut gauche',
    cornerTopRight: 'le coin haut droit',
    cornerBottomLeft: 'le coin bas gauche',
    cornerBottomRight: 'le coin bas droit',
  );

  /// Words of the keyboard part.
  final ShipglowsHotkeyLabels keys;

  /// « Esc ×2 ».
  final String twice;
  final String left;
  final String right;
  final String middle;
  final String x1;
  final String x2;
  final String hold;
  final String drag;
  final String wheelUp;
  final String wheelDown;
  final String touch;

  /// Joins the gesture and its zone: « Wheel up on the taskbar ».
  final String on;
  final String anywhere;
  final String titleBar;
  final String taskbar;
  final String minimizeButton;
  final String maximizeButton;
  final String closeButton;
  final String cornerTopLeft;
  final String cornerTopRight;
  final String cornerBottomLeft;
  final String cornerBottomRight;

  String button(ShipglowsMouseButton button) => switch (button) {
    ShipglowsMouseButton.left => left,
    ShipglowsMouseButton.right => right,
    ShipglowsMouseButton.middle => middle,
    ShipglowsMouseButton.x1 => x1,
    ShipglowsMouseButton.x2 => x2,
  };

  String zone(ShipglowsZone zone) => switch (zone) {
    ShipglowsZone.anywhere => anywhere,
    ShipglowsZone.titleBar => titleBar,
    ShipglowsZone.taskbar => taskbar,
    ShipglowsZone.minimizeButton => minimizeButton,
    ShipglowsZone.maximizeButton => maximizeButton,
    ShipglowsZone.closeButton => closeButton,
    ShipglowsZone.cornerTopLeft => cornerTopLeft,
    ShipglowsZone.cornerTopRight => cornerTopRight,
    ShipglowsZone.cornerBottomLeft => cornerBottomLeft,
    ShipglowsZone.cornerBottomRight => cornerBottomRight,
  };
}

/// What starts an action: a key combination, a key pressed twice, or a mouse
/// gesture (with modifier keys held, for « mouse + keyboard »).
///
/// A trigger is a value: compare, save ([toJson]) and show ([label]) it. The
/// app gives one to each action through [ShipglowsHotkeys].
@immutable
sealed class ShipglowsTrigger {
  const ShipglowsTrigger();

  /// A key combination, such as Ctrl+Alt+Space, caught system-wide.
  const factory ShipglowsTrigger.key(ShipglowsHotkey hotkey) =
      ShipglowsKeyTrigger;

  /// Whether the trigger can be registered. An invalid one is reported as
  /// [ShipglowsHotkeyConflict.invalid].
  bool get isValid;

  /// « Ctrl+Alt+Space », « Esc ×2 », « Wheel up on the taskbar ».
  String label([ShipglowsTriggerLabels labels = ShipglowsTriggerLabels.en]);

  Map<String, Object?> toJson();

  /// Null when [json] is not something [toJson] wrote. A map without a `type`
  /// is a key combination written by an earlier version.
  static ShipglowsTrigger? fromJson(Object? json) {
    if (json is! Map) return null;
    switch (json['type']) {
      case null:
      case 'key':
        final hotkey = ShipglowsHotkey.fromJson(json);
        return hotkey == null ? null : ShipglowsKeyTrigger(hotkey);
      case 'doubleKey':
        final key = json['key'];
        final within = json['withinMs'];
        if (key is! int) return null;
        return ShipglowsDoubleKeyTrigger(
          key,
          withinMs: within is int ? within : ShipglowsDoubleKeyTrigger.defaultWithinMs,
        );
      case 'mouse':
        return ShipglowsMouseTrigger._fromJson(json);
      default:
        return null;
    }
  }
}

/// A key combination caught system-wide (Windows `RegisterHotKey`).
@immutable
final class ShipglowsKeyTrigger extends ShipglowsTrigger {
  const ShipglowsKeyTrigger(this.hotkey);

  final ShipglowsHotkey hotkey;

  @override
  bool get isValid => hotkey.isValid;

  @override
  String label([ShipglowsTriggerLabels labels = ShipglowsTriggerLabels.en]) =>
      hotkey.label(labels.keys);

  @override
  Map<String, Object?> toJson() => {'type': 'key', ...hotkey.toJson()};

  @override
  bool operator ==(Object other) =>
      other is ShipglowsKeyTrigger && other.hotkey == hotkey;

  @override
  int get hashCode => hotkey.hashCode;

  @override
  String toString() => 'ShipglowsKeyTrigger(${hotkey.label()})';
}

/// A single key pressed twice quickly, with no modifier: « Esc ×2 ».
///
/// Caught with a keyboard hook that never swallows the key, so the first
/// press still reaches the application. Choose a key whose single press is
/// harmless, and exclude the applications that use it
/// ([ShipglowsHotkeyBinding.excludeProcesses]).
@immutable
final class ShipglowsDoubleKeyTrigger extends ShipglowsTrigger {
  const ShipglowsDoubleKeyTrigger(
    this.key, {
    this.withinMs = defaultWithinMs,
  });

  static const defaultWithinMs = 400;

  /// Windows virtual-key code ([ShipglowsKey]).
  final int key;

  /// Longest delay between the two presses.
  final int withinMs;

  @override
  bool get isValid =>
      key > 0 &&
      key < 0xFF &&
      !ShipglowsKey.isModifier(key) &&
      withinMs >= 150 &&
      withinMs <= 1500;

  @override
  String label([ShipglowsTriggerLabels labels = ShipglowsTriggerLabels.en]) =>
      '${ShipglowsHotkey(key).label(labels.keys)} ${labels.twice}';

  @override
  Map<String, Object?> toJson() => {
    'type': 'doubleKey',
    'key': key,
    'withinMs': withinMs,
  };

  @override
  bool operator ==(Object other) =>
      other is ShipglowsDoubleKeyTrigger && other.key == key;

  @override
  int get hashCode => Object.hash('doubleKey', key);

  @override
  String toString() => 'ShipglowsDoubleKeyTrigger(0x${key.toRadixString(16)})';
}

/// A mouse gesture in a [zone], with modifier keys held for
/// « mouse + keyboard »: Ctrl+wheel up anywhere, middle click on a title bar…
///
/// Caught with a low-level mouse hook, which is installed only while such a
/// trigger is active.
@immutable
final class ShipglowsMouseTrigger extends ShipglowsTrigger {
  const ShipglowsMouseTrigger(
    this.gesture, {
    this.button,
    this.zone = ShipglowsZone.anywhere,
    this.control = false,
    this.alt = false,
    this.shift = false,
    this.meta = false,
    this.delayMs,
    this.distance = defaultDragDistance,
  });

  const ShipglowsMouseTrigger.wheelUp({
    this.zone = ShipglowsZone.anywhere,
    this.control = false,
    this.alt = false,
    this.shift = false,
    this.meta = false,
  }) : gesture = ShipglowsMouseGesture.wheelUp,
       button = null,
       delayMs = null,
       distance = defaultDragDistance;

  const ShipglowsMouseTrigger.wheelDown({
    this.zone = ShipglowsZone.anywhere,
    this.control = false,
    this.alt = false,
    this.shift = false,
    this.meta = false,
  }) : gesture = ShipglowsMouseGesture.wheelDown,
       button = null,
       delayMs = null,
       distance = defaultDragDistance;

  const ShipglowsMouseTrigger.click(
    ShipglowsMouseButton this.button, {
    this.zone = ShipglowsZone.anywhere,
    this.control = false,
    this.alt = false,
    this.shift = false,
    this.meta = false,
  }) : gesture = ShipglowsMouseGesture.click,
       delayMs = null,
       distance = defaultDragDistance;

  const ShipglowsMouseTrigger.hold(
    ShipglowsMouseButton this.button, {
    this.zone = ShipglowsZone.anywhere,
    this.control = false,
    this.alt = false,
    this.shift = false,
    this.meta = false,
    this.delayMs,
  }) : gesture = ShipglowsMouseGesture.hold,
       distance = defaultDragDistance;

  const ShipglowsMouseTrigger.drag(
    ShipglowsMouseButton this.button, {
    this.zone = ShipglowsZone.anywhere,
    this.control = false,
    this.alt = false,
    this.shift = false,
    this.meta = false,
    this.distance = defaultDragDistance,
  }) : gesture = ShipglowsMouseGesture.drag,
       delayMs = null;

  /// The pointer rests in the screen corner [zone].
  const ShipglowsMouseTrigger.touch(
    ShipglowsZone this.zone, {
    this.control = false,
    this.alt = false,
    this.shift = false,
    this.meta = false,
    this.delayMs,
  }) : gesture = ShipglowsMouseGesture.touch,
       button = null,
       distance = defaultDragDistance;

  static const defaultDragDistance = 60;
  static const defaultHoldMs = 1000;
  static const defaultTouchMs = 300;

  final ShipglowsMouseGesture gesture;

  /// The button of a click, hold or drag; null for the wheel and touch.
  final ShipglowsMouseButton? button;
  final ShipglowsZone zone;
  final bool control;
  final bool alt;
  final bool shift;

  /// The Windows key.
  final bool meta;

  /// How long a hold or touch lasts; null: [defaultHoldMs] or
  /// [defaultTouchMs].
  final int? delayMs;

  /// Least distance of a drag, in pixels.
  final int distance;

  /// `RegisterHotKey` modifiers: Alt=1, Ctrl=2, Shift=4, Win=8.
  int get modifiers =>
      (alt ? 0x1 : 0) | (control ? 0x2 : 0) | (shift ? 0x4 : 0) | (meta ? 0x8 : 0);

  /// [delayMs], or the default of the gesture.
  int get effectiveDelayMs =>
      delayMs ??
      (gesture == ShipglowsMouseGesture.touch ? defaultTouchMs : defaultHoldMs);

  @override
  bool get isValid {
    final needsButton =
        gesture == ShipglowsMouseGesture.click ||
        gesture == ShipglowsMouseGesture.hold ||
        gesture == ShipglowsMouseGesture.drag;
    if (needsButton != (button != null)) return false;
    if (gesture == ShipglowsMouseGesture.touch) {
      return zone.isCorner && effectiveDelayMs >= 50 && effectiveDelayMs <= 5000;
    }
    if (zone.isCorner) return false;
    if (zone == ShipglowsZone.anywhere && modifiers == 0) return false;
    if (gesture == ShipglowsMouseGesture.click &&
        button == ShipglowsMouseButton.left &&
        modifiers == 0) {
      // A swallowed plain left click would break the title bar, the taskbar
      // and every button.
      return false;
    }
    if (gesture == ShipglowsMouseGesture.hold &&
        (effectiveDelayMs < 200 || effectiveDelayMs > 5000)) {
      return false;
    }
    if (gesture == ShipglowsMouseGesture.drag &&
        (distance < 20 || distance > 2000)) {
      return false;
    }
    return true;
  }

  @override
  String label([ShipglowsTriggerLabels labels = ShipglowsTriggerLabels.en]) {
    final modifierWords = [
      if (control) labels.keys.control,
      if (alt) labels.keys.alt,
      if (shift) labels.keys.shift,
      if (meta) labels.keys.meta,
    ];
    final gestureWord = switch (gesture) {
      ShipglowsMouseGesture.click => labels.button(button!),
      ShipglowsMouseGesture.hold =>
        '${labels.button(button!)} ${labels.hold}',
      ShipglowsMouseGesture.drag => '${labels.button(button!)} ${labels.drag}',
      ShipglowsMouseGesture.wheelUp => labels.wheelUp,
      ShipglowsMouseGesture.wheelDown => labels.wheelDown,
      ShipglowsMouseGesture.touch => labels.touch,
    };
    final head = [...modifierWords, gestureWord].join('+');
    return zone == ShipglowsZone.anywhere
        ? head
        : '$head ${labels.on} ${labels.zone(zone)}';
  }

  @override
  Map<String, Object?> toJson() => {
    'type': 'mouse',
    'gesture': gesture.name,
    if (button != null) 'button': button!.name,
    'zone': zone.name,
    'modifiers': modifiers,
    if (delayMs != null) 'delayMs': delayMs,
    'distance': distance,
  };

  static ShipglowsMouseTrigger? _fromJson(Map<Object?, Object?> json) {
    final gesture = ShipglowsMouseGesture.values.asNameMap()[json['gesture']];
    final zone = ShipglowsZone.values.asNameMap()[json['zone']];
    final modifiers = json['modifiers'];
    if (gesture == null || zone == null || modifiers is! int) return null;
    final buttonName = json['button'];
    final button = ShipglowsMouseButton.values.asNameMap()[buttonName];
    if (buttonName != null && button == null) return null;
    final delay = json['delayMs'];
    final distance = json['distance'];
    return ShipglowsMouseTrigger(
      gesture,
      button: button,
      zone: zone,
      alt: (modifiers & 0x1) != 0,
      control: (modifiers & 0x2) != 0,
      shift: (modifiers & 0x4) != 0,
      meta: (modifiers & 0x8) != 0,
      delayMs: delay is int ? delay : null,
      distance: distance is int ? distance : defaultDragDistance,
    );
  }

  /// Two triggers conflict when the same gesture in the same zone is asked
  /// with the same modifiers, whatever the delay or distance.
  @override
  bool operator ==(Object other) =>
      other is ShipglowsMouseTrigger &&
      other.gesture == gesture &&
      other.button == button &&
      other.zone == zone &&
      other.modifiers == modifiers;

  @override
  int get hashCode => Object.hash(gesture, button, zone, modifiers);

  @override
  String toString() => 'ShipglowsMouseTrigger(${label()})';
}
