import 'package:flutter/material.dart';

import 'reconciliation.dart';
import 'sync_review.dart';
import 'sync_status_widgets.dart';
import 'sync_strings.dart';

/// The copies kept before a reviewed sync, with a way back to either one;
/// takes no space when there are none. Fits a settings page.
class SyncRecoveryPanel extends StatelessWidget {
  const SyncRecoveryPanel({
    super.key,
    required this.host,
    this.strings = SyncStrings.fr,
  });

  final SyncRecoveryHost host;
  final SyncStrings strings;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: host,
    builder: (context, _) {
      final recovery = host.recovery;
      if (recovery == null) return const SizedBox.shrink();
      final theme = Theme.of(context);
      final muted = theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(strings.recoveryTitle, style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: 4),
          Text(
            strings.recoverySavedOn.replaceAll(
              '{date}',
              formatSyncTime(context, recovery.savedAt),
            ),
            style: muted,
          ),
          Text(
            recovery.confirmed
                ? strings.recoveryConfirmed
                : strings.recoveryInterrupted,
            style: muted,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => _restore(context, SyncSide.device),
                child: Text(strings.restoreDevice),
              ),
              OutlinedButton(
                onPressed: () => _restore(context, SyncSide.account),
                child: Text(strings.restoreAccount),
              ),
              TextButton(
                onPressed: host.dropRecovery,
                child: Text(strings.dropRecovery),
              ),
            ],
          ),
        ],
      );
    },
  );

  Future<void> _restore(BuildContext context, SyncSide side) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          side == SyncSide.device ? strings.restoreDevice : strings.restoreAccount,
        ),
        content: Text(strings.restoreWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.restore),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final restored = await host.restoreRecovery(side);
    messenger?.showSnackBar(
      SnackBar(content: Text(restored ? strings.restored : strings.restoreFailed)),
    );
  }
}
