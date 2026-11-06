import 'dart:math' as math;
import 'dart:ui' show Offset, RRect, Radius, Rect, Size;

import 'package:flutter/foundation.dart';

/// Sizes of the floating launcher, in logical pixels.
///
/// The app's engine sizes the launcher's window from them
/// ([windowSize], [bubbleRect]); they travel with each snapshot, so the
/// launcher's engine lays its bubble and actions out with the same values.
///
/// The window is larger than what it draws: the bubble sits at its center,
/// with room on every side for the actions and their tooltips. Only the
/// bubble is kept on screen; the transparent rest may leave it.
@immutable
class ShipglowsFloatingLauncherGeometry {
  const ShipglowsFloatingLauncherGeometry({
    this.bubbleSize = 64,
    this.actionSize = 46,
    this.radius = 82,
    this.maxRadius = 128,
    this.actionGap = 6,
    this.stepAngle = 36,
    this.maxSweep = 320,
    this.tooltipWidth = 220,
    this.tooltipHeight = 72,
    this.tooltipGap = 10,
    this.shadowExtent = 12,
  });

  /// Restores a geometry from [json], as produced by [toJson]; missing or
  /// invalid values keep their default. Null when [json] is not a map.
  static ShipglowsFloatingLauncherGeometry? fromJson(Object? json) {
    if (json is! Map) return null;
    const fallback = ShipglowsFloatingLauncherGeometry();
    double read(String key, double value) => switch (json[key]) {
      final num number when number.isFinite && number >= 0 =>
        number.toDouble(),
      _ => value,
    };
    return ShipglowsFloatingLauncherGeometry(
      bubbleSize: read('bubbleSize', fallback.bubbleSize),
      actionSize: read('actionSize', fallback.actionSize),
      radius: read('radius', fallback.radius),
      maxRadius: read('maxRadius', fallback.maxRadius),
      actionGap: read('actionGap', fallback.actionGap),
      stepAngle: read('stepAngle', fallback.stepAngle),
      maxSweep: read('maxSweep', fallback.maxSweep),
      tooltipWidth: read('tooltipWidth', fallback.tooltipWidth),
      tooltipHeight: read('tooltipHeight', fallback.tooltipHeight),
      tooltipGap: read('tooltipGap', fallback.tooltipGap),
      shadowExtent: read('shadowExtent', fallback.shadowExtent),
    );
  }

  /// Diameter of the bubble.
  final double bubbleSize;

  /// Diameter of one action.
  final double actionSize;

  /// Distance from the bubble's center to the actions' centers.
  final double radius;

  /// Largest distance, reached when many actions need room on their arc.
  /// The window is sized for it.
  final double maxRadius;

  /// Smallest space between two neighbouring actions, and between an action
  /// and the bubble.
  final double actionGap;

  /// Angle between two neighbouring actions, in degrees, while the arc has
  /// room.
  final double stepAngle;

  /// Widest arc the actions spread over, in degrees.
  final double maxSweep;

  /// Widest tooltip card, beside the hovered action.
  final double tooltipWidth;

  /// Tallest tooltip card (label on up to two lines, shortcut below).
  final double tooltipHeight;

  /// Space between an action and its tooltip.
  final double tooltipGap;

  /// Room left around what is drawn for shadows; also the transparent
  /// margin of the window's shape.
  final double shadowExtent;

  /// Distance from the bubble's center to the actions' centers that
  /// [windowSize] provides for: never closer than the bubble allows.
  double get reach => math.max(
    math.max(radius, maxRadius),
    bubbleSize / 2 + actionGap + actionSize / 2,
  );

  /// Size of the launcher's window: the bubble at the center, the actions
  /// at [reach] and a tooltip beside any of them.
  Size get windowSize => Size(
    2 * (reach + actionSize / 2 + tooltipGap + tooltipWidth + shadowExtent),
    2 * (reach + math.max(actionSize, tooltipHeight) / 2 + shadowExtent),
  );

  /// Where the bubble is in the window: the part kept on screen.
  Rect get bubbleRect => Rect.fromCenter(
    center: windowSize.center(Offset.zero),
    width: bubbleSize,
    height: bubbleSize,
  );

  /// JSON-safe map with the keys [fromJson] reads.
  Map<String, Object?> toJson() => <String, Object?>{
    'bubbleSize': bubbleSize,
    'actionSize': actionSize,
    'radius': radius,
    'maxRadius': maxRadius,
    'actionGap': actionGap,
    'stepAngle': stepAngle,
    'maxSweep': maxSweep,
    'tooltipWidth': tooltipWidth,
    'tooltipHeight': tooltipHeight,
    'tooltipGap': tooltipGap,
    'shadowExtent': shadowExtent,
  };

