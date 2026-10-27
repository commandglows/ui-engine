import 'package:flutter/material.dart';
import 'package:shipglows_icons/shipglows_icons.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'delta_badge.dart';
import 'metric.dart';
import 'sparkline.dart';
import 'strings.dart';

enum _TileState { ready, loading, empty, error }

/// How much room a [MetricTile] takes. [regular] suits a dashboard's main
/// figures; [compact] fits a dense grid of smaller ones, with a shorter value
/// line, a smaller value, no caption and a shorter sparkline.
enum MetricTileDensity { regular, compact }

/// One metric on a raised card: an optional [icon] before its label, its
/// value, its change badge, a caption and its sparkline. Read as one sentence:
/// « Revenue, 1 240 €, up 12 %, vs. last week ».
///
/// [MetricTile.loading], [MetricTile.empty] and [MetricTile.error] keep the
/// label and the same height, so a dashboard does not jump when its data
/// arrives. Each [MetricTileDensity] keeps that promise on its own.
class MetricTile extends StatelessWidget {
  const MetricTile(
    Metric this.metric, {
    super.key,
    this.icon,
    this.iconColor,
    this.onTap,
    this.strings,
    this.density = MetricTileDensity.regular,
  }) : _state = _TileState.ready,
       label = null,
       message = null,
       onRetry = null;

  const MetricTile.loading({
    super.key,
    required String this.label,
    this.icon,
    this.iconColor,
    this.strings,
    this.density = MetricTileDensity.regular,
  }) : _state = _TileState.loading,
       metric = null,
       message = null,
       onTap = null,
       onRetry = null;

  /// No value yet; [message] defaults to [MetricStrings.noData].
  const MetricTile.empty({
    super.key,
    required String this.label,
    this.message,
    this.icon,
    this.iconColor,
    this.strings,
    this.density = MetricTileDensity.regular,
  }) : _state = _TileState.empty,
       metric = null,
       onTap = null,
       onRetry = null;

  /// Loading failed: [message], and « Retry » when [onRetry] is set.
  const MetricTile.error({
    super.key,
    required String this.label,
    required String this.message,
    this.onRetry,
    this.icon,
    this.iconColor,
    this.strings,
    this.density = MetricTileDensity.regular,
  }) : _state = _TileState.error,
       metric = null,
       onTap = null;

  final _TileState _state;
  final Metric? metric;
  final String? label;
  final String? message;

  /// Before the label, decorative: the label says what is measured.
  final IconData? icon;

  /// Defaults to [ShipglowsTheme.icon]; an app may keep one color per
  /// metric, the value itself stays in [ShipglowsTheme.text].
  final Color? iconColor;

  /// Opens the metric's details; the whole tile is the button.
  final VoidCallback? onTap;

  final VoidCallback? onRetry;

  /// Defaults to [MetricStrings.of] the context.
  final MetricStrings? strings;

  /// How much room the tile takes. The value line keeps the height of its
  /// density in every state.
  final MetricTileDensity density;

  /// Height of the value line, kept by every state of the same density.
  double get _valueHeight => switch (density) {
    MetricTileDensity.regular => 36.0,
    MetricTileDensity.compact => 28.0,
  };

  /// Height of the sparkline under the value.
  double get _sparklineHeight => switch (density) {
    MetricTileDensity.regular => 32.0,
    MetricTileDensity.compact => 20.0,
  };

  /// Space inside the card.
  double _padding(ShipglowsTheme theme) => switch (density) {
    MetricTileDensity.regular => theme.spaceLg,
    MetricTileDensity.compact => theme.spaceMd,
  };

  /// Style of the value: the display headline, or a title size when compact.
  TextStyle? _valueStyle(TextTheme textTheme) => switch (density) {
    MetricTileDensity.regular => textTheme.headlineSmall,
    MetricTileDensity.compact => textTheme.titleLarge,
  };

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final texts = strings ?? MetricStrings.of(context);
    final textTheme = Theme.of(context).textTheme;
    final metric = this.metric;
    final title = metric?.label ?? label!;

    final body = switch (_state) {
      _TileState.ready => _ready(context, metric!, theme, textTheme),
      _TileState.loading => _loading(theme),
      _TileState.empty => _empty(message ?? texts.noData, theme, textTheme),
      _TileState.error => _error(texts, theme, textTheme),
    };

