import 'package:flutter/material.dart';

import 'reconciliation.dart';
import 'sync_review.dart';
import 'sync_strings.dart';

/// Names a conflict in the user's words (`theme` → "Thème").
typedef SyncConflictLabel = String Function(SyncConflict conflict);

/// Shows one side's value of a conflict in the user's words.
typedef SyncValueLabel =
    String Function(Object? value, SyncConflict conflict);

/// Opens the review of [host] as a dialog. "Stay local" closes it: sync
/// stays suspended and the device values stay in use until the user comes
/// back (status chip, banner). Returns whether the review was confirmed.
Future<bool> showSyncReviewDialog(
  BuildContext context, {
  required SyncReviewHost host,
  SyncStrings strings = SyncStrings.fr,
  SyncConflictLabel? labelOf,
  SyncValueLabel? describe,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => ListenableBuilder(
      listenable: host,
      builder: (context, _) => PopScope(
        canPop: !host.isResolvingReview,
        child: Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SyncReviewView(
              host: host,
              strings: strings,
              labelOf: labelOf,
              describe: describe,
              onDone: (confirmed) => Navigator.of(context).pop(confirmed),
            ),
          ),
        ),
      ),
    ),
  );
  return confirmed ?? false;
}

/// Opens [showSyncReviewDialog] by itself each time [host] gets a new
/// review, once per review. Put it high in the tree, under the navigator
/// (in `MaterialApp.builder`, give it [navigatorKey]).
class SyncReviewPrompt extends StatefulWidget {
  const SyncReviewPrompt({
    super.key,
    required this.host,
    required this.child,
    this.navigatorKey,
    this.strings = SyncStrings.fr,
    this.labelOf,
    this.describe,
  });

  final SyncReviewHost host;
  final Widget child;

  /// The app's navigator when this widget sits above it.
  final GlobalKey<NavigatorState>? navigatorKey;
  final SyncStrings strings;
  final SyncConflictLabel? labelOf;
  final SyncValueLabel? describe;

  @override
  State<SyncReviewPrompt> createState() => _SyncReviewPromptState();
}

class _SyncReviewPromptState extends State<SyncReviewPrompt> {
  String? _shown;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    widget.host.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didUpdateWidget(SyncReviewPrompt old) {
    super.didUpdateWidget(old);
    if (!identical(old.host, widget.host)) {
      old.host.removeListener(_check);
      widget.host.addListener(_check);
    }
  }

  @override
  void dispose() {
    widget.host.removeListener(_check);
    super.dispose();
  }

