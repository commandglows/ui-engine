import 'package:flutter/material.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'feedback_kind.dart';
import 'strings.dart';

/// Icon and text of a message: the icon in the kind's color, the text in the
/// theme's text color (never the kind's, for contrast). A screen reader reads
/// « Error: message ».
class FeedbackContent extends StatelessWidget {
  const FeedbackContent({
    super.key,
    required this.message,
    this.kind = FeedbackKind.info,
    this.strings,
  });

  final String message;
  final FeedbackKind kind;

  /// Defaults to [FeedbackStrings.of] the context.
  final FeedbackStrings? strings;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final label = (strings ?? FeedbackStrings.of(context)).labelOf(kind);
    return Semantics(
      label: '$label: $message',
      excludeSemantics: true,
      child: Row(
        children: [
          Icon(kind.icon, color: kind.colorOf(theme), size: 20),
          SizedBox(width: theme.spaceMd),
          Expanded(
            child: Text(message, style: TextStyle(color: theme.text)),
          ),
        ],
      ),
    );
  }
}
