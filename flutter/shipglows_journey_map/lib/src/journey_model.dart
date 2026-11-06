import 'package:flutter/widgets.dart';

/// Where a node stands on the journey.
enum JourneyNodeState {
  /// Reached or completed.
  done,

  /// The place the person is at now; drawn with a highlighted ring.
  current,

  /// Not reached yet.
  upcoming,

  /// No progression meaning (for example a past life event).
  neutral,
}

/// One stop on the path.
@immutable
class JourneyNode {
  const JourneyNode({
    required this.id,
    required this.label,
    this.state = JourneyNodeState.neutral,
    this.marker,
    this.icon,
    this.caption,
    this.progress,
    this.semanticLabel,
  }) : assert(progress == null || (progress >= 0 && progress <= 1));

  /// Stable identity handed back to [JourneyMap.onSelect].
  final String id;

  /// Name shown under the node.
  final String label;

  final JourneyNodeState state;

  /// Short text inside the node (a number, a year). Falls back to [icon].
  final String? marker;

  /// Icon inside the node when there is no [marker].
  final IconData? icon;

  /// Small secondary line under [label] (a date, a count).
  final String? caption;

  /// Optional 0..1 ring drawn around the node.
  final double? progress;

  /// Replaces the default spoken label (`label, state`).
  final String? semanticLabel;
}

/// A titled group of nodes drawn on one path.
@immutable
class JourneyChapter {
  const JourneyChapter({
    required this.id,
    required this.title,
    required this.nodes,
    this.icon,
    this.trailing,
  });

  final String id;
  final String title;
  final List<JourneyNode> nodes;
  final IconData? icon;

  /// Right-aligned summary in the chapter header (for example `3/8`).
  final String? trailing;
}

/// Spoken names for [JourneyNodeState]; override to localise.
@immutable
class JourneyStateLabels {
  const JourneyStateLabels({
    this.done = 'terminé',
    this.current = 'en cours',
    this.upcoming = 'à venir',
    this.neutral = '',
  });

  final String done;
  final String current;
  final String upcoming;
  final String neutral;

  String of(JourneyNodeState state) => switch (state) {
    JourneyNodeState.done => done,
    JourneyNodeState.current => current,
    JourneyNodeState.upcoming => upcoming,
    JourneyNodeState.neutral => neutral,
  };
}
