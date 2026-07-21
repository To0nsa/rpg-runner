# Slopes Phase 1 - Pure Geometry Kernel And Static Edge Index Checklist

- Created: July 19, 2026
- Status: Accepted; implementation and evidence complete
- Source plan: [plan.md](plan.md)
- Frozen technical contracts:
  [phase0-technical-contracts.md](phase0-technical-contracts.md)
- Golden/performance specification:
  [phase0-golden-performance-spec.md](phase0-golden-performance-spec.md)
- Phase 0 acceptance:
  [phase0-implementation-checklist.md](phase0-implementation-checklist.md)

## 1) Goal And Boundary

Implement and prove the pure deterministic terrain geometry layer required by
later capsule-controller and navigation phases.

Phase 1 owns:

- fixed-grid polygon, edge, identity, and geometry-bundle types
- validation-independent runtime safety checks
- deterministic canonicalization and exposed-edge compilation helpers
- internal-edge removal, adjacency, and seam stitching
- pure capsule/segment geometry and continuous sweep primitives
- deterministic terrain-edge spatial index and reusable query buffers
- canonical signatures, golden geometry tests, allocation tests, and
  microbenchmarks

Phase 1 does not:

- make polygon terrain the production `GameCore` collision authority
- replace `StaticSolid`, `StaticGroundSegment`, or current snapshots
- add actor capsule stores or integrate player/enemy motion
- alter `GameCore.stepOneTick()` ordering
- change navigation, streaming, spawning, rendering, editor schema, generated
  content, replay versions, or production compatibility issuance
- introduce a temporary runtime flag that selects between rectangle and polygon
  physics

New geometry code may be imported only by pure tests and benchmark tools during
this phase. Any production import blocks acceptance.

## 2) Required File Layout

Use one Core-owned domain under:

```text
packages/runner_core/lib/collision/terrain/
```

Expected responsibilities:

| File/type area | Responsibility |
| --- | --- |
| `terrain_numeric.dart` | quantization, epsilon constants, ordered integer comparisons |
| `terrain_polygon.dart` | immutable canonical polygon and source metadata |
| `terrain_edge_id.dart` | stable identity lineage and total ordering |
| `terrain_edge.dart` | immutable endpoints, tangent/normal, mode, adjacency, bounds |
| `terrain_geometry.dart` | ordered polygons, exposed edges, source maps, version/signature input |
| `terrain_compiler.dart` | canonicalization, deterministic splitting, internal removal, adjacency/seams |
| `terrain_edge_index.dart` | deterministic grid insertion/query and stable candidate order |
| `terrain_query_buffer.dart` | caller-owned dedup/contact scratch storage |
| `upright_capsule.dart` | center, radius, vertical half-segment, derived AABB |
| `capsule_segment_kernel.dart` | closest points, signed separation, contact normal, continuous sweep |

Names may be adjusted only to match a clearly stronger existing Core naming
pattern. Responsibility boundaries and one-domain ownership may not change.

Test and benchmark locations:

```text
packages/runner_core/test/collision/terrain/
packages/runner_core/test/fixtures/slopes_golden_fixture.dart
packages/runner_core/tool/benchmark_slopes.dart
```

Do not add Flutter or Flame dependencies.

## 3) Entry Gate And Baseline

- [x] Re-read repository and Core `AGENTS.md` files.
- [x] Confirm Phase 0 is marked accepted and its decision ledger has no open
      row.
- [x] Confirm the golden/performance spec is unchanged or explicitly
      re-accepted.
- [x] Record starting revision and unrelated dirty-worktree entries.
- [x] Run:
  - [x] `dart analyze packages/runner_core`
  - [x] `dart test packages/runner_core/test`
  - [x] root focused determinism and fixed-point tests
  - [x] current fixed-point benchmark, track and no-track variants
- [x] Record baseline results without changing expected behavior.

Gate:

