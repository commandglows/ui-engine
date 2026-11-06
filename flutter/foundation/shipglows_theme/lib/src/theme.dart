import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'scale.dart';
import 'typography.dart';

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
    this.success = const Color(0xFF2E8B57),
    this.warning = const Color(0xFFB87A00),
    required this.focus,
    required this.scrim,
    required this.keyBackground,
    required this.keyForeground,
    required this.keyBorder,
    required this.keyShadow,
    this.lineWidth = 1,
    this.radiusSm = ShipglowsScale.radiusSm,
    this.radiusMd = ShipglowsScale.radiusMd,
    this.radiusLg = ShipglowsScale.radiusLg,
    this.spaceXs = ShipglowsScale.spaceXs,
    this.spaceSm = ShipglowsScale.spaceSm,
    this.spaceMd = ShipglowsScale.spaceMd,
    this.spaceLg = ShipglowsScale.spaceLg,
    this.spaceXl = ShipglowsScale.spaceXl,
    this.keyMinSize = 22,
    this.keyDepth = 1,
    this.keyPaddingX = 6,
    this.keyPaddingY = 2,
    this.keyLabelStyle,
    this.controlMinHeight = 44,
    this.motionFast = ShipglowsScale.motionFast,
    this.motionNormal = ShipglowsScale.motionNormal,
    this.fontSans = ShipglowsFonts.sans,
    this.fontDisplay = ShipglowsFonts.display,
    this.fontMono = ShipglowsFonts.mono,
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
    success: scheme.brightness == Brightness.dark
        ? const Color(0xFF6FCF97)
        : const Color(0xFF1E7B45),
    warning: scheme.brightness == Brightness.dark
        ? const Color(0xFFF2C14E)
        : const Color(0xFF9A6200),
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

  /// [theme] dressed with these roles: the font roles on its text themes,
  /// the shared scrollbars, and this extension added (or replaced). One call
  /// in the app theme gives every ShipGlows app the same type and scrollbars.
  ThemeData applyTo(ThemeData theme) => theme.copyWith(
    textTheme: textTheme(theme.textTheme),
    primaryTextTheme: textTheme(theme.primaryTextTheme),
    scrollbarTheme: shipglowsScrollbarTheme(this),
    extensions: [
      ...theme.extensions.values.where((e) => e is! ShipglowsTheme),
      this,
    ],
  );

  /// [base] with [fontSans] and, on display and headline styles,
  /// [fontDisplay].
  TextTheme textTheme(TextTheme base) =>
      ShipglowsFonts.textTheme(base, sans: fontSans, display: fontDisplay);

  /// [base] (or the text theme's `bodyMedium`) in [fontMono], for code,
  /// paths and logs.
  TextStyle monoStyle(BuildContext context, [TextStyle? base]) =>
      (base ?? Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
          .copyWith(
            fontFamily: fontMono,
            fontFamilyFallback: ShipglowsFonts.monoFallback,
          );

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

  /// Done, saved, synced. Used for marks and icons beside [text], never as
  /// a text color: at least 3:1 against [surfaceRaised]. The default is a
  /// mid tone readable on light and dark surfaces; set the brand's own.
  final Color success;

  /// Needs attention but nothing failed. Same contrast rule as [success].
  final Color warning;

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

  /// Space above and below a keycap's label.
  final double keyPaddingY;

  /// Keycap label, over the bold `labelSmall` of the text theme. Its color
  /// is ignored: the label always takes [keyForeground].
  final TextStyle? keyLabelStyle;

  /// Minimum height of a control, at least the touch target.
  final double controlMinHeight;

  /// Quick feedback: hover, press.
  final Duration motionFast;

  /// Regular transitions: open, close, move.
  final Duration motionNormal;

  /// Interface text. Defaults to the bundled Inter ([ShipglowsFonts.sans]).
  final String fontSans;

  /// Titles and big numbers. Defaults to the bundled Cal Sans
  /// ([ShipglowsFonts.display]).
  final String fontDisplay;

  /// Code, paths, logs. Defaults to the bundled JetBrains Mono
  /// ([ShipglowsFonts.mono]), with system monospace faces behind it.
  final String fontMono;

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
    Color? success,
    Color? warning,
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
    double? keyPaddingY,
    TextStyle? keyLabelStyle,
    double? controlMinHeight,
    Duration? motionFast,
    Duration? motionNormal,
    String? fontSans,
    String? fontDisplay,
    String? fontMono,
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
    success: success ?? this.success,
    warning: warning ?? this.warning,
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
    keyPaddingY: keyPaddingY ?? this.keyPaddingY,
    keyLabelStyle: keyLabelStyle ?? this.keyLabelStyle,
    controlMinHeight: controlMinHeight ?? this.controlMinHeight,
    motionFast: motionFast ?? this.motionFast,
    motionNormal: motionNormal ?? this.motionNormal,
    fontSans: fontSans ?? this.fontSans,
    fontDisplay: fontDisplay ?? this.fontDisplay,
    fontMono: fontMono ?? this.fontMono,
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
      success: c(success, other.success),
      warning: c(warning, other.warning),
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
      keyPaddingY: d(keyPaddingY, other.keyPaddingY),
      keyLabelStyle: TextStyle.lerp(keyLabelStyle, other.keyLabelStyle, t),
      controlMinHeight: d(controlMinHeight, other.controlMinHeight),
      motionFast: t < 0.5 ? motionFast : other.motionFast,
      motionNormal: t < 0.5 ? motionNormal : other.motionNormal,
      fontSans: t < 0.5 ? fontSans : other.fontSans,
      fontDisplay: t < 0.5 ? fontDisplay : other.fontDisplay,
      fontMono: t < 0.5 ? fontMono : other.fontMono,
    );
  }
}
