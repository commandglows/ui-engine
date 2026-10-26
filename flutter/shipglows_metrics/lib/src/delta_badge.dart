import 'package:flutter/material.dart';
import 'package:shipglows_icons/shipglows_icons.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'metric.dart';
import 'strings.dart';

/// A change in a pill: its arrow and signed text, in the success color when
/// good, the danger color when bad, muted when neither. Read as « up 12 % ».
class MetricDeltaBadge extends StatelessWidget {
  const MetricDeltaBadge(this.delta, {super.key, this.strings});

  final MetricDelta delta;

  /// Defaults to [MetricStrings.of] the context.
  final MetricStrings? strings;

  /// The color of [delta] in [theme].
  static Color colorOf(MetricDelta delta, ShipglowsTheme theme) =>
      switch (delta.isFavorable) {
        true => theme.success,
        false => theme.danger,
        null => theme.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final texts = strings ?? MetricStrings.of(context);
    final color = colorOf(delta, theme);
    final text = texts.formatDelta(delta);
    final direction = delta.direction;
    final iconName = switch (direction) {
      MetricDirection.up => 'trendUp',
      MetricDirection.down => 'trendDown',
      MetricDirection.flat => 'trendFlat',
    };
    final spoken = direction == MetricDirection.flat
        ? texts.flat
        : '${texts.labelOf(direction)} $text';
    return Semantics(
      label: spoken,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(theme.radiusSm),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spaceSm,
            vertical: theme.spaceXs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(ShipglowsIcons.of(context, iconName), size: 14, color: color),
              SizedBox(width: theme.spaceXs),
              Text(
                text,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