- [x] No failure is incorrectly attributed to Phase 1.
- [x] No production geometry authority change is present in the starting diff.

## 4) Numeric And Coordinate Foundation

Implement the frozen numeric contract before geometry algorithms.

- [x] Represent source identity coordinates as integer half-pixel ticks.
- [x] Represent compiled geometry coordinates as integer 1/1024-world-unit
      ticks or an equivalently exact centralized type.
- [x] Centralize:
  - [x] geometry equality epsilon: 1/1024 world unit
  - [x] contact/tie epsilon: 2/1024 world unit
  - [x] collision skin: 1/16 world unit
  - [x] source-to-physics transform quantization
- [x] Provide checked conversion at source, transformed, and public diagnostic
      boundaries.
- [x] Reject non-finite values, overflow, negative dimensions, and coordinates
      outside the supported integer range.
- [x] Use squared-distance comparisons until distance or normalization is
      required.
- [x] Keep trigonometry out of runtime hot-path classification.
- [x] Document units and overflow bounds on public numeric APIs.

Tests:

- [x] positive/negative half-pixel round trip
- [x] exact 1/1024 quantization ties
- [x] mirrored/scaled/transformed coordinate order
- [x] overflow and non-finite rejection
- [x] deterministic equality/tie comparison
- [x] `(56,-97)` normal quantizes to the inclusive 60-degree threshold
- [x] `(55,-97)` classifies above that threshold

Gate:

- [x] All later geometry code consumes the centralized numeric API.
- [x] No algorithm owns a private epsilon or ad-hoc rounding rule.

## 5) Immutable Geometry And Identity Types

- [x] Implement collision mode independently from semantic/material metadata.
- [x] Implement immutable polygon vertices and canonical source identity.
- [x] Implement `TerrainEdgeId` lineage:
  - [x] base/chunk index and chunk key
  - [x] placed-prefab deterministic identity when present
  - [x] shape ID
  - [x] canonical local edge index
- [x] Give edge IDs one explicit total order and value equality.
- [x] Implement immutable edge fields:
  - [x] quantized endpoints
  - [x] deterministically derived/quantized tangent and outward normal
  - [x] collision mode and walkability metadata
  - [x] previous/next exposed edge IDs
  - [x] source lineage
  - [x] tight AABB
- [x] Implement immutable geometry bundle with monotonically supplied geometry
      version and canonical edge order.
- [x] Keep diagnostic/source maps out of hot query iteration.
- [x] Document that default object `hashCode` is never a deterministic
      signature.

Tests:

- [x] ID equality/order across negative, base, and positive chunk indices
- [x] placed versus direct-source identity ordering
- [x] stable polygon/edge value equality
- [x] clockwise Y-down outward normals
- [x] derived bounds for horizontal, vertical, and sloped edges
- [x] immutable collection behavior

Gate:

- [x] Identity/order can be used by compiler, index, contact ties, signatures,
      streaming, and navigation without translation.

## 6) Runtime Safety Validation And Canonicalization

The editor later owns author-facing diagnostics. Phase 1 still rejects unsafe
runtime/test inputs.

- [x] Reject fewer than 3 distinct vertices and zero area.
- [x] Reject repeated closing vertices and consecutive duplicates.
- [x] Detect self-intersection deterministically.
- [x] Detect area overlap while allowing exact compatible shared boundaries.
- [x] Enforce minimum edge length and polygon area.
- [x] Enforce shape, vertex, and edge hard limits.
- [x] Normalize winding to clockwise in Y-down coordinates.
- [x] Rotate first vertex to the lexicographically canonical cyclic sequence.
- [x] Remove collinear middle vertices only through explicit normalization.
- [x] Sort diagnostics by source path, shape ID, element index, then code.
- [x] Preserve valid concavity; do not convex-decompose collision polygons.
- [x] Keep holes unsupported and blocking.

Tests:

