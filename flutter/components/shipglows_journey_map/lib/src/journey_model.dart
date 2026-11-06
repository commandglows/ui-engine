import 'package:flutter/widgets.dart';

/// Where a node stands on the journey.
enum JourneyNodeState {
  /// Reached or completed; drawn with a check badge.
  done,

  /// The place the person is at now; drawn with a thick ring and a soft pulse.
  current,

  /// Not reached yet; drawn as an outlined node.
  upcoming,

  /// No progression meaning (for example a past life event).
  neutral,
}

/// One stop on the path.
@immutable
class JourneyNode {
  /// Creates a stop.
  ///
  /// [id] should be unique within the map: a repeated id still renders, but
  /// every node sharing it reads as selected together.
  const JourneyNode({
    required this.id,
    required this.label,
    this.state = JourneyNodeState.neutral,
    this.marker,
    this.icon,
    this.caption,
    this.progress,
    this.semanticLabel,
  }) : assert(
         progress == null || (progress >= 0 && progress <= 1),
         'progress must be between 0 and 1',
       );

  /// Stable identity handed back to `onSelect`.
  final String id;

  /// Name shown under the node. Long labels are cut visually after two lines;
  /// the full text always stays in the semantics label.
  final String label;

  /// Progression state; carried by a mark and a spoken label, never by colour
  /// alone.
  final JourneyNodeState state;

  /// Short text inside the node (a number, a year). Falls back to [icon].
  final String? marker;

  /// Icon inside the node when there is no [marker].
  final IconData? icon;

  /// Small secondary line under [label] (a date, a count).
  final String? caption;

  /// Optional 0..1 ring drawn around the node.
  final double? progress;

  /// Replaces the default spoken label (`label, caption, state, position`).
  final String? semanticLabel;
}

/// A titled group of nodes drawn on one path.
@immutable
class JourneyChapter {
  /// Creates a chapter.
  const JourneyChapter({
    required this.id,
    required this.title,
    required this.nodes,
    this.icon,
    this.trailing,
  });

  /// Stable identity of the chapter.
  final String id;

  /// Header text.
  final String title;

  /// Stops of this chapter, in path order.
  final List<JourneyNode> nodes;

  /// Icon before the title.
  final IconData? icon;

  /// Right-aligned summary in the chapter header (for example `3/8`).
  final String? trailing;
}
