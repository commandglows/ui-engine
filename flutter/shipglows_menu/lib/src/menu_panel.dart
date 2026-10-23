import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'app_menu.dart';
import 'menu_icons.dart';
import 'menu_items.dart';
import 'menu_search.dart';
import 'menu_theme.dart';

/// The action list itself: an optional title line, titled groups, shortcut
/// keys on the right and a « Rechercher une action… » field that filters
/// as you type (accents and case ignored).
///
/// Keyboard: ↑/↓ move, Enter chooses, → or Enter opens a submenu, ← or
/// Backspace (empty search) goes back up, Escape goes back up then calls
/// [onDismiss] — the event stops here, so Escape never reaches the window.
///
/// `showShipglowsMenu` shows it floating next to a widget; use the panel
/// directly to embed it.
class ShipglowsMenuPanel extends StatefulWidget {
  const ShipglowsMenuPanel({
    super.key,
    required this.menu,
    required this.onSelected,
    this.onDismiss,
    this.strings = ShipglowsMenuStrings.fr,
    this.showSearch = true,
    this.autofocus = true,
    this.icons,
  });

  final ShipglowsMenu menu;

  /// An enabled action was chosen. Its `onSelected` is left to the caller.
  final ValueChanged<ShipglowsMenuAction> onSelected;

  /// Escape at the top level.
  final VoidCallback? onDismiss;

  final ShipglowsMenuStrings strings;

  /// Whether the search field shows; typing filters only with it.
  final bool showSearch;

  /// Takes the keyboard when shown.
  final bool autofocus;

  /// Flutter icons by `ShipglowsMenuIcon.name`, over the theme's
  /// [ShipglowsMenuTheme.icons]: for actions built at run time from
  /// `IconData` (`ShipglowsMenuIcon.named('row.copy')`).
  final Map<String, IconData>? icons;

  @override
  State<ShipglowsMenuPanel> createState() => _ShipglowsMenuPanelState();
}

sealed class _Row {
  const _Row();

  bool get selectable => false;
}

final class _HeaderRow extends _Row {
  const _HeaderRow(this.label);

  final String label;
}

final class _SeparatorRow extends _Row {
  const _SeparatorRow();
}

final class _ActionRow extends _Row {
  const _ActionRow(this.action);

  final ShipglowsMenuAction action;

  @override
  bool get selectable => action.enabled;
}

final class _SubmenuRow extends _Row {
  const _SubmenuRow(this.submenu);

  final ShipglowsMenuSubmenu submenu;

  @override
  bool get selectable => submenu.enabled;
}

class _ShipglowsMenuPanelState extends State<ShipglowsMenuPanel> {
  final _query = TextEditingController();
  late final _focus = FocusNode(
    debugLabel: 'ShipglowsMenuPanel',
    onKeyEvent: _onKey,
  );
  final _levels = <ShipglowsMenuSubmenu>[];
  final _rowKeys = <int, GlobalKey>{};
  List<_Row> _rows = const [];
  int _highlighted = -1;

  /// Row showing its [ShipglowsMenuAction.confirmLabel], waiting for a
  /// second choice.
  int? _confirming;

  @override
  void initState() {
    super.initState();
    _query.addListener(_onQueryChanged);
    _rebuildRows();
    // Embedded next to a field that has the focus, autofocus alone would
    // leave it there.
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(ShipglowsMenuPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.menu, widget.menu)) {
      _levels.clear();
      _rebuildRows();
    }
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<ShipglowsMenuItem> get _levelItems =>
      _levels.isEmpty ? widget.menu.items : _levels.last.items;

  void _onQueryChanged() => setState(_rebuildRows);

  void _rebuildRows() {
    final query = _query.text;
    final rows = <_Row>[];
    if (query.trim().isEmpty) {
      for (final item in normalizeShipglowsMenuSeparators(_levelItems)) {
        rows.add(switch (item) {
          ShipglowsMenuAction() => _ActionRow(item),
          ShipglowsMenuSeparator() => const _SeparatorRow(),
          ShipglowsMenuHeader(:final label) => _HeaderRow(label),
          ShipglowsMenuSubmenu() => _SubmenuRow(item),
        });
      }
    } else {
      String? group;
      for (final result in searchShipglowsMenu(_levelItems, query)) {
        final title = [...result.path, ?result.header].join(' › ');
        if (title != group && title.isNotEmpty) rows.add(_HeaderRow(title));
        group = title;
        rows.add(_ActionRow(result.action));
      }
    }
    _rows = rows;
    _rowKeys.clear();
    _highlighted = rows.indexWhere((row) => row.selectable);
    _confirming = null;
  }

