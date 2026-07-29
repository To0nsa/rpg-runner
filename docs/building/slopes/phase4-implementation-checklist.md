# Slopes Phase 4 - Polygon Authoring, Migration, And Generation Checklist

- Created: July 28, 2026
- Status: Implementation in progress; no Phase 4 source/schema cutover has begun
- Source plan: [plan.md](plan.md)
- Frozen gameplay decisions:
  [phase0-gameplay-decisions.md](phase0-gameplay-decisions.md)
- Frozen technical contracts:
  [phase0-technical-contracts.md](phase0-technical-contracts.md)
- Golden/performance specification:
  [phase0-golden-performance-spec.md](phase0-golden-performance-spec.md)
- Consumer inventory:
  [phase0-consumer-inventory.md](phase0-consumer-inventory.md)
- Accepted geometry foundation:
  [phase1-implementation-checklist.md](phase1-implementation-checklist.md)
- Accepted capsule/player foundation:
  [phase2-implementation-checklist.md](phase2-implementation-checklist.md)
- Accepted enemy/navigation foundation:
  [phase3-implementation-checklist.md](phase3-implementation-checklist.md)

## 1) Goal And Exit Outcome

Replace rectangle-only prefab collision and flat-ground/gap authoring with one
versioned polygon source contract, make that contract safely editable by a
non-developer, migrate every current source record deterministically, and
generate canonical Phase 1 terrain inputs/edges and deterministic render
triangles without changing normal production collision authority yet.

At Phase 4 acceptance:

- prefab schema v3 and chunk schema v2 use polygon collision source only
- the normal editor/store path no longer writes prefab `colliders`, chunk
  `groundProfile`, or chunk `groundGaps`
- exact half-pixel source coordinates are represented as integers internally
- prefab placement transform, reflection, rational scale, and physics-grid
  quantization have one documented order and one tested implementation
- the editor can create, select, move, insert, delete, and inspect polygon
  vertices with undo/redo and deterministic save output
- prefab-local and chunk-local polygon workflows reuse the same geometry
  editing/diagnostic primitives rather than forked implementations
- Core's accepted terrain compiler remains the geometry authority used by
  generator validation and editor preview adapters
- source, editor preview, generator output, and Core compilation produce
  identical canonical signatures for the same fixture
- all current colliders, flat ground, and gaps migrate automatically or appear
  in a reviewed blocking reauthor report
- seam validation covers every chunk adjacency the actual level scheduler can
  emit, including transitions between assembly runs/tier pools
- invalid geometry, placement expansion, seams, limits, or generated drift
  blocks export with a stable actionable diagnostic
- no-op load/save, migration check, and generation are deterministic
- the representative polygon interaction and authoring-capacity gates pass

Phase 4 changes the repository authoring source and staged generated terrain
data. It does not make polygon terrain authoritative in normal `GameCore`,
stream it, render it in Flame, issue a new compatibility version, or remove the
legacy runtime authority. Those remain Phases 5-7.

## 2) Phase Boundary And Non-Goals

In scope:

- shared source polygon/value/diagnostic models
- prefab schema v3 and chunk schema v2
- strict parsers, canonical serializers, stores, plugins, pending diffs, and
  source-drift/write safety
- deterministic rectangle union and flat-ground/gap migration tooling
- prefab and chunk polygon manipulation UI
- transformed placement preview and collision overlay
- cross-shape, chunk-bound, and scheduler-aware seam validation
- Core compiler integration for preview/generation/parity
- staged generated local polygons, exposed edges, triangle indices, identity
  lineage, and signatures for later streaming/rendering
- generator validation and generated-file drift detection
- editor interaction/capacity benchmarks
- TDD/editor documentation for delivered authoring behavior

Out of scope:

- normal runtime terrain-authority selection or production cutover
- streamed world-space stitching/culling and atomic runtime bundle rebuilds
- Flame terrain fill, material tiling, foreground masks, or debug rendering
- final production slope content design/pass
- changing level procedural selection, difficulty pacing, or assembly rules
- player/enemy movement, navigation, placement, or balance changes
- moving/rotating/deformable/destructible terrain
- curves, splines, holes, non-uniform scale, or arbitrary placement rotation
- per-instance prefab vertex overrides in the Chunk Creator
- actor/entity collider authoring changes; world-contact capsules continue to
  derive from the accepted entity AABB source while combat bounds remain AABB
- combat/pickup/trigger collider migration from AABBs
- replay protocol/version issuance and deployment rollout

The editor may preview accepted Core geometry and actor slope eligibility, but
it must not become a second gameplay simulator or redefine walkability.

## 3) Frozen Source Contract

Implement these accepted decisions without reopening them:

| Property | Frozen rule |
| --- | --- |
| Geometry | static simple polygons only |
| Coordinates | prefab/chunk local, Y-down, exact multiples of `0.5 px` |
| Internal source unit | integer half-pixel ticks |
| Winding | clockwise in Y-down coordinates |
| Start vertex | lexicographically smallest canonical cyclic sequence |
| Minimum shape | 3 distinct vertices, non-zero area, at least `1 px²` |
| Minimum edge | `1 px` |
| Collision mode | `solid` or `oneWay` |
| Metadata | optional `surfaceKind` and optional render `materialKey` |
| Shape overlap | exact shared boundaries allowed; positive-area overlap blocked |
| Chunk bounds | every transformed vertex inside closed chunk bounds |
| Cross-chunk continuity | matching boundary vertices/coverage, never overflow ownership |
| Placement transform | anchor-relative vertex, X/Y reflection, uniform scale, translation, then one physics-grid quantization |
| Limits | 64 shapes/prefab, 64 vertices/shape, 512 expanded/source shapes/chunk, 4,096 exposed edges/chunk |

Migration and new-shape defaults are deliberately conservative:

- every legacy AABB migrates as `solid`
- prefab kind must not implicitly convert a platform to `oneWay`
- migration must not invent `surfaceKind` or `materialKey`
- a newly created shape defaults to `solid` with optional metadata absent
- changing collision mode or metadata is an explicit undoable edit
- rendering metadata never changes collision behavior

## 4) Current Implementation Map

Phase 4 must replace or extend these concrete owners:

| Current owner | Current assumption | Required Phase 4 outcome |
| --- | --- | --- |
| `prefab_schema.dart` | prefab schema v2 | add v3; normal writes target v3 only |
| `prefab_collider_def.dart` | one center/width/height AABB | replace normal source model with shared polygon shapes |
| `prefab_def.dart` | `colliders` list | `collisionShapes` with stable shape IDs and metadata |
| `PrefabStore` | loads/migrates rectangle-era prefab JSON | strict v3 normal path; old schema only through migration input |
| `prefab_validation_geometry.dart` | AABB dimensions/source-bound intersection | polygon structure, bounds, overlap, limits, and visual-source intersection |
| Prefab Creator overlay | rectangle move/resize handles | shared polygon create/select/vertex/shape tools |
| `chunk_domain_models.dart` | chunk schema v1, flat profile and pit gaps | schema v2 direct chunk terrain polygons |
| `ChunkStore` | normalizes flat ground authority | preserves polygon source and exact half-pixel coordinates |
| `chunk_validation.dart` | flat top/gap/span checks | local/expanded polygon, boundary, seam, and capacity checks |
| `ChunkDomainPlugin` | ground-profile/gap commands | polygon edit commands and derived prefab-impact diagnostics |
| Chunk Creator scene/inspector | generated flat ground band plus gap forms | direct terrain polygon editing and read-only expanded prefab shapes |
| `prefab_runtime_adapter.dart` | maps prefab AABBs into chunk preview | maps polygon definitions and exact placement transforms |
| `generate_chunk_runtime_data.dart` | parses rectangles/flat ground and emits `StaticSolidRel`/`GapRel` | consumes current polygon source, compiles staged terrain data, and detects generated drift |
| `authored_chunk_patterns.dart` | production rectangle/gap pattern data | retain the bounded legacy projection required until Phase 5 while also generating staged terrain data |
| level assembly definitions | select chunks from tiers/groups/runs | provide the real allowed-adjacency set for seam validation |

