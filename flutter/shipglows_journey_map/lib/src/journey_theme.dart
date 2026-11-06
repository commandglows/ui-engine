import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'journey_model.dart';

/// WCAG contrast ratio between two opaque colours, from 1 to 21.
double journeyContrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Visual tokens of a journey map.
///
/// Resolution order, last wins: the ambient [ColorScheme], the
/// [JourneyMapTheme] extension registered on the app [ThemeData], then the
/// `theme` given to the widget. Every null falls back, so an app only states
/// what its brand needs; light and dark come from the [ColorScheme].
@immutable
class JourneyMapTheme extends ThemeExtension<JourneyMapTheme> {
  /// Creates a theme; every value is optional.
  const JourneyMapTheme({
    this.pathColor,
    this.progressColor,
    this.doneColor,
    this.currentColor,
    this.neutralColor,
    this.upcomingColor,
    this.ringColor,
    this.onNodeColor,
    this.labelColor,
    this.pathWidth,
    this.nodeRadius,
    this.maxContentWidth,
  });

  /// Colour of the path between nodes not yet walked (opaque).
  final Color? pathColor;

  /// Colour of the path after a done node.
  final Color? progressColor;

  /// Fill of done nodes.
  final Color? doneColor;

  /// Fill of the current node.
  final Color? currentColor;

  /// Fill of neutral nodes.
  final Color? neutralColor;

  /// Fill of upcoming nodes.
  final Color? upcomingColor;

  /// Ring of the current or selected node.
  final Color? ringColor;

  /// Text and icon colour inside every node; derived from the fill when null.
  final Color? onNodeColor;

  /// Colour of labels and chapter titles.
  final Color? labelColor;

  /// Stroke width of the path.
  final double? pathWidth;

  /// Radius of a node.
  final double? nodeRadius;

  /// Widest the map grows on large screens; it is centred beyond that.
  final double? maxContentWidth;

  /// Ambient theme: the registered extension, or an empty one.
  static JourneyMapTheme of(BuildContext context) =>
      Theme.of(context).extension<JourneyMapTheme>() ?? const JourneyMapTheme();

  /// This theme with every non-null value of [other] on top.
  JourneyMapTheme merge(JourneyMapTheme? other) => other == null
      ? this
      : JourneyMapTheme(
          pathColor: other.pathColor ?? pathColor,
          progressColor: other.progressColor ?? progressColor,
          doneColor: other.doneColor ?? doneColor,
          currentColor: other.currentColor ?? currentColor,
          neutralColor: other.neutralColor ?? neutralColor,
          upcomingColor: other.upcomingColor ?? upcomingColor,
          ringColor: other.ringColor ?? ringColor,
          onNodeColor: other.onNodeColor ?? onNodeColor,
          labelColor: other.labelColor ?? labelColor,
          pathWidth: other.pathWidth ?? pathWidth,
          nodeRadius: other.nodeRadius ?? nodeRadius,
          maxContentWidth: other.maxContentWidth ?? maxContentWidth,
        );

  @override
  JourneyMapTheme copyWith({
    Color? pathColor,
    Color? progressColor,
    Color? doneColor,
    Color? currentColor,
    Color? neutralColor,
    Color? upcomingColor,
    Color? ringColor,
    Color? onNodeColor,
    Color? labelColor,
    double? pathWidth,
    double? nodeRadius,
    double? maxContentWidth,
  }) => merge(
    JourneyMapTheme(
      pathColor: pathColor,
      progressColor: progressColor,
      doneColor: doneColor,
      currentColor: currentColor,
      neutralColor: neutralColor,
      upcomingColor: upcomingColor,
      ringColor: ringColor,
      onNodeColor: onNodeColor,
      labelColor: labelColor,
      pathWidth: pathWidth,
      nodeRadius: nodeRadius,
      maxContentWidth: maxContentWidth,
    ),
  );

  @override
  JourneyMapTheme lerp(JourneyMapTheme? other, double t) {
    if (other == null) return this;
    return JourneyMapTheme(
      pathColor: Color.lerp(pathColor, other.pathColor, t),
      progressColor: Color.lerp(progressColor, other.progressColor, t),
      doneColor: Color.lerp(doneColor, other.doneColor, t),
      currentColor: Color.lerp(currentColor, other.currentColor, t),
      neutralColor: Color.lerp(neutralColor, other.neutralColor, t),
      upcomingColor: Color.lerp(upcomingColor, other.upcomingColor, t),
      ringColor: Color.lerp(ringColor, other.ringColor, t),
      onNodeColor: Color.lerp(onNodeColor, other.onNodeColor, t),
      labelColor: Color.lerp(labelColor, other.labelColor, t),
      pathWidth: _lerpDouble(pathWidth, other.pathWidth, t),
      nodeRadius: _lerpDouble(nodeRadius, other.nodeRadius, t),
      maxContentWidth: _lerpDouble(maxContentWidth, other.maxContentWidth, t),
    );
  }

