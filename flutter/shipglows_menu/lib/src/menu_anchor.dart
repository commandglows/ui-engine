import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_menu.dart';
import 'menu_items.dart';
import 'menu_panel.dart';
import 'menu_theme.dart';

/// Shows [menu] floating next to the widget of [context] (a button), or at
/// [position] (global, for example a right click), and returns the chosen
/// action's id, null when dismissed. The action's `onSelected` runs once
/// the menu has closed.
///
/// The menu opens below its anchor, or above it when [preferAbove] (the
/// Raycast ≡ menu at the bottom of a bar) or when the space requires.
/// Escape, a click outside or the back gesture close only the menu.
Future<String?> showShipglowsMenu(
  BuildContext context, {
  required ShipglowsMenu menu,
  Offset? position,
  Rect? anchorRect,
  bool preferAbove = false,
  bool showSearch = true,
  ShipglowsMenuStrings strings = ShipglowsMenuStrings.fr,
  bool useRootNavigator = false,
}) async {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final overlay = navigator.overlay?.context.findRenderObject();
  final Rect anchor;
  if (overlay is! RenderBox) {
    anchor = Rect.zero;
  } else if (position != null) {
    anchor = overlay.globalToLocal(position) & Size.zero;
  } else if (anchorRect != null) {
    anchor = Rect.fromPoints(
      overlay.globalToLocal(anchorRect.topLeft),
      overlay.globalToLocal(anchorRect.bottomRight),
    );
  } else {
    final box = context.findRenderObject();
    anchor = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero, ancestor: overlay) & box.size
        : Rect.zero;
  }
  final action = await navigator.push(
    _ShipglowsMenuRoute(
      menu: menu,
      anchor: anchor,
      preferAbove: preferAbove,
      showSearch: showSearch,
      strings: strings,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
    ),
  );
  action?.onSelected?.call();
  return action?.id;
}

/// Opens [menu] from the widget [builder] returns: call its `open`
/// (a button's `onPressed`), or right-click it with [openOnSecondaryTap].
class ShipglowsMenuAnchor extends StatelessWidget {
  const ShipglowsMenuAnchor({
    super.key,
    required this.menu,
    required this.builder,
    this.onSelected,
    this.openOnSecondaryTap = false,
    this.preferAbove = false,
    this.showSearch = true,
    this.strings = ShipglowsMenuStrings.fr,
  });

  final ShipglowsMenu menu;
  final Widget Function(BuildContext context, VoidCallback open) builder;

  /// The chosen action's id, after its own `onSelected`.
  final ValueChanged<String>? onSelected;

  /// A right click opens the menu at the pointer.
  final bool openOnSecondaryTap;
  final bool preferAbove;
  final bool showSearch;
  final ShipglowsMenuStrings strings;

  Future<void> _open(BuildContext context, {Offset? position}) async {
    final id = await showShipglowsMenu(
      context,
      menu: menu,
      position: position,
      preferAbove: preferAbove,
      showSearch: showSearch,
      strings: strings,
    );
    if (id != null) onSelected?.call(id);
  }

  @override
  Widget build(BuildContext context) => Builder(
    builder: (anchorContext) {
      final child = builder(anchorContext, () => _open(anchorContext));
      if (!openOnSecondaryTap) return child;
      return GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onSecondaryTapUp: (details) =>
            _open(anchorContext, position: details.globalPosition),
        child: child,
      );
    },
  );
}

/// An icon button (≡ by default; `Icons.more_horiz` for « ⋯ ») opening
/// [menu].
class ShipglowsMenuButton extends StatelessWidget {
  const ShipglowsMenuButton({
    super.key,
    required this.menu,
    this.onSelected,
    this.icon = const Icon(Icons.menu_rounded),
    this.tooltip,
    this.preferAbove = false,
    this.showSearch = true,
    this.strings = ShipglowsMenuStrings.fr,
  });

  final ShipglowsMenu menu;
  final ValueChanged<String>? onSelected;
  final Widget icon;

