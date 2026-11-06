import 'package:flutter/material.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'journey_geometry.dart';
import 'journey_labels.dart';
import 'journey_model.dart';
import 'journey_rows.dart';
import 'journey_theme.dart';

/// What a custom node builder receives besides the node itself.
@immutable
class JourneyNodeSlot {
  /// Creates a slot description.
  const JourneyNodeSlot({
    required this.selected,
    required this.radius,
    required this.palette,
    required this.labels,
    required this.position,
    required this.total,
    this.onTap,
  });

  /// Whether the node is the selected one.
  final bool selected;

  /// Radius the default node would use.
  final double radius;

  /// Resolved colours.
  final JourneyPalette palette;

  /// Resolved labels, for semantics.
  final JourneyMapLabels labels;

  /// 1-based position of the node in its chapter.
  final int position;

  /// Number of nodes in the chapter.
  final int total;

  /// Selection callback; null when the map is read-only.
  final VoidCallback? onTap;
}

/// Replaces the default node cell (disc and labels). The builder owns the
/// semantics and the tap target: use [JourneyNodeSlot.onTap] and keep targets
/// at least 44 logical pixels.
typedef JourneyNodeBuilder =
    Widget Function(
      BuildContext context,
      JourneyNode node,
      JourneyNodeSlot slot,
    );

/// Everything a row needs, resolved once per build from the ambient theme.
class JourneyRowScope {
  /// Creates a scope.
  const JourneyRowScope({
    required this.palette,
    required this.metrics,
    required this.labels,
    required this.textDirection,
    required this.animate,
    this.selectedId,
    this.onSelect,
    this.nodeBuilder,
  });

  /// Resolves the scope from [context].
  factory JourneyRowScope.resolve(
    BuildContext context, {
    JourneyMapTheme? theme,
    JourneyMapLabels? labels,
    String? selectedId,
    ValueChanged<String>? onSelect,
    JourneyNodeBuilder? nodeBuilder,
    bool animateCurrent = true,
  }) {
    final palette = JourneyPalette.resolve(
      Theme.of(context).colorScheme,
      JourneyMapTheme.of(context).merge(theme),
    );
    final scaler = MediaQuery.textScalerOf(context);
    return JourneyRowScope(
      palette: palette,
      metrics: JourneyMetrics.from(
        nodeRadius: palette.nodeRadius,
        scaleOf: scaler.scale,
      ),
      labels:
          labels ?? JourneyMapLabels.forLocale(Localizations.localeOf(context)),
      textDirection: Directionality.of(context),
      animate: animateCurrent && !MediaQuery.disableAnimationsOf(context),
      selectedId: selectedId,
      onSelect: onSelect,
      nodeBuilder: nodeBuilder,
    );
  }

  /// Resolved colours.
  final JourneyPalette palette;

  /// Text-scale aware sizes.
  final JourneyMetrics metrics;

  /// Strings.
  final JourneyMapLabels labels;

  /// Reading direction; the path mirrors in RTL.
  final TextDirection textDirection;

  /// Whether the current node may pulse.
  final bool animate;

  /// Selected node id.
  final String? selectedId;

  /// Selection callback.
  final ValueChanged<String>? onSelect;

  /// Optional node override.
  final JourneyNodeBuilder? nodeBuilder;
}

/// One row of the map: chapter header, empty notice or node with its path.
class JourneyRowView extends StatelessWidget {
  /// Creates a row view.
  const JourneyRowView({required this.row, required this.scope, super.key});

  /// The row to draw.
  final JourneyRow row;

