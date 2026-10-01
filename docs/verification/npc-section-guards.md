# NPC section guards verification

Verified: October 2, 2026. Branch: `feature/npc-section-guards`.
Isolated worktree: `C:/dev/rpg_runner/.tmp/npc-section-guards`.
Base: `135fa7cc`. Implementation commits: `fde0dafe` (section occurrence
ownership) and `ef273f7d` (guard lifecycle, targeting and compatibility).
No deployment, merge or production data change was performed.

## Delivered behavior

Rescued and unassisted cleared survivors remain vulnerable and fight within the
containing Flow section occurrence. Active encounters retain chunk confinement;
automatic levels and standalone Chunk Play use one chunk. Repeated section/group
IDs cannot share a territory. Guard rosters refresh before the shared AI target
selection and retain stable targets and navigation evidence. Ordinary enemies
can target guards with player fallback; active encounter policies remain owned
by the encounter. Later deaths never change settled rescue rewards. Run end
stops guards even after their original encounter records retire.

Kinematic ground targets such as Derf receive support evidence from the existing
terrain placement query without moving them or adding dynamic contact state.
Movement, cooldown, status, resource, faction and attack execution stay in their
existing Core systems. Client, Functions and worker share gameplay compatibility
`2026.10.1`; the worker rejects `2026.09.10` and other older versions before replay.
Scoring, rules, ghosts and replay/command encoding are unchanged.

## Passing checks

| Check | Evidence |
| --- | --- |
| Core analysis | `dart analyze packages/runner_core`: no issues |
| Core package | `dart test`: 736 passed, including the traversal matrix and controls |
| App analysis | `dart analyze lib test`: no issues |
| Flutter | `flutter test test/core test/game/npc_render_test.dart test/ui/state/app_state_run_ticket_prefetch_test.dart`: 385 passed |
| Worker analysis | `dart analyze` from the validator: no issues |
| Worker tests | `dart test test`: 174 passed |
| Functions | `corepack pnpm --dir functions build` and `test`: build passed; 212 emulator tests passed |
| Editor | `dart analyze`: no issues; focused encounter authoring/source tests: 15 passed |
| AOT worker | `dart compile exe bin/server.dart` succeeded |
| Strict benchmark | Compiled `benchmark --ticks=36000 --strict` passed all nine gates at clean implementation commit `ef273f7d` |

The section fixture uses three chunks of production Field flat terrain with
synthetic encounter/section metadata and camera auto-scroll disabled. Each NPC
continuously crosses the original chunk seam, attacks a later enemy and takes
retaliatory damage at catalog capabilities. A separate camera-follow
trace, with the same disabled auto-scroll, advances the player and proves that the living guard remains in later
terrain after its origin chunk retires. No actors are teleported in these traces.
Real motion tests drive every NPC to both expanded full-body boundaries.

The worker replay regression covers all three archetypes, seeds 7/42/2026 and
30/60 Hz (18 combinations). It compares entity state at replay checkpoints and
completion, verifies continuous seam crossing/damage, and checks immutable rescue
statistics. Unit tests cover enemy entry/exit, territory edges, repeated sections,
sticky targets, blocked navigation evidence, active encounter policy ownership,
player fallback, deaths, destruction/recycled IDs and run-end cleanup.

## Horizons and limitations

The committed-runtime traversal matrix covers the complete finite Forest assembly
before its repeating final section, plus 32-chunk Field and new_level prefixes,
for Grojib, Hashash and Unoco with seeds 7/42/2026: 27 cases plus harness controls.
Derf is stationary and has placement/support tests instead. This matrix is enemy
pursuit evidence, not complete NPC Forest traversal, camera or combat coverage.

Generated freshness is not green on the inherited baseline. Temporary regeneration
passes dry-run but exposes four Forest traversal failures, independently reproduced
at the pre-feature revision. The generated refresh was discarded and no authored
geometry was changed. See the [open content finding](../audit/forest_content_drift_2026-10-02.md).
Passing committed-runtime tests must not be presented as current authored Forest
clearance evidence.

The [benchmark report](npc-section-guards-benchmark.json) is local Windows AOT
evidence on the unchanged committed runtime. It uses no-enemy streams and does
not measure maximum-density guard combat. Its Forest trace advances about 332
world pixels, so it is not finite-route traversal proof. It does not replace the
exact release-image one-CPU/512 MiB container gate or signed-in gameplay smoke.
The latest production remains frozen `6bfda4c8` at `2026.09.10`. A future
`2026.10.1` cutover requires matching client/Functions/worker artifacts, old
issuance stopped and validation/settlement drained, without an implicit reset.
