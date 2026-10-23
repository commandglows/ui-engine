import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

/// Builds one keycap, for an app that draws its own.
typedef CommandBarKeycapBuilder =
    Widget Function(BuildContext context, String label);

/// Look of the command bar, set once in the app theme:
/// `ThemeData(extensions: [CommandBarThemeData(...)])`.
///
/// Every value is optional; a missing one comes from the app's shared
/// [ShipglowsTheme] (its [ColorScheme] when it declares none).
@immutable
class CommandBarThemeData extends ThemeExtension<CommandBarThemeData> {
  const CommandBarThemeData({
    this.backgroundColor,
    this.barrierColor,
    this.highlightColor,
    this.borderColor,
    this.textColor,
    this.mutedColor,
    this.iconColor,
    this.highlightedIconColor,
    this.highlightIndicatorColor,
    this.radius,
    this.rowRadius,
    this.rowMinHeight,
    this.maxWidth,
    this.maxHeight,
    this.keycapBuilder,
    this.quietKeycapBuilder,
    this.activeFilterKeycapBuilder,
  });

  /// Dialog surface.
  final Color? backgroundColor;

  /// Scrim behind the dialog.
  final Color? barrierColor;

  /// Background of the highlighted row.
  final Color? highlightColor;

  /// Dividers and the dialog outline.
  final Color? borderColor;

  /// Labels.
  final Color? textColor;

  /// Section titles, second lines, hints and the footer.
  final Color? mutedColor;

  /// Row icons.
  final Color? iconColor;

  /// Icon of the highlighted row.
  final Color? highlightedIconColor;

  /// Bar drawn along the leading edge of the highlighted row, so the
  /// highlight does not rest on its fill alone. No bar when null.
  final Color? highlightIndicatorColor;

  /// Corner radius of the dialog.
  final double? radius;

  /// Corner radius of a row.
  final double? rowRadius;

  /// Minimum height of a row, at least the touch target.
  final double? rowMinHeight;

  /// Maximum width of the dialog.
  final double? maxWidth;

  /// Maximum height of the dialog.
  final double? maxHeight;

  /// Draws one keycap; [CommandBarKeycap] when null.
  final CommandBarKeycapBuilder? keycapBuilder;

  /// Draws the keys that are not in focus: those of the rows other than the
  /// highlighted one and of the inactive filters. When null they are drawn
  /// by [keycapBuilder], faded.
  final CommandBarKeycapBuilder? quietKeycapBuilder;

  /// Draws the key of the active filter, so it can stand out from the
  /// others (filled, for instance). When null it is drawn by
  /// [keycapBuilder].
  final CommandBarKeycapBuilder? activeFilterKeycapBuilder;

  @override
  CommandBarThemeData copyWith({
    Color? backgroundColor,
    Color? barrierColor,
    Color? highlightColor,
    Color? borderColor,
    Color? textColor,
    Color? mutedColor,
    Color? iconColor,
    Color? highlightedIconColor,
    Color? highlightIndicatorColor,
    double? radius,
    double? rowRadius,
    double? rowMinHeight,
    double? maxWidth,
    double? maxHeight,
    CommandBarKeycapBuilder? keycapBuilder,
    CommandBarKeycapBuilder? quietKeycapBuilder,
    CommandBarKeycapBuilder? activeFilterKeycapBuilder,
  }) => CommandBarThemeData(
    backgroundColor: backgroundColor ?? this.backgroundColor,
    barrierColor: barrierColor ?? this.barrierColor,
    highlightColor: highlightColor ?? this.highlightColor,
    borderColor: borderColor ?? this.borderColor,
    textColor: textColor ?? this.textColor,
    mutedColor: mutedColor ?? this.mutedColor,
    iconColor: iconColor ?? this.iconColor,
    highlightedIconColor: highlightedIconColor ?? this.highlightedIconColor,
    highlightIndicatorColor:
        highlightIndicatorColor ?? this.highlightIndicatorColor,
    radius: radius ?? this.radius,
    rowRadius: rowRadius ?? this.rowRadius,
    rowMinHeight: rowMinHeight ?? this.rowMinHeight,
    maxWidth: maxWidth ?? this.maxWidth,
    maxHeight: maxHeight ?? this.maxHeight,
    keycapBuilder: keycapBuilder ?? this.keycapBuilder,
    quietKeycapBuilder: quietKeycapBuilder ?? this.quietKeycapBuilder,
    activeFilterKeycapBuilder:
        activeFilterKeycapBuilder ?? this.activeFilterKeycapBuilder,
  );

