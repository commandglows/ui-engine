import 'dart:math' as math;
import 'dart:ui';

/// Pure geometry of the winding path; painter and hit targets share it so
/// they always agree. Every node of a chapter sits one `rowHeight` below the
/// previous one.
abstract final class JourneyGeometry {
  /// Horizontal centre of the node at [index] in a chapter drawn in [width].
  ///
  /// A gentle sine keeps the first node centred and the others inside
  /// `margin + nodeRadius` of both edges. [rtl] mirrors the path.
  static double centerX(
    int index,
    double width, {
    required double nodeRadius,
    bool rtl = false,
    double margin = 24,
  }) {
    final usable = math.max(0, width - 2 * (margin + nodeRadius));
    final x = width / 2 + math.sin(index * 1.15) * usable * 0.42;
    return rtl ? width - x : x;
  }

  /// Smooth cubic from the node at [from] to the node at [to], with vertical
  /// tangents at both ends.
  static Path segment(Offset from, Offset to) {
    final midY = (from.dy + to.dy) / 2;
    return Path()
      ..moveTo(from.dx, from.dy)
      ..cubicTo(from.dx, midY, to.dx, midY, to.dx, to.dy);
  }
}

/// Sizes derived from the text scale, so large text never overlaps rows.
class JourneyMetrics {
  /// Creates metrics from explicit values.
  const JourneyMetrics({
    required this.nodeRadius,
    required this.rowExtent,
    required this.headerExtent,
    required this.cellWidth,
    required this.centerY,
  });

  /// Computes metrics for a node radius and a text scaler.
  ///
  /// [scaleOf] maps a font size to its scaled size (`TextScaler.scale`). The
  /// label block holds two label lines and one caption line.
  factory JourneyMetrics.from({
    required double nodeRadius,
    required double Function(double fontSize) scaleOf,
  }) {
    final line = scaleOf(14) * 1.4;
    const topPad = 10.0;
    final labelBlock = line * 3;
    final row = topPad + nodeRadius * 2 + 4 + labelBlock + 14;
    final header = math.max(56, scaleOf(16) * 1.5 * 2 + 24).toDouble();
    final scale = scaleOf(14) / 14;
    return JourneyMetrics(
      nodeRadius: nodeRadius,
      rowExtent: row,
      headerExtent: header,
      cellWidth: 136 + 24 * math.max(0, scale - 1),
      centerY: topPad + nodeRadius,
    );
  }

  /// Radius of a node.
  final double nodeRadius;

  /// Height of one node row; also the distance between node centres.
  final double rowExtent;

  /// Height of a chapter header or of an empty-chapter notice.
  final double headerExtent;

  /// Width of the tappable cell under and around a node.
  final double cellWidth;

  /// Vertical position of the node centre inside its row.
  final double centerY;
}
