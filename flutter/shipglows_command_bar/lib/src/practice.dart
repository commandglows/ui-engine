import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'shortcuts.dart';
import 'strings.dart';
import 'theme.dart';

/// Practice open right now, so app-wide keys stand aside.
int _activePractices = 0;

/// Shortcuts practice: one card per shortcut, its keys pressed from memory.
///
/// The keys are checked against the hint's [CommandBarShortcutHint.bindings]
/// when it has some, else against its shortcut labels. Keys Windows or the
/// app catch first (Win, Alt+Tab, a global hotkey) cannot reach the practice:
/// such a card asks the user to rate themselves. While it is on screen,
/// [isActive] is true and [CommandBarScope] leaves every key to it.
class CommandBarShortcutPractice extends StatefulWidget {
  const CommandBarShortcutPractice({
    super.key,
    required this.groups,
    required this.onExit,
    this.strings = CommandBarStrings.en,
    this.random,
  });

  /// Where the cards come from: every hint with keycaps.
  final List<CommandBarShortcutGroup> groups;

  /// Back to the list.
  final VoidCallback onExit;

  final CommandBarStrings strings;

  /// Card order; a new shuffle each time when null.
  final math.Random? random;

  /// Whether a practice is on screen.
  static bool get isActive => _activePractices > 0;

  /// The cards [groups] give, as many as the practice will show.
  static int cardCount(List<CommandBarShortcutGroup> groups) =>
      _cards(groups).length;

  @override
  State<CommandBarShortcutPractice> createState() =>
      _CommandBarShortcutPracticeState();
}

/// Waiting and wrong listen to the keys; paused leaves them to the buttons.
enum _Status { waiting, wrong, paused, right, revealed }

class _Card {
  _Card(this.group, this.hint)
    : activators = [
        for (final activator in hint.bindings.keys)
          if (!_isPlainEscape(activator)) activator,
      ],
      sequences = [
        for (final shortcut in hint.shortcuts) ?_parseSequence(shortcut),
      ];

  final String group;
  final CommandBarShortcutHint hint;
  final List<ShortcutActivator> activators;
  final List<List<_Chord>> sequences;

  /// Whether the practice can see the keys.
  bool get checkable =>
      activators.isNotEmpty ||
      sequences.any((steps) => !steps.any((chord) => chord.intercepted));
}

/// Escape pauses the practice, so it cannot be an answer.
bool _isPlainEscape(ShortcutActivator activator) =>
    activator is SingleActivator &&
    activator.trigger == LogicalKeyboardKey.escape &&
    !activator.control &&
    !activator.alt &&
    !activator.shift &&
    !activator.meta;

List<_Card> _cards(List<CommandBarShortcutGroup> groups) => [
  for (final group in groups)
    for (final hint in group.hints)
      if (hint.shortcuts.isNotEmpty) _Card(group.title, hint),
];