- [x] convex and concave canonical loops
- [x] every cyclic rotation and reversed winding produces one canonical result
- [x] duplicate, collinear, zero-length, zero-area, and self-crossing cases
- [x] exact shared edge accepted
- [x] area overlap rejected
- [x] disconnected polygons accepted as separate shapes
- [x] hard-limit boundary and one-over-limit failures
- [x] diagnostic order remains stable across input map/list construction order

Gate:

- [x] Invalid input cannot reach edge compilation.
- [x] Canonical output is byte-stable across fresh processes.

## 7) Exposed Edge Compilation

- [x] Emit local edges in canonical polygon/edge order.
- [x] Split partially overlapping collinear edges deterministically.
- [x] Remove exact reversed internal solid edges.
- [x] Do not remove one-way edges merely because a solid overlaps them.
- [x] Preserve source lineage through split edges with deterministic sub-edge
      identity.
- [x] Build previous/next exposed adjacency.
- [x] Classify smooth connected vertices versus exposed endpoints for later
      ghost-vertex contact handling.
- [x] Stitch matching chunk-boundary endpoints only after ordered active
      geometry flattening.
- [x] Require quantized endpoint and compatible semantic/mode match for a
      continuous seam.
- [x] Treat unmatched, missing-neighbor, or incompatible endpoints as exposed
      ledges.
- [x] Keep intentional missing polygon coverage as a pit.
- [x] Produce polygon and edge records in one compiler result; never derive
      collision edges from render triangles.

Golden tests:

- [x] compile all `slopes_golden_v1` chunks
- [x] verify chunk-0/chunk-1 and chunk-2/chunk-3 seam identities
- [x] verify pit edges remain exposed
- [x] verify one-way slope keeps its authored top side
- [x] verify ceiling/underside normals
- [x] verify narrow peak endpoint adjacency
- [x] verify overlapping surface candidate IDs/order
- [x] freeze `source-v1` and `edges-v1` signatures

Gate:

- [x] Compiler output is independent of input object allocation/map order.
- [x] No internal edge survives and no exposed gameplay edge is removed.

## 8) Upright Capsule And Segment Kernel

This step implements pure geometry only, not body integration.

- [x] Implement upright capsule center, facing-aware offset, radius, vertical
      half-segment, and derived AABB.
- [x] Support zero half-segment as a circle.
- [x] Implement allocation-free:
  - [x] closest point on finite segment
  - [x] closest points between capsule spine and terrain segment
  - [x] squared distance and separation
  - [x] endpoint radial normal
  - [x] face normal contact
  - [x] overlap/penetration diagnostic
  - [x] conservative-advance moving capsule versus segment
  - [x] fixed 8-iteration advance and 8-step bisection refinement
- [x] Return explicit hit/no-hit, time of impact, point, normal, feature kind,
      and edge ID without heap allocation in the hot path.
- [x] Define equal-time comparison through the shared tie epsilon and edge-ID
      order.
- [x] Bound invalid-start recovery primitives to inputs needed by the Phase 2
      controller; do not implement controller policy here.
- [x] Keep one-way side/crossing policy outside the raw distance primitive and
      expose the inputs needed by the later filter.

Tests:

- [x] horizontal, vertical, and sloped face contacts
- [x] both segment endpoints
- [x] capsule side and both caps
- [x] circle degeneration
- [x] parallel and near-parallel motion
- [x] grazing/tangent contact
- [x] zero displacement
- [x] starting overlap diagnostic
- [x] maximum representative velocity without tunneling
- [x] mirrored coordinates/facing offsets
- [x] simultaneous equal-time edges select canonical ID
- [x] `capsule contact-order` golden signature

Gate:

- [x] Pure kernel results contain no gameplay grounding/walkability decision.
- [x] Continuous sweep is the normal high-speed path; discrete overlap is not
      used as successful collision resolution.

## 9) Deterministic Static Edge Index

- [x] Reuse the existing 2D grid primitive only where it preserves the frozen
      closed-boundary and order contract; otherwise wrap shared cell math
      without retaining AABB-face categories.
