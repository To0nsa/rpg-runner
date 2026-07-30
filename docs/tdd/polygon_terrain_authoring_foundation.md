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
| Editor-to-Core conversion | editor `TerrainSourceCoreAdapter` | migration checks and shared interaction reducer; prefab/chunk UI integration is pending |
| Shared polygon interaction state | editor `TerrainPolygonInteractionReducer` | pure-Dart selection/draft/gesture/semantic-edit tests; route wiring is pending |
| Render projection and source-space hit testing | editor `TerrainPolygonSceneProjection` / `TerrainPolygonSceneHitTest` | framework-neutral scene tests; Prefab/Chunk route wiring is pending |
| Canvas projection and source-loop overlay | editor `TerrainPolygonViewportTransform` / `TerrainPolygonScenePainter` | shared Flutter painter tests; compiler-edge overlay and route wiring are pending |
| Prefab polygon owner validation | editor `validatePrefabCollisionShapes` | Core compiler plus exact visual-bounds tests; normal `PrefabDef` integration is pending |
| Immutable prefab-v3 polygon record | editor `PrefabV3Def` | migration target and model-contract tests; normal store/UI integration is pending |
| Strict prefab-v3 file structure and canonical serialization | editor `PrefabV3FileData` / `PrefabV3FileCodec` | normal prefab layer and delegated migration checks; filesystem store integration is pending |
| Prefab polygon commit and revision policy | editor `PrefabV3CollisionCommitPolicy` | shared reducer commit tests; plugin/page dispatch is pending |
| Fail-closed authored JSON and retained-metadata parsing | editor neutral domain plus `StrictTerrainSourceCodec` | legacy migration, prefab v3, and chunk-v2 target codecs |
| Legacy prefab occupied-area union and reviewed corrections | editor prefab migration domain | aggregate check plan; removal follows verified prefab v3 write |
| Legacy flat-ground/gap conversion | editor chunk migration domain | aggregate check plan; removal follows verified chunk v2 write |
| Strict legacy prefab-v1/v2 and chunk-v1 source parsing | editor migration-owned `LegacyPrefabDef` / chunk-v1 models | read-only aggregate planner input; compatibility stores and normal `PrefabDef` are bypassed |
| Cross-domain canonical migration report | editor migration domain | read-only CLI, strict in-memory targets, and exact source SHA-256 audit; source writes remain pending |
| Isolated chunk-v2 target structure | editor migration domain | strict canonical codec and complete-repository round-trip; normal `ChunkStore` does not consume it yet |

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
Normalize operation applies Core's canonical vertices. The shared interaction
reducer now exposes that operation as one undoable before/after commit; its
button and keyboard wiring remain pending in the prefab and chunk routes.

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
classifies the complete source set before selecting a parser. Prefab v1/v2 plus
chunk v1 enters legacy planning; prefab v3 plus chunk v2 enters strict current-
schema validation; every partial or mixed generation fails closed. Legacy mode
builds all nine targets in memory and requires strict byte-stable target round
trips. Current mode requires source to already equal its canonical bytes,
rechecks Core geometry and placement references, and emits the same nine files
as byte-identical no-op targets. Readiness report v2 records source state, all
nine before/after SHA-256 pairs, 107 unchanged revision decisions, and 99
prefab impact records covering 50 placements. The legacy report fingerprint is
`14297a48`; the equivalent current-state fingerprint is `4116ae04`.

Rectangle-era prefab records used by this path are isolated as
`LegacyPrefabDef`/`LegacyPrefabData` inside the migration layer. The strict
codec, migration planner, reviewed union, and v3 target conversion no longer
depend on normal `PrefabDef`. This preserves the frozen legacy interpretation
while the immutable normal `PrefabV3Def` record establishes polygon ownership
without retaining a second editable rectangle authority. The existing v2
`PrefabDef`, store, and UI remain active until their single cutover.

