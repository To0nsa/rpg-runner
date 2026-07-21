# Slopes Phase 0 - Golden Fixture And Performance Specification

- Date: July 19, 2026
- Status: Accepted Phase 0 specification; implementation begins in Phase 1
- Source plan: [plan.md](plan.md)
- Phase 0 checklist:
  [phase0-implementation-checklist.md](phase0-implementation-checklist.md)
- Frozen contracts:
  [phase0-technical-contracts.md](phase0-technical-contracts.md)
- Gameplay rules:
  [phase0-gameplay-decisions.md](phase0-gameplay-decisions.md)

This document freezes the fixtures, observable invariants, measurement
environments, and initial budgets. It does not claim that polygon terrain,
capsule collision, or the fixtures are implemented.

## 1) Reference Environments

### Local Core reference

- OS: Windows 11 `10.0.26200`, build `26200`
- CPU: AMD Ryzen 7 4800H with Radeon Graphics
- memory: 15.42 GiB
- power plan: ASUS Recommended
- Dart: 3.11.5 stable, `windows_x64`
- Flutter: 3.41.7 stable
- repository revision measured: `d942020`
- working tree: pre-existing dirty tree; slopes changes are documentation-only

Local timing runs must:

- run without another repository build/test process in parallel
- execute one warmup and at least 3 balanced measured runs
- report sample count, mean, p95, p99, and maximum
- use release/profile or compiled execution for acceptance numbers; JIT numbers
  may be recorded as development diagnostics

### Validator reference

The deployment-shaped validator environment is the checked-in Cloud Run policy:

- 1 vCPU
- 512 MiB memory
- 240-second request timeout
- concurrency 1

The validator gate is measured in the same compiled container image intended
for deployment. A local desktop result cannot replace the Cloud Run result.

### Editor reference

Editor interaction is measured in Flutter profile mode on the local Core
reference machine at 60 Hz. At least 600 drag frames follow a 120-frame warmup.
The benchmark uses a maximally populated soft-budget document and records
interaction-update p50/p95/p99 plus Flutter build/raster frame times.

## 2) Current Equivalent Baselines

These measurements characterize the current rectangle/flat implementation.
They are comparison evidence, not performance claims for the future edge
solver.

### Content capacity

The July 19 content audit found:

- 99 prefab definitions
- rectangle-collider distribution:
  - 29 prefabs with 0 colliders
  - 41 with 1
  - 16 with 2
  - 9 with 3
  - 4 with 4
- current maximum: 4 collider rectangles in one prefab
- 8 authored chunks
- current maximum per chunk: 33 rectangle-equivalent exposed edges, counting
  four faces per placed collider and one edge per flat ground segment
- five highest current chunks together: 138 rectangle-equivalent edges

Reproduce from PowerShell:

```powershell
$defs = Get-Content -Raw assets/authoring/level/prefab_defs.json |
  ConvertFrom-Json
$counts = @{}
foreach ($prefab in $defs.prefabs) {
  $counts[$prefab.id] = @($prefab.colliders).Count
}
foreach ($file in Get-ChildItem assets/authoring/level/chunks -Filter *.json -Recurse) {
  $chunk = Get-Content -Raw $file.FullName | ConvertFrom-Json
  $rectangles = 0
  foreach ($placed in @($chunk.prefabs)) {
    $rectangles += [int]$counts[$placed.prefabId]
  }
  $groundSegments = @($chunk.groundGaps).Count + 1
  [pscustomobject]@{
    chunk = $chunk.id
    rectangles = $rectangles
    equivalentEdges = 4 * $rectangles + $groundSegments
  }
}
```

### Whole-Core tick

The existing fixed-point benchmark was run at revision `d942020`:

```powershell
dart run test/integration_test/core-fixed-point/core_fixed_point_benchmark.dart `
  --runs=3 --warmup-ticks=250 --ticks=3000

dart run test/integration_test/core-fixed-point/core_fixed_point_benchmark.dart `
  --runs=3 --warmup-ticks=250 --ticks=3000 --track --autoscroll
```

