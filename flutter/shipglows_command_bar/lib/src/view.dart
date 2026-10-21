import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'command.dart';
import 'query.dart';
import 'strings.dart';
import 'theme.dart';

/// What the user chose in the bar: an entry, and whether its secondary action
/// (Shift+Enter) was asked for. The owner of the bar runs it.
@immutable
class CommandBarChoice {
  const CommandBarChoice({required this.id, this.secondary = false});

  /// Id of the chosen entry, as in [CommandBarEntry.id].
  final String id;

  /// Whether the secondary action was chosen instead of the primary one.
  final bool secondary;
}

/// The command bar: a search field, a filter chip, a grouped list and a
/// keyboard footer. It only reports choices through [onChoose]; running them
/// is up to the owner, so the same widget serves the in-app dialog and a
/// floating bar.
///
/// Keys: ↑/↓ move, Enter chooses, Shift+Enter or Ctrl/⌘+Enter chooses the
/// secondary action,
/// Ctrl/⌘+1…9 chooses row n, Backspace on an empty field removes the filter,
/// Escape removes the filter first, then closes, and Ctrl/⌘+K closes.
class CommandBarView extends StatefulWidget {
  const CommandBarView({
    super.key,
    required this.source,
    required this.onChoose,
    required this.onClose,
    this.sections = const <CommandBarSection>[],
    this.filters = const <CommandBarFilter>[],
    this.strings = CommandBarStrings.en,
    this.autofocus = true,
    this.refresh,
  });

  /// Where the entries come from.
  final CommandBarSource source;

  /// Notifies when [source] changed while the bar is open (entries loaded
  /// after opening), so the list is built again.
  final Listenable? refresh;

  /// Called with the entry the user chose.
  final ValueChanged<CommandBarChoice> onChoose;

  /// Called when the user asks to close the bar.
  final VoidCallback onClose;

  /// Section titles, in display order.
  final List<CommandBarSection> sections;

  /// Categories reachable with a one-letter prefix.
  final List<CommandBarFilter> filters;

  /// Texts of the bar.
  final CommandBarStrings strings;

  /// Whether the search field takes the focus when the bar opens.
  final bool autofocus;

  @override
  State<CommandBarView> createState() => _CommandBarViewState();
}

/// Number of rows reachable with Ctrl/⌘+1…9.
const int _numberedRows = 9;

/// Width under which the Ctrl/⌘+n keycaps are hidden: touch layouts have no
/// keyboard to use them.
const double _numberedRowsMinWidth = 600;

sealed class _BarRow {
  const _BarRow();
}

final class _HeaderRow extends _BarRow {
  const _HeaderRow(this.title);

  final String title;
}

final class _EntryRow extends _BarRow {
  const _EntryRow({required this.entry, required this.itemIndex});

  final CommandBarEntry entry;

  /// Position among the entries, which the highlight and Ctrl+n use.
  final int itemIndex;
}

/// The rows of one build: the list to paint, and the entries in order.
class _BarLayout {
  const _BarLayout({
    required this.rows,
    required this.items,
    required this.rowOfItem,
  });

  static const empty = _BarLayout(
    rows: <_BarRow>[],
    items: <CommandBarEntry>[],
    rowOfItem: <int>[],
  );

  final List<_BarRow> rows;
  final List<CommandBarEntry> items;
  final List<int> rowOfItem;
}

