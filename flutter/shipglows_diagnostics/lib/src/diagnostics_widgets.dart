import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'diagnostic_event.dart';
import 'shipglows_diagnostics.dart';

/// Builds report sections from the widget tree at copy time (theme preset,
/// signed-in state...).
typedef DiagnosticSectionsBuilder =
    List<DiagnosticSection> Function(BuildContext context);

/// Texts of the diagnostic widgets. French by default; pass
/// [ShipglowsDiagnosticsLabels.english] or your own for other locales.
class ShipglowsDiagnosticsLabels {
  const ShipglowsDiagnosticsLabels({
    this.title = 'Diagnostic',
    this.description =
        'Rapport sans secrets à joindre à un signalement : version, '
        'plateforme et derniers événements.',
    this.copy = 'Copier le diagnostic',
    this.copied = 'Diagnostic copié',
    this.copyFailed =
        'Copie impossible : sélectionnez le texte du rapport à la main.',
    this.view = 'Voir le diagnostic',
    this.clear = 'Effacer les journaux',
    this.cleared = 'Journaux effacés',
    this.revealLog = 'Ouvrir le dossier du journal',
    this.revealFailed = 'Impossible d’ouvrir le dossier du journal.',
    this.close = 'Fermer',
    this.summary = _frenchSummary,
  });

  static const english = ShipglowsDiagnosticsLabels(
    title: 'Diagnostics',
    description:
        'A report without secrets to attach to a bug report: version, '
        'platform and latest events.',
    copy: 'Copy diagnostics',
    copied: 'Diagnostics copied',
    copyFailed: 'Copy failed: select the report text by hand.',
    view: 'View diagnostics',
    clear: 'Clear logs',
    cleared: 'Logs cleared',
    revealLog: 'Open log folder',
    revealFailed: 'Could not open the log folder.',
    close: 'Close',
    summary: _englishSummary,
  );

  final String title;
  final String description;
  final String copy;
  final String copied;
  final String copyFailed;
  final String view;
  final String clear;
  final String cleared;
  final String revealLog;
  final String revealFailed;
  final String close;

  /// "12 événements, dont 2 erreurs".
  final String Function(int events, int errors) summary;

  static String _frenchSummary(int events, int errors) {
    if (events == 0) return 'Aucun événement enregistré.';
    final e = events > 1 ? 's' : '';
    if (errors == 0) return '$events événement$e, aucune erreur.';
    return '$events événement$e, dont $errors erreur${errors > 1 ? 's' : ''}.';
  }

  static String _englishSummary(int events, int errors) {
    if (events == 0) return 'No event recorded.';
    final e = events > 1 ? 's' : '';
    if (errors == 0) return '$events event$e, no error.';
    return '$events event$e, $errors error${errors > 1 ? 's' : ''}.';
  }
}

/// Interface state at copy time: locale, brightness, window size, pixel
/// ratio and text scale. Added to every report the widgets copy.
DiagnosticSection diagnosticsInterfaceSection(BuildContext context) {
  final media = MediaQuery.maybeOf(context);
  final size = media?.size;
  return DiagnosticSection('Interface', {
    'locale': Localizations.maybeLocaleOf(context)?.toLanguageTag() ?? 'unknown',
    'theme': Theme.of(context).brightness.name,
    if (media != null) 'system_theme': media.platformBrightness.name,
    if (size != null)
      'window': '${size.width.round()}x${size.height.round()} logical px',
    if (media != null) 'pixel_ratio': media.devicePixelRatio.toStringAsFixed(2),
    if (media != null) 'text_scale': media.textScaler.scale(1).toStringAsFixed(2),
    if (media != null)
      'reduce_motion': '${media.disableAnimations || media.accessibleNavigation}',
  });
}

List<DiagnosticSection> _sectionsFor(
  BuildContext context,
  DiagnosticSectionsBuilder? extra,
) => [
  diagnosticsInterfaceSection(context),
  if (extra != null) ...extra(context),
];

ShipglowsDiagnostics _resolve(ShipglowsDiagnostics? diagnostics) {
  final resolved = diagnostics ?? ShipglowsDiagnostics.current;
  assert(
    resolved != null,
    'Install ShipglowsDiagnostics in main() or pass one to the widget.',
  );
  return resolved!;
}