| Scenario | Mode | Samples | Mean | p95 | p99 |
| --- | --- | ---: | ---: | ---: | ---: |
| No track/autoscroll | current baseline | 18,000 | 20.50 us | 50 us | 205 us |
| No track/autoscroll | fixed-point pilot | 18,000 | 9.13 us | 19 us | 83 us |
| Track + autoscroll | current baseline | 18,000 | 28.28 us | 61 us | 497 us |
| Track + autoscroll | fixed-point pilot | 18,000 | 16.07 us | 19 us | 249 us |

The slopes comparison uses fixed-point-pilot track/autoscroll as the closest
current equivalent because the frozen solver makes that quantization path
mandatory. Microbenchmarks below must also report a matched flat polygon
fixture so slope overhead can be compared without unrelated game changes.

### Metrics with no current equivalent

The current runtime has no polygon compiler, terrain-edge grid, capsule/segment
solver, sloped navigation graph, or polygon editor interaction. Their baseline
is explicitly `N/A - new authority`, not zero. Phase 1 must establish the first
measured value before the relevant gate can pass.

## 3) Golden Terrain Fixture

### Fixture identity and constants

- fixture ID: `slopes_golden_v1`
- seed: `0x0510A35`
- fixed tick: 60 Hz
- source units: exact half-world-pixel grid; this fixture uses integer points
- physics quantization: 1/1024 world unit
- chunk width: 512
- chunk height: 512
- ordinary floor Y: 320
- `killPlaneY`: 480
- enemy cull plane Y: 496
- chunks: 4, indices 0 through 3

Solid ground polygons use the listed top polyline from left to right, then
close through `(lastX, 512)` and `(firstX, 512)`. Each resulting loop is
canonicalized by the frozen polygon rules. Separate obstacles and one-way
platforms use their listed complete loops.

### Chunk 0 - ordinary transitions and seam

`terrain/chunk0/main` top polyline, chunk-local:

```text
(0,320)
(96,320)    flat
(160,288)   26.565-degree ascent to the right
(224,288)   upper flat
(288,320)   26.565-degree descent to the right
(320,320)
(352,336)   concave-valley bottom
(384,320)
(416,320)
(448,304)   convex-peak top
(480,320)
(512,320)   continuous boundary endpoint
```

Expected coverage:

- flat support
- allowed ascent/descent in both travel directions
- flat/slope transitions
- concave valley with no bounce
- convex peak with 4-pixel support preservation, then natural departure when
  snap cannot retain support
- exact continuous seam to chunk 1

### Chunk 1 - slope limits, pit, wall, underside, and one-way

`terrain/chunk1/limit_island` top polyline:

```text
(0,320)
(64,320)
(120,223)   delta (56,-97)
(176,223)
(224,271)   45-degree descent
(256,271)
```

The `(56,-97)` edge derives a quantized walkability component exactly equal to
the 60-degree runtime threshold. It is the inclusive-limit case even though
irrational 60-degree geometry cannot be represented exactly by integer source
coordinates.

There is an intentional pit over local X `[256,288)`.

`terrain/chunk1/over_limit_island` top polyline:

```text
(288,320)
(343,223)   delta (55,-97), above the player limit
(368,223)
(368,320)   vertical wall
(512,320)
```

Complete separate loops:

```text
terrain/chunk1/ceiling_solid:
  (400,128) (480,128) (480,192) (448,176) (416,192) (400,192)

terrain/chunk1/one_way_slope:
  (384,272) (448,240) (448,248) (384,280)

terrain/chunk1/narrow_peak:
  (464,320) (472,304) (480,320)
```

Expected coverage:

- runtime-normal equality is player-walkable at the inclusive 60-degree limit
- the `(55,-97)` edge is over limit and resolves as a wall
- the vertical face is a solid wall
- the hanging polygon supplies a sloped underside and ceiling contacts
- the one-way top passes actors from below and supports them from above
- its endpoints do not become side walls
- the narrow peak cannot satisfy the player's full 20.6-pixel spawn interval
- one-way and ground surfaces overlap vertically at the same X; highest valid
  lookup selects the one-way top and ties remain stable by edge ID

