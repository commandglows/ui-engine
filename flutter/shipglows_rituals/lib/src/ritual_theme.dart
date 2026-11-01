import 'package:flutter/material.dart';

/// Ritual-specific geometry; colors, type and spacing come from the app theme.
class RitualThemeData extends ThemeExtension<RitualThemeData> {
  const RitualThemeData({this.dialogMaxWidth = 520});
  final double dialogMaxWidth;

  static RitualThemeData of(BuildContext context) =>
      Theme.of(context).extension<RitualThemeData>() ?? const RitualThemeData();

  @override
  RitualThemeData copyWith({double? dialogMaxWidth}) =>
      RitualThemeData(dialogMaxWidth: dialogMaxWidth ?? this.dialogMaxWidth);

  @override
  RitualThemeData lerp(covariant RitualThemeData? other, double t) =>
      other == null
      ? this
      : RitualThemeData(
          dialogMaxWidth:
              dialogMaxWidth + (other.dialogMaxWidth - dialogMaxWidth) * t,
        );
}