Before editing, repeat this inventory and add any new authoring field, route,
adapter, generator output, or runtime consumer introduced after July 28, 2026.

## 5) Staging And Compatibility Boundary

- [ ] Keep normal `GameCore`, `TrackStreamer`, replay validation, and board
      issuance on the accepted legacy production authority throughout Phase 4.
- [ ] Cut repository source to polygon schemas in one migration; do not leave
      normal editor writes capable of emitting both rectangles and polygons.
- [ ] Keep legacy v1/v2 prefab and v1 chunk parsing inside the offline
      migration tool only after committed source is migrated.
- [ ] Remove rectangle/ground-gap commands and forms from normal editor paths
      in the same change that installs polygon replacements.
- [ ] Generate a clearly named staged terrain artifact/API that normal runtime
      construction cannot select accidentally.
- [ ] Retain only the bounded legacy generated projection needed by the
      existing production runtime until Phase 5 replaces streaming.
- [ ] Reject non-orthogonal production content if it cannot be represented by
      that temporary projection; interactive slope acceptance uses a fixture
      workspace or non-runtime-selected fixture content until Phase 5 consumes
      staged terrain.
- [ ] Record the exact staged artifact and legacy projection removal points in
      the Phase 5/6 checklists.
- [ ] Add a construction test proving normal levels still select legacy world
      motion after generation changes.

This temporary generated bridge is not a per-level runtime switch. There is
one unchanged production authority and one unreachable staged terrain artifact.

## 6) Implementation Order

Implement in dependency order:

1. capture baseline schema/generator/editor behavior and migration audit
2. introduce shared half-pixel polygon source values and diagnostics
3. implement canonicalization, exact predicates, and Core compiler adapter
4. add strict prefab v3 and chunk v2 models/codecs/validation
5. implement dry-run migration plan/report and golden it
6. add shared polygon interaction state and scene rendering
7. migrate Prefab Creator and its plugin/store path
8. migrate Chunk Creator, expanded prefab preview, and seam diagnostics
9. extend generator, staged terrain output, and legacy compatibility projection
10. write migrated source only after all read-only gates pass
11. remove normal rectangle/flat-gap source paths and stale UI/tests
12. close parity, determinism, capacity, interaction performance, docs, and
    findings

Do not write source during steps 1-9. Migration `--write` is enabled only after
the complete read-only report, round-trip, parity, and generator tests pass.

## 7) Baseline And Reproducibility Evidence

- [x] Record starting revision, dirty flag, OS, Dart/Flutter versions, and
      editor/root lockfile state.
- [x] Record current source schema versions: prefab v2 and chunk v1.
- [x] Record current source counts and canonical file hashes.
- [x] Reproduce the Phase 0 audit:
  - [x] 70 collision-bearing prefabs
  - [x] 88 migrated simple prefab polygons
  - [x] 29 decoration prefabs unchanged
  - [x] 29 multi-rectangle prefabs
  - [x] 31 collision-bearing chunk placements / 32 expanded polygon instances
  - [x] 8 flat ground profiles / 9 finite ground polygons including the gap
  - [x] zero current holes, point-only ambiguities, invalid half pixels, or
        limit blockers
- [x] Record current prefab/chunk no-op save output and pending-diff behavior.
- [x] Record current rectangle overlay, ground profile, and gap editor controls
      targeted for removal.
- [x] Run editor analysis and full tests.
- [x] Run root generator `--dry-run` and record generated-file hashes.
- [x] Run Core package analysis/tests, root Core tests, and replay-validator
      analysis/tests before changing cross-package generation.
- [x] Confirm normal game/replay construction is legacy before Phase 4 work.

All baseline commands and counts go in the validation ledger in §28. Existing
unrelated dirty-worktree changes must remain untouched.

## 8) Shared Polygon Source Values

Introduce one reusable pure-Dart geometry model consumed by prefab/chunk
editor state and thin Core adapters:

- [x] `TerrainSourceVertexDef` stores `xHalfPixels` and `yHalfPixels` as `int`.
- [x] `TerrainSourceShapeDef` stores stable `shapeId`, ordered vertices,
      collision mode, optional `surfaceKind`, and optional `materialKey`.
- [x] JSON codecs accept only finite numbers exactly divisible by `0.5`.
- [x] JSON codecs render whole pixels as integers and half pixels with one
      `.5`; never emit `-0`, exponent notation, or imprecise decimals.
- [x] Shape IDs use the existing stable identifier convention and are unique
      case-sensitively and case-insensitively inside their owner.
- [x] Shape lists serialize in stable `shapeId` order.
- [x] Vertex order remains geometrically ordered; vertices are never sorted as
      an unordered list.
- [x] Equality/pending-diff logic compares exact integers and metadata.
- [x] Models remain independent of Flutter widgets and filesystem writes.
- [ ] Prefab and chunk domains compose this model rather than copying it.

Prefer placing these values in a small shared editor domain folder and using
Core's existing `TerrainPolygonInput` through an adapter. Do not create a new
generic geometry framework or duplicate the accepted terrain compiler.

## 9) Canonicalization And Exact Predicates

- [x] Keep authoritative geometry predicates in Core. Expose a narrow
      pure-Dart validation/normalization result where the accepted compiler's
      current private helpers are needed by editor quick fixes.
- [ ] Limit editor-owned preflight to schema/identity/draft-state checks and
      translate Core geometry diagnostics instead of reimplementing them.
- [x] Implement signed doubled area entirely in integer half-pixel space.
- [x] Enforce clockwise winding in Y-down coordinates.
- [x] Rotate the loop to the lexicographically smallest complete cyclic
      sequence.
- [x] Reject a repeated closing vertex and consecutive duplicates.
- [x] Reject fewer than three distinct vertices and zero area.
- [x] Reject edges shorter than two half-pixel ticks (`1 px`).
- [x] Reject area smaller than four half-pixel square units (`1 px²`).
- [x] Detect non-adjacent edge intersection, collinear overlap, and point-only
      self-contact exactly.
- [x] Detect positive-area shape overlap while permitting exact shared
      boundaries.
- [x] Treat collinear middle vertices as a normalization diagnostic.
- [ ] Provide an explicit undoable Normalize action that can remove collinear
      middle vertices.
- [ ] Never remove vertices silently during load or save.
- [ ] New/edit commits may rotate/reverse an otherwise unchanged valid loop to
      canonical winding/start, but load-time noncanonical source must surface a
      stable quick-fix diagnostic rather than rewrite on export.