  @override
  bool operator ==(Object other) =>
      other is ShipglowsFloatingLauncherGeometry &&
      other.bubbleSize == bubbleSize &&
      other.actionSize == actionSize &&
      other.radius == radius &&
      other.maxRadius == maxRadius &&
      other.actionGap == actionGap &&
      other.stepAngle == stepAngle &&
      other.maxSweep == maxSweep &&
      other.tooltipWidth == tooltipWidth &&
      other.tooltipHeight == tooltipHeight &&
      other.tooltipGap == tooltipGap &&
      other.shadowExtent == shadowExtent;

  @override
  int get hashCode => Object.hash(
    bubbleSize,
    actionSize,
    radius,
    maxRadius,
    actionGap,
    stepAngle,
    maxSweep,
    tooltipWidth,
    tooltipHeight,
    tooltipGap,
    shadowExtent,
  );
}

/// Where each part of the launcher goes, in window coordinates: the bubble
/// at [center], the actions on an arc toward the free side of the screen,
/// and the tooltip of each action on its outer side.
@immutable
class FloatingLauncherLayout {
  const FloatingLauncherLayout._({
    required this.geometry,
    required this.center,
    required this.radius,
    required this.direction,
    required this.actionCenters,
    required this.tooltipOnLeft,
    required this.workArea,
  });

  /// Lays [count] actions out around a bubble at [center]. [workArea] is the
  /// screen the window can draw on, in window coordinates (null: unknown,
  /// the actions open to the left).
  factory FloatingLauncherLayout.compute({
    required ShipglowsFloatingLauncherGeometry geometry,
    required Offset center,
    required int count,
    Rect? workArea,
  }) {
    final step = count < 2
        ? 0.0
        : math.min(
            _radians(geometry.stepAngle),
            _radians(geometry.maxSweep) / (count - 1),
          );
    final radius = _radiusFor(geometry, count, step);
    final direction = _directionFor(
      geometry,
      center,
      count,
      radius,
      step,
      workArea,
    );
    final centers = _arc(center, count, radius, step, direction);
    return FloatingLauncherLayout._(
      geometry: geometry,
      center: center,
      radius: radius,
      direction: direction,
      actionCenters: centers,
      tooltipOnLeft: [
        for (final point in centers)
          _tooltipOnLeft(geometry, center, point, workArea),
      ],
      workArea: workArea,
    );
  }

  final ShipglowsFloatingLauncherGeometry geometry;

  /// Center of the bubble.
  final Offset center;

  /// Distance from [center] to the actions' centers.
  final double radius;

  /// Direction the arc opens toward, in radians (0: right, y down).
  final double direction;

  /// Center of each action, the first one at the upper end of the arc.
  final List<Offset> actionCenters;

  /// Whether the tooltip of each action opens on its left.
  final List<bool> tooltipOnLeft;

  /// Screen the window can draw on, in window coordinates; null if unknown.
  final Rect? workArea;

  int get count => actionCenters.length;

  /// Bounds of the bubble.
  Rect get bubbleRect =>
      Rect.fromCircle(center: center, radius: geometry.bubbleSize / 2);

  /// Bounds of action [index].
  Rect actionRect(int index) => Rect.fromCircle(
    center: actionCenters[index],
    radius: geometry.actionSize / 2,
  );

  /// Room for the tooltip of action [index]; the card is narrower when its
  /// text is short, against the action's side of this slot. Centered on the
  /// action, moved up or down just enough to stay on screen next to an
  /// action close to the top or bottom edge.
  Rect tooltipSlot(int index) {
    final action = actionCenters[index];
    final half = geometry.actionSize / 2;
    final height = geometry.tooltipHeight;
    final left = tooltipOnLeft[index]
        ? action.dx - half - geometry.tooltipGap - geometry.tooltipWidth
        : action.dx + half + geometry.tooltipGap;
    var top = action.dy - height / 2;
    final area = workArea;
    if (area != null && area.height >= height) {
      top = top.clamp(area.top, area.bottom - height);
    }
    return Rect.fromLTWH(left, top, geometry.tooltipWidth, height);
  }

  /// Window shape while folded: the bubble and its shadow.
  List<RRect> get collapsedShape =>
      collapsedShapeAt(geometry, center);

  /// [collapsedShape] for a bubble at [center].
  static List<RRect> collapsedShapeAt(
    ShipglowsFloatingLauncherGeometry geometry,
    Offset center,
  ) {
    final radius = geometry.bubbleSize / 2 + geometry.shadowExtent;
    return [
      RRect.fromRectAndRadius(
        Rect.fromCircle(center: center, radius: radius),
        Radius.circular(radius),
      ),
    ];
  }

