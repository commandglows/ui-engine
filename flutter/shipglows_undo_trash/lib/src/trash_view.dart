import 'dart:async';

import 'package:flutter/material.dart';

import 'strings.dart';

/// What [TrashView] shows of one trashed item.
@immutable
class TrashEntry {
  const TrashEntry({
    required this.id,
    required this.title,
    this.searchText,
    this.deletedAt,
    this.purgeAt,
    this.purging = false,
    this.icon,
  });

  /// Stable identity, for the per-row busy state.
  final String id;
  final String title;

  /// Extra text the search looks into (summary, body excerpt).
  final String? searchText;
  final DateTime? deletedAt;

  /// When the item is deleted for good; null when the trash keeps it.
  final DateTime? purgeAt;

  /// Whether permanent deletion has started: restore is no longer possible.
  final bool purging;
  final IconData? icon;

  /// Whole days left before [purgeAt], rounded up (0 on the last day); null
  /// without a purge date.
  int? daysRemaining({DateTime? now}) {
    final deadline = purgeAt;
    if (deadline == null) return null;
    final remaining = deadline.toUtc().difference(
      (now ?? DateTime.now()).toUtc(),
    );
    if (remaining.isNegative) return 0;
    return (remaining.inSeconds / Duration.secondsPerDay).ceil();
  }
}

/// A filter of the trash (a content type, a source).
@immutable
class TrashFilter<T> {
  const TrashFilter({required this.label, required this.test});

  final String label;
  final bool Function(T item) test;
}

/// The operation that failed, for [TrashView.onError].
enum TrashOperation { restore, deletePermanently, emptyTrash }

/// Asks before an irreversible operation; true goes ahead.
typedef TrashConfirm = Future<bool> Function(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
});

/// The body of a trash screen: search, filter, restore, delete permanently,
/// empty the trash. The app keeps the data (server, local database) and its
/// own scaffold; operations run through the callbacks, each row showing a
/// spinner meanwhile. Rows are sorted by deletion date, most recent first.
class TrashView<T> extends StatefulWidget {
  const TrashView({
    super.key,
    required this.items,
    required this.entryOf,
    required this.onRestore,
    this.onDeletePermanently,
    this.onEmptyTrash,
    this.filters = const [],
    this.strings = TrashStrings.en,
    this.confirm,
    this.formatDate,
    this.onError,
    this.emptyBuilder,
    this.warnDays = 3,
    this.now,
    this.padding = const EdgeInsets.all(16),
  });

  final List<T> items;
  final TrashEntry Function(T item) entryOf;
  final Future<void> Function(T item) onRestore;

  /// Deletes one item for good, after confirmation; null hides the button.
  final Future<void> Function(T item)? onDeletePermanently;

  /// Deletes every item for good, after confirmation; null hides the button.
  final Future<void> Function(List<T> items)? onEmptyTrash;
  final List<TrashFilter<T>> filters;
  final TrashStrings strings;

  /// The app's confirmation dialog; a plain [AlertDialog] by default.
  final TrashConfirm? confirm;

  /// Date in the subtitle; the medium Material date by default.
  final String Function(BuildContext context, DateTime date)? formatDate;

  /// Receives a failed operation (an error toast, a diagnostic); reported to
  /// [FlutterError.onError] by default.
  final void Function(
    Object error,
    StackTrace stackTrace,
    TrashOperation operation,
    T? item,
  )?
  onError;

  /// The empty state; [filtered] when items exist but none matches.
  final Widget Function(BuildContext context, {required bool filtered})?
  emptyBuilder;

  /// From this many days left, the subtitle turns to the error color.
  final int warnDays;

  /// Clock for the days left, for tests.
  final DateTime Function()? now;
  final EdgeInsetsGeometry padding;

  @override
  State<TrashView<T>> createState() => _TrashViewState<T>();
}

class _TrashViewState<T> extends State<TrashView<T>> {
  String _query = '';
  int? _filter;
  final Set<String> _busy = {};
  bool _emptying = false;

  @override
  void didUpdateWidget(TrashView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final filter = _filter;
    if (filter != null && filter >= widget.filters.length) _filter = null;
  }

  List<T> _visible() {
    final words = [
      for (final word in _fold(_query).split(' '))
        if (word.isNotEmpty) word,
    ];
    final filter = _filter == null ? null : widget.filters[_filter!];
    final rows = <(T, TrashEntry)>[];
    for (final item in widget.items) {
      if (filter != null && !filter.test(item)) continue;
      final entry = widget.entryOf(item);
      if (words.isNotEmpty) {
        final haystack = _fold('${entry.title} ${entry.searchText ?? ''}');
        if (!words.every(haystack.contains)) continue;
      }
      rows.add((item, entry));
    }
    rows.sort((a, b) {
      final left = a.$2.deletedAt;
      final right = b.$2.deletedAt;
      if (left == null || right == null) {
        return left == null ? (right == null ? 0 : 1) : -1;
      }
      return right.compareTo(left);
    });
    return [for (final row in rows) row.$1];
  }

  Future<bool> _confirm(String title, String message, String confirmLabel) {
    final confirm = widget.confirm;
    if (confirm != null) {
      return confirm(
        context,
        title: title,
        message: message,
        confirmLabel: confirmLabel,
      );
    }
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(widget.strings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ).then((value) => value ?? false);
  }

