import 'package:flutter/material.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'journey_controller.dart';
import 'journey_labels.dart';
import 'journey_model.dart';
import 'journey_row_view.dart';
import 'journey_rows.dart';
import 'journey_theme.dart';

/// Widget shown instead of the map while loading, on error or when empty;
/// null when the map itself should be drawn.
Widget? _statusWidget(
  BuildContext context, {
  required JourneyMapLabels labels,
  required bool loading,
  required Object? error,
  required VoidCallback? onRetry,
  required WidgetBuilder? emptyBuilder,
  required bool isEmpty,
}) {
  if (loading) {
    return Padding(
      padding: const EdgeInsets.all(ShipglowsScale.spaceXl),
      child: Center(
        child: Semantics(
          liveRegion: true,
          label: labels.loading,
          child: const CircularProgressIndicator(),
        ),
      ),
    );
  }
  if (error != null) {
    return Padding(
      padding: const EdgeInsets.all(ShipglowsScale.spaceXl),
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline),
            const SizedBox(height: ShipglowsScale.spaceMd),
            Text(labels.error, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: ShipglowsScale.spaceLg),
              FilledButton(onPressed: onRetry, child: Text(labels.retry)),
            ],
          ],
        ),
      ),
    );
  }
  if (isEmpty) {
    return emptyBuilder?.call(context) ??
        Padding(
          padding: const EdgeInsets.all(ShipglowsScale.spaceXl),
          child: Center(child: Text(labels.empty, textAlign: TextAlign.center)),
        );
  }
  return null;
}

/// Chapters of nodes drawn along winding paths, as a non-scrolling column.
///
/// Fine for a handful of chapters inside an existing list. For long journeys
/// use [SliverJourneyMap] or [JourneyMapView], which build only the rows on
/// screen.
class JourneyMap extends StatefulWidget {
  /// Creates a map.
  const JourneyMap({
    required this.chapters,
    super.key,
    this.onSelect,
    this.selectedId,
    this.theme,
    this.labels,
    this.nodeBuilder,
    this.animateCurrent = true,
    this.loading = false,
    this.error,
    this.onRetry,
    this.emptyBuilder,
  });

  /// Chapters, in order.
  final List<JourneyChapter> chapters;

  /// Called with the node id; nodes are inert when null.
  final ValueChanged<String>? onSelect;

  /// Id of the selected node.
  final String? selectedId;

  /// Overrides on top of the ambient [JourneyMapTheme].
  final JourneyMapTheme? theme;

  /// Strings; defaults to the ambient locale (English or French).
  final JourneyMapLabels? labels;

  /// Replaces the default node cell.
  final JourneyNodeBuilder? nodeBuilder;

  /// Lets the current node pulse (still off when the platform reduces motion).
  final bool animateCurrent;

  /// Shows a spinner instead of the map.
  final bool loading;

  /// When non-null, shows the error notice instead of the map.
  final Object? error;

  /// Retry action of the error notice.
  final VoidCallback? onRetry;

  /// Replaces the notice shown when there are no chapters.
  final WidgetBuilder? emptyBuilder;

  @override
  State<JourneyMap> createState() => _JourneyMapState();
}

class _JourneyMapState extends State<JourneyMap> {
  late JourneyRows _rows = JourneyRows.from(widget.chapters);

  @override
  void didUpdateWidget(JourneyMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.chapters, widget.chapters)) {
      _rows = JourneyRows.from(widget.chapters);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = JourneyRowScope.resolve(
      context,
      theme: widget.theme,
      labels: widget.labels,
      selectedId: widget.selectedId,
      onSelect: widget.onSelect,
      nodeBuilder: widget.nodeBuilder,
      animateCurrent: widget.animateCurrent,
    );
    final status = _statusWidget(
      context,
      labels: scope.labels,
      loading: widget.loading,
      error: widget.error,
      onRetry: widget.onRetry,
      emptyBuilder: widget.emptyBuilder,
      isEmpty: widget.chapters.isEmpty,
    );
    if (status != null) return status;
    final metrics = scope.metrics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _rows.length; i++)
          SizedBox(
            height: _rows.extentOf(i, metrics.headerExtent, metrics.rowExtent),
            child: JourneyRowView(row: _rows.rows[i], scope: scope),
          ),
      ],
    );
  }
}

/// The same map as a sliver: only rows near the viewport are built, so a
/// hundred thousand nodes scroll like ten.
///
/// Use it inside a [CustomScrollView], or take [JourneyMapView] which wraps
/// one. Pass a [JourneyMapController] to scroll to a node.
class SliverJourneyMap extends StatefulWidget {
  /// Creates a sliver map.
  const SliverJourneyMap({
    required this.chapters,
    super.key,
    this.onSelect,
    this.selectedId,
    this.theme,
    this.labels,
    this.nodeBuilder,
    this.controller,
    this.animateCurrent = true,
    this.loading = false,
    this.error,
    this.onRetry,
    this.emptyBuilder,
  });

  /// Chapters, in order. Keep the same list instance between builds when
  /// nothing changed: the flattened model is rebuilt only when it changes.
  final List<JourneyChapter> chapters;

  /// Called with the node id; nodes are inert when null.
  final ValueChanged<String>? onSelect;

