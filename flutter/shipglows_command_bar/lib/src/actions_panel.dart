import 'package:flutter/material.dart';
import 'package:shipglows_menu/shipglows_menu.dart';

import 'command.dart';

/// One line of the actions panel: Enter, Shift+Enter or one of the
/// [CommandBarEntry.actions].
@immutable
class CommandBarPanelLine {
  const CommandBarPanelLine({
    required this.label,
    this.icon,
    this.group,
    this.shortcut,
    this.secondary = false,
    this.action,
    this.destructive = false,
    this.confirm = false,
  });

  final String label;
  final IconData? icon;

  /// Title of the group the line opens or continues
  /// ([CommandBarEntryAction.group]); lines without one come first.
  final String? group;

  /// Keys shown on the right (`Shift+↵`, `Ctrl+Shift+C`).
  final String? shortcut;

  /// Whether the line is Shift+Enter.
  final bool secondary;

  /// Id of the [CommandBarEntryAction]; null for Enter and Shift+Enter.
  final String? action;

  /// Whether the line is listed last, after a separator, in the error color
  /// ([CommandBarEntryAction.destructive]).
  final bool destructive;

  /// Whether choosing the line asks for a second press first
  /// ([CommandBarEntryAction.confirm]).
  final bool confirm;
}

/// Places the actions panel against the end of the row it belongs to, its
/// top level with the row's, kept inside the list.
class CommandBarActionsPanelLayout extends SingleChildLayoutDelegate {
  CommandBarActionsPanelLayout({
    required this.anchor,
    required this.textDirection,
  });

  /// The row, in the coordinates of the area the panel is laid out in.
  final Rect anchor;
  final TextDirection textDirection;

  /// Room left at the end of the row, so its « … » button stays visible.
  static const double _endInset = 40;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final maxX = (size.width - childSize.width).clamp(0.0, double.infinity);
    final maxY = (size.height - childSize.height).clamp(0.0, double.infinity);
    final x = textDirection == TextDirection.rtl
        ? anchor.left + _endInset
        : anchor.right - _endInset - childSize.width;
    // The panel has its own margin: its card lines up with the row.
    final y = anchor.top - CommandBarActionsPanel.margin;
    return Offset(x.clamp(0.0, maxX), y.clamp(0.0, maxY));
  }

  @override
  bool shouldRelayout(CommandBarActionsPanelLayout oldDelegate) =>
      oldDelegate.anchor != anchor ||
      oldDelegate.textDirection != textDirection;
}

/// The actions of the highlighted row, next to it: the shared action menu
/// (`shipglows_menu`), titled with the entry, its search field taking the
/// keyboard. Destructive lines come last after a separator, in the error
/// color; a line that [CommandBarPanelLine.confirm]s asks for a second
/// press.
class CommandBarActionsPanel extends StatelessWidget {
  const CommandBarActionsPanel({
    super.key,
    required this.title,
    required this.lines,
    required this.onChoose,
    required this.onDismiss,
    required this.strings,
    this.subtitle,
    this.confirmLabel,
  });

  /// Space around the card.
  static const double margin = 8;

  static const double _width = 300;

  /// Room the panel takes with [lines], margin included, as the shared
  /// menu lays them out (44 px rows, title and search lines).
  static double heightFor(List<CommandBarPanelLine> lines) {
    const row = 44.0;
    var groups = 0;
    String? previous;
    for (final line in lines) {
      final group = line.destructive ? null : line.group;
      if (group != null && group != previous) groups++;
      previous = group;
    }
    final separated =
        lines.any((line) => line.destructive) &&
        lines.any((line) => !line.destructive);
    final list =
        lines.length * row + groups * (row + 9) + (separated ? 9 : 0) + 12;
    final body = row + (list > 6 * row ? 6 * row : list) + row + 2;
    return body + 2 * margin;
  }

  /// The entry's label.
  final String title;

  /// What the entry is, dimmed after [title] (« Snippet · Pinned »).
  final String? subtitle;

  /// Lines in display order: the destructive ones last.
  final List<CommandBarPanelLine> lines;

  /// Label of a confirming line while it waits for its second press.
  final String? confirmLabel;

  final ShipglowsMenuStrings strings;
  final ValueChanged<CommandBarPanelLine> onChoose;

  /// Escape: the panel closes, the bar stays.
  final VoidCallback onDismiss;

  static const String _iconPrefix = 'commandBar.line.';

  ShipglowsMenu _menu() {
    final items = <ShipglowsMenuItem>[];
    String? previous;
    var separated = false;
    for (final (index, line) in lines.indexed) {
      if (line.destructive && !separated) {
        separated = true;
        items.add(const ShipglowsMenuSeparator());
      }
      final group = line.destructive ? null : line.group;
      if (group != null && group != previous) {
        items
          ..add(const ShipglowsMenuSeparator())
          ..add(ShipglowsMenuHeader(group));
      }
      previous = group;
      items.add(
        ShipglowsMenuAction(
          '$index',
          line.label,
          icon: line.icon == null
              ? null
              : ShipglowsMenuIcon.named('$_iconPrefix$index'),
          shortcut: line.shortcut,
          isDefault: index == 0 && !line.secondary && line.action == null,
          destructive: line.destructive,
          confirmLabel: line.confirm ? confirmLabel : null,
        ),
      );
    }
    return ShipglowsMenu(title: title, subtitle: subtitle, items: items);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(margin),
    child: SizedBox(
      width: _width,
      child: ShipglowsMenuPanel(
        menu: _menu(),
        strings: strings,
        icons: {
          for (final (index, line) in lines.indexed)
            if (line.icon case final icon?) '$_iconPrefix$index': icon,
        },
        onSelected: (action) {
          final index = int.tryParse(action.id);
          if (index != null && index < lines.length) onChoose(lines[index]);
        },
        onDismiss: onDismiss,
      ),
    ),
  );
}
