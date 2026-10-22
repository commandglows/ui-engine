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
    required this.keys,
    this.icon,
    this.group,
    this.secondary = false,
    this.action,
  });

  final String label;
  final IconData? icon;

  /// Keycaps shown at the end of the line; empty without a shortcut.
  final List<String> keys;

  /// Title of the group the line opens or continues
  /// ([CommandBarEntryAction.group]); lines without one come first.
  final String? group;

  /// Whether the line is Shift+Enter.
  final bool secondary;

  /// Id of the [CommandBarEntryAction]; null for Enter and Shift+Enter.
  final String? action;
}

/// The actions of the highlighted row, over the end of the list: a title,
/// then its lines grouped by [CommandBarPanelLine.group], with their
/// shortcuts. Keyboard handling stays with the bar.
class CommandBarActionsPanel extends StatelessWidget {
  const CommandBarActionsPanel({
    super.key,
    required this.title,
    required this.lines,
    required this.highlight,
    required this.onChoose,
  });

  static const double _rowHeight = 36;
  static const double _headerHeight = 26;
  static const double _titleHeight = 32;
  static const double _maxListHeight = 8 * _rowHeight;
  static const double _margin = 8;

  /// Room the panel takes with [lines], margin included.
  static double heightFor(List<CommandBarPanelLine> lines) {
    final list = lines.length * _rowHeight + _groups(lines) * _headerHeight;
    return _titleHeight +
        (list > _maxListHeight ? _maxListHeight : list) +
        4 +
        2 * _margin;
  }

  /// Number of group titles [lines] show.
  static int _groups(List<CommandBarPanelLine> lines) {
    var count = 0;
    String? previous;
    for (final line in lines) {
      final group = line.group;
      if (group != null && group != previous) count++;
      previous = group;
    }
    return count;
  }

  final String title;
  final List<CommandBarPanelLine> lines;

  /// Index in [lines] of the line Enter chooses.
  final int highlight;
  final ValueChanged<CommandBarPanelLine> onChoose;

  @override
  Widget build(BuildContext context) {
    final style = CommandBarThemeData.of(context);
    final textTheme = Theme.of(context).textTheme;
    final headerStyle = textTheme.labelSmall?.copyWith(
      color: style.mutedColor,
      fontWeight: FontWeight.w600,
    );
    final children = <Widget>[];
    String? previous;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final group = line.group;
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
          highlighted: i == highlight,
          onTap: () => onChoose(line),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(_margin),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Material(
          color: style.backgroundColor,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(style.rowRadius + 4),
            side: BorderSide(color: style.borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Semantics(
            label: title,
            explicitChildNodes: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: _titleHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ExcludeSemantics(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: headerStyle,
                        ),
                      ),
                    ),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 4),
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
    required this.highlighted,
    required this.onTap,
  });

  final CommandBarPanelLine line;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = CommandBarThemeData.of(context);
    final textTheme = Theme.of(context).textTheme;
    final icon = line.icon;
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
            label: line.label,
            excludeSemantics: true,
            child: SizedBox(
              height: CommandBarActionsPanel._rowHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      child: icon == null
                          ? null
                          : Icon(
                              icon,
                              size: 16,
                              color: highlighted
                                  ? style.highlightedIconColor
                                  : style.iconColor,
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        line.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: style.textColor,
                          fontWeight: highlighted
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (line.keys.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      CommandBarKeys(keys: line.keys),
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
