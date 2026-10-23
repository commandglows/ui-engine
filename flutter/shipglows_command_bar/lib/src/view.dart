import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shipglows_menu/shipglows_menu.dart';

import 'actions_panel.dart';
import 'behavior.dart';
import 'command.dart';
import 'hotkey.dart';
import 'practice.dart';
import 'query.dart';
import 'query_history.dart';
import 'strings.dart';
import 'theme.dart';

/// What the user chose in the bar: an entry, whether its secondary action
/// (Shift+Enter) or one of its [CommandBarEntry.actions] was asked for, and
/// the typed text it works on. The owner of the bar runs it.
@immutable
class CommandBarChoice {
  const CommandBarChoice({
    required this.id,
    this.secondary = false,
    this.query,
    this.action,
    this.appMenu = false,
  });

  /// Id of the chosen entry, as in [CommandBarEntry.id]; with [appMenu], the
  /// id of the [ShipglowsMenuAction] chosen in [CommandBarView.appMenu].
  final String id;

  /// Whether [id] is an action of the app menu (the ≡ button), not an
  /// entry. Its `onSelected`, when it has one, already ran.
  final bool appMenu;

  /// Whether the secondary action was chosen instead of the primary one.
  final bool secondary;

  /// The typed words, filter prefix left out, for an entry that
  /// [CommandBarEntry.usesQuery]; null for any other.
  final String? query;

  /// Id of the [CommandBarEntryAction] chosen in the actions panel, or with
  /// its shortcut; null for Enter and Shift+Enter.
  final String? action;
}

/// The command bar: a search field, a filter chip, a grouped list and a
/// keyboard footer. It only reports choices through [onChoose]; running them
/// is up to the owner, so the same widget serves the in-app dialog and a
/// floating bar.
///
/// Keys: ↑/↓ move, Enter chooses, Shift+Enter or Ctrl/⌘+Enter chooses the
/// secondary action, Alt+Enter (or a right-click on a row) opens the actions
/// panel of the row, the shortcut of one of its [CommandBarEntry.actions]
/// chooses it, Ctrl/⌘+1…9 chooses row n, Backspace on an empty field removes
/// the filter, Escape closes the panel, then removes the filter, then closes,
/// and [hotkey] closes.
///
/// With [CommandBarBehavior.restoreLastQuery] the field opens with the first
/// of [queryHistory], selected; with [CommandBarBehavior.showQueryHistory]
/// the past searches are listed under an empty or restored field.
/// [onQueryUsed] receives what was typed, once per opening (on a choice or
/// when the bar closes), so the owner can keep the history.
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
    this.behavior = const CommandBarBehavior(),
    this.onSearchDoubleTap,
    this.onSearchDragStart,
    this.footerBuilder,
    this.fillHeight = false,
    this.queryHistory = const <String>[],
    this.onQueryUsed,
    this.hotkey = CommandBarHotkey.standard,
    this.appMenu,
  });

  /// Where the entries come from.
  final CommandBarSource source;

  /// Notifies when [source] changed while the bar is open (entries loaded
  /// after opening), so the list is built again.
  final Listenable? refresh;

  /// Optional search and listing behaviours, all off by default.
  final CommandBarBehavior behavior;

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

  /// Called when the user double-clicks the search field (expand the bar,
  /// maximize its window). The field then keeps its caret instead of
  /// selecting the word under the pointer.
  final VoidCallback? onSearchDoubleTap;

  /// Called when the user drags in the search field with the primary button,
  /// instead of selecting text with the mouse: a floating window moves from
  /// there. Keyboard selection (Shift+arrows, Ctrl+A) and a click to place
  /// the caret keep working.
  final VoidCallback? onSearchDragStart;

  /// Wraps the footer strip of key hints, which holds nothing to click: a
  /// frameless window can make it its drag area.
  final Widget Function(BuildContext context, Widget footer)? footerBuilder;

  /// Whether the bar takes all the height it is given, the list growing and
  /// the footer at the bottom (a window of its own). Otherwise it is as tall
  /// as its content (a dialog).
  final bool fillHeight;

  /// Past searches, most recent first, filter prefix included (as passed to
  /// [onQueryUsed]).
  final List<String> queryHistory;

  /// Called with the search, filter prefix included, when an entry is chosen
  /// or the bar closes with words in the field. Not called for an empty
  /// field.
  final ValueChanged<String>? onQueryUsed;

  /// The app's hotkey for the bar, which closes it too. Null when a native
  /// shell handles it system-wide (a floating window).
  final CommandBarHotkey? hotkey;

  /// The app's own menu (settings, feedback, manual, about…), opened by the
  /// ≡ button at the start of the footer, as in the tray: usually
  /// `ShipglowsAppMenu.menu()`. A choice closes the bar through [onChoose]
  /// with [CommandBarChoice.appMenu]. No button when null.
  final ShipglowsMenu? appMenu;

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

