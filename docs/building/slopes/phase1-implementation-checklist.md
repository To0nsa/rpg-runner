# Slopes Phase 1 - Pure Geometry Kernel And Static Edge Index Checklist

- Created: July 19, 2026
- Status: Ready; implementation not started
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

- [ ] Re-read repository and Core `AGENTS.md` files.
- [ ] Confirm Phase 0 is marked accepted and its decision ledger has no open
      row.
- [ ] Confirm the golden/performance spec is unchanged or explicitly
      re-accepted.
- [ ] Record starting revision and unrelated dirty-worktree entries.
- [ ] Run:
  - [ ] `dart analyze packages/runner_core`
  - [ ] `dart test packages/runner_core/test`
  - [ ] root focused determinism and fixed-point tests
  - [ ] current fixed-point benchmark, track and no-track variants
- [ ] Record baseline results without changing expected behavior.

Gate:

- [ ] No failure is incorrectly attributed to Phase 1.
- [ ] No production geometry authority change is present in the starting diff.

## 4) Numeric And Coordinate Foundation

Implement the frozen numeric contract before geometry algorithms.

- [ ] Represent source identity coordinates as integer half-pixel ticks.
- [ ] Represent compiled geometry coordinates as integer 1/1024-world-unit
      ticks or an equivalently exact centralized type.
- [ ] Centralize:
  - [ ] geometry equality epsilon: 1/1024 world unit
  - [ ] contact/tie epsilon: 2/1024 world unit
  - [ ] collision skin: 1/16 world unit
  - [ ] source-to-physics transform quantization
- [ ] Provide checked conversion at source, transformed, and public diagnostic
      boundaries.
- [ ] Reject non-finite values, overflow, negative dimensions, and coordinates
      outside the supported integer range.
- [ ] Use squared-distance comparisons until distance or normalization is
      required.
- [ ] Keep trigonometry out of runtime hot-path classification.
- [ ] Document units and overflow bounds on public numeric APIs.

Tests:

- [ ] positive/negative half-pixel round trip
- [ ] exact 1/1024 quantization ties
- [ ] mirrored/scaled/transformed coordinate order
- [ ] overflow and non-finite rejection
- [ ] deterministic equality/tie comparison
- [ ] `(56,-97)` normal quantizes to the inclusive 60-degree threshold
- [ ] `(55,-97)` classifies above that threshold

Gate:

- [ ] All later geometry code consumes the centralized numeric API.
- [ ] No algorithm owns a private epsilon or ad-hoc rounding rule.

## 5) Immutable Geometry And Identity Types

- [ ] Implement collision mode independently from semantic/material metadata.
- [ ] Implement immutable polygon vertices and canonical source identity.
- [ ] Implement `TerrainEdgeId` lineage:
  - [ ] base/chunk index and chunk key
  - [ ] placed-prefab deterministic identity when present
  - [ ] shape ID
  - [ ] canonical local edge index
- [ ] Give edge IDs one explicit total order and value equality.
- [ ] Implement immutable edge fields:
  - [ ] quantized endpoints
  - [ ] deterministically derived/quantized tangent and outward normal
  - [ ] collision mode and walkability metadata
  - [ ] previous/next exposed edge IDs
  - [ ] source lineage
  - [ ] tight AABB
- [ ] Implement immutable geometry bundle with monotonically supplied geometry
      version and canonical edge order.
- [ ] Keep diagnostic/source maps out of hot query iteration.
- [ ] Document that default object `hashCode` is never a deterministic
      signature.

Tests:

- [ ] ID equality/order across negative, base, and positive chunk indices
- [ ] placed versus direct-source identity ordering
- [ ] stable polygon/edge value equality
- [ ] clockwise Y-down outward normals
- [ ] derived bounds for horizontal, vertical, and sloped edges
- [ ] immutable collection behavior

Gate:

