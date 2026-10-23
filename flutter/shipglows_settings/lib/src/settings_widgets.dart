import 'package:flutter/material.dart';

import 'setting_key.dart';
import 'settings_controller.dart';

/// Rebuilds only when [setting] changes value.
class SettingBuilder<T> extends StatelessWidget {
  const SettingBuilder({
    super.key,
    required this.controller,
    required this.setting,
    required this.builder,
  });

  final SettingsController controller;
  final SettingKey<T> setting;
  final Widget Function(BuildContext context, T value) builder;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<T>(
    valueListenable: controller.listenable(setting),
    builder: (context, value, _) => builder(context, value),
  );
}

/// Switch row bound to a boolean setting. Saving failures go to [onError]
/// (a snackbar), the switch then shows the stored value again.
class SettingSwitchTile extends StatelessWidget {
  const SettingSwitchTile({
    super.key,
    required this.controller,
    required this.setting,
    required this.title,
    this.subtitle,
    this.enabled = true,
    this.onError,
  });

  final SettingsController controller;
  final SettingKey<bool> setting;
  final Widget title;
  final Widget? subtitle;
  final bool enabled;
  final void Function(Object error)? onError;

  @override
  Widget build(BuildContext context) => SettingBuilder<bool>(
    controller: controller,
    setting: setting,
    builder: (context, value) => SwitchListTile(
      value: value,
      title: title,
      subtitle: subtitle,
      onChanged: enabled
          ? (next) => controller.set(setting, next).catchError((Object error) {
              onError?.call(error);
            })
          : null,
    ),
  );
}
