import 'package:flutter/material.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

/// What a message reports. Each kind has its own icon as well as its color,
/// so the kind never rests on color alone.
enum FeedbackKind {
  /// Neutral news: an action done, a hint.
  info(Icons.info_outline, Duration(seconds: 4)),

  /// Saved, sent, synced.
  success(Icons.check_circle_outline, Duration(seconds: 4)),

  /// Needs attention but nothing failed: offline, partial result.
  warning(Icons.warning_amber_rounded, Duration(seconds: 6)),

  /// Something failed; says what and, when there is one, what to do.
  error(Icons.error_outline, Duration(seconds: 8));

  const FeedbackKind(this.icon, this.duration);

  /// Icon shown before the message.
  final IconData icon;

  /// How long the message stays by default: longer for what needs reading.
  final Duration duration;

  /// Color of the icon, from the app's [ShipglowsTheme].
  Color colorOf(ShipglowsTheme theme) => switch (this) {
    FeedbackKind.info => theme.accent,
    FeedbackKind.success => theme.success,
    FeedbackKind.warning => theme.warning,
    FeedbackKind.error => theme.danger,
  };
}
