# Campaign blessing objective and introduction

Authorized: first introduce a basin objective, resume for a real landing, then
explain the lit fire and regeneration in two paused pages. Preserve the existing
uncommitted framework and concurrent work; the task baseline is captured locally.

- [x] Add a Core-owned, shrine-bound mission objective with strict source/generator parity.
- [x] Add one three-step tutorial with gameplay between objective and reward pages.
- [x] Share objective acknowledgement, step authoring and spotlight presentation.
- [x] Bind editor target selection, Save/Undo/captured Play to the shrine marker.
- [x] Author Reporting for Duty and bilingual text; leave terrain/regen tuning unchanged.
- [x] Test real landing, bypass/backtrack, input/pause/restart, objective exit gate and replay.
- [x] Verify editor authoring, visual preview, generated freshness and localization.
- [x] Review changes, update current docs and rebuild the Windows editor.

Core owns completion independently of tutorial visibility. The mission selects
one existing shrine marker for this objective; disabling guidance cannot remove
the required landing. The first page reveals the objective, movement resumes for
practice, activation opens page two, Next opens resource/indicator guidance, and
fresh movement resumes. Completion acknowledgement ages only during gameplay.

Continuous traversal acceptance: Reporting for Duty, seed 42, catalog Éloïse,
from authored spawn through the seventh chunk's basin, with finite budgets and
ordinary movement/jump inputs. No teleport, physics changes or enemy coverage.

## Implementation decisions and validation

- Added an independent exact-shrine Core objective; guidance never grants progress.
- Extracted shared step values/dialog from the jump sequence, preserving its schema.
- Corrected ordering found by the real landing test: activation precedes the
  living-player objective/exit gate, after death/failure. Simultaneous exit and
  shrine activation are covered; the next gameplay release must include this change.
- Screenshot review found the centered reward card covered the lit basin. Shared
  world-target placement now uses available space beside/above the spotlight.
- Continuous tests retain the actual fifth-chunk pool/platform route, both sixth-
  chunk gaps and seventh-chunk statue. The return variant misses the basin first,
  backtracks, activates it, then crosses X 4200 with continuous actor state.
- Core integration (525), targeted Core (16), pipeline (23), UI (8), control modes
  (4), overlay layouts (8), editor dialogs/history/capture (9), worker (4), and
  generated fixture (1) pass. Root/editor/worker analysis is clean; generation,
  localization and Functions build pass. The Windows editor build passes and its final captured sources match.

See [verification](../../../verification/campaign-blessing-tutorial-2026-11-13.md) for
commands, source binding, visual review and explicit coverage limits.