- [ ] Identity/order can be used by compiler, index, contact ties, signatures,
      streaming, and navigation without translation.

## 6) Runtime Safety Validation And Canonicalization

The editor later owns author-facing diagnostics. Phase 1 still rejects unsafe
runtime/test inputs.

- [ ] Reject fewer than 3 distinct vertices and zero area.
- [ ] Reject repeated closing vertices and consecutive duplicates.
- [ ] Detect self-intersection deterministically.
- [ ] Detect area overlap while allowing exact compatible shared boundaries.
- [ ] Enforce minimum edge length and polygon area.
- [ ] Enforce shape, vertex, and edge hard limits.
- [ ] Normalize winding to clockwise in Y-down coordinates.
- [ ] Rotate first vertex to the lexicographically canonical cyclic sequence.
- [ ] Remove collinear middle vertices only through explicit normalization.
- [ ] Sort diagnostics by source path, shape ID, element index, then code.
- [ ] Preserve valid concavity; do not convex-decompose collision polygons.
- [ ] Keep holes unsupported and blocking.

Tests:

- [ ] convex and concave canonical loops
- [ ] every cyclic rotation and reversed winding produces one canonical result
- [ ] duplicate, collinear, zero-length, zero-area, and self-crossing cases
- [ ] exact shared edge accepted
- [ ] area overlap rejected
- [ ] disconnected polygons accepted as separate shapes
- [ ] hard-limit boundary and one-over-limit failures
- [ ] diagnostic order remains stable across input map/list construction order

Gate:

- [ ] Invalid input cannot reach edge compilation.
- [ ] Canonical output is byte-stable across fresh processes.

## 7) Exposed Edge Compilation

- [ ] Emit local edges in canonical polygon/edge order.
- [ ] Split partially overlapping collinear edges deterministically.
- [ ] Remove exact reversed internal solid edges.
- [ ] Do not remove one-way edges merely because a solid overlaps them.
- [ ] Preserve source lineage through split edges with deterministic sub-edge
      identity.
- [ ] Build previous/next exposed adjacency.
- [ ] Classify smooth connected vertices versus exposed endpoints for later
      ghost-vertex contact handling.
- [ ] Stitch matching chunk-boundary endpoints only after ordered active
      geometry flattening.
- [ ] Require quantized endpoint and compatible semantic/mode match for a
      continuous seam.
- [ ] Treat unmatched, missing-neighbor, or incompatible endpoints as exposed
      ledges.
- [ ] Keep intentional missing polygon coverage as a pit.
- [ ] Produce polygon and edge records in one compiler result; never derive
      collision edges from render triangles.

Golden tests:

- [ ] compile all `slopes_golden_v1` chunks
- [ ] verify chunk-0/chunk-1 and chunk-2/chunk-3 seam identities
- [ ] verify pit edges remain exposed
- [ ] verify one-way slope keeps its authored top side
- [ ] verify ceiling/underside normals
- [ ] verify narrow peak endpoint adjacency
- [ ] verify overlapping surface candidate IDs/order
- [ ] freeze `source-v1` and `edges-v1` signatures

Gate:

- [ ] Compiler output is independent of input object allocation/map order.
- [ ] No internal edge survives and no exposed gameplay edge is removed.

## 8) Upright Capsule And Segment Kernel

This step implements pure geometry only, not body integration.

- [ ] Implement upright capsule center, facing-aware offset, radius, vertical
      half-segment, and derived AABB.
- [ ] Support zero half-segment as a circle.
- [ ] Implement allocation-free:
  - [ ] closest point on finite segment
  - [ ] closest points between capsule spine and terrain segment
  - [ ] squared distance and separation
  - [ ] endpoint radial normal
  - [ ] face normal contact
  - [ ] overlap/penetration diagnostic
  - [ ] conservative-advance moving capsule versus segment
  - [ ] fixed 8-iteration advance and 8-step bisection refinement
