import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'metric.dart';

/// A small line through recent values, with a faint area under it and the
/// lowest value at the bottom. Draws nothing under two values. Decorative: the
/// tile says the value and its change, so the line is kept out of semantics.
///
/// [MetricSparkline] spaces undated values evenly, oldest on the left.
/// [MetricSparkline.points] spaces dated points by their date, breaks the line
/// at a gap, and shows the nearest point's value on hover or touch.
class MetricSparkline extends StatefulWidget {
  /// A line through [values], oldest first, spaced evenly.
  const MetricSparkline(
    this.values, {
    super.key,
    this.color,
    this.height = 32,
    this.fill = true,
  }) : points = const [],
       describe = null;

  /// A line through [points], oldest first, each placed by its date. A point
  /// without a value is a gap: the line stops there and nothing is tinted
  /// under it. Hovering or touching shows the nearest point, with [describe]
  /// as its text; by default the value, without decimals when whole and with
  /// one decimal otherwise.
  const MetricSparkline.points(
    this.points, {
    super.key,
    this.color,
    this.height = 32,
    this.fill = true,
    this.describe,
  }) : values = const [];

  /// The values of [MetricSparkline]; empty for [MetricSparkline.points].
  final List<double> values;

  /// The dated points of [MetricSparkline.points]; empty otherwise.
  final List<MetricPoint> points;

  /// The tooltip text of a point; null for the default.
  final String Function(MetricPoint point)? describe;

  /// Defaults to [ShipglowsTheme.accent].
  final Color? color;

  /// Height of the line.
  final double height;

  /// Whether the area under the line is tinted.
  final bool fill;

  @override
  State<MetricSparkline> createState() => _MetricSparklineState();
}

class _MetricSparklineState extends State<MetricSparkline> {
  /// Index of the point under the pointer or the finger, or null.
  int? _hovered;

  /// Shows the point nearest to [x], given where each point is drawn in
  /// [dots].
  void _hoverAt(double x, List<Offset?> dots) {
    final index = _nearest(dots, x);
    if (index != _hovered) setState(() => _hovered = index);
  }

  void _clear() {
    if (_hovered != null) setState(() => _hovered = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final color = widget.color ?? theme.accent;
    final strokeWidth = theme.lineWidth * 1.5;
    final child = widget.points.isEmpty
        ? _valuesLine(color, strokeWidth)
        : _pointsLine(color, strokeWidth);
    return ExcludeSemantics(child: child);
  }

  Widget _valuesLine(Color color, double strokeWidth) {
    final values = widget.values;
    if (values.length < 2) return SizedBox(height: widget.height);
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(
          values: values,
          color: color,
          strokeWidth: strokeWidth,
          fill: widget.fill,
        ),
      ),
    );
  }

  // No LayoutBuilder: a MetricGrid measures its rows with IntrinsicHeight,
  // which a LayoutBuilder cannot answer. The width is read from the render
  // box when the pointer moves, and the tooltip layout places itself.
  Widget _pointsLine(Color color, double strokeWidth) {
    final points = widget.points;
    if (_countKnown(points) < 2) return SizedBox(height: widget.height);
    final theme = ShipglowsTheme.of(context);
    final hovered = _hovered;
    final index = hovered != null && hovered < points.length ? hovered : null;

    void hoverAt(Offset position) {
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final size = Size(box.size.width, widget.height);
      _hoverAt(position.dx, _placePoints(points, size, strokeWidth));
    }

    return MouseRegion(
      onHover: (event) => hoverAt(event.localPosition),
      onExit: (_) => _clear(),
      child: Listener(
        onPointerDown: (event) => hoverAt(event.localPosition),
        onPointerMove: (event) => hoverAt(event.localPosition),
        onPointerUp: (event) {
          // A mouse keeps its tooltip while it hovers; a finger lifts it.
          if (event.kind != PointerDeviceKind.mouse) _clear();
        },
        onPointerCancel: (_) => _clear(),
        child: SizedBox(
          width: double.infinity,
          height: widget.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _PointsPainter(
                    points: points,
                    color: color,
                    strokeWidth: strokeWidth,
                    fill: widget.fill,
                    hovered: index,
                  ),
                ),
              ),
              if (index != null)
                Positioned.fill(
                  child: CustomSingleChildLayout(
                    delegate: _TooltipLayout(
                      points: points,
                      index: index,
                      strokeWidth: strokeWidth,
                      gap: theme.spaceXs,
                    ),
                    child: _tooltip(theme, points[index]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tooltip(ShipglowsTheme theme, MetricPoint point) {
    final describe = widget.describe ?? _defaultDescribe;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.surfaceRaised,
          border: Border.all(color: theme.border, width: theme.lineWidth),
          borderRadius: BorderRadius.circular(theme.radiusSm),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spaceSm,
            vertical: theme.spaceXs,
          ),
          child: Text(
            describe(point),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: theme.text),
          ),
        ),
      ),
    );
  }
}

/// A real value, or null for a gap (no value, or a value that is not finite).
double? _finite(double? value) =>
    value != null && value.isFinite ? value : null;

/// How many points carry a value that can be drawn.
int _countKnown(List<MetricPoint> points) =>
    points.where((point) => _finite(point.value) != null).length;