  Future<void> _run(
    TrashOperation operation,
    T? item,
    Future<void> Function() body,
  ) async {
    try {
      await body();
    } catch (error, stackTrace) {
      final onError = widget.onError;
      if (onError != null) {
        onError(error, stackTrace, operation, item);
      } else {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'shipglows_undo_trash',
            context: ErrorDescription('during trash ${operation.name}'),
          ),
        );
      }
    }
  }

  Future<void> _restore(T item, TrashEntry entry) async {
    setState(() => _busy.add(entry.id));
    await _run(TrashOperation.restore, item, () => widget.onRestore(item));
    if (mounted) setState(() => _busy.remove(entry.id));
  }

  Future<void> _delete(T item, TrashEntry entry) async {
    final delete = widget.onDeletePermanently;
    if (delete == null) return;
    final strings = widget.strings;
    final confirmed = await _confirm(
      strings.deleteTitle,
      strings.deleteMessage,
      strings.deletePermanently,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy.add(entry.id));
    await _run(TrashOperation.deletePermanently, item, () => delete(item));
    if (mounted) setState(() => _busy.remove(entry.id));
  }

  Future<void> _emptyTrash() async {
    final empty = widget.onEmptyTrash;
    if (empty == null || widget.items.isEmpty) return;
    final strings = widget.strings;
    final items = List<T>.of(widget.items);
    final confirmed = await _confirm(
      strings.emptyTitle,
      strings.emptyMessage.replaceAll('{count}', '${items.length}'),
      strings.emptyTrash,
    );
    if (!confirmed || !mounted) return;
    setState(() => _emptying = true);
    await _run(TrashOperation.emptyTrash, null, () => empty(items));
    if (mounted) setState(() => _emptying = false);
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final visible = _visible();
    final canEmpty = widget.onEmptyTrash != null && widget.items.isNotEmpty;
    final toolbar = Padding(
      padding: widget.padding,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: strings.searchHint,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          if (widget.filters.isNotEmpty)
            DropdownButton<int?>(
              value: _filter,
              items: [
                DropdownMenuItem<int?>(child: Text(strings.allFilter)),
                for (var i = 0; i < widget.filters.length; i++)
                  DropdownMenuItem<int?>(
                    value: i,
                    child: Text(widget.filters[i].label),
                  ),
              ],
              onChanged: (value) => setState(() => _filter = value),
            ),
          if (canEmpty)
            _emptying
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton.icon(
                    onPressed: _emptyTrash,
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: Text(strings.emptyTrash),
                  ),
        ],
      ),
    );
    final Widget body;
    if (visible.isEmpty) {
      final filtered = widget.items.isNotEmpty;
      body =
          widget.emptyBuilder?.call(context, filtered: filtered) ??
          _DefaultEmpty(label: filtered ? strings.noMatch : strings.empty);
    } else {
      final resolved = widget.padding.resolve(Directionality.of(context));
      body = ListView.builder(
        padding: resolved.copyWith(top: 0),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final item = visible[index];
          final entry = widget.entryOf(item);
          return _TrashTile(
            entry: entry,
            strings: strings,
            subtitle: _subtitle(context, entry),
            warn: _warns(entry),
            busy: _emptying || _busy.contains(entry.id),
            onRestore: () => _restore(item, entry),
            onDelete: widget.onDeletePermanently == null
                ? null
                : () => _delete(item, entry),
          );
        },
      );
    }
    return Column(
      children: [
        toolbar,
        Expanded(child: body),
      ],
    );
  }

  bool _warns(TrashEntry entry) {
    if (entry.purging) return false;
    final days = entry.daysRemaining(now: widget.now?.call());
    return days != null && days <= widget.warnDays;
  }

  String? _subtitle(BuildContext context, TrashEntry entry) {
    final strings = widget.strings;
    if (entry.purging) return strings.purging;
    final deletedAt = entry.deletedAt;
    final date = deletedAt == null
        ? '—'
        : widget.formatDate?.call(context, deletedAt) ??
              MaterialLocalizations.of(context)
                  .formatMediumDate(deletedAt.toLocal());
    final days = entry.daysRemaining(now: widget.now?.call());
    if (days == null) {
      return deletedAt == null
          ? null
          : strings.deleted.replaceAll('{date}', date);
    }
    final template = days == 0 ? strings.lastDay : strings.deletedWithDays;
    return template.replaceAll('{date}', date).replaceAll('{days}', '$days');
  }
}

class _TrashTile extends StatelessWidget {
  const _TrashTile({
    required this.entry,
    required this.strings,
    required this.subtitle,
    required this.warn,
    required this.busy,
    required this.onRestore,
    required this.onDelete,
  });

  final TrashEntry entry;
  final TrashStrings strings;
  final String? subtitle;
  final bool warn;
  final bool busy;
  final VoidCallback onRestore;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Widget trailing;
    if (entry.purging) {
      trailing = const Icon(Icons.hourglass_top_rounded);
    } else if (busy) {
      trailing = const SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton.icon(
            onPressed: onRestore,
            icon: const Icon(Icons.restore_rounded),
            label: Text(strings.restore),
          ),
          if (onDelete != null)
            IconButton(
              tooltip: strings.deletePermanently,
              onPressed: onDelete,
              icon: const Icon(Icons.delete_forever_outlined),
            ),
        ],
      );
    }
    final subtitle = this.subtitle;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(entry.icon ?? Icons.description_outlined),
        title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                style: warn ? TextStyle(color: scheme.error) : null,
              ),
        trailing: trailing,
      ),
    );
  }
}

class _DefaultEmpty extends StatelessWidget {
  const _DefaultEmpty({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.delete_sweep_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

const _accents = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', //
  'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i', //
  'ñ': 'n',
  'ô': 'o', 'ö': 'o', 'ó': 'o', 'ò': 'o', 'õ': 'o', //
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u', //
  'ÿ': 'y',
  'œ': 'oe', 'æ': 'ae',
};

/// Lower case with accents folded, so « ecran » finds « Écran ».
String _fold(String text) {
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final char in lower.split('')) {
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString();
}
