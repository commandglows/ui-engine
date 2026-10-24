import 'package:flutter/material.dart';
import 'package:shipglows_theme/shipglows_theme.dart';
import 'package:shipglows_icons/shipglows_icons.dart';

/// What a message reports. Each kind has its own icon as well as its color,
/// so the kind never rests on color alone.
enum FeedbackKind {
  /// Neutral news: an action done, a hint.
  info(ShipglowsIcons.info, Duration(seconds: 4)),

  /// Saved, sent, synced.
  success(ShipglowsIcons.success, Duration(seconds: 4)),

  /// Needs attention but nothing failed: offline, partial result.
  warning(ShipglowsIcons.warning, Duration(seconds: 6)),

  /// Something failed; says what and, when there is one, what to do.
  error(ShipglowsIcons.error, Duration(seconds: 8));

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
