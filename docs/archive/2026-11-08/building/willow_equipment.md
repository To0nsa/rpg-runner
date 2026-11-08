# Willow equipment parity

Authorized scope: 28 additional items, tuning for the three starter kits,
complete character/store/render/replay integration and stale equipment docs.
Starting checkout: clean `8438ff4c`. Execution uses reviewed commands outside
the sandbox because sandboxed process startup hangs; no configuration changed.

Acceptance: each character has 8 primary, 10 secondary, 8 resource kits/books,
8 ranged items and 8 shared accessories. New items cost the existing 150 gold;
only the original starter items are granted. Preserve retained enum indices,
character ownership, ability behavior and deterministic replay.

- [x] Read current catalogs, layer rules and parent brand references.
- [x] Author catalogs, shared names, family art and backend item eligibility.
- [x] Verify payloads, reactive effects, ownership, store, UI and replay behavior.
- [x] Refresh generated projectile geometry and Admin catalog fixture.
- [x] Update GDD/TDD and stale descriptions.
- [x] Record final local verification evidence.
- [x] Review the full diff, validate and archive this checklist.

Commit deferred: concurrent muzzle and Codex work overlaps these files. No
changes were staged or committed from this workstream. Implementation is complete.
See [local verification](../../../verification/willow-equipment-2026-11-08.md).

Prepared compatibility: `2026.11.8`; no deployment or live account mutation.
Dedicated item illustrations and live balance/device acceptance remain unrun.

Concurrent edits appeared after the initial clean check, including menu/build
layout and Willow muzzle alignment. Preserve them; do not stage overlapping
files wholesale. Current Core tests include those new muzzle checks.