- [ ] Return explicit hit/no-hit, time of impact, point, normal, feature kind,
      and edge ID without heap allocation in the hot path.
- [ ] Define equal-time comparison through the shared tie epsilon and edge-ID
      order.
- [ ] Bound invalid-start recovery primitives to inputs needed by the Phase 2
      controller; do not implement controller policy here.
- [ ] Keep one-way side/crossing policy outside the raw distance primitive and
      expose the inputs needed by the later filter.

Tests:

- [ ] horizontal, vertical, and sloped face contacts
- [ ] both segment endpoints
- [ ] capsule side and both caps
- [ ] circle degeneration
- [ ] parallel and near-parallel motion
- [ ] grazing/tangent contact
- [ ] zero displacement
- [ ] starting overlap diagnostic
- [ ] maximum representative velocity without tunneling
- [ ] mirrored coordinates/facing offsets
- [ ] simultaneous equal-time edges select canonical ID
- [ ] `capsule contact-order` golden signature

Gate:

- [ ] Pure kernel results contain no gameplay grounding/walkability decision.
- [ ] Continuous sweep is the normal high-speed path; discrete overlap is not
      used as successful collision resolution.

## 9) Deterministic Static Edge Index

- [ ] Reuse the existing 2D grid primitive only where it preserves the frozen
      closed-boundary and order contract; otherwise wrap shared cell math
      without retaining AABB-face categories.
- [ ] Use the frozen 128-world-unit default cell size.
- [ ] Insert an edge into every closed cell touched by its tight AABB.
- [ ] Insert exact-boundary edges into both adjacent cells.
- [ ] Preserve canonical edge order inside buckets.
- [ ] Query the swept-shape AABB expanded by skin/contact tolerance.
- [ ] Deduplicate with caller-owned stamps or an equivalent allocation-free
      mechanism.
- [ ] Sort deduplicated candidates by canonical edge ID before narrow phase.
- [ ] Rebuild only from an immutable ordered edge list.
- [ ] Expose counters for inserted references, cells visited, raw candidates,
      unique candidates, and overflow/limit diagnostics.
- [ ] Never truncate candidates to meet a budget.

Tests:

- [ ] horizontal, vertical, diagonal, zero-width-bound, and multi-cell edges
- [ ] negative world coordinates
- [ ] exact cell-boundary insertion/query
- [ ] expanded swept-AABB inclusivity
- [ ] duplicate removal across cells
- [ ] candidate order independent of query traversal
- [ ] rebuild after reordered but canonically equivalent input
- [ ] 1280-edge representative and 5120-edge hard fixtures

Gate:

- [ ] Every brute-force query result equals the indexed result.
- [ ] Candidate output is duplicate-free and canonically ordered.

## 10) Signatures And Determinism

- [ ] Implement canonical UTF-8 record writers for `source-v1` and `edges-v1`.
- [ ] Serialize quantized integers and stable enum/string IDs only.
- [ ] Hash with SHA-256 through an existing dependency or a narrowly justified
      pure-Dart implementation/dependency addition.
- [ ] Add repeated fresh-instance and fresh-process comparison harnesses.
- [ ] Verify streaming flatten/stitch order signatures without connecting the
      bundle to production `TrackManager`.
- [ ] Store reviewed golden digest files next to the fixture tests.
- [ ] Require an explicit update flag/command; normal tests never rewrite
      goldens.
- [ ] Record the compatibility review trigger for any digest change.

Gate:

- [ ] Geometry and contact-order signatures match across repeated local runs.
- [ ] No unordered collection or default hash influences a signature.

## 11) Allocation And Performance Harness

- [ ] Implement `packages/runner_core/tool/benchmark_slopes.dart`.
- [ ] Support:
  - [ ] representative 1280-edge fixture
  - [ ] hard-stream 5120-edge fixture
  - [ ] matched flat-polygon fixture
  - [ ] warmup/runs/iterations flags
  - [ ] JSON output with environment and revision
