import 'package:flutter/material.dart';

import 'tray.dart';
import 'tray_config.dart';

/// What the user picked in the close dialog.
@immutable
class ShipglowsTrayCloseDecision {
  const ShipglowsTrayCloseDecision(this.behavior, {required this.remember});

  /// [ShipglowsTrayCloseBehavior.hideToTray] or
  /// [ShipglowsTrayCloseBehavior.quit].
  final ShipglowsTrayCloseBehavior behavior;

  /// « Ne plus me demander » was ticked.
  final bool remember;
}

/// Asks whether closing the window hides the app to the tray or quits it.
/// Null when cancelled (Annuler, Escape, a tap outside). `ShipglowsTray`
/// shows it itself; call it only for a custom flow.
Future<ShipglowsTrayCloseDecision?> showShipglowsTrayCloseDialog(
  BuildContext context, {
  required String appName,
  ShipglowsTrayStrings strings = ShipglowsTrayStrings.fr,
}) => showDialog<ShipglowsTrayCloseDecision>(
  context: context,
  builder: (_) => _CloseDialog(appName: appName, strings: strings),
);

class _CloseDialog extends StatefulWidget {
  const _CloseDialog({required this.appName, required this.strings});

  final String appName;
  final ShipglowsTrayStrings strings;

  @override
  State<_CloseDialog> createState() => _CloseDialogState();
}

class _CloseDialogState extends State<_CloseDialog> {
  bool _remember = false;

  String _fill(String template) => template.replaceAll('{app}', widget.appName);

  void _choose(ShipglowsTrayCloseBehavior behavior) => Navigator.of(
    context,
  ).pop(ShipglowsTrayCloseDecision(behavior, remember: _remember));

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    return AlertDialog(
      title: Text(_fill(strings.closeTitle)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(strings.closeMessage),
            const SizedBox(height: 16),
            _Choice(
              icon: Icons.south_east_rounded,
              title: strings.closeToTray,
              hint: _fill(strings.closeToTrayHint),
              autofocus: true,
              onPressed: () => _choose(ShipglowsTrayCloseBehavior.hideToTray),
            ),
            const SizedBox(height: 8),
            _Choice(
              icon: Icons.power_settings_new_rounded,
              title: _fill(strings.quit),
              hint: strings.closeQuitHint,
              onPressed: () => _choose(ShipglowsTrayCloseBehavior.quit),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _remember,
              onChanged: (value) => setState(() => _remember = value ?? false),
              title: Text(strings.closeRemember),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.icon,
    required this.title,
    required this.hint,
    required this.onPressed,
    this.autofocus = false,
  });

  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback onPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton(
      onPressed: onPressed,
      autofocus: autofocus,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(14),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  hint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A settings row choosing what closing the window does, saved like
/// « Ne plus me demander ». Shows nothing where the tray does not exist.
class ShipglowsTrayCloseSetting extends StatelessWidget {
  const ShipglowsTrayCloseSetting({super.key});

  @override
  Widget build(BuildContext context) {
    final tray = ShipglowsTray.instance;
    final config = tray.config;
    if (!ShipglowsTray.isSupported || config == null) {
      return const SizedBox.shrink();
    }
    final strings = config.standard.strings;
    String label(ShipglowsTrayCloseBehavior behavior) => switch (behavior) {
      ShipglowsTrayCloseBehavior.ask => strings.closeAsk,
      ShipglowsTrayCloseBehavior.hideToTray => strings.closeToTray,
      ShipglowsTrayCloseBehavior.minimize => strings.closeMinimize,
      ShipglowsTrayCloseBehavior.quit => strings.quit.replaceAll(
        '{app}',
        config.appName,
      ),
    };
    return ValueListenableBuilder<ShipglowsTrayCloseBehavior>(
      valueListenable: tray.closeBehavior,
      builder: (context, current, _) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(strings.closeSetting),
        trailing: DropdownButton<ShipglowsTrayCloseBehavior>(
          value: current,
          onChanged: (value) {
            if (value != null) tray.setCloseBehavior(value);
          },
          items: [
            for (final behavior in ShipglowsTrayCloseBehavior.values)
              DropdownMenuItem(value: behavior, child: Text(label(behavior))),
          ],
        ),
      ),
    );
  }
}
