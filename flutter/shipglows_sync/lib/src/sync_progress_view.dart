import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'sync_progress.dart';
import 'sync_strings.dart';

/// Shows [progress] above [child] while an account's data first reaches the
/// device: the app beneath keeps its state but takes no input until the
/// steps are done; the final notice can be closed at once.
class SyncProgressOverlay extends StatelessWidget {
  const SyncProgressOverlay({
    super.key,
    required this.progress,
    required this.child,
    this.strings = SyncStrings.fr,
  });

  final SyncProgress progress;
  final Widget child;
  final SyncStrings strings;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: progress,
    child: child,
    builder: (context, child) {
      final stage = progress.stage;
      return Stack(
        children: [
          child!,
          if (stage != null)
            Positioned.fill(
              child: SyncProgressView(progress: progress, strings: strings),
            ),
        ],
      );
    },
  );
}

/// The first-sync card: a kicker, the current step's title and message,
/// and the list of steps done and to come.
class SyncProgressView extends StatelessWidget {
  const SyncProgressView({
    super.key,
    required this.progress,
    this.strings = SyncStrings.fr,
  });

  final SyncProgress progress;
  final SyncStrings strings;

  static const _steps = [
    SyncStage.waitingServer,
    SyncStage.dataReceived,
    SyncStage.dataApplied,
  ];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: progress,
    builder: (context, _) {
      final stage = progress.stage;
      if (stage == null) return const SizedBox.shrink();
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      final done = stage == SyncStage.ready;
      final reduceMotion = MediaQuery.disableAnimationsOf(context);
      final width = MediaQuery.sizeOf(context).width;

      return Material(
        color: theme.scaffoldBackgroundColor,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: math.min(560, width - 32),
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.10),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Semantics(
                  liveRegion: true,
                  container: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (done ? strings.progressDoneKicker : strings.progressKicker)
                            .toUpperCase(),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.primary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Semantics(
                        header: true,
                        child: Text(
                          strings.stageTitles[stage] ?? '',
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        strings.stageMessages[stage] ?? '',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      for (final step in _steps)
                        _Step(
                          label: strings.stageSteps[step] ?? '',
                          state: step.index < stage.index || done
                              ? _StepState.done
                              : step == stage
                              ? _StepState.current
                              : _StepState.todo,
                          reduceMotion: reduceMotion,
                        ),
                      if (done) ...[
                        const SizedBox(height: 24),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: FilledButton(
                            onPressed: progress.reset,
                            child: Text(strings.close),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

enum _StepState { done, current, todo }

class _Step extends StatelessWidget {
  const _Step({
    required this.label,
    required this.state,
    required this.reduceMotion,
  });

  final String label;
  final _StepState state;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Widget icon = switch (state) {
      _StepState.done => Icon(
        Icons.check_circle,
        size: 20,
        color: scheme.primary,
      ),
      _StepState.current when !reduceMotion => const SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      _StepState.current => Icon(
        Icons.radio_button_checked,
        size: 20,
        color: scheme.primary,
      ),
      _StepState.todo => Icon(
        Icons.radio_button_unchecked,
        size: 20,
        color: scheme.outline,
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox.square(dimension: 20, child: Center(child: icon)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: state == _StepState.todo
                    ? scheme.onSurfaceVariant
                    : scheme.onSurface,
                fontWeight: state == _StepState.current
                    ? FontWeight.w600
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