/// Id prefix of the rows listing past searches; never a real entry id.
const String _queryRowPrefix = '\u0000query:';

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

  /// The search field, which gets the keyboard back when the actions panel
  /// closes.
  final FocusNode _searchFocus = FocusNode(debugLabel: 'CommandBarSearch');
  final ScrollController _scroll = ScrollController();
  // One key per list row, so the highlighted row can be brought into view
  // without a fixed row height.
  final Map<int, GlobalKey> _rowKeys = <int, GlobalKey>{};
  CommandBarFilter? _filter;
  int _highlight = 0;
  _BarLayout _layout = _BarLayout.empty;

  /// Last primary press on the search field, to spot a double-click.
  PointerDownEvent? _lastSearchDown;

  /// Primary press in progress on the search field, until it moves the
  /// window or is released.
  PointerDownEvent? _searchPress;

  /// Selection to put back once the press ends, when the field must not keep
  /// what the mouse did (a word selected by a double-click, a drag
  /// selection while the window moved).
  TextSelection? _restoreSelection;

  /// Selection after the last click released on the search field.
  TextSelection? _selectionAfterClick;

  /// Whether the field still holds the restored last search, untouched: the
  /// past searches are listed then too.
  bool _restoredUntouched = false;

  /// Whether this opening already gave its search to [onQueryUsed].
  bool _queryReported = false;

  /// Whether the actions panel of the highlighted entry is open.
  bool _actionsOpen = false;

  /// The row the actions panel belongs to, in the coordinates of [_listKey];
  /// null when it could not be measured.
  Rect? _panelAnchor;

  /// The list area the actions panel is laid out over.
  final GlobalKey _listKey = GlobalKey();

  /// Entry under the mouse, which shows its « … » button.
  final ValueNotifier<int?> _hoveredItem = ValueNotifier<int?>(null);

  @override
  void initState() {
    super.initState();
    widget.refresh?.addListener(_onSourceChanged);
    if (widget.behavior.restoreLastQuery && widget.queryHistory.isNotEmpty) {
      _fillQuery(widget.queryHistory.first, selectAll: true);
      _restoredUntouched = _controller.text.isNotEmpty;
    }
  }

  /// Gives what was typed to [onQueryUsed], once per opening.
  void _reportQuery() {
    if (_queryReported || _controller.text.trim().isEmpty) return;
    _queryReported = true;
    widget.onQueryUsed?.call(_rawQuery());
  }

  /// Puts the past search [raw] back in the field, its prefix in the chip.
  /// [selectAll] selects the words, so typing replaces them.
  void _fillQuery(String raw, {required bool selectAll}) {
    final parsed = parseCommandBarQuery(raw, widget.filters);
    _filter = parsed.filter;
    _highlight = 0;
    _controller.value = TextEditingValue(
      text: parsed.text,
      selection: selectAll
          ? TextSelection(baseOffset: 0, extentOffset: parsed.text.length)
          : TextSelection.collapsed(offset: parsed.text.length),
    );
  }

  /// The current search as typed, filter prefix included, so it parses back
  /// to the same filter and words.
  String _rawQuery() {
    final text = _controller.text.trim();
    final filter = _filter;
    if (filter == null) return text;
    if (filter.prefix == ' ') return ' $text';
    return filter.requiresSpace
        ? '${filter.prefix} $text'
        : '${filter.prefix}$text';
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
    // Closed without a choice: the search is kept all the same.
    _reportQuery();
    _controller.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    _hoveredItem.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    _restoredUntouched = false;
    _actionsOpen = false;
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

  /// Applies [filter] from its prefix hint, keeping the typed words.
  void _applyFilter(CommandBarFilter filter) {
    setState(() {
      _filter = filter;
      _highlight = 0;
    });
  }

  void _clearFilter() {
    setState(() {
      _filter = null;
      _highlight = 0;
    });
  }

  /// Moves to the previous or next button of the filter row, « All » first,
  /// wrapping around.
  void _stepFilter(int delta) {
    final steps = <CommandBarFilter?>[null, ...widget.filters];
    // By prefix: the app may rebuild its filters (a new language).
    final current = steps.indexWhere(
      (step) => step?.prefix == _filter?.prefix,
    );
    final next = steps[(current + delta) % steps.length];
    if (next == null) {
      _clearFilter();
    } else {
      _applyFilter(next);
    }
  }

  /// Whether Left or Right should change the filter: the field is empty, or
  /// the caret already sits at that edge, so the key would not move it.
  bool _arrowSwitchesFilter({required bool left}) {
    if (widget.filters.isEmpty) return false;
    final text = _controller.text;
    if (text.isEmpty) return true;
    final selection = _controller.selection;
    if (!selection.isValid || !selection.isCollapsed) return false;
    return selection.baseOffset == (left ? 0 : text.length);
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
    setState(() {
      _highlight = next;
      _actionsOpen = false;
    });
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

  /// Spots a double-click from raw presses, so the text field keeps its own
  /// tap and selection gestures.
  void _onSearchPointerDown(PointerDownEvent event) {
    if (event.buttons != kPrimaryButton) return;
    _searchPress = event;
    final onDoubleTap = widget.onSearchDoubleTap;
    if (onDoubleTap == null) return;
    final previous = _lastSearchDown;
    if (previous != null &&
        previous.kind == event.kind &&
        event.timeStamp - previous.timeStamp <= kDoubleTapTimeout &&
        (event.position - previous.position).distance <= kDoubleTapSlop) {
      _lastSearchDown = null;
      _searchPress = null;
      // The field selects the word on this press: the caret goes back.
      _restoreSelection =
          _selectionAfterClick ??
          TextSelection.collapsed(offset: _controller.text.length);
      onDoubleTap();
      return;
    }
    _lastSearchDown = event;
  }

  void _onSearchPointerMove(PointerMoveEvent event) {
    final press = _searchPress;
    final onDragStart = widget.onSearchDragStart;
    if (press == null || onDragStart == null) return;
    final slop = press.kind == PointerDeviceKind.touch
        ? kTouchSlop
        : kPrecisePointerPanSlop;
    if ((event.position - press.position).distance <= slop) return;
    _searchPress = null;
    _lastSearchDown = null;
    // The field placed the caret on the press and may have started a drag
    // selection from it: the caret stays where the press was.
    _restoreSelection = TextSelection.collapsed(
      offset: _controller.selection.baseOffset,
    );
    onDragStart();
  }

  void _onSearchPointerEnd(PointerEvent event) {
    _searchPress = null;
    final restore = _restoreSelection;
    _restoreSelection = null;
    if (restore != null) {
      _controller.selection = restore;
      _selectionAfterClick = restore;
      // The field may still apply its own gesture end after this event.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.selection = restore;
      });
      return;
    }
    // The field places the caret once the click is resolved, after this
    // event.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _selectionAfterClick = _controller.selection;
    });
  }

  void _chooseItem(int itemIndex, {required bool secondary, String? action}) {
    if (itemIndex < 0 || itemIndex >= _layout.items.length) return;
    final entry = _layout.items[itemIndex];
    if (entry.id.startsWith(_queryRowPrefix)) {
      if (secondary || action != null) return;
      setState(() {
        _restoredUntouched = false;
        _fillQuery(
          entry.id.substring(_queryRowPrefix.length),
          selectAll: false,
        );
      });
      return;
    }
    if (action != null) {
      // Like the secondary action, an entry action runs on a disabled row.
      if (!entry.actions.any((candidate) => candidate.id == action)) return;
    } else if (secondary) {
      if (!entry.hasSecondary) return;
    } else if (!entry.enabled) {
      // A disabled entry stays visible but never runs.
      return;
    }
    _reportQuery();
    widget.onChoose(
      CommandBarChoice(
        id: entry.id,
        secondary: action == null && secondary,
        query: entry.usesQuery ? _controller.text.trim() : null,
        action: action,
      ),
    );
  }

  /// What the actions panel of [entry] lists: Enter when it runs, Shift+Enter
  /// when there is one, then the entry's own actions, those without a group
  /// first, then each group in the order it first appears.
  List<CommandBarPanelLine> _panelActions(CommandBarEntry entry) {
    final strings = widget.strings;
    final groups = <String?>[
      null,
      for (final action in entry.actions) action.group,
    ].toSet().toList();
    final actions = [
      for (final group in groups)
        for (final action in entry.actions)
          if (action.group == group && !action.destructive) action,
      for (final action in entry.actions)
        if (action.destructive) action,
    ];
    return [
      if (entry.enabled)
        CommandBarPanelLine(
          label: entry.primaryLabel ?? strings.open,
          icon: entry.icon,
          shortcut: '↵',
        ),
      if (entry.hasSecondary)
        CommandBarPanelLine(
          label: entry.secondaryLabel ?? strings.secondary,
          shortcut: '${strings.shiftKey}+↵',
          secondary: true,
        ),
      for (final action in actions)
        CommandBarPanelLine(
          label: action.label,
          icon: action.icon,
          group: action.group,
          shortcut: action.shortcut,
          action: action.id,
          destructive: action.destructive,
          confirm: action.confirm,
        ),
    ];
  }

  CommandBarEntry? get _highlightedEntry =>
      _layout.items.isEmpty ? null : _layout.items[_effectiveHighlight];

  /// Opens the actions panel of row [itemIndex], when it has more than Enter.
  void _openActions(int itemIndex) {
    if (itemIndex < 0 || itemIndex >= _layout.items.length) return;
    if (!_layout.items[itemIndex].hasActions) return;
    setState(() {
      _highlight = itemIndex;
      _actionsOpen = true;
      _panelAnchor = _anchorOf(itemIndex);
    });
  }

  /// Opens the actions panel of row [itemIndex], or closes it when it is
  /// already that row's: the « … » button and a right-click toggle it.
  void _toggleActions(int itemIndex) {
    if (_actionsOpen && _effectiveHighlight == itemIndex) {
      _closeActions();
    } else {
      _openActions(itemIndex);
    }
  }

  /// Where row [itemIndex] is over the list, to anchor the panel to it.
  Rect? _anchorOf(int itemIndex) {
    final row = _layout.rowOfItem[itemIndex];
    final rowBox = _rowKeys[row]?.currentContext?.findRenderObject();
    final listBox = _listKey.currentContext?.findRenderObject();
    if (rowBox is! RenderBox || listBox is! RenderBox) return null;
    if (!rowBox.hasSize || !listBox.hasSize) return null;
    return rowBox.localToGlobal(Offset.zero, ancestor: listBox) & rowBox.size;
  }

  /// Closes the actions panel; the search field takes the keyboard back.
  void _closeActions() {
    setState(() => _actionsOpen = false);
    _searchFocus.requestFocus();
  }

  /// A line chosen in the panel, its confirmation (if any) already given.
  void _choosePanelAction(CommandBarPanelLine line) {
    setState(() => _actionsOpen = false);
    _chooseItem(
      _effectiveHighlight,
      secondary: line.secondary,
      action: line.action,
    );
  }

  /// Chooses the action of [entry] whose shortcut [event] presses; false
  /// when none does.
  bool _runActionShortcut(CommandBarEntry? entry, KeyEvent event) {
    if (entry == null || event is KeyRepeatEvent) return false;
    for (final action in entry.actions) {
      final shortcut = action.shortcut;
      if (shortcut != null && commandBarShortcutMatches(shortcut, event)) {
        setState(() => _actionsOpen = false);
        _chooseItem(_effectiveHighlight, secondary: false, action: action.id);
        return true;
      }
    }
    return false;
  }

  /// Keys the actions panel lets through (it handles ↑/↓, Enter, Escape and
  /// typing in its search): the bar's hotkey, an action's shortcut, and
  /// Alt+Enter or ← (empty search) to close it. Others go on, so typed
  /// characters reach the panel's field.
  KeyEventResult _onPanelKeyEvent(KeyEvent event) {
    final key = event.logicalKey;
    if (widget.hotkey?.matches(event) ?? false) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    final enter =
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter;
    if (key == LogicalKeyboardKey.arrowLeft ||
        (enter && HardwareKeyboard.instance.isAltPressed)) {
      if (event is! KeyRepeatEvent) _closeActions();
      return KeyEventResult.handled;
    }
    return _runActionShortcut(_highlightedEntry, event)
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  KeyEventResult _onKeyEvent(KeyEvent event, double rowHeight) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    final hasCommandModifier =
        keyboard.isControlPressed || keyboard.isMetaPressed;
    if (_actionsOpen) return _onPanelKeyEvent(event);

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
    if ((key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.arrowRight) &&
        !keyboard.isShiftPressed &&
        !keyboard.isAltPressed &&
        !hasCommandModifier) {
      // Elsewhere in the field the arrows move the caret as usual.
      final left = key == LogicalKeyboardKey.arrowLeft;
      if (!_arrowSwitchesFilter(left: left)) return KeyEventResult.ignored;
      _stepFilter(left ? -1 : 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      // Holding Enter must not run a command again and again.
      if (event is KeyRepeatEvent) return KeyEventResult.handled;
      if (keyboard.isAltPressed) {
        _openActions(_effectiveHighlight);
        return KeyEventResult.handled;
      }
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
    if (widget.hotkey?.matches(event) ?? false) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    if (_runActionShortcut(_highlightedEntry, event)) {
      return KeyEventResult.handled;
    }
    // Plain digits are not shortcuts: they type into the field.
    return KeyEventResult.ignored;
  }

  /// Rows for the current query: recents (without a filter only), then one
  /// block per section, each in ranking order, then the actions on the typed
  /// text. Search-only entries need typed words, except among the recents.
  _BarLayout _layoutFor() {
    final query = CommandBarQuery(filter: _filter, text: _controller.text);
    final hidden = widget.behavior.hiddenKinds;
    final shown = [
      for (final entry in widget.source.entries)
        if (!hidden.contains(entry.kind?.id)) entry,
    ];
    // Actions on the text are never searched: they come last, with the text.
    final queryActions = [
      for (final entry in shown)
        if (entry.usesQuery) entry,
    ];
    final entries = [
      for (final entry in shown)
        if (!entry.usesQuery) entry,
    ];
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

    // The past searches; choosing one puts it back in the field.
    void addQueryHistory() {
      if (!widget.behavior.showQueryHistory) return;
      final past = widget.queryHistory
          .where((raw) => raw.trim().isNotEmpty)
          .take(commandBarQueryHistoryShown)
          .toList(growable: false);
      if (past.isEmpty) return;
      rows.add(_HeaderRow(widget.strings.querySection));
      for (final raw in past) {
        final parsed = parseCommandBarQuery(raw, widget.filters);
        addItem(
          CommandBarEntry(
            id: '$_queryRowPrefix$raw',
            label: parsed.text,
            section: _queryRowPrefix,
            icon: Icons.history_rounded,
            subtitle: parsed.filter?.label,
            primaryLabel: widget.strings.fillQuery,
          ),
        );
      }
    }

    if (query.filter == null) {
      final recents = commandBarMatches(
        [
          for (final id in widget.source.recentIds)
            if (byId[id] case final entry?) entry,
        ],
        query,
        fuzzy: widget.behavior.fuzzyMatch,
      );
      if (recents.isNotEmpty) {
        rows.add(_HeaderRow(widget.strings.recentSection));
        recents.forEach(addItem);
      }
      if (query.text.trim().isEmpty) addQueryHistory();
    }

    final behavior = widget.behavior;
    final typed = query.text.trim().isNotEmpty;
    final scored = scoreCommandBarMatches(
      [
        for (final entry in entries)
          if (typed || !entry.searchOnly) entry,
      ],
      query,
      fuzzy: behavior.fuzzyMatch,
    );
    final matches = [for (final match in scored) match.entry];
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
    if (behavior.sortSectionsByMatch && typed && query.filter == null) {
      // Best rank of each section; the app order breaks ties (stable sort).
      final best = <String, int>{};
      for (final match in scored) {
        final section = match.entry.section;
        final rank = best[section];
        if (rank == null || match.rank < rank) best[section] = match.rank;
      }
      final position = {for (var i = 0; i < order.length; i++) order[i]: i};
      order.sort((a, b) {
        final byRank = (best[a] ?? 1 << 30).compareTo(best[b] ?? 1 << 30);
        return byRank != 0 ? byRank : position[a]!.compareTo(position[b]!);
      });
    }
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
    final text = query.text.trim();
    if (text.isNotEmpty) {
      final actions = [
        for (final entry in queryActions)
          if (query.filter?.matches(entry) ?? true) entry.withQuery(text),
      ];
      if (actions.isNotEmpty) {
        rows.add(_HeaderRow(widget.strings.queryActionsSection));
        actions.forEach(addItem);
      }
    }
    // A restored search keeps the history in view, after its matches.
    if (_restoredUntouched) addQueryHistory();
    return _BarLayout(rows: rows, items: items, rowOfItem: rowOfItem);
  }

  Widget _wrapFooter(BuildContext context, Widget footer) =>
      widget.footerBuilder?.call(context, footer) ?? footer;

  /// Opens [CommandBarView.appMenu] above the ≡ button at [anchor].
  Future<void> _openAppMenu(BuildContext anchor) async {
    final menu = widget.appMenu;
    if (menu == null) return;
    final id = await showShipglowsMenu(
      anchor,
      menu: menu,
      preferAbove: true,
      strings: widget.strings.menu,
    );
    if (!mounted) return;
    if (id == null) {
      _searchFocus.requestFocus();
      return;
    }
    widget.onChoose(CommandBarChoice(id: id, appMenu: true));
  }

  Widget _list(_BarLayout layout, int highlight, bool showNumbers) {
    final strings = widget.strings;
    final behavior = widget.behavior;
    final list = ListView.builder(
      controller: _scroll,
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: layout.rows.length,
      itemBuilder: (context, row) => KeyedSubtree(
        key: _keyOfRow(row),
        child: switch (layout.rows[row]) {
          _HeaderRow(:final title) => _SectionHeader(title),
          _EntryRow(:final entry, :final itemIndex) => CommandBarTile(
            entry: entry,
            showKind: behavior.showEntryKinds,
            kindDisplay: behavior.kindDisplay,
            kindLabel: strings.entryKinds[entry.kind?.id],
            kindText:
                strings.entryKindLabels[entry.kind?.id] ??
                strings.entryKinds[entry.kind?.id],
            compact: behavior.compactRows,
            highlighted: itemIndex == highlight,
            // A row with its own shortcut shows that one only: two near
            // identical keycaps would read as a duplicate.
            number:
                showNumbers &&
                    itemIndex < _numberedRows &&
                    entry.shortcuts.isEmpty
                ? itemIndex + 1
                : null,
            onTap: () => _chooseItem(itemIndex, secondary: false),
            onSecondaryTap: entry.hasActions
                ? () => _toggleActions(itemIndex)
                : null,
            onHover: (hovering) {
              if (hovering) {
                _hoveredItem.value = itemIndex;
              } else if (_hoveredItem.value == itemIndex) {
                _hoveredItem.value = null;
              }
            },
            actionsButton: entry.hasActions
                ? ValueListenableBuilder<int?>(
                    valueListenable: _hoveredItem,
                    builder: (context, hovered, _) => _ActionsButton(
                      visible: itemIndex == highlight || hovered == itemIndex,
                      tooltip: strings.actionsPanel.replaceAll(
                        '{label}',
                        entry.label,
                      ),
                      onPressed: () => _toggleActions(itemIndex),
                    ),
                  )
                : null,
          ),
        },
      ),
    );
    // The panel is anchored to its row: it closes once the list moves.
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (_) {
        if (_actionsOpen) _closeActions();
        return false;
      },
      child: list,
    );
  }

  /// What the panel says under the entry's label: its section, then its
  /// state and subtitle.
  String? _panelSubtitle(CommandBarEntry entry) {
    String? section;
    for (final candidate in widget.sections) {
      if (candidate.id == entry.section) section = candidate.title;
    }
    final parts = [?section, ?entry.badge, ?entry.subtitle];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Lays [panel] out next to its row, or at the end of the list when the
  /// row could not be measured.
  Widget _placePanel(BuildContext context, Widget panel) {
    final anchor = _panelAnchor;
    if (anchor == null) {
      return Align(alignment: AlignmentDirectional.bottomEnd, child: panel);
    }
    return CustomSingleChildLayout(
      delegate: CommandBarActionsPanelLayout(
        anchor: anchor,
        textDirection: Directionality.of(context),
      ),
      child: panel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = CommandBarThemeData.of(context);
    final textTheme = Theme.of(context).textTheme;
    final strings = widget.strings;

    final layout = _layoutFor();
    _layout = layout;
    final highlight = _effectiveHighlight;
    final filter = _filter;
    final showNumbers =
        MediaQuery.sizeOf(context).width >= _numberedRowsMinWidth;
    final highlighted = layout.items.isEmpty ? null : layout.items[highlight];
    final panelActions = _actionsOpen && highlighted != null
        ? _panelActions(highlighted)
        : const <CommandBarPanelLine>[];
    final panelSubtitle = highlighted == null
        ? null
        : _panelSubtitle(highlighted);

    return Focus(
      onKeyEvent: (node, event) => _onKeyEvent(event, style.rowMinHeight),
      child: Column(
        mainAxisSize: widget.fillHeight ? MainAxisSize.max : MainAxisSize.min,
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
                child: Listener(
                  onPointerDown: _onSearchPointerDown,
                  onPointerMove: _onSearchPointerMove,
                  onPointerUp: _onSearchPointerEnd,
                  onPointerCancel: _onSearchPointerEnd,
                  child: TextField(
                    controller: _controller,
                    focusNode: _searchFocus,
                    autofocus: widget.autofocus,
                    onChanged: _onChanged,
                    style: textTheme.bodyLarge?.copyWith(
                      color: style.textColor,
                    ),
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
              ),
            ],
          ),
          Divider(height: 1, color: style.borderColor),
          if (widget.filters.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: _FilterRow(
                filters: widget.filters,
                active: filter,
                strings: strings,
                onApply: _applyFilter,
                onClear: _clearFilter,
              ),
            ),
          Flexible(
            fit: widget.fillHeight ? FlexFit.tight : FlexFit.loose,
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
                : Stack(
                    key: _listKey,
                    fit: StackFit.passthrough,
                    children: [
                      ConstrainedBox(
                        // The panel needs room even over a short list.
                        constraints: BoxConstraints(
                          minHeight: panelActions.isEmpty
                              ? 0
                              : CommandBarActionsPanel.heightFor(
                                  panelActions,
                                ),
                        ),
                        child: _list(layout, highlight, showNumbers),
                      ),
                      if (panelActions.isNotEmpty)
                        Positioned.fill(
                          child: _placePanel(
                            context,
                            CommandBarActionsPanel(
                              title: highlighted!.label,
                              subtitle: panelSubtitle,
                              lines: panelActions,
                              confirmLabel: strings.confirmAction,
                              strings: strings.menu,
                              onChoose: _choosePanelAction,
                              onDismiss: _closeActions,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          Divider(height: 1, color: style.borderColor),
          _wrapFooter(
            context,
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                widget.appMenu == null ? 16 : 6,
                widget.appMenu == null ? 8 : 2,
                16,
                widget.appMenu == null ? 8 : 2,
              ),
              child: Row(
                children: [
                  if (widget.appMenu != null) ...[
                    Builder(
                      builder: (anchor) => IconButton(
                        onPressed: () => unawaited(_openAppMenu(anchor)),
                        tooltip: strings.menu.button,
                        iconSize: 18,
                        visualDensity: VisualDensity.compact,
                        color: style.mutedColor,
                        icon: const Icon(Icons.menu_rounded),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: ExcludeSemantics(
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _FooterHint(
                            keys: const ['↑', '↓'],
                            label: strings.navigate,
                          ),
                          if (widget.filters.isNotEmpty)
                            _FooterHint(
                              keys: const ['←', '→'],
                              label: strings.switchFilter,
                            ),
                          _FooterHint(
                            keys: const ['Enter'],
                            label: highlighted?.primaryLabel ?? strings.open,
                          ),
                          if (highlighted != null && highlighted.hasSecondary)
                            _FooterHint(
                              keys: const ['Shift', 'Enter'],
                              label:
                                  highlighted.secondaryLabel ??
                                  strings.secondary,
                            ),
                          if (highlighted != null && highlighted.hasActions)
                            _FooterHint(
                              keys: const ['Alt', 'Enter'],
                              label: strings.actions,
                            ),
                          _FooterHint(
                            keys: const ['Esc'],
                            label: strings.close,
                          ),
                        ],
                      ),
                    ),
                  ),
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
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: style.mutedColor, fontWeight: FontWeight.w600),
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
    this.showKind = false,
    this.kindLabel,
    this.kindDisplay = CommandBarKindDisplay.icon,
    this.kindText,
    this.compact = false,
    this.onSecondaryTap,
    this.onHover,
    this.actionsButton,
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

  /// Whether the row shows the marker of its [CommandBarEntry.kind].
  final bool showKind;

  /// What the kind does ([CommandBarStrings.entryKinds]): the marker's
  /// tooltip, read aloud with the row.
  final String? kindLabel;

  /// Whether the kind shows as its icon, its [kindText] or both.
  final CommandBarKindDisplay kindDisplay;

  /// Short name of the kind ([CommandBarStrings.entryKindLabels]), written
  /// at the end of the row unless [kindDisplay] is
  /// [CommandBarKindDisplay.icon].
  final String? kindText;

  /// Whether the subtitle follows the label on the same line
  /// ([CommandBarBehavior.compactRows]). A disabled row keeps its reason on
  /// a second line.
  final bool compact;

  /// Called on tap, unless the entry is disabled.
  final VoidCallback onTap;

  /// Called on a right-click, even on a disabled entry: the bar opens the
  /// row's actions panel. Null when the row has none.
  final VoidCallback? onSecondaryTap;

  /// Called when the mouse enters or leaves the row.
  final ValueChanged<bool>? onHover;

  /// Shown at the end of the row, such as the bar's « … » button that opens
  /// the row's actions panel.
  final Widget? actionsButton;

  @override
  Widget build(BuildContext context) {
    final style = CommandBarThemeData.of(context);
    final textTheme = Theme.of(context).textTheme;
    final disabled = !entry.enabled;
    // A disabled row explains why in its second line; otherwise the subtitle,
    // on the label's line when compact.
    final secondLine = disabled ? entry.disabledReason : entry.subtitle;
    final inlineSubtitle = compact && !disabled ? entry.subtitle : null;
    final belowLine = inlineSubtitle == null ? secondLine : null;
    final trailingLabel = this.trailingLabel;
    final badge = entry.badge;
    final kind = showKind ? entry.kind : null;
    final kindLabel = kind == null ? null : this.kindLabel;
    final kindText = kind == null || kindDisplay == CommandBarKindDisplay.icon
        ? null
        : this.kindText ?? kindLabel;
    final kindIcon = kind != null && kindDisplay != CommandBarKindDisplay.label;
    final mutedSmall = textTheme.labelSmall?.copyWith(color: style.mutedColor);
    final labelStyle = textTheme.bodyMedium?.copyWith(
      color: disabled ? style.mutedColor : style.textColor,
      fontWeight: highlighted ? FontWeight.w600 : FontWeight.w500,
    );
    final spoken = [
      entry.label,
      ?badge,
      ?secondLine,
      ?kindLabel,
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
          onSecondaryTap: onSecondaryTap,
          onHover: onHover,
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
                              // One text: the label keeps its room, the
                              // subtitle after it is cut first.
                              child: Text.rich(
                                TextSpan(
                                  text: entry.label,
                                  style: labelStyle,
                                  children: [
                                    if (inlineSubtitle != null)
                                      TextSpan(
                                        text: '   $inlineSubtitle',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: style.mutedColor,
                                        ),
                                      ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (badge != null) ...[
                              const SizedBox(width: 8),
                              _Badge(badge),
                            ],
                          ],
                        ),
                        if (belowLine != null)
                          Text(
                            belowLine,
                            // The reason a row is disabled is never cut short.
                            maxLines: disabled ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: mutedSmall,
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
                  if (kind != null) ...[
                    const SizedBox(width: 8),
                    _KindMarker(
                      icon: kindIcon ? kind.icon : null,
                      text: kindText,
                      tooltip: kindLabel,
                      style: mutedSmall,
                      color: style.mutedColor,
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
                  if (actionsButton case final button?) ...[
                    const SizedBox(width: 4),
                    button,
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

/// The filter row: « All », then one button per filter, the active one
/// highlighted. Left and Right step through it from the edges of the field.
class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.filters,
    required this.active,
    required this.strings,
    required this.onApply,
    required this.onClear,
  });

  final List<CommandBarFilter> filters;
  final CommandBarFilter? active;
  final CommandBarStrings strings;
  final ValueChanged<CommandBarFilter> onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterButton(
            label: strings.allFilters,
            selected: active == null,
            onPressed: onClear,
          ),
          for (final filter in filters) ...[
            const SizedBox(width: 4),
            _FilterButton(
              label: filter.label,
              prefix: filter.prefix == ' ' ? strings.spaceKey : filter.prefix,
              tooltip:
                  (filter.requiresSpace
                          ? strings.prefixTooltip
                          : strings.prefixTooltipNoSpace)
                      .replaceAll(
                        '{prefix}',
                        filter.prefix == ' ' ? strings.spaceKey : filter.prefix,
                      ),
              selected: active?.prefix == filter.prefix,
              onPressed: () => onApply(filter),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.prefix,
    this.tooltip,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  /// The prefix that applies the filter when typed, written before the
  /// label in the button's text (« c Presse-papiers »).
  final String? prefix;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final style = CommandBarThemeData.of(context);
    final prefix = this.prefix;
    // One keycap like the footer's, holding the prefix then the label; the
    // active one is fully opaque, like the highlighted row's number.
    final button = Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Opacity(
              opacity: selected ? 1 : 0.5,
              child: style.keycapBuilder(
                context,
                prefix == null ? label : '$prefix $label',
              ),
            ),
          ),
        ),
      ),
    );
    final tooltip = this.tooltip;
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
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
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: style.mutedColor),
      ),
    );
  }
}

/// The « … » button at the end of a row, which opens its actions panel.
/// It keeps its room when hidden, so the row never shifts.
class _ActionsButton extends StatelessWidget {
  const _ActionsButton({
    required this.visible,
    required this.tooltip,
    required this.onPressed,
  });

  final bool visible;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final style = CommandBarThemeData.of(context);
    return Visibility(
      visible: visible,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: SizedBox.square(
        dimension: 28,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          iconSize: 18,
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(style.rowRadius),
            ),
          ),
          icon: Icon(Icons.more_horiz_rounded, color: style.iconColor),
        ),
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
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: style.mutedColor),
        ),
      ],
    );
  }
}

/// The kind of a row at its end: icon, short text, or both, with the long
/// description as tooltip.
class _KindMarker extends StatelessWidget {
  const _KindMarker({
    required this.icon,
    required this.text,
    required this.tooltip,
    required this.style,
    required this.color,
  });

  final IconData? icon;
  final String? text;
  final String? tooltip;
  final TextStyle? style;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    final text = this.text;
    final marker = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) Icon(icon, size: 16, color: color),
        if (icon != null && text != null) const SizedBox(width: 4),
        if (text != null) Text(text, maxLines: 1, style: style),
      ],
    );
    final tooltip = this.tooltip;
    // The text already says it: the tooltip only explains a lone icon.
    if (tooltip == null || (text != null && text == tooltip)) return marker;
    return Tooltip(message: tooltip, child: marker);
  }
}
