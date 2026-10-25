import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'feedback_kind.dart';
import 'feedback_snack_bar.dart';
import 'strings.dart';

/// What a screen or a panel shows instead of its content when loading it
/// failed: the error icon, an optional [title], the [message], an optional
/// [helperText] (what the user can do), « Retry » when [onRetry] is set, a
/// second action ([secondaryLabel], [onSecondary]: « Clear », « See plans »)
/// and « Copy details » when [details] is set. Announced when it appears.
///
/// By default centered, at most 420 wide; [compact] aligns it to the start
/// with a smaller icon and less padding, for a panel or a card.
class FeedbackErrorState extends StatelessWidget {
  const FeedbackErrorState({
    super.key,
    required this.message,
    this.title,
    this.helperText,
    this.onRetry,
    this.retryLabel,
    this.secondaryLabel,
    this.onSecondary,
    this.details,
    this.copyLabel,
    this.compact = false,
    this.selectable = false,
    this.showIcon = true,
    this.strings,
  });

  final String message;
  final String? title;

  /// What the user can do about it, under the message, muted.
  final String? helperText;

  /// Loads again; no button without it.
  final VoidCallback? onRetry;

  /// Defaults to [FeedbackStrings.retry].
  final String? retryLabel;

  /// Second action, shown as a quieter button after « Retry ».
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Technical details for a bug report, read when copied.
  final String Function()? details;

  /// Defaults to [FeedbackStrings.copyDetails].
  final String? copyLabel;

  /// Start-aligned, smaller icon and padding: for a panel or a card.
  final bool compact;

  /// Whether the message can be selected and copied by hand.
  final bool selectable;

  final bool showIcon;

  /// Defaults to [FeedbackStrings.of] the context.
  final FeedbackStrings? strings;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final texts = strings ?? FeedbackStrings.of(context);
    final title = this.title;
    final helperText = this.helperText;
    final details = this.details;
    final secondaryLabel = this.secondaryLabel;
    final onSecondary = this.onSecondary;
    final hasSecondary = secondaryLabel != null && onSecondary != null;
    final align = compact ? TextAlign.start : TextAlign.center;
    final messageStyle = textTheme.bodyMedium?.copyWith(
      color: title == null ? theme.text : theme.textMuted,
    );
    final column = Semantics(
      container: true,
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: compact
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          if (showIcon) ...[
            ExcludeSemantics(
              child: Icon(
                FeedbackKind.error.icon,
                color: theme.danger,
                size: compact ? 24 : 40,
              ),
            ),
            SizedBox(height: compact ? theme.spaceSm : theme.spaceMd),
          ],
          if (title != null) ...[
            Text(
              title,
              textAlign: align,
              style: textTheme.titleMedium?.copyWith(color: theme.text),
            ),
            SizedBox(height: theme.spaceSm),
          ],
          if (selectable)
            SelectableText(message, textAlign: align, style: messageStyle)
          else
            Text(message, textAlign: align, style: messageStyle),
          if (helperText != null) ...[
            SizedBox(height: theme.spaceSm),
            Text(
              helperText,
              textAlign: align,
              style: textTheme.bodySmall?.copyWith(color: theme.textMuted),
            ),
          ],
          if (onRetry != null || hasSecondary || details != null) ...[
            SizedBox(height: compact ? theme.spaceMd : theme.spaceLg),
            Wrap(
              alignment: compact ? WrapAlignment.start : WrapAlignment.center,
              spacing: theme.spaceSm,
              runSpacing: theme.spaceSm,
              children: [
                if (onRetry != null)
                  FilledButton(
                    onPressed: onRetry,
                    child: Text(retryLabel ?? texts.retry),
                  ),
                if (secondaryLabel != null && onSecondary != null)
                  OutlinedButton(
                    onPressed: onSecondary,
                    child: Text(secondaryLabel),
                  ),
                if (details != null)
                  TextButton(
                    onPressed: () =>
                        copyFeedbackDetails(context, details, texts),
                    child: Text(copyLabel ?? texts.copyDetails),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
    if (compact) {
      return Padding(padding: EdgeInsets.all(theme.spaceMd), child: column);
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(padding: EdgeInsets.all(theme.spaceXl), child: column),
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
