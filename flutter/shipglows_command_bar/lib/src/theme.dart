import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Builds one keycap, for an app that draws its own.
typedef CommandBarKeycapBuilder =
    Widget Function(BuildContext context, String label);

/// Look of the command bar, set once in the app theme:
/// `ThemeData(extensions: [CommandBarThemeData(...)])`.
///
/// Every value is optional; a missing one comes from the [ColorScheme].
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
    this.radius,
    this.rowRadius,
    this.rowMinHeight,
    this.maxWidth,
    this.maxHeight,
    this.keycapBuilder,
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
    double? radius,
    double? rowRadius,
    double? rowMinHeight,
    double? maxWidth,
    double? maxHeight,
    CommandBarKeycapBuilder? keycapBuilder,
  }) => CommandBarThemeData(
    backgroundColor: backgroundColor ?? this.backgroundColor,
    barrierColor: barrierColor ?? this.barrierColor,
    highlightColor: highlightColor ?? this.highlightColor,
    borderColor: borderColor ?? this.borderColor,
    textColor: textColor ?? this.textColor,
    mutedColor: mutedColor ?? this.mutedColor,
    iconColor: iconColor ?? this.iconColor,
    highlightedIconColor: highlightedIconColor ?? this.highlightedIconColor,
    radius: radius ?? this.radius,
    rowRadius: rowRadius ?? this.rowRadius,
    rowMinHeight: rowMinHeight ?? this.rowMinHeight,
    maxWidth: maxWidth ?? this.maxWidth,
    maxHeight: maxHeight ?? this.maxHeight,
    keycapBuilder: keycapBuilder ?? this.keycapBuilder,
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
      radius: lerpDouble(radius, other.radius, t),
      rowRadius: lerpDouble(rowRadius, other.rowRadius, t),
      rowMinHeight: lerpDouble(rowMinHeight, other.rowMinHeight, t),
      maxWidth: lerpDouble(maxWidth, other.maxWidth, t),
      maxHeight: lerpDouble(maxHeight, other.maxHeight, t),
      keycapBuilder: t < 0.5 ? keycapBuilder : other.keycapBuilder,
    );
  }

  /// The theme of [context] with every missing value filled from its
  /// [ColorScheme].
  static ResolvedCommandBarTheme of(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final data =
        theme.extension<CommandBarThemeData>() ?? const CommandBarThemeData();
    return ResolvedCommandBarTheme(
      backgroundColor: data.backgroundColor ?? scheme.surfaceContainerHigh,
      barrierColor:
          data.barrierColor ?? scheme.scrim.withValues(alpha: 0.32),
      highlightColor: data.highlightColor ?? scheme.secondaryContainer,
      borderColor: data.borderColor ?? scheme.outlineVariant,
      textColor: data.textColor ?? scheme.onSurface,
      mutedColor: data.mutedColor ?? scheme.onSurfaceVariant,
      iconColor: data.iconColor ?? scheme.onSurfaceVariant,
      highlightedIconColor:
          data.highlightedIconColor ?? scheme.onSecondaryContainer,
      radius: data.radius ?? 16,
      rowRadius: data.rowRadius ?? 10,
      rowMinHeight: data.rowMinHeight ?? 44,
      maxWidth: data.maxWidth ?? 640,
      maxHeight: data.maxHeight ?? 520,
      keycapBuilder:
          data.keycapBuilder ??
          (context, label) => CommandBarKeycap(label: label),
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
    required this.radius,
    required this.rowRadius,
    required this.rowMinHeight,
    required this.maxWidth,
    required this.maxHeight,
    required this.keycapBuilder,
  });

  final Color backgroundColor;
  final Color barrierColor;
  final Color highlightColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;
  final Color iconColor;
  final Color highlightedIconColor;
  final double radius;
  final double rowRadius;
  final double rowMinHeight;
  final double maxWidth;
  final double maxHeight;
  final CommandBarKeycapBuilder keycapBuilder;
}

/// Default keycap: the label in a small outlined box.
class CommandBarKeycap extends StatelessWidget {
  const CommandBarKeycap({super.key, required this.label});

  /// Text of the key, such as `Ctrl` or `K`.
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(6),
        // A rounded border must keep one color, so the key's depth is a hard
        // shadow under it.
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [BoxShadow(color: scheme.outline, offset: const Offset(0, 1))],
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Keycaps of [keys], side by side.
class CommandBarKeys extends StatelessWidget {
  const CommandBarKeys({super.key, required this.keys});

  /// Labels of the keys, in order.
  final List<String> keys;

  @override
  Widget build(BuildContext context) {
    final builder = CommandBarThemeData.of(context).keycapBuilder;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          builder(context, keys[i]),
        ],
      ],
    );
  }
}

/// Label of the primary shortcut modifier: `⌘` on Apple platforms, `Ctrl`
/// elsewhere. On the web it follows the visitor's system.
String commandBarPrimaryModifierLabel() => switch (defaultTargetPlatform) {
  TargetPlatform.macOS || TargetPlatform.iOS => '⌘',
  _ => 'Ctrl',
};
