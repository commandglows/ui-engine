import 'package:flutter/material.dart';

import 'sync_status.dart';
import 'sync_strings.dart';

/// Local date and time of [value], in the app's language.
String formatSyncTime(BuildContext context, DateTime value) {
  final local = MaterialLocalizations.of(context);
  final time = value.toLocal();
  return '${local.formatShortDate(time)} '
      '${local.formatTimeOfDay(TimeOfDay.fromDateTime(time))}';
}

/// Small chip with the sync state; tapping it syncs now, or opens the review
/// when one waits ([onReview]). Icon and text both carry the state, never
/// the color alone.
class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip({
    super.key,
    required this.source,
    this.strings = SyncStrings.fr,
    this.onReview,
  });

  final SyncSource source;
  final SyncStrings strings;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: source,
    builder: (context, _) {
      final status = source.status;
      final (icon, color) = syncStatusLook(context, status.health);
      final label = strings.statusLabel(status);
      final last = status.lastSyncedAt;
      final VoidCallback? onPressed = switch (status.health) {
        SyncHealth.localOnly => null,
        SyncHealth.needsReview => onReview,
        _ => source.sync,
      };
      return Tooltip(
        message: last == null
            ? label
            : strings.lastSynced.replaceAll(
                '{time}',
                formatSyncTime(context, last),
              ),
        child: Semantics(
          button: onPressed != null,
          label: label,
          excludeSemantics: true,
          child: ActionChip(
            avatar: Icon(icon, size: 18, color: color),
            label: Text(label),
            onPressed: onPressed,
          ),
        ),
      );
    },
  );
}

/// Icon and color of [health], shared by the chip and the banner.
(IconData, Color) syncStatusLook(BuildContext context, SyncHealth health) {
  final scheme = Theme.of(context).colorScheme;
  return switch (health) {
    SyncHealth.localOnly => (Icons.phone_android_outlined, scheme.outline),
    SyncHealth.synced => (Icons.cloud_done_outlined, scheme.primary),
    SyncHealth.pending => (Icons.cloud_upload_outlined, scheme.tertiary),
    SyncHealth.syncing => (Icons.cloud_sync_outlined, scheme.primary),
    SyncHealth.needsReview => (Icons.compare_arrows, scheme.tertiary),
    SyncHealth.unreachable => (Icons.cloud_off_outlined, scheme.error),
    SyncHealth.failed => (Icons.cloud_off_outlined, scheme.error),
  };
}

/// Explains a sync problem and offers its way out (retry, sign in, compare);
/// takes no space while all is well.
class SyncIssueBanner extends StatelessWidget {
  const SyncIssueBanner({
    super.key,
    required this.source,
    this.strings = SyncStrings.fr,
    this.onReview,
    this.onSignIn,
  });

  final SyncSource source;
  final SyncStrings strings;

  /// Opens the review; without it no Compare action is shown.
  final VoidCallback? onReview;

  /// Opens the sign-in; without it no Sign in action is shown.
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: source,
    builder: (context, _) {
      final status = source.status;
      if (!status.needsAttention) return const SizedBox.shrink();
      final signInNeeded = status.issue?.retryable == false;
      final message = switch (status.health) {
        SyncHealth.needsReview => strings.bannerNeedsReview,
        SyncHealth.unreachable => strings.bannerUnreachable,
        SyncHealth.pending => strings.bannerOffline.replaceAll(
          '{count}',
          '${status.pendingCount}',
        ),
        _ when signInNeeded => strings.bannerSignIn,
        _ => strings.bannerFailed,
      };
      final Widget? action = switch (status.health) {
        SyncHealth.needsReview when onReview != null => FilledButton.tonal(
          onPressed: onReview,
          child: Text(strings.compare),
        ),
        SyncHealth.needsReview => null,
        _ when signInNeeded => onSignIn == null
            ? null
            : FilledButton.tonal(
                onPressed: onSignIn,
                child: Text(strings.signIn),
              ),
        _ => TextButton(onPressed: source.sync, child: Text(strings.retry)),
      };
      final scheme = Theme.of(context).colorScheme;
      final (icon, color) = syncStatusLook(context, status.health);
      return Semantics(
        liveRegion: true,
        container: true,
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: BorderDirectional(start: BorderSide(color: color, width: 3)),
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 12),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Text(message),
                    ),
                  ),
                ],
              ),
              ?action,
            ],
          ),
        ),
      );
    },
  );
}
