import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

/// The words around the question.
@immutable
class ReflectionPromptStrings {
  /// Creates the strings.
  const ReflectionPromptStrings({
    required this.answerLabel,
    required this.keep,
    required this.moveOn,
    required this.moveOnWithoutKeeping,
    required this.keepFailed,
  });

  /// French.
  static const fr = ReflectionPromptStrings(
    answerLabel: 'Ta réponse, si tu veux en écrire une',
    keep: 'Garder ma réponse',
    moveOn: 'Une autre question',
    moveOnWithoutKeeping: 'Continuer sans garder',
    keepFailed:
        'Ta réponse n’a pas pu être gardée sur cet appareil. Réessaie dans un instant.',
  );

  /// English.
  static const en = ReflectionPromptStrings(
    answerLabel: 'Your answer, if you want to write one',
    keep: 'Keep my answer',
    moveOn: 'Another question',
    moveOnWithoutKeeping: 'Continue without keeping',
    keepFailed: 'Your answer could not be kept on this device. Try again shortly.',
  );

  /// Label of the answer field.
  final String answerLabel;

  /// Button keeping the answer.
  final String keep;

  /// Button moving on when nothing is written.
  final String moveOn;

  /// Button moving on when something is written, which is then forgotten.
  final String moveOnWithoutKeeping;

  /// Said when keeping failed. The text stays in the field.
  final String keepFailed;
}

/// One question and a private field to answer it.
///
/// Writing is optional and moving on needs no reason. The draft is forgotten
/// when [question] changes, and when the app leaves the foreground unless
/// [forgetDraftInBackground] is false: an answer may be about something that
/// someone else must not read.
class ReflectionPrompt extends StatefulWidget {
  /// Creates the card.
  const ReflectionPrompt({
    super.key,
    required this.question,
    required this.onKeep,
    required this.onMoveOn,
    this.lens,
    this.quote,
    this.privacyNote,
    this.strings = ReflectionPromptStrings.fr,
    this.forgetDraftInBackground = true,
  });

  /// The question, the largest text.
  final String question;

  /// Small line above the question, naming its angle.
  final String? lens;

  /// Earlier words to look at again, shown above the question.
  final String? quote;

  /// Says where an answer stays, under the field.
  final String? privacyNote;

  /// Keeps the answer, trimmed. `false` keeps the text in the field and says so.
  final Future<bool> Function(String answer) onKeep;

  /// Moves on with [draft], which the card then forgets. Empty if nothing was
  /// written. An app can read it to watch for a crisis, and must not store it.
  final ValueChanged<String> onMoveOn;

  /// The words around the question.
  final ReflectionPromptStrings strings;

  /// Whether the draft is forgotten when the app leaves the foreground.
  final bool forgetDraftInBackground;

  @override
  State<ReflectionPrompt> createState() => _ReflectionPromptState();
}

class _ReflectionPromptState extends State<ReflectionPrompt>
    with WidgetsBindingObserver {
  final _answer = TextEditingController();
  bool _keeping = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(ReflectionPrompt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question != widget.question ||
        oldWidget.quote != widget.quote) {
      _answer.clear();
      _failed = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _answer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.forgetDraftInBackground &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.inactive ||
            state == AppLifecycleState.hidden)) {
      setState(_answer.clear);
    }
  }

  Future<void> _keep() async {
    if (_keeping) return;
    setState(() {
      _keeping = true;
      _failed = false;
    });
    bool kept;
    try {
      kept = await widget.onKeep(_answer.text.trim());
    } on Exception {
      kept = false;
    }
    if (!mounted) return;
    setState(() {
      _keeping = false;
      _failed = !kept;
      if (kept) _answer.clear();
    });
  }

  void _moveOn() {
    final draft = _answer.text.trim();
    setState(() {
      _answer.clear();
      _failed = false;
    });
    widget.onMoveOn(draft);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final strings = widget.strings;
    final lens = widget.lens;
    final quote = widget.quote;
    final note = widget.privacyNote;
    final written = _answer.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (lens != null) ...[
          Text(
            lens,
            style: textTheme.labelLarge?.copyWith(color: theme.textMuted),
          ),
          SizedBox(height: theme.spaceSm),
        ],
        if (quote != null) ...[
          Text(
            quote,
            style: textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
          ),
          SizedBox(height: theme.spaceMd),
        ],
        Semantics(
          header: true,
          child: Text(widget.question, style: textTheme.headlineSmall),
        ),
        SizedBox(height: theme.spaceLg),
        TextField(
          controller: _answer,
          minLines: 4,
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: strings.answerLabel,
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        if (note != null) ...[
          SizedBox(height: theme.spaceSm),
          Text(
            note,
            style: textTheme.bodySmall?.copyWith(color: theme.textMuted),
          ),
        ],
        if (_failed) ...[
          SizedBox(height: theme.spaceSm),
          Semantics(
            liveRegion: true,
            child: Text(strings.keepFailed, style: textTheme.bodyMedium),
          ),
        ],
        SizedBox(height: theme.spaceLg),
        if (written) ...[
          FilledButton(
            onPressed: _keeping ? null : () => unawaited(_keep()),
            child: Text(strings.keep),
          ),
          SizedBox(height: theme.spaceSm),
        ],
        OutlinedButton(
          onPressed: _keeping ? null : _moveOn,
          child: Text(written ? strings.moveOnWithoutKeeping : strings.moveOn),
        ),
      ],
    );
  }
}
