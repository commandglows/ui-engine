# shipglows_rituals

Reusable Flutter UI for human routines and reflection templates, backed by
`shipglows_rituals_core` (re-exported). Each host supplies its own content,
persistence callbacks and associated items. No data leaves the app through this
package; there is no automatic AI processing or shared user-data store.

```yaml
dependencies:
  shipglows_rituals:
    path: ../../shipglows-ui-engine/flutter/shipglows_rituals
```

## Public API

- `RitualTemplateCard`: a model's period, start/resume/read action, customizer
  and caller-supplied saved/completed state.
- `RitualFields`: text, checkbox, single/multiple choice, number and scale
  prompts, including declarative `showWhen` visibility. Legacy callers can keep
  supplying controllers, checked state and callbacks; typed callers pass
  `values`, `onValueChanged`, and optional numeric draft/error maps. A
  `RitualPromptFieldBuilder` can replace any default field while receiving a
  `RitualPromptFieldBinding` for the current value and callbacks. Typed text
  fields can use values/callbacks without controllers; controller-based legacy
  forms remain supported. Numeric draft callbacks receive clear actions too.
- `showRitualPage`: optional associated `RitualReference` items, read-only
  `RitualContextGroup`s, typed questions/checklist, optional host footer and
  draft or final save. Set `guided: true` for visible-step progress with back
  and next controls; `fieldBuilder` lets a host retain its own input style.
  `onSave` is the only persistence boundary. Return true only after saving;
  false or a thrown exception retains input and presents an error.
- `showRitualTemplateEditor`: title, purpose, daily/weekly cadence and one
  question/checkbox per line for simple templates, with 1–40 prompts and the
  same save boundary. Existing simple prompt IDs are retained where possible.
  Rich templates keep their app-defined prompts, choices, conditions and bounds
  intact while title, purpose and cadence remain editable.
- `RitualStrings.en` / `.fr`: default copy selected from the app's locale;
  `copyWith(overrides: {RitualText.references: 'Projects'})` customizes language
  and product vocabulary. Question content is supplied by the host.
- `RitualThemeData(dialogMaxWidth:)`: optional component geometry in
  `ThemeData.extensions`. Type and Material controls follow the active app
  theme; spacing follows `ShipglowsTheme`.

```dart
await showRitualPage(
  context,
  page: draft, // RitualPage from this app's store, including its recordId
  references: const [RitualReference(id: 'project-1', label: 'My project')],
  referencesLabel: 'Projects',
  onSave: (page) async {
    await appStore.save(page.toJson()); // app-owned adapter, local or remote
    return true;
  },
);
```

Opening a dialog writes nothing. Closing modified input requires an explicit
discard choice; saving disables controls and closing until the callback ends.
Do not use a background scheduler's "ignore store errors" policy for responses.
Each host must enforce its own revision or concurrency checks before returning
success. Completing a checklist never changes the host's tasks or health data.
Invalid numeric drafts stay visible with a field error and block saving; optional
number and choice responses can be cleared, and an untouched scale has no
persisted response.
Guided navigation leaves shared-theme spacing before the fields so a floating
question label does not overlap the back/next controls.

## Consumers and boundaries

DreamGlows consumes the cards and both editors. Its five product templates,
goals, actions, Path commands, Journal and exports remain local adapters.

ContentGlows currently has five fixed narrative categories (reflection, win,
struggle, idea, pivot), a two-filled-entry submission rule, AI synthesis and a
separate approval/rejection step. Its existing API and approval flow remain
app-owned; `RitualFields` can support a future UI migration. ContentGlows has
not been migrated to these packages in this change.

A tracking app can supply its own questions and persistence without depending
on DreamGlows, ContentGlows or their backends. The package contains no medical
questionnaire, score or interpretation. Adding a remote backend remains an
explicit integration owned by that application.

Proof: source review and format, followed by a successful managed Windows debug
restart/reload of the DreamGlows consumer. No automated tests, analyze or release
build. DreamGlows' weekly cycle, draft/resume, conditional choices and hidden
answer retention were exercised in T3's web preview in managed profile mode,
including a cold reload and desktop/mobile viewport checks. The guided-label
spacing fix was visually rechecked there. Native Windows, Android, numeric
fields and full accessibility acceptance remain outside this browser proof.
