import 'package:flutter/widgets.dart';

import 'shipglows_title_bar.dart';
import 'shipglows_title_bar_style.dart';
import 'shipglows_window.dart';

/// Puts the custom title bar above the app; returns [child] untouched on
/// mobile, web, or when [enabled] is false.
///
/// Meant for `MaterialApp.builder`, so every route sits under the same bar.
class ShipglowsWindowFrame extends StatelessWidget {
  const ShipglowsWindowFrame({
    super.key,
    required this.child,
    this.enabled = true,
    this.style,
    this.leading,
    this.title,
    this.actions = const <Widget>[],
  });

  /// The app content shown under the bar.
  final Widget child;

  /// Whether to draw the bar; lets an app limit it to some desktop targets.
  final bool enabled;

  /// Visual tokens; defaults to the current theme.
  final ShipglowsTitleBarStyle? style;

  /// Optional widget before the title.
  final Widget? leading;

  /// Optional title.
  final Widget? title;

  /// Optional app widgets placed before the caption buttons.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    if (!enabled || !ShipglowsWindow.isSupported) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShipglowsTitleBar(
          style: style,
          leading: leading,
          title: title,
          actions: actions,
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}
