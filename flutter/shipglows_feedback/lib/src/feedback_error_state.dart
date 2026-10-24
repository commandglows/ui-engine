import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'feedback_kind.dart';
import 'feedback_snack_bar.dart';
import 'strings.dart';

/// What a screen shows instead of its content when loading it failed: the
/// error icon, an optional [title], the [message], « Retry » when [onRetry]
/// is set and « Copy details » when [details] is. Centered, at most 420
/// wide, announced when it appears.
class FeedbackErrorState extends StatelessWidget {
  const FeedbackErrorState({
    super.key,
    required this.message,
    this.title,
    this.onRetry,
    this.retryLabel,
    this.details,
    this.strings,
  });

  final String message;
  final String? title;

  /// Loads again; no button without it.
  final VoidCallback? onRetry;

  /// Defaults to [FeedbackStrings.retry].
  final String? retryLabel;

  /// Technical details for a bug report, read when copied.
  final String Function()? details;

  /// Defaults to [FeedbackStrings.of] the context.
  final FeedbackStrings? strings;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final texts = strings ?? FeedbackStrings.of(context);
    final title = this.title;
    final details = this.details;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: EdgeInsets.all(theme.spaceXl),
          child: Semantics(
            container: true,
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    FeedbackKind.error.icon,
                    color: theme.danger,
                    size: 40,
                  ),
                ),
                SizedBox(height: theme.spaceMd),
                if (title != null) ...[
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(color: theme.text),
                  ),
                  SizedBox(height: theme.spaceSm),
                ],
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: title == null ? theme.text : theme.textMuted,
                  ),
                ),
                if (onRetry != null || details != null) ...[
                  SizedBox(height: theme.spaceLg),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: theme.spaceSm,
                    runSpacing: theme.spaceSm,
                    children: [
                      if (onRetry != null)
                        FilledButton(
                          onPressed: onRetry,
                          child: Text(retryLabel ?? texts.retry),
                        ),
                      if (details != null)
                        TextButton(
                          onPressed: () =>
                              copyFeedbackDetails(context, details, texts),
                          child: Text(texts.copyDetails),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Puts [details] on the clipboard and confirms it with a short message.
Future<void> copyFeedbackDetails(
  BuildContext context,
  String Function() details, [
  FeedbackStrings? strings,
]) async {
  final feedback = FeedbackMessenger.of(context);
  final texts = strings ?? FeedbackStrings.of(context);
  await Clipboard.setData(ClipboardData(text: details()));
  feedback.show(texts.detailsCopied, replaceCurrent: true);
}