/// Copies the report (with the interface section and [sections]). When the
/// clipboard refuses it, opens the preview so the text can be selected.
/// Returns whether the copy succeeded.
Future<bool> copyShipglowsDiagnostics(
  BuildContext context, {
  ShipglowsDiagnostics? diagnostics,
  DiagnosticSectionsBuilder? sections,
  ShipglowsDiagnosticsLabels labels = const ShipglowsDiagnosticsLabels(),
}) async {
  final target = _resolve(diagnostics);
  final copied = await target.copyReport(
    sections: _sectionsFor(context, sections),
  );
  if (!copied && context.mounted) {
    await showShipglowsDiagnosticsDialog(
      context,
      diagnostics: target,
      sections: sections,
      labels: labels,
      notice: labels.copyFailed,
    );
  }
  return copied;
}

/// Compact copy button for a header, an error view or a status bar. Shows a
/// check mark and [ShipglowsDiagnosticsLabels.copied] for two seconds.
class ShipglowsDiagnosticsButton extends StatefulWidget {
  const ShipglowsDiagnosticsButton({
    super.key,
    this.diagnostics,
    this.sections,
    this.labels = const ShipglowsDiagnosticsLabels(),
    this.iconSize,
    this.constraints,
  });

  /// Defaults to [ShipglowsDiagnostics.current].
  final ShipglowsDiagnostics? diagnostics;
  final DiagnosticSectionsBuilder? sections;
  final ShipglowsDiagnosticsLabels labels;
  final double? iconSize;
  final BoxConstraints? constraints;

  @override
  State<ShipglowsDiagnosticsButton> createState() =>
      _ShipglowsDiagnosticsButtonState();
}

class _ShipglowsDiagnosticsButtonState
    extends State<ShipglowsDiagnosticsButton> {
  Timer? _reset;
  bool _copied = false;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    final copied = await copyShipglowsDiagnostics(
      context,
      diagnostics: widget.diagnostics,
      sections: widget.sections,
      labels: widget.labels,
    );
    if (!copied || !mounted) return;
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final label = _copied ? widget.labels.copied : widget.labels.copy;
    return Semantics(
      liveRegion: _copied,
      child: IconButton(
        tooltip: label,
        onPressed: () => unawaited(_copy()),
        iconSize: widget.iconSize,
        constraints: widget.constraints,
        icon: Icon(
          _copied ? Icons.check_rounded : Icons.bug_report_outlined,
          semanticLabel: label,
        ),
      ),
    );
  }
}

/// Settings block: title, description, event summary and the actions copy,
/// view, clear logs and (desktop, with a crash file) open the log folder.
/// Feedback is shown inline, so it needs no `Scaffold`.
class ShipglowsDiagnosticsPanel extends StatefulWidget {
  const ShipglowsDiagnosticsPanel({
    super.key,
    this.diagnostics,
    this.sections,
    this.labels = const ShipglowsDiagnosticsLabels(),
    this.showTitle = true,
  });

  /// Defaults to [ShipglowsDiagnostics.current].
  final ShipglowsDiagnostics? diagnostics;
  final DiagnosticSectionsBuilder? sections;
  final ShipglowsDiagnosticsLabels labels;

  /// False when the host page already titles the section.
  final bool showTitle;

  @override
  State<ShipglowsDiagnosticsPanel> createState() =>
      _ShipglowsDiagnosticsPanelState();
}

class _ShipglowsDiagnosticsPanelState extends State<ShipglowsDiagnosticsPanel> {
  String? _status;

  ShipglowsDiagnostics get _diagnostics => _resolve(widget.diagnostics);

  void _say(String status) {
    if (mounted) setState(() => _status = status);
  }

  Future<void> _copy() async {
    final copied = await copyShipglowsDiagnostics(
      context,
      diagnostics: widget.diagnostics,
      sections: widget.sections,
      labels: widget.labels,
    );
    if (copied) _say(widget.labels.copied);
  }

