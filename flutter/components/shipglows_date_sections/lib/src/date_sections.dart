import 'package:flutter/material.dart';
import 'package:shipglows_date_groups/shipglows_date_groups.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

/// Date sections as a sliver, for your own [CustomScrollView]. Rows are built
/// lazily.
class SliverDateSections<T> extends StatelessWidget {
  /// Creates the sliver. Groups without items are skipped.
  const SliverDateSections({
    super.key,
    required this.groups,
    required this.itemBuilder,
    this.headingBuilder,
  });

  /// Sections to show, in order, usually from [groupByDate].
  final List<DateGroup<T>> groups;

  /// Builds the row of one item.
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Replaces the default heading of a section.
  final Widget Function(BuildContext context, DateGroup<T> group)?
  headingBuilder;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget Function(BuildContext)>[];
    for (final group in groups) {
      if (group.items.isEmpty) continue;
      rows.add(
        (context) =>
            headingBuilder?.call(context, group) ??
            _Heading(key: ValueKey(group.id), title: group.title),
      );
      for (final item in group.items) {
        rows.add((context) => itemBuilder(context, item));
      }
    }
    return SliverList.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) => rows[index](context),
    );
  }
}

/// A ready scroll view around [SliverDateSections].
class DateSectionsView<T> extends StatelessWidget {
  /// Creates the view.
  const DateSectionsView({
    super.key,
    required this.groups,
    required this.itemBuilder,
    this.headingBuilder,
    this.header,
    this.empty,
    this.padding = const EdgeInsets.all(16),
  });

  /// Sections to show, in order, usually from [groupByDate].
  final List<DateGroup<T>> groups;

  /// Builds the row of one item.
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Replaces the default heading of a section.
  final Widget Function(BuildContext context, DateGroup<T> group)?
  headingBuilder;

  /// Scrolls with the sections, above them: a [DatePeriodFilter], for example.
  final Widget? header;

  /// Shown when no section has an item.
  final Widget? empty;

  /// Padding around the content.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final headerWidget = header;
    final emptyWidget = empty;
    final isEmpty = groups.every((group) => group.items.isEmpty);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: padding,
          sliver: SliverMainAxisGroup(
            slivers: [
              if (headerWidget != null) SliverToBoxAdapter(child: headerWidget),
              if (isEmpty && emptyWidget != null)
                SliverToBoxAdapter(child: emptyWidget)
              else
                SliverDateSections<T>(
                  groups: groups,
                  itemBuilder: itemBuilder,
                  headingBuilder: headingBuilder,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(top: theme.spaceLg, bottom: theme.spaceSm),
      child: Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}