- [x] Sort diagnostics by source path, shape ID, edge/vertex index, then code.

Test every predicate with negative coordinates, half pixels, shared endpoints,
shared full edges, concave loops, reversed/rotated loops, and near-limit values.

## 10) Prefab Schema V3

The v3 source shape is:

```json
{
  "schemaVersion": 3,
  "prefabs": [
    {
      "prefabKey": "stable_key",
      "id": "display_id",
      "revision": 1,
      "collisionShapes": [
        {
          "shapeId": "collision_001",
          "collisionMode": "solid",
          "vertices": [
            {"x": -16, "y": -8},
            {"x": 16, "y": -8},
            {"x": 16, "y": 8},
            {"x": -16, "y": 8}
          ]
        }
      ]
    }
  ]
}
```

- [ ] Add prefab schema v3 and make canonical writes target v3.
- [ ] Replace `PrefabDef.colliders` with `collisionShapes` in normal models.
- [ ] Keep coordinates relative to the existing prefab anchor.
- [ ] Preserve prefab key, human ID, status, kind, visual source, anchor, tags,
      and revision semantics.
- [ ] Require at least one collision shape for colliding obstacle/platform
      contracts; decoration behavior stays unchanged.
- [ ] Require at least one shape to intersect resolved visual source bounds.
- [ ] Permit intentional extent outside visual bounds and report its exact
      amount without clipping.
- [ ] Update deterministic comparison, pending diff, duplicate/rename,
      deprecate, and runtime-preview adapters.
- [ ] Bump a prefab revision only when its canonical collision source or other
      existing revision-owned source changes.
- [ ] Do not bump revision for schema representation alone when occupied
      collision source is exactly equivalent.
- [ ] After committed migration, normal `PrefabStore` rejects v1/v2 source with
      an actionable `migration_required` issue rather than silently converting.

## 11) Chunk Schema V2

Chunk v2 replaces `groundProfile` and `groundGaps` with direct chunk-local
`collisionShapes` while retaining normal prefab placements:

```json
{
  "schemaVersion": 2,
  "chunkKey": "forest_early_00",
  "revision": 1,
  "width": 600,
  "height": 270,
  "collisionShapes": [
    {
      "shapeId": "ground_001",
      "collisionMode": "solid",
      "vertices": [
        {"x": 0, "y": 224},
        {"x": 600, "y": 224},
        {"x": 600, "y": 270},
        {"x": 0, "y": 270}
      ]
    }
  ]
}
```

- [ ] Add chunk schema v2 and make canonical writes target v2.
- [ ] Remove `GroundProfileDef` and `GroundGapDef` from normal v2 models.
- [ ] Remove ground-profile/gap plugin commands, inspector forms, and tests once
      polygon replacements cover them.
- [ ] Add chunk-local `collisionShapes` with stable IDs.
- [ ] Preserve chunk key, ID, revision, status, level, tile/grid metadata,
      assembly group, tags, visual layers, prefab placements, and markers.
- [ ] Retain `groundBandZIndex` only as visual composition metadata until
      Phase 5 replaces the ground rendering path.
- [ ] Do not force direct polygons to `runtimeGroundTopY`; that field remains a
      legacy level/default bridge only.
- [ ] Require every direct and transformed prefab vertex to stay inside closed
      chunk bounds after the one quantization step.
- [ ] Do not permit per-placement collision-shape overrides.
- [ ] Bump chunk revision only when chunk-owned canonical source changes;
      changing a referenced prefab bumps the prefab revision/output, not every
      referencing chunk source revision.
- [ ] After committed migration, normal `ChunkStore` rejects v1 source with an
      actionable migration issue.

## 12) Placement Transform And Quantization

- [x] Add one small pure-Dart Core-owned placement-transform primitive under
      `collision/terrain`; it accepts integer half-pixel vertices, reflection,
      exact scale numerator/denominator, translation, and emits physics ticks.
- [x] Keep JSON parsing, editor selection, and UI state outside that Core
      primitive.
- [ ] Make both editor preview and root generation call the same primitive.
- [x] Convert source half-pixel ticks relative to the prefab anchor.
- [x] Apply `flipX` and `flipY` before scale.
- [x] Represent the existing `0.3-3.0`, `0.1`-step uniform scale as an exact
      integer rational, not binary floating-point identity.
- [x] Reject authored scale outside bounds or off the `0.1` step.
- [x] Apply placement translation after uniform scale.
- [x] Quantize once to `1/1024` world-unit physics ticks using the accepted Core
      rounding rule.
- [x] Recanonicalize transformed winding/start after an odd reflection.
- [x] Preserve local shape/vertex lineage through placement and compilation.
- [x] Prove flip/scale/translation order with asymmetric half-pixel fixtures.
- [ ] Prove identical transformed ticks across editor preview, generator, Core,
      Windows/Linux, JIT/AOT, and fresh processes.
- [x] Treat a post-transform degenerate/short edge as blocking, even when the
      untransformed source was valid.

One function/adapter owns this transform. The Chunk scene, validation,
migration report, and generator must not each reimplement it.

## 13) Validation And Diagnostic Contract

Every issue contains severity, stable code, source path, owner key, shape ID,
optional vertex/edge index, and an actionable message.

Blocking categories:

- [ ] malformed schema/value/enum/half-pixel coordinate
- [ ] missing/duplicate/case-colliding shape ID
- [ ] repeated closing or consecutive duplicate vertex
- [ ] noncanonical winding/start requiring explicit repair
- [ ] too few distinct vertices, zero/small area, or short edge
- [ ] self-intersection, self-touch ambiguity, or collinear edge overlap
- [ ] positive-area overlap between shapes
- [ ] unsupported hole/disconnected loop in one shape
- [ ] prefab visual-source intersection contract failure
- [ ] post-transform degeneracy or chunk-bounds overflow
- [ ] unknown prefab/revision/source reference
- [ ] owner shape/vertex/expanded-edge limit overflow
- [ ] Core compiler error or source/compiled signature mismatch
- [ ] scheduler-reachable seam incompatibility
- [ ] generated output drift in validation mode

Non-blocking categories:

- [ ] intentional collision extent beyond visual bounds
- [ ] collinear middle vertex with explicit Normalize quick fix
- [ ] optional metadata absent
- [ ] material reference deferred until the Phase 5 material catalog exists
- [ ] content near a soft capacity/performance target

Do not downgrade geometry or seam correctness to a warning to make migration
pass. Do not truncate shapes, vertices, edges, or diagnostics at a hard limit.

## 14) Core Compiler Adapter And Preview Authority

- [x] Add a local path dependency from the editor to pure-Dart `runner_core` or
      another existing non-cyclic access path; Core must not depend on editor.
- [x] Adapt valid source shapes to `TerrainPolygonInput` with exact identity and
      integer coordinates.
- [ ] Use `TerrainCompiler` for normalization/edge exposure diagnostics in
      preview and final validation.
- [ ] Put deterministic triangulation in the same pure-Dart Core geometry
      boundary (or another already-shared pure-Dart boundary) so editor,
      generator, and later renderer data cannot drift.