class _CommandBarViewState extends State<CommandBarView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  // One key per list row, so the highlighted row can be brought into view
  // without a fixed row height.
  final Map<int, GlobalKey> _rowKeys = <int, GlobalKey>{};
  CommandBarFilter? _filter;
  int _highlight = 0;
  _BarLayout _layout = _BarLayout.empty;

  @override
  void initState() {
    super.initState();
    widget.refresh?.addListener(_onSourceChanged);
  }

  @override
  void didUpdateWidget(CommandBarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refresh != widget.refresh) {
      oldWidget.refresh?.removeListener(_onSourceChanged);
      widget.refresh?.addListener(_onSourceChanged);
    }
  }

  /// Rebuilds for new entries. A source may change during a build (a screen
  /// publishing its commands), so the rebuild then waits for the next frame.
  void _onSourceChanged() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.refresh?.removeListener(_onSourceChanged);
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    final parsed = parseCommandBarQuery(raw, widget.filters);
    if (_filter == null && parsed.filter != null) {
      // The prefix moves into the chip; only the words stay in the field.
      _controller.value = TextEditingValue(
        text: parsed.text,
        selection: TextSelection.collapsed(offset: parsed.text.length),
      );
      setState(() {
        _filter = parsed.filter;
        _highlight = 0;
      });
      return;
    }
    setState(() => _highlight = 0);
  }

  void _clearFilter() {
    setState(() {
      _filter = null;
      _highlight = 0;
    });
  }

  /// The highlighted entry, kept inside the list when it shrank.
  int get _effectiveHighlight => _layout.items.isEmpty
      ? 0
      : _highlight.clamp(0, _layout.items.length - 1).toInt();

  void _moveHighlight(int delta, double rowHeight) {
    final count = _layout.items.length;
    if (count == 0) return;
    final previous = _effectiveHighlight;
    final next = ((previous + delta) % count + count) % count;
    setState(() => _highlight = next);
    _revealRow(
      _layout.rowOfItem[next],
      towardsEnd: next > previous,
      rowHeight: rowHeight,
    );
  }

  GlobalKey _keyOfRow(int row) => _rowKeys.putIfAbsent(row, GlobalKey.new);

  /// Scrolls the minimum needed to show [row]. A row that is not built yet
  /// (the list is lazy) is reached by a jump near it, then brought into view
  /// once it is built.
  void _revealRow(
    int row, {
    required bool towardsEnd,
    required double rowHeight,
  }) {
    if (!_scroll.hasClients) return;
    final policy = towardsEnd
        ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
        : ScrollPositionAlignmentPolicy.keepVisibleAtStart;
    final built = _rowKeys[row]?.currentContext;
    if (built != null) {
      unawaited(Scrollable.ensureVisible(built, alignmentPolicy: policy));
      return;
    }
    final position = _scroll.position;
    final estimate = (row * rowHeight).clamp(0.0, position.maxScrollExtent);
    _scroll.jumpTo(estimate.toDouble());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rowContext = _rowKeys[row]?.currentContext;
      if (rowContext == null) return;
      unawaited(Scrollable.ensureVisible(rowContext, alignmentPolicy: policy));
    });
  }

  void _chooseItem(int itemIndex, {required bool secondary}) {
    if (itemIndex < 0 || itemIndex >= _layout.items.length) return;
    final entry = _layout.items[itemIndex];
    if (secondary) {
      if (!entry.hasSecondary) return;
    } else if (!entry.enabled) {
      // A disabled entry stays visible but never runs.
      return;
    }
    widget.onChoose(CommandBarChoice(id: entry.id, secondary: secondary));
  }

  KeyEventResult _onKeyEvent(KeyEvent event, double rowHeight) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    final hasCommandModifier =
        keyboard.isControlPressed || keyboard.isMetaPressed;

    if (key == LogicalKeyboardKey.escape) {
      if (_controller.text.isEmpty && _filter != null) {
        _clearFilter();
      } else {
        widget.onClose();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveHighlight(1, rowHeight);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveHighlight(-1, rowHeight);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      // Holding Enter must not run a command again and again.
      if (event is KeyRepeatEvent) return KeyEventResult.handled;
      _chooseItem(
        _effectiveHighlight,
        secondary: keyboard.isShiftPressed || hasCommandModifier,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace &&
        _controller.text.isEmpty &&
        _filter != null) {
      _clearFilter();
      return KeyEventResult.handled;
    }
    final digit = commandBarDigit(key);
    if (digit != null && hasCommandModifier) {
      _chooseItem(digit - 1, secondary: false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyK && hasCommandModifier) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    // Plain digits are not shortcuts: they type into the field.
    return KeyEventResult.ignored;
  }

  /// Rows for the current query: recents (without a filter only), then one
  /// block per section, each in ranking order. Search-only entries need typed
  /// words, except among the recents.
  _BarLayout _layoutFor() {
    final query = CommandBarQuery(filter: _filter, text: _controller.text);
    final entries = widget.source.entries;
    final byId = <String, CommandBarEntry>{
      for (final entry in entries) entry.id: entry,
    };

    final rows = <_BarRow>[];
    final items = <CommandBarEntry>[];
    final rowOfItem = <int>[];
    void addItem(CommandBarEntry entry) {
      rowOfItem.add(rows.length);
      items.add(entry);
      rows.add(_EntryRow(entry: entry, itemIndex: items.length - 1));
    }

    if (query.filter == null) {
      final recents = commandBarMatches([
        for (final id in widget.source.recentIds)
          if (byId[id] case final entry?) entry,
      ], query);
      if (recents.isNotEmpty) {
        rows.add(_HeaderRow(widget.strings.recentSection));
        recents.forEach(addItem);
      }
    }

    final typed = query.text.trim().isNotEmpty;
    final matches = commandBarMatches([
      for (final entry in entries)
        if (typed || !entry.searchOnly) entry,
    ], query);
    final titles = <String, String>{
      for (final section in widget.sections) section.id: section.title,
    };
    final limits = <String, int>{
      for (final section in widget.sections)
        if (section.limit case final limit?) section.id: limit,
    };
    final order = <String>[
      for (final section in widget.sections) section.id,
      for (final entry in matches)
        if (!titles.containsKey(entry.section)) entry.section,
    ];
    final seen = <String>{};
    for (final sectionId in order) {
      if (!seen.add(sectionId)) continue;
      final section = [
        for (final entry in matches)
          if (entry.section == sectionId) entry,
      ];
      if (section.isEmpty) continue;
      final limit = query.filter == null ? limits[sectionId] : null;
      rows.add(_HeaderRow(titles[sectionId] ?? sectionId));
      (limit == null ? section : section.take(limit)).forEach(addItem);
    }
    return _BarLayout(rows: rows, items: items, rowOfItem: rowOfItem);
  }

  String _prefixHint() {
    final parts = [
      for (final filter in widget.filters)
        '${filter.prefix == ' ' ? widget.strings.spaceKey : filter.prefix} '
            '${filter.label.toLowerCase()}',
    ];
    return '${widget.strings.prefixesHint} ${parts.join(' · ')}';
  }

  @override
  Widget build(BuildContext context) {
    final style = CommandBarThemeData.of(context);
    final textTheme = Theme.of(context).textTheme;
    final mutedStyle = textTheme.labelSmall?.copyWith(color: style.mutedColor);
    final strings = widget.strings;

    final layout = _layoutFor();
    _layout = layout;
    final highlight = _effectiveHighlight;
    final filter = _filter;
    final showPrefixHint =
        widget.filters.isNotEmpty &&
        filter == null &&
        _controller.text.trim().isEmpty;
    final showNumbers =
        MediaQuery.sizeOf(context).width >= _numberedRowsMinWidth;
    final highlighted = layout.items.isEmpty ? null : layout.items[highlight];

    return Focus(
      onKeyEvent: (node, event) => _onKeyEvent(event, style.rowMinHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (filter != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: Semantics(
                    label: strings.filterChip.replaceAll(
                      '{filter}',
                      filter.label.toLowerCase(),
                    ),
                    child: ExcludeSemantics(
                      child: Chip(
                        label: Text(filter.label),
                        visualDensity: VisualDensity.compact,
                        onDeleted: _clearFilter,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: widget.autofocus,
                  onChanged: _onChanged,
                  style: textTheme.bodyLarge?.copyWith(color: style.textColor),
                  decoration: InputDecoration(
                    hintText: strings.searchHint,
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Divider(height: 1, color: style.borderColor),
          if (showPrefixHint)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(_prefixHint(), style: mutedStyle),
            ),
          Flexible(
            child: layout.items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      filter?.emptyText ?? strings.noMatch,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: style.mutedColor,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: layout.rows.length,
                    itemBuilder: (context, row) => KeyedSubtree(
                      key: _keyOfRow(row),
                      child: switch (layout.rows[row]) {
                        _HeaderRow(:final title) => _SectionHeader(title),
                        _EntryRow(:final entry, :final itemIndex) =>
                            CommandBarTile(
                          entry: entry,
                          highlighted: itemIndex == highlight,
                          number: showNumbers && itemIndex < _numberedRows
                              ? itemIndex + 1
                              : null,
                          onTap: () => _chooseItem(itemIndex, secondary: false),
                        ),
                      },
                    ),
                  ),
          ),
          Divider(height: 1, color: style.borderColor),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ExcludeSemantics(
              child: Wrap(
                spacing: 16,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _FooterHint(keys: const ['↑', '↓'], label: strings.navigate),
                  _FooterHint(
                    keys: const ['Enter'],
                    label: highlighted?.primaryLabel ?? strings.open,
                  ),
                  if (highlighted != null && highlighted.hasSecondary)
                    _FooterHint(
                      keys: const ['Shift', 'Enter'],
                      label: highlighted.secondaryLabel ?? strings.secondary,
                    ),
                  _FooterHint(keys: const ['Esc'], label: strings.close),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final style = CommandBarThemeData.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: style.mutedColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// One row of the bar: icon, label, second line, shortcuts and row number.
///
/// Public so an app can list commands in its own surface (suggestions under a
/// search field) with the same row as the bar.
class CommandBarTile extends StatelessWidget {
  const CommandBarTile({
    super.key,
    required this.entry,
    required this.highlighted,
    required this.onTap,
    this.number,
    this.trailingLabel,
  });

  /// The entry shown.
  final CommandBarEntry entry;

  /// Whether the row is the one Enter runs.
  final bool highlighted;

  /// Row number reachable with Ctrl/⌘+n, or null when it has none.
  final int? number;

  /// Muted text before the shortcuts, such as the section title in a list
  /// without section headers.
  final String? trailingLabel;

  /// Called on tap, unless the entry is disabled.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = CommandBarThemeData.of(context);
    final textTheme = Theme.of(context).textTheme;
    final disabled = !entry.enabled;
    // A disabled row explains why in its second line; otherwise the subtitle.
    final secondLine = disabled ? entry.disabledReason : entry.subtitle;
    final trailingLabel = this.trailingLabel;
    final badge = entry.badge;
    final spoken = [
      entry.label,
      ?badge,
      ?secondLine,
      ?trailingLabel,
    ].join(', ');
    final iconColor = disabled
        ? style.mutedColor
        : highlighted
        ? style.highlightedIconColor
        : style.iconColor;
    final number = this.number;
    final indicator = highlighted ? style.highlightIndicatorColor : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      child: Material(
        color: highlighted ? style.highlightColor : Colors.transparent,
        borderRadius: BorderRadius.circular(style.rowRadius),
        // Keeps the indicator inside the rounded corners.
        clipBehavior: indicator == null ? Clip.none : Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(style.rowRadius),
          onTap: disabled ? null : onTap,
          child: Semantics(
            button: true,
            enabled: entry.enabled,
            selected: highlighted,
            label: spoken,
            excludeSemantics: true,
            child: Container(
              constraints: BoxConstraints(minHeight: style.rowMinHeight),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: indicator == null
                  ? null
                  : BoxDecoration(
                      border: BorderDirectional(
                        start: BorderSide(color: indicator, width: 3),
                      ),
                    ),
              child: Row(
                children: [
                  Icon(
                    entry.icon ?? Icons.arrow_forward_rounded,
                    size: 20,
                    color: iconColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                entry.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: disabled
                                      ? style.mutedColor
                                      : style.textColor,
                                  fontWeight: highlighted
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (badge != null) ...[
                              const SizedBox(width: 8),
                              _Badge(badge),
                            ],
                          ],
                        ),
                        if (secondLine != null)
                          Text(
                            secondLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelSmall?.copyWith(
                              color: style.mutedColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (trailingLabel != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      trailingLabel,
                      style: textTheme.labelSmall?.copyWith(
                        color: style.mutedColor,
                      ),
                    ),
                  ],
                  for (final shortcut in entry.shortcuts) ...[
                    const SizedBox(width: 8),
                    CommandBarKeys(keys: commandShortcutKeys(shortcut)),
                  ],
                  if (number != null) ...[
                    const SizedBox(width: 8),
                    Opacity(
                      opacity: highlighted ? 1 : 0.6,
                      child: CommandBarKeys(
                        keys: [commandBarPrimaryModifierLabel(), '$number'],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = CommandBarThemeData.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: style.borderColor),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: style.mutedColor),
      ),
    );
  }
}

class _FooterHint extends StatelessWidget {
  const _FooterHint({required this.keys, required this.label});

  final List<String> keys;
  final String label;

  @override
  Widget build(BuildContext context) {
    final style = CommandBarThemeData.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CommandBarKeys(keys: keys),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: style.mutedColor,
          ),
        ),
      ],
    );
  }
}
