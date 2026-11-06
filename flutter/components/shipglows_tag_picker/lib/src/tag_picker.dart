import 'package:flutter/material.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

/// One word the person can pick.
@immutable
class TagOption {
  /// Creates an option.
  const TagOption({required this.id, required this.label});

  /// Stable id, the value to store.
  final String id;

  /// Text shown on the chip.
  final String label;
}

/// A wrap of chips where the person picks any number of [options], up to
/// [maxSelected].
class TagPicker extends StatelessWidget {
  /// Creates a picker. The selection is owned by the caller.
  const TagPicker({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.title,
    this.helper,
    this.maxSelected,
    this.limitMessage,
  });

  /// Words to pick from, in display order.
  final List<TagOption> options;

  /// Ids currently picked. Ids missing from [options] are kept.
  final Set<String> selected;

  /// Called with the whole new selection.
  final ValueChanged<Set<String>> onChanged;

  /// Heading above the chips.
  final String? title;

  /// Short line under the heading.
  final String? helper;

  /// Most words that can be picked; `null` for no limit.
  final int? maxSelected;

  /// Shown once [maxSelected] is reached, to explain the disabled chips.
  final String? limitMessage;

  bool get _full {
    final max = maxSelected;
    return max != null && selected.length >= max;
  }

  void _toggle(String id) {
    final next = {...selected};
    if (!next.remove(id)) next.add(id);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final titleText = title;
    final helperText = helper;
    final limitText = limitMessage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (titleText != null)
          Semantics(
            header: true,
            child: Text(titleText, style: textTheme.titleMedium),
          ),
        if (helperText != null)
          Padding(
            padding: EdgeInsets.only(top: theme.spaceXs),
            child: Text(
              helperText,
              style: textTheme.bodyMedium?.copyWith(color: theme.textMuted),
            ),
          ),
        if (titleText != null || helperText != null)
          SizedBox(height: theme.spaceSm),
        Wrap(
          spacing: theme.spaceSm,
          runSpacing: theme.spaceSm,
          children: [for (final option in options) _chip(theme, option)],
        ),
        if (_full && limitText != null)
          Padding(
            padding: EdgeInsets.only(top: theme.spaceSm),
            child: Semantics(
              liveRegion: true,
              child: Text(
                limitText,
                style: textTheme.bodyMedium?.copyWith(color: theme.textMuted),
              ),
            ),
          ),
      ],
    );
  }

  Widget _chip(ShipglowsTheme theme, TagOption option) {
    final isSelected = selected.contains(option.id);
    final enabled = isSelected || !_full;
    return FilterChip(
      label: Text(option.label),
      selected: isSelected,
      selectedColor: theme.highlight,
      checkmarkColor: theme.onHighlight,
      labelStyle: TextStyle(
        color: isSelected
            ? theme.onHighlight
            : enabled
            ? theme.text
            : theme.textMuted,
      ),
      onSelected: enabled ? (_) => _toggle(option.id) : null,
    );
  }
}
