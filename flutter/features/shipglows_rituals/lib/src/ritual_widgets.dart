import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shipglows_rituals_core/shipglows_rituals_core.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'strings.dart';
import 'ritual_theme.dart';

/// Read-only host context next to the questions (for example planned actions).
class RitualContextGroup {
  const RitualContextGroup({required this.title, required this.items});
  final String title;
  final List<String> items;
}

class RitualTemplateCard extends StatelessWidget {
  const RitualTemplateCard({
    super.key,
    required this.template,
    required this.date,
    this.hasSavedPage = false,
    this.completed = false,
    this.strings,
    required this.onOpen,
    required this.onEdit,
  });

  final RitualTemplate template;
  final DateTime date;
  final bool hasSavedPage, completed;
  final RitualStrings? strings;
  final VoidCallback? onOpen, onEdit;

  @override
  Widget build(BuildContext context) {
    final strings = this.strings ?? RitualStrings.of(context);
    final dates = MaterialLocalizations.of(context);
    final start = ritualPeriod(template, date);
    final period = template.weekly
        ? strings.format(RitualText.weekPeriod, {
            'start': dates.formatShortDate(start),
            'end': dates.formatShortDate(addRitualDays(start, 6)),
          })
        : dates.formatFullDate(start);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(ShipglowsTheme.of(context).spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(template.title, style: Theme.of(context).textTheme.titleLarge),
            Text(
              '${strings(template.weekly ? RitualText.weekly : RitualText.daily)} · $period',
            ),
            if (template.description.isNotEmpty) ...[
              SizedBox(height: ShipglowsTheme.of(context).spaceSm),
              Text(template.description),
            ],
            SizedBox(height: ShipglowsTheme.of(context).spaceMd),
            Wrap(
              spacing: ShipglowsTheme.of(context).spaceMd,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  key: ValueKey('ritual-open-${template.id}'),
                  onPressed: onOpen,
                  icon: Icon(
                    completed
                        ? Icons.menu_book_outlined
                        : Icons.play_arrow_outlined,
                  ),
                  label: Text(
                    !hasSavedPage
                        ? strings(RitualText.start)
                        : completed
                        ? strings(RitualText.reread)
                        : strings(RitualText.resume),
                  ),
                ),
                TextButton(
                  onPressed: onEdit,
                  child: Text(strings(RitualText.customize)),
                ),
                if (hasSavedPage)
                  Text(
                    completed
                        ? strings(RitualText.completed)
                        : strings(RitualText.draft),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> _confirmDiscard(
  BuildContext context,
  RitualStrings strings,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(strings(RitualText.discardTitle)),
        content: Text(strings(RitualText.discardMessage)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(strings(RitualText.continueWriting)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(strings(RitualText.discard)),
          ),
        ],
      ),
    ) ==
    true;

/// Questions and checkboxes for an existing app screen, without a dialog,
/// save policy or network request. The caller owns and disposes the controllers
/// for every text prompt and decides what a checked step means in its product.
class RitualFields extends StatelessWidget {
  const RitualFields({
    super.key,
    required this.template,
    this.controllers = const {},
    this.checked = const {},
    this.values = const {},
    this.numericControllers = const {},
    this.numericDrafts = const {},
    this.numericErrors = const {},
    this.onTextChanged,
    this.onCheckChanged,
    this.onValueChanged,
    this.onNumericDraftChanged,
    this.promptIds,
    this.fieldBuilder,
    this.strings,
    this.enabled = true,
  });
  final RitualTemplate template;
  final Map<String, TextEditingController> controllers;
  final Set<String> checked;
  final Map<String, Object?> values;
  final Map<String, TextEditingController> numericControllers;
  final Map<String, String> numericDrafts, numericErrors;
  final VoidCallback? onTextChanged;
  final void Function(String id, bool selected)? onCheckChanged;
  final void Function(String id, Object? value)? onValueChanged;
  final void Function(String id, String draft)? onNumericDraftChanged;
  final Set<String>? promptIds;
  final RitualPromptFieldBuilder? fieldBuilder;
  final RitualStrings? strings;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final strings = this.strings ?? RitualStrings.of(context);
    final page = RitualPage(
      template: template,
      periodStart: '',
      answers: {
        for (final entry in controllers.entries) entry.key: entry.value.text,
      },
      checked: checked,
      values: values,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final prompt in template.prompts)
          if ((promptIds == null || promptIds!.contains(prompt.id)) &&
              page.isPromptVisible(prompt))
            Padding(
              padding: EdgeInsets.only(
                bottom: ShipglowsTheme.of(context).spaceMd,
              ),
              child: _buildPrompt(context, prompt, strings),
            ),
      ],
    );
  }

