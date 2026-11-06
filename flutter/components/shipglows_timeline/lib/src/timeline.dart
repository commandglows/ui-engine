import 'package:flutter/material.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

/// Width kept for the rail and the entry's icon.
const double _railWidth = 40;

/// Size of the disc holding the icon.
const double _discSize = 28;

/// One row of the timeline.
@immutable
class TimelineEntry {
  /// Creates an entry.
  const TimelineEntry({
    required this.id,
    required this.title,
    this.subtitle,
    this.icon,
    this.tags = const [],
    this.semanticLabel,
    this.onTap,
  });

  /// Stable id, unique across the timeline.
  final String id;

  /// Main line.
  final String title;

  /// Text under [title], shown in full.
  final String? subtitle;

  /// Icon in the rail; a plain disc without one. Decorative.
  final IconData? icon;

  /// Short words shown under the texts.
  final List<String> tags;

  /// Replaces what screen readers say; by default, the texts as one sentence.
  final String? semanticLabel;

  /// Called when the row is tapped; the row is not tappable without it.
  final VoidCallback? onTap;
}

/// A heading and its entries, in the order given.
@immutable
class TimelineGroup {
  /// Creates a group.
  const TimelineGroup({
    required this.id,
    required this.title,
    required this.entries,
  });

  /// Stable id, unique across the timeline.
  final String id;

  /// Heading text.
  final String title;

  /// Rows of the group.
  final List<TimelineEntry> entries;
}

/// The timeline as a sliver, for your own [CustomScrollView]. Rows are built
/// lazily.
class SliverTimeline extends StatelessWidget {
  /// Creates the sliver. Groups without entries are skipped.
  const SliverTimeline({super.key, required this.groups});

  /// Groups to show, in order.
  final List<TimelineGroup> groups;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget Function()>[];
    for (final group in groups) {
      if (group.entries.isEmpty) continue;
      rows.add(
        () => _GroupHeading(key: ValueKey(group.id), title: group.title),
      );
      for (var i = 0; i < group.entries.length; i++) {
        final entry = group.entries[i];
        final last = i == group.entries.length - 1;
        rows.add(
          () => _EntryRow(key: ValueKey(entry.id), entry: entry, last: last),
        );
      }
    }
    return SliverList.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) => rows[index](),
    );
  }
}

/// A ready scroll view around [SliverTimeline].
class TimelineView extends StatelessWidget {
  /// Creates the view.
  const TimelineView({
    super.key,
    required this.groups,
    this.header,
    this.empty,
    this.padding = const EdgeInsets.all(16),
  });

  /// Groups to show, in order.
  final List<TimelineGroup> groups;

  /// Scrolls with the timeline, above it.
  final Widget? header;

  /// Shown when no group has an entry.
  final Widget? empty;

  /// Padding around the content.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final headerWidget = header;
    final emptyWidget = empty;
    final isEmpty = groups.every((group) => group.entries.isEmpty);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: padding,
          sliver: SliverMainAxisGroup(
            slivers: [
              if (headerWidget != null) SliverToBoxAdapter(child: headerWidget),
              if (isEmpty && emptyWidget != null)
                SliverToBoxAdapter(child: emptyWidget)
              else
                SliverTimeline(groups: groups),
            ],
          ),
        ),
      ],
    );
  }
}

class _GroupHeading extends StatelessWidget {
  const _GroupHeading({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(top: theme.spaceLg, bottom: theme.spaceMd),
      child: Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({super.key, required this.entry, required this.last});

  final TimelineEntry entry;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final subtitle = entry.subtitle;
    final label = entry.semanticLabel;
    final onTap = entry.onTap;

    Widget row = CustomPaint(
      painter: _RailPainter(
        color: theme.line,
        width: theme.lineWidth,
        direction: Directionality.of(context),
        last: last,
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : theme.spaceLg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _railWidth,
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: _Disc(icon: entry.icon),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.title, style: textTheme.titleSmall),
                  if (subtitle != null)
                    Padding(
                      padding: EdgeInsets.only(top: theme.spaceXs),
                      child: Text(subtitle),
                    ),
                  if (entry.tags.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: theme.spaceSm),
                      child: Wrap(
                        spacing: theme.spaceXs,
                        runSpacing: theme.spaceXs,
                        children: [for (final tag in entry.tags) _Tag(tag)],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      row = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(theme.radiusMd),
        child: row,
      );
    }
    if (label == null) return MergeSemantics(child: row);
    return Semantics(
      container: true,
      label: label,
      button: onTap != null,
      onTap: onTap,
      excludeSemantics: true,
      child: row,
    );
  }
}

class _Disc extends StatelessWidget {
  const _Disc({required this.icon});

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final iconData = icon;
    return Container(
      width: _discSize,
      height: _discSize,
      decoration: BoxDecoration(
        color: theme.surfaceRaised,
        shape: BoxShape.circle,
        border: Border.all(color: theme.border, width: theme.lineWidth),
      ),
      child: iconData == null
          ? null
          : Icon(iconData, size: ShipglowsScale.iconSm, color: theme.icon),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.border, width: theme.lineWidth),
        borderRadius: BorderRadius.circular(theme.radiusSm),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spaceSm,
          vertical: theme.spaceXs / 2,
        ),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: theme.textMuted),
        ),
      ),
    );
  }
}

/// Draws the vertical line below the disc, behind the row's content.
class _RailPainter extends CustomPainter {
  const _RailPainter({
    required this.color,
    required this.width,
    required this.direction,
    required this.last,
  });

  final Color color;
  final double width;
  final TextDirection direction;
  final bool last;

  @override
  void paint(Canvas canvas, Size size) {
    if (last) return;
    final x = direction == TextDirection.ltr
        ? _discSize / 2
        : size.width - _discSize / 2;
    canvas.drawLine(
      Offset(x, _discSize),
      Offset(x, size.height),
      Paint()
        ..color = color
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      old.color != color ||
      old.width != width ||
      old.direction != direction ||
      old.last != last;
}