  @override
  CommandBarThemeData lerp(CommandBarThemeData? other, double t) {
    if (other == null) return this;
    return CommandBarThemeData(
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t),
      barrierColor: Color.lerp(barrierColor, other.barrierColor, t),
      highlightColor: Color.lerp(highlightColor, other.highlightColor, t),
      borderColor: Color.lerp(borderColor, other.borderColor, t),
      textColor: Color.lerp(textColor, other.textColor, t),
      mutedColor: Color.lerp(mutedColor, other.mutedColor, t),
      iconColor: Color.lerp(iconColor, other.iconColor, t),
      highlightedIconColor: Color.lerp(
        highlightedIconColor,
        other.highlightedIconColor,
        t,
      ),
      highlightIndicatorColor: Color.lerp(
        highlightIndicatorColor,
        other.highlightIndicatorColor,
        t,
      ),
      radius: lerpDouble(radius, other.radius, t),
      rowRadius: lerpDouble(rowRadius, other.rowRadius, t),
      rowMinHeight: lerpDouble(rowMinHeight, other.rowMinHeight, t),
      maxWidth: lerpDouble(maxWidth, other.maxWidth, t),
      maxHeight: lerpDouble(maxHeight, other.maxHeight, t),
      keycapBuilder: t < 0.5 ? keycapBuilder : other.keycapBuilder,
      quietKeycapBuilder: t < 0.5
          ? quietKeycapBuilder
          : other.quietKeycapBuilder,
      activeFilterKeycapBuilder: t < 0.5
          ? activeFilterKeycapBuilder
          : other.activeFilterKeycapBuilder,
    );
  }

  /// The theme of [context] with every missing value filled from its
  /// [ShipglowsTheme].
  static ResolvedCommandBarTheme of(BuildContext context) {
    final theme = Theme.of(context);
    final roles = ShipglowsTheme.of(context);
    final data =
        theme.extension<CommandBarThemeData>() ?? const CommandBarThemeData();
    return ResolvedCommandBarTheme(
      backgroundColor: data.backgroundColor ?? roles.surfaceRaised,
      barrierColor: data.barrierColor ?? roles.scrim,
      highlightColor: data.highlightColor ?? roles.highlight,
      borderColor: data.borderColor ?? roles.border,
      textColor: data.textColor ?? roles.text,
      mutedColor: data.mutedColor ?? roles.textMuted,
      iconColor: data.iconColor ?? roles.icon,
      highlightedIconColor: data.highlightedIconColor ?? roles.onHighlight,
      highlightIndicatorColor: data.highlightIndicatorColor,
      radius: data.radius ?? roles.radiusLg,
      rowRadius: data.rowRadius ?? roles.radiusMd,
      rowMinHeight: data.rowMinHeight ?? roles.controlMinHeight,
      maxWidth: data.maxWidth ?? 640,
      maxHeight: data.maxHeight ?? 520,
      keycapBuilder:
          data.keycapBuilder ??
          (context, label) => CommandBarKeycap(label: label),
      quietKeycapBuilder: data.quietKeycapBuilder,
      activeFilterKeycapBuilder: data.activeFilterKeycapBuilder,
    );
  }
}

/// [CommandBarThemeData] with every value filled.
@immutable
class ResolvedCommandBarTheme {
  const ResolvedCommandBarTheme({
    required this.backgroundColor,
    required this.barrierColor,
    required this.highlightColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
    required this.iconColor,
    required this.highlightedIconColor,
    required this.highlightIndicatorColor,
    required this.radius,
    required this.rowRadius,
    required this.rowMinHeight,
    required this.maxWidth,
    required this.maxHeight,
    required this.keycapBuilder,
    required this.quietKeycapBuilder,
    required this.activeFilterKeycapBuilder,
  });

  final Color backgroundColor;
  final Color barrierColor;
  final Color highlightColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;
  final Color iconColor;
  final Color highlightedIconColor;
  final Color? highlightIndicatorColor;
  final double radius;
  final double rowRadius;
  final double rowMinHeight;
  final double maxWidth;
  final double maxHeight;
  final CommandBarKeycapBuilder keycapBuilder;
  final CommandBarKeycapBuilder? quietKeycapBuilder;
  final CommandBarKeycapBuilder? activeFilterKeycapBuilder;
}

/// Default keycap: the shared [ShipglowsKeycap], so the bar's keys look
/// like every other key of the app.
class CommandBarKeycap extends StatelessWidget {
  const CommandBarKeycap({super.key, required this.label});

  /// Text of the key, such as `Ctrl` or `K`.
  final String label;

  @override
  Widget build(BuildContext context) => ShipglowsKeycap(label);
}

/// Keycaps of [keys], side by side.
class CommandBarKeys extends StatelessWidget {
  const CommandBarKeys({
    super.key,
    required this.keys,
    this.quiet = false,
    this.fadedOpacity = 1,
  });

  /// Labels of the keys, in order.
  final List<String> keys;

  /// Keys out of focus: drawn by the theme's quiet builder when it has one,
  /// otherwise by the usual one at [fadedOpacity].
  final bool quiet;

  /// Opacity of [quiet] keys when the theme has no quiet builder.
  final double fadedOpacity;

  @override
  Widget build(BuildContext context) {
    final style = CommandBarThemeData.of(context);
    final quietBuilder = quiet ? style.quietKeycapBuilder : null;
    final builder = quietBuilder ?? style.keycapBuilder;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          builder(context, keys[i]),
        ],
      ],
    );
    return quiet && quietBuilder == null && fadedOpacity < 1
        ? Opacity(opacity: fadedOpacity, child: row)
        : row;
  }
}

/// Label of the primary shortcut modifier: `⌘` on Apple platforms, `Ctrl`
/// elsewhere. On the web it follows the visitor's system.
String commandBarPrimaryModifierLabel() => switch (defaultTargetPlatform) {
  TargetPlatform.macOS || TargetPlatform.iOS => '⌘',
  _ => 'Ctrl',
};
