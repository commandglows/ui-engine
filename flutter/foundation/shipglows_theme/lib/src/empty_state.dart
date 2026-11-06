import 'package:flutter/material.dart';

import 'theme.dart';

/// An empty list that says what belongs there and offers the first step,
/// instead of a bare line. Colors and spacing come from [ShipglowsTheme]; the
/// texts are the caller's.
class ShipglowsEmptyState extends StatelessWidget {
  const ShipglowsEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  /// Drawn above the message, in [ShipglowsTheme.accent]. Excluded from the
  /// semantics tree: the message says it.
  final IconData icon;

  /// What belongs in the list, or why it is empty.
  final String message;

  /// Label of the first-step button. No button when null.
  final String? actionLabel;

  /// Null disables the button (for example while the app is busy).
  final VoidCallback? onAction;

  static const _iconSize = 40.0;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final label = actionLabel;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spaceLg),
      child: Column(
        children: [
          ExcludeSemantics(
            child: Icon(icon, size: _iconSize, color: theme.accent),
          ),
          SizedBox(height: theme.spaceSm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (label != null) ...[
            SizedBox(height: theme.spaceMd),
            FilledButton.tonalIcon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(label),
            ),
          ],
        ],
      ),
    );
  }
}
