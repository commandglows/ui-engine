import 'package:flutter/foundation.dart';

import 'trigger.dart';

/// State of the low-level hooks behind the mouse triggers and the double keys,
/// for a diagnostic screen.
@immutable
class ShipglowsHookStatus {
  const ShipglowsHookStatus({
    this.mouseHook = false,
    this.keyboardHook = false,
    this.reinstalls = 0,
    this.fullscreen = false,
  });

  /// Whether the mouse hook is installed (a mouse trigger is active).
  final bool mouseHook;

  /// Whether the keyboard hook is installed (a double key is active).
  final bool keyboardHook;

  /// How many times the watchdog put the hooks back: every 30 seconds while
  /// idle, and after a sleep or an unlocked session. Windows silently drops a
  /// hook after those, or after a callback that took too long.
  final int reinstalls;

  /// Whether a full-screen program (a game, a presentation) is in front. The
  /// triggers rest meanwhile when `pauseInFullscreen` is on.
  final bool fullscreen;

  static ShipglowsHookStatus fromJson(Object? json) {
    if (json is! Map) return const ShipglowsHookStatus();
    return ShipglowsHookStatus(
      mouseHook: json['mouseHook'] == true,
      keyboardHook: json['keyboardHook'] == true,
      reinstalls: json['reinstalls'] is int ? json['reinstalls'] as int : 0,
      fullscreen: json['fullscreen'] == true,
    );
  }
}

/// What is under the pointer, as the mouse triggers see it: lets an app show
/// « this is the title bar of code.exe » to explain why a gesture did or did
/// not fire.
@immutable
class ShipglowsPointerInfo {
  const ShipglowsPointerInfo({
    required this.x,
    required this.y,
    this.window,
    this.process,
    this.className,
    this.title,
    this.zones = const {},
  });

  /// Pointer position, in screen pixels.
  final int x;
  final int y;

  /// Handle (HWND) of the top-level window under the pointer.
  final int? window;

  /// Executable name in lower case (`code.exe`).
  final String? process;
  final String? className;
  final String? title;

  /// Every zone the pointer is in right now.
  final Set<ShipglowsZone> zones;

  static ShipglowsPointerInfo? fromJson(Object? json) {
    if (json is! Map || json['x'] is! int || json['y'] is! int) return null;
    String? text(String key) {
      final value = json[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    final window = json['window'];
    final names = json['zones'];
    final zones = ShipglowsZone.values.asNameMap();
    return ShipglowsPointerInfo(
      x: json['x'] as int,
      y: json['y'] as int,
      window: window is int && window != 0 ? window : null,
      process: text('process'),
      className: text('className'),
      title: text('title'),
      zones: {
        if (names is List)
          for (final name in names)
            if (zones[name] case final zone?) zone,
      },
    );
  }
}
