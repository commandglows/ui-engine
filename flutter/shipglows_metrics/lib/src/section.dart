import 'package:flutter/material.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

/// A titled group of a dashboard: [title] (a heading for screen readers),
/// an optional [trailing] control on its right (a `MetricPeriodSelector`),
/// then [child] (a `MetricGrid`). Under 480 wide, [trailing] moves under
/// the title.
class MetricSection extends StatelessWidget {
  const MetricSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
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
    final trailing = this.trailing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (trailing == null)
          heading
        else
          LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 480
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      heading,
                      SizedBox(height: theme.spaceSm),
                      trailing,
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: heading),
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
