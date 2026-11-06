import 'package:flutter/material.dart';
import 'package:shipglows_icons/shipglows_icons.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'strings.dart';

/// The unread count over [child] (a bell, a menu entry): hidden at 0,
/// « 99+ » above [max], in the theme's `accent` with `onAccent` text, so it
/// reads as news, not as an error. Its count is not spoken: the button
/// carrying it says it (see [NotificationBellButton]).
class NotificationBadge extends StatelessWidget {
  const NotificationBadge({
    super.key,
    required this.count,
    required this.child,
    this.max = 99,
  });

  final int count;
  final Widget child;

  /// Above it, « max+ ».
  final int max;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    return Badge(
      isLabelVisible: count > 0,
      backgroundColor: theme.accent,
      textColor: theme.onAccent,
      label: ExcludeSemantics(child: Text(count > max ? '$max+' : '$count')),
      child: child,
    );
  }
}

/// The bell that opens the center, with its [NotificationBadge]. Its tooltip
/// is the title; a screen reader hears « 3 unread notifications » when
/// there are some. 44 px at least.
class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({
    super.key,
    required this.count,
    required this.onPressed,
    this.icon,
    this.tooltip,
    this.strings,
  });

  final int count;
  final VoidCallback? onPressed;

  /// The bell of [ShipglowsIcons] by default.
  final Widget? icon;

  /// Defaults to [NotificationStrings.title].
  final String? tooltip;

  /// Defaults to [NotificationStrings.of] the context.
  final NotificationStrings? strings;

  @override
  Widget build(BuildContext context) {
    final texts = strings ?? NotificationStrings.of(context);
    final tooltip = this.tooltip ?? texts.title;
    return Semantics(
      label: count > 0 ? '$tooltip, ${texts.badge(count)}' : tooltip,
      button: true,
      excludeSemantics: true,
      child: IconButton(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        tooltip: tooltip,
        onPressed: onPressed,
        icon: NotificationBadge(
          count: count,
          child:
              icon ??
              Icon(
                ShipglowsIcons.of(context, 'notifications') ??
                    ShipglowsIcons.notifications,
              ),
        ),
      ),
    );
  }
}
