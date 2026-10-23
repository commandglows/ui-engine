import 'package:flutter/material.dart';

import 'tray.dart';

/// A settings switch turning the launch at Windows sign-in on or off. Shows
/// nothing where the tray does not exist.
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
    return ValueListenableBuilder<bool>(
      valueListenable: tray.launchAtStartup,
      builder: (context, enabled, _) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          strings.launchAtStartup.replaceAll('{app}', config.appName),
        ),
        subtitle: config.hideWhenLaunchedAtStartup
            ? Text(strings.launchAtStartupHint)
            : null,
        value: enabled,
        onChanged: tray.setLaunchAtStartup,
      ),
    );
  }
}
