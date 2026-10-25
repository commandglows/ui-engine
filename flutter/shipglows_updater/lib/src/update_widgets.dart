import 'package:flutter/material.dart';

import 'update_state.dart';
import 'updater.dart';
import 'updater_config.dart';

/// Settings row « Mises à jour »: the state as a subtitle (announced when
/// it changes), then « Rechercher une mise à jour », « Installer »,
/// « Autoriser » or « Réessayer » as it fits, and a progress bar while the
/// APK downloads. Shows nothing where the updater is not active (debug,
/// store install, web, no URL).
class ShipglowsUpdateSetting extends StatelessWidget {
  const ShipglowsUpdateSetting({
    super.key,
    this.strings = ShipglowsUpdaterStrings.fr,
    this.updater,
  });

  final ShipglowsUpdaterStrings strings;

  /// Defaults to [ShipglowsUpdater.instance].
  final ShipglowsUpdater? updater;

  @override
  Widget build(BuildContext context) {
    final updater = this.updater ?? ShipglowsUpdater.instance;
    return ValueListenableBuilder(
      valueListenable: updater.state,
      builder: (context, state, _) {
        if (!updater.isActive) return const SizedBox.shrink();
        final current = updater.currentVersion;
        final status = _status(state);
        final subtitle = status ??
            (current == null
                ? null
                : strings.currentVersion.replaceAll(
                    '{version}',
                    current.display,
                  ));
        final progress = state is ShipglowsUpdateDownloading
            ? state
            : null;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(strings.title),
              subtitle: subtitle == null
                  ? null
                  : Semantics(liveRegion: true, child: Text(subtitle)),
              trailing: _action(updater, state),
            ),
            if (progress != null)
              LinearProgressIndicator(
                value: progress.progress,
                semanticsLabel: subtitle,
              ),
          ],
        );
      },
    );
  }

  String? _status(ShipglowsUpdateState state) {
    String withVersion(String text, Object? version) =>
        version == null ? text : text.replaceAll('{version}', '$version');
    return switch (state) {
      ShipglowsUpdateIdle() => null,
      ShipglowsUpdateChecking() => strings.checking,
      ShipglowsUpdateUpToDate() => strings.upToDate,
      ShipglowsUpdateAvailable(:final release) =>
        release == null
            ? strings.available.replaceAll(' {version}', '')
            : withVersion(strings.available, release.version.display),
      ShipglowsUpdateDownloading(:final release) => withVersion(
        strings.downloading,
        release.version.display,
      ),
      ShipglowsUpdateNeedsPermission() => strings.needsPermission,
      ShipglowsUpdateInstalling(:final release) =>
        release == null
            ? strings.installing.replaceAll(' {version}', '')
            : withVersion(strings.installing, release.version.display),
      ShipglowsUpdateFailed(:final error) => switch (error.kind) {
        ShipglowsUpdateErrorKind.network => strings.failedNetwork,
        ShipglowsUpdateErrorKind.manifest => strings.failedManifest,
        ShipglowsUpdateErrorKind.checksum => strings.failedChecksum,
        ShipglowsUpdateErrorKind.signature => strings.failedSignature,
        ShipglowsUpdateErrorKind.downgrade => strings.failedDowngrade,
        ShipglowsUpdateErrorKind.install => strings.failedInstall,
      },
    };
  }

  Widget? _action(ShipglowsUpdater updater, ShipglowsUpdateState state) {
    Widget button(String label, Future<void> Function() onPressed) =>
        TextButton(onPressed: onPressed, child: Text(label));
    return switch (state) {
      ShipglowsUpdateChecking() || ShipglowsUpdateDownloading() => null,
      ShipglowsUpdateAvailable() => FilledButton(
        onPressed: updater.install,
        child: Text(strings.install),
      ),
      // The system dialog may have been cancelled: offer it again.
      ShipglowsUpdateInstalling(:final release) =>
        release == null ? null : button(strings.install, updater.install),
      ShipglowsUpdateNeedsPermission() => button(strings.allow, updater.install),
      ShipglowsUpdateFailed(:final release) => button(
        strings.retry,
        release == null ? updater.checkNow : updater.install,
      ),
      ShipglowsUpdateIdle() || ShipglowsUpdateUpToDate() => button(
        strings.check,
        updater.checkNow,
      ),
    };
  }
}