  /// Resolved context.
  final JourneyRowScope scope;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: scope.palette.maxContentWidth),
        child: switch (row.kind) {
          JourneyRowKind.header => _Header(row: row, scope: scope),
          JourneyRowKind.emptyChapter => _EmptyChapter(scope: scope),
          JourneyRowKind.node => _NodeRow(row: row, scope: scope),
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.row, required this.scope});

  final JourneyRow row;
  final JourneyRowScope scope;

  @override
  Widget build(BuildContext context) {
    final chapter = row.chapter;
    final theme = Theme.of(context);
    final color = scope.palette.label;
    final title = chapter.title.isEmpty ? scope.labels.untitled : chapter.title;
    return Semantics(
      header: true,
      excludeSemantics: true,
      label: JourneyMapLabels.fill(scope.labels.chapter, {
        'title': title,
        'count': chapter.nodes.length,
      }),
      child: Row(
        children: [
          if (chapter.icon != null) ...[
            Icon(chapter.icon, color: color),
            const SizedBox(width: ShipglowsScale.spaceMd),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (chapter.trailing != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: ShipglowsScale.spaceMd,
              ),
              child: Text(
                chapter.trailing!,
                style: theme.textTheme.titleSmall?.copyWith(color: color),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyChapter extends StatelessWidget {
  const _EmptyChapter({required this.scope});

  final JourneyRowScope scope;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        scope.labels.emptyChapter,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: scope.palette.label),
      ),
    );
  }
}

class _NodeRow extends StatelessWidget {
  const _NodeRow({required this.row, required this.scope});

  final JourneyRow row;
  final JourneyRowScope scope;

  @override
  Widget build(BuildContext context) {
    final node = row.node!;
    final metrics = scope.metrics;
    final palette = scope.palette;
    final rtl = scope.textDirection == TextDirection.rtl;
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        double xAt(int index) => JourneyGeometry.centerX(
          index,
          width,
          nodeRadius: metrics.nodeRadius,
          rtl: rtl,
        );
        final x = xAt(row.nodeIndex);
        final cell = width < metrics.cellWidth ? width : metrics.cellWidth;
        final left = (x - cell / 2).clamp(0.0, width - cell);
        final selected = node.id == scope.selectedId;
        final slot = JourneyNodeSlot(
          selected: selected,
          radius: metrics.nodeRadius,
          palette: palette,
          labels: scope.labels,
          position: row.nodeIndex + 1,
          total: row.chapter.nodes.length,
          onTap: scope.onSelect == null ? null : () => scope.onSelect!(node.id),
        );
        return CustomPaint(
          painter: _SegmentPainter(
            x: x,
            previousX: row.previous == null ? null : xAt(row.nodeIndex - 1),
            nextX: row.next == null ? null : xAt(row.nodeIndex + 1),
            centerY: metrics.centerY,
            rowExtent: metrics.rowExtent,
            width: palette.pathWidth,
            upColor: row.previous?.state == JourneyNodeState.done
                ? palette.progress
                : palette.path,
            downColor: node.state == JourneyNodeState.done
                ? palette.progress
                : palette.path,
          ),
          child: Stack(
            children: [
              Positioned(
                left: left,
                top: metrics.centerY - metrics.nodeRadius,
                width: cell,
                child:
                    scope.nodeBuilder?.call(context, node, slot) ??
                    JourneyNodeCell(
                      key: ValueKey('journey-node-${node.id}'),
                      node: node,
                      slot: slot,
                      animate: scope.animate,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SegmentPainter extends CustomPainter {
  const _SegmentPainter({
    required this.x,
    required this.previousX,
    required this.nextX,
    required this.centerY,
    required this.rowExtent,
    required this.width,
    required this.upColor,
    required this.downColor,
  });

  final double x;
  final double? previousX;
  final double? nextX;
  final double centerY;
  final double rowExtent;
  final double width;
  final Color upColor;
  final Color downColor;

  Paint _stroke(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    // Each row only paints inside itself; the next row continues the same
    // curve shifted by one row extent, so rows can be built independently.
    canvas
      ..save()
      ..clipRect(Rect.fromLTWH(0, -0.5, size.width, size.height + 1));
    if (previousX != null) {
      canvas.drawPath(
        JourneyGeometry.segment(
          Offset(previousX!, centerY - rowExtent),
          Offset(x, centerY),
        ),
        _stroke(upColor),
      );
    }
    if (nextX != null) {
      canvas.drawPath(
        JourneyGeometry.segment(
          Offset(x, centerY),
          Offset(nextX!, centerY + rowExtent),
        ),
        _stroke(downColor),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SegmentPainter old) =>
      old.x != x ||
      old.previousX != previousX ||
      old.nextX != nextX ||
      old.centerY != centerY ||
      old.rowExtent != rowExtent ||
      old.width != width ||
      old.upColor != upColor ||
      old.downColor != downColor;
}

/// The default node: disc, mark, label and caption, as one tap target.
class JourneyNodeCell extends StatelessWidget {
  /// Creates the default node cell.
  const JourneyNodeCell({
    required this.node,
    required this.slot,
    required this.animate,
    super.key,
  });

  /// The node.
  final JourneyNode node;

  /// Selection, colours and labels.
  final JourneyNodeSlot slot;

  /// Whether the current node pulses.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final palette = slot.palette;
    final paint = palette.paintFor(node.state);
    final radius = slot.radius;
    final isCurrent = node.state == JourneyNodeState.current;
    final ring = isCurrent || slot.selected;
    final label = node.label.isEmpty ? slot.labels.untitled : node.label;
    final stateName = slot.labels.stateName(node.state);
    final spoken =
        node.semanticLabel ??
        [
          label,
          if (node.caption != null && node.caption!.isNotEmpty) node.caption!,
          if (stateName.isNotEmpty) stateName,
          JourneyMapLabels.fill(slot.labels.position, {
            'index': slot.position,
            'total': slot.total,
          }),
        ].join(', ');

    // A mark inside a fixed disc follows the text scale only up to 1.3x; the
    // label and caption under it scale freely and the semantics carry it all.
    final Widget inner = node.marker != null
        ? Text(
            node.marker!,
            maxLines: 1,
            textScaler: MediaQuery.textScalerOf(
              context,
            ).clamp(maxScaleFactor: 1.3),
            style: textTheme.titleMedium?.copyWith(
              color: paint.onFill,
              fontWeight: FontWeight.w800,
            ),
          )
        : Icon(
            node.icon ?? Icons.circle,
            color: paint.onFill,
            size: radius * 0.8,
          );

    final disc = SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (isCurrent && animate)
            Positioned.fill(child: _Halo(color: palette.ring)),
          Container(
            width: radius * 2,
            height: radius * 2,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: paint.fill,
              border: Border.all(
                color: ring ? palette.ring : paint.border,
                width: ring ? 4 : 2,
              ),
            ),
            child: inner,
          ),
          if (node.progress != null)
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: node.progress,
                strokeWidth: 3,
                color: paint.onFill,
                backgroundColor: Colors.transparent,
              ),
            ),
          if (node.state == JourneyNodeState.done)
            Positioned(
              right: -2,
              bottom: -2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.surface,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: radius * 0.7,
                  color: paint.fill,
                ),
              ),
            ),
        ],
      ),
    );

    return Semantics(
      container: true,
      button: slot.onTap != null,
      selected: slot.selected,
      label: spoken,
      excludeSemantics: true,
      onTap: slot.onTap,
      child: InkWell(
        onTap: slot.onTap,
        borderRadius: BorderRadius.circular(ShipglowsScale.radiusMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            disc,
            const SizedBox(height: ShipglowsScale.spaceXs),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelLarge?.copyWith(
                color: palette.label,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (node.caption != null)
              Text(
                node.caption!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(color: palette.label),
              ),
          ],
        ),
      ),
    );
  }
}

/// Soft pulse around the current node; only built when animations are on.
class _Halo extends StatefulWidget {
  const _Halo({required this.color});

  final Color color;

  @override
  State<_Halo> createState() => _HaloState();
}

class _HaloState extends State<_Halo> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Transform.scale(
            scale: 1 + 0.22 * _controller.value,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(
                  alpha: 0.28 * (1 - _controller.value),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