/// The tooltip text of a point with no custom [MetricSparkline.describe].
String _defaultDescribe(MetricPoint point) {
  final value = _finite(point.value);
  if (value == null) return '';
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

/// Where each point sits in a box of [size]: x by its date (oldest on the
/// left), y by its value (lowest at the bottom), and null where there is a
/// gap. A flat series sits in the middle, and so do points on one date.
List<Offset?> _placePoints(
  List<MetricPoint> points,
  Size size,
  double strokeWidth,
) {
  final known = <double>[
    for (final point in points)
      if (_finite(point.value) case final value?) value,
  ];
  if (known.isEmpty) return List<Offset?>.filled(points.length, null);
  final low = known.reduce((a, b) => a < b ? a : b);
  final high = known.reduce((a, b) => a > b ? a : b);
  final times = [for (final point in points) point.at.microsecondsSinceEpoch];
  final earliest = times.reduce((a, b) => a < b ? a : b);
  final latest = times.reduce((a, b) => a > b ? a : b);
  final timeSpan = latest - earliest;
  final valueSpan = high - low;
  final inset = strokeWidth / 2;
  final usable = size.height - strokeWidth;
  return <Offset?>[
    for (final point in points)
      if (_finite(point.value) case final value?)
        Offset(
          timeSpan == 0
              ? size.width / 2
              : size.width *
                    (point.at.microsecondsSinceEpoch - earliest) /
                    timeSpan,
          valueSpan == 0
              ? size.height / 2
              : inset + usable * (1 - (value - low) / valueSpan),
        )
      else
        null,
  ];
}

/// The index of the drawn point nearest to [x], or null when none is drawn.
int? _nearest(List<Offset?> dots, double x) {
  int? nearest;
  var distance = double.infinity;
  for (var i = 0; i < dots.length; i++) {
    final dot = dots[i];
    if (dot == null) continue;
    final gap = (dot.dx - x).abs();
    if (gap < distance) {
      distance = gap;
      nearest = i;
    }
  }
  return nearest;
}

/// The runs of drawn points, each one unbroken by a gap.
List<List<Offset>> _runsOf(List<Offset?> dots) {
  final runs = <List<Offset>>[];
  var run = <Offset>[];
  for (final dot in dots) {
    if (dot == null) {
      if (run.isNotEmpty) runs.add(run);
      run = <Offset>[];
    } else {
      run.add(dot);
    }
  }
  if (run.isNotEmpty) runs.add(run);
  return runs;
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.color,
    required this.strokeWidth,
    required this.fill,
  });

  final List<double> values;
  final Color color;
  final double strokeWidth;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    var low = values.first;
    var high = values.first;
    for (final value in values) {
      if (value < low) low = value;
      if (value > high) high = value;
    }
    final span = high - low;
    final inset = strokeWidth / 2;
    final usable = size.height - strokeWidth;
    final step = size.width / (values.length - 1);
    // A flat series sits in the middle.
    double yOf(double value) => span == 0
        ? size.height / 2
        : inset + usable * (1 - (value - low) / span);

    final line = Path()..moveTo(0, yOf(values.first));
    for (var i = 1; i < values.length; i++) {
      line.lineTo(step * i, yOf(values[i]));
    }
    if (fill) {
      final area = Path.from(line)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.12));
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      !listEquals(old.values, values) ||
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.fill != fill;
}

/// Draws dated points: one line per run between gaps, a dot for a run of one,
/// and a larger dot on the [hovered] point.
class _PointsPainter extends CustomPainter {
  _PointsPainter({
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.fill,
    required this.hovered,
  });

  final List<MetricPoint> points;
  final Color color;
  final double strokeWidth;
  final bool fill;

  /// Index of the point to mark with a dot, or null.
  final int? hovered;

  @override
  void paint(Canvas canvas, Size size) {
    final dots = _placePoints(points, size, strokeWidth);
    final dotPaint = Paint()..color = color;
    final line = Path();
    final area = Path();
    for (final run in _runsOf(dots)) {
      final first = run.first;
      if (run.length == 1) {
        canvas.drawCircle(first, strokeWidth, dotPaint);
        continue;
      }
      final segment = Path()..moveTo(first.dx, first.dy);
      for (final dot in run.skip(1)) {
        segment.lineTo(dot.dx, dot.dy);
      }
      line.addPath(segment, Offset.zero);
      if (fill) {
        final last = run.last;
        final under = Path.from(segment)
          ..lineTo(last.dx, size.height)
          ..lineTo(first.dx, size.height)
          ..close();
        area.addPath(under, Offset.zero);
      }
    }
    if (fill) {
      canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.12));
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    final index = hovered;
    if (index != null && index < dots.length) {
      final dot = dots[index];
      if (dot != null) canvas.drawCircle(dot, strokeWidth * 1.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_PointsPainter old) =>
      !listEquals(old.points, points) ||
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.fill != fill ||
      old.hovered != hovered;
}

/// Places the tooltip above the point at [index], centred on it, and keeps it
/// within the width of the sparkline.
class _TooltipLayout extends SingleChildLayoutDelegate {
  const _TooltipLayout({
    required this.points,
    required this.index,
    required this.strokeWidth,
    required this.gap,
  });

  final List<MetricPoint> points;

  /// The point the tooltip describes.
  final int index;

  final double strokeWidth;

  /// Space between the tooltip's bottom edge and the point.
  final double gap;

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final anchor = _placePoints(points, size, strokeWidth)[index];
    if (anchor == null) return const Offset(0, -10000);
    final rightmost = math.max(0.0, size.width - childSize.width);
    final x = math.min(
      math.max(0.0, anchor.dx - childSize.width / 2),
      rightmost,
    );
    final y = anchor.dy - childSize.height - gap;
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_TooltipLayout old) =>
      !listEquals(old.points, points) ||
      old.index != index ||
      old.strokeWidth != strokeWidth ||
      old.gap != gap;
}
