import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'journey_geometry.dart';
import 'journey_rows.dart';

/// Scrolls a [SliverJourneyMap] or [JourneyMapView] to a node.
///
/// Offsets come from the flattened model, not from built widgets, so it works
/// for nodes far outside the viewport of a virtualised map.
class JourneyMapController {
  /// Creates a controller; pass [scrollController] to share an existing one.
  JourneyMapController({ScrollController? scrollController})
    : scrollController = scrollController ?? ScrollController(),
      _ownsScrollController = scrollController == null;

  /// The scroll controller to hand to the enclosing scroll view.
  final ScrollController scrollController;
  final bool _ownsScrollController;

  /// Distance from the top of the scrollable to the first row: padding or
  /// slivers placed before the map.
  double leadingExtent = 0;

  JourneyRows? _rows;
  JourneyMetrics? _metrics;
  bool _reduceMotion = false;

  /// Called by the map on every build; not for app code.
  void bind(
    JourneyRows rows,
    JourneyMetrics metrics, {
    bool reduceMotion = false,
  }) {
    _rows = rows;
    _metrics = metrics;
    _reduceMotion = reduceMotion;
  }

  /// Id of the first node in the current state, or null.
  String? get currentNodeId => _rows?.currentNodeId;

  /// Scroll offset of the top of the node's row, or null if unknown.
  double? offsetOfNode(String id) {
    final rows = _rows;
    final metrics = _metrics;
    final index = rows?.indexOfNode(id);
    if (rows == null || metrics == null || index == null) return null;
    return leadingExtent +
        rows.offsetOf(index, metrics.headerExtent, metrics.rowExtent);
  }

  /// Scrolls so the node sits at [alignment] of the viewport (0 top, 1
  /// bottom). Returns false when the node or the scroll view is unknown.
  /// Jumps instead of animating when the platform asks to reduce motion.
  Future<bool> scrollToNode(
    String id, {
    double alignment = 0.35,
    Duration duration = const Duration(milliseconds: 320),
    Curve curve = Curves.easeOutCubic,
  }) async {
    final top = offsetOfNode(id);
    final metrics = _metrics;
    if (top == null || metrics == null || !scrollController.hasClients) {
      return false;
    }
    final position = scrollController.position;
    final raw = top + metrics.centerY - position.viewportDimension * alignment;
    final max = math.max(position.minScrollExtent, position.maxScrollExtent);
    final target = raw.clamp(position.minScrollExtent, max).toDouble();
    if (_reduceMotion || duration == Duration.zero) {
      scrollController.jumpTo(target);
    } else {
      await scrollController.animateTo(
        target,
        duration: duration,
        curve: curve,
      );
    }
    return true;
  }

  /// Scrolls to the current node; false when there is none.
  Future<bool> scrollToCurrent({
    double alignment = 0.35,
    Duration duration = const Duration(milliseconds: 320),
  }) {
    final id = currentNodeId;
    return id == null
        ? Future.value(false)
        : scrollToNode(id, alignment: alignment, duration: duration);
  }

  /// Releases the scroll controller when this controller created it.
  void dispose() {
    if (_ownsScrollController) scrollController.dispose();
  }
}