  Widget _buildPrompt(
    BuildContext context,
    RitualPrompt prompt,
    RitualStrings strings,
  ) {
    final type = prompt.responseType;
    final value = values.containsKey(prompt.id)
        ? values[prompt.id]
        : type == RitualPromptType.text
        ? controllers[prompt.id]?.text
        : type == RitualPromptType.check
        ? checked.contains(prompt.id)
        : null;
    final canEditTyped = onValueChanged != null;
    void change(Object? next) {
      if (onValueChanged != null) {
        onValueChanged!(prompt.id, next);
      } else if (type == RitualPromptType.text) {
        controllers[prompt.id]?.text = next is String ? next : '';
        onTextChanged?.call();
      } else if (type == RitualPromptType.check) {
        onCheckChanged?.call(prompt.id, next == true);
      }
    }

    final binding = RitualPromptFieldBinding(
      value: value,
      enabled:
          enabled &&
          (type == RitualPromptType.text
              ? controllers.containsKey(prompt.id) || canEditTyped
              : type == RitualPromptType.check
              ? onCheckChanged != null || canEditTyped
              : type == RitualPromptType.number
              ? onNumericDraftChanged != null
              : canEditTyped),
      onChanged: change,
      onNumericDraftChanged: (draft) =>
          onNumericDraftChanged?.call(prompt.id, draft),
      onClear: () => change(null),
      numericError: numericErrors[prompt.id],
    );
    final defaultField = switch (type) {
      RitualPromptType.text => _textField(prompt),
      RitualPromptType.check => _checkField(prompt, value),
      RitualPromptType.singleChoice => _singleChoiceField(
        prompt,
        value,
        strings,
      ),
      RitualPromptType.multipleChoice => _multipleChoiceField(prompt, value),
      RitualPromptType.number => _numberField(prompt, value, strings),
      RitualPromptType.scale => _scaleField(prompt, value, strings),
    };
    return fieldBuilder?.call(context, prompt, binding, defaultField) ??
        defaultField;
  }

  Widget _textField(RitualPrompt prompt) => TextFormField(
    key: ValueKey('ritual-answer-${prompt.id}'),
    controller: controllers[prompt.id],
    initialValue: controllers.containsKey(prompt.id)
        ? null
        : values[prompt.id] as String?,
    enabled:
        enabled &&
        (controllers.containsKey(prompt.id) || onValueChanged != null),
    minLines: 2,
    maxLines: null,
    textCapitalization: TextCapitalization.sentences,
    decoration: InputDecoration(
      label: Text(prompt.label, softWrap: true),
      alignLabelWithHint: true,
    ),
    onChanged: (text) {
      if (!controllers.containsKey(prompt.id))
        onValueChanged?.call(prompt.id, text);
      onTextChanged?.call();
    },
  );

