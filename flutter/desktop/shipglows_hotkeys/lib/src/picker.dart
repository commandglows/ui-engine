// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'hotkey.dart';
import 'hotkeys.dart';
import 'trigger.dart';

/// Every word the trigger picker shows.
@immutable
class ShipglowsTriggerPickerLabels {
  const ShipglowsTriggerPickerLabels({
    this.trigger = ShipglowsTriggerLabels.en,
    this.mouse = 'Mouse',
    this.keys = 'Shortcut',
    this.doubleKey = 'Key ×2',
    this.gesture = 'Gesture',
    this.button = 'Button',
    this.where = 'Where',
    this.click = 'Click',
    this.hold = 'Press and hold',
    this.drag = 'Drag',
    this.wheelUp = 'Wheel up',
    this.wheelDown = 'Wheel down',
    this.touch = 'Touch a corner',
    this.left = 'Left',
    this.right = 'Right',
    this.middle = 'Wheel',
    this.x1 = 'Back',
    this.x2 = 'Forward',
    this.anywhere = 'Anywhere (with a key)',
    this.titleBar = 'Title bar',
    this.taskbar = 'Taskbar',
    this.minimizeButton = 'Minimize button',
    this.maximizeButton = 'Maximize button',
    this.closeButton = 'Close button',
    this.cornerTopLeft = 'Top-left corner',
    this.cornerTopRight = 'Top-right corner',
    this.cornerBottomLeft = 'Bottom-left corner',
    this.cornerBottomRight = 'Bottom-right corner',
    this.captureKeys = 'Press the shortcut (with Ctrl, Alt, Shift or Win).',
    this.captureDoubleKey =
        'Press the key. It fires on the second press; the first one still '
        'reaches the application.',
    this.nothingChosen = 'Nothing chosen yet.',
    this.notUsable = 'This trigger cannot be used:',
    this.whyKeys = 'add Ctrl, Alt, Shift or Win (a function key is enough).',
    this.whyDoubleKey = 'choose a plain key.',
    this.whyAnywhere =
        '« Anywhere » needs a key (Ctrl, Alt, Shift or Win), or the mouse '
        'would stop working normally.',
    this.whyPlainClick =
        'a plain left click is reserved. Add a key or choose « Press and '
        'hold ».',
    this.whyOther = 'this combination is not possible.',
    this.cancel = 'Cancel',
    this.choose = 'Choose',
  });

  static const en = ShipglowsTriggerPickerLabels();

  static const fr = ShipglowsTriggerPickerLabels(
    trigger: ShipglowsTriggerLabels.fr,
    mouse: 'Souris',
    keys: 'Raccourci',
    doubleKey: 'Touche ×2',
    gesture: 'Geste',
    button: 'Bouton',
    where: 'Où',
    click: 'Clic',
    hold: 'Clic maintenu',
    drag: 'Glisser',
    wheelUp: 'Molette vers le haut',
    wheelDown: 'Molette vers le bas',
    touch: 'Toucher un coin',
    left: 'Gauche',
    right: 'Droit',
    middle: 'Molette',
    x1: 'Précédent',
    x2: 'Suivant',
    anywhere: 'Partout (avec une touche)',
    titleBar: 'Barre de titre',
    taskbar: 'Barre des tâches',
    minimizeButton: 'Bouton Réduire',
    maximizeButton: 'Bouton Agrandir',
    closeButton: 'Bouton Fermer',
    cornerTopLeft: 'Coin haut gauche',
    cornerTopRight: 'Coin haut droit',
    cornerBottomLeft: 'Coin bas gauche',
    cornerBottomRight: 'Coin bas droit',
    captureKeys: 'Appuie sur le raccourci (avec Ctrl, Alt, Maj ou Win).',
    captureDoubleKey:
        'Appuie sur la touche, elle se déclenche à la deuxième pression. La '
        'première passe quand même à l’application.',
    nothingChosen: 'Aucun déclencheur choisi.',
    notUsable: 'Ce déclencheur n’est pas utilisable :',
    whyKeys: 'ajoute Ctrl, Alt, Maj ou Win (une touche de fonction suffit).',
    whyDoubleKey: 'choisis une touche simple.',
    whyAnywhere:
        '« Partout » demande une touche (Ctrl, Alt, Maj ou Win), sinon la '
        'souris ne marcherait plus normalement.',
    whyPlainClick:
        'un simple clic gauche est réservé. Ajoute une touche ou choisis '
        '« Clic maintenu ».',
    whyOther: 'cette combinaison n’est pas possible.',
    cancel: 'Annuler',
    choose: 'Choisir',
  );