  /// Defaults to `strings.button`.
  final String? tooltip;
  final bool preferAbove;
  final bool showSearch;
  final ShipglowsMenuStrings strings;

  @override
  Widget build(BuildContext context) => ShipglowsMenuAnchor(
    menu: menu,
    onSelected: onSelected,
    preferAbove: preferAbove,
    showSearch: showSearch,
    strings: strings,
    builder: (context, open) => IconButton(
      icon: icon,
      tooltip: tooltip ?? strings.button,
      onPressed: open,
    ),
  );
}

class _ShipglowsMenuRoute extends PopupRoute<ShipglowsMenuAction> {
  _ShipglowsMenuRoute({
    required this.menu,
    required this.anchor,
    required this.preferAbove,
    required this.showSearch,
    required this.strings,
    required this.themes,
  });

  final ShipglowsMenu menu;
  final Rect anchor;
  final bool preferAbove;
  final bool showSearch;
  final ShipglowsMenuStrings strings;
  final CapturedThemes themes;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => strings.dismiss;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 120);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 80);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => themes.wrap(
    Builder(
      builder: (context) {
        final style = ResolvedShipglowsMenuTheme.of(context);
        return CustomSingleChildLayout(
          delegate: _MenuLayout(
            anchor: anchor,
            preferAbove: preferAbove,
            width: style.width,
            maxHeight: style.maxHeight,
            padding: MediaQuery.paddingOf(context),
            textDirection: Directionality.of(context),
          ),
          child: ShipglowsMenuPanel(
            menu: menu,
            strings: strings,
            showSearch: showSearch,
            onSelected: (action) => Navigator.of(context).pop(action),
            onDismiss: () => Navigator.of(context).pop(),
          ),
        );
      },
    ),
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    );
  }
}

/// Below the anchor (or above with `preferAbove`), on the side with room
/// when the preferred one has none, kept inside the screen.
class _MenuLayout extends SingleChildLayoutDelegate {
  const _MenuLayout({
    required this.anchor,
    required this.preferAbove,
    required this.width,
    required this.maxHeight,
    required this.padding,
    required this.textDirection,
  });

  static const _gap = 4.0;
  static const _margin = 8.0;

  final Rect anchor;
  final bool preferAbove;
  final double width;
  final double maxHeight;
  final EdgeInsets padding;
  final TextDirection textDirection;

  double _below(Size size) =>
      size.height - padding.bottom - _margin - anchor.bottom - _gap;

  double _above() => anchor.top - _gap - padding.top - _margin;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final size = constraints.biggest;
    final room = math.max(_below(size), _above());
    final w = math.max(0.0, math.min(width, size.width - 2 * _margin));
    return BoxConstraints(
      minWidth: w,
      maxWidth: w,
      maxHeight: math.max(0.0, math.min(maxHeight, room)),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final fitsBelow = childSize.height <= _below(size);
    final fitsAbove = childSize.height <= _above();
    final above = preferAbove
        ? fitsAbove || !fitsBelow && _above() >= _below(size)
        : !fitsBelow && (fitsAbove || _above() > _below(size));
    var y = above ? anchor.top - _gap - childSize.height : anchor.bottom + _gap;
    final minY = padding.top + _margin;
    final maxY = size.height - padding.bottom - _margin - childSize.height;
    y = maxY < minY ? minY : y.clamp(minY, maxY);
    var x = textDirection == TextDirection.rtl
        ? anchor.right - childSize.width
        : anchor.left;
    final maxX = size.width - _margin - childSize.width;
    x = maxX < _margin ? _margin : x.clamp(_margin, maxX);
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_MenuLayout oldDelegate) =>
      anchor != oldDelegate.anchor ||
      preferAbove != oldDelegate.preferAbove ||
      width != oldDelegate.width ||
      maxHeight != oldDelegate.maxHeight ||
      padding != oldDelegate.padding ||
      textDirection != oldDelegate.textDirection;
}