- [ ] Measure compiler, index rebuild, candidate query, and raw capsule/segment
      sweep separately.
- [ ] Add a steady-state allocation assertion for query and kernel calls.
- [ ] Report p50/p95/p99/max and candidate counters.
- [ ] Keep benchmark instrumentation out of normal hot paths unless behind the
      existing debug/test gate.

Phase 1 gates:

- [ ] representative index rebuild p99 <=15 ms
- [ ] hard 5120-edge index rebuild p99 <=50 ms
- [ ] query candidate p95 <=24 and p99 <=64
- [ ] zero steady-state allocation per terrain query
- [ ] matched slope query/index overhead <=25% versus flat
- [ ] no capacity case truncates or reorders output

Actor solve, whole-Core tick, navigation graph, validator, and editor budgets
belong to their later owning phases and are not Phase 1 exit gates.

## 12) Documentation And Review

- [ ] Add high-signal public API docs with units, invariants, ordering, and
      allocation behavior.
- [ ] Document reasoning hotspots only:
  - [ ] winding/outward-normal convention
  - [ ] canonical ID/tie order
  - [ ] collinear split/internal removal
  - [ ] exact cell-boundary insertion
  - [ ] conservative-advance bounds
- [ ] Do not update TDD/GDD as though the new geometry were production
      authority.
- [ ] Update this checklist and `docs/building/slopes/plan.md` with measured
      evidence.
- [ ] If public Core exports change, update the package export surface and API
      docs deliberately.
- [ ] Record any implementation finding that would affect a later phase; do
      not silently broaden Phase 1.

## 13) Validation

Required:

- [ ] `dart format --output=none --set-exit-if-changed` on changed Dart files
- [ ] `dart analyze packages/runner_core`
- [ ] `dart test packages/runner_core/test`
- [ ] all new terrain geometry tests
- [ ] root determinism and fixed-point tests
- [ ] both fixed-point benchmark variants
- [ ] both new slope benchmark fixtures
- [ ] `git diff --check`
- [ ] local Markdown link integrity

Also run the smallest root tests for any existing utility/export file touched.

Record command, revision, environment, result, and artifact path. A timeout or
unknown result is not a pass.

## 14) Removal And Non-Authority Proof

- [ ] `rg` proves no production `GameCore`, `TrackManager`, collision system,
      navigation system, spawn system, snapshot builder, or renderer imports
      the Phase 1 terrain domain.
- [ ] No feature flag or alternate runtime authority was added.
- [ ] No legacy rectangle/flat-ground type or test was removed.
- [ ] No generated source asset was migrated.
- [ ] Temporary benchmark artifacts are outside tracked source.
- [ ] Any abandoned prototype file/API is removed before acceptance.

The Phase 1 terrain types themselves are retained for Phase 2. Legacy removal
is intentionally deferred to the direct cutover phase after all consumers have
migrated.

## 15) Phase 1 Exit Gate

- [ ] Numeric policy has one implementation and complete boundary tests.
- [ ] Polygon/edge identity and canonicalization are deterministic.
- [ ] Internal removal, adjacency, ledges, pits, and seams match the golden.
- [ ] Capsule/segment closest-distance and sweep primitives pass exhaustive
      edge cases.
- [ ] Static edge index matches brute force and preserves canonical order.
- [ ] Geometry/contact signatures match across fresh runs.
- [ ] Allocation and performance gates pass.
- [ ] Public APIs are documented and Core remains Flutter/Flame-free.
- [ ] Production runtime authority remains exclusively on the legacy path.
- [ ] No Phase 0 decision was reopened or guessed.
- [ ] Validation ledger has no unexplained failure.
- [ ] Phase 2 findings are recorded, but no Phase 2 detailed checklist is
      created until Phase 1 evidence is accepted.

Only after every exit item is checked may Phase 2 capsule-controller and player
integration planning begin.