- [x] Use the frozen 64-world-unit default cell size.
- [x] Insert an edge into every closed cell touched by its tight AABB.
- [x] Insert exact-boundary edges into both adjacent cells.
- [x] Preserve canonical edge order inside buckets.
- [x] Query the swept-shape AABB expanded by skin/contact tolerance.
- [x] Deduplicate with caller-owned stamps or an equivalent allocation-free
      mechanism.
- [x] Sort deduplicated candidates by canonical edge ID before narrow phase.
- [x] Rebuild only from an immutable ordered edge list.
- [x] Expose counters for inserted references, cells visited, raw candidates,
      unique candidates, and overflow/limit diagnostics.
- [x] Never truncate candidates to meet a budget.

Tests:

- [x] horizontal, vertical, diagonal, zero-width-bound, and multi-cell edges
- [x] negative world coordinates
- [x] exact cell-boundary insertion/query
- [x] expanded swept-AABB inclusivity
- [x] duplicate removal across cells
- [x] candidate order independent of query traversal
- [x] rebuild after reordered but canonically equivalent input
- [x] 1280-edge representative and 5120-edge hard fixtures

Gate:

- [x] Every brute-force query result equals the indexed result.
- [x] Candidate output is duplicate-free and canonically ordered.

## 10) Signatures And Determinism

- [x] Implement canonical UTF-8 record writers for `source-v1` and `edges-v1`.
- [x] Serialize quantized integers and stable enum/string IDs only.
- [x] Hash with SHA-256 through an existing dependency or a narrowly justified
      pure-Dart implementation/dependency addition.
- [x] Add repeated fresh-instance and fresh-process comparison harnesses.
- [x] Verify streaming flatten/stitch order signatures without connecting the
      bundle to production `TrackManager`.
- [x] Store reviewed golden digest files next to the fixture tests.
- [x] Require an explicit update flag/command; normal tests never rewrite
      goldens.
- [x] Record the compatibility review trigger for any digest change.

Gate:

- [x] Geometry and contact-order signatures match across repeated local runs.
- [x] No unordered collection or default hash influences a signature.

## 11) Allocation And Performance Harness

- [x] Implement `packages/runner_core/tool/benchmark_slopes.dart`.
- [x] Support:
  - [x] representative 1280-edge fixture
  - [x] hard-stream 5120-edge fixture
  - [x] matched flat-polygon fixture
  - [x] warmup/runs/iterations flags
  - [x] JSON output with environment and revision
- [x] Measure compiler, index rebuild, candidate query, and raw capsule/segment
      sweep separately.
- [x] Add a steady-state allocation assertion for query and kernel calls.
- [x] Report p50/p95/p99/max and candidate counters.
- [x] Keep benchmark instrumentation out of normal hot paths unless behind the
      existing debug/test gate.

Phase 1 gates:

- [x] representative index rebuild p99 <=15 ms
- [x] hard 5120-edge index rebuild p99 <=50 ms
- [x] query candidate p95 <=24 and p99 <=64
- [x] zero steady-state allocation per terrain query
- [x] matched slope query/index overhead <=25% versus flat
- [x] no capacity case truncates or reorders output

Actor solve, whole-Core tick, navigation graph, validator, and editor budgets
belong to their later owning phases and are not Phase 1 exit gates.

## 12) Documentation And Review

- [x] Add high-signal public API docs with units, invariants, ordering, and
      allocation behavior.
- [x] Document reasoning hotspots only:
  - [x] winding/outward-normal convention
  - [x] canonical ID/tie order
  - [x] collinear split/internal removal
  - [x] exact cell-boundary insertion
  - [x] conservative-advance bounds
- [x] Do not update TDD/GDD as though the new geometry were production
      authority.
- [x] Update this checklist and `docs/building/slopes/plan.md` with measured
      evidence.
- [x] If public Core exports change, update the package export surface and API
      docs deliberately.
