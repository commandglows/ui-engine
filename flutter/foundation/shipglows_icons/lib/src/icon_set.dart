import 'package:flutter/material.dart';

import 'icons.dart';

/// An app's own icons over the base set, by name:
/// `ThemeData(extensions: [ShipglowsIconSet(overrides: {'settings': ...})])`.
/// Every name left out keeps its [ShipglowsIcons] base icon.
@immutable
class ShipglowsIconSet extends ThemeExtension<ShipglowsIconSet> {
  const ShipglowsIconSet({this.overrides = const {}});

  /// Icons replacing the base ones, keyed by [ShipglowsIcons.byName] names.
  final Map<String, IconData> overrides;

  /// The icon set of [context]'s theme, if it declares one.
  static ShipglowsIconSet? maybeOf(BuildContext context) =>
      Theme.of(context).extension<ShipglowsIconSet>();

  @override
  ShipglowsIconSet copyWith({Map<String, IconData>? overrides}) =>
      ShipglowsIconSet(overrides: overrides ?? this.overrides);

  @override
  ShipglowsIconSet lerp(ShipglowsIconSet? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

/// The icon named [name] ([ShipglowsIcons.of]), sized and colored by the
/// [IconTheme]. An unknown name keeps its room empty. Decorative unless a
/// [semanticLabel] is given.
class ShipglowsIcon extends StatelessWidget {
  const ShipglowsIcon(
    this.name, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  final String name;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final data = ShipglowsIcons.of(context, name);
    if (data == null) {
      return SizedBox.square(dimension: size ?? IconTheme.of(context).size);
    }
    return Icon(data, size: size, color: color, semanticLabel: semanticLabel);
  }
}