### Chunk 2 - navigation, jump/drop, and streamed graph rebuild

`terrain/chunk2/main_left` top polyline:

```text
(0,320)
(96,320)
(160,288)
(224,288)
(288,320)
(352,320)
```

There is an intentional gap over local X `[352,416)`.

`terrain/chunk2/landing_right` top polyline:

```text
(416,288)
(512,288)
```

Complete one-way loop:

```text
terrain/chunk2/one_way_bridge:
  (336,256) (448,224) (448,232) (336,264)
```

Expected coverage:

- Grojib and Hashash build different walkability views over shared surface IDs
- walk cost is surface length divided by authored enemy speed
- jump/drop samples use exact source/destination `yAt(x)`
- gap and one-way transitions validate full capsule clearance
- adding or removing chunk 3 increments one geometry/graph version and
  deterministically invalidates held paths

### Chunk 3 - placement and enemy-policy zone

`terrain/chunk3/main` top polyline:

```text
(0,288)     continuous boundary endpoint from chunk 2
(64,320)
(256,320)
(320,304)
(512,304)
```

Complete perch loops:

```text
terrain/chunk3/derf_valid:
  (96,256) (160,239) (160,272) (96,272)

terrain/chunk3/derf_narrow:
  (192,256) (223,248) (223,272) (192,272)

terrain/chunk3/unoco_blocker:
  (288,144) (416,144) (416,208) (352,192) (288,208)
```

Expected coverage:

- valid Derf support has 64 horizontal pixels and is below 15 degrees
- the 31-pixel Derf support is rejected as too narrow
- Grojib/Hashash marker correction stays on the intended support
- Unoco Demon references local terrain, is blocked by the solid obstacle from
  every side, and ignores the one-way bridge
- player, enemy, pickup, and restoration placement exercise their accepted
  slope, width, clearance, and skip/fail policies

## 4) Golden Scenario Matrix

Each case gets a stable test ID. Tests may start an actor at the named feature
rather than requiring one uninterrupted run through blocked zones.

### Player

| ID | Setup/commands | Required invariant |
| --- | --- | --- |
| `SG-P01` | Spawn on chunk-0 flat; no input for 180 ticks | Support ID remains valid; position does not drift; idle stays grounded |
| `SG-P02` | Hold right 240 ticks, left 240 ticks | Start/stop/reverse crosses ordinary slopes without snag or airborne flicker |
| `SG-P03` | Run at normal and maximum configured speed over chunk 0 | No tunneling; signed-slope X-speed curve matches accepted control points |
| `SG-P04` | Jump at flat, ascent, descent, and ledge; repeat with buffered/coyote/air jump | Jump is world-up; snap does not recapture takeoff; existing windows persist |
| `SG-P05` | Grounded dash/roll uphill and downhill | Tangent motion preserves authored surface distance and uses 4-pixel helpers |
| `SG-P06` | Apply knockback into floor, steep wall, and ceiling | Same capsule solver resolves each contact without penetration or extra launch |
| `SG-P07` | Land on 30/45/60-degree support at low, run, and maximum fall velocity | Earliest contact is stable; eligible support grounds exactly once |
| `SG-P08` | Leave chunk-1 pit edge | Natural airborne transition, coyote behavior, then `killPlaneY` run end |
| `SG-P09` | Move upward through and descend onto one-way slope | Pass below, land above, no endpoint wall |
| `SG-P10` | Query future ground target above stacked surfaces and behind blocker | Preview/commit agree; blocked/invalid target has no cost or cooldown |
| `SG-P11` | Repeat command fixture to run end | Tick, distance, score, resources, events, and end reason match signatures |
| `SG-P12` | Run `SG-P01`-`SG-P11` for Éloïse and Éloïse WIP | Shared capsule derivation and player-specific authored tuning remain valid |

### Enemies and navigation