  void _check() {
    final review = widget.host.review;
    if (review == null || _open || !mounted) return;
    // A review recomputed after a resume is the same choice: ask once.
    final id = '${review.accountId}:${review.account.fingerprint}';
    if (id == _shown) return;
    final navigatorContext =
        widget.navigatorKey?.currentContext ?? context;
    if (Navigator.maybeOf(navigatorContext) == null) return;
    _shown = id;
    _open = true;
    showSyncReviewDialog(
      navigatorContext,
      host: widget.host,
      strings: widget.strings,
      labelOf: widget.labelOf,
      describe: widget.describe,
    ).whenComplete(() => _open = false);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The review itself: what will happen, one choice per difference, confirm
/// or stay local. [onDone] gets whether the review was confirmed.
class SyncReviewView extends StatefulWidget {
  const SyncReviewView({
    super.key,
    required this.host,
    required this.onDone,
    this.strings = SyncStrings.fr,
    this.labelOf,
    this.describe,
  });

  final SyncReviewHost host;
  final ValueChanged<bool> onDone;
  final SyncStrings strings;
  final SyncConflictLabel? labelOf;
  final SyncValueLabel? describe;

  @override
  State<SyncReviewView> createState() => _SyncReviewViewState();
}

class _SyncReviewViewState extends State<SyncReviewView> {
  final SyncChoices _choices = {};
  SyncReview? _review;

  SyncStrings get _t => widget.strings;

  @override
  Widget build(BuildContext context) {
    final host = widget.host;
    final review = host.review;
    if (!identical(review, _review)) {
      // A new comparison (a side changed) starts its choices over.
      _review = review;
      _choices.clear();
    }
    if (review == null) return const SizedBox.shrink();
    final plan = review.plan(_choices);
    final busy = host.isResolvingReview;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final error = switch (host.reviewError) {
      SyncReviewError.changed => _t.reviewChanged,
      SyncReviewError.failed => _t.reviewFailed,
      null => null,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(_t.reviewTitle, style: theme.textTheme.headlineSmall),
          ),
          const SizedBox(height: 8),
          Text(_t.reviewDescription, style: muted),
          const SizedBox(height: 16),
          Text(_t.reviewUnion),
          const SizedBox(height: 8),
          Text(_t.reviewRecovery, style: muted),
          const SizedBox(height: 16),
          if (!plan.hasConflicts)
            Text(_t.reviewNoConflicts)
          else ...[
            Text(
              _t.reviewConflicts.replaceAll(
                '{count}',
                '${plan.conflicts.length}',
              ),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => setState(
                          () => _choices.addAll(plan.chooseAll(SyncSide.device)),
                        ),
                  child: Text(_t.allDevice),
                ),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => setState(
                          () =>
                              _choices.addAll(plan.chooseAll(SyncSide.account)),
                        ),
                  child: Text(_t.allAccount),
                ),
              ],
            ),
            for (final conflict in plan.conflicts) ...[
              const SizedBox(height: 12),
              _ConflictCard(
                title: widget.labelOf?.call(conflict) ?? conflict.id,
                conflict: conflict,
                choice: _choices[conflict.key],
                enabled: !busy,
                strings: _t,
                describe: (value) =>
                    widget.describe?.call(value, conflict) ??
                    describeSyncValue(value, _t),
                onChanged: (side) =>
                    setState(() => _choices[conflict.key] = side),
              ),
            ],
          ],
          if (error != null) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                error,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
          if (!plan.isComplete) ...[
            const SizedBox(height: 16),
            Text(_t.incomplete, style: muted),
          ],
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: busy ? null : () => widget.onDone(false),
                child: Text(_t.stayLocal),
              ),
              FilledButton(
                onPressed: busy || !plan.isComplete
                    ? null
                    : () async {
                        final done = await host.resolveReview(
                          Map.of(_choices),
                        );
                        if (done && mounted) widget.onDone(true);
                      },
                child: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_t.confirm),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Plain words for a JSON value: on/off, list items, `name: value` lines.
String describeSyncValue(Object? value, SyncStrings strings) => switch (value) {
  null => strings.empty,
  true => strings.enabled,
  false => strings.disabled,
  final List<Object?> list when list.isEmpty => strings.empty,
  final List<Object?> list =>
    list.map((item) => describeSyncValue(item, strings)).join(' · '),
  final Map<Object?, Object?> map => map.entries
      .map((entry) => '${entry.key} : ${describeSyncValue(entry.value, strings)}')
      .join('\n'),
  _ => '$value',
};

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({
    required this.title,
    required this.conflict,
    required this.choice,
    required this.enabled,
    required this.strings,
    required this.describe,
    required this.onChanged,
  });

  final String title;
  final SyncConflict conflict;
  final SyncSide? choice;
  final bool enabled;
  final SyncStrings strings;
  final String Function(Object? value) describe;
  final ValueChanged<SyncSide> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: RadioGroup<SyncSide>(
        groupValue: choice,
        onChanged: (side) {
          if (side != null && enabled) onChanged(side);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Semantics(
                header: true,
                child: Text(title, style: theme.textTheme.titleSmall),
              ),
            ),
            for (final side in SyncSide.values)
              RadioListTile<SyncSide>(
                value: side,
                enabled: enabled,
                title: Text(
                  side == SyncSide.device ? strings.device : strings.account,
                ),
                subtitle: Text(describe(conflict.valueOf(side))),
              ),
          ],
        ),
      ),
    );
  }
}
