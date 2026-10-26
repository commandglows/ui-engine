import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

/// [values] as a small line, oldest on the left, the lowest at the bottom,
/// with a faint area under it. Draws nothing under two values. Decorative:
/// the tile says the value and its change.
class MetricSparkline extends StatelessWidget {
  const MetricSparkline(
    this.values, {
    super.key,
    this.color,
    this.height = 32,
    this.fill = true,
  });

  final List<double> values;

  /// Defaults to [ShipglowsTheme.accent].
  final Color? color;

  final double height;

  /// Whether the area under the line is tinted.
  final bool fill;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return SizedBox(height: height);
    final theme = ShipglowsTheme.of(context);
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _SparklinePainter(
            values: values,
            color: color ?? theme.accent,
            strokeWidth: theme.lineWidth * 1.5,
            fill: fill,
          ),
        ),
      ),
    );
  }
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
    double yOf(double value) =>
        span == 0 ? size.height / 2 : inset + usable * (1 - (value - low) / span);

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
