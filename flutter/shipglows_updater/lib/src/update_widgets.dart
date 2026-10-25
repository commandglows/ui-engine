import 'dart:async';

import 'package:flutter/material.dart';

import 'update_release.dart';
import 'update_state.dart';
import 'updater.dart';
import 'updater_config.dart';

/// Opens the update dialog where the platform has one (Android), or
/// WinSparkle's own window (Windows), so every entry point behaves alike.
Future<void> openShipglowsUpdate(
  BuildContext context, {
  required String appName,
  ShipglowsUpdaterStrings strings = ShipglowsUpdaterStrings.fr,
  ShipglowsUpdater? updater,
}) {
  final service = updater ?? ShipglowsUpdater.instance;
  final state = service.state.value;
  if (state is ShipglowsUpdateAvailable && state.release == null) {
    return service.install();
  }
  return showShipglowsUpdateDialog(
    context,
    appName: appName,
    strings: strings,
    updater: service,
  );
}

/// The update dialog: what is new, what installing does to the person's
/// work, then progress, permission and recovery in place. « Plus tard » and
/// « Masquer » always leave; the download carries on behind « Masquer ».
Future<void> showShipglowsUpdateDialog(
  BuildContext context, {
  required String appName,
  ShipglowsUpdaterStrings strings = ShipglowsUpdaterStrings.fr,
  ShipglowsUpdater? updater,
}) => showDialog<void>(
  context: context,
  builder: (_) => ShipglowsUpdateDialog(
    appName: appName,
    strings: strings,
    updater: updater ?? ShipglowsUpdater.instance,
  ),
);

class ShipglowsUpdateDialog extends StatelessWidget {
  const ShipglowsUpdateDialog({
    super.key,
    required this.appName,
    required this.updater,
    this.strings = ShipglowsUpdaterStrings.fr,
  });

  final String appName;
  final ShipglowsUpdater updater;
  final ShipglowsUpdaterStrings strings;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: updater.state,
      builder: (context, state, _) {
        final theme = Theme.of(context);
        final release = updater.release;
        final lead = _lead(state, release);
        final notes = release?.notes;
        final showNotes =
            notes != null &&
            (state is ShipglowsUpdateAvailable ||
                state is ShipglowsUpdateDownloading);
        final progress = state is ShipglowsUpdateDownloading ? state : null;
        return AlertDialog(
          title: Text(
            updater.hasPendingUpdate ? strings.dialogTitle : strings.title,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(liveRegion: true, child: Text(lead)),
                if (progress != null) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: progress.progress,
                    semanticsLabel: lead,
                    semanticsValue: progress.progress == null
                        ? null
                        : '${(progress.progress! * 100).round()} %',
                  ),
                ],
                if (showNotes) ...[
                  const SizedBox(height: 16),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.notesLabel,
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(notes, style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ),
                ],
                if (state is ShipglowsUpdateAvailable) ...[
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          strings.whatHappensAndroid,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: _actions(context, state),
        );
      },
    );
  }

  String _lead(ShipglowsUpdateState state, ShipglowsRelease? release) {
    String fill(String text) => text
        .replaceAll('{app}', appName)
        .replaceAll('{version}', release?.version.display ?? '')
        .replaceAll('{current}', updater.currentVersion?.display ?? '');
    return switch (state) {
      ShipglowsUpdateIdle() =>
        updater.currentVersion == null
            ? strings.title
            : strings.currentVersion.replaceAll(
                '{version}',
                updater.currentVersion!.display,
              ),
      ShipglowsUpdateChecking() => strings.checking,
      ShipglowsUpdateUpToDate() =>
        strings.upToDateLong
            .replaceAll('{app}', appName)
            .replaceAll('{version}', updater.currentVersion?.display ?? ''),
      ShipglowsUpdateAvailable() => fill(strings.dialogAvailable),
      ShipglowsUpdateDownloading() => fill(strings.downloading),
      ShipglowsUpdateNeedsPermission() => fill(strings.needsPermissionLong),
      ShipglowsUpdateInstalling() => strings.installingAndroid,
      ShipglowsUpdateFailed(:final error) => _failure(strings, error.kind),
    };
  }

  List<Widget> _actions(BuildContext context, ShipglowsUpdateState state) {
    void close() => Navigator.of(context).pop();
    Widget secondary(String label, VoidCallback onPressed) =>
        TextButton(onPressed: onPressed, child: Text(label));
    Widget primary(String label, VoidCallback onPressed) =>
        FilledButton(onPressed: onPressed, child: Text(label));
    return switch (state) {
      ShipglowsUpdateChecking() => [
        const Padding(
          padding: EdgeInsets.all(8),
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ],
      ShipglowsUpdateIdle() ||
      ShipglowsUpdateUpToDate() => [primary(strings.close, close)],
      ShipglowsUpdateAvailable() => [
        secondary(strings.later, close),
        primary(strings.installNow, () => unawaited(updater.install())),
      ],
      // The download carries on: the pill or badge brings the dialog back.
      ShipglowsUpdateDownloading() => [secondary(strings.hide, close)],
      ShipglowsUpdateNeedsPermission() => [
        secondary(strings.later, close),
        primary(
          strings.allow,
          () => unawaited(updater.openInstallPermission()),
        ),
      ],
      // The system dialog may have been cancelled: offer it again.
      ShipglowsUpdateInstalling() => [
        secondary(strings.close, close),
        primary(strings.reopenInstaller, () => unawaited(updater.install())),
      ],
      ShipglowsUpdateFailed() => [
        secondary(strings.later, close),
        primary(strings.retry, () => unawaited(updater.retry())),
      ],
    };
  }
}

