import 'package:flutter/material.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'strings.dart';

/// Five stars to pick a rating, with what the rating means written under
/// them (shape and words carry it, not color alone). Tapping the chosen star
/// again clears the rating. Each star is a 48 px target read as « 4 out of
/// 5, Good », selected or not.
class ShipglowsStarRating extends StatelessWidget {
  const ShipglowsStarRating({
    super.key,
    required this.value,
    required this.onChanged,
    this.strings,
    this.size = 36,
  });

  /// 1 to 5, or `null` when nothing is chosen.
  final int? value;

  /// `null` makes the stars read-only.
  final ValueChanged<int?>? onChanged;
  final ShipglowsReviewStrings? strings;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final texts = strings ?? ShipglowsReviewStrings.of(context);
    final value = this.value;
    final onChanged = this.onChanged;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          children: [
            for (var stars = 1; stars <= 5; stars++)
              MergeSemantics(
                child: Semantics(
                  selected: value == stars,
                  inMutuallyExclusiveGroup: true,
                  child: IconButton(
                    tooltip:
                        '${ShipglowsReviewStrings.fill(texts.ratingValue, count: stars)}, '
                        '${texts.levelOf(stars)}',
                    isSelected: value != null && stars <= value,
                    iconSize: size,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    icon: Icon(Icons.star_outline_rounded, color: theme.icon),
                    selectedIcon: Icon(
                      Icons.star_rounded,
                      color: theme.accent,
                    ),
                    onPressed: onChanged == null
                        ? null
                        : () => onChanged(value == stars ? null : stars),
                  ),
                ),
              ),
          ],
        ),
        Padding(
          padding: EdgeInsetsDirectional.only(start: theme.spaceSm),
          child: Semantics(
            liveRegion: true,
            child: Text(
              value == null ? '' : texts.levelOf(value),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: theme.textMuted),
            ),
          ),
        ),
      ],
    );
  }
}
