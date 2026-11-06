---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: ShipGlows App Engine
created: "2026-11-07"
updated: "2026-11-07"
created_at: "2026-11-07"
updated_at: "2026-11-07"
status: reviewed
source_model: Claude Opus 5.5
source_skill: 100-sg-spec
scope: shared-task-management
owner: Diane
user_story: "As a ShipGlows app builder, I want one shared task contract and task widgets so that every app gets reliable task lists without writing its own."
confidence: high
risk_level: medium
security_impact: low
docs_impact: yes
linked_systems:
  - flutter/core/shipglows_organize
  - typescript/shipglows_sync
  - dreamglows/packages/path-core
  - dreamglows/packages/path_core_dart
  - dreamglows/packages/path_flutter
  - communityglows/packages/core
  - communityglows/app/lib/features/tasks
  - communityglows/app/lib/features/sync/cloud_sync.dart
  - communityglows/backend/convex/workspaceState.ts
depends_on: []
supersedes: []
evidence:
  - "Code audit of DreamGlows, CommunityGlows and shipglows_app on 2026-11-06; no test was run."
  - "Operator decision 2026-11-07: the shared contract covers Flutter and TypeScript/Vue."
next_step: "Operator approval of the chantier, then readiness review"
---

# Shared Task Management

## Status

Reviewed draft. Not implemented. Readiness and implementation need operator approval.

## User Story

As a ShipGlows app builder, I want one shared task contract and task widgets so that every app gets reliable task lists without writing its own, and so that a person's tasks survive every client and device.

## Minimal Behavior Contract

An app declares its workflow (statuses and their categories), its limits and its own extra fields, then creates, edits, moves, completes, deletes and restores tasks through the shared logic, which returns either the next state or a stable refusal code. The same input gives the same result in Dart and TypeScript, proved by shared fixtures. Anything a client does not understand (unknown field, unknown status, undecodable record) is kept and written back unchanged, never coerced or dropped. The easiest case to miss: two client generations writing the same stored snapshot during a rollout.

## Success Behavior

- An app adds task lists by depending on the packages and supplying a workflow, strings, storage and optional extra-field builders.
- The person sees a list or a board, adds a task quickly, edits it, reorders it by pointer, touch or keyboard, and sees overdue and next tasks.
- CommunityGlows and DreamGlows keep their stored data, wire formats and visible behavior, and lose their private duplicate logic.
- Proof: shared fixtures pass in both languages, and existing stored documents of both apps round-trip byte-equivalent as JSON values.

## Error Behavior

- A refused command returns a stable code (`empty-title`, `title-too-long`, `note-too-long`, `too-many-tags`, `tag-too-long`, `task-not-found`, `task-deleted`, `task-not-deleted`, `unknown-status`, `parent-not-found`, `cycle`, `nesting-disabled`, `invalid-schedule`) and leaves the state unchanged. Hosts translate the code.
- A malformed date, or a start after the end, is reported on write and treated as "no date" by projections, never guessed.
- A stored record that cannot be decoded is returned as an undecodable entry. Hosts keep it and write it back.
- A failed save stays the host's error: widgets keep the form content and show the host's failure.

## Problem

- CommunityGlows has unrelated Vue and Flutter models kept in step by hand. The Flutter one has already drifted: it ignores `contactIds` when reading and writing, then pushes the full list, which erases the links on the account (read in the code, not reproduced). It also turns an unknown status into `todo` and drops undecodable records.
- DreamGlows has the most reliable mechanics (rank, schedule, next action, overdue, tombstones, unknown-field preservation, twin Dart/TS with fixtures), but mixed with dreams, goals, habits, focus and progress in `path_repository.dart` (2,066 lines), on untyped maps. Its action screens live in `app.dart` (8,074 lines) and are not extractable.
- Other apps have no task model yet and would write a third and fourth one.
- `shipglows_app` has no task list: `TasksParser` reads `TASKS.md`, and `project_orders` are agent runs with an 11-status lifecycle in the Runner.

## Solution

Three new packages, plus adapters in each consuming app.

| Package | Layer | Holds | Depends on |
| --- | --- | --- | --- |
| `flutter/core/shipglows_tasks_core` | core, pure Dart | Model, workflow, commands, projections, codec | `shipglows_organize` |
| `typescript/shipglows_tasks` (`@shipglows/tasks`) | TypeScript, no Vue, Pinia or Convex | The same, plus the rank port and the shared fixtures | nothing |
| `flutter/components/shipglows_tasks` | components | `TaskList`, `TaskBoard`, `TaskEditor`, `TaskQuickAdd`, `TaskStrings` (FR/EN) | `shipglows_tasks_core`, `shipglows_theme`, `shipglows_icons`, `shipglows_tag_picker`, `shipglows_swipe_actions` |