- [ ] Do not copy compiler seam cancellation, outward-normal, adjacency, or
      edge-order logic into editor widgets.
- [ ] Keep cheap source-shape diagnostics available while a draft is invalid;
      invoke the full compiler only on a valid/debounced snapshot or gesture
      commit.
- [ ] Render preview fills from source loops and collision/debug edges from the
      compiler result; never derive collision back from render triangles.
- [ ] Display exact edge IDs, tangent/normal, slope angle, collision mode,
      source lineage, and compiler diagnostic on selection.
- [ ] Optionally display accepted Éloïse/Grojib/Hashash/Derf eligibility using
      existing Core profiles; the editor must not define new thresholds.
- [ ] Build any surface/graph overlay with the accepted Phase 3 extractor and
      profile graph builders; never infer navigation from visual polygon fill.
- [ ] Keep all preview state read-only with respect to Core/runtime objects.

## 15) Deterministic Migration Tool

Add a dedicated offline command with explicit modes, for example:

```powershell
dart run tool/migrate_polygon_authoring.dart --check `
  --report=.tmp/slopes-phase4-migration.json
dart run tool/migrate_polygon_authoring.dart --write `
  --report=.tmp/slopes-phase4-migration.json
```

- [ ] Default to read-only `--check`; never infer write from a missing flag.
- [ ] Reject unknown flags and dirty source drift discovered after planning.
- [ ] Parse legacy prefab v1/v2 and chunk v1 strictly.
- [x] Convert one isolated AABB to four exact clockwise vertices.
- [x] Union touching/overlapping AABBs with deterministic integer orthogonal
      geometry, removing every interior edge.
- [x] Emit multiple loops for disconnected union components.
- [x] Block holes, point-only ambiguity, invalid half pixels, overflow, or
      unsupported topology.
- [x] Derive `collision_001...` IDs from canonical component order and preserve
      them on repeated runs.
- [ ] Convert flat chunk ground into finite `[0,width] x [topY,height]`
      coverage minus pit intervals.
- [ ] Derive `ground_001...` IDs left-to-right/canonical order.
- [x] Preserve occupied area exactly before placement quantization.
- [ ] Preserve stable prefab/chunk keys and human IDs.
- [ ] Keep revisions unchanged for representation-only equivalent migration.
- [ ] Emit sorted automatic conversion, union, disconnected component,
      blocker, revision, and generated-impact records.
- [ ] Include before/after canonical source signatures and occupied-area facts.
- [ ] Make `--check` exit nonzero for blockers or source already differing from
      the planned canonical output.
- [ ] Make `--write` require a complete blocker-free plan generated from the
      same source fingerprints.

## 16) Migration Write Transaction And Recovery

- [ ] Build and validate every target file in memory before the first write.
- [ ] Show the exact multi-file save plan and source fingerprints.
- [ ] Stage temporary files on the same volume.
- [ ] Recheck every source fingerprint immediately before replacement.
- [ ] Preserve existing newline/encoding policy and canonical JSON formatting.
- [ ] Replace files through the repository's safe-write primitives.
- [ ] If any replacement fails, restore every already-replaced source from the
      transaction backup and report the failure.
- [ ] Never leave mixed prefab/chunk schema versions after a failed batch.
- [ ] Write a machine-readable transaction/report artifact outside authored
      source; do not commit backup files.
- [ ] Re-running `--check` after success must report zero pending migrations.
- [ ] Re-running `--write` after success must be a no-op.

The normal editor export remains document-scoped and source-drift guarded. The
batch transaction exists only for the one-time schema migration.

## 17) Shared Polygon Interaction Model

Build shared non-widget command/state primitives under the editor's shared
scene/domain seams before wiring either route.

Required tools:

- [ ] select shape/vertex/edge
- [ ] create polygon by ordered vertex clicks
- [ ] close valid polygon explicitly; Escape cancels the draft
- [ ] move one vertex
- [ ] translate one complete shape
- [ ] insert a vertex on a selected edge
- [ ] delete a vertex when at least three valid vertices remain
- [ ] delete/duplicate a shape with deterministic unique ID allocation
- [ ] edit collision mode and optional metadata
- [ ] explicit Normalize quick fix

Interaction rules:

- [ ] preserve shared `Ctrl+drag` pan and `Ctrl+scroll` zoom behavior
- [ ] primary drag remains tool-driven
- [ ] expose a visible snap selector: owner grid or exact `0.5 px`
- [ ] never permit arbitrary non-half-pixel vertex values
- [ ] inspector numeric fields accept integer/`.5` text and display exact values
- [ ] one pointer gesture produces one undo entry, not one entry per event
- [ ] Escape restores the pre-gesture draft; commit runs validation once
- [ ] selection and viewport changes do not bump document revision
- [ ] a temporarily invalid drag can render local diagnostics, but export and
      gesture commit policy must never silently repair topology
- [ ] keyboard delete/undo/redo and focus behavior are tested
- [ ] scene semantics are shared between Prefab and Chunk routes

Multi-shape selection, boolean authoring operations, rotation, arbitrary scale,
curves, and holes are not required for the baseline tool.

## 18) Prefab Creator Polygon Workflow

- [ ] Replace rectangle overlay handles with the shared polygon interaction
      layer in obstacle and platform prefab workflows.
- [ ] Show visual source, anchor, all collision fills, edge modes, vertices,
      and selected-shape diagnostics in prefab-local coordinates.
- [ ] Keep atlas/platform-module image-size caches workspace-scoped.
- [ ] Preserve slice/module selection, prefab operations, tags, and status.
- [ ] Provide shape list ordering by stable ID and focus from diagnostics.
- [ ] Show exact collision extent beyond visual bounds without clipping.
- [ ] Keep page-local selection/tool/viewport drafts projected over the
      plugin-owned `PrefabData` document.
- [ ] Route every committed geometry edit through `PrefabDomainPlugin` and
      `PrefabStore`; no page-local JSON write path.
- [ ] Bump revision exactly once per committed semantic edit.
- [ ] Make a drag one pending semantic change even if it has many pointer
      updates.
- [ ] Preview downstream referencing chunks/placements affected by a prefab
      change without mutating those chunk source revisions.
- [ ] Keep decoration prefabs with no collision valid and unchanged.

## 19) Chunk Creator Polygon Workflow

- [ ] Replace flat ground profile/gap inspector sections with direct chunk
      collision-shape tools.
- [ ] Render chunk-local shapes as editable and resolved prefab shapes as
      read-only overlays with source prefab/placement lineage.
- [ ] Keep prefab instance transform editing at the placement level only.
- [ ] Provide an action to open the owning prefab workflow for shape edits
      instead of creating per-instance overrides.
- [ ] Preserve chunk create/duplicate/rename/deprecate, metadata, prefabs,
      markers, visual layers, level scope, and pending diff behavior.
- [ ] Preserve `groundBandZIndex` preview until Phase 5 replaces its renderer.
- [ ] Fill the visible ground preview from direct terrain polygons where
      possible; label it preview-only, not runtime collision authority.
- [ ] Show transformed/quantized coordinates and chunk-bound violations.
- [ ] Show source-shape and expanded-shape/edge capacity separately.
- [ ] Recompile only affected draft/placement data during interaction, then run
      full chunk validation on gesture commit/export.
