# NPC section guards

Created: October 2, 2026.
Branch: `feature/npc-section-guards`.
Status: implemented and locally validated; no deployment.
An inherited Forest content finding remains unresolved outside this workstream.

## Scope and decisions

After an encounter clears its required enemies, living NPCs guard that occurrence
of the containing Flow section. Unassisted clears also produce guards without
rescue credit. Active encounters retain their chunk bounds and explicit targeting.
Failed or abandoned groups remain protected. Automatic levels and Chunk Play
fall back to the owning chunk. Guards remain vulnerable; earned rescue counts and
points are immutable even if a guard subsequently dies. No deployment is requested.

Use the scheduler's selected section occurrence, not group names or repeated
source IDs. Carry its metadata through streaming, derive immutable section bounds,
and expand survivor motion bounds only at completion. Refresh explicit guard
rosters before shared AI selection, retaining targets and negative navigation
evidence when membership is unchanged. Ordinary enemies in a guard territory
may select guards using nearest-opponent policy with player fallback; active
encounter policies remain authoritative. No player participation credit comes
from guards. Preserve normal streaming/camera cleanup and detached attack lifetime.

Considered approaches: keep guards in their original chunk; retain complete
sections and add escort behavior; use existing streaming/navigation with a
section-bounded survivor lifecycle. The last fits existing systems without
retaining terrain indefinitely or changing actor capabilities.

## Acceptance criteria

- [x] Streaming retains section occurrence metadata in actual and prepared selections.
- [x] Cleared survivors cross chunk seams within their own section, with complete
  body containment at both section boundaries and no access to later occurrences.
- [x] Dynamic enemy entry, exit, death and entity-ID reuse update rosters safely;
  selection and blocked-target evidence remain stable across unchanged ticks.
- [x] Ordinary enemies can target guards; active encounter ownership/policies persist.
- [x] Guards can attack, take damage and die without changing settled rescue awards.
- [x] Failed/abandoned groups stay safe; run end stops surviving guard combat;
  origin-chunk retirement does not remove a guard in later loaded terrain.
- [x] Automatic/standalone chunk scenarios use one-chunk territories.
- [x] Core, Flutter, backend and replay worker compatibility advance together;
  old gameplay versions remain rejected by the new worker.
- [x] Relevant analyzer, Core/Flutter/validator/backend tests, generated freshness,
  traversal matrix and compiled worker benchmark are recorded.

## Milestones

1. Section metadata and survivor lifecycle, with focused tests.
2. Dynamic targeting and streamed combat/movement regressions.
3. Compatibility, documentation, full relevant validation and final handoff.

## Validation evidence

Section ownership milestone: `dart analyze packages/runner_core` passed; 21
focused region/encounter-definition/preparation tests passed.

The existing traversal matrix covers Forest's finite authored assembly
and 32-chunk Field/new_level prefixes for seeds 7, 42, 2026 and Grojib, Hashash,
Unoco. It does not prove every NPC route; dedicated guard fixtures must verify
continuous NPC movement and combat without teleporting actors.

Delivered commits: `fde0dafe` and `ef273f7d`. All feature acceptance criteria
are implemented; the validation checkbox records checks and their limits, not
a claim that inherited generated freshness or current authored Forest traversal
passes. Full results: [verification](../../../verification/npc-section-guards.md).
The [Forest content finding](../../../audit/forest_content_drift_2026-10-02.md)
reproduces before this feature; archiving this completed plan does not close it.

Final local checks: 736 Core tests, 385 Flutter tests, 174 worker tests, 212
Functions emulator tests and 15 editor tests passed; all relevant analyzers
passed. The clean compiled worker at `ef273f7d` passed the strict 36,000-tick
benchmark for all three included levels. Eighteen guard replay combinations
cover all NPCs, seeds 7/42/2026 and 30/60 Hz. Continuous Field guard fixtures
and full-body boundary tests run with catalog capabilities and no teleporting.

Freshness was checked before interpreting current authored-source traversal.
After temporary regeneration the generator passes, but four Forest traversal
cases fail identically in a detached pre-feature worktree. The generated refresh
was discarded. Committed-runtime traversal passes all 27 cases plus controls;
current authored Forest clearance is explicitly not claimed. No maximum-density
guard, exact release-container, signed-in smoke or full NPC Forest route evidence
is supplied by these local checks.