The widgets belong in `components` because they need no service, and because `features` cannot depend on `shipglows_undo_trash` or `shipglows_sync`. Persistence, undo and sync are supplied by the host through callbacks, like `shipglows_rituals`.

### Canonical task (JSON, version 1)

```text
id          string, opaque, stable
title       string
note        string
statusId    string, an id of the app's workflow, kept even if unknown
priority    "low" | "medium" | "high", optional
rank        string, optional fractional key (shipglows_organize contract)
parentId    string, optional
tags        string[]
schedule    { start?, end? }, each a civil date or a zoned instant
completedAt zoned instant, optional
deletedAt   zoned instant, optional (tombstone)
createdAt   zoned instant
updatedAt   zoned instant
extensions  JSON object owned by the app, preserved untouched
```

### Workflow

`TaskWorkflow(statuses, initialStatusId, nesting, limits)`. Each status has an `id` and a `category`: `open`, `active`, `waiting`, `done` or `cancelled`. Behavior reads the category only: entering `done` sets `completedAt`, leaving it clears it, and `done` and `cancelled` are terminal for projections. Labels never live in the data: the host supplies them, which keeps CommunityGlows' renamed columns.

| App | Statuses (id → category) |
| --- | --- |
| CommunityGlows | `todo` → open, `waiting` → waiting, `done` → done |
| DreamGlows | `todo` → open, `in-progress` → active, `done` → done, `cancelled` → cancelled |

### Operations

Commands are pure, with injected clock and id generator: `create`, `update`, `setStatus`, `move`, `reparent`, `schedule`, `unschedule`, `delete`, `restore`. Each returns the next list plus a `TaskChange(before, after)`, or a refusal. Replay protection, history and remote delivery stay with the host, because they already exist in `@shipglows/sync`.

Projections, ported from DreamGlows semantics:

- `tasksByStatus`: rank first, then unranked in given order.
- `selectNextTask`: live non-terminal tasks, earliest date first, undated last in given order, ties in given order. The date is `start ?? end`, or `start` alone when the host passes that option (DreamGlows does).
- `isOverdue`: live non-terminal task whose `end ?? start` falls before `today`. Invalid or reversed periods are not overdue. The host passes `today` as a civil date and a resolver for zoned instants, so nothing reads a global clock or zone.

## Scope In

- The three packages, the shared fixtures, FR/EN strings and an adoption guide in the package READMEs.
- The CommunityGlows Flutter fix for lost fields, ahead of everything else.
- CommunityGlows Flutter and web adoption, through an adapter over the current wire format.
- DreamGlows adoption of the shared rank, next-task and overdue logic, through an adapter.
- Removal of the unimported copy `communityglows/packages/core/src/ui/setup/pages/CommunityGlows/services/kanbanService.ts`.

## Scope Out

- `shipglows_app`: `project_orders`, signals and the `TASKS.md` parser stay as they are.
- The ShipGlows `TASKS.md` tracker format.
- A shared Vue package: CommunityGlows is the only Vue consumer, so its components stay local.
- DreamGlows screens: its visual presets and `app.dart` keep their UI. Adopting the widgets there is a later decision.
- Moving CommunityGlows from a full snapshot to command sync. Tracked as a residual risk below.
- Converging the legacy `KanbanItem` model, owned by CommunityGlows' `unified-kanban.md`.
- Recurrence, reminders, assignment, dependencies between tasks and attachments.
- DreamGlows' document format, events and sync protocol.

## Constraints

- Engine layers and `dart tool/check_layers.dart` apply. `core` stays pure Dart.
- Widgets take colors, radii, spacing and keys from `ShipglowsTheme`, with no raw values.
- No wire change for CommunityGlows other than the additive `rank`, because older clients keep writing the same snapshot: its three statuses stay, `order` stays written, and deletion stays physical on the wire, since older clients would show a tombstoned task.
- No format change for DreamGlows: schema version 1, the `medium` priority, `set-action-rank` and the existing fixtures stay untouched.
- Limits apply on write only. Reading never truncates or normalizes stored data.
- CommunityGlows links the package as it links `@shipglows/account-deletion`.
- Operator rules: no build, and tests and lints run only when asked. Dev sessions go through `s`. Direct work on `main`, no branch or worktree, no push without a request.

