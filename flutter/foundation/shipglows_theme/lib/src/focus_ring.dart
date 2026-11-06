import 'package:flutter/material.dart';

import 'theme.dart';

/// Draws a visible ring while keyboard focus is anywhere inside [child], so a
/// row reached with Tab is always findable, whatever ink its Material allows.
/// A mouse click draws no ring. The ring is [ShipglowsTheme.focus].
class ShipglowsFocusRing extends StatefulWidget {
  const ShipglowsFocusRing({
    super.key,
    required this.child,
    this.radius,
    this.width,
  });

  final Widget child;

  /// Corner radius of the ring. [ShipglowsTheme.radiusMd] when null.
  final double? radius;

  /// Width of the ring. Twice [ShipglowsTheme.lineWidth] when null.
  final double? width;

  @override
  State<ShipglowsFocusRing> createState() => _ShipglowsFocusRingState();
}

class _ShipglowsFocusRingState extends State<ShipglowsFocusRing> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    // Only keyboard navigation shows the ring; a mouse click does not.
    final visible =
        _focused &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: (value) => setState(() => _focused = value),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius ?? theme.radiusMd),
          border: visible
              ? Border.all(
                  color: theme.focus,
                  width: widget.width ?? theme.lineWidth * 2,
                )
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}
