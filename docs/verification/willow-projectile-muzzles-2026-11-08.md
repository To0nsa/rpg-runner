# Willow projectile muzzle alignment — November 8, 2026

Source: local changes on the November 7 checkout, alongside concurrent Willow
equipment and UI work. Validation below includes the eight currently authored
ranged items; unrelated edits and the existing Git index are preserved.

## Result

Willow releases bullets, bolts and every pellet from the gun's visible firing
tip. Authored native endpoints account for base-cell placement, canvas pivot
and 1.35 world scale. Standing, airborne and all eight running-body poses use
the same Core posture/frame selection as the visible sprite. Launch samples
current position and facing after motion, with one shared origin per fan.

Auto aim predicts from that attachment and checks the same muzzle sightline.
A close quarry between the body and barrel retains the selected muzzle's facing
rather than flipping the sprite when its projectile must travel back toward it.
Bomb drops, other casters, command encoding and phase order retain their existing
contracts. The current prepared compatibility is `2026.11.8`; these changes need
matching client and worker artifacts and have not been deployed.

## Local checks

| Directory | Command | Result |
| --- | --- | --- |
| Root | `dart analyze packages/runner_core test/game/willow_muzzle_render_test.dart services/replay_validator/test/bounty_hunter_replay_test.dart` | No issues |
| `packages/runner_core` | `dart test test/combat/bounty_hunter_test.dart test/combat/projectile_auto_aim_test.dart --reporter expanded` | 206 passed; includes release-time movement/posture, both facings, 30/60/120 Hz, common-origin fans, once-only release and close/far auto aim |
| Root | `flutter test --no-pub --no-version-check test/game/willow_muzzle_render_test.dart --reporter expanded` | 1 passed; all 80 authored attachment samples touch the last opaque barrel pixel and the adjacent outward pixel is transparent |
| `services/replay_validator` | `dart test test/bounty_hunter_replay_test.dart --reporter expanded` | 8 passed; actual first-shot snapshots match the muzzle, then encoded replay reproduces the run for every gun |
| `packages/runner_core` | `dart test --reporter expanded` | 2,501 passed in 3m41s |
| Root | `flutter test --no-pub --no-version-check test/core/anim_system_test.dart test/core/anim_resolver_test.dart test/core/command_scheduling_test.dart test/core/determinism_test.dart test/core/fixed_point_pilot_test.dart test/core/projectile_homing_and_pierce_test.dart test/core/projectile_hit_system_test.dart --reporter expanded` | 68 passed in 49s |

Navigation fingerprint check from the root also passed:
`dart run packages/runner_core/tool/update_navigation_revision.dart --check`
retained `bd2274e0b71f13d538e131be959817d040eb11182da317b2db98903ed26a1e98`.
Task-path `git diff --check` passed. The full workspace check additionally saw
an unrelated trailing blank line in an in-progress equipment test; it was left
to its owning workstream. Muzzle changes remain uncommitted because character,
Core wiring, combat/replay tests and Willow docs overlap that concurrent work;
no other task's staged content was changed.

The reviewed real-sprite contact sheet is ignored scratch output at
`.tmp/willow_muzzle_render.png`. Green points mark the exact launch attachments
at live scale. Diagnostic command logs are also in `.tmp/willow_muzzle_*`.

No phone acceptance, hot restart, app rebuild, backend deployment or account
mutation was performed. This report describes local source and test evidence.