String _failure(
  ShipglowsUpdaterStrings strings,
  ShipglowsUpdateErrorKind kind,
) => switch (kind) {
  ShipglowsUpdateErrorKind.network => strings.failedNetwork,
  ShipglowsUpdateErrorKind.manifest => strings.failedManifest,
  ShipglowsUpdateErrorKind.checksum => strings.failedChecksum,
  ShipglowsUpdateErrorKind.signature => strings.failedSignature,
  ShipglowsUpdateErrorKind.downgrade => strings.failedDowngrade,
  ShipglowsUpdateErrorKind.install => strings.failedInstall,
};

/// A quiet entry in the app's chrome (sidebar, menu, header) shown only
/// while a newer version waits: the version, then download progress. Opens
/// [openShipglowsUpdate]. Nothing when no update is pending.
class ShipglowsUpdatePill extends StatelessWidget {
  const ShipglowsUpdatePill({
    super.key,
    required this.appName,
    this.strings = ShipglowsUpdaterStrings.fr,
    this.compact = false,
    this.updater,
  });

  final String appName;
  final ShipglowsUpdaterStrings strings;

  /// Icon only (narrow sidebar); the label becomes the tooltip.
  final bool compact;

  /// Defaults to [ShipglowsUpdater.instance].
  final ShipglowsUpdater? updater;