- [x] Record any implementation finding that would affect a later phase; do
      not silently broaden Phase 1.

## 13) Validation

Required:

- [x] `dart format --output=none --set-exit-if-changed` on changed Dart files
- [x] `dart analyze packages/runner_core`
- [x] `dart test packages/runner_core/test`
- [x] all new terrain geometry tests
- [x] root determinism and fixed-point tests
- [x] both fixed-point benchmark variants
- [x] both new slope benchmark fixtures
- [x] `git diff --check`
- [x] local Markdown link integrity

Also run the smallest root tests for any existing utility/export file touched.

Record command, revision, environment, result, and artifact path. A timeout or
unknown result is not a pass.

## 14) Removal And Non-Authority Proof

- [x] `rg` proves no production `GameCore`, `TrackManager`, collision system,
      navigation system, spawn system, snapshot builder, or renderer imports
      the Phase 1 terrain domain.
- [x] No feature flag or alternate runtime authority was added.
- [x] No legacy rectangle/flat-ground type or test was removed.
- [x] No generated source asset was migrated.
- [x] Temporary benchmark artifacts are outside tracked source.
- [x] Any abandoned prototype file/API is removed before acceptance.

The Phase 1 terrain types themselves are retained for Phase 2. Legacy removal
is intentionally deferred to the direct cutover phase after all consumers have
migrated.

## 15) Phase 1 Exit Gate

- [x] Numeric policy has one implementation and complete boundary tests.
- [x] Polygon/edge identity and canonicalization are deterministic.
- [x] Internal removal, adjacency, ledges, pits, and seams match the golden.
- [x] Capsule/segment closest-distance and sweep primitives pass exhaustive
      edge cases.
- [x] Static edge index matches brute force and preserves canonical order.
- [x] Geometry/contact signatures match across fresh runs.
- [x] Allocation and performance gates pass.
- [x] Public APIs are documented and Core remains Flutter/Flame-free.
- [x] Production runtime authority remains exclusively on the legacy path.
- [x] No Phase 0 decision was reopened or guessed.
- [x] Validation ledger has no unexplained failure.
- [x] Phase 2 findings are recorded, but no Phase 2 detailed checklist is
      created until Phase 1 evidence is accepted.

Only after every exit item is checked may Phase 2 capsule-controller and player
integration planning begin.

## 16) Implementation Findings

| Finding | Resolution | Later-phase impact |
| --- | --- | --- |
| This checklist originally repeated a 128-world-unit index cell, while the accepted Phase 0 technical contract freezes 64 world units. | Corrected the checklist and implemented `terrainDefaultCellSizeWorld = 64`; the accepted Phase 0 contract remains authoritative. | Phase 2+ consumers must use the terrain-index default or document a measured override. |
| Slash-delimited edge IDs were not injective when authored keys themselves contained `/`. | Canonical edge keys now length-prefix every authored string and distinguish a missing placement from every present value. A regression test covers the former collision. | Any later persisted signature uses the reviewed Phase 1 encoding; no production compatibility value has been issued. |
| Exact endpoint tangency enters contact slightly before mathematical TOI because contact is inclusive at the frozen 2/1024-world-unit epsilon. | Conservative advancement uses projected closing speed and the test asserts the accepted tolerance interval and final separation. | The Phase 2 solver must preserve the same contact boundary when ranking hits. |
| Public numeric, identity, geometry-bundle, and capsule construction initially relied too heavily on compiler context or debug assertions. | Public boundaries now perform release-mode finite/range/dimension/key/order checks; the geometry bundle canonicalizes input order and rejects duplicate edge IDs. | Production integration can consume these types without relying on editor validation. |
| A VM heap-allocation profiler is not part of this package-local harness. | Query/kernel APIs use caller-owned outputs, source inspection contains no query-time collection construction, 10,000-query tests prove no owned storage replacement, and both benchmark fixtures report zero steady-state buffer growth. | Phase 2 whole-controller profiling should add VM/profile-build heap evidence around the complete per-body solve before production cutover. |

