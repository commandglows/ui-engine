import 'package:flutter/material.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'feedback_kind.dart';
import 'strings.dart';

/// Icon and text of a message: the icon in the kind's color, the text in the
/// theme's text color (never the kind's, for contrast). A screen reader reads
/// « Error: message ».
///
/// Takes the full width given. [liveRegion] announces it when it appears or
/// changes: set it for a message shown in place (under a form); a snack bar
/// already announces its own.
class FeedbackContent extends StatelessWidget {
  const FeedbackContent({
    super.key,
    required this.message,
    this.kind = FeedbackKind.info,
    this.strings,
    this.liveRegion = false,
    this.textColor,
    this.iconColor,
  });

  final String message;
  final FeedbackKind kind;

  /// Defaults to [FeedbackStrings.of] the context.
  final FeedbackStrings? strings;

  /// Whether a screen reader announces it when it appears or changes.
  final bool liveRegion;

  /// Defaults to the theme's text color.
  final Color? textColor;

  /// Defaults to the kind's color.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final label = (strings ?? FeedbackStrings.of(context)).labelOf(kind);
    return Semantics(
      label: '$label: $message',
      liveRegion: liveRegion,
      excludeSemantics: true,
      child: Row(
        children: [
          Icon(kind.icon, color: iconColor ?? kind.colorOf(theme), size: 20),
          SizedBox(width: theme.spaceMd),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: textColor ?? theme.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// A message shown in place: under a form, at the top of a panel, in a
/// list. A box tinted with the kind's color, an optional bold [title] over
/// the [message], announced when it appears or changes.
///
/// Sized to its content ([dense]: tighter padding, smaller icon), so it
/// fits in a [Row] or a [Wrap] as well as a [Column]; [trailing] holds an
/// action beside the text (a « Retry » text button), [actions] one or more
/// under it.
class FeedbackInline extends StatelessWidget {
  const FeedbackInline({
    super.key,
    required this.message,
    this.kind = FeedbackKind.info,
    this.title,
    this.dense = false,
    this.trailing,
    this.actions = const [],
    this.strings,
  });

  final String message;
  final FeedbackKind kind;
  final String? title;
  final bool dense;
  final Widget? trailing;

  /// Buttons under the message, start-aligned, wrapping when narrow.
  final List<Widget> actions;

  /// Defaults to [FeedbackStrings.of] the context.
  final FeedbackStrings? strings;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final tone = kind.colorOf(theme);
    final label = (strings ?? FeedbackStrings.of(context)).labelOf(kind);
    final title = this.title;
    final padding = dense ? theme.spaceSm : theme.spaceMd;
    return Semantics(
      container: true,
      liveRegion: true,
      label: title == null ? '$label: $message' : '$label: $title. $message',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            tone.withValues(alpha: 0.10),
            theme.surfaceRaised,
          ),
          borderRadius: BorderRadius.circular(theme.radiusMd),
          border: Border.all(
            color: tone.withValues(alpha: 0.45),
            width: theme.lineWidth,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(kind.icon, color: tone, size: dense ? 18 : 20),
              ),
              SizedBox(width: dense ? theme.spaceSm : theme.spaceMd),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (title != null)
                            Text(
                              title,
                              style: textTheme.titleSmall?.copyWith(
                                color: theme.text,
                              ),
                            ),
                          Text(
                            message,
                            style:
                                (dense
                                        ? textTheme.bodySmall
                                        : textTheme.bodyMedium)
                                    ?.copyWith(color: theme.text),
                          ),
                        ],
                      ),
                    ),
                    if (actions.isNotEmpty) ...[
                      SizedBox(height: theme.spaceSm),
                      Wrap(
                        spacing: theme.spaceSm,
                        runSpacing: theme.spaceXs,
                        children: actions,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing case final trailing?) ...[
                SizedBox(width: theme.spaceSm),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
