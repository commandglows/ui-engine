import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// The semantic roles every ShipGlows surface draws with, set once in the
/// app theme: `ThemeData(extensions: [ShipglowsTheme(...)])`.
///
/// The values are the app's brand (generated from its design tokens); the
/// roles are shared, so the command bar, menus, guide and title bar of every
/// app follow the same rules. Without one in the theme,
/// [ShipglowsTheme.of] derives the roles from the [ColorScheme].
@immutable
class ShipglowsTheme extends ThemeExtension<ShipglowsTheme> {
  const ShipglowsTheme({
    required this.surface,
    required this.surfaceRaised,
    required this.text,
    required this.textMuted,
    required this.icon,
    required this.border,
    required this.line,
    required this.highlight,
    required this.onHighlight,
    required this.accent,
    required this.onAccent,
    required this.danger,
    required this.focus,
    required this.scrim,
    required this.keyBackground,
    required this.keyForeground,
    required this.keyBorder,
    required this.keyShadow,
    this.lineWidth = 1,
    this.radiusSm = 6,
    this.radiusMd = 10,
    this.radiusLg = 16,
    this.spaceXs = 4,
    this.spaceSm = 8,
    this.spaceMd = 12,
    this.spaceLg = 16,
    this.spaceXl = 24,
    this.keyMinSize = 22,
    this.keyDepth = 1,
    this.keyPaddingX = 6,
    this.keyLabelStyle,
    this.controlMinHeight = 44,
    this.motionFast = const Duration(milliseconds: 120),
    this.motionNormal = const Duration(milliseconds: 200),
  });

  /// Roles taken from [scheme], for an app that declares no brand values.
  factory ShipglowsTheme.fallback(ColorScheme scheme) => ShipglowsTheme(
    surface: scheme.surface,
    surfaceRaised: scheme.surfaceContainerHigh,
    text: scheme.onSurface,
    textMuted: scheme.onSurfaceVariant,
    icon: scheme.onSurfaceVariant,
    border: scheme.outlineVariant,
    line: scheme.outline,
    highlight: scheme.secondaryContainer,
    onHighlight: scheme.onSecondaryContainer,
    accent: scheme.primary,
    onAccent: scheme.onPrimary,
    danger: scheme.error,
    focus: scheme.primary,
    scrim: scheme.scrim.withValues(alpha: 0.32),
    keyBackground: scheme.surface,
    keyForeground: scheme.onSurfaceVariant,
    keyBorder: scheme.outlineVariant,
    keyShadow: scheme.outline,
  );

  /// The roles of [context]: the app's [ShipglowsTheme], or
  /// [ShipglowsTheme.fallback] from its color scheme.
  static ShipglowsTheme of(BuildContext context) => from(Theme.of(context));

  /// The roles of [theme], for code that holds a [ThemeData] rather than a
  /// context.
  static ShipglowsTheme from(ThemeData theme) =>
      theme.extension<ShipglowsTheme>() ??
      ShipglowsTheme.fallback(theme.colorScheme);

  /// Page background.
  final Color surface;

  /// Raised surfaces: dialogs, menus, the command bar.
  final Color surfaceRaised;

  /// Main text.
  final Color text;

  /// Secondary text, hints, section titles.
  final Color textMuted;

  /// Icons at rest.
  final Color icon;

  /// Dividers and quiet outlines.
  final Color border;

  /// Strong outline, the brand's ink.
  final Color line;

  /// Background of the highlighted or selected item.
  final Color highlight;

  /// Text and icons on [highlight].
  final Color onHighlight;

  /// Brand accent: primary actions, active marks.
  final Color accent;

  /// Text and icons on [accent].
  final Color onAccent;

  /// Destructive actions and errors.
  final Color danger;

  /// Focus ring.
  final Color focus;

  /// Scrim behind a modal surface.
  final Color scrim;

  /// Keycap face.
  final Color keyBackground;

  /// Keycap label.
  final Color keyForeground;

  /// Keycap outline.
  final Color keyBorder;

  /// Hard shadow under a keycap, its depth.
  final Color keyShadow;

  /// Width of outlines.
  final double lineWidth;

  /// Small radius: keycaps, chips.
  final double radiusSm;

  /// Medium radius: rows, buttons.
  final double radiusMd;

  /// Large radius: dialogs, menus.
  final double radiusLg;

  /// Spacing scale.
  final double spaceXs;
  final double spaceSm;
  final double spaceMd;
  final double spaceLg;
  final double spaceXl;

  /// Minimum width and height of a keycap.
  final double keyMinSize;

  /// Height of the hard shadow under a keycap.
  final double keyDepth;

  /// Space on each side of a keycap's label.
  final double keyPaddingX;

  /// Keycap label, over the bold `labelSmall` of the text theme.
  final TextStyle? keyLabelStyle;