  Future<void> _view() async {
    await showShipglowsDiagnosticsDialog(
      context,
      diagnostics: widget.diagnostics,
      sections: widget.sections,
      labels: widget.labels,
    );
    // The dialog may have cleared the events.
    if (mounted) setState(() {});
  }

  void _clear() {
    _diagnostics.clearEvents();
    _say(widget.labels.cleared);
  }

  Future<void> _reveal() async {
    final opened = await _diagnostics.revealCrashLog();
    if (!opened) _say(widget.labels.revealFailed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diagnostics = _diagnostics;
    final labels = widget.labels;
    final canReveal = !kIsWeb && diagnostics.crashLog.file != null;
    final status = _status;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showTitle)
          Text(labels.title, style: theme.textTheme.titleMedium),
        if (widget.showTitle) const SizedBox(height: 4),
        Text(labels.description, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(
          labels.summary(diagnostics.buffer.length, diagnostics.buffer.errorCount),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => unawaited(_copy()),
              icon: const Icon(Icons.content_copy_rounded),
              label: Text(labels.copy),
            ),
            OutlinedButton.icon(
              onPressed: () => unawaited(_view()),
              icon: const Icon(Icons.article_outlined),
              label: Text(labels.view),
            ),
            if (canReveal)
              OutlinedButton.icon(
                onPressed: () => unawaited(_reveal()),
                icon: const Icon(Icons.folder_open_outlined),
                label: Text(labels.revealLog),
              ),
            TextButton.icon(
              onPressed: diagnostics.buffer.length == 0 ? null : _clear,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: Text(labels.clear),
            ),
          ],
        ),
        if (status != null) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(status, style: theme.textTheme.bodySmall),
          ),
        ],
      ],
    );
  }
}

/// Shows the full report as selectable text, with copy and clear actions.
/// [notice] is shown above the report (used when the clipboard failed).
Future<void> showShipglowsDiagnosticsDialog(
  BuildContext context, {
  ShipglowsDiagnostics? diagnostics,
  DiagnosticSectionsBuilder? sections,
  ShipglowsDiagnosticsLabels labels = const ShipglowsDiagnosticsLabels(),
  String? notice,
}) {
  final target = _resolve(diagnostics);
  // Read from the caller's context: the dialog route has its own media query.
  final reportSections = _sectionsFor(context, sections);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _DiagnosticsDialog(
      diagnostics: target,
      sections: reportSections,
      labels: labels,
      notice: notice,
    ),
  );
}

class _DiagnosticsDialog extends StatefulWidget {
  const _DiagnosticsDialog({
    required this.diagnostics,
    required this.sections,
    required this.labels,
    this.notice,
  });

  final ShipglowsDiagnostics diagnostics;
  final List<DiagnosticSection> sections;
  final ShipglowsDiagnosticsLabels labels;
  final String? notice;

  @override
  State<_DiagnosticsDialog> createState() => _DiagnosticsDialogState();
}

class _DiagnosticsDialogState extends State<_DiagnosticsDialog> {
  late String? _status = widget.notice;

  Future<void> _copy() async {
    final copied = await widget.diagnostics.copyReport(
      sections: widget.sections,
    );
    if (!mounted) return;
    setState(
      () => _status = copied ? widget.labels.copied : widget.labels.copyFailed,
    );
  }

  void _clear() {
    widget.diagnostics.clearEvents();
    setState(() => _status = widget.labels.cleared);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = widget.labels;
    final report = widget.diagnostics.report(sections: widget.sections);
    final status = _status;
    return AlertDialog(
      title: Text(labels.title),
      content: SizedBox(
        width: 720,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (status != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(
                  liveRegion: true,
                  child: Text(status, style: theme.textTheme.bodySmall),
                ),
              ),
            Flexible(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    report,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'Consolas',
                      fontFamilyFallback: const ['Menlo', 'monospace'],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.diagnostics.buffer.length == 0 ? null : _clear,
          child: Text(labels.clear),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(labels.close),
        ),
        FilledButton.icon(
          onPressed: () => unawaited(_copy()),
          icon: const Icon(Icons.content_copy_rounded),
          label: Text(labels.copy),
        ),
      ],
    );
  }
}