- [ ] Route every semantic edit through `ChunkDomainPlugin` and `ChunkStore`.
- [ ] Preserve source-drift, case-insensitive filename collision, and atomic
      one-file-per-chunk save rules.

### 19.1 Placement And Navigation Authoring Diagnostics

- [ ] Overlay Éloïse, Grojib, and Hashash eligible surfaces and walk/jump/drop
      graph edges from accepted Core profiles.
- [ ] Overlay Unoco solid blockers/local-hover candidates without constructing
      a flight graph.
- [ ] Overlay Derf perch eligibility and the independent 32-pixel support span.
- [ ] Resolve existing ground/highest-surface/obstacle-top marker previews
      through the accepted Phase 3 placement query and actor/item policy.
- [ ] Preserve marker order, chance, salt, and source placement intent; preview
      must consume no RNG and mutate no marker.
- [ ] Distinguish an intentionally optional rejected spawn from malformed or
      impossible authored placement instead of treating every miss alike.
- [ ] Keep reachability/placement evidence advisory in Phase 4 unless it
      violates an already-blocking source contract. Phase 5 owns full
      streamed gameplay/content acceptance and may promote reviewed diagnostics.
- [ ] Record projectile terrain as the existing later-phase disposition; the
      editor must not imply ballistic terrain support is already delivered.

## 20) Scheduler-Aware Seam Validation

A seam is validated against the transitions the generated level scheduler can
actually produce, not directory order or an arbitrary editor neighbor.

- [ ] Derive canonical left/right boundary signatures from transformed,
      quantized, compiled chunk geometry.
- [ ] Include ordered boundary vertices/coverage intervals, collision mode, and
      geometry needed for physical edge cancellation/continuity.
- [ ] Treat a fully open boundary as an explicit empty signature.
- [ ] Enumerate every possible adjacent pair within a tier/group pool.
- [ ] Enumerate transitions at early/easy/normal/hard tier boundaries.
- [ ] Enumerate within-run and between-run transitions from authored level
      assembly schedules.
- [ ] Respect existing distinct-chunk/group eligibility without changing
      selection behavior.
- [ ] Validate both directions where the scheduler can emit both orders.
- [ ] Block mismatched physical coverage/vertices that would create an
      unintended seam wall, overlap, ledge, or hole.
- [ ] Report level ID, scheduler transition, left/right chunk keys, side,
      expected/actual signature, and exact mismatch coordinates.
- [ ] Keep render material-phase mismatch as Phase 5 evidence unless a current
      material key makes it unambiguous now.
- [ ] Show compatible candidate neighbors and failing pairs in Chunk Creator.
- [ ] Add a workspace/global validation path so a valid individual chunk cannot
      be exported while it breaks a reachable level transition.
- [ ] Golden the reachable adjacency set so validator/editor/generator cannot
      disagree about which seams matter.

Do not add new neighbor metadata or change procedural selection merely to make
an incompatible chunk pass. Any requested scheduling change is a separate
gameplay/content decision.

## 21) Generator Refactor And Staged Terrain Output

- [ ] Keep `tool/generate_chunk_runtime_data.dart` the single repository
      generation entry point.
- [ ] Refactor polygon parsing/transform/compile/render steps into focused
      testable pure-Dart files rather than growing the monolith further.
- [ ] Parse only current prefab v3/chunk v2 in normal generation.
- [ ] Expand prefab placements with stable placement/source lineage.
- [ ] Validate all direct/expanded shapes and scheduler seams before rendering
      any output.
- [ ] Feed exact quantized polygons through the accepted Core compiler.
- [ ] Generate normalized local polygon loops and precompiled exposed local
      edges with collision/render metadata.
- [ ] Deterministically triangulate each normalized simple polygon during
      generation, never independently inside Flame.
- [ ] Use exact integer orientation/containment predicates and a stable ear
      tie-break based on canonical vertex index.
- [ ] Require exactly `vertexCount - 2` non-degenerate triangles whose signed
      area sum equals the source polygon exactly.
- [ ] Store triangle indices into the same normalized polygon loop used by
      collision/source signatures.
- [ ] Generate source identity lineage: chunk key, placement key when present,
      prefab key/revision, shape ID, and local edge identity.
- [ ] Preserve runtime chunk index/version binding for Phase 5; do not bake a
      fake streamed chunk index into authoring identities.
- [ ] If the accepted Core compiler requires an instance chunk index during
      local preview, use a reserved internal value, strip it from generated
      local records, and assert it is never serialized as runtime identity.
- [ ] Include deterministic compiler/signature format versions.
- [ ] Generate collision and render inputs from the same normalized source in
      one pass.
- [ ] Never rebuild collision edges from render triangles.
- [ ] Keep generated data generated; no hand edits.
- [ ] Sort all maps/lists explicitly before Dart rendering.
- [ ] Keep generated numeric output integer/fixed rational where authoritative.
- [ ] Produce the bounded legacy rectangle/gap projection only for migrated
      orthogonal production content until Phase 5 removes that need.
- [ ] Deterministically decompose orthogonal solid polygon unions into
      non-overlapping canonical rectangles without changing occupied area.
- [ ] Derive legacy flat ground/gaps only when the direct chunk coverage has the
      exact flat representable form.
- [ ] Prove the projected legacy geometry and current normal-run outcomes match
      the pre-migration baseline; internal decomposition seams must not become
      observable contacts.
- [ ] Reject runtime-selected diagonal or one-way content that the legacy
      authority cannot express exactly.
- [ ] Fail rather than approximate a slope into rectangles.
- [ ] Make `--dry-run` render every output in memory and compare it byte-for-byte
      with committed generated files after validation.
- [ ] Report sorted missing/stale/unexpected output files and exit nonzero on
      drift.

The staged terrain output should use a narrowly named API/file that cannot be
mistaken for the current `ChunkPattern` production source.

## 22) Authoring/Runtime Parity Fixtures

Create small checked-in fixtures that cover:

- [ ] one prefab-local rectangle migrated to a polygon
- [ ] concave union of overlapping/touching rectangles
- [ ] disconnected union components and derived IDs
- [ ] direct chunk slope and flat-to-slope seam
- [ ] pit/open boundary and finite ground coverage
- [ ] solid and one-way shapes
- [ ] optional surface/material metadata
- [ ] half-pixel coordinates
- [ ] asymmetric X/Y reflection
- [ ] minimum/maximum rational placement scale
- [ ] internal shared-edge cancellation
- [ ] cross-shape exact shared boundary
- [ ] allowed cross-chunk seam pair
- [ ] every major blocking diagnostic

For each valid fixture, compare:

1. canonical source JSON/records
2. editor model round trip
3. editor Core-preview adapter
4. generator transformed polygons
5. generated local polygon/edge/triangle records
6. direct Core compiler polygon/edge signatures

All six must agree on exact integers, IDs, ordering, modes, metadata,
diagnostics, and signatures.

## 23) Determinism And Golden Signatures

- [ ] Add `authoring-polygons-v1` for canonical owner/shape/vertex/metadata
      records.
- [ ] Add `authoring-placement-v1` for exact transformed/quantized placement
      records.
