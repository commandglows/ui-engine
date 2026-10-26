import 'package:flutter/material.dart';
import 'package:shipglows_icons/shipglows_icons.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'delta_badge.dart';
import 'metric.dart';
import 'sparkline.dart';
import 'strings.dart';

enum _TileState { ready, loading, empty, error }

/// One metric on a raised card: its label, its value, its change badge, a
/// caption and its sparkline. Read as one sentence: « Revenue, 1 240 €, up
/// 12 %, vs. last week ».
///
/// [MetricTile.loading], [MetricTile.empty] and [MetricTile.error] keep the
/// label and the same height, so a dashboard does not jump when its data
/// arrives.
class MetricTile extends StatelessWidget {
  const MetricTile(Metric this.metric, {super.key, this.onTap, this.strings})
    : _state = _TileState.ready,
      label = null,
      message = null,
      onRetry = null;

  const MetricTile.loading({super.key, required String this.label, this.strings})
    : _state = _TileState.loading,
      metric = null,
      message = null,
      onTap = null,
      onRetry = null;

  /// No value yet; [message] defaults to [MetricStrings.noData].
  const MetricTile.empty({
    super.key,
    required String this.label,
    this.message,
    this.strings,
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
    this.strings,
  }) : _state = _TileState.error,
       metric = null,
       onTap = null;

  final _TileState _state;
  final Metric? metric;
  final String? label;
  final String? message;

  /// Opens the metric's details; the whole tile is the button.
  final VoidCallback? onTap;

  final VoidCallback? onRetry;

  /// Defaults to [MetricStrings.of] the context.
  final MetricStrings? strings;

  /// Height of the value line, kept by every state.
  static const _valueHeight = 36.0;

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
      padding: EdgeInsets.all(theme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 2,
            style: textTheme.labelLarge?.copyWith(color: theme.textMuted),
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
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, child: content),
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
      _TileState.empty || _TileState.error => Semantics(
        container: true,
        child: card,
      ),
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
                  style: textTheme.headlineSmall?.copyWith(
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
        if (caption != null) ...[
          SizedBox(height: theme.spaceXs),
          Text(
            caption,
            style: textTheme.bodySmall?.copyWith(color: theme.textMuted),
          ),
        ],
        if (metric.series.length >= 2) ...[
          SizedBox(height: theme.spaceMd),
          MetricSparkline(metric.series, color: trendColor),
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
          color: theme.line,
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
                  style: textTheme.headlineSmall?.copyWith(
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
                child: Icon(ShipglowsIcons.error, size: 20, color: theme.danger),
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
