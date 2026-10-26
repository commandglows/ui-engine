import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

/// [children] in as many equal columns as the width allows, each at least
/// [minTileWidth] wide and at most [maxColumns]; the tiles of a row share
/// the height of the tallest one. One column on a phone.
class MetricGrid extends StatelessWidget {
  const MetricGrid({
    super.key,
    required this.children,
    this.minTileWidth = 220,
    this.maxColumns = 4,
    this.spacing,
  });

  final List<Widget> children;
  final double minTileWidth;
  final int maxColumns;

  /// Gap between tiles; defaults to [ShipglowsTheme.spaceMd].
  final double? spacing;

  @override
  Widget build(BuildContext context) {
    final gap = spacing ?? ShipglowsTheme.of(context).spaceMd;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Unbounded (inside a horizontal scroll): as many columns as allowed.
        final fit = constraints.hasBoundedWidth
            ? ((constraints.maxWidth + gap) / (minTileWidth + gap)).floor()
            : maxColumns;
        final columns = math.max(1, math.min(fit, maxColumns));
        final rows = <Widget>[];
        for (var start = 0; start < children.length; start += columns) {
          final row = children.skip(start).take(columns).toList();
          if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < columns; i++) ...[
                    if (i > 0) SizedBox(width: gap),
                    Expanded(
                      child: i < row.length ? row[i] : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: rows,
        );
      },
    );
  }
}
