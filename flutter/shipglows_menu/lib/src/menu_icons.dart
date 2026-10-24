import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shipglows_icons/shipglows_icons.dart';

import 'menu_icon.dart';

/// Draws a [ShipglowsMenuIcon] in Flutter: by name from [overrides], then
/// from the shared base icons ([ShipglowsIcons.of], which honors the app's
/// [ShipglowsIconSet]); else its Segoe glyph on Windows (Segoe Fluent Icons,
/// Segoe MDL2 Assets on Windows 10); else nothing.
/// Decorative: screen readers read the entry's label.
class ShipglowsMenuIconView extends StatelessWidget {
  const ShipglowsMenuIconView(
    this.icon, {
    super.key,
    this.size = 18,
    this.color,
    this.overrides = const {},
  });

  final ShipglowsMenuIcon icon;
  final double size;
  final Color? color;
  final Map<String, IconData> overrides;

  @override
  Widget build(BuildContext context) {
    final name = icon.name;
    final data = name == null
        ? null
        : overrides[name] ?? ShipglowsIcons.of(context, name);
    if (data != null) {
      return ExcludeSemantics(
        child: Icon(data, size: size, color: color),
      );
    }
    final glyph = icon.glyph;
    if (glyph == null || !ShipglowsMenuIcons.hasSegoeFont) {
      return SizedBox.square(dimension: size);
    }
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: Text(
            String.fromCharCode(glyph),
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: 'Segoe Fluent Icons',
              fontFamilyFallback: const ['Segoe MDL2 Assets'],
              fontSize: size * 0.9,
              height: 1,
              color: color ?? IconTheme.of(context).color,
            ),
          ),
        ),
      ),
    );
  }
}

/// Platform facts for drawing [ShipglowsMenuIcon]s.
abstract final class ShipglowsMenuIcons {
  /// Whether the Segoe icon fonts can be used (Windows desktop).
  static bool get hasSegoeFont =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
}
