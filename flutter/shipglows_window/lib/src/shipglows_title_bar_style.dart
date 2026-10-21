import 'package:flutter/material.dart';

/// Visual tokens of the title bar; each app passes its own brand values.
@immutable
class ShipglowsTitleBarStyle {
  const ShipglowsTitleBarStyle({
    required this.background,
    required this.foreground,
    required this.hoverBackground,
    required this.pressedBackground,
    this.closeHoverBackground = const Color(0xFFC42B1C),
    this.closeHoverForeground = const Color(0xFFFFFFFF),
    this.height = 40,
    this.buttonWidth = 46,
    this.bottomBorder,
  });

  /// Blends the bar into the app: scaffold background, on-surface glyphs.
  factory ShipglowsTitleBarStyle.fromTheme(ThemeData theme) {
    final scheme = theme.colorScheme;
    return ShipglowsTitleBarStyle(
      background: theme.scaffoldBackgroundColor,
      foreground: scheme.onSurface,
      hoverBackground: scheme.onSurface.withValues(alpha: 0.08),
      pressedBackground: scheme.onSurface.withValues(alpha: 0.14),
    );
  }

  /// Fill behind the whole bar.
  final Color background;

  /// Title text and caption glyph color.
  final Color foreground;

  /// Caption button fill while the pointer is over it.
  final Color hoverBackground;

  /// Caption button fill while pressed.
  final Color pressedBackground;

  /// Close button fill on hover, red by Windows convention.
  final Color closeHoverBackground;

  /// Close glyph color on hover.
  final Color closeHoverForeground;

  /// Bar height in logical pixels.
  final double height;

  /// Width of each caption button in logical pixels.
  final double buttonWidth;

  /// Optional separator under the bar.
  final BorderSide? bottomBorder;

  ShipglowsTitleBarStyle copyWith({
    Color? background,
    Color? foreground,
    Color? hoverBackground,
    Color? pressedBackground,
    Color? closeHoverBackground,
    Color? closeHoverForeground,
    double? height,
    double? buttonWidth,
    BorderSide? bottomBorder,
  }) {
    return ShipglowsTitleBarStyle(
      background: background ?? this.background,
      foreground: foreground ?? this.foreground,
      hoverBackground: hoverBackground ?? this.hoverBackground,
      pressedBackground: pressedBackground ?? this.pressedBackground,
      closeHoverBackground: closeHoverBackground ?? this.closeHoverBackground,
      closeHoverForeground: closeHoverForeground ?? this.closeHoverForeground,
      height: height ?? this.height,
      buttonWidth: buttonWidth ?? this.buttonWidth,
      bottomBorder: bottomBorder ?? this.bottomBorder,
    );
  }
}