## Test Contract

- Surface: pure packages, Flutter widgets, CommunityGlows Flutter and Vue, DreamGlows Flutter and TS.
- Automated: shared JSON fixtures executed by both languages (rank, commands, refusals, projections, codec round-trip), package unit tests, widget tests for pointer and keyboard reorder, 320 px width and doubled text.
- Execution: tests are written with the code. Running the parity fixtures needs the operator's explicit approval, because of the rule above. Without it, the chantier ends as "written, not verified".
- Manual: dev-session check per consuming app, including signed-in protected data where the app has an account. Build success is never proof.
- Exceptions: no browser or provider proof for the pure packages.

## Dependencies

`shipglows_organize` (rank, tags, tree), `shipglows_theme`, `shipglows_icons`, `shipglows_tag_picker`, `shipglows_swipe_actions`. No new third-party dependency. The fixture `dreamglows/packages/path-core/fixtures/action-rank-v1.json` is the rank authority and is copied, with its version, into the shared fixtures.

## Invariants

1. Dart and TypeScript give the same result for every fixture.
2. Decoding then encoding a task returns the same JSON value, unknown fields and statuses included.
3. A refused command changes nothing.
4. Moving one task rewrites as few ranks as `planRankMove` allows.
5. Core packages have no I/O, global clock, UI or backend import.
6. Sharing never changes what an existing app has stored.

## Links & Consequences

- Upstream: `shipglows_organize`. Its README already defers status and due dates to a later package, and will point here.
- Downstream: CommunityGlows (web, extension, desktop, Flutter) and DreamGlows (Flutter, Obsidian, extension, backend) through `path-core`. Each adoption phase revalidates its consumers.
- `shipglows_recents` mentions tasks as generic picker ids: no impact.
- `tool/gen_catalog.dart` regenerates `flutter/CATALOG.md`.

## Documentation Coherence

- Package READMEs, with an adoption guide and the workflow examples above.
- `flutter/CATALOG.md`, `shipglows_organize/README.md`, the engine root README's TypeScript section, engine `TASKS.md`.
- `communityglows/shipglows_data/technical/context.md`: remove the stale "sans sync Convex", describe the adapter.
- `dreamglows/shipglows_data/workflow/TASKS.md`: revise decision D9, which keeps `set-action-rank` local.
- `dreamglows/shipglows_data/technical/code-docs-map.md` and the CommunityGlows equivalent.

## Edge Cases

**ZOMBIES coverage**

- Zero: empty list, empty workflow rejected at construction, no eligible next task (`no-tasks` versus `no-eligible-tasks`).
- One: move within a one-item column, restore of the only task.
- Many: long lists stay lazily built; a move across an unranked tail ranks only what it passes.
- Boundary: civil versus zoned dates across midnight and time zones, limits exactly reached, rank length cap.
- Interface: older client writing during a rollout; old web client filtering a task whose status it rejects, which is why the statuses stay frozen.
- Exceptions: undecodable record, unknown status, parent deleted or missing, parent cycle, failed save.
- Simple: quick add with a title only yields a valid task in the initial status.

## Implementation Tasks

Each task is a milestone commit in its repository.

1. **CommunityGlows Flutter, lost fields.** In `app/lib/features/tasks/tasks.dart`, keep `contactIds`, unknown keys, unknown statuses and undecodable records through read and write. Add a round-trip test. Standalone, no engine dependency. Protects the data now.
2. **Fixtures and TypeScript core.** Create `typescript/shipglows_tasks` with model, workflow, commands, projections, codec, rank port and `fixtures/*-v1.json`. Depends on nothing. Check: TS suite over the fixtures.
3. **Dart core.** Create `flutter/core/shipglows_tasks_core` with tests reading the TS fixtures, then run `tool/gen_catalog.dart` and `tool/check_layers.dart`. Depends on 2.
4. **Flutter widgets.** Create `flutter/components/shipglows_tasks`. `TaskList`, `TaskBoard`, `TaskEditor`, `TaskQuickAdd`, with builders for extra fields and row metadata, and keyboard reorder. Depends on 3.
5. **CommunityGlows Flutter adoption.** Add a wire adapter mapping `note`, `status`, `priority` (`normal` ↔ `medium`), `dueDate` ↔ `schedule.end`, the additive `rank`, and everything else into `extensions`. Replace the private logic and `tasks_screen.dart` with the shared widgets, keeping the same visible behavior. Depends on 1, 4.
6. **CommunityGlows web adoption.** `contextualTasksService.ts` delegates to `@shipglows/tasks` through the same adapter, under the same wire fixture. `replaceState` stops dropping invalid records. The Pinia store's API and the Vue components stay. Delete the unimported `kanbanService.ts` copy. Depends on 2, 5.
7. **DreamGlows adoption.** `path-core` and `path_core_dart` delegate rank, next-task and overdue logic through an `action ↔ task` adapter. Every existing DreamGlows fixture stays unchanged and must still hold. Depends on 2, 3.
8. **Documentation.** Update everything in Documentation Coherence, and record the closure state. Depends on 2 to 7.

