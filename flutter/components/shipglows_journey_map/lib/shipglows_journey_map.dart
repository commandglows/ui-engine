/// A winding journey map: ordered chapters, each drawing its nodes along a
/// smooth path (the "level map" pattern).
///
/// Data-agnostic: apps adapt their own domain (goals, life events,
/// milestones) into [JourneyChapter]s of [JourneyNode]s and receive taps
/// through `onSelect`.
///
/// * [JourneyMap] — non-scrolling column, for short maps inside a list.
/// * [SliverJourneyMap] / [JourneyMapView] — virtualised, for long journeys,
///   with [JourneyMapController] to scroll to a node.
/// * [JourneyMapTheme] — a `ThemeExtension`; [JourneyMapLabels] — every string.
///
/// State is always carried by a mark and a spoken label, never by colour
/// alone; the path mirrors in right-to-left; animations stop when the
/// platform reduces motion.
library;

export 'src/journey_controller.dart';
export 'src/journey_geometry.dart';
export 'src/journey_labels.dart';
export 'src/journey_map.dart';
export 'src/journey_model.dart';
export 'src/journey_row_view.dart' show JourneyNodeBuilder, JourneyNodeSlot;
export 'src/journey_rows.dart' show JourneyRow, JourneyRowKind, JourneyRows;
export 'src/journey_theme.dart';
