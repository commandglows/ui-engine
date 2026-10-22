import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Customises the Flutter action menu. Every null field falls back to the
/// app's `ColorScheme` and `TextTheme`.
///
/// ```dart
/// ThemeData(extensions: const [ShipglowsMenuTheme(width: 340)])
/// ```
@immutable
class ShipglowsMenuTheme extends ThemeExtension<ShipglowsMenuTheme> {
  const ShipglowsMenuTheme({
    this.backgroundColor,
    this.borderColor,
    this.highlightColor,
    this.foregroundColor,
    this.mutedColor,
    this.keycapColor,
    this.keycapForegroundColor,
    this.width,
    this.maxHeight,
    this.radius,
    this.rowHeight,
    this.shadows,
    this.labelStyle,
    this.icons,
  });

  final Color? backgroundColor;
  final Color? borderColor;

  /// Background of the highlighted row (keyboard or pointer).
  final Color? highlightColor;
  final Color? foregroundColor;

  /// Group titles, subtitle, disabled entries and the search placeholder.
  final Color? mutedColor;

  /// Background of the shortcut keys.
  final Color? keycapColor;
  final Color? keycapForegroundColor;

  /// Width of the menu (300 by default).
  final double? width;

  /// Height the menu never exceeds (440 by default), on top of the space
  /// the screen leaves.
  final double? maxHeight;
  final double? radius;

  /// Minimum row height; never below 44 (touch target).
  final double? rowHeight;
  final List<BoxShadow>? shadows;
  final TextStyle? labelStyle;

  /// Flutter icons by `ShipglowsMenuIcon.name`, over the built-in table.
  final Map<String, IconData>? icons;

  @override
  ShipglowsMenuTheme copyWith({
    Color? backgroundColor,
    Color? borderColor,
    Color? highlightColor,
    Color? foregroundColor,
    Color? mutedColor,
    Color? keycapColor,
    Color? keycapForegroundColor,
    double? width,
    double? maxHeight,
    double? radius,
    double? rowHeight,
    List<BoxShadow>? shadows,
    TextStyle? labelStyle,
    Map<String, IconData>? icons,
  }) => ShipglowsMenuTheme(
    backgroundColor: backgroundColor ?? this.backgroundColor,
    borderColor: borderColor ?? this.borderColor,
    highlightColor: highlightColor ?? this.highlightColor,
    foregroundColor: foregroundColor ?? this.foregroundColor,
    mutedColor: mutedColor ?? this.mutedColor,
    keycapColor: keycapColor ?? this.keycapColor,
    keycapForegroundColor: keycapForegroundColor ?? this.keycapForegroundColor,
    width: width ?? this.width,
    maxHeight: maxHeight ?? this.maxHeight,
    radius: radius ?? this.radius,
    rowHeight: rowHeight ?? this.rowHeight,
    shadows: shadows ?? this.shadows,
    labelStyle: labelStyle ?? this.labelStyle,
    icons: icons ?? this.icons,
  );

  @override
  ShipglowsMenuTheme lerp(ShipglowsMenuTheme? other, double t) {
    if (other == null) return this;
    return ShipglowsMenuTheme(
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t),
      borderColor: Color.lerp(borderColor, other.borderColor, t),
      highlightColor: Color.lerp(highlightColor, other.highlightColor, t),
      foregroundColor: Color.lerp(foregroundColor, other.foregroundColor, t),
      mutedColor: Color.lerp(mutedColor, other.mutedColor, t),
      keycapColor: Color.lerp(keycapColor, other.keycapColor, t),
      keycapForegroundColor: Color.lerp(
        keycapForegroundColor,
        other.keycapForegroundColor,
        t,
      ),
      width: lerpDouble(width, other.width, t),
      maxHeight: lerpDouble(maxHeight, other.maxHeight, t),
      radius: lerpDouble(radius, other.radius, t),
      rowHeight: lerpDouble(rowHeight, other.rowHeight, t),
      shadows: BoxShadow.lerpList(shadows, other.shadows, t),
      labelStyle: TextStyle.lerp(labelStyle, other.labelStyle, t),
      icons: t < 0.5 ? icons : other.icons,
    );
  }
}

/// [ShipglowsMenuTheme] with every value filled in for [context].
@immutable
class ResolvedShipglowsMenuTheme {
  const ResolvedShipglowsMenuTheme._({
    required this.backgroundColor,
    required this.borderColor,
    required this.highlightColor,
    required this.foregroundColor,
    required this.mutedColor,
    required this.keycapColor,
    required this.keycapForegroundColor,
    required this.width,
    required this.maxHeight,
    required this.radius,
    required this.rowHeight,
    required this.shadows,
    required this.labelStyle,
    required this.icons,
  });

  factory ResolvedShipglowsMenuTheme.of(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final custom =
        theme.extension<ShipglowsMenuTheme>() ?? const ShipglowsMenuTheme();
    final foreground = custom.foregroundColor ?? scheme.onSurface;
    return ResolvedShipglowsMenuTheme._(
      backgroundColor: custom.backgroundColor ?? scheme.surfaceContainerHigh,
      borderColor: custom.borderColor ?? scheme.outlineVariant,
      highlightColor:
          custom.highlightColor ?? scheme.onSurface.withValues(alpha: 0.10),
      foregroundColor: foreground,
      mutedColor: custom.mutedColor ?? scheme.onSurfaceVariant,
      keycapColor: custom.keycapColor ?? scheme.surfaceContainerHighest,
      keycapForegroundColor:
          custom.keycapForegroundColor ?? scheme.onSurfaceVariant,
      width: custom.width ?? 300,
      maxHeight: custom.maxHeight ?? 440,
      radius: custom.radius ?? 12,
      rowHeight: math.max(44, custom.rowHeight ?? 44),
      shadows:
          custom.shadows ??
          [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
      labelStyle: (theme.textTheme.bodyMedium ?? const TextStyle())
          .copyWith(color: foreground)
          .merge(custom.labelStyle),
      icons: custom.icons ?? const {},
    );
  }

  final Color backgroundColor;
  final Color borderColor;
  final Color highlightColor;
  final Color foregroundColor;
  final Color mutedColor;
  final Color keycapColor;
  final Color keycapForegroundColor;
  final double width;
  final double maxHeight;
  final double radius;
  final double rowHeight;
  final List<BoxShadow> shadows;
  final TextStyle labelStyle;
  final Map<String, IconData> icons;
}
