# Polygon Terrain Authoring Foundation

## Status And Authority Boundary

The exact polygon-source foundation is implemented in `runner_core` and the
standalone editor. It is not yet the normal prefab/chunk source contract and
does not make polygon terrain authoritative in production gameplay.

Current normal source and runtime behavior remain unchanged:

- prefab authoring still persists schema v2 rectangle `colliders`
- chunk authoring still persists schema v1 `groundProfile` and `groundGaps`
- normal `GameCore(...)` and replay validation still use legacy rectangle
  motion authority
- no staged polygon generator output or Flame terrain rendering exists yet

The active schema migration, generator, preview, and cutover work remains in
[the Phase 4 checklist](../building/slopes/phase4-implementation-checklist.md).

## Ownership

| Contract | Owner | Implemented consumer |
| --- | --- | --- |
| Exact half-pixel source vertex and shape values | `tools/editor/lib/src/terrain_authoring/terrain_source_models.dart` | editor model/codec tests and the Core adapter |
| Source validation and canonicalization | `runner_core` `TerrainSourceCanonicalizer` | `TerrainCompiler` and editor adapter |
| Positive-area polygon overlap | `runner_core` `TerrainPolygonOverlap` | `TerrainCompiler`; source-loop entry point is ready for editor owner validation |
| Exact placement and physics-grid quantization | `runner_core` `TerrainSourceTransform` | `TerrainCompiler`, Core fixtures, and editor adapter |
| Editor-to-Core conversion | editor `TerrainSourceCoreAdapter` | pure-Dart authoring tests; prefab/chunk UI integration is pending |

Core has no dependency on editor models, JSON, widgets, or filesystem state.
The editor depends on Core through a one-way local package dependency and does
not reimplement geometric predicates.

## Source Coordinates And Canonicalization

Editor source coordinates are stored as integer half-pixel ticks: two source
ticks equal one world unit. JSON accepts only finite integer or `.5` values and
emits canonical integer/one-decimal representations.

Core reviews each source loop without mutating it. The exact review:

1. rejects repeated closure, consecutive duplicates, fewer than three distinct
   vertices, short edges, small/zero area, and every self-contact
2. calculates orientation and area using integer `BigInt` products, including
   at the accepted coordinate limit
3. canonicalizes to clockwise winding in Y-down coordinates
4. rotates to the lexicographically smallest complete cyclic sequence
5. reports collinear middle vertices and removes them only when an explicit
   normalization call requests it
6. sorts diagnostics by source path, shape ID, element index, and code

Committed noncanonical source can therefore be diagnosed without being
silently rewritten. The editor adapter returns a new shape when an explicit
Normalize/quick-fix flow applies Core's canonical vertices; an undoable UI
command has not been wired yet.

Cross-shape overlap also uses exact integer products. Proper crossings,
containment, coincident occupied area, and same-interior collinear boundaries
are overlap. A shared vertex or a shared boundary whose interiors lie on
opposite sides is legal.

## Exact Placement Transform

`TerrainSourceTransform` is the only implemented polygon placement primitive.
Its inputs are integer source ticks plus an exact rational uniform scale. The
order is fixed:

1. subtract the source anchor
2. apply horizontal and vertical reflection
3. apply the exact uniform scale
4. add source-tick translation
5. quantize once to the `1/1024` physics grid, with halfway values rounded away
   from zero

The accepted authored scale range is `0.3` through `3.0` in exact `0.1` steps.
Core rejects a non-positive denominator/numerator, an off-step rational, or an
out-of-range scale. Intermediate products use `BigInt`; the final physics tick
must fit the public terrain coordinate range.

`TerrainCompiler` canonicalizes the transformed loop again, keeping source
vertices aligned with their transformed lineage through odd reflection. It
rejects a placement that collapses area or makes any edge shorter than one
world unit.

The editor adapter accepts anchor and translation in integer half-pixel ticks
and scale as integer tenths. Existing editor placement JSON still stores a
`double`; converting that legacy field and the root generator to this exact
boundary is pending Phase 4 work.

## Read-only Legacy Prefab Union Planner

The editor owns a pure migration-planning primitive for legacy prefab AABB
colliders. It performs no filesystem writes, schema changes, or runtime
cutover. For a collider centered at integer offset `(x, y)` with integer width
`w` and height `h`, its exact half-pixel-tick bounds are:

```text
left = 2x - w   right  = 2x + w
top  = 2y - h   bottom = 2y + h
```

The planner coordinate-compresses those bounds, unions occupied cells using
four-way connectivity, traces deterministic clockwise outer boundaries,
removes only collinear middle vertices, and delegates final canonicalization
and validation to Core. Disconnected components receive stable canonical IDs
`collision_001...`. Exact occupied-area comparison detects any lost or added
coverage. Holes, point-only contacts, invalid dimensions, coordinate overflow,
unsupported topology, and Core shape/vertex/geometry failures are blockers.

The current repository audit produces 88 topological candidate loops from 70
collision-bearing prefabs. Core accepts 85 loops across 67 prefabs unchanged.
`dark_menhir_01`, `dark_menhir_03`, and `ruin_stone_00` each produce an exact
one-source-tick (`0.5 px`) exterior edge below the accepted one-world-unit
minimum. The planner reports those records instead of modifying their occupied
area or weakening the shared geometry rule. Prefab v3 writing remains pending
an explicit content decision; existing schema v2 source and legacy runtime
authority are unchanged.

## Determinism And Validation Evidence

The foundation is covered by:

- exact source model/codec/order/equality tests
- canonical winding/start, explicit collinear normalization, self-contact,
  coordinate-limit, and compiler-parity tests
- shared-boundary, point-contact, crossing, containment, concavity, opposite
  winding, and coordinate-limit overlap tests
- asymmetric anchor/reflection/scale/translation and symmetric rounding tests
- post-transform short-edge rejection
- full Core geometry/signature goldens and fresh-process signature tests
- full editor regression tests

The latest command counts and revisions are recorded in the Phase 4 validation
ledger rather than duplicated here.
