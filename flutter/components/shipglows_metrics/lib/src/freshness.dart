import 'package:flutter/material.dart';
import 'package:shipglows_icons/shipglows_icons.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'strings.dart';

/// How current the data of a metric is: when it was [updatedAt], whether it
/// is [stale] (not refreshed on time), whether it is [partial] (the last
/// days are still arriving) and which [source] produced it, such as
/// « Google Search Console ».
@immutable
class MetricFreshness {
  const MetricFreshness({
    this.updatedAt,
    this.stale = false,
    this.partial = false,
    this.source,
  });

  /// When the data was last refreshed; no « Updated » text without it.
  final DateTime? updatedAt;

  /// Whether the data was not refreshed on time: shows the stale badge.
  final bool stale;

  /// Whether the data is known to be incomplete: shows the partial badge.
  final bool partial;

  /// Where the data comes from, written first on the line.
  final String? source;

  @override
  bool operator ==(Object other) =>
      other is MetricFreshness &&
      other.updatedAt == updatedAt &&
      other.stale == stale &&
      other.partial == partial &&
      other.source == source;

  @override
  int get hashCode => Object.hash(updatedAt, stale, partial, source);
}

/// One muted line about how current a metric is: its [MetricFreshness.source],
/// when it was updated (« Updated 2 h ago », in its largest unit only), then
/// a badge for stale and one for partial data. Each badge carries its word,
/// so the meaning never rests on color alone. Renders nothing when there is
/// nothing to say.
class MetricFreshnessLine extends StatelessWidget {
  const MetricFreshnessLine({
    super.key,
    required this.freshness,
    this.now,
    this.strings,
  });

  /// What to say about the data.
  final MetricFreshness freshness;

  /// The moment the age of [MetricFreshness.updatedAt] is measured at.
  /// Defaults to [DateTime.now]; set it in tests.
  final DateTime? now;

  /// Defaults to [MetricStrings.of] the context.
  final MetricStrings? strings;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final texts = strings ?? MetricStrings.of(context);
    final textTheme = Theme.of(context).textTheme;
    final updatedAt = freshness.updatedAt;
    final source = freshness.source;
    final current = now ?? DateTime.now();

    final parts = <String>[
      if (source != null && source.isNotEmpty) source,
      if (updatedAt != null) _updatedText(updatedAt, current, texts),
    ];
    if (parts.isEmpty && !freshness.stale && !freshness.partial) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: theme.spaceSm,
      runSpacing: theme.spaceXs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (parts.isNotEmpty)
          Text(
            parts.join(' · '),
            style: textTheme.bodySmall?.copyWith(color: theme.textMuted),
          ),
        if (freshness.stale)
          _badge(
            theme: theme,
            textTheme: textTheme,
            icon: ShipglowsIcons.of(context, 'history'),
            accent: theme.warning,
            label: texts.stale,
          ),
        if (freshness.partial)
          _badge(
            theme: theme,
            textTheme: textTheme,
            icon: ShipglowsIcons.of(context, 'warning'),
            accent: theme.textMuted,
            label: texts.partial,
          ),
      ],
    );
  }

  /// « Updated 2 h ago », with the largest unit only; under a minute it is
  /// « Updated just now ». A moment in the future counts as just now.
  String _updatedText(DateTime updatedAt, DateTime now, MetricStrings texts) {
    final age = now.difference(updatedAt);
    if (age < const Duration(minutes: 1)) return texts.updatedJustNow;
    if (age.inDays >= 1) {
      return texts.updatedAgo.replaceFirst(
        '{time}',
        '${age.inDays} ${texts.dayShort}',
      );
    }
    if (age.inHours >= 1) {
      return texts.updatedAgo.replaceFirst(
        '{time}',
        '${age.inHours} ${texts.hourShort}',
      );
    }
    return texts.updatedAgo.replaceFirst(
      '{time}',
      '${age.inMinutes} ${texts.minuteShort}',
    );
  }

  /// A small pill: a decorative [icon] in [accent] tinting the pill, then
  /// [label] in the text color.
  Widget _badge({
    required ShipglowsTheme theme,
    required TextTheme textTheme,
    required IconData? icon,
    required Color accent,
    required String label,
  }) => DecoratedBox(
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.12),
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
          ExcludeSemantics(child: Icon(icon, size: 14, color: accent)),
          SizedBox(width: theme.spaceXs),
          Text(label, style: textTheme.labelSmall?.copyWith(color: theme.text)),
        ],
      ),
    ),
  );
}
