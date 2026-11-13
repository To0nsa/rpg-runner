# Campaign decoration introduction

Authorized: add one editable lesson after Reporting for Duty's first pool.
Baseline: existing water tutorial and other work are uncommitted; preserve them.

Acceptance:
- [x] Reference the real pale tree; its spotlight follows current sprite geometry.
- [x] Trigger on grounded, non-swimming arrival beyond the selected water, including a jump across.
- [x] Fresh movement resumes; no additional HUD is revealed; completion is per attempt.
- [x] Reuse bilingual panel, manual spotlight, captured mission and transactional editor flows.
- [x] Reject missing/non-decoration/ambiguous targets rather than silently selecting another.
- [x] Verify strict source, editor edits and continuous swim/bypass gameplay; regenerate and rebuild editor.
- [x] Review task diff and update implemented docs/evidence.

Approach: retain the prefab source key as visual metadata through the existing
chunk materializer/generator. This lesson references a unique single-sprite
decoration in its mission chunk and the water region that precedes it. This avoids
duplicating the tree's rectangle or identifying it by mutable list order.
Simulation, collision, resource costs, tint and replay commands remain unchanged.

Completed with 51 targeted tests passing, clean focused analysis, source and
localization freshness, and a rebuilt Windows editor. A final build refresh
incorporated concurrent shared UI changes; no tutorial sources changed during it.
See [verification and limits](../../../verification/campaign-decoration-tutorial-2026-11-13.md).
