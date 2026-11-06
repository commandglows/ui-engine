import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'journey_layout.dart';
import 'journey_model.dart';

/// Colours of a [JourneyMap]; every null falls back to the ambient
/// [ColorScheme], so an app only overrides what its brand needs.
@immutable
class JourneyMapStyle {
  const JourneyMapStyle({
    this.pathColor,
    this.doneColor,
    this.currentColor,
    this.neutralColor,
    this.upcomingColor,
    this.ringColor,
    this.onNodeColor,
    this.labelColor,
    this.pathWidth = 14,
    this.nodeRadius = 28,
  });

  final Color? pathColor;
  final Color? doneColor;
  final Color? currentColor;
  final Color? neutralColor;
  final Color? upcomingColor;

  /// Ring of the current or selected node.
  final Color? ringColor;

  /// Text/icon colour inside filled nodes.
  final Color? onNodeColor;

  /// Colour of node captions and chapter titles.
  final Color? labelColor;

  final double pathWidth;
  final double nodeRadius;
}

/// Chapters of nodes drawn along winding paths. Non-scrolling: place it in a
/// scrollable of your choice.
class JourneyMap extends StatelessWidget {
  const JourneyMap({
    super.key,
    required this.chapters,
    this.onSelect,
    this.selectedId,
    this.style = const JourneyMapStyle(),
    this.stateLabels = const JourneyStateLabels(),
    this.emptyChapterLabel = 'Rien ici pour le moment.',
  });

  final List<JourneyChapter> chapters;

  /// Called with the node id; nodes are inert when null.
  final ValueChanged<String>? onSelect;
  final String? selectedId;
  final JourneyMapStyle style;
  final JourneyStateLabels stateLabels;
  final String emptyChapterLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final chapter in chapters)
          _ChapterView(
            key: ValueKey('journey-chapter-${chapter.id}'),
            chapter: chapter,
            onSelect: onSelect,
            selectedId: selectedId,
            style: style,
            emptyLabel: emptyChapterLabel,
            stateLabels: stateLabels,
          ),
      ],
    );
  }
}

class _ChapterView extends StatelessWidget {
  const _ChapterView({
    super.key,
    required this.chapter,
    required this.onSelect,
    required this.selectedId,
    required this.style,
    required this.stateLabels,
    required this.emptyLabel,
  });

  final JourneyChapter chapter;
  final ValueChanged<String>? onSelect;
  final String? selectedId;
  final JourneyMapStyle style;
  final JourneyStateLabels stateLabels;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelColor = style.labelColor ?? theme.colorScheme.onSurface;
    final scale = math
        .max(1.0, MediaQuery.textScalerOf(context).scale(16) / 16)
        .clamp(1.0, 2.0)
        .toDouble();
    final radius = style.nodeRadius;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ShipglowsScale.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Row(
              children: [
                if (chapter.icon != null) ...[
                  Icon(chapter.icon, color: labelColor),
                  const SizedBox(width: ShipglowsScale.spaceMd),
                ],
                Expanded(
                  child: Text(
                    chapter.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: labelColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (chapter.trailing != null)
                  Text(
                    chapter.trailing!,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: labelColor,
                    ),
                  ),
              ],
            ),
          ),
          if (chapter.nodes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(ShipglowsScale.spaceLg),
              child: Text(emptyLabel, style: TextStyle(color: labelColor)),
            )
          else
            LayoutBuilder(
              builder: (context, box) {
                final layout = JourneyLayout.winding(
                  count: chapter.nodes.length,
                  width: box.maxWidth,
                  nodeRadius: radius,
                  rowHeight: (radius * 2 + 62) * scale,
                );
                final cell = math.min(box.maxWidth, 136.0 + 24 * (scale - 1));
                return SizedBox(
                  height: layout.height,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: ExcludeSemantics(
                          child: CustomPaint(
                            painter: _PathPainter(
                              layout.path,
                              style.pathColor ??
                                  theme.colorScheme.outlineVariant,
                              style.pathWidth,
                            ),
                          ),
                        ),
                      ),
                      for (var i = 0; i < chapter.nodes.length; i++)
                        Positioned(
                          left: (layout.centers[i].dx - cell / 2).clamp(
                            0.0,
                            math.max(0.0, box.maxWidth - cell),
                          ),
                          top: layout.centers[i].dy - radius,
                          width: cell,
                          child: _NodeView(
                            node: chapter.nodes[i],
                            selected: chapter.nodes[i].id == selectedId,
                            onSelect: onSelect,
                            style: style,
                            stateLabels: stateLabels,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _PathPainter extends CustomPainter {
  const _PathPainter(this.path, this.color, this.width);

  final Path path;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_PathPainter old) =>
      old.color != color || old.width != width || old.path != path;
}

class _NodeView extends StatelessWidget {
  const _NodeView({
    required this.node,
    required this.selected,
    required this.onSelect,
    required this.style,
    required this.stateLabels,
  });

  final JourneyNode node;
  final bool selected;
  final ValueChanged<String>? onSelect;
  final JourneyMapStyle style;
  final JourneyStateLabels stateLabels;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final radius = style.nodeRadius;
    final labelColor = style.labelColor ?? scheme.onSurface;
    final fill = switch (node.state) {
      JourneyNodeState.done => style.doneColor ?? scheme.primary,
      JourneyNodeState.current => style.currentColor ?? scheme.primary,
      JourneyNodeState.neutral => style.neutralColor ?? scheme.secondary,
      JourneyNodeState.upcoming => style.upcomingColor ?? scheme.surface,
    };
    final filled = node.state != JourneyNodeState.upcoming;
    final onFill = filled
        ? (style.onNodeColor ??
              (ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
                  ? Colors.white
                  : Colors.black87))
        : scheme.onSurface;
    final ring = node.state == JourneyNodeState.current || selected;
    final stateText = stateLabels.of(node.state);
    final spoken =
        node.semanticLabel ??
        [
          node.label,
          if (node.caption != null) node.caption!,
          if (stateText.isNotEmpty) stateText,
        ].join(', ');

    final Widget inner = node.marker != null
        ? Text(
            node.marker!,
            style: textTheme.titleMedium?.copyWith(
              color: onFill,
              fontWeight: FontWeight.w800,
            ),
          )
        : Icon(node.icon ?? Icons.circle, color: onFill, size: radius * 0.8);

    final circle = SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: Border.all(
                color: ring
                    ? (style.ringColor ?? scheme.tertiary)
                    : (filled ? Colors.white70 : scheme.outline),
                width: ring ? 4 : 2,
              ),
            ),
            alignment: Alignment.center,
            child: inner,
          ),
          if (node.progress != null)
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: node.progress,
                strokeWidth: 3,
                color: onFill,
                backgroundColor: Colors.transparent,
              ),
            ),
          if (node.state == JourneyNodeState.done)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surface,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: radius * 0.7,
                  color: style.doneColor ?? scheme.primary,
                ),
              ),
            ),
        ],
      ),
    );

    return Semantics(
      container: true,
      button: onSelect != null,
      selected: selected,
      label: spoken,
      excludeSemantics: true,
      onTap: onSelect == null ? null : () => onSelect!(node.id),
      child: InkWell(
        onTap: onSelect == null ? null : () => onSelect!(node.id),
        borderRadius: BorderRadius.circular(ShipglowsScale.radiusMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            circle,
            const SizedBox(height: ShipglowsScale.spaceXs),
            Text(
              node.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelLarge?.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (node.caption != null)
              Text(
                node.caption!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(color: labelColor),
              ),
          ],
        ),
      ),
    );
  }
}