  /// Words of the chosen trigger's label.
  final ShipglowsTriggerLabels trigger;

  final String mouse;
  final String keys;
  final String doubleKey;
  final String gesture;
  final String button;
  final String where;
  final String click;
  final String hold;
  final String drag;
  final String wheelUp;
  final String wheelDown;
  final String touch;
  final String left;
  final String right;
  final String middle;
  final String x1;
  final String x2;
  final String anywhere;
  final String titleBar;
  final String taskbar;
  final String minimizeButton;
  final String maximizeButton;
  final String closeButton;
  final String cornerTopLeft;
  final String cornerTopRight;
  final String cornerBottomLeft;
  final String cornerBottomRight;
  final String captureKeys;
  final String captureDoubleKey;
  final String nothingChosen;
  final String notUsable;
  final String whyKeys;
  final String whyDoubleKey;
  final String whyAnywhere;
  final String whyPlainClick;
  final String whyOther;
  final String cancel;
  final String choose;

  String gestureName(ShipglowsMouseGesture gesture) => switch (gesture) {
    ShipglowsMouseGesture.click => click,
    ShipglowsMouseGesture.hold => hold,
    ShipglowsMouseGesture.drag => drag,
    ShipglowsMouseGesture.wheelUp => wheelUp,
    ShipglowsMouseGesture.wheelDown => wheelDown,
    ShipglowsMouseGesture.touch => touch,
  };

  String buttonName(ShipglowsMouseButton button) => switch (button) {
    ShipglowsMouseButton.left => left,
    ShipglowsMouseButton.right => right,
    ShipglowsMouseButton.middle => middle,
    ShipglowsMouseButton.x1 => x1,
    ShipglowsMouseButton.x2 => x2,
  };

  String zoneName(ShipglowsZone zone) => switch (zone) {
    ShipglowsZone.anywhere => anywhere,
    ShipglowsZone.titleBar => titleBar,
    ShipglowsZone.taskbar => taskbar,
    ShipglowsZone.minimizeButton => minimizeButton,
    ShipglowsZone.maximizeButton => maximizeButton,
    ShipglowsZone.closeButton => closeButton,
    ShipglowsZone.cornerTopLeft => cornerTopLeft,
    ShipglowsZone.cornerTopRight => cornerTopRight,
    ShipglowsZone.cornerBottomLeft => cornerBottomLeft,
    ShipglowsZone.cornerBottomRight => cornerBottomRight,
  };
}

enum _Mode { keys, doubleKey, mouse }