class _CommandBarShortcutPracticeState
    extends State<CommandBarShortcutPractice> {
  final FocusNode _focus = FocusNode(debugLabel: 'CommandBarShortcutPractice');
  late List<_Card> _deck;
  int _index = 0;
  _Status _status = _Status.waiting;
  String? _typed;
  final Set<_Card> _right = {};
  final Set<_Card> _review = {};
  // Steps of each sequence already pressed, by alternative.
  List<int> _progress = const [];
  Timer? _advance;

  _Card? get _card => _index < _deck.length ? _deck[_index] : null;

  @override
  void initState() {
    super.initState();
    _activePractices++;
    _start(_cards(widget.groups));
  }

  @override
  void dispose() {
    _activePractices--;
    _advance?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _start(List<_Card> cards) {
    _advance?.cancel();
    _deck = List.of(cards)..shuffle(widget.random);
    _index = 0;
    _right.clear();
    _review.clear();
    _show();
  }

  void _show() {
    _status = _Status.waiting;
    _typed = null;
    _progress = List.filled(_card?.sequences.length ?? 0, 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _next() {
    _advance?.cancel();
    setState(() {
      _index++;
      _show();
    });
  }

  void _rate({required bool right}) {
    final card = _card;
    if (card == null) return;
    (right ? _right : _review).add(card);
    _next();
  }

  void _resume() {
    setState(() {
      _status = _Status.waiting;
      _typed = null;
      _progress = List.filled(_card?.sequences.length ?? 0, 0);
    });
    _focus.requestFocus();
  }

  void _reveal() {
    final card = _card;
    if (card == null) return;
    setState(() {
      _review.add(card);
      _status = _Status.revealed;
    });
  }

  /// Escape climbs one level: a listening card pauses, a paused card shows
  /// its answer, anything else goes back to the list.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    final escape =
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        !keyboard.isControlPressed &&
        !keyboard.isAltPressed &&
        !keyboard.isShiftPressed &&
        !keyboard.isMetaPressed;
    final card = _card;
    final listening =
        card != null &&
        card.checkable &&
        (_status == _Status.waiting || _status == _Status.wrong);
    if (card == null || !listening) {
      if (escape) {
        if (card != null && _status == _Status.paused) {
          _reveal();
        } else {
          widget.onExit();
        }
        return KeyEventResult.handled;
      }
      // Enter goes on; other keys reach the buttons (Tab).
      if (event is KeyDownEvent &&
          (_status == _Status.right || _status == _Status.revealed) &&
          (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
        _next();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (escape) {
      setState(() => _status = _Status.paused);
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) return KeyEventResult.handled;
    if (_isModifier(event.logicalKey)) return KeyEventResult.handled;
    var matched = card.activators.any(
      (activator) => activator.accepts(event, keyboard),
    );
    var advanced = false;
    for (var i = 0; i < card.sequences.length && !matched; i++) {
      final steps = card.sequences[i];
      if (steps[_progress[i]].accepts(event, keyboard)) {
        _progress[i]++;
      } else {
        _progress[i] = steps.first.accepts(event, keyboard) ? 1 : 0;
      }
      if (_progress[i] == steps.length) {
        matched = true;
      } else if (_progress[i] > 0) {
        advanced = true;
      }
    }
    setState(() {
      if (matched) {
        if (!_review.contains(card)) _right.add(card);
        _status = _Status.right;
        _advance = Timer(const Duration(milliseconds: 900), () {
          if (mounted) _next();
        });
      } else if (!advanced) {
        _progress = List.filled(card.sequences.length, 0);
        _status = _Status.wrong;
        _typed = _typedLabel(event, keyboard, widget.strings);
      }
    });
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: card == null ? _summary(context) : _cardView(context, card),
    );
  }

  Widget _cardView(BuildContext context, _Card card) {
    final style = CommandBarThemeData.of(context);
    final textTheme = Theme.of(context).textTheme;
    final strings = widget.strings;
    final checkable = card.checkable;
    final message = switch (_status) {
      _Status.waiting =>
        checkable ? strings.practicePrompt : strings.practiceSelfPrompt,
      _Status.wrong => strings.practiceWrong.replaceAll('{keys}', _typed ?? ''),
      _Status.paused => strings.practicePaused,
      _Status.right => strings.practiceRight,
      _Status.revealed => null,
    };
    final answered =
        _status == _Status.right || _status == _Status.revealed;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.practiceCard
                .replaceAll('{index}', '${_index + 1}')
                .replaceAll('{count}', '${_deck.length}'),
            style: textTheme.labelSmall?.copyWith(color: style.mutedColor),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: _deck.isEmpty ? 0 : _index / _deck.length,
            minHeight: 3,
            color: style.highlightIndicatorColor ?? style.iconColor,
            backgroundColor: style.borderColor,
          ),
          const SizedBox(height: 20),
          Text(
            card.group.toUpperCase(),
            style: textTheme.labelSmall?.copyWith(
              color: style.mutedColor,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Semantics(
            liveRegion: true,
            child: Text(
              card.hint.label,
              style: textTheme.titleLarge?.copyWith(color: style.textColor),
            ),
          ),
          const SizedBox(height: 16),
          if (message != null)
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                style: textTheme.bodyMedium?.copyWith(
                  color: _status == _Status.right
                      ? style.textColor
                      : style.mutedColor,
                  fontWeight: _status == _Status.right
                      ? FontWeight.w600
                      : null,
                ),
              ),
            ),
          if (answered || !checkable) ...[
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: CommandBarShortcutKeys(hint: card.hint, strings: strings),
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              if (!checkable && !answered) ...[
                OutlinedButton(
                  onPressed: () => _rate(right: false),
                  child: Text(strings.practiceReview),
                ),
                FilledButton(
                  onPressed: () => _rate(right: true),
                  child: Text(strings.practiceGotIt),
                ),
              ] else if (!answered) ...[
                if (_status == _Status.paused)
                  TextButton(
                    onPressed: _resume,
                    child: Text(strings.practiceResume),
                  ),
                TextButton(
                  onPressed: _reveal,
                  child: Text(strings.practiceShowAnswer),
                ),
              ] else
                FilledButton(
                  onPressed: _next,
                  child: Text(strings.practiceNext),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summary(BuildContext context) {
    final style = CommandBarThemeData.of(context);
    final textTheme = Theme.of(context).textTheme;
    final strings = widget.strings;
    final missed = [
      for (final card in _deck)
        if (!_right.contains(card)) card,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              strings.practiceSummary
                  .replaceAll('{right}', '${_deck.length - missed.length}')
                  .replaceAll('{count}', '${_deck.length}'),
              style: textTheme.titleLarge?.copyWith(color: style.textColor),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onExit,
                child: Text(strings.practiceBack),
              ),
              OutlinedButton(
                onPressed: () => setState(() => _start(_deck)),
                child: Text(strings.practiceRestart),
              ),
              if (missed.isNotEmpty)
                FilledButton(
                  autofocus: true,
                  onPressed: () => setState(() => _start(missed)),
                  child: Text(strings.practiceAgain),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One key combination of a shortcut label, as the practice checks it.
@immutable
class _Chord {
  const _Chord({
    this.key,
    this.character,
    this.control = false,
    this.alt = false,
    this.shift = false,
    this.meta = false,
  });

  /// A named key, letter or digit.
  final LogicalKeyboardKey? key;

  /// A symbol (`[`, `?`), matched by the typed character whatever Shift or
  /// AltGr it took on the user's layout.
  final String? character;

  final bool control;
  final bool alt;
  final bool shift;
  final bool meta;

  /// Whether Windows takes these keys before the app sees them.
  bool get intercepted =>
      (meta && defaultTargetPlatform == TargetPlatform.windows) ||
      (alt && !control && key == LogicalKeyboardKey.tab) ||
      (alt && !control && key == LogicalKeyboardKey.f4) ||
      (control && alt && key == LogicalKeyboardKey.delete) ||
      (control && !alt && key == LogicalKeyboardKey.escape) ||
      // Escape alone pauses the practice.
      (!control && !alt && !shift && !meta && key == LogicalKeyboardKey.escape);

  bool accepts(KeyEvent event, HardwareKeyboard keyboard) {
    final character = this.character;
    if (character != null) {
      // AltGr arrives as Ctrl+Alt.
      final altGr =
          !control &&
          !alt &&
          keyboard.isControlPressed &&
          keyboard.isAltPressed;
      if (!altGr &&
          (keyboard.isControlPressed != control ||
              keyboard.isAltPressed != alt)) {
        return false;
      }
      return keyboard.isMetaPressed == meta &&
          (event.character == character ||
              event.logicalKey.keyLabel == character);
    }
    return keyboard.isControlPressed == control &&
        keyboard.isAltPressed == alt &&
        keyboard.isShiftPressed == shift &&
        keyboard.isMetaPressed == meta &&
        event.logicalKey == key;
  }
}

final Map<String, LogicalKeyboardKey> _namedKeys = {
  for (final name in ['space', 'espace']) name: LogicalKeyboardKey.space,
  for (final name in ['enter', 'entrée', 'entree', 'return', '↵'])
    name: LogicalKeyboardKey.enter,
  for (final name in ['esc', 'escape', 'échap', 'echap'])
    name: LogicalKeyboardKey.escape,
  'tab': LogicalKeyboardKey.tab,
  for (final name in ['backspace', 'retour arrière', '⌫'])
    name: LogicalKeyboardKey.backspace,
  for (final name in ['del', 'delete', 'suppr'])
    name: LogicalKeyboardKey.delete,
  for (final name in ['ins', 'insert', 'inser'])
    name: LogicalKeyboardKey.insert,
  for (final name in ['home', 'début', 'debut']) name: LogicalKeyboardKey.home,
  for (final name in ['end', 'fin']) name: LogicalKeyboardKey.end,
  for (final name in ['pgup', 'pageup', 'page up', 'page ↑', 'page préc.'])
    name: LogicalKeyboardKey.pageUp,
  for (final name in ['pgdn', 'pagedown', 'page down', 'page ↓', 'page suiv.'])
    name: LogicalKeyboardKey.pageDown,
  for (final name in ['←', 'left']) name: LogicalKeyboardKey.arrowLeft,
  for (final name in ['→', 'right']) name: LogicalKeyboardKey.arrowRight,
  for (final name in ['↑', 'up']) name: LogicalKeyboardKey.arrowUp,
  for (final name in ['↓', 'down']) name: LogicalKeyboardKey.arrowDown,
};

const List<LogicalKeyboardKey> _functionKeys = [
  LogicalKeyboardKey.f1,
  LogicalKeyboardKey.f2,
  LogicalKeyboardKey.f3,
  LogicalKeyboardKey.f4,
  LogicalKeyboardKey.f5,
  LogicalKeyboardKey.f6,
  LogicalKeyboardKey.f7,
  LogicalKeyboardKey.f8,
  LogicalKeyboardKey.f9,
  LogicalKeyboardKey.f10,
  LogicalKeyboardKey.f11,
  LogicalKeyboardKey.f12,
  LogicalKeyboardKey.f13,
  LogicalKeyboardKey.f14,
  LogicalKeyboardKey.f15,
  LogicalKeyboardKey.f16,
  LogicalKeyboardKey.f17,
  LogicalKeyboardKey.f18,
  LogicalKeyboardKey.f19,
  LogicalKeyboardKey.f20,
  LogicalKeyboardKey.f21,
  LogicalKeyboardKey.f22,
  LogicalKeyboardKey.f23,
  LogicalKeyboardKey.f24,
];

/// The chords of one shortcut label: one for `Ctrl+K`, one per step for a
/// sequence (`G N`). Null when a part is not a key the practice knows.
List<_Chord>? _parseSequence(String label) {
  final whole = _parseChord(label);
  if (whole != null) return [whole];
  if (label.length < 2 || !label.contains(' ')) return null;
  final steps = <_Chord>[];
  for (final part in label.split(' ')) {
    if (part.isEmpty) continue;
    final chord = _parseChord(part);
    if (chord == null) return null;
    steps.add(chord);
  }
  return steps.isEmpty ? null : steps;
}

_Chord? _parseChord(String label) {
  final text = label.trim();
  if (text.isEmpty) return null;
  List<String> parts;
  if (text == '+') {
    parts = ['+'];
  } else if (text.endsWith('++')) {
    parts = [...text.substring(0, text.length - 2).split('+'), '+'];
  } else {
    parts = text.split('+');
  }
  var control = false;
  var alt = false;
  var shift = false;
  var meta = false;
  for (final modifier in parts.sublist(0, parts.length - 1)) {
    switch (modifier.trim().toLowerCase()) {
      case 'ctrl' || 'control' || 'ctl':
        control = true;
      case 'alt' || 'option' || '⌥':
        alt = true;
      case 'shift' || 'maj' || '⇧':
        shift = true;
      case 'win' || 'meta' || 'cmd' || 'command' || '⌘' || 'super':
        meta = true;
      default:
        return null;
    }
  }
  final name = parts.last.trim();
  final lower = name.toLowerCase();
  var key = _namedKeys[lower];
  final function = RegExp(r'^f([1-9]|1[0-9]|2[0-4])$').firstMatch(lower);
  if (function != null) key = _functionKeys[int.parse(function[1]!) - 1];
  if (key == null && name.runes.length == 1) {
    final code = lower.codeUnitAt(0);
    final letterOrDigit =
        (code >= 0x61 && code <= 0x7A) || (code >= 0x30 && code <= 0x39);
    if (!letterOrDigit) {
      return _Chord(character: name, control: control, alt: alt, meta: meta);
    }
    key = LogicalKeyboardKey(code);
  }
  if (key == null) return null;
  return _Chord(
    key: key,
    control: control,
    alt: alt,
    shift: shift,
    meta: meta,
  );
}

bool _isModifier(LogicalKeyboardKey key) => _modifierKeys.contains(key);

final Set<LogicalKeyboardKey> _modifierKeys = {
  LogicalKeyboardKey.control,
  LogicalKeyboardKey.controlLeft,
  LogicalKeyboardKey.controlRight,
  LogicalKeyboardKey.alt,
  LogicalKeyboardKey.altLeft,
  LogicalKeyboardKey.altRight,
  LogicalKeyboardKey.altGraph,
  LogicalKeyboardKey.shift,
  LogicalKeyboardKey.shiftLeft,
  LogicalKeyboardKey.shiftRight,
  LogicalKeyboardKey.meta,
  LogicalKeyboardKey.metaLeft,
  LogicalKeyboardKey.metaRight,
  LogicalKeyboardKey.capsLock,
};

/// « Ctrl+Maj+K »: what the user pressed, to show a wrong answer.
String _typedLabel(
  KeyEvent event,
  HardwareKeyboard keyboard,
  CommandBarStrings strings,
) {
  final label = event.logicalKey.keyLabel;
  final key = label.isNotEmpty ? label : (event.character ?? '?');
  return [
    if (keyboard.isControlPressed) 'Ctrl',
    if (keyboard.isAltPressed) 'Alt',
    if (keyboard.isShiftPressed) strings.shiftKey,
    if (keyboard.isMetaPressed)
      defaultTargetPlatform == TargetPlatform.macOS ? '⌘' : 'Win',
    key.length == 1 ? key.toUpperCase() : key,
  ].join('+');
}

/// Whether [event] presses the one key combination [label] names
/// (`Ctrl+Shift+C`, `Alt+P`), as the practice reads labels. A sequence or a
/// label the bar cannot read never matches.
bool commandBarShortcutMatches(String label, KeyEvent event) {
  if (event is KeyUpEvent || _isModifier(event.logicalKey)) return false;
  final chord = _parseChord(label);
  return chord != null && chord.accepts(event, HardwareKeyboard.instance);
}
