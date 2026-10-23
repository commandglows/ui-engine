import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

/// Look of the introduction. Every null value falls back on the shared
/// [ShipglowsTheme] roles and the `TextTheme`; text styles given here are
/// merged onto those defaults, so `TextStyle(fontFamily: 'Cal Sans')` keeps
/// the default size and color.
@immutable
class OnboardingThemeData extends ThemeExtension<OnboardingThemeData> {
  const OnboardingThemeData({
    this.titleStyle,
    this.descriptionStyle,
    this.eyebrowStyle,
    this.skipStyle,
    this.specimenStyle,
    this.progressGradient,
    this.progressTrackColor,
    this.previewColor,
    this.cardRadius,
    this.buttonRadius,
    this.maxCardWidth,
    this.maxCardHeight,
    this.narrowWidth,
    this.motionDuration,
    this.motionCurve,
  });

  /// Page title (default: 44 px, tight, `text`).
  final TextStyle? titleStyle;

  /// Description, note and body text (default: body large, `textMuted`).
  final TextStyle? descriptionStyle;

  /// Uppercase line above the title.
  final TextStyle? eyebrowStyle;

  /// The quiet Skip action.
  final TextStyle? skipStyle;

  /// Greetings of the language preview (default: the title style at 64 px).
  final TextStyle? specimenStyle;

  /// Paints the done segments of the progress bar (default: plain `accent`).
  final Gradient? progressGradient;

  /// Segments still to come (default: `line`).
  final Color? progressTrackColor;

  /// Background of the preview column (default: `surfaceContainerLow`).
  final Color? previewColor;

  /// Default: `radiusLg`.
  final double? cardRadius;

  /// Language buttons (default: `radiusMd`).
  final double? buttonRadius;

  /// Card size at most (default 1216 × 768).
  final double? maxCardWidth;
  final double? maxCardHeight;

  /// Below this width the card is one scrolling column without preview
  /// (default 832).
  final double? narrowWidth;

  /// Page and progress transitions (default: `motionNormal`); none when the
  /// platform asks to reduce motion.
  final Duration? motionDuration;
  final Curve? motionCurve;

  /// The theme's values with every fallback applied.
  static OnboardingThemeData of(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final own = theme.extension<OnboardingThemeData>();
    final roles = ShipglowsTheme.from(theme);

    final title = TextStyle(
      fontSize: 44,
      fontWeight: FontWeight.w400,
      height: 1.05,
      letterSpacing: -0.4,
      color: roles.text,
    ).merge(own?.titleStyle);
    return OnboardingThemeData(
      titleStyle: title,
      descriptionStyle: (text.bodyLarge ?? const TextStyle(fontSize: 16))
          .copyWith(height: 1.55, color: roles.textMuted)
          .merge(own?.descriptionStyle),
      eyebrowStyle: (text.labelMedium ?? const TextStyle(fontSize: 12))
          .copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.7,
            color: roles.textMuted,
          )
          .merge(own?.eyebrowStyle),
      skipStyle: (text.bodySmall ?? const TextStyle(fontSize: 13))
          .copyWith(color: roles.textMuted)
          .merge(own?.skipStyle),
      specimenStyle: title
          .copyWith(fontSize: 64, letterSpacing: -0.6)
          .merge(own?.specimenStyle),
      progressGradient: own?.progressGradient,
      progressTrackColor: own?.progressTrackColor ?? roles.line,
      previewColor: own?.previewColor ?? scheme.surfaceContainerLow,
      cardRadius: own?.cardRadius ?? roles.radiusLg,
      buttonRadius: own?.buttonRadius ?? roles.radiusMd,
      maxCardWidth: own?.maxCardWidth ?? 1216,
      maxCardHeight: own?.maxCardHeight ?? 768,
      narrowWidth: own?.narrowWidth ?? 832,
      motionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : own?.motionDuration ?? roles.motionNormal,
      motionCurve: own?.motionCurve ?? Curves.easeOutCubic,
    );
  }

  @override
  OnboardingThemeData copyWith({
    TextStyle? titleStyle,
    TextStyle? descriptionStyle,
    TextStyle? eyebrowStyle,
    TextStyle? skipStyle,
    TextStyle? specimenStyle,
    Gradient? progressGradient,
    Color? progressTrackColor,
    Color? previewColor,
    double? cardRadius,
    double? buttonRadius,
    double? maxCardWidth,
    double? maxCardHeight,
    double? narrowWidth,
    Duration? motionDuration,
    Curve? motionCurve,
  }) {
    return OnboardingThemeData(
      titleStyle: titleStyle ?? this.titleStyle,
      descriptionStyle: descriptionStyle ?? this.descriptionStyle,
      eyebrowStyle: eyebrowStyle ?? this.eyebrowStyle,
      skipStyle: skipStyle ?? this.skipStyle,
      specimenStyle: specimenStyle ?? this.specimenStyle,
      progressGradient: progressGradient ?? this.progressGradient,
      progressTrackColor: progressTrackColor ?? this.progressTrackColor,
      previewColor: previewColor ?? this.previewColor,
      cardRadius: cardRadius ?? this.cardRadius,
      buttonRadius: buttonRadius ?? this.buttonRadius,
      maxCardWidth: maxCardWidth ?? this.maxCardWidth,
      maxCardHeight: maxCardHeight ?? this.maxCardHeight,
      narrowWidth: narrowWidth ?? this.narrowWidth,
      motionDuration: motionDuration ?? this.motionDuration,
      motionCurve: motionCurve ?? this.motionCurve,
    );
  }

  @override
  OnboardingThemeData lerp(OnboardingThemeData? other, double t) {
    if (other == null) return this;
    final near = t < 0.5 ? this : other;
    return OnboardingThemeData(
      titleStyle: TextStyle.lerp(titleStyle, other.titleStyle, t),
      descriptionStyle: TextStyle.lerp(
        descriptionStyle,
        other.descriptionStyle,
        t,
      ),
      eyebrowStyle: TextStyle.lerp(eyebrowStyle, other.eyebrowStyle, t),
      skipStyle: TextStyle.lerp(skipStyle, other.skipStyle, t),
      specimenStyle: TextStyle.lerp(specimenStyle, other.specimenStyle, t),
      progressGradient: Gradient.lerp(
        progressGradient,
        other.progressGradient,
        t,
      ),
      progressTrackColor: Color.lerp(
        progressTrackColor,
        other.progressTrackColor,
        t,
      ),
      previewColor: Color.lerp(previewColor, other.previewColor, t),
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t),
      buttonRadius: lerpDouble(buttonRadius, other.buttonRadius, t),
      maxCardWidth: lerpDouble(maxCardWidth, other.maxCardWidth, t),
      maxCardHeight: lerpDouble(maxCardHeight, other.maxCardHeight, t),
      narrowWidth: lerpDouble(narrowWidth, other.narrowWidth, t),
      motionDuration: near.motionDuration,
      motionCurve: near.motionCurve,
    );
  }
}