- [ ] Reuse accepted Core `source-v1`/`edges-v1` signatures for compiled facts.
- [ ] Add `authoring-seams-v1` for sorted reachable adjacency/signature records.
- [ ] Add `authoring-migration-v1` for the sorted migration report.
- [ ] Add `authoring-triangles-v1` for polygon IDs and deterministic triangle
      index triples.
- [ ] Rebuild signatures from fresh objects and fresh Dart processes.
- [ ] Reverse input file/map/shape order and prove canonical equality.
- [ ] Rotate/reverse equivalent valid loops and prove explicit normalization
      reaches the same signature.
- [ ] Mutate one coordinate, mode, metadata field, placement transform,
      reachable seam, or source identity and prove the relevant digest changes.
- [ ] Prove Windows/Linux path normalization cannot change source-path ordering.
- [ ] Never update a reviewed golden merely to hide nondeterminism or semantic
      drift; record the cause in §26 first.

## 24) Interaction Performance And Capacity

Representative editor fixture:

- one 600 x 270 chunk
- 16 direct polygons with up to 24 vertices each
- resolved prefab placements sufficient to reach 256 exposed edges
- neighbor/seam preview candidates from its actual level assembly group
- source image/ground preview enabled
- validation and compiled-edge overlays enabled

Hard authoring fixtures:

- 64 shapes per prefab
- 64 vertices in one shape
- 512 direct/expanded shapes per chunk
- 4,096 exposed compiled edges per chunk
- invalid fixtures one unit over every hard limit

Frozen gates:

- [ ] vertex/shape drag update p95 `<=8 ms`
- [ ] drag update p99 `<=16.67 ms`
- [ ] no missed-input burst in the profile interaction trace
- [ ] no full repository reload or full generator run per pointer event
- [ ] no source model allocation proportional to total workspace per drag
- [ ] no interaction-time query/diagnostic truncation
- [ ] hard-limit fixtures validate deterministically without hanging
- [ ] one-unit-over fixtures fail with the expected stable diagnostic
- [ ] no-op save/migration/generation remains byte/signature deterministic

Use the frozen profile-mode Windows command:

```powershell
Push-Location tools/editor
flutter drive --profile `
  --driver=test_driver/integration_test.dart `
  --target=integration_test/polygon_interaction_benchmark_test.dart `
  -d windows
