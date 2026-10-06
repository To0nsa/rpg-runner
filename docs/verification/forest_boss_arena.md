# Forest boss arena verification

Implementation commit: `1c350b0e6` on `feature/forest-boss-arena`, based on
`6519461c6`. The isolated worktree is
`C:/dev/rpg_runner/.tmp/forest-boss-arena`; existing main-worktree Forest edits
were preserved. Gameplay compatibility `2026.10.8` and score partition
`score-v4` are prepared in source. Nothing was deployed.

## Delivered behavior

Forest reserves one `forest_boss_easy_001` occurrence before the easy enchanted
forest section. Core frames the complete 600-by-270 chunk, holds the player,
plays the complete smoke entrance, enables bounded combat, and resumes running
after normal boss death cleanup. Bringer uses its imported source strip,
committed scythe and captured-position pillar attacks, a named health bar, and
purple boundary cues. Shared Build/Play placement, editor metadata Save/undo,
fixed defeat scoring, and worker replay follow the same Core contract.

See [technical contracts](../tdd/boss_arenas.md) and
[gameplay tuning](../gdd/bringer_of_death.md).

## Local validation

- Core `dart test test --concurrency=4`: **929 passed**, including the 18 boss
  tests and seeded traversal matrix.
- App-owned `flutter test --no-pub test/core`: **495 passed**.
- Shared content pipeline `dart test test`: **91 passed**.
- Validator boss replay and worker tests: **90 passed**, including real combat
  clears and equal outcomes/score at 30, 60 and 90 Hz.
- Editor boss authoring, file codec and marker catalog tests: **8 passed**.
- Flame terrain loading and ghost layer tests: **11 passed**.
- Boss source-frame review and existing enemy rendering: **3 passed**.
- Functions TypeScript build and test build passed; compatibility and board
  provisioning tests in the local Firestore emulator: **7 passed**.
- Core, pipeline, client, affected editor files and worker analysis: no issues.
- `dart run tool/generate_chunk_runtime_data.dart --dry-run`: **82 chunks,
  3 levels, 3 parallax themes and 3 terrain materials**, with no blocking issues.
- Generated asset manifest is synchronized and the repository commit hook passes.

The boss tests cover both playable characters, exact first-held framing, physical
hold through movement/jump/dash/action inputs, quantized entrance, both attacks,
ordinary combat clears, death release, required-actor loss, simultaneous death,
charge reset, protection ownership after entity recycling, and time/kill scoring.
The ordinary combat trace retains its reviewed hash. Terrain graph/run digests
were reviewed for the added Bringer graph; the surface digest is unchanged.

The content suite inherited a stale test that treated any Derf rescue placement
as invalid. This failure reproduced in the unchanged main-worktree baseline.
The test now places Derf at the boundary so it exercises actual full-body
rejection without changing production placement rules.

## Traversal horizons

The matrix covers Forest's complete finite authored assembly, excluding its
repeating final section, and the first 32 production-selected chunks of Field
and `new_level`. Seeds are **7, 42 and 2026**, with Unoco, Grojib, Hashash and
Derf: **36 pursuit cases**, plus harness controls and retained exact-route
regressions. These use actual movement limits and require crossing route exits.
Bringer's dry arena is covered by confinement/combat tests rather than open-route
pursuit or the ordinary pool-engagement harness. These checks do not prove every
legal seed, endless route, player traversal, device performance or balance.

## Compiled local performance evidence

The service executable compiled successfully and
`benchmark --ticks=36000 --strict` passed all existing local gates:

| Level | Measured replay time | Simulation / wall time |
| --- | ---: | ---: |
| Forest | 0.986 s | 608x |
| Field | 1.669 s | 360x |
| `new_level` | 1.658 s | 362x |

Each measurement executes 36,000 replay ticks at 60 Hz with equal recorded and
replayed outcomes. The benchmark's Forest bot stalls early at about 332 units
with geometry version 1, so its gate is limited evidence of Forest streaming
cost and does not measure the boss fight. Boss coverage comes from actual
combat/replay tests; route coverage comes from the traversal matrix. This local
Windows result does not establish the release container CPU/memory gate or live
worker readiness.

## Visual review and remaining release work

### Reusable entrance feedback follow-up

The later entrance-feedback change exposes Core's existing entrance timing and
adds shared presentation modules with no enemy ID, sprite or Bringer dependency.
Three black border pulses, moderate camera shakes and medium haptic cues share
that clock. The original red player-impact border uses the same painter. Pause
does not duplicate cues, and run disposal/restart removes the haptics listener.
The player hold and combat/replay outcomes are unchanged.

Final follow-up checks: **48 focused Flutter tests**, **18 Core boss tests** and
**3 actual-combat validator replay tests** passed. Analysis of affected client,
Core and test files has no issues. Tests cover a second arbitrary boss identity
with a different entrance duration, all three tick rates, separate shake pulses,
pause/resume, teardown, center transparency, red/black pixels, preserved player
impact fade, pointer passthrough, and run/Flame/controller integration.

The reviewed comparison below shows the shared red style on the left and black
entrance style on the right at peak intensity. Physical device haptics were not
manually tested; the platform adapter and dispatch counts were validated locally.

![Shared red and black screen border review](assets/boss_entrance_border_review.png)

### Initial sprite review

The image below reviews entrance, sweep, cast and death (top to bottom), sampling
frames 0, 3, 6 and the final clamped frame. The wrapped strips and reversed smoke
sequence loaded correctly and were visually inspected.

![Bringer animation frame review](assets/bringer_animation_review.png)

No manual device playtest, signed-in production smoke, exact-image container
benchmark or deployment was performed. Boss balance is an initial tuning pass;
device feel should be reviewed before release. Production requires the existing
coordinated compatibility/worker/Functions/client release workflow.
