# Combat hitbox alignment

Accepted October 5, 2026. Scope: both player entries, all three NPCs, all four
enemies, their melee/projectile/impact geometry, action timing, and debug views.
Shield block and Aegis Riposte retain protection from every direction, as
requested by the owner. Production deployment is a separate release action.

## Approach and acceptance

Use reviewed, anchor-relative capsules for individual combat poses, following
the existing trap model. Resolve animation and collision from the same fixed-tick
frame selection. Separate vulnerable body geometry from immutable terrain
capsules so rolls and leaning poses do not alter navigation or support.

Changing only rectangle dimensions would leave weapon arcs and timing mismatched.
Runtime pixel collision would add asset I/O to Core and change replay authority.
Explicit catalog geometry fits the current deterministic content boundary.

- [x] Shared capsule and action-frame contracts; remove ambiguous authored melee dimensions.
- [x] Reviewed melee poses for player, Warrior, Huntress, Grojib, Hashash and Unoco.
- [x] Phase-aligned animation under action-speed and tick-rate changes; complete Grojib strips.
- [x] Vulnerable body poses, especially roll/contact stun, without terrain changes.
- [x] Fitted projectile poses, launch/release visibility and Unoco cast presentation.
- [x] Derf explosion visible damage poses and fitted area geometry.
- [x] Exact snapshot-driven capsule debug views, including rotation and rounded ends.
- [x] Regression coverage for misses outside art, both facings, interruption,
      hit-once behavior, modified timing and deterministic replay.
- [x] Current TDD/GDD, gameplay compatibility and release preparation notes.

Acceptance requires all shipped combat attacks to use explicit geometry, no
damage on empty explosion poses, identical geometry in debug and narrow phase,
unchanged terrain capability/authority, and passing Core, relevant render and
validator checks. Run the complete Core suites because this changes shared
collision and action timing; run backend/validator compatibility checks and the
validator's required compile/strict benchmark. Do not deploy as part of this task.

## Progress

Completed October 5, 2026. Core, Flutter Core/game, and replay-validator suites
pass. Projectile generation is reproducible, generated terrain is fresh, and
the compiled native strict benchmark passes all nine gates. Source client,
Functions and worker agree on `2026.10.6`. Existing unrelated terrain/release
work is preserved. Shield protection remains omnidirectional.

See [verification](../../../verification/combat-hitbox-alignment.md) and the
[technical contract](../../../tdd/combat_pose_geometry.md) for results and
coverage. Production image preparation, container benchmarking, cutover and
signed-in smoke remain in the separate release workflow.