  /// Minimum height of a control, at least the touch target.
  final double controlMinHeight;

  /// Quick feedback: hover, press.
  final Duration motionFast;

  /// Regular transitions: open, close, move.
  final Duration motionNormal;

  @override
  ShipglowsTheme copyWith({
    Color? surface,
    Color? surfaceRaised,
    Color? text,
    Color? textMuted,
    Color? icon,
    Color? border,
    Color? line,
    Color? highlight,
    Color? onHighlight,
    Color? accent,
    Color? onAccent,
    Color? danger,
    Color? focus,
    Color? scrim,
    Color? keyBackground,
    Color? keyForeground,
    Color? keyBorder,
    Color? keyShadow,
    double? lineWidth,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? spaceXs,
    double? spaceSm,
    double? spaceMd,
    double? spaceLg,
    double? spaceXl,
    double? keyMinSize,
    double? keyDepth,
    double? keyPaddingX,
    TextStyle? keyLabelStyle,
    double? controlMinHeight,
    Duration? motionFast,
    Duration? motionNormal,
  }) => ShipglowsTheme(
    surface: surface ?? this.surface,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    text: text ?? this.text,
    textMuted: textMuted ?? this.textMuted,
    icon: icon ?? this.icon,
    border: border ?? this.border,
    line: line ?? this.line,
    highlight: highlight ?? this.highlight,
    onHighlight: onHighlight ?? this.onHighlight,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    danger: danger ?? this.danger,
    focus: focus ?? this.focus,
    scrim: scrim ?? this.scrim,
    keyBackground: keyBackground ?? this.keyBackground,
    keyForeground: keyForeground ?? this.keyForeground,
    keyBorder: keyBorder ?? this.keyBorder,
    keyShadow: keyShadow ?? this.keyShadow,
    lineWidth: lineWidth ?? this.lineWidth,
    radiusSm: radiusSm ?? this.radiusSm,
    radiusMd: radiusMd ?? this.radiusMd,
    radiusLg: radiusLg ?? this.radiusLg,
    spaceXs: spaceXs ?? this.spaceXs,
    spaceSm: spaceSm ?? this.spaceSm,
    spaceMd: spaceMd ?? this.spaceMd,
    spaceLg: spaceLg ?? this.spaceLg,
    spaceXl: spaceXl ?? this.spaceXl,
    keyMinSize: keyMinSize ?? this.keyMinSize,
    keyDepth: keyDepth ?? this.keyDepth,
    keyPaddingX: keyPaddingX ?? this.keyPaddingX,
    keyLabelStyle: keyLabelStyle ?? this.keyLabelStyle,
    controlMinHeight: controlMinHeight ?? this.controlMinHeight,
    motionFast: motionFast ?? this.motionFast,
    motionNormal: motionNormal ?? this.motionNormal,
  );

  @override
  ShipglowsTheme lerp(ShipglowsTheme? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    double d(double a, double b) => lerpDouble(a, b, t)!;
    return ShipglowsTheme(
      surface: c(surface, other.surface),
      surfaceRaised: c(surfaceRaised, other.surfaceRaised),
      text: c(text, other.text),
      textMuted: c(textMuted, other.textMuted),
      icon: c(icon, other.icon),
      border: c(border, other.border),
      line: c(line, other.line),
      highlight: c(highlight, other.highlight),
      onHighlight: c(onHighlight, other.onHighlight),
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      danger: c(danger, other.danger),
      focus: c(focus, other.focus),
      scrim: c(scrim, other.scrim),
      keyBackground: c(keyBackground, other.keyBackground),
      keyForeground: c(keyForeground, other.keyForeground),
      keyBorder: c(keyBorder, other.keyBorder),
      keyShadow: c(keyShadow, other.keyShadow),
      lineWidth: d(lineWidth, other.lineWidth),
      radiusSm: d(radiusSm, other.radiusSm),
      radiusMd: d(radiusMd, other.radiusMd),
      radiusLg: d(radiusLg, other.radiusLg),
      spaceXs: d(spaceXs, other.spaceXs),
      spaceSm: d(spaceSm, other.spaceSm),
      spaceMd: d(spaceMd, other.spaceMd),
      spaceLg: d(spaceLg, other.spaceLg),
      spaceXl: d(spaceXl, other.spaceXl),
      keyMinSize: d(keyMinSize, other.keyMinSize),
      keyDepth: d(keyDepth, other.keyDepth),
      keyPaddingX: d(keyPaddingX, other.keyPaddingX),
      keyLabelStyle: TextStyle.lerp(keyLabelStyle, other.keyLabelStyle, t),
      controlMinHeight: d(controlMinHeight, other.controlMinHeight),
      motionFast: t < 0.5 ? motionFast : other.motionFast,
      motionNormal: t < 0.5 ? motionNormal : other.motionNormal,
    );
  }
}
