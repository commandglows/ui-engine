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
    required this.controllers,
    required this.checked,
    required this.onTextChanged,
    required this.onCheckChanged,
    this.enabled = true,
  });
  final RitualTemplate template;
  final Map<String, TextEditingController> controllers;
  final Set<String> checked;
  final VoidCallback onTextChanged;
  final void Function(String id, bool selected) onCheckChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final prompt in template.prompts)
        if (prompt.check)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(prompt.label),
            value: checked.contains(prompt.id),
            onChanged: enabled
                ? (value) => onCheckChanged(prompt.id, value == true)
                : null,
          )
        else
          Padding(
            padding: EdgeInsets.only(
              bottom: ShipglowsTheme.of(context).spaceMd,
            ),
            child: TextField(
              key: ValueKey('ritual-answer-${prompt.id}'),
              controller:
                  controllers[prompt.id] ??
                  (throw ArgumentError('Missing controller for ${prompt.id}')),
              enabled: enabled,
              minLines: 2,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                label: Text(prompt.label, softWrap: true),
                alignLabelWithHint: true,
              ),
              onChanged: (_) => onTextChanged(),
            ),
          ),
    ],
  );
}

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
    required this.onSave,
  });
  final RitualPage page;
  final List<RitualReference> references;
  final List<RitualContextGroup> contextGroups;
  final String? referencesLabel;
  final Widget? footer;
  final RitualStrings? strings;
  final Future<bool> Function(RitualPage) onSave;

  @override
  State<_RitualPageEditor> createState() => _RitualPageEditorState();
}

class _RitualPageEditorState extends State<_RitualPageEditor> {
  RitualStrings get _strings => widget.strings ?? RitualStrings.of(context);
  late final _answers = {
    for (final prompt in widget.page.template.prompts.where(
      (prompt) => !prompt.check,
    ))
      prompt.id: TextEditingController(
        text: widget.page.answers[prompt.id] ?? '',
      ),
  };
  late final _checked = {...widget.page.checked};
  late final _referenceIds = {...widget.page.referenceIds};
  bool _dirty = false, _saving = false, _confirming = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in _answers.values) {
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
              entry.key: entry.value.text.trim(),
          },
          checked: {..._checked},
          referenceIds: {..._referenceIds},
          completed: completed,
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
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(_close());
    },
    child: AlertDialog(
      title: Text('${widget.page.template.title} · ${widget.page.periodStart}'),
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
                        title: Text(_strings(RitualText.unavailableReference)),
                      ),
                  ],
                ),
              for (final group in widget.contextGroups)
                ExpansionTile(
                  title: Text(group.title),
                  children: [
                    for (final item in group.items) ListTile(title: Text(item)),
                  ],
                ),
              SizedBox(height: ShipglowsTheme.of(context).spaceMd),
              RitualFields(
                template: widget.page.template,
                controllers: _answers,
                checked: _checked,
                enabled: !_saving,
                onTextChanged: () => setState(() => _dirty = true),
                onCheckChanged: (id, selected) => setState(() {
                  _dirty = true;
                  selected ? _checked.add(id) : _checked.remove(id);
                }),
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
    if (questions.length + steps.length > 40 ||
        questions.length + steps.length == 0) {
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
          prompts: [
            for (var i = 0; i < questions.length; i++)
              RitualPrompt('question-$i', questions[i]),
            for (var i = 0; i < steps.length; i++)
              RitualPrompt('step-$i', steps[i], check: true),
          ],
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
