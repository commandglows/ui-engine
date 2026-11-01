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

Proof: source review and format only; no automated test or analyze executed.
Managed Windows integration evidence is recorded in the consuming app's spec.
