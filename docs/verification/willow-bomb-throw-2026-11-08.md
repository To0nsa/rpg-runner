# Willow bomb throws — local verification

Source: the task commit containing this record, following sprite-scale milestone
`cc1e69cc`. Implementation is prepared for compatibility `2026.11.8.6`; no cloud
deployment, run cancellation or data mutation was performed.

## Delivered behavior

All four bombs spend 6 Supplies on commitment and retain their cooldowns. They
release from the mirrored throwing hand on frame 6, select the farthest
reachable hostile within 320 units and follow an upward, gravity-driven arc.
The aimed flight is 0.8 seconds; an empty scene uses a forward lob. First
hostile/terrain contact or the one-second release fuse triggers one area hit.
Allies do not trigger it. Bomb, fuse and explosion retain Willow's 1.35 scale.

The [hand-release review](assets/willow-bomb-hand-release-2026-11-08.png) shows
the actual frame and bomb sprites at runtime scale, across pistol, crossbow and
shotgun families in both directions. Local Training Field captures also show
the explosion at the end of its throw. These are local render checks, not a
physical-device playtest.

## Checks

| Working directory | Command/check | Result |
| --- | --- | --- |
| Root | `dart analyze packages/runner_core` | Pass |
| Root | Targeted `dart analyze` of changed UI/state/test files | Pass |
| `packages/runner_core` | `dart test test/combat/bounty_hunter_test.dart --reporter expanded` | 253 pass |
| Root | `flutter test test/core test/ui/text/ability_damage_tooltip_test.dart test/ui/state/firebase_run_session_api_test.dart --no-pub --reporter expanded` | 536 pass |
| Root | `flutter test test/ui/pages/select_character/loadout_setup_page_phase4_test.dart --plain-name 'Willow training loads' --no-pub` | 3 pass |
| `services/replay_validator` | `dart analyze` | Pass |
| `services/replay_validator` | `dart test test --reporter expanded` | 367 pass |
| `services/replay_validator` | `dart test test/bounty_hunter_replay_test.dart --reporter expanded` | 22 pass |
| Root | `corepack pnpm --dir functions build` and `build:test` | Pass |
| `functions` | `node --test lib_test/test/runs/compatibility.test.js` | 3 pass |
| Root | `node functions/tool/refresh_navigation_routes.mjs` | Offline routes regenerated for the new compatibility |
| Root | `dart run packages/runner_core/tool/update_navigation_revision.dart --check` | Existing graph fingerprint remains current |
| Root | `git diff --check` | Pass |

Combat coverage includes moving targets/casters, airborne mirrored releases,
farthest selection and stable ties, blocked-arc rejection, finite no-target
flight, 30/60/120 Hz, owner removal, one-way ascent/descent, swept first contact,
blast wall shielding, allies, one damage pulse, interruption and the 5.99/6
Supplies boundary. Render/replay assertions check frame-6 position and the
actual detonation clock. The final normalization of stored intent direction
was followed by focused analysis, all 253 combat tests, the three bomb replay
cases at 30/60/120 Hz and all three Training Field cases.

Initial failures were obsolete free/drop-bomb assertions and a compatibility
fixture treating the new current version as future. Those were corrected to
the requested behavior; checks above passed afterward. The first standalone
Functions test invocation also used the root working directory; rerunning from
`functions` satisfied its repository-relative file reads.

## Compiled benchmark

Built locally with `dart compile exe bin/server.dart -o
../../.tmp/willow_bomb_validator.exe`, then ran `benchmark --ticks=36000 --strict`.
All gates passed: Forest 0.677s and Field 0.585s for 600 simulated seconds each.
The [raw result](assets/willow-bomb-benchmark-2026-11-08.json) reports deterministic
outcomes and sustained progress. This is the existing generated-terrain benchmark,
not a combat-load, device or container benchmark.

Executable SHA-256:
`be0715324da0b705bedca1b503a8e4245bb85edd8252742db268fd17e41b81d5`.

Navigation geometry/build identity is unchanged, so graph packs need no rebuild.
The client, issuer and worker compatibility must ship together through the
normal authorized release workflow. Device acceptance and deployment remain
outside this local implementation.