| ID | Setup | Required invariant |
| --- | --- | --- |
| `SG-E01` | Grojib pursues over chunk 0/2, seam, jump, and drop | 45-degree maximum, 4-pixel helpers, time-based path costs |
| `SG-E02` | Hashash pursues and tests clear/blocked ambush destinations | 60-degree maximum; right, mirrored-left, cancel order; no new RNG |
| `SG-E03` | Unoco flies around chunk-3 blocker and one-way bridge | Local 60-180 band, bounded steering, solid blocking, one-way ignored |
| `SG-E04` | Spawn Derf on valid, narrow, steep, absent, and blocked supports | Only valid 32-pixel/15-degree perch spawns; cast target remains predicted player center |
| `SG-E05` | Target crosses chains and becomes airborne | Stable target lookup; no false surface ownership or hidden teleport |
| `SG-E06` | Stream/cull chunk 3 while paths are held | One atomic geometry/graph version change; deterministic invalidation/replan |
| `SG-E07` | Ground-impact death on flat and eligible slopes | Final support triggers impact consistently; timeout fallback remains deterministic |

## 5) Deterministic Signatures

All signatures use UTF-8 canonical field records and SHA-256. Numeric geometry
and simulation values are serialized as quantized integers, not formatted
floating-point text.

### Required signature records

- `source-v1`: document key, canonical shape ID/order, collision mode, semantic
  keys, and integer vertices
- `edges-v1`: geometry version, stable edge ID, quantized endpoints/tangent/
  normal, mode, adjacency, source lineage, and index-cell membership
- `contacts-v1`: tick, entity ID, quantized transform/velocity, grounded,
  support ID/point/normal/tangent, wall/ceiling flags, and contact edge order
- `graphs-v1`: enemy profile ID, geometry version, ordered surface nodes,
  directed transition type/cost, and stable destinations
- `paths-v1`: tick, enemy entity/profile, start/target surface, ordered path,
  transition state, and invalidation reason
- `run-v1`: compatibility/content/ruleset IDs, seed, player ID, ordered command
  stream, per-checkpoint contact/graph digests, final tick/transform/resources,
  score breakdown, distance, events, end reason, and RNG state

### Comparison gates

- two fresh Core instances match at every checkpoint and final digest
- repeated runs in one process match fresh-process runs
- stream/cull/rebuild schedules produce identical identity/order signatures
- client recorder and validator consume the same replay blob and match
  `run-v1`
- exact canonical data must match byte-for-byte; epsilon is used only for
  explicitly noncanonical diagnostic/render values
- a signature update requires a reviewed compatibility/content/ruleset change,
  never an automatic golden rewrite

## 6) Phase 1 Performance And Capacity Ledger

`Soft` is the normal authoring/representative target. `Hard` is a validation or
release gate; content never truncates to satisfy it.

| Metric | Current equivalent baseline | Phase 1 soft target | Hard gate |
| --- | --- | --- | --- |
| Shapes per prefab | Max 4 rectangles | <=16 polygons | <=64 |
| Vertices per polygon | Rectangle = 4 | <=24 | <=64 |
| Exposed edges per chunk | Max 33 rectangle-equivalent | <=1024 | <=4096 |
| Active streamed edges | Five current worst = 138 equivalent | 5 chunks / 1280-edge benchmark | <=5120 at normal stream window |
| Static edge-index rebuild | N/A - new authority | p99 <=15 ms at 1280 edges | p99 <=50 ms at 5120 edges |
| Player candidates per sweep | N/A - new authority | p95 <=24 | p99 <=64 |
| Enemy candidates per sweep | N/A - new authority | p95 <=24 | p99 <=64 |
| Dynamic actor solve | N/A - new authority | p95 <=75 us/body | p99 <=150 us/body |
| One enemy-profile graph build | N/A - sloped graph | p95 <=5 ms | p99 <=10 ms |
| Both grounded-enemy graphs | N/A - sloped graph | p95 <=20 ms | p99 <=35 ms |
| Combined index + graph rebuild | N/A - new authority | p95 <=35 ms | p99 <=50 ms |
| Terrain-query allocations | Current path not comparable | 0 steady-state/body/tick | Any steady-state allocation fails |
| Whole Core slope tick | Fixed-point track p99 249 us | p99 <=2 ms representative | p99 <4 ms and <=25% matched-flat overhead |
| Validator replay | No deployment-shaped slope fixture | >=4x real-time target | >=2x real time; 36,000 ticks <300 s |
| Editor polygon drag/update | No polygon editor | p95 <=8 ms | p99 <=16.67 ms, no missed-input burst |

