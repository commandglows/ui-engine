import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Look of the guide card and spotlight. Every null value falls back on the
/// `ColorScheme`.
@immutable
class GuideThemeData extends ThemeExtension<GuideThemeData> {
  const GuideThemeData({
    this.accentColor,
    this.onAccentColor,
    this.surfaceColor,
    this.scrimColor,
    this.maxWidth,
    this.borderRadius,
    this.spotlightPadding,
    this.spotlightRadius,
    this.floatingBottomOffset,
  });

  /// Progress, ring, hint and primary button (default: `primary`).
  final Color? accentColor;
  final Color? onAccentColor;

  /// Card background (default: `surfaceContainerHigh`).
  final Color? surfaceColor;

  /// Dims the screen around the target (default: `scrim` at 55 %).
  final Color? scrimColor;

  /// Card width at most (default 420).
  final double? maxWidth;
  final double? borderRadius;

  /// Space between the target and the spotlight's edge (default 6).
  final double? spotlightPadding;
  final double? spotlightRadius;

  /// Distance from the bottom of a card without target, room for a bottom
  /// navigation bar (default 96).
  final double? floatingBottomOffset;

  /// The theme's values with every fallback applied.
  static GuideThemeData of(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final own = theme.extension<GuideThemeData>();
    final accent = own?.accentColor ?? scheme.primary;
    return GuideThemeData(
      accentColor: accent,
      onAccentColor:
          own?.onAccentColor ??
          (accent == scheme.primary
              ? scheme.onPrimary
              : ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
              ? Colors.white
              : Colors.black),
      surfaceColor: own?.surfaceColor ?? scheme.surfaceContainerHigh,
      scrimColor: own?.scrimColor ?? scheme.scrim.withValues(alpha: 0.55),
      maxWidth: own?.maxWidth ?? 420,
      borderRadius: own?.borderRadius ?? 16,
      spotlightPadding: own?.spotlightPadding ?? 6,
      spotlightRadius: own?.spotlightRadius ?? 12,
      floatingBottomOffset: own?.floatingBottomOffset ?? 96,
    );
  }

  @override
  GuideThemeData copyWith({
    Color? accentColor,
    Color? onAccentColor,
    Color? surfaceColor,
    Color? scrimColor,
    double? maxWidth,
    double? borderRadius,
    double? spotlightPadding,
    double? spotlightRadius,
    double? floatingBottomOffset,
  }) {
    return GuideThemeData(
      accentColor: accentColor ?? this.accentColor,
      onAccentColor: onAccentColor ?? this.onAccentColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      scrimColor: scrimColor ?? this.scrimColor,
      maxWidth: maxWidth ?? this.maxWidth,
      borderRadius: borderRadius ?? this.borderRadius,
      spotlightPadding: spotlightPadding ?? this.spotlightPadding,
      spotlightRadius: spotlightRadius ?? this.spotlightRadius,
      floatingBottomOffset: floatingBottomOffset ?? this.floatingBottomOffset,
    );
  }

  @override
  GuideThemeData lerp(GuideThemeData? other, double t) {
    if (other == null) return this;
    return GuideThemeData(
      accentColor: Color.lerp(accentColor, other.accentColor, t),
      onAccentColor: Color.lerp(onAccentColor, other.onAccentColor, t),
      surfaceColor: Color.lerp(surfaceColor, other.surfaceColor, t),
      scrimColor: Color.lerp(scrimColor, other.scrimColor, t),
      maxWidth: lerpDouble(maxWidth, other.maxWidth, t),
      borderRadius: lerpDouble(borderRadius, other.borderRadius, t),
      spotlightPadding: lerpDouble(spotlightPadding, other.spotlightPadding, t),
      spotlightRadius: lerpDouble(spotlightRadius, other.spotlightRadius, t),
      floatingBottomOffset: lerpDouble(
        floatingBottomOffset,
        other.floatingBottomOffset,
        t,
      ),
    );
  }
}