  void _move(int step) {
    if (_rows.isEmpty) return;
    var index = _highlighted;
    for (var tries = 0; tries < _rows.length; tries++) {
      index = (index + step) % _rows.length;
      if (index < 0) index += _rows.length;
      if (_rows[index].selectable) {
        setState(() {
          _highlighted = index;
          _confirming = null;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(index));
        return;
      }
    }
  }

  void _reveal(int index) {
    final context = _rowKeys[index]?.currentContext;
    if (context == null || !context.mounted) return;
    Scrollable.ensureVisible(
      context,
      duration: Duration.zero,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
    Scrollable.ensureVisible(
      context,
      duration: Duration.zero,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    );
  }

  void _activate(int index) {
    if (index < 0 || index >= _rows.length) return;
    switch (_rows[index]) {
      case _ActionRow(:final action)
          when action.enabled &&
              action.confirmLabel != null &&
              _confirming != index:
        setState(() {
          _highlighted = index;
          _confirming = index;
        });
      case _ActionRow(:final action) when action.enabled:
        widget.onSelected(action);
      case _SubmenuRow(:final submenu) when submenu.enabled:
        _enter(submenu);
      case _ActionRow() || _SubmenuRow() || _HeaderRow() || _SeparatorRow():
        break;
    }
  }

  void _enter(ShipglowsMenuSubmenu submenu) {
    _levels.add(submenu);
    _resetLevel();
  }

  bool _back() {
    if (_levels.isEmpty) return false;
    _levels.removeLast();
    _resetLevel();
    return true;
  }

  void _resetLevel() {
    if (_query.text.isEmpty) {
      setState(_rebuildRows);
    } else {
      _query.clear(); // Rebuilds through the listener.
    }
    _focus.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final empty = _query.text.isEmpty;
    if (key == LogicalKeyboardKey.arrowDown) {
      _move(1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _move(-1);
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _activate(_highlighted);
    } else if (key == LogicalKeyboardKey.escape) {
      if (!_back()) widget.onDismiss?.call();
    } else if (key == LogicalKeyboardKey.arrowRight && empty) {
      final row = _highlighted < 0 ? null : _rows[_highlighted];
      if (row is! _SubmenuRow) return KeyEventResult.ignored;
      _activate(_highlighted);
    } else if ((key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.backspace) &&
        empty) {
      if (!_back()) return KeyEventResult.ignored;
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final style = ResolvedShipglowsMenuTheme.of(context);
    final menu = widget.menu;
    final level = _levels.isEmpty ? null : _levels.last;
    final title = level?.label ?? menu.title;
    final subtitle = level == null ? menu.subtitle : null;
    final panel = Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: title ?? widget.strings.button,
      child: Material(
        type: MaterialType.transparency,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: style.backgroundColor,
            borderRadius: BorderRadius.circular(style.radius),
            border: Border.all(color: style.borderColor),
            boxShadow: style.shadows,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(style.radius),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null)
                  _TitleBar(
                    title: title,
                    subtitle: subtitle,
                    onBack: level == null ? null : _back,
                    strings: widget.strings,
                    style: style,
                  ),
                if (title != null) Divider(height: 1, color: style.borderColor),
                Flexible(child: _list(style)),
                if (widget.showSearch) ...[
                  Divider(height: 1, color: style.borderColor),
                  _search(style),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    if (widget.showSearch) return panel;
    // Without the field, the panel itself takes the keys.
    return Focus(focusNode: _focus, autofocus: widget.autofocus, child: panel);
  }

  Widget _list(ResolvedShipglowsMenuTheme style) {
    if (_rows.isEmpty) {
      return Semantics(
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(
            widget.strings.noResults,
            style: style.labelStyle.copyWith(color: style.mutedColor),
          ),
        ),
      );
    }
    // Built whole (menus are short) so any row can be scrolled to.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, row) in _rows.indexed) _row(index, row, style),
        ],
      ),
    );
  }

  Widget _row(int index, _Row row, ResolvedShipglowsMenuTheme style) {
    final icons = widget.icons == null
        ? style.icons
        : {...?style.icons, ...widget.icons!};
    switch (row) {
      case _SeparatorRow():
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Divider(height: 1, color: style.borderColor),
        );
      case _HeaderRow(:final label):
        return Semantics(
          header: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Text(
              label,
              style: style.labelStyle.copyWith(
                color: style.mutedColor,
                fontSize: (style.labelStyle.fontSize ?? 14) * 0.86,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      case _ActionRow(:final action):
        final danger = action.destructive
            ? Theme.of(context).colorScheme.error
            : null;
        return _Tile(
          key: _rowKeys.putIfAbsent(index, GlobalKey.new),
          label: index == _confirming
              ? action.confirmLabel ?? action.label
              : action.label,
          color: danger,
          icon: action.checked
              ? Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: style.foregroundColor,
                )
              : action.icon == null
              ? null
              : ShipglowsMenuIconView(
                  action.icon!,
                  color: action.enabled
                      ? danger ?? style.foregroundColor
                      : style.mutedColor,
                  overrides: icons,
                ),
          shortcut: action.shortcut,
          bold: action.isDefault,
          enabled: action.enabled,
          checked: action.checked ? true : null,
          highlighted: index == _highlighted,
          style: style,
          onHover: () => setState(() {
            if (_highlighted != index) _confirming = null;
            _highlighted = index;
          }),
          onTap: () => _activate(index),
        );
      case _SubmenuRow(:final submenu):
        return _Tile(
          key: _rowKeys.putIfAbsent(index, GlobalKey.new),
          label: submenu.label,
          icon: submenu.icon == null
              ? null
              : ShipglowsMenuIconView(
                  submenu.icon!,
                  color: style.foregroundColor,
                  overrides: icons,
                ),
          trailing: Icon(
            Directionality.of(context) == TextDirection.rtl
                ? Icons.chevron_left_rounded
                : Icons.chevron_right_rounded,
            size: 18,
            color: style.mutedColor,
          ),
          enabled: submenu.enabled,
          highlighted: index == _highlighted,
          style: style,
          onHover: () => setState(() => _highlighted = index),
          onTap: () => _activate(index),
        );
    }
  }

  Widget _search(ResolvedShipglowsMenuTheme style) => ConstrainedBox(
    constraints: BoxConstraints(minHeight: style.rowHeight),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.search_rounded,
              size: 18,
              color: style.mutedColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _query,
              focusNode: _focus,
              autofocus: widget.autofocus,
              style: style.labelStyle,
              cursorColor: style.foregroundColor,
              textInputAction: TextInputAction.done,
              // Enter is handled as a key; keep the focus.
              onEditingComplete: () {},
              decoration: InputDecoration.collapsed(
                hintText: widget.strings.searchHint,
                hintStyle: style.labelStyle.copyWith(color: style.mutedColor),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.strings,
    required this.style,
  });

  final String title;
  final String? subtitle;
  final bool Function()? onBack;
  final ShipglowsMenuStrings strings;
  final ResolvedShipglowsMenuTheme style;

  @override
  Widget build(BuildContext context) {
    final back = onBack;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: style.rowHeight),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: back == null ? 16 : 0,
          end: 16,
        ),
        child: Row(
          children: [
            if (back != null)
              IconButton(
                onPressed: back,
                tooltip: strings.back,
                iconSize: 18,
                color: style.mutedColor,
                icon: const BackButtonIcon(),
              ),
            Expanded(
              child: Semantics(
                header: true,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        TextSpan(
                          text: '  $subtitle',
                          style: TextStyle(color: style.mutedColor),
                        ),
                    ],
                  ),
                  style: style.labelStyle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.label,
    required this.icon,
    required this.enabled,
    required this.highlighted,
    required this.style,
    required this.onHover,
    required this.onTap,
    this.shortcut,
    this.trailing,
    this.bold = false,
    this.checked,
    this.color,
  });

  final String label;
  final Widget? icon;

  /// Label color of an enabled row; the theme's foreground when null.
  final Color? color;
  final String? shortcut;
  final Widget? trailing;
  final bool bold;
  final bool enabled;
  final bool? checked;
  final bool highlighted;
  final ResolvedShipglowsMenuTheme style;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final keys = shortcut == null ? const <String>[] : _keys(shortcut!);
    final color = enabled
        ? this.color ?? style.foregroundColor
        : style.mutedColor;
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      selected: highlighted,
      checked: checked,
      label: label,
      value: keys.isEmpty ? null : keys.join(' + '),
      onTap: enabled ? onTap : null,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: enabled ? (_) => onHover() : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: Container(
            constraints: BoxConstraints(minHeight: style.rowHeight),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: highlighted && enabled ? style.highlightColor : null,
              borderRadius: BorderRadius.circular(style.rowRadius),
            ),
            child: Row(
              children: [
                SizedBox.square(dimension: 20, child: Center(child: icon)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: style.labelStyle.copyWith(
                      color: color,
                      fontWeight: bold ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                if (keys.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  for (final (index, key) in keys.indexed) ...[
                    if (index > 0) const SizedBox(width: 4),
                    _Keycap(key, style: style),
                  ],
                ],
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// `Ctrl+Alt+K` as `[Ctrl, Alt, K]`; a trailing `++` is the `+` key.
  static List<String> _keys(String shortcut) {
    final plusKey = shortcut.endsWith('++');
    final body = plusKey
        ? shortcut.substring(0, shortcut.length - 2)
        : shortcut;
    return [
      for (final part in body.split('+'))
        if (part.trim().isNotEmpty) part.trim(),
      if (plusKey) '+',
    ];
  }
}

/// The shared [ShipglowsKeycap], so the menu's keys look like every other
/// key of the app; the menu theme only recolors it.
class _Keycap extends StatelessWidget {
  const _Keycap(this.label, {required this.style});

  final String label;
  final ResolvedShipglowsMenuTheme style;

  @override
  Widget build(BuildContext context) => ShipglowsKeycap(
    label,
    backgroundColor: style.keycapColor,
    foregroundColor: style.keycapForegroundColor,
  );
}