## Acceptance Criteria

- [ ] Every shared fixture passes in Dart and TypeScript.
- [ ] A CommunityGlows task with `contactIds` and an unknown field, passed through Flutter read, edit and push, keeps both.
- [ ] A task with an unknown status is displayed as unrecognized, excluded from projections, and written back unchanged.
- [ ] Existing `contextual-tasks-v1` snapshots and DreamGlows documents load with no migration and round-trip as equal JSON values.
- [ ] All existing DreamGlows fixtures still hold, unedited.
- [ ] A task can be reordered by pointer, touch and keyboard, at 320 px and with doubled text.
- [ ] A refused command changes nothing and returns its stable code.
- [ ] `check_layers.dart` passes and the catalog lists all new packages.
- [ ] No raw colors, radii or durations in `shipglows_tasks`.
- [ ] CommunityGlows and DreamGlows behave as before in their dev sessions, signed in where they have accounts.

## Test Strategy

Fixtures are the contract and TypeScript owns the files, as in DreamGlows. Each behavior gets one fixture case before its implementation in either language. App adapters get their own wire fixtures built from real document shapes with synthetic content. Widget tests cover keyboard and narrow layouts. Visual and login checks happen in dev sessions.

## Risks

- **Older CommunityGlows Flutter clients** keep erasing `contactIds` until updated. Task 1 ships first to shorten this window. Residual until those clients update.
- **Last write wins in CommunityGlows' snapshot** remains: two devices can still overwrite each other. Accepted for this chantier, and needs its own one on `@shipglows/sync`.
- **Over-generalizing:** the model stays minimal, and everything app-specific goes in `extensions`. A field is promoted only when two apps use it.
- **DreamGlows regression:** adoption comes last, behind its fixtures, with no format change. If the adapter proves awkward, task 7 stops at rank and the remaining logic stays local.
- **Concurrent engine work:** the engine's working tree has uncommitted lint and tooling changes from another session (`shipglows_lints`, `tool/verify.dart`). New packages follow whatever is committed when they start, and commits stay file-scoped.

### Security Gate

No network, authentication or secrets in the packages, so the OWASP web categories do not apply. Remaining rules: decoding validates types and treats input as data; `extensions` and notes are rendered as plain text and never as HTML or links; CommunityGlows' URL sanitization stays in its adapter, unchanged; tasks and notes never reach logs. Ownership and tenant checks stay in each backend (`requireAuthUserId` in CommunityGlows).

## Execution Notes

- Start with `dreamglows/packages/path-core/src/action-rank.ts`, `next-action.ts`, `packages/path_flutter/lib/src/overdue_actions.dart` and `communityglows/packages/core/src/services/contextualTasksService.ts`.
- Follow `shipglows_rituals_core` and `shipglows_rituals` for the core/component split and host-owned saving.
- Follow `typescript/shipglows_sync/package.json` for the private, source-exporting TS package.
- Copy DreamGlows' semantics, not its `Map<String, dynamic>` style: the shared Dart model is typed.

## Open Questions

- **Q1. Running the parity fixtures.** Recommended: approve running the shared fixtures and the adapters' tests for this chantier, since parity is the contract. Otherwise it closes as written but unverified.

## Skill Run History

| Date | Skill | Model | Result |
| --- | --- | --- | --- |
| 2026-11-07 | 100-sg-spec | Claude Opus 5.5 | Spec written and self-reviewed from the 2026-11-06 audit |

## Current Chantier Flow

`spec` done → `ready` pending operator approval → `start`, `verify`, `end` not started.