`tool/migrate_polygon_authoring.dart` defaults to check mode. It returns `0`
for a complete blocker-free readiness plan, `1` for source/plan/target/drift or
report-write failure, and `64` for invalid usage. Immediately before reporting,
it rereads and rehashes every source. The only optional write is an explicitly
requested workspace-relative `.json` report outside `assets/authoring`;
`--write` is rejected. The command dependency chain is pure Dart: shared model
immutability annotations use `package:meta` rather than pulling `dart:ui` into
offline tooling.

This report is still not a source-write authorization. Current-schema
idempotence is proven, but staged generated-artifact impact, normal editor
schema support, transaction staging, rollback, and source replacement remain
separate gates. Normal source and runtime behavior are unchanged.

## Polygon Target Schemas And Normal Prefab Record

`PrefabV3Def` is the immutable normal-model record for the intended prefab-v3
shape. `PrefabV3FileData` snapshots the complete v3 file payload and is reused
by the migration target alias, while `ChunkV2TargetDocument` remains an isolated
migration target. Prefab v3 replaces only the legacy `colliders` field with
anchor-relative `collisionShapes`; chunk v2 replaces only
`groundProfile`/`groundGaps` with direct chunk-local `collisionShapes`. Existing
identity, revision, lifecycle, visual source, dimensions, composition,
placement, marker, tag, and ground-band metadata is preserved.

The normal records snapshot their lists but deliberately preserve supplied
shape and tag order. This lets validation diagnose noncanonical authored input
instead of silently repairing it. `PrefabV3FileCodec` sorts and normalizes
copied records only while encoding, then strictly decodes its own result before
returning it. Read-only planned output therefore remains deterministic without
mutating the source record or allowing an invalid enum/source model to escape.

`PrefabV3FileCodec` is the single prefab-v3 structural authority in the normal
prefab layer. `PolygonAuthoringTargetCodec` delegates prefab-v3 calls to it and
retains the isolated chunk-v2 facade. Both require exact target versions and
field sets, canonical list/ID/tag ordering, exact integer fields, half-pixel
coordinates, known enums, and accepted placement-scale steps. Unknown and
legacy fields reject rather than default. Geometry/topology acceptance remains
Core-owned and is not duplicated in structural codecs.

All planned current repository output—99 prefab records and 8 chunk files—has
been encoded, decoded strictly, and re-encoded byte-for-byte in tests. The
chunk target document/codec remains migration staging. The normal prefab layer
now owns `PrefabV3Def`, `PrefabV3FileData`, and `PrefabV3FileCodec`, but
`PrefabStore`, `ChunkStore`, UI, generator, source JSON, and runtime authority
still use their existing paths.

## Prefab Polygon Owner Validation

`validatePrefabCollisionShapes` is independent of the still-v2 normal
`PrefabDef`, allowing prefab-v3 rules to be proven before the model/store
cutover. It requires collision shapes for obstacle/platform owners and forbids
them for decorations. Each source loop must satisfy Core's canonical authoring
policy; the full Core compiler then owns occupied-overlap, duplicate identity,
vertex, shape, and compiled-geometry limits. Exact shared boundaries remain
legal.

Visual bounds are converted to anchor-relative half-pixel ticks. At least one
accepted shape must overlap that rectangle in positive area: point or edge
contact alone is not sufficient. A shape may deliberately extend beyond the
visual source. Its left/top/right/bottom extent is reported exactly in integer
or `.5 px` units as a non-blocking warning, and geometry is never clipped.
Missing or invalid geometry and no positive-area visual intersection remain
blocking. Prefab validation issues now carry severity and exact
source/shape/element location; the domain plugin maps warnings without making
them export blockers.

`PrefabV3CollisionCommitPolicy` is the owner boundary between a successful
shared interaction commit and session history. It requires the commit's
`beforeShapes` to equal the current prefab snapshot, rejects missing owners,
noncanonical shape order, unresolved colliding visual bounds, and every
blocking owner issue, and returns the original file-data instance on rejection
or no-op. An accepted semantic change replaces only that prefab and increments
its revision once; non-blocking extent warnings remain attached to the result.

