/// A winding journey map: ordered chapters, each drawing its nodes along a
/// smooth path (the "level map" pattern). Data-agnostic: apps adapt their own
/// domain (goals, life events, milestones) into [JourneyChapter]s of
/// [JourneyNode]s and receive taps through [JourneyMap.onSelect].
///
/// The widget never scrolls by itself; put it in any scrollable. State is
/// always carried by an icon or a mark AND a semantics label, never by colour
/// alone.
library;

export 'src/journey_layout.dart';
export 'src/journey_map.dart';
export 'src/journey_model.dart';
