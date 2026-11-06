import 'package:flutter/material.dart';

/// The design scale every ShipGlows app and package shares: spacing, radii,
/// motion, type sizes, icon sizes and window breakpoints.
///
/// These are constants, so an app can use them in `const` widgets and in its
/// own theme. [ShipglowsTheme] takes its defaults from here; an app that
/// brands a role overrides it there, not in the screen code.
///
/// Rule: a screen never writes a raw spacing, radius, duration, font size or
/// breakpoint that is on this scale. A value that is truly specific to one
/// app (an illustration size, a fixed panel width) stays a named constant in
/// that app's own theme.
abstract final class ShipglowsScale {
  // Spacing: the gap between and inside elements.

  /// 4: tight pairs (icon and label, dot and text).
  static const double spaceXs = 4;

  /// 8: items in a row or a list.
  static const double spaceSm = 8;

  /// 12: inside a card, between a field and its label.
  static const double spaceMd = 12;

  /// 16: the page gutter and the padding of a surface.
  static const double spaceLg = 16;

  /// 24: between sections of one view.
  static const double spaceXl = 24;

  /// 32: between major blocks.
  static const double spaceXxl = 32;

  /// 48: an empty state or a hero block.
  static const double spaceXxxl = 48;

  // Radii: the corners of keycaps, rows, surfaces and pills.

  /// 4: badges and tiny marks.
  static const double radiusXs = 4;

  /// 6: keycaps and chips.
  static const double radiusSm = 6;

  /// 10: rows and buttons.
  static const double radiusMd = 10;

  /// 16: menus, dialogs and cards.
  static const double radiusLg = 16;

  /// 24: large panels and sheets.
  static const double radiusXl = 24;

  /// Fully round: pills, progress bars, thumbs.
  static const double radiusFull = 999;

  // Motion: how long a change takes to settle.

  /// Quick feedback: hover, press, a small fade.
  static const Duration motionFast = Duration(milliseconds: 120);

  /// Regular transitions: open, close, move.
  static const Duration motionNormal = Duration(milliseconds: 200);

  /// Large changes that the eye must follow: a page or a panel.
  static const Duration motionSlow = Duration(milliseconds: 320);

  /// Standard curve: elements that enter or move.
  static const Curve curveStandard = Curves.easeOutCubic;

  /// Emphasized curve: elements that leave or change place.
  static const Curve curveEmphasized = Curves.easeInOutCubic;

  // Type sizes, in logical pixels. Use with the text theme's font family.

  /// 11: captions, eyebrows, footnotes.
  static const double textXs = 11;

  /// 14: secondary text, hints, dense rows.
  static const double textSm = 14;

  /// 16: body text.
  static const double textMd = 16;

  /// 18: row titles, section titles.
  static const double textLg = 18;

  /// 22: page subtitles.
  static const double textXl = 22;

  /// 38: hero titles and big numbers.
  static const double textHero = 38;

  // Icon sizes.

  /// 16: an icon beside small text.
  static const double iconSm = 16;

  /// 20: an icon beside body text, a row icon.
  static const double iconMd = 20;

  /// 24: a button or a navigation icon.
  static const double iconLg = 24;

  // Window breakpoints, Material 3 window size classes. Use with the
  // constraints of a LayoutBuilder, never with the device or the platform.

  /// Below this width: compact (phone, narrow window). One pane.
  static const double breakpointCompact = 600;

  /// From [breakpointCompact] to this width: medium (tablet, half window).
  static const double breakpointMedium = 840;

  /// From [breakpointMedium] to this width: expanded (desktop). From
  /// [breakpointExpanded] up: large.
  static const double breakpointExpanded = 1200;
}
