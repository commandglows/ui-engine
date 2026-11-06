import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shipglows_lifeline_core/shipglows_lifeline_core.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

/// Readable width of the page on large screens.
const double _maxContentWidth = 560;

/// How firmly a suggestion is offered.
enum LifelineEmphasis { strong, normal, quiet }

/// Something the page offers.
@immutable
class LifelineSuggestion {
  /// A number to call or text. The page stays open afterwards.
  const LifelineSuggestion.contact(
    LifelineContact this.contact, {
    this.emphasis = LifelineEmphasis.normal,
  }) : title = null,
       detail = null,
       onSelected = null;

  /// Something to do in the app. The page closes, then [onSelected] runs.
  const LifelineSuggestion.action({
    required String this.title,
    required VoidCallback this.onSelected,
    this.detail,
    this.emphasis = LifelineEmphasis.normal,
  }) : contact = null;

  /// The number, for a contact.
  final LifelineContact? contact;

  /// The label, for an action.
  final String? title;

  /// Line under the label, for an action.
  final String? detail;

  /// What an action does.
  final VoidCallback? onSelected;

  /// How firmly it is offered.
  final LifelineEmphasis emphasis;
}

/// What the page says at one level. Written by the app.
@immutable
class LifelineContent {
  /// Creates the content.
  const LifelineContent({
    required this.title,
    required this.message,
    required this.suggestions,
    required this.dismissLabel,
    required this.callFailed,
    this.reason,
    this.emergencyColor,
    this.onEmergencyColor,
  });

  /// First sentence, the largest.
  final String title;

  /// A few words under the title.
  final String message;

  /// Why the page appears, as an observation of what the person noted.
  final String? reason;

  /// What is offered, in order.
  final List<LifelineSuggestion> suggestions;

  /// Label of the button leaving the page.
  final String dismissLabel;

  /// Says which number to dial by hand when a call could not start.
  final String Function(String number) callFailed;

  /// Fill of a strong emergency button; the theme's danger by default.
  final Color? emergencyColor;

  /// Text on a strong emergency button; the scheme's onError by default.
  final Color? onEmergencyColor;
}

/// Opens the page. It completes when the page closes, however it closes.
Future<void> showLifelinePage({
  required BuildContext context,
  required LifelineContent content,
  required Future<bool> Function(LifelineContact contact) onContact,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => LifelinePage(content: content, onContact: onContact),
  ),
);

/// The full page. Use [showLifelinePage], or place it in your own route.
class LifelinePage extends StatefulWidget {
  /// Creates the page.
  const LifelinePage({
    super.key,
    required this.content,
    required this.onContact,
  });

  /// What the page says.
  final LifelineContent content;

  /// Places the call or opens the text message; `false` if it could not.
  final Future<bool> Function(LifelineContact contact) onContact;

  @override
  State<LifelinePage> createState() => _LifelinePageState();
}

class _LifelinePageState extends State<LifelinePage> {
  String? _callFailure;

  Future<void> _reach(LifelineContact contact) async {
    bool reached;
    try {
      reached = await widget.onContact(contact);
    } on Exception {
      reached = false;
    }
    if (!mounted) return;
    setState(() {
      _callFailure = reached ? null : widget.content.callFailed(contact.number);
    });
  }

  void _run(VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final content = widget.content;
    final reason = content.reason;
    final failure = _callFailure;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.all(theme.spaceLg),
                    children: [
                      SizedBox(height: theme.spaceXl),
                      Semantics(
                        header: true,
                        child: Text(
                          content.title,
                          style: textTheme.headlineMedium,
                        ),
                      ),
                      SizedBox(height: theme.spaceMd),
                      Text(content.message, style: textTheme.bodyLarge),
                      if (reason != null) ...[
                        SizedBox(height: theme.spaceSm),
                        Text(
                          reason,
                          style: textTheme.bodyMedium?.copyWith(
                            color: theme.textMuted,
                          ),
                        ),
                      ],
                      SizedBox(height: theme.spaceXl),
                      for (final suggestion in content.suggestions) ...[
                        _SuggestionButton(
                          suggestion: suggestion,
                          emergencyColor: content.emergencyColor,
                          onEmergencyColor: content.onEmergencyColor,
                          onContact: (contact) => unawaited(_reach(contact)),
                          onAction: _run,
                        ),
                        SizedBox(height: theme.spaceSm),
                      ],
                    ],
                  ),
                ),
                // Outside the list: however long it is, leaving stays on screen,
                // and so does the number to dial when a call failed.
                if (failure != null)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: theme.spaceLg),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(failure, style: textTheme.bodyLarge),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.all(theme.spaceSm),
                  child: TextButton(
                    style: TextButton.styleFrom(foregroundColor: theme.text),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(content.dismissLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionButton extends StatelessWidget {
  const _SuggestionButton({
    required this.suggestion,
    required this.emergencyColor,
    required this.onEmergencyColor,
    required this.onContact,
    required this.onAction,
  });

  final LifelineSuggestion suggestion;
  final Color? emergencyColor;
  final Color? onEmergencyColor;
  final ValueChanged<LifelineContact> onContact;
  final ValueChanged<VoidCallback> onAction;

  @override
  Widget build(BuildContext context) {
    final contact = suggestion.contact;
    final onSelected = suggestion.onSelected;
    final VoidCallback onPressed = contact != null
        ? () => onContact(contact)
        : () => onAction(onSelected!);
    final title = contact != null
        ? '${contact.number} · ${contact.name}'
        : suggestion.title!;
    final detail = contact?.detail ?? suggestion.detail;
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (detail != null) Text(detail),
        ],
      ),
    );
    final theme = ShipglowsTheme.of(context);
    final emergency = contact?.emergency ?? false;
    const size = Size.fromHeight(56);
    return switch (suggestion.emphasis) {
      LifelineEmphasis.strong => FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: size,
          alignment: AlignmentDirectional.centerStart,
          backgroundColor: emergency
              ? emergencyColor ?? theme.danger
              : theme.accent,
          foregroundColor: emergency
              ? onEmergencyColor ?? Theme.of(context).colorScheme.onError
              : theme.onAccent,
        ),
        onPressed: onPressed,
        child: child,
      ),
      LifelineEmphasis.normal => OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: size,
          alignment: AlignmentDirectional.centerStart,
          foregroundColor: theme.text,
        ),
        onPressed: onPressed,
        child: child,
      ),
      LifelineEmphasis.quiet => TextButton(
        style: TextButton.styleFrom(
          minimumSize: size,
          alignment: AlignmentDirectional.centerStart,
          foregroundColor: theme.text,
        ),
        onPressed: onPressed,
        child: child,
      ),
    };
  }
}
