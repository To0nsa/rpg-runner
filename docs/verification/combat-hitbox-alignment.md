# Combat hitbox alignment verification

Verified October 5, 2026, against the working source based on `267dac64`.
Combat implementation and compatibility commit: `3cfccd91`.
Existing pickup-placement and release work was present during validation and
was preserved. Source compatibility is `2026.10.6`; no production deployment
was performed.

## Delivered inventory

| Actor or delivery | Resolved behavior |
| --- | --- |
| Éloïse and Éloïse WIP | Shared strike/back-strike weapon poses, mirrored source-facing correction, aimed pose rotation, compact roll and leaning/air/hit body capsules |
| Warrior | Strike blade geometry and leaning vulnerable body, retimed to committed action phases |
| Huntress | Separate stab/slash weapon arcs, leaning body, spear launch and fitted flight poses |
| Ranger | Bow release timing and fitted arrow flight; stable body baseline with air/hit poses |
| Grojib | Both complete strike strips, active blade arcs, leaning body and profile-based AI reach |
| Hashash | Strike/ambush blade arcs, compact body poses, shared action timing |
| Unoco | Melee pose 6 damage, recovery pose 7, compact flying body and explicit cast presentation |
| Derf | Cast body pose; world-anchored explosion damages only visible poses 2 and 3 |
| Eight bolt types, spear and arrow | Generated opaque silhouette capsules at runtime scale; Core owns startup/repeat frames and direction |
| Existing traps and poison dart | Retain authored trap geometry; target the same resolved vulnerable bodies |
| Live and ghost presentation | Snapshot flight/actor frames, fixed-tick impact clocks and exact oriented capsule debug overlays |

All authored melee and target-point deliveries now require explicit profiles.
Compound segments damage a target once per delivery policy, rather than once
per segment. Fast piercing travel uses swept contacts ordered by arrival and
entity ID. Interrupting an attack removes its invisible weapon geometry.

Terrain/navigation capsules and movement capabilities are unchanged by this
work. Roll changes vulnerable body/contact shape without adding invulnerability.
Shield block and Aegis Riposte remain omnidirectional by owner instruction.
Damage, costs and committed attack durations retain their existing tuning;
visible damaging poses, effective reach and resulting hits intentionally change.

## Passing checks

| Check | Result |
| --- | --- |
| Analysis of Core, game, client compatibility source, validator, affected tests and combat tools | No issues |
| Complete portable Core suite | 800 passed |
| Complete Flutter `test/core test/game` suites | 584 passed |
| Complete replay-validator suite | 188 passed |
| Client ticket-prefetch target | 16 passed |
| Final startup/back-strike target after initial-body snapshot refresh | 3 passed |
| Final ghost/debug-render targets after obsolete flight-clock cleanup | 11 passed; game analysis clean |
| Functions production and test builds | Passed |
| Functions cross-layer compatibility test | Passed; issuer/client/worker agree, retired versions rejected |
| Affected board, leaderboard, run/auth/submission and compatibility emulator targets | 62 passed against the local demo Firestore emulator |
| Projectile generator `--check` | Fresh output |
| Chunk runtime generator dry-run | Fresh output; 81 chunks, 3 levels, 3 parallax sets and 3 materials; no blocking issues |
| Final `dart compile exe bin/server.dart` | Succeeded |
| Final compiled `benchmark --ticks=36000 --strict` | All nine gates passed |

The full suites precede the final initial-body snapshot refresh and removal of
unused renderer flight-clock code; focused startup/render checks and final
executable compilation cover those changes. The
Functions change is compatibility enforcement and fixtures; the six affected
targets passed, while the complete backend suite was not rerun. No production
callable or production state was mutated.

Focused regressions include each melee profile at 30/60/120 Hz and
0.75/1.0/1.5 action speed, both NPC facings, guard hold, roll/terrain separation,
back-strike mirroring, aimed rotation, compound-hit
deduplication, harmless explosion poses, outside-art misses, projectile clocks,
oriented flight silhouettes, piercing sweeps and rendered rounded-end bounds.
Source art was visually reviewed against the authored active-pose capsules.

The seed-42 ordinary-combat snapshot trace was intentionally updated for these
changed poses and hits. It ends at tick 414 and includes Grojib, Hashash and
Unoco; the expected SHA-256 is
`5b9183a57849295e0c3093af160bf342dfada332ba0c2c370a4ac22bb71967e1`.
It is a regression trace, not an assertion that every enemy attack executes in
that short scenario.

## Traversal and benchmark scope

The Core suite includes the fresh-source 27-case movement matrix: Grojib,
Hashash and Unoco at seeds 7, 42 and 2026 across Forest, Field and `new_level`.
Forest crosses its complete finite route; Field and `new_level` declare a
32-chunk horizon. Exact rock-route regressions and finite clear/blocked finish
controls also pass. Derf is stationary and excluded from pursuit. These
movement checks isolate navigation from combat and do not establish full-run,
spawn, camera or player traversal coverage.

The [native benchmark report](combat-hitbox-alignment-benchmark.json) records
Windows x64, Dart 3.13.1, `dirty: true`, and the pre-commit base revision.
Each of the three levels replays 36,000 ticks at 60 Hz with deterministic
outcomes and passes the time/throughput gates. The fixture has no enemy stream;
it verifies compiled replay/terrain throughput rather than combat stress load.
The strict exact-image one-CPU/512-MiB container gate, production cutover and
signed-in gameplay/replay/settlement/leaderboard/ghost smoke remain release work.

See the [technical contract](../tdd/combat_pose_geometry.md),
[gameplay design](../gdd/combat/combat_system_design.md),
[completed plan](../archive/2026-10-05/building/combat_hitbox_alignment.md), and
[release checklist](../building/rescue_release_operations.md).
