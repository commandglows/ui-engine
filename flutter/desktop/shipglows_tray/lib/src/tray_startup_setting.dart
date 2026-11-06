import 'package:flutter/material.dart';

import 'tray.dart';
import 'tray_config.dart';

/// Settings rows for the launch at Windows sign-in: a switch, then, while it
/// is on, how the window starts (hidden in the tray, minimized, open).
/// Shows nothing where the tray does not exist.
class ShipglowsTrayStartupSetting extends StatelessWidget {
  const ShipglowsTrayStartupSetting({super.key});

  @override
  Widget build(BuildContext context) {
    final tray = ShipglowsTray.instance;
    final config = tray.config;
    if (!ShipglowsTray.isSupported || config == null) {
      return const SizedBox.shrink();
    }
    final strings = config.standard.strings;
    String label(ShipglowsTrayStartupWindow window) => switch (window) {
      ShipglowsTrayStartupWindow.hidden => strings.startupHidden,
      ShipglowsTrayStartupWindow.minimized => strings.startupMinimized,
      ShipglowsTrayStartupWindow.shown => strings.startupShown,
    };
    return ListenableBuilder(
      listenable: Listenable.merge([tray.launchAtStartup, tray.startupWindow]),
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              strings.launchAtStartup.replaceAll('{app}', config.appName),
            ),
            value: tray.launchAtStartup.value,
            onChanged: tray.setLaunchAtStartup,
          ),
          if (tray.launchAtStartup.value)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(strings.startupWindow),
              trailing: DropdownButton<ShipglowsTrayStartupWindow>(
                value: tray.startupWindow.value,
                onChanged: (value) {
                  if (value != null) tray.setStartupWindow(value);
                },
                items: [
                  for (final window in ShipglowsTrayStartupWindow.values)
                    DropdownMenuItem(value: window, child: Text(label(window))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