The generic plugin command API has no rejected-command result channel.
Therefore temporarily invalid gesture state and policy diagnostics remain in
the page projection, and the page must dispatch only an accepted policy result.
The future plugin handler reuses this policy defensively before replacing its
authoritative document. This keeps invalid drags and empty commits out of
session undo/redo.

## Shared Polygon Interaction And Scene Projection

`TerrainPolygonInteractionState` keeps committed owner shapes separate from an
open creation draft or pointer-gesture preview. Repeated pointer updates change
only the preview. A successful Core-reviewed commit returns one immutable
before/after snapshot for history; rejection keeps the preview and sorted
diagnostics available; cancellation discards it without reconstructing source.
Selection and tool changes produce no semantic commit. A no-op gesture never
canonicalizes loaded geometry implicitly.

The shared reducer provides shape/edge/vertex selection, ordered polygon
creation, vertex and whole-shape movement, provisional edge insertion,
vertex/shape deletion, deterministic lowest-free-ID duplication, explicit
mode/metadata editing, and explicit Core normalization. Semantic geometry
commits use the Core canonicalizer and exact positive-area overlap predicate.
Owner-specific bounds, visual intersection, capacity, transformed placement,
and seam validation stay in the prefab/chunk plugins rather than this shared
state machine.

All stored and preview edit coordinates remain integer half-pixel ticks. The
half-pixel snap preserves each tick; owner-grid snap uses an integer pixel step
with exact ties away from zero. Scene hit testing alone accepts fractional
source-space pointer coordinates produced by inverse viewport transforms.

`TerrainPolygonSceneProjection` exposes stable shape order, selected
edge/vertex indices, gesture-preview identity, and an open draft without
depending on Flutter. `TerrainPolygonSceneHitTest` uses vertex, edge, then fill
priority. It chooses the closest feature first and resolves equal distances by
selected shape, visually topmost canonical shape, local element index, then
shape ID. These are UI selection rules only; collision geometry remains Core-
owned.

`TerrainPolygonViewportTransform` maps exact source half-pixel ticks into
display-only canvas doubles. Its inverse deliberately returns fractional
source-space pointer coordinates; a semantic edit must still pass those values
through the reducer's integer snap policy. `TerrainPolygonScenePainter` renders
solid/one-way source fills and boundaries, vertices, selected edges, gesture
previews, and open drafts from the shared projection. Projection, transform,
and style have structural equality so equivalent frames do not repaint.

This painter does not compile geometry and its fills are never collision or
navigation authority. Collision-edge/normal/lineage diagnostics must come from
the Core compiler preview adapter. Prefab/Chunk controls, keyboard handling,
route painter installation, and plugin/store commit wiring remain pending.

## Determinism And Validation Evidence

The foundation is covered by:

- exact source model/codec/order/equality tests
- canonical winding/start, explicit collinear normalization, self-contact,
  coordinate-limit, and compiler-parity tests
- shared-boundary, point-contact, crossing, containment, concavity, opposite
  winding, and coordinate-limit overlap tests
- asymmetric anchor/reflection/scale/translation and symmetric rounding tests
- post-transform short-edge rejection
- shared polygon selection/draft/gesture cancellation and one-commit history
- deterministic shape IDs, exact snapping, explicit normalization, and
  positive-area duplicate rejection
- shared render projection plus vertex/edge/fill hit-test priority and
  deterministic tie-breaks
- exact canvas/source transform, structural repaint, and widget-level source
  fill/selection/preview/draft painter tests
- immutable prefab-v3 snapshots, value equality/copy/revision behavior,
  preserved authored ordering, and target-boundary canonicalization tests
- strict prefab-v3 file parsing, copy-only canonical serialization, duplicate
  identity rejection, invalid-model refusal, and delegated migration round trips
- prefab owner commit freshness, canonical order, visual-bound resolution,
  warning/error handling, no-op identity, and exactly-once revision tests
- full Core geometry/signature goldens and fresh-process signature tests
- full editor regression tests

The latest command counts and revisions are recorded in the Phase 4 validation
ledger rather than duplicated here.
