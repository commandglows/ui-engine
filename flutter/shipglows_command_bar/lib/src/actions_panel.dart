import 'package:flutter/material.dart';

import 'command.dart';
import 'theme.dart';

/// One line of the actions panel: Enter, Shift+Enter or one of the
/// [CommandBarEntry.actions].
///
/// The panel only knows these lines, so it can later give way to a shared
/// floating menu without touching the bar.
@immutable
class CommandBarPanelLine {
  const CommandBarPanelLine({
    required this.label,
    this.icon,
    this.group,
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

/// The actions of the highlighted row, next to it: its title and what it
/// is, then its lines numbered 1 to 9, the destructive ones last after a
/// separator. Keyboard handling stays with the bar.
class CommandBarActionsPanel extends StatelessWidget {
  const CommandBarActionsPanel({
    super.key,
    required this.title,
    required this.lines,
    required this.highlight,
    required this.onChoose,
    this.subtitle,
    this.semanticLabel,
    this.confirming,
    this.confirmLabel = '',
  });

  static const double _rowHeight = 36;
  static const double _headerHeight = 26;
  static const double _titleHeight = 36;
  static const double _subtitleHeight = 16;
  static const double _separatorHeight = 9;
  static const double _maxListHeight = 8 * _rowHeight;

  /// Space around the card.
  static const double margin = 8;

  /// Room the panel takes with [lines], margin included.
  static double heightFor(
    List<CommandBarPanelLine> lines, {
    bool subtitle = false,
  }) {
    var list = lines.length * _rowHeight + _groups(lines) * _headerHeight;
    if (lines.any((line) => line.destructive) &&
        lines.any((line) => !line.destructive)) {
      list += _separatorHeight;
    }
    return _titleHeight +
        (subtitle ? _subtitleHeight : 0) +
        (list > _maxListHeight ? _maxListHeight : list) +
        8 +
        2 * margin;
  }

  /// Number of group titles [lines] show.
  static int _groups(List<CommandBarPanelLine> lines) {
    var count = 0;
    String? previous;
    for (final line in lines) {
      final group = line.destructive ? null : line.group;
      if (group != null && group != previous) count++;
      previous = group;
    }
    return count;
  }

  /// The entry's label.
  final String title;

  /// What the entry is, muted under [title] (« Snippet · Pinned »).
  final String? subtitle;

  /// Accessible name of the panel; [title] when null.
  final String? semanticLabel;

  /// Lines in display order: the destructive ones last.
  final List<CommandBarPanelLine> lines;

  /// Index in [lines] of the line Enter chooses.
  final int highlight;

  /// Index in [lines] of the line waiting for its second press, shown with
  /// [confirmLabel].
  final int? confirming;
  final String confirmLabel;
  final ValueChanged<CommandBarPanelLine> onChoose;

  @override
  Widget build(BuildContext context) {
    final style = CommandBarThemeData.of(context);
    final textTheme = Theme.of(context).textTheme;
    final danger = Theme.of(context).colorScheme.error;
    final headerStyle = textTheme.labelSmall?.copyWith(
      color: style.mutedColor,
      fontWeight: FontWeight.w600,
    );
    final subtitle = this.subtitle;
    final children = <Widget>[];
    String? previous;
    var separated = false;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.destructive && !separated && i > 0) {
        separated = true;
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Divider(height: 1, color: style.borderColor),
          ),
        );
      }
      final group = line.destructive ? null : line.group;
      if (group != null && group != previous) {
        children.add(
          SizedBox(
            height: _headerHeight,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 12, top: 8),
              child: Semantics(
                header: true,
                child: Text(group, maxLines: 1, style: headerStyle),
              ),
            ),
          ),
        );
      }
      previous = group;
      children.add(
        _PanelLineTile(
          line: line,
          label: i == confirming ? confirmLabel : line.label,
          number: i < 9 ? i + 1 : null,
          color: line.destructive ? danger : style.textColor,
          highlighted: i == highlight,
          onTap: () => onChoose(line),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(margin),
      child: SizedBox(
        width: 280,
        child: Material(
          color: style.backgroundColor,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(style.rowRadius + 4),
            side: BorderSide(color: style.borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Semantics(
            label: semanticLabel ?? title,
            explicitChildNodes: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            color: style.textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelSmall?.copyWith(
                              color: style.mutedColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, color: style.borderColor),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    children: children,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelLineTile extends StatelessWidget {
  const _PanelLineTile({
    required this.line,
    required this.label,
    required this.number,
    required this.color,
    required this.highlighted,
    required this.onTap,
  });

  final CommandBarPanelLine line;
  final String label;

  /// Digit that chooses the line, or null past the ninth.
  final int? number;
  final Color color;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = CommandBarThemeData.of(context);
    final textTheme = Theme.of(context).textTheme;
    final icon = line.icon;
    final number = this.number;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: highlighted ? style.highlightColor : Colors.transparent,
        borderRadius: BorderRadius.circular(style.rowRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(style.rowRadius),
          onTap: onTap,
          child: Semantics(
            button: true,
            selected: highlighted,
            label: label,
            excludeSemantics: true,
            child: SizedBox(
              height: CommandBarActionsPanel._rowHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: 16,
                        color: line.destructive
                            ? color
                            : highlighted
                            ? style.highlightedIconColor
                            : style.iconColor,
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: color,
                          fontWeight: highlighted
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (number != null) ...[
                      const SizedBox(width: 12),
                      CommandBarKeys(keys: ['$number']),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