  /// Window shape while unfolded: a disc around the bubble that holds every
  /// action, so moving from the bubble to an action never leaves the window,
  /// plus the tooltips of [tooltips] (action indexes, in the given order).
  List<RRect> expandedShape([Iterable<int> tooltips = const <int>[]]) {
    final disc = radius + geometry.actionSize / 2 + geometry.shadowExtent;
    return [
      RRect.fromRectAndRadius(
        Rect.fromCircle(center: center, radius: disc),
        Radius.circular(disc),
      ),
      for (final index in tooltips)
        if (index >= 0 && index < count)
          RRect.fromRectAndRadius(
            tooltipSlot(index).inflate(geometry.shadowExtent),
            Radius.circular(geometry.shadowExtent),
          ),
    ];
  }

  static double _radians(double degrees) => degrees * math.pi / 180;

  // Far enough for neighbours [step] apart to keep their gap, and for every
  // action to clear the bubble; never beyond what the window holds.
  static double _radiusFor(
    ShipglowsFloatingLauncherGeometry geometry,
    int count,
    double step,
  ) {
    final clear =
        geometry.bubbleSize / 2 + geometry.actionGap + geometry.actionSize / 2;
    var wanted = math.max(geometry.radius, clear);
    if (count > 1 && step > 0) {
      final chord = geometry.actionSize + geometry.actionGap;
      wanted = math.max(wanted, chord / (2 * math.sin(step / 2)));
    }
    return math.min(wanted, geometry.reach);
  }

  // The direction, closest to the side with the most room, in which the
  // most actions stay on screen.
  static double _directionFor(
    ShipglowsFloatingLauncherGeometry geometry,
    Offset center,
    int count,
    double radius,
    double step,
    Rect? workArea,
  ) {
    if (workArea == null || count == 0) return math.pi;
    final dx = (workArea.right - center.dx) - (center.dx - workArea.left);
    final dy = (workArea.bottom - center.dy) - (center.dy - workArea.top);
    final preferred = dx.abs() < 1 && dy.abs() < 1
        ? math.pi
        : math.atan2(dy, dx);
    final room = workArea.deflate(geometry.actionSize / 2);
    const candidates = 48;
    var best = preferred;
    var bestFit = -1;
    for (var k = 0; k < candidates; k++) {
      // 0, +1, -1, +2, -2…: the first candidate found wins a tie.
      final turn = (k + 1) ~/ 2 * (k.isOdd ? 1 : -1);
      final candidate = preferred + turn * 2 * math.pi / candidates;
      var fit = 0;
      for (final point in _arc(center, count, radius, step, candidate)) {
        if (room.contains(point)) fit++;
      }
      if (fit > bestFit) {
        best = candidate;
        bestFit = fit;
        if (fit == count) break;
      }
    }
    return best;
  }

  static List<Offset> _arc(
    Offset center,
    int count,
    double radius,
    double step,
    double direction,
  ) {
    final span = step * (count - 1);
    var start = direction - span / 2;
    var delta = step;
    // The first action is the upper end of the arc (the left one when both
    // ends are level), as a list reads.
    final startY = math.sin(start);
    final endY = math.sin(start + span);
    if (endY < startY - 1e-6 ||
        ((endY - startY).abs() <= 1e-6 &&
            math.cos(start + span) < math.cos(start))) {
      start += span;
      delta = -step;
    }
    return [
      for (var i = 0; i < count; i++)
        center +
            Offset(math.cos(start + i * delta), math.sin(start + i * delta)) *
                radius,
    ];
  }

  // Outward from the bubble; above or below it, toward the roomier side. A
  // tooltip that would leave the screen goes to the other side if it fits
  // there.
  static bool _tooltipOnLeft(
    ShipglowsFloatingLauncherGeometry geometry,
    Offset center,
    Offset action,
    Rect? workArea,
  ) {
    final dx = action.dx - center.dx;
    final roomierLeft =
        workArea == null ||
        center.dx - workArea.left >= workArea.right - center.dx;
    final left = dx.abs() < 0.5 ? roomierLeft : dx < 0;
    if (workArea == null) return left;
    final reach =
        geometry.actionSize / 2 + geometry.tooltipGap + geometry.tooltipWidth;
    final fitsLeft = action.dx - reach >= workArea.left;
    final fitsRight = action.dx + reach <= workArea.right;
    if (left && !fitsLeft && fitsRight) return false;
    if (!left && !fitsRight && fitsLeft) return true;
    return left;
  }
}
