# Shoggoth boss redesign — October 9, 2026

This change is prepared source for gameplay compatibility `2026.10.11`; it has
not been deployed. The [gameplay specification](../gdd/ancient_god_bosses.md#shoggoth)
and [technical contract](../tdd/ancient_god_bosses.md#shoggoth-tactics) describe
the implemented behavior.

## Verified behavior

- 260 HP, range-based attack selection, bounded sweep approach and turning only
  between live strikes.
- Charges move at 360 units/second through ordinary terrain integration. Their
  direction locks after the warning. Final-phase return charges require natural
  completion of the exact first action, retain a full warning and have their
  own damage provenance and longer recovery.
- One-time minion waves at 70% and 35% health, including burst damage, healing,
  interrupted casts, admission failures, caps, expiry and recycled entity IDs.
- Sustained separation triggers checked teleports with a fixed destination
  marker. Invalid preflight falls back to offense; an invalidated visible mark
  never silently moves. Cancellation, replacement, death, stun and suspension
  cancel pending placement and charge continuation.
- Both characters clear the authored Forest Shoggoth room with ordinary combat
  inputs and cross its actual 600-unit exit boundary. Coverage uses seeds
  7, 42 and 2026 at 30, 60 and 90 Hz. Focused motion checks cover charge walls,
  arena bounds and sweep displacement. The blocked-approach marker check uses
  a separate terrain harness with a real wall.
- Protocol command replays reproduce both minion waves and a completed return
  charge at all three tick rates, including actor identities, health, positions
  and animation frames.

## Checks

| Check | Result |
| --- | --- |
| Core analysis | No issues |
| Worker boss replay test analysis | No issues |
| Generated-content dry run | Fresh: 83 chunks, three levels, three parallax themes and three terrain materials |
| New Shoggoth tactics, motion and arena tests | 103 passed as part of the boss suite |
| Complete Core boss directory | 506 passed; 23 failures described below |
| Worker `test/boss_replay_test.dart` | 30 passed |
| Flutter teleport cue, command scheduling, determinism and fixed-point pilot targets | Nine passed |
| Final replay-validator executable build | Passed |
| Final executable `benchmark --ticks=36000 --strict` | All nine determinism/throughput gates passed |
| `git diff --check` | Passed |

The Core and worker tests used the existing compiled Dart test runner snapshots
because the sandboxed `dart test` launcher stalled during dependency setup.
Flutter tests ran with `--no-pub` and SDK cache access; no dependency changes were
made. The validator benchmark ran locally on Windows with Dart 3.13.1 against
`normal-included-levels-no-enemy-stream`. It is not evidence of boss throughput,
Cloud Run container performance or a production release.

The broader boss run has five failures in `forest_boss_sequence_test.dart` and
18 Bringer platform-camper failures in `boss_arena_test.dart`. Before this task,
the working tree already changed Forest's boss order and section lengths,
Bringer's dimensions, and authored arena geometry. The sequence tests still
expect Bringer before Goddess, while the authored source now puts Goddess first.
The Bringer failures concern its pillar reaching platform campers. Those source
edits and tests are outside the Shoggoth change and remain unmodified by this
task. No clean-baseline rerun was performed; these failures are disclosed rather
than counted as successful regressions.

## Scope

These are finite arena, combat, lifecycle, rendering and replay checks. They do
not establish ambient route traversal, continuous four-boss campaign balance,
device performance or a human playtest. The existing route-wide matrix was not
rerun because no shared navigation capability or level geometry was changed by
this task. No deployment, live replay settlement or signed-in gameplay smoke
test was performed.