  /// Id of the selected node.
  final String? selectedId;

  /// Overrides on top of the ambient [JourneyMapTheme].
  final JourneyMapTheme? theme;

  /// Strings; defaults to the ambient locale (English or French).
  final JourneyMapLabels? labels;

  /// Replaces the default node cell.
  final JourneyNodeBuilder? nodeBuilder;

  /// Lets the app scroll to a node.
  final JourneyMapController? controller;

  /// Lets the current node pulse (still off when the platform reduces motion).
  final bool animateCurrent;

  /// Shows a spinner instead of the map.
  final bool loading;

  /// When non-null, shows the error notice instead of the map.
  final Object? error;

  /// Retry action of the error notice.
  final VoidCallback? onRetry;

  /// Replaces the notice shown when there are no chapters.
  final WidgetBuilder? emptyBuilder;

  @override
  State<SliverJourneyMap> createState() => _SliverJourneyMapState();
}

class _SliverJourneyMapState extends State<SliverJourneyMap> {
  late JourneyRows _rows = JourneyRows.from(widget.chapters);

  @override
  void didUpdateWidget(SliverJourneyMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.chapters, widget.chapters)) {
      _rows = JourneyRows.from(widget.chapters);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = JourneyRowScope.resolve(
      context,
      theme: widget.theme,
      labels: widget.labels,
      selectedId: widget.selectedId,
      onSelect: widget.onSelect,
      nodeBuilder: widget.nodeBuilder,
      animateCurrent: widget.animateCurrent,
    );
    final status = _statusWidget(
      context,
      labels: scope.labels,
      loading: widget.loading,
      error: widget.error,
      onRetry: widget.onRetry,
      emptyBuilder: widget.emptyBuilder,
      isEmpty: widget.chapters.isEmpty,
    );
    if (status != null) return SliverToBoxAdapter(child: status);
    final metrics = scope.metrics;
    widget.controller?.bind(
      _rows,
      metrics,
      reduceMotion: MediaQuery.disableAnimationsOf(context),
    );
    return SliverVariedExtentList.builder(
      itemCount: _rows.length,
      itemExtentBuilder: (index, _) =>
          _rows.extentOf(index, metrics.headerExtent, metrics.rowExtent),
      itemBuilder: (context, index) =>
          JourneyRowView(row: _rows.rows[index], scope: scope),
    );
  }
}

/// A ready-made scroll view around [SliverJourneyMap].
class JourneyMapView extends StatefulWidget {
  /// Creates a scrolling map.
  const JourneyMapView({
    required this.chapters,
    super.key,
    this.onSelect,
    this.selectedId,
    this.theme,
    this.labels,
    this.nodeBuilder,
    this.controller,
    this.padding = const EdgeInsets.all(ShipglowsScale.spaceLg),
    this.initialScrollToCurrent = false,
    this.animateCurrent = true,
    this.loading = false,
    this.error,
    this.onRetry,
    this.emptyBuilder,
  });

  /// Chapters, in order.
  final List<JourneyChapter> chapters;

  /// Called with the node id; nodes are inert when null.
  final ValueChanged<String>? onSelect;

  /// Id of the selected node.
  final String? selectedId;

  /// Overrides on top of the ambient [JourneyMapTheme].
  final JourneyMapTheme? theme;

  /// Strings; defaults to the ambient locale (English or French).
  final JourneyMapLabels? labels;

  /// Replaces the default node cell.
  final JourneyNodeBuilder? nodeBuilder;

  /// Scroll control; one is created when null.
  final JourneyMapController? controller;

  /// Space around the map.
  final EdgeInsets padding;

  /// Opens already scrolled to the current node.
  final bool initialScrollToCurrent;

  /// Lets the current node pulse (still off when the platform reduces motion).
  final bool animateCurrent;

  /// Shows a spinner instead of the map.
  final bool loading;

  /// When non-null, shows the error notice instead of the map.
  final Object? error;

  /// Retry action of the error notice.
  final VoidCallback? onRetry;

  /// Replaces the notice shown when there are no chapters.
  final WidgetBuilder? emptyBuilder;

  @override
  State<JourneyMapView> createState() => _JourneyMapViewState();
}

class _JourneyMapViewState extends State<JourneyMapView> {
  JourneyMapController? _owned;

  JourneyMapController get _controller =>
      widget.controller ?? (_owned ??= JourneyMapController());

  @override
  void initState() {
    super.initState();
    if (widget.initialScrollToCurrent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.scrollToCurrent(duration: Duration.zero);
      });
    }
  }

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller..leadingExtent = widget.padding.top;
    return CustomScrollView(
      controller: controller.scrollController,
      slivers: [
        SliverPadding(
          padding: widget.padding,
          sliver: SliverJourneyMap(
            chapters: widget.chapters,
            onSelect: widget.onSelect,
            selectedId: widget.selectedId,
            theme: widget.theme,
            labels: widget.labels,
            nodeBuilder: widget.nodeBuilder,
            controller: controller,
            animateCurrent: widget.animateCurrent,
            loading: widget.loading,
            error: widget.error,
            onRetry: widget.onRetry,
            emptyBuilder: widget.emptyBuilder,
          ),
        ),
      ],
    );
  }
}
