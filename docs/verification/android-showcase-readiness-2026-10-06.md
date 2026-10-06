# Android showcase gameplay verification

Verified locally October 6, 2026. Baseline: `4c7eb46a`.
Follow-up fixes: `bdded54f` and `add5757c`.
The owner deferred release until level authoring was finished. This local review
performed no production deployment, native installation, run cancellation or
account reset. The finalized coordinated release subsequently deployed October 7;
see [production evidence](game-compat-2026.10.7-production.md).

## Fixed behavior

- `4c7eb46a`: lifecycle resume intent survives the full background/return
  sequence. Manual pauses and pre-start readiness remain paused.
- `bdded54f`: GameController dispatches transient Core events to its subscribers
  without retaining an unused second copy of the entire run's event history.
  The terminal RunEndedEvent remains available to the game-over UI.
- `add5757c`: cancellation drops unapplied movement, aim, hold starts, and action
  presses. Explicit hold releases survive, including the old slot during an
  unapplied switch. A tap or aimed release queued immediately before pause
  cannot fire after resume. Input and aim scheduling reset for a fresh press.

The two queued-action regressions first failed with pressed masks 63 (all tap
actions) and 8 (projectile release), then passed with cancellation. Widget tests
also exercise a jump queued immediately before the full Android lifecycle
sequence, frozen background ticks, cleared movement, and preserved manual pause.
These bridge changes do not alter Core rules or replay wire formats.

## Checks

| Check | Evidence |
| --- | --- |
| Baseline analysis of `lib`, `test`, and Core | No issues |
| Baseline full client suite | 1,067 passed |
| Full Core suite, including traversal | 880 passed |
| Final affected Game, controller, input-router, touch/desktop controls, run-widget, ghost, and playtest-host targets | 213 passed |
| Final targeted analysis | No issues |
| Worker ballistic-projectile and replay-simulation targets | 9 passed |
| Mixed-input live/replay matrix, included in the final targets | 18 passed |
| Android ARM64 profile APK | Native build succeeded |

The baseline suites preceded the follow-up bridge fixes. Unchanged Core and
unaffected client checks were reused; the 213 final targets cover the modified
bridge and its consumers. Counts overlap and must not be added into one total.
Expected missing-asset/storage logs come from passing failure-recovery fixtures.
Functions and editor source were not changed or independently tested here.

Raw local logs are under `.tmp/showcase-readiness/`. The profile artifact is
`build/app/outputs/flutter-apk/app-profile.apk` (120.5 MB), SHA-256
`cc69e373088c0bb7bb7a1cc719a910b12c3cc044577306d58c7b299612f4f776`.
It is a compilation check, not the final showcase package or evidence of
device startup, authentication, or frame rate.

## Gameplay horizons

The mixed-input matrix uses normal generated levels, both registered characters,
and seeds 7, 42, and 2026. It exercises all action categories through the semantic
dispatcher, buffered movement/aim, pause cancellation, varied frame deltas and
250-ms hitches. Every recorded frame replays through the shared command codec;
checkpoints compare camera, resources, terrain versions, actors, projectiles,
traps, and animation state. Terminal stats and event order also agree.
Finite coordinates and unique entity identities are checked during live play.

| Level | Autonomous attempt horizon per character |
| --- | --- |
| Forest, seed 7 | 355 ticks; 1,134.996 world units; gap death |
| Forest, seed 42 | 1,521 ticks; 4,801.943 world units; gap death |
| Forest, seed 2026 | 461 ticks; 1,045.939 world units; behind-camera death |
| Field, all three seeds | 7,201 ticks each, approximately two simulated minutes; 25,209–25,914 world units; manual completion |
| `new_level`, all three seeds | 7,201 ticks each; 25,209–25,914 world units; manual completion |

The cap can overshoot by the last frame's tick batch. Actors, damage, movement,
camera, resources and authored geometry were not overridden. The simple input
policy's normal Forest deaths do not establish a content defect or full Forest
player traversal. It does not reach Forest's hard section.

The separate seeded pursuit matrix continuously crosses the real route boundary
with Grojib, Hashash, and Unoco at those same three seeds:

| Level | Chunks / required exit in world units |
| --- | --- |
| Forest, seed 7 | 81 / 48,600 |
| Forest, seed 42 | 78 / 46,800 |
| Forest, seed 2026 | 80 / 48,000 |
| Field and `new_level`, each seed | 32 / 19,200 |

Forest stops before its final segment repeats. Endless routes use finite
32-chunk prefixes. Continuation terrain supports the final target without
extending those horizons. Derf is stationary and excluded from pursuit.
Pursuit isolates movement/navigation; it does not prove player, camera, combat,
spawn-marker, rescue, rendering, or mobile-performance behavior over that route.

## Remaining showcase gates

Authoring files changed throughout this local review and were deliberately left
alone. Finalized authoring was subsequently regenerated, terrain blockers were
repaired and all 85 traversal/control cases passed with failing routes retained
as regressions. Frozen `ffd6475f` was deployed under compatibility `2026.10.7`
to matching Functions, worker and Hosting; see the
[October 7 production evidence](game-compat-2026.10.7-production.md). That release
does not establish the device acceptance checks below.

No Android device was connected during this review. Following the coordinated
release, verify the actual showcase phone/tablet: cold signed-in startup, repeated starts
and restarts, multitouch combat/aim, hard-chunk and rescue playthroughs,
background/return, sustained frame rate/temperature, replay acceptance,
settlement, leaderboard updates, and ghost playback. Automated tests do not
establish that hardware or live-service evidence.