Pop-Location
```

The JSON report records revision, dirty flag, OS/runtime, fixture/signatures,
warmup, samples, p50/p95/p99/max, missed-input count, affected shape/edge
counts, allocation/buffer evidence where available, and every gate result.

## 25) Required Test Matrix

Models/codecs:

- [x] exact integer/half-pixel JSON parsing/rendering
- [x] malformed/nonfinite/off-grid numeric rejection
- [ ] schema version and legacy migration-required behavior
- [x] stable shape IDs/list order/equality/copy behavior
- [x] canonical winding/start and explicit normalization

Geometry/compiler:

- [ ] simple/concave polygons and every invalid topology class
- [x] shared boundaries versus positive-area overlap
- [ ] minimum edge/area and hard limits
- [ ] transform order, reflection, rational scale, quantization
- [ ] Core preview/generator signature parity

Migration:

- [x] isolated/multi/overlapping/touching/disconnected rectangles
- [x] hole and point-only ambiguity blockers
- [ ] flat ground with zero/one/multiple gaps
- [ ] exact corrected audit counts and zero unclassified blockers (pending the
      explicit resolution of the three minimum-edge blockers in §26)
- [ ] stable report/order/IDs/revisions across repeated checks
- [ ] write transaction, source-drift abort, rollback, and idempotence

Stores/plugins:

- [ ] load/validate/edit/pending diff/export for prefab v3 and chunk v2
- [ ] atomic paired prefab/tile writes and one-file chunk writes
- [ ] route/session/workspace switching with polygon draft state
- [ ] create/duplicate/rename/deprecate revision semantics
- [ ] downstream prefab impact preview without chunk mutation
- [ ] invalid/global-seam issue export gating

UI/interactions:

- [ ] create/close/cancel polygon
- [ ] shape/edge/vertex selection
- [ ] drag vertex/shape with grid and half-pixel snap
- [ ] insert/delete/duplicate/normalize
- [ ] one undo entry per gesture and deterministic redo
- [ ] diagnostics focus the exact shape/vertex/edge
- [ ] shared scene control parity on Prefab and Chunk routes
- [ ] read-only expanded prefab overlay in Chunk Creator
- [ ] Core-owned actor eligibility/navigation and marker-placement overlays
- [ ] preview consumes no marker RNG and preserves source ordering
- [ ] accessibility labels, keyboard controls, and narrow-window behavior

Generator/seams:

- [ ] current-schema strict parsing
- [ ] unknown prefab/source/scale/bounds diagnostics
- [ ] staged polygon/edge/lineage output golden
- [ ] concave triangulation count, winding, exact area, ordering, and golden
- [ ] legacy orthogonal decomposition, flat-ground/gap projection, baseline
      collision parity, and diagonal/one-way rejection
- [ ] all scheduler-reachable within/between pool/run transitions
- [ ] dry-run generated drift/missing/unexpected output detection
- [ ] fresh-process signatures and permutation invariance

Regression:

- [ ] all existing editor domains and route/session tests
- [ ] full Core package and root Core tests
- [ ] normal legacy game construction and current run goldens unchanged
- [ ] replay-validator analysis/tests unchanged

## 26) Implementation Findings

Record every discovered contract mismatch or non-obvious design consequence
before changing the accepted plan.

| Finding | Resolution | Later-phase impact |
| --- | --- | --- |
| Current chunk selection draws from tier/group pools and authored runs, so file adjacency does not describe runtime adjacency. | Seam validation enumerates the scheduler's actual possible pair set. | Phase 5 can stitch only combinations already proven compatible without changing procedural pacing. |
| Prefab geometry changes can affect many chunks while those chunk JSON records remain untouched. | Pending changes report downstream placement/output impact, but only the prefab revision/source changes. | Phase 5 runtime identities must include referenced prefab revision/signature without forcing mass chunk revision churn. |
| Existing placement scales are decimal tenths; multiplying half-pixel source coordinates with binary doubles would make identity platform-sensitive. | Parse scale into an exact integer rational and quantize once after reflection/scale/translation. The initial editor-to-Core source adapter remains identity-transform-only until that primitive replaces the current double transform. | Generated world geometry and validator replay receive the same physics ticks on every platform. |
| Source-point construction multiplied an unchecked authored tick by the source-to-physics factor before range validation, so native integer overflow could occur before rejection. | Validate against an explicit source-tick limit before conversion and use overflow-safe comparison bounds. Promote exact authoring/compiler area, orientation, overlap, and line-key products to `BigInt`; keep this work outside per-tick contact. | Migration and editor validation can safely exercise the accepted coordinate limits without platform-dependent wraparound. |
| Phase 4 must stage polygon data while production still reads rectangles. | Source cuts over once; generation emits an unreachable staged terrain artifact and a bounded exact legacy projection for orthogonal current content. | Phase 5 removes the projection when streaming consumes staged terrain; no runtime toggle is introduced. |
| Phase 3 moved enemy AABBs into top-level constants so legacy collision and staged capsules share one definition, but the entity editor only parsed inline collider expressions. | Resolve a directly referenced top-level `ColliderAabbDef` initializer and bind edits to that initializer; keep unresolved/indirect shapes non-writable. | Enemy authoring remains operational through the Phase 4 source migration without duplicating capsule/AABB dimensions. |
| The earlier Phase 0 topology audit did not run the accepted one-world-unit minimum-edge predicate. Exact Core revalidation finds `0.5 px` exterior edges in `dark_menhir_01`, `dark_menhir_03`, and `ruin_stone_00`; 67/70 collision prefabs and 85/88 candidate loops pass unchanged. | Keep the migration planner blocking and preserve exact occupied area; do not relax the global rule or rewrite the three records without an explicit content decision. | Prefab v3 write/cutover remains blocked for those three records; production source and legacy runtime behavior are unchanged. |

Append rows during implementation. Do not silently relax source, compiler,
seam, determinism, or performance contracts.

## 27) Documentation

During implementation:

- [x] document the delivered pre-schema source/canonicalization/overlap/exact
      placement boundary in `docs/tdd/polygon_terrain_authoring_foundation.md`
- [ ] create a focused TDD for source schema ownership, transform order,
      migration, generation, identity lineage, diagnostics, and staging
- [ ] update `docs/tdd/sloped_navigation_and_enemy_terrain.md` only for the
      delivered generated-data boundary, not production cutover claims
- [ ] update `tools/editor/README.md` with the user-visible polygon workflow,
      controls, validation, migration prerequisite, and limitations
- [ ] update `docs/building/editor/chunkCreator/plan.md` and relevant open
      checklist status where ground/gap/collider authoring is replaced
- [ ] update root/editor/Core `AGENTS.md` only if actual ownership or working
      rules change
- [ ] keep Phase 5 streaming/rendering and Phase 6 direct cutover work in their
      future building checklists
- [ ] update schema examples and generator commands after names are final
- [ ] document every temporary staged/legacy artifact and exact removal phase

No player-facing GDD update is required for a behavior-preserving authoring
phase unless implementation discovers and accepts a gameplay/content rule.

## 28) Validation Ledger And Final Commands

Record each milestone with date/revision, commands, environment, counts, and
result.

| Date / revision | Scope | Environment | Result |
| --- | --- | --- | --- |
| 2026-07-28 / `85b5b902342d94589e1b101b76b1ffdf2144405e` | Phase 4 baseline and entity-editor seam repair | Windows NT 10.0.26200.0; Dart 3.11.5; Flutter 3.41.7 stable | Baseline reproduced; editor analysis clean; 180 full editor tests plus 2 no-op characterization tests pass; generator dry-run and 17 generator tests pass. Same-revision Phase 3 evidence supplies 291 Core package tests, 432 root Core tests, and 78 validator tests. |
| 2026-07-28 / same working revision | Shared exact polygon-source values | Dart VM on Windows | Focused analysis clean; 10/10 model/codec/order/equality tests pass. No prefab/chunk schema or authored JSON changed. |
| 2026-07-29 / `c182a277` | Core-owned exact source canonicalization seam | Dart VM on Windows | Core analysis clean; 13 focused compiler/canonicalizer tests and all 297 Core package tests pass. Existing geometry/signature goldens are unchanged; no runtime authority or replay contract changed. |
| 2026-07-29 / `35ea2d08` | Editor-to-Core polygon source adapter | Flutter test VM on Windows | Editor analysis clean; all 197 editor tests pass, including 4 adapter tests and 10 source-model tests. The dependency is one-way, conversion preserves exact identity/integer coordinates, and placement transforms remain pending §12. |
| 2026-07-29 / `0ee1b750` | Source-coordinate overflow guard | Dart VM on Windows | Focused analysis clean and all 6 terrain numeric tests pass. Maximum accepted source ticks convert exactly; one-unit-over and overflow-sized values reject before multiplication. |
| 2026-07-29 / `a048ff44` | Exact cross-shape occupied-area overlap | Dart VM and Flutter test VM on Windows | Core analysis clean; 26 focused numeric/canonicalization/overlap/compiler tests and all 304 Core package tests pass. Shared edges and points remain legal, concave/contained/crossing/near-limit overlap is exact, existing geometry/signature goldens are unchanged, and the editor adapter's 4 tests still pass. |
| 2026-07-29 / `2e40d351` | Exact Core placement transform | Dart VM on Windows | Core analysis clean and all 308 Core package tests pass. Anchor/reflection/rational scale/translation/one quantization order, half-away rounding, scale bounds/steps, and post-transform edge rejection are covered; existing geometry/signature goldens are unchanged. |
| 2026-07-29 / `0e8b0f90` | Editor exact-placement adapter | Flutter test VM on Windows | Editor analysis clean and all 199 editor tests pass, including 6 source/Core adapter tests. The editor bridge accepts integer half-pixel anchor/translation and integer scale tenths; prefab/chunk UI and JSON remain unchanged. |
| 2026-07-29 / `668cf375` | Read-only legacy prefab collider union planner | Flutter test VM on Windows | Editor analysis clean; 8 focused planner tests and all 207 editor tests pass. Exact Core revalidation accepts 67/70 collision prefabs and 85/88 candidate loops; three minimum-edge blockers are reported without source, schema, or runtime writes. |

### 28.1 Baseline Environment And Source Identity

- Starting worktree: dirty with 133 pre-existing entries. The authoring JSON,
  five generated outputs, and both lockfiles listed below were clean. Phase 4
  work does not own or alter the unrelated entries.
- Root `pubspec.lock` SHA-256:
  `960E659DC06AF51944155D2F8495E505CE91E7D060D9E011A1B90494223F925A`.
- Editor `pubspec.lock` SHA-256:
  `84BBD3E72A8F7A9DEAB3A5C65F5C44630816A4F25C60C1708DF62ADB727A67B2`.
- Source schemas: `prefab_defs.json` v2; all 8 chunk files v1.
- Source inventory: 99 prefabs, 70 collision-bearing prefabs, 29
  decoration-only prefabs, 50 chunk placements, 8 flat ground profiles, and 1
  ground gap.

| Authoring source | SHA-256 |
| --- | --- |
| `assets/authoring/level/prefab_defs.json` | `EA578E38E66073A380E747936A225518E0EB2A135023625A366553B6097BD14D` |
| `chunks/field/field_flat.json` | `FB871B50B8B7C0348ADAD539F2C463EFAA2535400E413D8779A2630C39F8AFBC` |
| `chunks/forest/forest_early_00.json` | `27815E0D8ECE34689ECE51DBE06A66DFFA2BC49A16047DFA57E5767AF5EC4FB3` |
| `chunks/forest/forest_early_01.json` | `A7F3DBDDE448F82E32D61E0F5DC9444AF749DEC436F3222FA1A221CB0FAEA389` |
| `chunks/forest/forest_early_02.json` | `042A490F6256275EF26880CF13ED068F9B655F05E26D6D38DE434154E93DAEE9` |
| `chunks/forest/forest_early_03.json` | `1FCCE0D09600C0D90DD176A470C3D9A096777675564F642C6286B57DA34E59CB` |
| `chunks/forest/forest_early_flat.json` | `45AF8DAF2DE734D4A3CDCE46D8EDE9DD1DA74CFD0CD6E9D3C9FAAEC076548F18` |
| `chunks/forest/forest_easy_woodcamp_00.json` | `9D882CFF8311F4D5A14347F2EA4B59486741BEBB70AD40CBCD5B4E3215040016` |
| `chunks/forest/forest_normal_woodcamp_00.json` | `A5A6B0DC37EF4A88EAC2AA09B32EF9B42DB636EF7662F48BD61027C779089E37` |

### 28.2 Reproduced Migration Audit

The initial read-only coordinate-compressed union audit converted rectangle
bounds to integer half-pixel ticks, flood-filled positive-area components,
inspected unoccupied components for holes, detected diagonal point contacts,
and counted canonical boundary turns. It reproduced the topology-only
candidate inventory:

- 70 collision-bearing prefabs -> 88 simple polygons; 29 decorations remain
  collider-free and 29 collision prefabs contain multiple rectangles
- 31 collision-bearing placements -> 32 placed polygon instances
- 8 flat profiles plus one pit gap -> 9 finite ground polygons
- 60 collision prefabs require half-pixel-exact bounds because at least one
  rectangle dimension is odd
- 0 invalid legacy collider numbers, holes, or point-only contacts
- maximum 3 polygon components per prefab and 14 vertices per polygon, below
  Core's limits of 64 shapes per prefab and 64 vertices per shape

Phase 4's implemented planner additionally runs every loop through the accepted
exact Core canonicalizer. That revalidation accepts 67/70 collision prefabs and
85/88 candidate loops. It blocks `dark_menhir_01`, `dark_menhir_03`, and
`ruin_stone_00` because each has a one-source-tick (`0.5 px`) exterior edge,
below Core's one-world-unit minimum. The earlier zero-blocker conclusion was
therefore incomplete rather than a different topology result. No authored
source or runtime data has been changed.

### 28.3 No-op And Removal Baseline

`phase4_authoring_baseline_test.dart` proves that current repo source loads
canonically in both plugins. `describePendingChanges` returns
`PendingChanges.empty`; no-op export returns `applied: false` and exactly one
summary artifact reporting `changedFiles: 0` / `changedChunks: 0`. Neither path
writes the repository.

Legacy controls recorded for replacement are:

- Prefab rectangle state/forms in `prefab_form_state.dart`, obstacle/platform
  tabs and output panels, plus coordinator add/duplicate/delete mutations
- rectangle handle hit-testing, dragging, and painting in
  `prefab_overlay_interaction.dart`, `prefab_scene_view.dart`, and the platform
  module scene; the Chunk scene also renders this rectangle overlay
- Chunk Creator's Ground Profile and Ground Gaps expansion panels in
  `chunk_creator_page.dart`, its ground painter in `chunk_scene_ground.dart`,
  and `update_ground_profile` / `add_ground_gap` / `update_ground_gap` /
  `remove_ground_gap` commands in `chunk_domain_plugin.dart`

### 28.4 Generated Output And Validation Baseline

`dart run tool/generate_chunk_runtime_data.dart --dry-run` validates 8 chunks,
2 levels, and 2 parallax themes without blocking issues. Hashes before and
after the dry-run are identical:

| Generated output | SHA-256 |
| --- | --- |
| `packages/runner_core/lib/track/authored_chunk_patterns.dart` | `F6E48C33DFE145898F52C480BA24720CE56192E8F97E4C426CF8D430B2D15155` |
| `packages/runner_core/lib/levels/level_id.dart` | `602A54FC0341EC8E2E656AF90CDFC6B58B65614055BF1F141EDE5EC700044DE2` |
| `packages/runner_core/lib/levels/level_registry.dart` | `EF241B3CAC47600072B7DC0ACCD0C2E266DA12934D7E12C2510D8F5D027A1772` |
| `lib/ui/levels/generated_level_ui_metadata.dart` | `349B71A76746658280B3937F2D1B27C6145E03ED6520CAE5BFD69521D19C80C3` |
| `lib/game/themes/authored_parallax_themes.dart` | `C95FBD4A83C5C3AD857873E0A915F9E0E6F992191CF4591ACC3404D58410A7AF` |

Validation evidence:

- `tools/editor`: `dart analyze` clean; full suite 191/191 after the baseline,
  parser repair, no-op tests, and initial model tests; subsequent focused
  suites pass 11/11 entity parser/export tests and 10/10 exact source-model
  tests
- root generator coverage: 17/17 tests pass
- same-revision Phase 3 exit evidence: Core package analysis clean and 291/291
  tests pass; root Core 432/432 tests pass; replay validator 78/78 tests pass,
  with its known analyzer info at `validator_worker.dart:447` unchanged
- `GameCore(...)` still selects `LegacyWorldMotionAuthority`; only the explicit
  `GameCore.terrainMotionHarness(...)` test/tool factory selects staged terrain.
  Replay validation constructs normal `GameCore(...)`.

Minimum final commands:

```powershell
dart analyze

