# shipglows_rituals_core

Pure Dart definitions for **human** rituals: reusable questions/checklists,
daily or Monday–Sunday pages, answers, associated item IDs and draft/completed
state. No Flutter SDK, database, HTTP client, AI, authentication or scheduler.

`shipglows_routines` runs technical background jobs. These packages have separate
purposes and do not depend on one another.

```dart
import 'package:shipglows_rituals_core/shipglows_rituals_core.dart';

const template = RitualTemplate(
  id: 'weekly-check-in',
  title: 'My week',
  weekly: true,
  prompts: [
    RitualPrompt('important', 'What matters to me this week?'),
    RitualPrompt('prepare', 'Prepare my first step', check: true),
  ],
);
final day = DateTime(2026, 11, 2); // host-selected civil date
final page = RitualPage(
  template: template,
  periodStart: ritualDate(ritualPeriod(template, day)),
  answers: {'important': 'Make room for my project'},
);
final json = page.toJson();
final restored = RitualPage.read(json);
```

The host supplies the date in its chosen civil calendar. `ritualPeriod`,
`ritualDate`, `parseRitualDate` and `addRitualDays` never convert it to UTC or
assume that a calendar day lasts 24 hours. A weekly page starts on Monday.

## JSON v1

The template/page v1 contract below remains the compatibility baseline. The
invitation and cycle contracts are separate v1 records supplied by the host.

- A template contains `version: 1`, `id`, `title`, `description`, `cadence`
  (`daily` / `weekly`) and `prompts` (`id`, `label`, boolean `check`).
- A page contains `version: 1`, optional `recordId`, `templateId`, an independent
  `template` snapshot, `periodStart` (`YYYY-MM-DD`), `state` (`draft` /
  `completed`), `answers` (string map), `checked` (prompt ID list) and
  `referenceIds` (host-owned item ID list).
- `RitualTemplate.read` returns null for an unsupported/malformed model;
  `RitualPage.read` throws `FormatException` for an unsupported/malformed page.
  Prompt IDs are unique, labels are nonempty and 1–40 prompts are supported.
- `RitualReference` supplies a host item's ID and display label to Flutter.
  There is no prescribed goal, project, patient, user or account model.

Changing a template does not rewrite a saved page's snapshot. The host chooses
identity, record IDs, storage, revision checks, conflict handling, deletion,
encryption, retention, exports and any remote processing. The JSON contract can
be consumed by another backend language; the Dart implementation is reusable
directly only in Dart. No backend endpoint or cross-app synchronization is
provided. Unknown JSON members are not a generic lossless extension store.

DreamGlows is the first consumer through its Path reflection adapter. Existing
`goalIds` remain on disk and map to generic `referenceIds` in memory. Product
templates stay in the product repository.

Proof: source review and format; the DreamGlows managed Windows debug consumer
was restarted and reloaded successfully. No automated test or analyze executed.
Visual and interactive acceptance remain unverified; evidence is recorded in
the consuming app's spec.

## Typed pages and declarative visibility (JSON v2)

`RitualPromptType` supports text, check, singleChoice, multipleChoice, number
and scale. Choice options have stable IDs and readable labels. Numeric prompts
can carry minimum, maximum and step; scales require all three. A numeric step
is measured from the minimum, or zero when no minimum is supplied. A `showWhen`
`RitualCondition` compares a prior prompt with `equals`, or uses `contains`
for a multiple choice. Conditions never execute expressions or scripts.
Numeric conditions with a step compare the selected step index, avoiding
floating-point differences for decimal scales.

`RitualPage.values` holds typed responses; legacy `answers`, `checked`, `check`
and constructors remain usable. `visiblePrompts` resolves conditions against
current responses, including legacy text/check state. Hidden answers remain
stored for a later return to that branch; hosts decide what to include in a
readable export. Readers reject invalid options, response types, ranges,
numeric steps and conditions that do not reference an earlier valid prompt.

Templates with rich metadata and pages with rich templates or typed values
write version 2; ordinary text/check pages retain version 1. Version 2 pages
include a `values` map. Unknown versions fail explicitly instead of being
replaced with an empty page. The host should validate constructed models with
the readers before committing them to its store.

## Invitation policy and intention/review links

`RitualInvitationPolicy.daily/weekly/monthly` use civil period boundaries;
`rolling(interval:, anchor:)` uses fixed elapsed windows, including the interval
in its identity; `onEvent(name)` requires a matching event name and stable
host event ID. `evaluate(now:, mode:, prerequisitesMet:, state:)` is pure. A
disabled or quiet mode, failed prerequisites, completion, dismissal, snooze
or prior display produces an explicit reason instead of a notification.

`RitualInvitationState` retains shown, dismissed, snoozed and completed facts
separately. A snooze affects only its invitation identity. Dismissing never
completes a ritual. The host persists transitions only after its own successful
write; it must retain per-occurrence state if older events can be replayed.
An expired snooze can offer the ritual again; `markShown` then consumes that
expired snooze so the next evaluation does not repeat it. Dates in these new
state records use canonical UTC instants. No source reads
the clock or knows an app's health thresholds.

`RitualIntentionSnapshot` retains an authored intention's stable ID, text and
creation instant. `RitualCycleReview` records a review and optional intention /
previous-review references with retained readable text snapshots. Its readers
reject malformed or unsupported versions; readable labels can be supplied by
the host's locale. These records do not change tasks, medical data or profiles.

## More

Human routines and reusable reflection templates, extracted from DreamGlows.
The core is pure Dart: question/checklist models, daily or Monday–Sunday
periods, answer pages, original-template snapshots and compatible JSON v1/v2.
Typed choices/numbers/scales and declarative prior-answer conditions are shared.
Pure invitation policies cover civil periods, fixed rolling windows and explicit
events; intention/review records retain readable link snapshots. The Flutter
package provides `RitualTemplateCard`, embeddable `RitualFields`, page/model
editors, French/English copy and shared-theme spacing. Apps supply all content,
item references and persistence callbacks; neither package has a network,
AI or app/backend dependency. DreamGlows consumes both through local paths.
ContentGlows' narrative ritual was inspected and remains on its existing
API/synthesis/approval flow; it is not a consumer yet. NoCocaïne consumes only
the core for existing invitations, conditional check-in steps and local journal
links, retaining its UI and health rules. No cross-app data sharing is introduced.

See [`shipglows_rituals`](../../features/shipglows_rituals/README.md) for integration
and [`shipglows_rituals_core`](../../core/shipglows_rituals_core/README.md) for the
portable data contract. Tests/analyze and visual acceptance remain unexecuted.
