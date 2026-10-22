import 'package:flutter/material.dart';

import 'setting_key.dart';
import 'settings_controller.dart';
import 'sync_status.dart';

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

/// Labels of [SettingsSyncChip], French by default like the ShipGlows apps.
class SettingsSyncLabels {
  const SettingsSyncLabels({
    this.localOnly = 'Sur cet appareil',
    this.synced = 'Synchronisé',
    this.pending = 'En attente de synchro',
    this.syncing = 'Synchronisation…',
    this.failed = 'Synchro impossible',
    this.signInAgain = 'Reconnectez-vous pour synchroniser',
  });

  static const en = SettingsSyncLabels(
    localOnly: 'On this device',
    synced: 'Synced',
    pending: 'Waiting to sync',
    syncing: 'Syncing…',
    failed: 'Sync failed',
    signInAgain: 'Sign in again to sync',
  );

  final String localOnly;
  final String synced;
  final String pending;
  final String syncing;
  final String failed;
  final String signInAgain;

  String of(SyncStatus status) => switch (status.health) {
    SyncHealth.localOnly => localOnly,
    SyncHealth.synced => synced,
    SyncHealth.pending => pending,
    SyncHealth.syncing => syncing,
    SyncHealth.failed =>
      status.issue?.retryable == false ? signInAgain : failed,
  };
}

/// Small chip with the sync state of the account settings; tapping it syncs
/// now. Icon and text both carry the state, never the color alone.
class SettingsSyncChip extends StatelessWidget {
  const SettingsSyncChip({
    super.key,
    required this.controller,
    this.labels = const SettingsSyncLabels(),
  });

  final SettingsController controller;
  final SettingsSyncLabels labels;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final status = controller.status;
      final scheme = Theme.of(context).colorScheme;
      final (icon, color) = switch (status.health) {
        SyncHealth.localOnly => (Icons.phone_android_outlined, scheme.outline),
        SyncHealth.synced => (Icons.cloud_done_outlined, scheme.primary),
        SyncHealth.pending => (Icons.cloud_upload_outlined, scheme.tertiary),
        SyncHealth.syncing => (Icons.cloud_sync_outlined, scheme.primary),
        SyncHealth.failed => (Icons.cloud_off_outlined, scheme.error),
      };
      final label = labels.of(status);
      return Semantics(
        button: status.health != SyncHealth.localOnly,
        label: label,
        excludeSemantics: true,
        child: ActionChip(
          avatar: Icon(icon, size: 18, color: color),
          label: Text(label),
          onPressed: status.health == SyncHealth.localOnly
              ? null
              : controller.sync,
        ),
      );
    },
  );
}