Representative runtime load:

- 5 active 512-pixel chunks
- 256 exposed edges per chunk, 1280 total
- 1 player
- 8 Grojib
- 8 Hashash
- 4 Unoco Demon
- 4 Derf
- current projectile/pickup load from the fixed-point track benchmark
- one streamed chunk replacement and both grounded-enemy graph rebuilds

The 5120-edge hard stream case measures rebuild/query safety, not a normal
content recommendation.

## 7) Reproducible Measurement Commands

Phase 1 creates these test-only harnesses before implementing production
authority:

```powershell
Push-Location packages/runner_core
dart test test/collision/terrain/slopes_golden_geometry_test.dart
dart test test/collision/terrain/capsule_segment_golden_test.dart
dart run tool/benchmark_slopes.dart `
  --fixture=representative --runs=8 --ticks=8000 `
  --json-out=../../.tmp/slopes.json
dart run tool/benchmark_slopes.dart `
  --fixture=hard-stream --runs=8 --rebuilds=1000 `
  --json-out=../../.tmp/slopes-hard.json
Pop-Location

dart test packages/runner_core/test/navigation/sloped_graph_golden_test.dart
flutter test test/core/slopes_gameplay_golden_test.dart
flutter test test/game/replay/slopes_recorder_validator_parity_test.dart
```

Validator acceptance:

```powershell
docker build -f services/replay_validator/Dockerfile `
  -t replay-validator:slopes-benchmark .
docker run --rm --cpus=1 --memory=512m `
  replay-validator:slopes-benchmark benchmark `
  --fixture=slopes_golden_v1 --ticks=36000
```

The compiled validator may expose the benchmark through a separate test binary
instead of the production server command, but the container resource limits,
fixture, and output schema must remain identical.

Editor acceptance:

```powershell
cd tools/editor
flutter drive --profile `
  --driver=test_driver/integration_test.dart `
  --target=integration_test/polygon_interaction_benchmark_test.dart `
  -d windows
```

Every benchmark emits JSON containing revision, dirty flag, OS/runtime,
fixture/signature, warmup, sample count, p50/p95/p99/max, allocation count
where applicable, and pass/fail per budget.

## 8) Budget Failure Policy

- Source over a hard shape/vertex/edge limit fails editor validation and
  generation with a stable diagnostic.
- A representative performance miss blocks the phase that introduces the
  affected authority.
- A hard-stream miss blocks release even when representative content passes.
- Candidate overflow or solver iteration exhaustion records a deterministic
  diagnostic and fails the golden; it never drops candidates or contacts.
- Allocation failure requires buffer/index redesign, not a relaxed zero-allocation
  assertion.
- Validator throughput below 2x real time blocks compatibility issuance.
- Editor interaction over budget requires profiling and incremental
  recomputation; it does not lower geometry correctness.
- Budgets may change only with recorded measurements and explicit review in
  this document and the active implementation checklist.

## 9) Phase Ownership

- Phase 1 implements geometry, edge-index, signature, candidate, allocation,
  and microbenchmark harnesses.
- Phase 2 implements player scenarios and whole-Core slope tick comparison.
- Phase 3 implements enemy/navigation scenarios and graph timings.
- Phase 4 implements editor interaction and authoring-capacity gates.
- Phase 5 implements streamed rebuild and render-seam scenarios.
- Phase 6 freezes final reference digests after direct cutover readiness.
- Phase 7 records validator-container throughput and client/validator parity
  before compatible issuance.

No phase may invent a missing expected behavior; it must use the accepted
contracts and scenario invariants above.
