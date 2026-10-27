import 'package:flutter/material.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'freshness.dart';

/// A titled group of a dashboard: [title] (a heading for screen readers),
/// an optional [subtitle] muted under it, an optional [freshness] line under
/// that (a [MetricFreshnessLine]), then an optional [trailing] control on its
/// right (a `MetricPeriodSelector`), then [child] (a `MetricGrid`). Under 480
/// wide, [trailing] moves under the title block.
class MetricSection extends StatelessWidget {
  const MetricSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.freshness,
    this.trailing,
  });

  /// The heading of the section, announced as a header.
  final String title;

  /// A muted line under [title], such as « Last 28 days ».
  final String? subtitle;

  /// How current the section's data is, shown under [subtitle].
  final MetricFreshness? freshness;

  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final heading = Semantics(
      header: true,
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(color: theme.text),
      ),
    );
    final subtitle = this.subtitle;
    final freshness = this.freshness;
    // Without a subtitle or freshness, the title block is the heading alone.
    final header = subtitle == null && freshness == null
        ? heading
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              heading,
              if (subtitle != null) ...[
                SizedBox(height: theme.spaceXs),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: theme.textMuted),
                ),
              ],
              if (freshness != null) ...[
                SizedBox(height: theme.spaceXs),
                MetricFreshnessLine(freshness: freshness),
              ],
            ],
          );
    final trailing = this.trailing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (trailing == null)
          header
        else
          LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 480
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      header,
                      SizedBox(height: theme.spaceSm),
                      trailing,
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: header),
                      SizedBox(width: theme.spaceMd),
                      trailing,
                    ],
                  ),
          ),
        SizedBox(height: theme.spaceMd),
        child,
      ],
    );
  }
}