/// Asks the user for a trigger: a shortcut, a key pressed twice, or a mouse
/// gesture (with keys held for « mouse + keyboard »). Returns the trigger, or
/// null when the user cancels.
///
/// Give [hotkeys] so the app's triggers rest while the dialog is open
/// ([ShipglowsHotkeys.whileSuspended]): otherwise a shortcut already in use
/// would fire, or be swallowed by Windows, instead of being recorded.
///
/// [allowKeys], [allowDoubleKey] and [allowMouse] narrow the kinds offered.
Future<ShipglowsTrigger?> showShipglowsTriggerPicker(
  BuildContext context, {
  required String title,
  ShipglowsTrigger? current,
  ShipglowsHotkeys? hotkeys,
  ShipglowsTriggerPickerLabels labels = ShipglowsTriggerPickerLabels.en,
  bool allowKeys = true,
  bool allowDoubleKey = true,
  bool allowMouse = true,
}) {
  Future<ShipglowsTrigger?> show() async {
    if (!context.mounted) return null;
    return showDialog<ShipglowsTrigger>(
      context: context,
      builder: (context) => _PickerDialog(
        title: title,
        current: current,
        labels: labels,
        allowKeys: allowKeys,
        allowDoubleKey: allowDoubleKey,
        allowMouse: allowMouse,
      ),
    );
  }

  return hotkeys == null ? show() : hotkeys.whileSuspended(show);
}

class _PickerDialog extends StatefulWidget {
  const _PickerDialog({
    required this.title,
    required this.labels,
    required this.allowKeys,
    required this.allowDoubleKey,
    required this.allowMouse,
    this.current,
  });

  final String title;
  final ShipglowsTrigger? current;
  final ShipglowsTriggerPickerLabels labels;
  final bool allowKeys;
  final bool allowDoubleKey;
  final bool allowMouse;

  @override
  State<_PickerDialog> createState() => _PickerDialogState();
}

class _PickerDialogState extends State<_PickerDialog> {
  ShipglowsTrigger? _trigger;

  @override
  Widget build(BuildContext context) {
    final trigger = _trigger;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 460,
        child: ShipglowsTriggerPicker(
          initial: widget.current,
          labels: widget.labels,
          allowKeys: widget.allowKeys,
          allowDoubleKey: widget.allowDoubleKey,
          allowMouse: widget.allowMouse,
          onChanged: (trigger) => setState(() => _trigger = trigger),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.labels.cancel),
        ),
        FilledButton(
          onPressed: trigger != null && trigger.isValid
              ? () => Navigator.of(context).pop(trigger)
              : null,
          child: Text(widget.labels.choose),
        ),
      ],
    );
  }
}

/// The picker itself, to put in a dialog, a sheet or a page: kind of trigger,
/// its fields, and why a choice cannot be used. [onChanged] gets the trigger
/// as it stands (null when nothing is chosen, possibly not
/// [ShipglowsTrigger.isValid]).
///
/// Records keys with the platform key code, so it is for Windows desktop apps.
class ShipglowsTriggerPicker extends StatefulWidget {
  const ShipglowsTriggerPicker({
    required this.onChanged,
    super.key,
    this.initial,
    this.labels = ShipglowsTriggerPickerLabels.en,
    this.allowKeys = true,
    this.allowDoubleKey = true,
    this.allowMouse = true,
  }) : assert(allowKeys || allowDoubleKey || allowMouse);

  final ShipglowsTrigger? initial;
  final ValueChanged<ShipglowsTrigger?> onChanged;
  final ShipglowsTriggerPickerLabels labels;
  final bool allowKeys;
  final bool allowDoubleKey;
  final bool allowMouse;

  @override
  State<ShipglowsTriggerPicker> createState() => _TriggerPickerState();
}

class _TriggerPickerState extends State<ShipglowsTriggerPicker> {
  final FocusNode _focus = FocusNode();
  late _Mode _mode;

  ShipglowsHotkey? _hotkey;
  int? _doubleKey;

  ShipglowsMouseGesture _gesture = ShipglowsMouseGesture.wheelDown;
  ShipglowsMouseButton _button = ShipglowsMouseButton.left;
  ShipglowsZone _zone = ShipglowsZone.titleBar;
  bool _control = false;
  bool _alt = false;
  bool _shift = false;
  bool _meta = false;

  ShipglowsTriggerPickerLabels get _labels => widget.labels;

