import 'package:flutter/material.dart';
import 'package:shipglows_date_sections/shipglows_date_sections.dart';
import 'package:shipglows_tag_picker/shipglows_tag_picker.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'bulk_delete_strings.dart';

/// Width of the dialog's content, at most.
const double _contentWidth = 440;

/// One type of item the person can choose to delete.
@immutable
class BulkDeleteCategory {
  /// Creates a category.
  const BulkDeleteCategory({
    required this.id,
    required this.label,
    this.selected = true,
  });

  /// Stable id, matching [BulkDeleteEntry.category].
  final String id;

  /// Text of its chip, followed by how many items the choices match.
  final String label;

  /// Whether it starts chosen. Leave long-lived content off, such as snippets.
  final bool selected;
}

/// One item that may be deleted.
@immutable
class BulkDeleteEntry {
  /// Creates an entry.
  const BulkDeleteEntry({
    required this.id,
    required this.category,
    required this.date,
    this.protected = false,
  });

  /// Id of the item, for the caller.
  final String id;

  /// The [BulkDeleteCategory.id] it belongs to.
  final String category;

  /// Date used by the periods; without one, it only matches « Tout ».
  final DateTime? date;

  /// Pinned: kept unless the person asks to include pinned items.
  final bool protected;
}

/// Asks what to delete and returns the entries chosen, or null when cancelled.
/// Deletes nothing itself: the caller removes what comes back.
///
/// [periods] defaults to the last hour, today, the last 5 days and the last
/// week, and a custom range and « Tout » are always offered. [initialPeriod]
/// defaults to the first of them; null there means « Tout » only when [periods]
/// is empty. [notice] adds a line, such as what stays out of reach.
Future<List<BulkDeleteEntry>?> showBulkDeleteDialog({
  required BuildContext context,
  required List<BulkDeleteCategory> categories,
  required List<BulkDeleteEntry> entries,
  BulkDeleteStrings strings = BulkDeleteStrings.fr,
  List<DatePeriod>? periods,
  DatePeriod? initialPeriod,
  String? notice,
}) => showDialog<List<BulkDeleteEntry>>(
  context: context,
  builder: (_) => BulkDeleteDialog(
    categories: categories,
    entries: entries,
    strings: strings,
    periods: periods,
    initialPeriod: initialPeriod,
    notice: notice,
  ),
);

/// The dialog of [showBulkDeleteDialog]. It pops with the chosen entries.
class BulkDeleteDialog extends StatefulWidget {
  /// Creates the dialog.
  const BulkDeleteDialog({
    super.key,
    required this.categories,
    required this.entries,
    this.strings = BulkDeleteStrings.fr,
    this.periods,
    this.initialPeriod,
    this.notice,
  });

  /// Types to choose from, in display order.
  final List<BulkDeleteCategory> categories;

  /// Everything that may be deleted.
  final List<BulkDeleteEntry> entries;

  /// Texts of the dialog.
  final BulkDeleteStrings strings;

  /// Named periods; see [showBulkDeleteDialog].
  final List<DatePeriod>? periods;

  /// Period chosen at first; see [showBulkDeleteDialog].
  final DatePeriod? initialPeriod;

  /// Extra line above the warning.
  final String? notice;

  @override
  State<BulkDeleteDialog> createState() => _BulkDeleteDialogState();
}

class _BulkDeleteDialogState extends State<BulkDeleteDialog> {
  late final DateTime _now = DateTime.now();
  late final List<DatePeriod> _periods =
      widget.periods ??
      [
        DatePeriod.lastHour,
        DatePeriod.today,
        DatePeriod.last5Days,
        DatePeriod.daysAgo(
          id: 'last-week',
          from: 0,
          to: 6,
          title: widget.strings.lastWeek,
        ),
      ];
  late Set<String> _categories = {
    for (final category in widget.categories)
      if (category.selected) category.id,
  };
  late DatePeriod? _period =
      widget.initialPeriod ?? (_periods.isEmpty ? null : _periods.first);
  bool _includeProtected = false;

  bool _inPeriod(BulkDeleteEntry entry, DateSpan? span) {
    if (span == null) return true;
    final date = entry.date;
    return date != null && span.contains(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final strings = widget.strings;
    final span = _period?.spanAt(_now);

    final inPeriod = [
      for (final entry in widget.entries)
        if (_inPeriod(entry, span)) entry,
    ];
    bool kept(BulkDeleteEntry entry) => !entry.protected || _includeProtected;
    final counts = <String, int>{};
    for (final entry in inPeriod) {
      if (kept(entry)) {
        counts[entry.category] = (counts[entry.category] ?? 0) + 1;
      }
    }
    final chosen = [
      for (final entry in inPeriod)
        if (_categories.contains(entry.category) && kept(entry)) entry,
    ];
    final protectedCount = inPeriod
        .where(
          (entry) => entry.protected && _categories.contains(entry.category),
        )
        .length;
    final notice = widget.notice;

    return AlertDialog(
      scrollable: true,
      title: Text(strings.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _contentWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            TagPicker(
              title: strings.what,
              options: [
                for (final category in widget.categories)
                  TagOption(
                    id: category.id,
                    label: '${category.label} · ${counts[category.id] ?? 0}',
                  ),
              ],
              selected: _categories,
              onChanged: (next) => setState(() => _categories = next),
            ),
            SizedBox(height: theme.spaceLg),
            Semantics(
              header: true,
              child: Text(strings.when, style: textTheme.titleMedium),
            ),
            SizedBox(height: theme.spaceSm),
            DatePeriodFilter(
              value: _period,
              onChanged: (next) => setState(() => _period = next),
              strings: strings.dates,
              periods: _periods,
              allLast: true,
            ),
            if (protectedCount > 0) ...[
              SizedBox(height: theme.spaceMd),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _includeProtected,
                title: Text(
                  protectedCount == 1
                      ? strings.includeOneProtected
                      : strings.includeManyProtected.replaceAll(
                          '{n}',
                          '$protectedCount',
                        ),
                ),
                onChanged: (value) =>
                    setState(() => _includeProtected = value ?? false),
              ),
            ],
            SizedBox(height: theme.spaceLg),
            if (notice != null) ...[
              Text(
                notice,
                style: textTheme.bodyMedium?.copyWith(color: theme.textMuted),
              ),
              SizedBox(height: theme.spaceXs),
            ],
            Text(
              strings.warning,
              style: textTheme.bodyMedium?.copyWith(color: theme.textMuted),
            ),
          ],
        ),
      ),
      actions: [
        // Enter never confirms a deletion by default.
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.danger,
            side: BorderSide(
              color: chosen.isEmpty ? theme.border : theme.danger,
              width: theme.lineWidth,
            ),
          ),
          onPressed: chosen.isEmpty
              ? null
              : () => Navigator.of(context).pop(chosen),
          child: Text(switch (chosen.length) {
            0 => strings.nothing,
            1 => strings.deleteOne,
            final count => strings.deleteMany.replaceAll('{n}', '$count'),
          }),
        ),
      ],
    );
  }
}