    final content = Padding(
      padding: EdgeInsets.all(_padding(theme)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                ExcludeSemantics(
                  child: Icon(icon, size: 18, color: iconColor ?? theme.icon),
                ),
                SizedBox(width: theme.spaceSm),
              ],
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  style: textTheme.labelLarge?.copyWith(color: theme.textMuted),
                ),
              ),
            ],
          ),
          SizedBox(height: theme.spaceSm),
          body,
        ],
      ),
    );

    final radius = BorderRadius.circular(theme.radiusLg);
    final card = Material(
      color: theme.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: theme.border, width: theme.lineWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );

    return switch (_state) {
      _TileState.ready => Semantics(
        container: true,
        button: onTap != null,
        label: _spoken(metric!, texts),
        excludeSemantics: true,
        child: card,
      ),
      _TileState.loading => Semantics(
        container: true,
        label: '$title, ${texts.loading}',
        excludeSemantics: true,
        child: card,
      ),
      _TileState.empty ||
      _TileState.error => Semantics(container: true, child: card),
    };
  }

  String _spoken(Metric metric, MetricStrings texts) {
    final delta = metric.delta;
    return [
      metric.label,
      metric.value,
      if (delta != null)
        delta.direction == MetricDirection.flat
            ? texts.flat
            : '${texts.labelOf(delta.direction)} ${texts.formatDelta(delta)}',
      ?metric.caption,
    ].join(', ');
  }

  Widget _ready(
    BuildContext context,
    Metric metric,
    ShipglowsTheme theme,
    TextTheme textTheme,
  ) {
    final delta = metric.delta;
    final caption = metric.caption;
    // The line takes the badge's color when the change is good or bad.
    final trendColor = delta == null || delta.isFavorable == null
        ? null
        : MetricDeltaBadge.colorOf(delta, theme);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _valueHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  metric.value,
                  maxLines: 1,
                  softWrap: false,
                  style: _valueStyle(textTheme)?.copyWith(
                    color: theme.text,
                    fontFamily: theme.fontDisplay,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (delta != null) ...[
                SizedBox(width: theme.spaceSm),
                MetricDeltaBadge(delta, strings: strings),
              ],
            ],
          ),
        ),
        // A compact tile leaves the caption to its spoken label.
        if (caption != null && density == MetricTileDensity.regular) ...[
          SizedBox(height: theme.spaceXs),
          Text(
            caption,
            style: textTheme.bodySmall?.copyWith(color: theme.textMuted),
          ),
        ],
        if (metric.points.isNotEmpty) ...[
          SizedBox(height: theme.spaceMd),
          MetricSparkline.points(
            metric.points,
            color: trendColor,
            height: _sparklineHeight,
          ),
        ] else if (metric.series.length >= 2) ...[
          SizedBox(height: theme.spaceMd),
          MetricSparkline(
            metric.series,
            color: trendColor,
            height: _sparklineHeight,
          ),
        ],
      ],
    );
  }

  Widget _loading(ShipglowsTheme theme) {
    Widget bar(double widthFactor, double height) => FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: theme.border,
          borderRadius: BorderRadius.circular(theme.radiusSm),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _valueHeight,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: bar(0.5, 24),
          ),
        ),
        SizedBox(height: theme.spaceXs),
        bar(0.35, 12),
      ],
    );
  }

  Widget _empty(String message, ShipglowsTheme theme, TextTheme textTheme) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: _valueHeight,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ExcludeSemantics(
                child: Text(
                  '—',
                  style: _valueStyle(textTheme)?.copyWith(
                    color: theme.textMuted,
                    fontFamily: theme.fontDisplay,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: theme.spaceXs),
          Text(
            message,
            style: textTheme.bodySmall?.copyWith(color: theme.textMuted),
          ),
        ],
      );

  Widget _error(
    MetricStrings texts,
    ShipglowsTheme theme,
    TextTheme textTheme,
  ) {
    final onRetry = this.onRetry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  ShipglowsIcons.error,
                  size: 20,
                  color: theme.danger,
                ),
              ),
              SizedBox(width: theme.spaceSm),
              Expanded(
                child: Text(
                  message!,
                  style: textTheme.bodyMedium?.copyWith(color: theme.text),
                ),
              ),
            ],
          ),
        ),
        if (onRetry != null) ...[
          SizedBox(height: theme.spaceSm),
          TextButton(onPressed: onRetry, child: Text(texts.retry)),
        ],
      ],
    );
  }
}
