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

### Dames de la forêt victory blessing, October 7

After a verified boss death-strip completion, a surviving player receives one
instant restore of 60% of current maximum health, mana and stamina, rounded down
in fixed-point units and capped at each maximum. The reusable reward system
deduplicates streamed arena occurrences, preserves the shrine's regeneration
modifier and cannot revive a player killed on the reward tick. Arena release
and ordinary controls continue while the Holy effect follows the player's feet.

The supplied 768-by-48 Holy VFX 02 strip is copied unchanged to the runtime
blessing registry: sixteen 48-by-48 frames at 0.05 seconds, bottom-center anchor,
2x scale. Source and runtime SHA-256 both equal
`e6642c00f42ae4889fffc39b18ec4260decc2cbccfdb1617f15c1b3eb1d3fb8a`.
The Core-timed HUD names “Bénédiction des Dames de la forêt”.
The effect and message use 32/48/80 ticks at 30/60/90 Hz; pause freezes both.
Captured editor Play includes the image through the shared registry asset list.

Local follow-up checks:

- Complete Core suite: **973 passed**.
- Complete app Core integration suite: **495 passed**; affected Flame and HUD
  checks: **24 passed**, including the final four render tests rerun after
  correcting the test's component-mount wait.
- Worker boss replay suites: **12 passed**. Six new Forest victory cases cover
  both characters at 30/60/90 Hz and match all three restored resource pools,
  notice start/duration, player position and run distance.
- Analysis of Core, Game, the boss HUD and affected app/worker tests: **no issues**.
- Generated sources remain fresh: **82 chunks, 3 levels, 3 parallax themes and
  3 terrain materials**. The new asset directory is in the generated manifest.
- Compiled worker strict gate: **36,000 ticks per level**, equal replay outcomes,
  Forest **1.743 s**, Field **1.572 s**, new-level **1.572 s**. Forest's benchmark
  still stalls around 332 units with geometry version 1; real boss combat is
  covered by the focused integration and replay cases.

The frame review samples Holy frames 0, 3, 6, 9, 12 and 15 over the actual player
at runtime scale. It confirms the feet anchor, full beam, particles and empty
last frame. Live effect tests cover movement without clock restart, Core-clock
pause and removal at completion; ghost tests cover attachment interpolation and
single event consumption. No manual device playtest or deployment was performed.

![Holy blessing frame review](assets/boss_blessing_review.png)

### Grounded combat and shared knockback, October 7

Bringer's catalog disables intentional jumps and swim strokes in both graph
planning and locomotion. Both attacks now author the reusable accepted-damage
shove: 112 world units over 0.28 seconds, quantized to 9/17/26 ticks at
30/60/90 Hz. The actual platform is 96 units wide. No boss identity is used by
the damage, knockback state or motion systems. Shared payloads also carry the
effect for other melee, projectile, target-point and mobility damage.

The actual Forest platform tests cover both characters, X positions 175, 215
and 255, and all three tick rates: **18 expulsion cases pass** while Bringer
stays grounded. Opposing input cannot cancel the push. Separate scythe hits
push both characters, ordinary enemies retain their jumps, and collision tests
stop shoves at real walls and full-capsule arena bounds. Accepted partial guard,
full block, resistance, invulnerability, lifecycle recycling, body caps and
mobility/gravity cleanup have focused regressions.

Final local checks:

- Full Core suite: **960 passed**. Final shared shove suite: **9 passed** after
  adding the mobility-cleanup regression; production code was unchanged.
- Complete app Core integration suite: **495 passed**.
- Complete validator suite: **192 passed**. Final boss replay suite: **6 passed**,
  including three added damaging-pillar/push cases and three real combat clears.
- Core and changed replay-test analysis: **no issues**.
- Generated sources are fresh: **82 chunks, 3 levels, 3 parallax themes and
  3 terrain materials**. The focused traversal/harness matrix also passed
  **68 tests** before the full Core run: Forest's finite assembly and 32-chunk
  Field/new-level prefixes for seeds 7/42/2026 and the four ordinary enemies.
  Bringer remains excluded from route pursuit and is tested inside its arena.
- The worker executable compiled and its strict **36,000 ticks per level**
  local gate passed: Forest **2.491 s**, Field **2.749 s**, new-level **1.541 s**.
  Identical replay outcomes were confirmed. Forest's benchmark bot still stalls
  around 332 units at geometry version 1; it does not measure the boss encounter.

The reviewed graph golden now includes the explicit `canJump` profile flag and
removes Bringer's jump edges: `f10b00eb4f424af10cd022e7abbc28bab919cb89a5a95d19cc2faf2a11533193`.
The dependent run digest is
`bcdcd09080dde8513aa752daa0205ef82da72fba5a321dde54e131d01b5f6590`.
Surface geometry's digest is unchanged. Ordinary movement controls and traversal
retain their catalog limits; no failing route was skipped or teleported.

These results are local Windows evidence. The prepared compatibility remains
`2026.10.8`/`score-v4`; no merge, deployment, live replay submission, container
verification or manual device feel review was performed for this follow-up.

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