  @override
  Widget build(BuildContext context) {
    final service = updater ?? ShipglowsUpdater.instance;
    return ValueListenableBuilder(
      valueListenable: service.state,
      builder: (context, state, _) {
        if (!service.hasPendingUpdate) return const SizedBox.shrink();
        final version = service.release?.version.display;
        final label = switch (state) {
          ShipglowsUpdateDownloading(:final progress) =>
            strings.pillDownloading.replaceAll(
              '{percent}',
              '${((progress ?? 0) * 100).round()}',
            ),
          ShipglowsUpdateInstalling() => strings.pillInstalling,
          ShipglowsUpdateFailed() => strings.pillFailed,
          _ =>
            version == null
                ? strings.pillAvailableShort
                : strings.pillAvailable.replaceAll('{version}', version),
        };
        final icon = switch (state) {
          ShipglowsUpdateFailed() => Icons.error_outline,
          ShipglowsUpdateDownloading() ||
          ShipglowsUpdateInstalling() => Icons.downloading,
          _ => Icons.system_update_alt,
        };
        void open() => unawaited(
          openShipglowsUpdate(
            context,
            appName: appName,
            strings: strings,
            updater: service,
          ),
        );
        if (compact) {
          return ShipglowsUpdateBadge(
            updater: service,
            child: IconButton(
              tooltip: label,
              onPressed: open,
              icon: Icon(icon),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(8),
          child: OutlinedButton.icon(
            onPressed: open,
            icon: Icon(icon),
            label: Text(label),
          ),
        );
      },
    );
  }
}

/// A dot over [child] (a settings or menu icon) while an update waits on the
/// person: a version to install, a permission, a failure.
class ShipglowsUpdateBadge extends StatelessWidget {
  const ShipglowsUpdateBadge({super.key, required this.child, this.updater});

  final Widget child;

  /// Defaults to [ShipglowsUpdater.instance].
  final ShipglowsUpdater? updater;

  @override
  Widget build(BuildContext context) {
    final service = updater ?? ShipglowsUpdater.instance;
    return ValueListenableBuilder(
      valueListenable: service.state,
      builder: (context, state, child) {
        final attention =
            state is ShipglowsUpdateAvailable ||
            state is ShipglowsUpdateNeedsPermission ||
            (state is ShipglowsUpdateFailed && state.release != null);
        return Badge(isLabelVisible: attention, smallSize: 8, child: child);
      },
      child: child,
    );
  }
}

/// Announces a new version once, at launch only (a natural break, never in
/// the middle of a session), with the update dialog. Android only: on
/// Windows WinSparkle announces it itself. Put it in `MaterialApp.builder`.
class ShipglowsUpdateAnnouncer extends StatefulWidget {
  const ShipglowsUpdateAnnouncer({
    super.key,
    required this.navigatorKey,
    required this.appName,
    required this.child,
    this.strings = ShipglowsUpdaterStrings.fr,
    this.announcedVersion,
    this.onAnnounced,
    this.window = const Duration(minutes: 2),
    this.updater,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final String appName;
  final Widget child;
  final ShipglowsUpdaterStrings strings;

  /// The version announced last time, so a version is announced only once;
  /// save it from [onAnnounced]. Null announces once per launch.
  final String? announcedVersion;
  final ValueChanged<String>? onAnnounced;

  /// After this long the first check counts as « in a session »: the
  /// announcement is skipped and only the pill and badge remain.
  final Duration window;

  /// Defaults to [ShipglowsUpdater.instance].
  final ShipglowsUpdater? updater;

  @override
  State<ShipglowsUpdateAnnouncer> createState() =>
      _ShipglowsUpdateAnnouncerState();
}

class _ShipglowsUpdateAnnouncerState extends State<ShipglowsUpdateAnnouncer> {
  late final ShipglowsUpdater _updater =
      widget.updater ?? ShipglowsUpdater.instance;
  late final DateTime _launchedAt = DateTime.now();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _updater.state.addListener(_onState);
  }

  @override
  void dispose() {
    _updater.state.removeListener(_onState);
    super.dispose();
  }

  void _onState() {
    if (_done) return;
    final state = _updater.state.value;
    if (state is! ShipglowsUpdateAvailable) {
      if (state is ShipglowsUpdateUpToDate || state is ShipglowsUpdateFailed) {
        _done = true;
      }
      return;
    }
    _done = true;
    final release = state.release;
    if (release == null) return;
    if (DateTime.now().difference(_launchedAt) > widget.window) return;
    final version = release.version.toString();
    if (widget.announcedVersion == version) return;
    final context = widget.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    widget.onAnnounced?.call(version);
    unawaited(
      showShipglowsUpdateDialog(
        context,
        appName: widget.appName,
        strings: widget.strings,
        updater: _updater,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Settings row « Mises à jour »: the state as a subtitle (announced when
/// it changes) and one button: « Rechercher une mise à jour », or « Voir la
/// mise à jour » that opens [openShipglowsUpdate]. Shows nothing where the
/// updater is not active (debug, store install, web, no URL).
class ShipglowsUpdateSetting extends StatelessWidget {
  const ShipglowsUpdateSetting({
    super.key,
    required this.appName,
    this.strings = ShipglowsUpdaterStrings.fr,
    this.updater,
  });

  final String appName;
  final ShipglowsUpdaterStrings strings;

  /// Defaults to [ShipglowsUpdater.instance].
  final ShipglowsUpdater? updater;

  @override
  Widget build(BuildContext context) {
    final service = updater ?? ShipglowsUpdater.instance;
    return ValueListenableBuilder(
      valueListenable: service.state,
      builder: (context, state, _) {
        if (!service.isActive) return const SizedBox.shrink();
        final subtitle = _status(service, state);
        final pending = service.hasPendingUpdate;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(strings.title),
          subtitle: subtitle == null
              ? null
              : Semantics(liveRegion: true, child: Text(subtitle)),
          trailing: switch (state) {
            ShipglowsUpdateChecking() => const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            _ when pending => FilledButton(
              onPressed: () => unawaited(
                openShipglowsUpdate(
                  context,
                  appName: appName,
                  strings: strings,
                  updater: service,
                ),
              ),
              child: Text(strings.seeUpdate),
            ),
            ShipglowsUpdateFailed() => TextButton(
              onPressed: () => unawaited(service.retry()),
              child: Text(strings.retry),
            ),
            _ => TextButton(
              onPressed: () => unawaited(service.checkNow()),
              child: Text(strings.check),
            ),
          },
        );
      },
    );
  }

  String? _status(ShipglowsUpdater service, ShipglowsUpdateState state) {
    final version = service.release?.version.display;
    String withVersion(String text) => version == null
        ? text.replaceAll(' {version}', '')
        : text.replaceAll('{version}', version);
    final current = service.currentVersion;
    return switch (state) {
      ShipglowsUpdateIdle() =>
        current == null
            ? null
            : strings.currentVersion.replaceAll('{version}', current.display),
      ShipglowsUpdateChecking() => strings.checking,
      ShipglowsUpdateUpToDate() => strings.upToDate,
      ShipglowsUpdateAvailable() => withVersion(strings.available),
      ShipglowsUpdateDownloading() => withVersion(strings.downloading),
      ShipglowsUpdateNeedsPermission() => strings.needsPermission,
      ShipglowsUpdateInstalling() => withVersion(strings.installing),
      ShipglowsUpdateFailed(:final error) => _failure(strings, error.kind),
    };
  }
}