Reviewed Phase 1 digests:

- `source-v1`: `88be670c79f41e1d984acd86f2d9529b8639d2c91e60ca3c863f21d9e3e3b2db`
- `edges-v1`: `84db4f4588286f76b2d7c504d8e71bd07be58ef9a79d2a1566f18353d84ce472`
- `contacts-v1`: `cb708e7cc2be7fb394016515393eb3461b3171a9028bfbe9b98cceb88bebf6b1`

The edge/contact digest change during review was deliberate: it records the
injective edge-key encoding and projected-closing-speed sweep. Source geometry
did not change.

## 17) Validation And Performance Ledger

| Date/revision | Command/evidence | Environment | Result |
| --- | --- | --- | --- |
| 2026-07-19 / `804c680` | Starting `dart analyze packages/runner_core`; package-local pre-Phase-1 tests | Windows local checkout; unrelated dirty scheduling work retained | Analyze passed; existing package suite passed. The root determinism test initially exposed the unrelated in-progress command-scheduling change and was not attributed to slopes. |
| 2026-07-19 / `8fd98a2` + scoped dirty Phase 1 review | `cd packages/runner_core && dart analyze` | Windows; Dart 3.11.5 | Pass, no issues. The package-local inherited `flutter_lints` include emits a known resolution warning during tests but no analyzer issue. |
| 2026-07-19 / `8fd98a2` + scoped dirty Phase 1 review | `cd packages/runner_core && dart test test/collision/terrain` | Windows local checkout | Pass, 42 terrain tests, including fresh-process signatures and hard-limit boundaries. |
| 2026-07-19 / `8fd98a2` + scoped dirty Phase 1 review | `cd packages/runner_core && dart test test` | Windows local checkout | Pass, 47 package tests. |
| 2026-07-19 / `8fd98a2` + scoped dirty Phase 1 review | `flutter test test/core/determinism_test.dart test/core/fixed_point_pilot_test.dart` | Windows local checkout | Pass, 5 tests; confirms the unrelated baseline scheduling work is resolved at final validation. |
| 2026-07-19 / `8fd98a2` + scoped dirty Phase 1 review | Fixed-point benchmark, no track and track/autoscroll variants, 3 runs x 3000 ticks | Windows local checkout | Pass. Fixed-point p99: 47 us without track, 132 us with track; zero resets. |
| 2026-07-19 / `8fd98a2` + scoped dirty Phase 1 review | `benchmark_slopes.dart --fixture=representative --runs=8 --ticks=8000 --rebuilds=100 --strict` | Windows local checkout | Pass. 1280 edges; rebuild p99 2860 us; candidates p95/p99 3/3; owned-storage allocations 0; matched-flat overhead 0.63%. Artifact: `../../.tmp/slopes-phase1-representative.json` from the package directory. |
| 2026-07-19 / `8fd98a2` + scoped dirty Phase 1 review | `benchmark_slopes.dart --fixture=hard-stream --runs=8 --ticks=8000 --rebuilds=1000 --strict` | Windows local checkout | Pass. 5120 edges; rebuild p99 4097 us; candidates p95/p99 3/3; owned-storage allocations 0; matched-flat overhead 8.98%. Artifact: `../../.tmp/slopes-phase1-hard.json` from the package directory. |
| 2026-07-19 / `8fd98a2` + scoped dirty Phase 1 review | Changed-file format check, `git diff --check`, slopes Markdown-link scan, production-import scan, and Flutter/Flame-import scan | Windows local checkout | Pass. No formatting/diff/link error; no production consumer or UI framework imports the Phase 1 terrain domain. |

Final formatting, diff, link, and non-authority checks are part of the checked
validation/removal gates above. Benchmark artifacts remain ignored temporary
files; no production import, feature flag, generated content, replay version,
or runtime authority changed.
