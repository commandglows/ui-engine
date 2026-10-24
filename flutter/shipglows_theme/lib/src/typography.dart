import 'package:flutter/material.dart';

import 'theme.dart';

/// The font families bundled with `shipglows_theme`, the defaults of the
/// [ShipglowsTheme] font roles. Each name already carries the package
/// prefix, so it works as a plain `TextStyle(fontFamily: ...)`.
abstract final class ShipglowsFonts {
  /// Interface text: Inter, 400 to 700.
  static const sans = 'packages/shipglows_theme/Inter';

  /// Titles and big numbers: Cal Sans, one weight (600).
  static const display = 'packages/shipglows_theme/Cal Sans';

  /// Code, paths, logs: JetBrains Mono.
  static const mono = 'packages/shipglows_theme/JetBrains Mono';

  /// System monospace faces drawn while [mono] is missing a glyph or a file.
  static const monoFallback = ['Cascadia Mono', 'Consolas', 'Menlo', 'monospace'];

  /// [base] with [sans] on every style and [display] on the display and
  /// headline styles, sizes and colors kept.
  static TextTheme textTheme(
    TextTheme base, {
    String sans = ShipglowsFonts.sans,
    String display = ShipglowsFonts.display,
  }) {
    TextStyle? d(TextStyle? style) =>
        style?.copyWith(fontFamily: display, fontWeight: FontWeight.w600);
    final text = base.apply(fontFamily: sans);
    return text.copyWith(
      displayLarge: d(text.displayLarge),
      displayMedium: d(text.displayMedium),
      displaySmall: d(text.displaySmall),
      headlineLarge: d(text.headlineLarge),
      headlineMedium: d(text.headlineMedium),
      headlineSmall: d(text.headlineSmall),
    );
  }
}

/// Scrollbars drawn from the [ShipglowsTheme] roles: a thin rounded thumb in
/// [ShipglowsTheme.textMuted] that thickens and darkens under the pointer,
/// on no track.
ScrollbarThemeData shipglowsScrollbarTheme(ShipglowsTheme theme) {
  bool active(Set<WidgetState> states) =>
      states.contains(WidgetState.hovered) ||
      states.contains(WidgetState.dragged);
  return ScrollbarThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (states) => theme.textMuted.withValues(alpha: active(states) ? 0.7 : 0.4),
    ),
    trackColor: const WidgetStatePropertyAll(Colors.transparent),
    trackBorderColor: const WidgetStatePropertyAll(Colors.transparent),
    thickness: WidgetStateProperty.resolveWith(
      (states) => active(states) ? 10 : 6,
    ),
    radius: const Radius.circular(999),
    crossAxisMargin: 2,
    mainAxisMargin: 2,
    interactive: true,
  );
}
