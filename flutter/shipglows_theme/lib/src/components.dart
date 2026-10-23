import 'package:flutter/material.dart';

import 'theme.dart';

/// One key, such as `Ctrl` or `Entrée`: the label on a small raised face,
/// drawn from the [ShipglowsTheme] key roles.
class ShipglowsKeycap extends StatelessWidget {
  const ShipglowsKeycap(
    this.label, {
    super.key,
    this.backgroundColor,
    this.foregroundColor,
  });

  /// Text of the key.
  final String label;

  /// Face and label colors over [ShipglowsTheme.keyBackground] and
  /// [ShipglowsTheme.keyForeground], for a package theme that lets an app
  /// recolor its keys (`ShipglowsMenuTheme.keycapColor`).
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final base = Theme.of(context).textTheme.labelSmall ?? const TextStyle();
    return Container(
      constraints: BoxConstraints(
        minWidth: theme.keyMinSize,
        minHeight: theme.keyMinSize,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: theme.keyPaddingX,
        vertical: theme.keyPaddingY,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.keyBackground,
        borderRadius: BorderRadius.circular(theme.radiusSm),
        // A rounded border must keep one color, so the key's depth is a hard
        // shadow under it.
        border: Border.all(color: theme.keyBorder, width: theme.lineWidth),
        boxShadow: [
          BoxShadow(color: theme.keyShadow, offset: Offset(0, theme.keyDepth)),
        ],
      ),
      // Sized to its label: an unfactored alignment would stretch the key to
      // the whole width a Wrap or Column offers.
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          label,
          maxLines: 1,
          style: base
              .copyWith(fontWeight: FontWeight.w600)
              .merge(theme.keyLabelStyle)
              .copyWith(color: foregroundColor ?? theme.keyForeground),
        ),
      ),
    );
  }
}

/// Keycaps of [keys], side by side, such as `Ctrl` `K`.
class ShipglowsKeys extends StatelessWidget {
  const ShipglowsKeys(this.keys, {super.key, this.keyBuilder});

  /// Labels of the keys, in order.
  final List<String> keys;

  /// Draws one key; [ShipglowsKeycap] when null.
  final Widget Function(BuildContext context, String label)? keyBuilder;

  @override
  Widget build(BuildContext context) {
    final build = keyBuilder ?? (context, label) => ShipglowsKeycap(label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          build(context, keys[i]),
        ],
      ],
    );
  }
}

/// A button drawn as one keycap holding its whole text, such as
/// « c Presse-papiers »: the same face as the keys of a [ShipglowsKeyHint].
/// The selected one is fully opaque, the others fade.
class ShipglowsKeyButton extends StatelessWidget {
  const ShipglowsKeyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.tooltip,
    this.keyBuilder,
  });

  /// The button's whole text.
  final String label;
  final VoidCallback? onPressed;
  final bool selected;
  final String? tooltip;

  /// Draws the face; [ShipglowsKeycap] when null.
  final Widget Function(BuildContext context, String label)? keyBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final face = keyBuilder?.call(context, label) ?? ShipglowsKeycap(label);
    final button = Semantics(
      button: true,
      selected: selected,
      enabled: onPressed != null,
      label: label,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(theme.radiusSm),
          // The face stays small; the tap target keeps the control height.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: theme.controlMinHeight,
              minHeight: theme.controlMinHeight,
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: AnimatedOpacity(
                  opacity: selected ? 1 : 0.5,
                  duration: theme.motionFast,
                  child: face,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final tooltip = this.tooltip;
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

/// A key hint, such as the footer's `Alt` `Entrée` actions: [keys] as
/// keycaps, then [label] in muted text.
class ShipglowsKeyHint extends StatelessWidget {
  const ShipglowsKeyHint({
    super.key,
    required this.keys,
    required this.label,
    this.keyBuilder,
  });

  final List<String> keys;
  final String label;

  /// Draws one key; [ShipglowsKeycap] when null.
  final Widget Function(BuildContext context, String label)? keyBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShipglowsKeys(keys, keyBuilder: keyBuilder),
        SizedBox(width: theme.spaceXs),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: theme.textMuted),
        ),
      ],
    );
  }
}