  @override
  void initState() {
    super.initState();
    _mode = widget.allowMouse
        ? _Mode.mouse
        : widget.allowKeys
        ? _Mode.keys
        : _Mode.doubleKey;
    switch (widget.initial) {
      case ShipglowsKeyTrigger(:final hotkey) when widget.allowKeys:
        _mode = _Mode.keys;
        _hotkey = hotkey;
      case ShipglowsDoubleKeyTrigger(:final key) when widget.allowDoubleKey:
        _mode = _Mode.doubleKey;
        _doubleKey = key;
      case ShipglowsMouseTrigger trigger when widget.allowMouse:
        _gesture = trigger.gesture;
        _button = trigger.button ?? ShipglowsMouseButton.left;
        _zone = trigger.zone;
        _control = trigger.control;
        _alt = trigger.alt;
        _shift = trigger.shift;
        _meta = trigger.meta;
      default:
        break;
    }
    // The first value is reported once the first frame is built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onChanged(_trigger);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  bool get _needsButton =>
      _gesture == ShipglowsMouseGesture.click ||
      _gesture == ShipglowsMouseGesture.hold ||
      _gesture == ShipglowsMouseGesture.drag;

  bool get _isTouch => _gesture == ShipglowsMouseGesture.touch;

  bool get _anyModifier => _control || _alt || _shift || _meta;

  ShipglowsTrigger? get _trigger => switch (_mode) {
    _Mode.keys => _hotkey == null ? null : ShipglowsKeyTrigger(_hotkey!),
    _Mode.doubleKey =>
      _doubleKey == null ? null : ShipglowsDoubleKeyTrigger(_doubleKey!),
    _Mode.mouse => ShipglowsMouseTrigger(
      _gesture,
      button: _needsButton ? _button : null,
      zone: _zone,
      control: _control,
      alt: _alt,
      shift: _shift,
      meta: _meta,
    ),
  };

  void _change(VoidCallback change) {
    setState(change);
    widget.onChanged(_trigger);
  }

  void _onKey(RawKeyEvent event) {
    if (event is! RawKeyDownEvent || event.repeat) return;
    final data = event.data;
    if (data is! RawKeyEventDataWindows) return;
    final key = data.keyCode;
    if (ShipglowsKey.isModifier(key)) return;
    if (_mode == _Mode.mouse) return;
    _change(() {
      if (_mode == _Mode.keys) {
        _hotkey = ShipglowsHotkey(
          key,
          control: event.isControlPressed,
          alt: event.isAltPressed,
          shift: event.isShiftPressed,
          meta: event.isMetaPressed,
        );
      } else {
        _doubleKey = key;
      }
    });
  }

  void _selectGesture(ShipglowsMouseGesture gesture) => _change(() {
    _gesture = gesture;
    if (gesture == ShipglowsMouseGesture.touch) {
      if (!_zone.isCorner) _zone = ShipglowsZone.cornerTopLeft;
    } else if (_zone.isCorner) {
      _zone = ShipglowsZone.titleBar;
    }
  });

  String _why() => switch (_mode) {
    _Mode.keys => _labels.whyKeys,
    _Mode.doubleKey => _labels.whyDoubleKey,
    _Mode.mouse =>
      _zone == ShipglowsZone.anywhere && !_anyModifier
          ? _labels.whyAnywhere
          : _gesture == ShipglowsMouseGesture.click &&
                _button == ShipglowsMouseButton.left &&
                !_anyModifier
          ? _labels.whyPlainClick
          : _labels.whyOther,
  };

  @override
  Widget build(BuildContext context) {
    final trigger = _trigger;
    final valid = trigger != null && trigger.isValid;
    final scheme = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.bodySmall;
    final modes = [
      if (widget.allowMouse)
        ButtonSegment(
          value: _Mode.mouse,
          icon: const Icon(Icons.mouse_outlined),
          label: Text(_labels.mouse),
        ),
      if (widget.allowKeys)
        ButtonSegment(
          value: _Mode.keys,
          icon: const Icon(Icons.keyboard_outlined),
          label: Text(_labels.keys),
        ),
      if (widget.allowDoubleKey)
        ButtonSegment(
          value: _Mode.doubleKey,
          icon: const Icon(Icons.keyboard_double_arrow_right),
          label: Text(_labels.doubleKey),
        ),
    ];
    // Recording a key: the keys are the answer, not commands. Without this,
    // Esc would close the dialog, and Tab or Enter would move the focus.
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) => _mode == _Mode.mouse
          ? KeyEventResult.ignored
          : KeyEventResult.handled,
      child: RawKeyboardListener(
      focusNode: _focus,
      autofocus: true,
      onKey: _onKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (modes.length > 1)
            SegmentedButton<_Mode>(
              segments: modes,
              selected: {_mode},
              onSelectionChanged: (value) {
                _change(() => _mode = value.single);
                _focus.requestFocus();
              },
            ),
          const SizedBox(height: 12),
          if (_mode == _Mode.mouse) ..._mouseFields(),
          if (_mode == _Mode.keys)
            _capture(
              _labels.captureKeys,
              _hotkey?.label(_labels.trigger.keys),
            ),
          if (_mode == _Mode.doubleKey)
            _capture(
              _labels.captureDoubleKey,
              _doubleKey == null
                  ? null
                  : ShipglowsDoubleKeyTrigger(_doubleKey!).label(_labels.trigger),
            ),
          const SizedBox(height: 12),
          Text(
            trigger == null
                ? _labels.nothingChosen
                : valid
                ? trigger.label(_labels.trigger)
                : '${_labels.notUsable} ${_why()}',
            style: small?.copyWith(
              color: trigger == null || valid
                  ? scheme.onSurfaceVariant
                  : scheme.error,
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _capture(String hint, String? current) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.primary),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(hint, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Text(current ?? '…', style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );

  List<Widget> _mouseFields() {
    final zones = [
      for (final zone in ShipglowsZone.values)
        if (zone.isCorner == _isTouch) zone,
    ];
    return [
      DropdownButtonFormField<ShipglowsMouseGesture>(
        initialValue: _gesture,
        decoration: InputDecoration(labelText: _labels.gesture),
        items: [
          for (final gesture in ShipglowsMouseGesture.values)
            DropdownMenuItem(
              value: gesture,
              child: Text(_labels.gestureName(gesture)),
            ),
        ],
        onChanged: (value) {
          if (value != null) _selectGesture(value);
        },
      ),
      if (_needsButton) ...[
        const SizedBox(height: 8),
        DropdownButtonFormField<ShipglowsMouseButton>(
          initialValue: _button,
          decoration: InputDecoration(labelText: _labels.button),
          items: [
            for (final button in ShipglowsMouseButton.values)
              DropdownMenuItem(
                value: button,
                child: Text(_labels.buttonName(button)),
              ),
          ],
          onChanged: (value) {
            if (value != null) _change(() => _button = value);
          },
        ),
      ],
      const SizedBox(height: 8),
      DropdownButtonFormField<ShipglowsZone>(
        key: ValueKey(_isTouch),
        initialValue: _zone,
        decoration: InputDecoration(labelText: _labels.where),
        items: [
          for (final zone in zones)
            DropdownMenuItem(value: zone, child: Text(_labels.zoneName(zone))),
        ],
        onChanged: (value) {
          if (value != null) _change(() => _zone = value);
        },
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          for (final (label, value, set) in <(String, bool, ValueChanged<bool>)>[
            (_labels.trigger.keys.control, _control, (v) => _control = v),
            (_labels.trigger.keys.alt, _alt, (v) => _alt = v),
            (_labels.trigger.keys.shift, _shift, (v) => _shift = v),
            (_labels.trigger.keys.meta, _meta, (v) => _meta = v),
          ])
            FilterChip(
              label: Text(label),
              selected: value,
              onSelected: (v) => _change(() => set(v)),
            ),
        ],
      ),
    ];
  }
}
