import 'package:flutter/material.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'strings.dart';

/// How far a value has got toward a goal: 3 of 5 for a habit done three
/// times in a week planned five times.
///
/// [ratio] and [reached] never throw or return NaN: a [target] that is not
/// above zero is no goal, so its ratio is 0 and it is never reached.
@immutable
class MetricTarget {
  const MetricTarget({
    required this.value,
    required this.target,
    this.valueLabel,
    this.targetLabel,
  });

  /// The amount reached so far.
  final double value;

  /// The goal to reach. Zero or below means there is no goal.
  final double target;

  /// The value as shown, formatted by the app (« 3 », « 2,5 km »). Defaults
  /// to [value] rounded to a whole number.
  final String? valueLabel;

  /// The goal as shown, formatted by the app. Defaults to [target] rounded to
  /// a whole number.
  final String? targetLabel;

  /// Progress toward [target], from 0 to 1. 0 when there is no goal.
  double get ratio {
    if (target.isNaN || target <= 0) return 0.0;
    final fraction = value / target;
    if (fraction.isNaN || fraction <= 0) return 0.0;
    if (fraction >= 1) return 1.0;
    return fraction;
  }

  /// Whether [value] has reached [target]. Never true without a goal.
  bool get reached => target > 0 && value >= target;

  /// The value text: [valueLabel], or [value] as a whole number.
  String get _valueText => valueLabel ?? _whole(value);

  /// The target text: [targetLabel], or [target] as a whole number.
  String get _targetText => targetLabel ?? _whole(target);

  @override
  bool operator ==(Object other) =>
      other is MetricTarget &&
      other.value == value &&
      other.target == target &&
      other.valueLabel == valueLabel &&
      other.targetLabel == targetLabel;

  @override
  int get hashCode => Object.hash(value, target, valueLabel, targetLabel);
}

/// A bar of progress toward a [MetricTarget]: a track, a fill that grows to
/// the ratio and, above it on the right, the « 3 of 5 » text of
/// [MetricStrings.ofTarget]. A screen reader hears that text once, with the
/// percentage as its value; the bar itself is hidden from it.
class MetricProgressBar extends StatelessWidget {
  const MetricProgressBar({
    required this.target,
    super.key,
    this.color,
    this.height = 8,
    this.showText = true,
    this.strings,
  });

  /// The goal and the amount reached.
  final MetricTarget target;

  /// The fill before the goal is reached. Defaults to [ShipglowsTheme.accent].
  /// Once the goal is reached the fill is [ShipglowsTheme.success].
  final Color? color;

  /// Thickness of the bar; both ends are rounded.
  final double height;

  /// Whether the « 3 of 5 » text shows above the bar. A tile that already
  /// shows the text turns it off.
  final bool showText;

  /// Defaults to [MetricStrings.of] the context.
  final MetricStrings? strings;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final texts = strings ?? MetricStrings.of(context);
    final textTheme = Theme.of(context).textTheme;
    final text = _ofTarget(texts, target);
    final ratio = target.ratio;
    final fill = target.reached ? theme.success : (color ?? theme.accent);
    final radius = BorderRadius.circular(height / 2);

    // Reduced motion: the fill jumps to its ratio instead of growing.
    final track = MediaQuery.disableAnimationsOf(context)
        ? _track(theme, radius, fill, ratio)
        : TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: ratio),
            duration: theme.motionNormal,
            builder: (_, value, _) => _track(theme, radius, fill, value),
          );

    return Semantics(
      label: text,
      value: '${(ratio * 100).round()}${texts.percentSuffix}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showText) ...[
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                text,
                style: textTheme.labelLarge?.copyWith(
                  color: theme.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            SizedBox(height: theme.spaceXs),
          ],
          track,
        ],
      ),
    );
  }

  /// The track in [ShipglowsTheme.border] with the [fraction] of it filled.
  Widget _track(
    ShipglowsTheme theme,
    BorderRadius radius,
    Color fill,
    double fraction,
  ) => ExcludeSemantics(
    child: DecoratedBox(
      decoration: BoxDecoration(color: theme.border, borderRadius: radius),
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          height: height,
          child: FractionallySizedBox(
            widthFactor: fraction,
            alignment: AlignmentDirectional.centerStart,
            child: ColoredBox(color: fill),
          ),
        ),
      ),
    ),
  );
}

/// One goal on a raised card, the same card as a metric tile: its label with
/// an optional [icon], the « 3 of 5 » text big, the progress bar and a muted
/// [caption]. Read as one sentence: « Weekly habits, 3 of 5, this week ».
///
/// The whole tile is the button when [onTap] is set.
class MetricProgressTile extends StatelessWidget {
  const MetricProgressTile({
    required this.label,
    required this.target,
    super.key,
    this.caption,
    this.icon,
    this.iconColor,
    this.onTap,
    this.strings,
  });

  /// What is measured: « Weekly habits », « Pages read ».
  final String label;

  /// The goal and the amount reached.
  final MetricTarget target;

  /// Under the bar, muted: what the goal covers (« this week »).
  final String? caption;

  /// Before the label, decorative: the label says what is measured.
  final IconData? icon;

  /// Defaults to [ShipglowsTheme.icon].
  final Color? iconColor;

  /// Opens the details; the whole tile is the button.
  final VoidCallback? onTap;

  /// Defaults to [MetricStrings.of] the context.
  final MetricStrings? strings;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final texts = strings ?? MetricStrings.of(context);
    final textTheme = Theme.of(context).textTheme;
    final caption = this.caption;
    final progress = _ofTarget(texts, target);

    final content = Padding(
      padding: EdgeInsets.all(theme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                ExcludeSemantics(
                  child: Icon(icon, size: 18, color: iconColor ?? theme.icon),
                ),
                SizedBox(width: theme.spaceSm),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  style: textTheme.labelLarge?.copyWith(color: theme.textMuted),
                ),
              ),
            ],
          ),
          SizedBox(height: theme.spaceSm),
          Text(
            progress,
            style: textTheme.headlineSmall?.copyWith(
              color: theme.text,
              fontFamily: theme.fontDisplay,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(height: theme.spaceSm),
          MetricProgressBar(target: target, strings: texts, showText: false),
          if (caption != null) ...[
            SizedBox(height: theme.spaceXs),
            Text(
              caption,
              style: textTheme.bodySmall?.copyWith(color: theme.textMuted),
            ),
          ],
        ],
      ),
    );

    final radius = BorderRadius.circular(theme.radiusLg);
    final card = Material(
      color: theme.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: theme.border, width: theme.lineWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );

    return Semantics(
      container: true,
      button: onTap != null,
      label: [label, progress, ?caption].join(', '),
      excludeSemantics: true,
      child: card,
    );
  }
}

/// A whole number as text; a value that is not finite stays as it is.
String _whole(double number) =>
    number.isFinite ? number.round().toString() : number.toString();

/// The « {value} of {target} » text of [texts] for [progress].
String _ofTarget(MetricStrings texts, MetricTarget progress) => texts.ofTarget
    .replaceAll('{value}', progress._valueText)
    .replaceAll('{target}', progress._targetText);