  Widget _checkField(RitualPrompt prompt, Object? value) => CheckboxListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(prompt.label),
    value: value is bool ? value : checked.contains(prompt.id),
    onChanged: !enabled
        ? null
        : (selected) {
            final next = selected == true;
            onCheckChanged?.call(prompt.id, next);
            onValueChanged?.call(prompt.id, next);
          },
  );

  Widget _singleChoiceField(
    RitualPrompt prompt,
    Object? value,
    RitualStrings strings,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(prompt.label),
      for (final option in prompt.options)
        RadioListTile<String>(
          contentPadding: EdgeInsets.zero,
          title: Text(option.label),
          value: option.id,
          groupValue: value is String ? value : null,
          onChanged: enabled && onValueChanged != null
              ? (selected) => onValueChanged!.call(prompt.id, selected)
              : null,
        ),
      if (value is String)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: enabled && onValueChanged != null
                ? () => onValueChanged!.call(prompt.id, null)
                : null,
            child: Text(strings(RitualText.clearResponse)),
          ),
        ),
    ],
  );

  Widget _multipleChoiceField(RitualPrompt prompt, Object? value) {
    final selected = value is List
        ? value.whereType<String>().toSet()
        : <String>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(prompt.label),
        for (final option in prompt.options)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(option.label),
            value: selected.contains(option.id),
            onChanged: enabled && onValueChanged != null
                ? (checked) {
                    final next = {...selected};
                    checked == true
                        ? next.add(option.id)
                        : next.remove(option.id);
                    onValueChanged!(
                      prompt.id,
                      next.isEmpty
                          ? null
                          : [
                              for (final candidate in prompt.options)
                                if (next.contains(candidate.id)) candidate.id,
                            ],
                    );
                  }
                : null,
          ),
      ],
    );
  }

  Widget _numberField(
    RitualPrompt prompt,
    Object? value,
    RitualStrings strings,
  ) => TextFormField(
    key: ValueKey('ritual-number-${prompt.id}'),
    controller: numericControllers[prompt.id],
    initialValue: numericControllers.containsKey(prompt.id)
        ? null
        : numericDrafts[prompt.id] ?? (value is num ? value.toString() : ''),
    enabled: enabled && onNumericDraftChanged != null,
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    decoration: InputDecoration(
      labelText: prompt.label,
      errorText: numericErrors[prompt.id],
      helperText: _rangeLabel(prompt),
      suffixIcon: value is num
          ? IconButton(
              tooltip: strings(RitualText.clearResponse),
              onPressed: !enabled
                  ? null
                  : () {
                      numericControllers[prompt.id]?.clear();
                      onNumericDraftChanged?.call(prompt.id, '');
                    },
              icon: const Icon(Icons.clear),
            )
          : null,
    ),
    onChanged: (draft) => onNumericDraftChanged?.call(prompt.id, draft),
  );

  Widget _scaleField(
    RitualPrompt prompt,
    Object? value,
    RitualStrings strings,
  ) {
    final minimum = prompt.minimum!.toDouble();
    final maximum = prompt.maximum!.toDouble();
    final step = prompt.step!.toDouble();
    final count = (((maximum - minimum) / step) + 1e-9).floor();
    double responseAt(int index) =>
        (minimum + index * step).clamp(minimum, maximum).toDouble();
    if (count > 1000) {
      final current = value is num ? value.toDouble() : minimum;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(prompt.label),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: current.clamp(minimum, maximum).toDouble(),
                  min: minimum,
                  max: maximum,
                  onChanged: enabled && onValueChanged != null
                      ? (next) {
                          final increments = ((next - minimum) / step).round();
                          onValueChanged!(
                            prompt.id,
                            responseAt(increments.clamp(0, count).toInt()),
                          );
                        }
                      : null,
                ),
              ),
              Text(
                value is num
                    ? _formatNumber(value.toDouble())
                    : strings(RitualText.chooseResponse),
              ),
              if (value is num)
                IconButton(
                  tooltip: strings(RitualText.clearResponse),
                  onPressed: enabled
                      ? () => onValueChanged?.call(prompt.id, null)
                      : null,
                  icon: const Icon(Icons.clear),
                ),
            ],
          ),
          Text(_rangeLabel(prompt)!),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InputDecorator(
          decoration: InputDecoration(
            labelText: prompt.label,
            helperText: _rangeLabel(prompt),
            suffixIcon: value is num
                ? IconButton(
                    tooltip: strings(RitualText.clearResponse),
                    onPressed: enabled
                        ? () => onValueChanged?.call(prompt.id, null)
                        : null,
                    icon: const Icon(Icons.clear),
                  )
                : null,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value is num ? ((value - minimum) / step).round() : null,
              hint: Text(strings(RitualText.chooseResponse)),
              isExpanded: true,
              items: [
                for (var index = 0; index <= count; index++)
                  DropdownMenuItem(
                    value: index,
                    child: Text(_formatNumber(responseAt(index))),
                  ),
              ],
              onChanged: enabled && onValueChanged != null
                  ? (next) => onValueChanged!.call(
                      prompt.id,
                      next == null ? null : responseAt(next),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  String? _rangeLabel(RitualPrompt prompt) {
    if (prompt.minimum == null && prompt.maximum == null) return null;
    return '${prompt.minimum ?? '…'} – ${prompt.maximum ?? '…'}';
  }

  String _formatNumber(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';
}

class RitualPromptFieldBinding {
  const RitualPromptFieldBinding({
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.onNumericDraftChanged,
    required this.onClear,
    required this.numericError,
  });

  final Object? value;
  final bool enabled;

  /// Supplies a typed response. Pass null to remove an optional response.
  final ValueChanged<Object?> onChanged;

  /// Numeric text input uses raw drafts so invalid input cannot be persisted.
  final ValueChanged<String> onNumericDraftChanged;
  final VoidCallback onClear;
  final String? numericError;
}

typedef RitualPromptFieldBuilder = Widget Function(
  BuildContext context,
  RitualPrompt prompt,
  RitualPromptFieldBinding binding,
  Widget defaultField,
);

/// Opens a page without writing. Only [onSave] can persist it; `false` or an
/// exception keeps the inputs and presents a retryable error. No data is sent
/// anywhere by this package. The host owns consent and any remote processing.
Future<void> showRitualPage(
  BuildContext context, {
  required RitualPage page,
  List<RitualReference> references = const [],
  List<RitualContextGroup> contextGroups = const [],
  String? referencesLabel,
  Widget? footer,
  RitualStrings? strings,
  bool guided = false,
  RitualPromptFieldBuilder? fieldBuilder,
  required Future<bool> Function(RitualPage) onSave,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _RitualPageEditor(
    page: page,
    references: references,
    contextGroups: contextGroups,
    referencesLabel: referencesLabel,
    footer: footer,
    strings: strings,
    guided: guided,
    fieldBuilder: fieldBuilder,
    onSave: onSave,
  ),
);

class _RitualPageEditor extends StatefulWidget {
  const _RitualPageEditor({
    required this.page,
    required this.references,
    required this.contextGroups,
    this.referencesLabel,
    this.footer,
    this.strings,
    required this.guided,
    this.fieldBuilder,
    required this.onSave,
  });
  final RitualPage page;
  final List<RitualReference> references;
  final List<RitualContextGroup> contextGroups;
  final String? referencesLabel;
  final Widget? footer;
  final RitualStrings? strings;
  final bool guided;
  final RitualPromptFieldBuilder? fieldBuilder;
  final Future<bool> Function(RitualPage) onSave;

  @override
  State<_RitualPageEditor> createState() => _RitualPageEditorState();
}

class _RitualPageEditorState extends State<_RitualPageEditor> {
  RitualStrings get _strings => widget.strings ?? RitualStrings.of(context);
  late final _answers = {
    for (final prompt in widget.page.template.prompts.where(
      (prompt) => prompt.responseType == RitualPromptType.text,
    ))
      prompt.id: TextEditingController(
        text: widget.page.values[prompt.id] is String
            ? widget.page.values[prompt.id] as String
            : widget.page.answers[prompt.id] ?? '',
      ),
  };
  late final _values = {...widget.page.values};
  late final _numericControllers = {
    for (final prompt in widget.page.template.prompts)
      if (prompt.responseType == RitualPromptType.number)
        prompt.id: TextEditingController(
          text: widget.page.values[prompt.id] is num
              ? widget.page.values[prompt.id].toString()
              : '',
        ),
  };
  late final _checked = {...widget.page.checked};
  late final _referenceIds = {...widget.page.referenceIds};
  final _numericDrafts = <String, String>{};
  final _numericErrors = <String, String>{};
  int _guidedPromptIndex = 0;
  bool _dirty = false, _saving = false, _confirming = false;
  String? _error;

  RitualPage get _workingPage => RitualPage(
    template: widget.page.template,
    periodStart: widget.page.periodStart,
    answers: {
      ...widget.page.answers,
      for (final entry in _answers.entries) entry.key: entry.value.text,
    },
    checked: _checked,
    values: _values,
  );

  void _textChanged() {
    setState(() {
      for (final prompt in widget.page.template.prompts) {
        if (prompt.responseType == RitualPromptType.text &&
            (prompt.type != null || _values.containsKey(prompt.id))) {
          _values[prompt.id] = _answers[prompt.id]!.text;
        }
      }
      _dirty = true;
    });
  }

  void _valueChanged(String id, Object? value) {
    setState(() {
      final prompt = widget.page.template.prompts.firstWhere(
        (candidate) => candidate.id == id,
      );
      if (prompt.responseType == RitualPromptType.text &&
          _answers.containsKey(id)) {
        _answers[id]!.value = TextEditingValue(
          text: value is String ? value : '',
          selection: TextSelection.collapsed(
            offset: value is String ? value.length : 0,
          ),
        );
      }
      if (prompt.type != null || _values.containsKey(id)) {
        if (value == null) {
          _values.remove(id);
        } else {
          _values[id] = value;
        }
      }
      if (prompt.responseType == RitualPromptType.check) {
        value == true ? _checked.add(id) : _checked.remove(id);
      }
      _dirty = true;
    });
  }

  void _numericDraftChanged(String id, String draft) {
    final prompt = widget.page.template.prompts.firstWhere(
      (candidate) => candidate.id == id,
    );
    final trimmed = draft.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _numericDrafts.remove(id);
        _numericErrors.remove(id);
        _values.remove(id);
        if (_numericDrafts.isEmpty) _error = null;
        _dirty = true;
      });
      return;
    }
    final value = num.tryParse(trimmed);
    final increments = value != null && prompt.step != null
        ? (value - (prompt.minimum ?? 0)) / prompt.step!
        : null;
    final valid =
        value != null &&
        (value is! double || value.isFinite) &&
        (prompt.minimum == null || value >= prompt.minimum!) &&
        (prompt.maximum == null || value <= prompt.maximum!) &&
        (increments == null ||
            (increments.isFinite &&
                (increments - increments.round()).abs() <= 1e-9));
    setState(() {
      _dirty = true;
      if (valid) {
        _values[id] = value;
        _numericDrafts.remove(id);
        _numericErrors.remove(id);
        if (_numericDrafts.isEmpty) _error = null;
      } else {
        _values.remove(id);
        _numericDrafts[id] = draft;
        _numericErrors[id] = _strings(RitualText.invalidNumber);
        _error = _strings(RitualText.fixInvalidAnswers);
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _answers.values) {
      controller.dispose();
    }
    for (final controller in _numericControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _close() async {
    if (_saving || _confirming) return;
    _confirming = true;
    final leave = !_dirty || await _confirmDiscard(context, _strings);
    _confirming = false;
    if (leave && mounted) Navigator.pop(context);
  }

  Future<void> _save(bool completed) async {
    if (_saving) return;
    if (_numericDrafts.isNotEmpty) {
      setState(() {
        for (final id in _numericDrafts.keys) {
          _numericErrors[id] = _strings(RitualText.invalidNumber);
        }
        _error = _strings(RitualText.fixInvalidAnswers);
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    var saved = false;
    try {
      saved = await widget.onSave(
        RitualPage(
          template: widget.page.template,
          periodStart: widget.page.periodStart,
          recordId: widget.page.recordId,
          answers: {
            ...widget.page.answers,
            for (final entry in _answers.entries)
              if (widget.page.template.prompts.any(
                (prompt) => prompt.id == entry.key && prompt.type == null,
              ))
                entry.key: entry.value.text.trim(),
          },
          checked: {..._checked},
          referenceIds: {..._referenceIds},
          completed: completed,
          values: Map<String, Object?>.of(_values),
        ),
      );
    } catch (_) {
      // Persistence belongs to the host; a failed callback never closes the draft.
      saved = false;
    }
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _saving = false;
      _error = _strings(RitualText.pageSaveFailure);
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _workingPage.visiblePrompts;
    final selectedIndex = visible.isEmpty
        ? 0
        : _guidedPromptIndex.clamp(0, visible.length - 1).toInt();
    final visibleIds = widget.guided && visible.isNotEmpty
        ? {visible[selectedIndex].id}
        : null;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: AlertDialog(
        title: Text(
          '${widget.page.template.title} · ${widget.page.periodStart}',
        ),
        content: SizedBox(
          width: RitualThemeData.of(context).dialogMaxWidth,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_strings(RitualText.pageIntro)),
                if (widget.page.recordId != null)
                  Text(_strings(RitualText.snapshot)),
                if (widget.references.isNotEmpty || _referenceIds.isNotEmpty)
                  ExpansionTile(
                    title: Text(
                      '${widget.referencesLabel ?? _strings(RitualText.references)} (${_referenceIds.length})',
                    ),
                    children: [
                      for (final reference in widget.references)
                        CheckboxListTile(
                          value: _referenceIds.contains(reference.id),
                          title: Text(reference.label),
                          onChanged: _saving
                              ? null
                              : (selected) => setState(() {
                                  _dirty = true;
                                  selected == true
                                      ? _referenceIds.add(reference.id)
                                      : _referenceIds.remove(reference.id);
                                }),
                        ),
                      for (final id in _referenceIds.where(
                        (id) => !widget.references.any(
                          (reference) => reference.id == id,
                        ),
                      ))
                        ListTile(
                          title: Text(
                            _strings(RitualText.unavailableReference),
                          ),
                        ),
                    ],
                  ),
                for (final group in widget.contextGroups)
                  ExpansionTile(
                    title: Text(group.title),
                    children: [
                      for (final item in group.items)
                        ListTile(title: Text(item)),
                    ],
                  ),
                SizedBox(height: ShipglowsTheme.of(context).spaceMd),
                if (widget.guided && visible.isNotEmpty) ...[
                  LinearProgressIndicator(
                    value: (selectedIndex + 1) / visible.length,
                  ),
                  SizedBox(height: ShipglowsTheme.of(context).spaceSm),
                  Text(
                    _strings.format(RitualText.stepProgress, {
                      'current': '${selectedIndex + 1}',
                      'total': '${visible.length}',
                    }),
                  ),
                  Wrap(
                    spacing: ShipglowsTheme.of(context).spaceSm,
                    children: [
                      OutlinedButton(
                        onPressed: _saving || selectedIndex == 0
                            ? null
                            : () => setState(
                                () => _guidedPromptIndex = selectedIndex - 1,
                              ),
                        child: Text(_strings(RitualText.back)),
                      ),
                      FilledButton.tonal(
                        onPressed:
                            _saving || selectedIndex >= visible.length - 1
                            ? null
                            : () => setState(
                                () => _guidedPromptIndex = selectedIndex + 1,
                              ),
                        child: Text(_strings(RitualText.next)),
                      ),
                    ],
                  ),
                  SizedBox(height: ShipglowsTheme.of(context).spaceMd),
                ],
                RitualFields(
                  template: widget.page.template,
                  controllers: _answers,
                  checked: _checked,
                  values: _values,
                  numericControllers: _numericControllers,
                  numericDrafts: _numericDrafts,
                  numericErrors: _numericErrors,
                  promptIds: visibleIds,
                  fieldBuilder: widget.fieldBuilder,
                  strings: widget.strings,
                  enabled: !_saving,
                  onTextChanged: _textChanged,
                  onCheckChanged: (id, selected) => setState(() {
                    _dirty = true;
                    selected ? _checked.add(id) : _checked.remove(id);
                  }),
                  onValueChanged: _valueChanged,
                  onNumericDraftChanged: _numericDraftChanged,
                ),
                ?widget.footer,
                if (_error != null) ...[
                  SizedBox(height: ShipglowsTheme.of(context).spaceMd),
                  Semantics(liveRegion: true, child: Text(_error!)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => unawaited(_close()),
            child: Text(_strings(RitualText.close)),
          ),
          if (!widget.page.completed)
            OutlinedButton(
              onPressed: _saving ? null : () => unawaited(_save(false)),
              child: Text(_strings(RitualText.saveDraft)),
            ),
          FilledButton(
            onPressed: _saving || (widget.page.completed && !_dirty)
                ? null
                : () => unawaited(_save(true)),
            child: Text(
              _saving
                  ? _strings(RitualText.saving)
                  : widget.page.completed
                  ? _strings(RitualText.saveChanges)
                  : _strings(RitualText.finish),
            ),
          ),
        ],
      ),
    );
  }
}

/// Edits a reusable model; existing pages retain their original snapshots.
Future<void> showRitualTemplateEditor(
  BuildContext context, {
  required RitualTemplate template,
  required Future<bool> Function(RitualTemplate) onSave,
  RitualStrings? strings,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) =>
      _TemplateEditor(template: template, onSave: onSave, strings: strings),
);

class _TemplateEditor extends StatefulWidget {
  const _TemplateEditor({
    required this.template,
    required this.onSave,
    this.strings,
  });
  final RitualTemplate template;
  final Future<bool> Function(RitualTemplate) onSave;
  final RitualStrings? strings;
  @override
  State<_TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends State<_TemplateEditor> {
  RitualStrings get _strings => widget.strings ?? RitualStrings.of(context);
  bool get _isRich => widget.template.hasRichMetadata;
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.template.title);
  late final _description = TextEditingController(
    text: widget.template.description,
  );
  late final _questions = TextEditingController(
    text: widget.template.prompts
        .where((p) => !p.check)
        .map((p) => p.label)
        .join('\n'),
  );
  late final _steps = TextEditingController(
    text: widget.template.prompts
        .where((p) => p.check)
        .map((p) => p.label)
        .join('\n'),
  );
  late bool _weekly = widget.template.weekly;
  bool _saving = false, _dirty = false, _confirming = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_title, _description, _questions, _steps]) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> _lines(TextEditingController controller) => controller.text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  List<RitualPrompt> _simplePrompts(
    List<String> questions,
    List<String> steps,
  ) {
    final original = widget.template.prompts;
    final reservedIds = original.map((prompt) => prompt.id).toSet();
    final usedIds = <String>{};
    final prompts = <RitualPrompt>[];
    void append(List<String> labels, RitualPromptType type, String prefix) {
      final candidates = original
          .where((prompt) => prompt.responseType == type)
          .toList(growable: false);
      final matching = <String, List<RitualPrompt>>{};
      for (final prompt in candidates) {
        matching.putIfAbsent(prompt.label.trim(), () => []).add(prompt);
      }
      final exactByIndex = <int, RitualPrompt>{};
      final reservedMatches = <String>{};
      for (var index = 0; index < labels.length; index++) {
        final match = matching[labels[index]]?.firstWhere(
          (prompt) => !reservedMatches.contains(prompt.id),
          orElse: () => RitualPrompt('', ''),
        );
        if (match != null && match.id.isNotEmpty) {
          exactByIndex[index] = match;
          reservedMatches.add(match.id);
        }
      }
      for (var index = 0; index < labels.length; index++) {
        RitualPrompt? prior;
        if (exactByIndex.containsKey(index)) {
          prior = exactByIndex[index];
        } else if (index < candidates.length &&
            !usedIds.contains(candidates[index].id) &&
            !reservedMatches.contains(candidates[index].id)) {
          prior = candidates[index];
        }
        var id = prior?.id ?? '$prefix-$index';
        var suffix = 1;
        while (usedIds.contains(id) ||
            (prior == null && reservedIds.contains(id))) {
          id = '$prefix-$index-${suffix++}';
        }
        usedIds.add(id);
        prompts.add(
          RitualPrompt(
            id,
            labels[index],
            check: type == RitualPromptType.check,
          ),
        );
      }
    }

    append(questions, RitualPromptType.text, 'question');
    append(steps, RitualPromptType.check, 'step');
    return prompts;
  }

  Future<void> _close() async {
    if (_saving || _confirming) return;
    _confirming = true;
    final leave = !_dirty || await _confirmDiscard(context, _strings);
    _confirming = false;
    if (leave && mounted) Navigator.pop(context);
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final questions = _lines(_questions), steps = _lines(_steps);
    final count = _isRich
        ? widget.template.prompts.length
        : questions.length + steps.length;
    if (count > 40 || count == 0) {
      setState(() => _error = _strings(RitualText.fieldCount));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    var saved = false;
    try {
      saved = await widget.onSave(
        RitualTemplate(
          id: widget.template.id,
          title: _title.text.trim(),
          description: _description.text.trim(),
          weekly: _weekly,
          prompts: _isRich
              ? widget.template.prompts
              : _simplePrompts(questions, steps),
        ),
      );
    } catch (_) {
      // Persistence belongs to the host; a failed callback never closes the draft.
      saved = false;
    }
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _saving = false;
      _error = _strings(RitualText.templateSaveFailure);
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(_close());
    },
    child: AlertDialog(
      title: Text(_strings(RitualText.editorTitle)),
      content: SizedBox(
        width: RitualThemeData.of(context).dialogMaxWidth,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            onChanged: () => _dirty = true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_strings(RitualText.editorIntro)),
                if (_isRich) ...[
                  SizedBox(height: ShipglowsTheme.of(context).spaceSm),
                  Text(_strings(RitualText.richTemplateHint)),
                ],
                SizedBox(height: ShipglowsTheme.of(context).spaceMd),
                TextFormField(
                  controller: _title,
                  enabled: !_saving,
                  decoration: InputDecoration(
                    labelText: _strings(RitualText.modelName),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? _strings(RitualText.requiredName)
                      : null,
                ),
                SizedBox(height: ShipglowsTheme.of(context).spaceMd),
                TextFormField(
                  controller: _description,
                  enabled: !_saving,
                  minLines: 1,
                  maxLines: null,
                  decoration: InputDecoration(
                    labelText: _strings(RitualText.modelPurpose),
                  ),
                ),
                SwitchListTile(
                  title: Text(_strings(RitualText.weeklyPage)),
                  subtitle: Text(_strings(RitualText.cadenceHint)),
                  value: _weekly,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() {
                          _weekly = value;
                          _dirty = true;
                        }),
                ),
                if (!_isRich) ...[
                  SizedBox(height: ShipglowsTheme.of(context).spaceMd),
                  TextFormField(
                    controller: _questions,
                    enabled: !_saving,
                    minLines: 4,
                    maxLines: null,
                    decoration: InputDecoration(
                      labelText: _strings(RitualText.questions),
                      helperText: _strings(RitualText.questionHint),
                    ),
                  ),
                  SizedBox(height: ShipglowsTheme.of(context).spaceMd),
                  TextFormField(
                    controller: _steps,
                    enabled: !_saving,
                    minLines: 4,
                    maxLines: null,
                    decoration: InputDecoration(
                      labelText: _strings(RitualText.steps),
                      helperText: _strings(RitualText.stepHint),
                    ),
                  ),
                ],
                if (_error != null)
                  Semantics(liveRegion: true, child: Text(_error!)),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => unawaited(_close()),
          child: Text(_strings(RitualText.cancel)),
        ),
        FilledButton(
          onPressed: _saving ? null : () => unawaited(_save()),
          child: Text(
            _saving
                ? _strings(RitualText.saving)
                : _strings(RitualText.saveTemplate),
          ),
        ),
      ],
    ),
  );
}
