import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One item offered as a quick pick.
@immutable
class RecentChoice {
  const RecentChoice({required this.id, required this.label});

  final String id;
  final String label;
}

/// Quick picks shown under a picker: the [choices] in their order (latest
/// use first), as many as fit on [maxLines] lines; a tap picks the item as
/// the picker would.
///
/// Every chip is measured before layout, so the lines never overflow and the
/// order is kept: the first chip that does not fit ends the list. A label
/// longer than [maxChipWidth] is shortened, its full text in a tooltip.
class RecentChips extends StatelessWidget {
  const RecentChips({
    required this.choices,
    required this.onSelected,
    this.selectedId,
    this.maxLines = 1,
    this.maxChipWidth = 220,
    this.spacing = 6,
    this.enabled = true,
    this.semanticsLabel,
    super.key,
  }) : assert(maxLines > 0);

  final List<RecentChoice> choices;
  final ValueChanged<String> onSelected;

  /// The item the picker holds, shown as selected.
  final String? selectedId;

  final int maxLines;
  final double maxChipWidth;

  /// Gap between chips and between lines.
  final double spacing;

  final bool enabled;

  /// Names the group for screen readers ("Recent projects").
  final String? semanticsLabel;

  static const double _padding = 12;
  static const double _minHeight = 32;

  @override
  Widget build(BuildContext context) {
    if (choices.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    // Measured bold, as the selected chip shows it: a chip keeps its width
    // when the selection moves.
    final style = (theme.textTheme.labelLarge ?? const TextStyle()).copyWith(
      fontWeight: FontWeight.w600,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final chips = <Widget>[];
        var line = 1;
        var used = 0.0;
        double? height;
        for (final choice in choices) {
          final painter = TextPainter(
            text: TextSpan(text: choice.label, style: style),
            textDirection: direction,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          height ??= math.max(_minHeight, painter.height + _padding);
          final natural = painter.width.ceilToDouble() + 2 * _padding + 2;
          painter.dispose();
          final width = math.min(natural, math.min(maxChipWidth, available));
          final gap = used == 0 ? 0.0 : spacing;
          if (used + gap + width > available) {
            if (line == maxLines) break;
            line++;
            used = width;
          } else {
            used += gap + width;
          }
          chips.add(
            _RecentChip(
              choice: choice,
              width: width,
              height: height,
              shortened: width < natural,
              selected: choice.id == selectedId,
              onTap: enabled ? () => onSelected(choice.id) : null,
            ),
          );
        }
        return Semantics(
          container: true,
          label: semanticsLabel,
          child: Wrap(spacing: spacing, runSpacing: spacing, children: chips),
        );
      },
    );
  }
}

class _RecentChip extends StatelessWidget {
  const _RecentChip({
    required this.choice,
    required this.width,
    required this.height,
    required this.shortened,
    required this.selected,
    required this.onTap,
  });

  final RecentChoice choice;
  final double width;
  final double height;
  final bool shortened;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final foreground = selected
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;
    final shape = StadiumBorder(
      side: BorderSide(
        // The selected chip also has a filled background: the state never
        // rests on colour alone.
        color: selected ? scheme.secondary : scheme.outlineVariant,
        width: selected ? 1.5 : 1,
      ),
    );
    Widget chip = SizedBox(
      width: width,
      height: height,
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: RecentChips._padding,
            ),
            child: Center(
              child: Text(
                choice.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: enabled
                      ? foreground
                      : foreground.withValues(alpha: 0.38),
                  fontWeight: selected ? FontWeight.w600 : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    chip = Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: choice.label,
      excludeSemantics: true,
      child: chip,
    );
    return shortened ? Tooltip(message: choice.label, child: chip) : chip;
  }
}
