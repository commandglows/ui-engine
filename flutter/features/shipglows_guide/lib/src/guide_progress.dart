import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

/// What the user did with a tour: where they stopped, whether they saw it.
@immutable
class GuideProgress {
  const GuideProgress({
    this.stepIndex = 0,
    this.started = false,
    this.completed = false,
  });

  static const initial = GuideProgress();

  /// Step to resume from.
  final int stepIndex;

  /// The tour was shown at least once: first-visit triggers leave it alone.
  final bool started;

  /// Finished or skipped.
  final bool completed;

  GuideProgress copyWith({int? stepIndex, bool? started, bool? completed}) {
    return GuideProgress(
      stepIndex: stepIndex ?? this.stepIndex,
      started: started ?? this.started,
      completed: completed ?? this.completed,
    );
  }

  Map<String, Object?> toJson() => {
    'step': stepIndex,
    'started': started,
    'completed': completed,
  };

  factory GuideProgress.fromJson(Map<String, Object?> json) {
    return GuideProgress(
      stepIndex: json['step'] is int ? json['step'] as int : 0,
      started: json['started'] == true,
      completed: json['completed'] == true,
    );
  }

  /// One string for a key-value store (`SharedPreferences.setString`).
  String encode() => jsonEncode(toJson());

  /// Reverse of [encode]; null for a missing or unreadable value.
  static GuideProgress? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      return json is Map<String, Object?> ? GuideProgress.fromJson(json) : null;
    } on FormatException {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is GuideProgress &&
      other.stepIndex == stepIndex &&
      other.started == started &&
      other.completed == completed;

  @override
  int get hashCode => Object.hash(stepIndex, started, completed);
}

/// Where [GuideProgress] is kept, one entry per tour id.
abstract interface class GuideStore {
  FutureOr<GuideProgress?> read(String tourId);
  FutureOr<void> write(String tourId, GuideProgress progress);
}

/// Forgets everything when the app closes. The default.
class MemoryGuideStore implements GuideStore {
  final _entries = <String, GuideProgress>{};

  @override
  GuideProgress? read(String tourId) => _entries[tourId];

  @override
  void write(String tourId, GuideProgress progress) {
    _entries[tourId] = progress;
  }
}

/// Backs the progress with the app's storage (`SharedPreferences`, user
/// settings…), for example:
///
/// ```dart
/// CallbackGuideStore(
///   onRead: (id) async => GuideProgress.decode(
///     (await SharedPreferences.getInstance()).getString('guide:$id')),
///   onWrite: (id, p) async =>
///     (await SharedPreferences.getInstance()).setString('guide:$id', p.encode()),
/// )
/// ```
class CallbackGuideStore implements GuideStore {
  const CallbackGuideStore({required this.onRead, required this.onWrite});

  final FutureOr<GuideProgress?> Function(String tourId) onRead;
  final FutureOr<void> Function(String tourId, GuideProgress progress) onWrite;

  @override
  FutureOr<GuideProgress?> read(String tourId) => onRead(tourId);

  @override
  FutureOr<void> write(String tourId, GuideProgress progress) =>
      onWrite(tourId, progress);
}