Push-Location packages/runner_core
dart analyze
dart test
Pop-Location

Push-Location tools/editor
dart analyze
flutter test
flutter drive --profile `
  --driver=test_driver/integration_test.dart `
  --target=integration_test/polygon_interaction_benchmark_test.dart `
  -d windows
Pop-Location

dart run tool/migrate_polygon_authoring.dart --check `
  --report=.tmp/slopes-phase4-migration-final.json
dart run tool/generate_chunk_runtime_data.dart --dry-run

flutter test test/core

Push-Location services/replay_validator
dart analyze
dart test test
Pop-Location

git diff --check
```

Also run every focused model, store, plugin, interaction, migration, generator,
seam, parity, golden, and normal-construction test introduced by this phase.

## 29) Exit Gate

Phase 4 is complete only when:

- [ ] the complete baseline and Phase 0 migration audit are reproduced
- [ ] prefab v3/chunk v2 are the only normal authoring write formats
- [ ] committed authoring source contains no rectangle collider, flat-profile,
      or gap source fields
- [ ] the migration check is blocker-free or every blocker is explicitly
      reviewed and reauthored
- [ ] repeated migration check/write is deterministic and idempotent
- [ ] a non-developer can complete polygon creation/edit/diagnostic/export
      workflows without hand-editing JSON or Dart
- [ ] invalid polygons, expanded placements, limits, and scheduler-reachable
      seams block export with actionable diagnostics
- [ ] editor preview, generator, generated records, and Core compiler parity
      signatures agree
- [ ] staged polygon/edge/triangle/lineage output is deterministic and
      unreachable from normal production construction
- [ ] legacy generated projection is exact, bounded, documented, and rejects
      non-orthogonal approximation
- [ ] no normal editor/store path writes legacy source fields
- [ ] no duplicate geometry, transform, validation, or persistence authority
      exists across Prefab and Chunk routes
- [ ] no-op save, dry-run generation, and fresh-process goldens are stable
- [ ] hard authoring limits do not truncate or hang
- [ ] polygon interaction p95/p99 and missed-input gates pass
- [ ] full editor/Core/root/validator analysis and tests pass
- [ ] documentation and the implementation findings ledger are current
- [ ] normal production levels and replay validation still use legacy authority

Passing a polygon widget demo or migrating only one fixture is not Phase 4
completion. The entire repository source, generator boundary, editor workflow,
and scheduler seam set must close together.
