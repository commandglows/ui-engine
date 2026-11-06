import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shipglows_feelings/shipglows_feelings.dart';
import 'package:shipglows_tag_picker/shipglows_tag_picker.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'feeling_picker_strings.dart';

/// How many example words a closed family shows.
const int _familyExamples = 4;

/// Options for the [ids] that [bank] can name, in the order given.
List<TagOption> _optionsFor(
  Iterable<String> ids,
  FeelingBank bank,
  String languageCode,
) => [
  for (final id in ids)
    if (bank.labelOf(id, languageCode: languageCode) case final label?)
      TagOption(id: id, label: label),
];

String _languageOf(BuildContext context, String? languageCode) =>
    languageCode ?? Localizations.localeOf(context).languageCode;

/// A few suggested words inline, and a button opening the whole bank.
class FeelingPicker extends StatelessWidget {
  /// Creates a picker. The selection is owned by the caller.
  const FeelingPicker({
    super.key,
    required this.bank,
    required this.suggestions,
    required this.selected,
    required this.onChanged,
    this.title,
    this.helper,
    this.maxSelected,
    this.allowCustom = true,
    this.languageCode,
    this.strings,
  });

  /// Words the person can pick from.
  final FeelingBank bank;

  /// Ids shown inline. Picked words are always shown too.
  final List<String> suggestions;

  /// Ids currently picked.
  final Set<String> selected;

  /// Called with the whole new selection.
  final ValueChanged<Set<String>> onChanged;

  /// Heading above the words.
  final String? title;

  /// Short line under the heading.
  final String? helper;

  /// Most words that can be picked; `null` for no limit.
  final int? maxSelected;

  /// Whether the person can add a word of their own from the search.
  final bool allowCustom;

  /// Language of the words; the ambient locale by default.
  final String? languageCode;

  /// Strings; the preset for the language by default.
  final FeelingPickerStrings? strings;

  @override
  Widget build(BuildContext context) {
    final language = _languageOf(context, languageCode);
    final text = strings ?? FeelingPickerStrings.of(language);
    final theme = ShipglowsTheme.of(context);
    final max = maxSelected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TagPicker(
          title: title,
          helper: helper,
          options: _optionsFor(
            {...selected.where((id) => !suggestions.contains(id)), ...suggestions},
            bank,
            language,
          ),
          selected: selected,
          onChanged: onChanged,
          maxSelected: max,
          limitMessage: max == null ? null : text.limitReached(max),
        ),
        SizedBox(height: theme.spaceXs),
        TextButton.icon(
          icon: const Icon(Icons.menu_book_outlined),
          label: Text(text.seeAll),
          onPressed: () => unawaited(
            showFeelingBankSheet(
              context: context,
              bank: bank,
              selected: selected,
              onChanged: onChanged,
              maxSelected: max,
              allowCustom: allowCustom,
              languageCode: language,
              strings: text,
            ),
          ),
        ),
      ],
    );
  }
}

/// Opens the whole bank in a sheet: picked words, search, then families.
///
/// [onChanged] is called on every change, so closing the sheet loses nothing.
Future<void> showFeelingBankSheet({
  required BuildContext context,
  required FeelingBank bank,
  required Set<String> selected,
  required ValueChanged<Set<String>> onChanged,
  int? maxSelected,
  bool allowCustom = true,
  String? languageCode,
  FeelingPickerStrings? strings,
}) {
  final language = _languageOf(context, languageCode);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.92,
      child: _BankSheet(
        bank: bank,
        selected: selected,
        onChanged: onChanged,
        maxSelected: maxSelected,
        allowCustom: allowCustom,
        languageCode: language,
        strings: strings ?? FeelingPickerStrings.of(language),
      ),
    ),
  );
}

class _BankSheet extends StatefulWidget {
  const _BankSheet({
    required this.bank,
    required this.selected,
    required this.onChanged,
    required this.maxSelected,
    required this.allowCustom,
    required this.languageCode,
    required this.strings,
  });

  final FeelingBank bank;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final int? maxSelected;
  final bool allowCustom;
  final String languageCode;
  final FeelingPickerStrings strings;

  @override
  State<_BankSheet> createState() => _BankSheetState();
}

class _BankSheetState extends State<_BankSheet> {
  final _search = TextEditingController();
  late Set<String> _selected = widget.selected;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _full {
    final max = widget.maxSelected;
    return max != null && _selected.length >= max;
  }

  void _change(Set<String> next) {
    setState(() => _selected = next);
    widget.onChanged(next);
  }

  void _addCustom(String id) {
    _change({..._selected, id});
    _search.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final text = widget.strings;
    final query = _search.text.trim();
    final max = widget.maxSelected;
    return Padding(
      // The keyboard must not hide the search results.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              theme.spaceLg,
              theme.spaceMd,
              theme.spaceSm,
              theme.spaceSm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      text.sheetTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(text.done),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: theme.spaceLg),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: text.searchHint,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).deleteButtonTooltip,
                        onPressed: _search.clear,
                      ),
              ),
            ),
          ),
          if (_selected.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                theme.spaceLg,
                theme.spaceMd,
                theme.spaceLg,
                0,
              ),
              child: TagPicker(
                title: text.selectedTitle,
                options: _optionsFor(
                  _selected,
                  widget.bank,
                  widget.languageCode,
                ),
                selected: _selected,
                onChanged: _change,
                maxSelected: max,
                limitMessage: max == null ? null : text.limitReached(max),
              ),
            ),
          SizedBox(height: theme.spaceSm),
          Expanded(
            child: query.isEmpty ? _families(theme) : _results(theme, query),
          ),
        ],
      ),
    );
  }

  Widget _families(ShipglowsTheme theme) {
    final families = widget.bank.families;
    return ListView.builder(
      itemCount: families.length,
      itemBuilder: (context, index) {
        final family = families[index];
        final words = widget.bank.ofFamily(family);
        final language = widget.languageCode;
        final examples = words
            .take(_familyExamples)
            .map((word) => word.label(language))
            .join(', ');
        return ExpansionTile(
          key: PageStorageKey<String>(family.name),
          title: Text(family.label(language)),
          subtitle: Text('$examples…'),
          childrenPadding: EdgeInsets.fromLTRB(
            theme.spaceLg,
            0,
            theme.spaceLg,
            theme.spaceMd,
          ),
          expandedAlignment: Alignment.centerLeft,
          children: [_picker(words)],
        );
      },
    );
  }

  Widget _results(ShipglowsTheme theme, String query) {
    final found = widget.bank.search(
      query,
      languageCode: widget.languageCode,
    );
    final custom = customFeelingId(query);
    final exact = found.any(
      (word) =>
          word.label(widget.languageCode).toLowerCase() == query.toLowerCase(),
    );
    final canAdd =
        widget.allowCustom &&
        custom != null &&
        !exact &&
        !_selected.contains(custom);
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: theme.spaceLg),
      children: [
        if (found.isEmpty)
          Semantics(liveRegion: true, child: Text(widget.strings.noResult))
        else
          _picker(found),
        if (canAdd)
          Padding(
            padding: EdgeInsets.only(top: theme.spaceSm),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: Text(
                  widget.strings.addCustom(customFeelingText(custom)!),
                ),
                onPressed: _full ? null : () => _addCustom(custom),
              ),
            ),
          ),
      ],
    );
  }

  /// The limit is explained once, under the picked words.
  Widget _picker(List<Feeling> words) => TagPicker(
    options: [
      for (final word in words)
        TagOption(id: word.id, label: word.label(widget.languageCode)),
    ],
    selected: _selected,
    onChanged: _change,
    maxSelected: widget.maxSelected,
  );
}
