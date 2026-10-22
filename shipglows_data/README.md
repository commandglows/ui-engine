---
artifact: project_governance
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: ShipGlows UI Engine
created: "2026-10-22"
updated: "2026-10-22"
status: active
source_skill: sg-docs
scope: project-governance
owner: Diane
confidence: high
risk_level: low
security_impact: none
docs_impact: yes
linked_systems:
  - ../README.md
  - ../flutter/
depends_on: []
supersedes: []
evidence:
  - "2026-10-22: governance topology audit found no shipglows_data/ corpus; the tray decision and its migration plan lived only in session notes."
next_review: "2027-01-22"
next_step: "Record each new shared package and each consumer migration in technical/context.md and workflow/TASKS.md."
---

# UI Engine Governance

Canonical internal corpus of `shipglows-ui-engine`: shared Flutter interface
packages for ShipGlows desktop apps, one package per component, consumed by
path dependency.

## Canonical Entry Points

- `../README.md`: usage and API of every package (integration source of truth).
- `technical/context.md`: package map, consumers, platform scope.
- `technical/contracts/tray-native-decision.md`: why the tray is native Win32,
  inventory of the apps' trays, migration order.
- `workflow/TASKS.md`: open migrations and follow-ups.

## Scope Boundary

Private infrastructure: no public editorial corpus. App-specific behavior
stays in each app's own governance; this corpus only records what the shared
packages promise and which apps adopt them.