  static double? _lerpDouble(double? a, double? b, double t) =>
      a == null || b == null ? (t < 0.5 ? a : b) : a + (b - a) * t;
}

/// Fill, content colour and border of one node state.
@immutable
class JourneyNodePaint {
  /// Creates a resolved node paint.
  const JourneyNodePaint({
    required this.fill,
    required this.onFill,
    required this.border,
  });

  /// Disc colour.
  final Color fill;

  /// Text and icon colour on [fill]; at least 4.5:1 for scheme defaults.
  final Color onFill;

  /// Outline colour.
  final Color border;
}

/// A [JourneyMapTheme] with every value filled from a [ColorScheme].
@immutable
class JourneyPalette {
  const JourneyPalette._({
    required this.path,
    required this.progress,
    required this.ring,
    required this.label,
    required this.surface,
    required this.pathWidth,
    required this.nodeRadius,
    required this.maxContentWidth,
    required Map<JourneyNodeState, JourneyNodePaint> nodes,
  }) : _nodes = nodes;

  /// Resolves [theme] over [scheme] defaults.
  factory JourneyPalette.resolve(ColorScheme scheme, JourneyMapTheme theme) {
    Color onFor(Color fill, Color schemeOn, {required bool custom}) =>
        theme.onNodeColor ?? (custom ? _bestOn(fill) : schemeOn);
    final done = theme.doneColor ?? scheme.primary;
    final current = theme.currentColor ?? scheme.primary;
    final neutral = theme.neutralColor ?? scheme.secondary;
    final upcoming = theme.upcomingColor ?? scheme.surface;
    final border = scheme.surface;
    return JourneyPalette._(
      path:
          theme.pathColor ??
          Color.alphaBlend(
            scheme.outlineVariant.withValues(alpha: 0.7),
            scheme.surface,
          ),
      progress:
          theme.progressColor ??
          Color.alphaBlend(
            (theme.doneColor ?? scheme.primary).withValues(alpha: 0.7),
            scheme.surface,
          ),
      ring: theme.ringColor ?? scheme.tertiary,
      label: theme.labelColor ?? scheme.onSurface,
      surface: scheme.surface,
      pathWidth: theme.pathWidth ?? 14,
      nodeRadius: theme.nodeRadius ?? 28,
      maxContentWidth: theme.maxContentWidth ?? 560,
      nodes: {
        JourneyNodeState.done: JourneyNodePaint(
          fill: done,
          onFill: onFor(
            done,
            scheme.onPrimary,
            custom: theme.doneColor != null,
          ),
          border: border,
        ),
        JourneyNodeState.current: JourneyNodePaint(
          fill: current,
          onFill: onFor(
            current,
            scheme.onPrimary,
            custom: theme.currentColor != null,
          ),
          border: border,
        ),
        JourneyNodeState.neutral: JourneyNodePaint(
          fill: neutral,
          onFill: onFor(
            neutral,
            scheme.onSecondary,
            custom: theme.neutralColor != null,
          ),
          border: border,
        ),
        JourneyNodeState.upcoming: JourneyNodePaint(
          fill: upcoming,
          onFill:
              theme.onNodeColor ??
              (theme.upcomingColor != null
                  ? _bestOn(upcoming)
                  : scheme.onSurface),
          border: scheme.outline,
        ),
      },
    );
  }

  /// Path colour before progress.
  final Color path;

  /// Path colour after a done node.
  final Color progress;

  /// Ring colour of current and selected nodes.
  final Color ring;

  /// Label and title colour.
  final Color label;

  /// Page surface, used to separate badges from nodes.
  final Color surface;

  /// Stroke width of the path.
  final double pathWidth;

  /// Radius of a node.
  final double nodeRadius;

  /// Widest content before the map centres itself.
  final double maxContentWidth;

  final Map<JourneyNodeState, JourneyNodePaint> _nodes;

  /// Paint of [state].
  JourneyNodePaint paintFor(JourneyNodeState state) => _nodes[state]!;

  static Color _bestOn(Color fill) {
    const light = Color(0xFFFFFFFF);
    const dark = Color(0xDD000000);
    final opaqueDark = Color.alphaBlend(dark, fill);
    return journeyContrastRatio(fill, light) >=
            journeyContrastRatio(fill, opaqueDark)
        ? light
        : dark;
  }
}
