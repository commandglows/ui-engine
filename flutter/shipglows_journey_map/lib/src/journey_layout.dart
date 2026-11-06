import 'dart:math' as math;
import 'dart:ui';

/// Geometry of one chapter's path, computed from the width alone so painter
/// and hit targets always agree.
class JourneyLayout {
  const JourneyLayout._(this.centers, this.height);

  /// Node centres, top to bottom, in the chapter's local space.
  final List<Offset> centers;

  /// Total height needed for the chapter's path area.
  final double height;

  /// Lays [count] nodes along a gentle sine: first and last stay inside
  /// [margin] + [nodeRadius] of the edges, rows are [rowHeight] apart.
  factory JourneyLayout.winding({
    required int count,
    required double width,
    double nodeRadius = 28,
    double rowHeight = 118,
    double margin = 24,
    double topInset = 8,
  }) {
    if (count <= 0) return const JourneyLayout._(<Offset>[], 0);
    final usable = math.max(0.0, width - 2 * (margin + nodeRadius));
    final mid = width / 2;
    final centers = <Offset>[
      for (var i = 0; i < count; i++)
        Offset(
          mid + math.sin(i * 1.15) * usable * 0.42,
          topInset + nodeRadius + i * rowHeight,
        ),
    ];
    return JourneyLayout._(
      centers,
      topInset + nodeRadius * 2 + (count - 1) * rowHeight + 44,
    );
  }

  /// Smooth path through every centre using vertical tangents.
  Path get path {
    final p = Path();
    if (centers.isEmpty) return p;
    p.moveTo(centers.first.dx, centers.first.dy);
    for (var i = 1; i < centers.length; i++) {
      final a = centers[i - 1];
      final b = centers[i];
      final midY = (a.dy + b.dy) / 2;
      p.cubicTo(a.dx, midY, b.dx, midY, b.dx, b.dy);
    }
    return p;
  }
}
