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
| Legacy prefab occupied-area union and reviewed corrections | editor prefab migration domain | aggregate check plan; removal follows verified prefab v3 write |
| Legacy flat-ground/gap conversion | editor chunk migration domain | aggregate check plan; removal follows verified chunk v2 write |
| Strict legacy prefab-v1/v2 and chunk-v1 source parsing | editor migration domain | read-only aggregate planner input; compatibility stores are bypassed |
| Cross-domain canonical migration report | editor migration domain | read-only CLI, strict in-memory targets, and exact source SHA-256 audit; source writes remain pending |
| Isolated prefab-v3/chunk-v2 target structures | editor migration domain | strict canonical codecs and complete-repository round-trip; normal stores do not consume them yet |

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
minimum. The accepted resolution keeps the shared geometry rule and provides a
closed migration-only catalog of minimal outward replacements. They add 34,
25, and 36 half-pixel-square ticks (`8.5 px²`, `6.25 px²`, and `9 px²`) and are
bound to the complete expected collider lists. Any source drift blocks rather
than applying a stale correction. All 70 collision prefabs and 88 planned
loops now pass Core. Prefab v3 writing remains pending; existing schema v2
source and legacy runtime authority are unchanged.

## Legacy Chunk Ground Planner And Aggregate Check Report

The editor also owns a pure flat-ground migration primitive. It validates
legacy chunk dimensions, flat profile bounds, pit types/bounds, non-overlap,
Core coordinate limits, and the per-chunk shape limit. Each positive solid span
between gaps becomes one canonical clockwise `ground_001...` rectangle covering
`[spanStart, spanEnd] x [topY, chunkHeight]`; a pit is represented only by
missing coverage. Adjacent gaps create no zero-width shape, a full-width gap
creates an empty valid ground list, and exact planned area is checked against
Core's reviewed doubled area.

`PolygonAuthoringLegacyCodec` parses the migration inputs without the normal
stores' compatibility normalization. It accepts only the documented prefab-v1
or prefab-v2 and chunk-v1 field sets, exact JSON types, known enums, valid scale
steps, and canonical current-schema ordering. Unknown fields, numeric coercion,
and noncanonical order reject. Prefab-v1 key/lifecycle defaults are promoted
only after its exact source shape passes validation. Each returned document is
bound to the SHA-256 digest of the exact UTF-8 text that was parsed.

The cross-domain `PolygonAuthoringMigrationPlan` combines those prefab and
chunk results without filesystem I/O. It canonicalizes path separators,
rejects missing/duplicate stable owner keys or absent/malformed digests,
verifies that every reviewed correction still has an owner, and emits stable
report-v2 JSON containing all nine source path/SHA-256 records, exact
decimal-string area facts, and the complete planned polygon source. Input
order does not affect the report. The current report contains 99 prefabs, 88
prefab shapes, 8 chunks, and 9 ground shapes with zero blockers; its report
fingerprint is `cc2ed2e6`.

The plan exposes a pure pre-write audit for freshly computed SHA-256 values.
Changed, missing, or ambiguously canonicalized paths reject deterministically.

`PolygonAuthoringMigrationCheck` is the read-only repository orchestrator. It
strictly loads all nine legacy files, validates unknown prefab placement
references, builds every prefab-v3/chunk-v2 target in memory, and requires each
target to decode and re-encode byte-for-byte. Readiness report v1 records the
nine before/after SHA-256 pairs, all 107 unchanged representation-only revision
decisions, and 99 prefab impact records covering the current 50 chunk
placements. Its current canonical report fingerprint is `90fbd996`.

`tool/migrate_polygon_authoring.dart` defaults to check mode. It returns `0`
for a complete blocker-free readiness plan, `1` for source/plan/target/drift or
report-write failure, and `64` for invalid usage. Immediately before reporting,
it rereads and rehashes every source. The only optional write is an explicitly
requested workspace-relative `.json` report outside `assets/authoring`;
`--write` is rejected. The command dependency chain is pure Dart: shared model
immutability annotations use `package:meta` rather than pulling `dart:ui` into
offline tooling.

This report is still not a source-write authorization. Post-cutover/current-
schema idempotence, staged generated-artifact impact, transaction staging,
rollback, and source replacement remain separate gates. Normal source and
runtime behavior are unchanged.

## Isolated Polygon Target Schemas

`PrefabV3TargetDocument` and `ChunkV2TargetDocument` define the intended output
shape without changing the normal editor models. Prefab v3 replaces only the
legacy `colliders` field with anchor-relative `collisionShapes`; chunk v2
replaces only `groundProfile`/`groundGaps` with direct chunk-local
`collisionShapes`. Existing identity, revision, lifecycle, visual source,
dimensions, composition, placement, marker, tag, and ground-band metadata is
preserved.

`PolygonAuthoringTargetCodec` is intentionally stricter than the current
compatibility stores. It requires the exact target version and field set,
canonical list/ID/tag ordering, exact integer fields, half-pixel coordinates,
known enums, and accepted placement-scale steps. It rejects unknown and legacy
fields rather than defaulting them. Geometry/topology acceptance remains
Core-owned and is not duplicated in the structural codec.

All planned current repository output—99 prefab records and 8 chunk files—has
been encoded, decoded strictly, and re-encoded byte-for-byte in tests. The
target types remain migration staging: normal `PrefabStore`, `ChunkStore`, UI,
generator, source JSON, and runtime authority still use their existing paths.

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
