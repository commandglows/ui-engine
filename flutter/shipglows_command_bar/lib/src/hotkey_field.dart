import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'hotkey.dart';
import 'strings.dart';
import 'theme.dart';

/// The app's single setting for the command bar's hotkey: its keycaps, a
/// tap to record another combination, and a way back to [defaultValue].
///
/// It only reports the choice through [onChanged]; saving it (preferences
/// on the web, the native shell on Windows) is up to the app.
class CommandBarHotkeyField extends StatefulWidget {
  const CommandBarHotkeyField({
    super.key,
    required this.value,
    required this.onChanged,
    this.strings = CommandBarStrings.en,
    this.defaultValue = CommandBarHotkey.standard,
    this.enabled = true,
  });

  /// The hotkey in use.
  final CommandBarHotkey value;

  /// Called with a valid new combination.
  final ValueChanged<CommandBarHotkey> onChanged;

  final CommandBarStrings strings;

  /// Restored by the reset button, shown while [value] differs from it.
  final CommandBarHotkey defaultValue;

  /// Whether the field can record (false while a change is being saved).
  final bool enabled;

  /// Whether a field is recording: the bar's hotkey then waits, so pressing
  /// the current combination records it instead of opening the bar.
  static bool get isRecording => _recording > 0;
  static int _recording = 0;

  @override
  State<CommandBarHotkeyField> createState() => _CommandBarHotkeyFieldState();
}

class _CommandBarHotkeyFieldState extends State<CommandBarHotkeyField> {
  final FocusNode _focus = FocusNode(debugLabel: 'CommandBarHotkeyField');
  bool _recording = false;
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _setRecording(false);
    _focus
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  /// Leaving the field stops recording.
  void _onFocusChanged() {
    if (!_focus.hasFocus && _recording) setState(() => _setRecording(false));
  }

  void _setRecording(bool recording) {
    if (recording == _recording) return;
    _recording = recording;
    CommandBarHotkeyField._recording += recording ? 1 : -1;
    if (!recording) _invalid = false;
  }

  void _start() {
    setState(() => _setRecording(true));
    _focus.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_recording) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.handled;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() => _setRecording(false));
      return KeyEventResult.handled;
    }
    final hotkey = CommandBarHotkey.fromKeyEvent(event);
    // A modifier alone waits for the key that completes the combination.
    if (hotkey == null) return KeyEventResult.handled;
    if (!hotkey.isValid) {
      setState(() => _invalid = true);
      return KeyEventResult.handled;
    }
    setState(() => _setRecording(false));
    if (hotkey != widget.value) widget.onChanged(hotkey);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final style = CommandBarThemeData.of(context);
    final muted = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: style.mutedColor);
    final recording = _recording;
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                button: true,
                label: recording
                    ? strings.hotkeyPress
                    : '${strings.hotkeyChange}, ${widget.value.label}',
                excludeSemantics: true,
                child: OutlinedButton(
                  onPressed: widget.enabled
                      ? (recording
                            ? () => setState(() => _setRecording(false))
                            : _start)
                      : null,
                  child: recording
                      ? Text(strings.hotkeyPress)
                      : CommandBarKeys(keys: widget.value.keys()),
                ),
              ),
              if (!recording && widget.value != widget.defaultValue)
                IconButton(
                  tooltip: strings.hotkeyReset,
                  onPressed: widget.enabled
                      ? () => widget.onChanged(widget.defaultValue)
                      : null,
                  icon: const Icon(Icons.restart_alt_rounded),
                ),
            ],
          ),
          if (recording && _invalid) ...[
            const SizedBox(height: 4),
            Text(strings.hotkeyInvalid, style: muted),
          ],
        ],
      ),
    );
  }
}
