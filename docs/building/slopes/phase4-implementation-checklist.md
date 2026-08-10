# Slopes Phase 4 - Polygon Authoring, Migration, And Generation Checklist

- Created: July 28, 2026
- Status: Implementation in progress; legacy collision content is cleared for
  polygon reauthoring, but no Phase 4 schema/runtime cutover has begun
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

- legacy obstacle AABBs migrate as `solid`; legacy platform AABBs migrate as
  `oneWay` to preserve their current top-only behavior
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
- [x] Generate a clearly named staged terrain artifact/API that normal runtime
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
        topology limit blockers
  - [x] exact Core revalidation finds three minimum-edge content corrections;
        reviewed minimal outward replacements resolve all three without
        relaxing the global rule
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
- [x] Provide an explicit undoable Normalize action that can remove collinear
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

- [x] Add one strict canonical prefab-v3 file codec in the normal prefab layer;
      make the migration target/checker delegate to that same authority.
- [x] Add reusable prefab-v3 owner validation that delegates canonical geometry,
      occupied overlap, and hard capacity limits to Core.
- [x] Define one immutable `PrefabV3Def` in the normal prefab model layer and
      reuse that record in migration targets without changing the v2 store/UI.
- [ ] Make normal canonical prefab writes target v3 at the single source
      cutover.
- [ ] Replace `PrefabDef.colliders` with `collisionShapes` in normal models.
- [x] Keep staged polygon coordinates relative to the existing prefab anchor.
- [x] Preserve prefab key, human ID, status, kind, visual source, anchor, tags,
      and revision semantics.
- [ ] Require at least one collision shape for colliding obstacle/platform
      contracts; decoration behavior stays unchanged.
- [ ] Require at least one shape to intersect resolved visual source bounds.
- [ ] Permit intentional extent outside visual bounds and report its exact
      amount without clipping.
- [ ] Update deterministic comparison, pending diff, duplicate/rename,
      deprecate, and runtime-preview adapters.
- [x] Bump a prefab revision only when its canonical collision source or other
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

- [x] Add immutable normal-layer `ChunkV2FileData` and one strict canonical
      `ChunkV2FileCodec`; migration target aliases/facades delegate to them.
- [x] Add an explicit strict all-v2 `ChunkStore` staging load that retains
      immutable source paths/baselines and cannot be selected by normal v1
      loading.
- [x] Compose staged chunks with strict prefab-v3/tile-v2 dependencies in a
      temporary document/scene, deterministic active-level projection,
      pending diffs, clean no-op export, and changed-source export lock.
- [x] Build a read-only v2 ownership/save plan for baseline-backed owners,
      explicitly created owners, managed-path moves, and baseline deletions.
      Require portable workspace-relative paths and reject missing ownership,
      case-insensitive target collisions, and deleted-path reuse.
- [ ] Make normal canonical chunk writes target v2 at the single source
      cutover.
- [ ] Remove `GroundProfileDef` and `GroundGapDef` from normal v2 models.
- [ ] Remove ground-profile/gap plugin commands, inspector forms, and tests once
      polygon replacements cover them.
- [x] Add staged chunk-local `collisionShapes` with stable IDs.
- [x] Preserve chunk key, ID, revision, status, level, tile/grid metadata,
      assembly group, tags, visual layers, prefab placements, and markers.
- [x] Retain `groundBandZIndex` only as visual composition metadata until
      Phase 5 replaces the ground rendering path.
- [x] Do not force direct polygons to `runtimeGroundTopY`; that field remains a
      legacy level/default bridge only.
- [x] Require every direct chunk-local vertex to stay inside closed chunk
      bounds and run accepted direct shapes through Core canonical/overlap
      validation.
- [x] Route staged chunk-local semantic commits through one freshness/order/
      bounds/Core owner policy and one typed plugin command; rejected and
      no-op commits preserve immutable document identity.
- [x] Expand placements through the one exact transform and require every
      transformed prefab vertex to stay inside closed chunk bounds after the
      one quantization step.
- [x] Do not permit per-placement collision-shape overrides in chunk v2.
- [x] Bump a chunk revision exactly once when an accepted canonical direct
      collision-source commit changes that chunk.
- [x] Apply the same freshness/no-op/exactly-once revision policy to existing-
      owner chunk-v2 metadata, deprecation status, and `groundBandZIndex`.
      The typed contract cannot mutate source identity, dimensions,
      composition, markers, placements, or polygon geometry.
- [x] Apply one strict existing-owner composition contract to tile layers,
      prefab placements, and enemy markers. Require canonical retained-source
      structure and complete staged placement/marker/seam/geometry validation;
      the contract cannot mutate identity, metadata, dimensions, or polygons.
- [x] Apply stale-checked deterministic lifecycle/source-path policy to
      chunk-v2 create/duplicate/rename/delete. Blank creates start deprecated
      at revision 1, duplicates start active at revision 1, rename retains the
      stable key and bumps once, loaded delete keeps baseline evidence, and an
      unsaved create/delete pair collapses to no pending change. Changing a
      referenced prefab still does not bump every referencing chunk revision.
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
- [x] Treat prefab-v3 collision loops as already anchor-relative during chunk
      expansion: pass a zero Core source anchor and do not subtract the visual
      `anchorXPx`/`anchorYPx` a second time.
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

The pure-Dart `TerrainAuthoringIssue` now provides that immutable envelope and
canonical ordering without making Core depend on JSON, filesystems, or editor
types. The staged generator uses it for strict prefab/chunk source parsing and
all compile/reference/transform/bounds findings; malformed file-level source
uses the canonical source path as the temporary owner because no owner key was
decoded. Chunk-v2 collision expansion maps the same envelope into editor
`ValidationIssue`, which now retains `ownerKey`: direct/placement failures own
the Chunk, while expanded-shape failures own the referenced Prefab. Seam,
generated-output drift, migration, and the remaining editor-wide validation
paths still need this boundary before the broad diagnostic gate can close.

Blocking categories:

- [x] malformed schema/value/enum/half-pixel coordinate
- [x] missing/duplicate/case-colliding shape ID
- [x] repeated closing or consecutive duplicate vertex
- [x] noncanonical winding/start requiring explicit repair
- [x] too few distinct vertices, zero/small area, or short edge
- [ ] self-intersection, self-touch ambiguity, or collinear edge overlap
- [x] positive-area overlap between shapes
- [ ] unsupported hole/disconnected loop in one shape
- [x] prefab visual-source intersection contract failure
- [x] post-transform degeneracy or chunk-bounds overflow
- [x] unknown prefab/revision/source reference
- [ ] owner shape/vertex/expanded-edge limit overflow
- [ ] Core compiler error or source/compiled signature mismatch
- [x] scheduler-reachable seam incompatibility
- [x] generated output drift in validation mode

Non-blocking categories:

- [x] intentional collision extent beyond visual bounds
- [x] collinear middle vertex with explicit Normalize quick fix
- [x] optional metadata absent
- [x] material reference deferred until the Phase 5 material catalog exists
- [ ] content near a soft capacity/performance target

Do not downgrade geometry or seam correctness to a warning to make migration
pass. Do not truncate shapes, vertices, edges, or diagnostics at a hard limit.

## 14) Core Compiler Adapter And Preview Authority

- [x] Add a local path dependency from the editor to pure-Dart `runner_core` or
      another existing non-cyclic access path; Core must not depend on editor.
- [x] Adapt valid source shapes to `TerrainPolygonInput` with exact identity and
      integer coordinates.
- [x] Use `TerrainCompiler` for normalization/edge exposure diagnostics in
      preview and final validation.
- [x] Put deterministic triangulation in the same pure-Dart Core geometry
      boundary (or another already-shared pure-Dart boundary) so editor,
      generator, and later renderer data cannot drift.
- [ ] Do not copy compiler seam cancellation, outward-normal, adjacency, or
      edge-order logic into editor widgets.
- [ ] Keep cheap source-shape diagnostics available while a draft is invalid;
      invoke the full compiler only on a valid/debounced snapshot or gesture
      commit.
- [x] Render shared preview fills, source boundaries, vertices, selections,
      gesture previews, and open drafts directly from exact source loops.
- [x] Render collision/debug edges from the compiler result; never derive
      collision back from render triangles or source-loop fills.
- [x] Display exact edge IDs, tangent/normal, slope angle, collision mode,
      source lineage, and compiler diagnostic on selection.
- [x] Optionally display accepted Éloïse/Grojib/Hashash/Derf eligibility using
      existing Core profiles; the editor does not define new thresholds.
- [x] Build the surface/graph overlay with the accepted Phase 3 extractor and
      profile graph builders; never infer navigation from visual polygon fill.
- [x] Keep all preview state read-only with respect to Core/runtime objects.

## 15) Deterministic Migration Tool

The read-only command now runs from the editor package:

```powershell
Push-Location tools/editor
dart run tool/migrate_polygon_authoring.dart --check `
  --report=.tmp/slopes-phase4-migration.json
Pop-Location
```

`--write` is intentionally rejected until §16 is complete.

The checker classifies the repository as one generation before parsing any
complete document. Prefab v1/v2 plus chunk v1 is the legacy conversion state;
prefab v3 plus chunk v2 is the current no-op state. Any partial cutover or mix
among chunk files is a stable blocker, never an invitation to convert the
remaining files independently.

- [x] Default to read-only `--check`; never infer write from a missing flag.
- [x] Reject unknown/duplicate CLI flags and unavailable `--write` with usage
      exit code `64` and no source/report side effect.
- [x] Detect dirty source drift after planning through canonical-path SHA-256
      audit records.
- [x] Parse legacy prefab v1/v2 and chunk v1 strictly without compatibility
      normalization or numeric coercion.
- [x] Convert one isolated AABB to four exact clockwise vertices.
- [x] Union touching/overlapping AABBs with deterministic integer orthogonal
      geometry, removing every interior edge.
- [x] Emit multiple loops for disconnected union components.
- [x] Block holes, point-only ambiguity, invalid half pixels, overflow, or
      unsupported topology.
- [x] Derive `collision_001...` IDs from canonical component order and preserve
      them on repeated runs.
- [x] Convert flat chunk ground into finite `[0,width] x [topY,height]`
      coverage minus pit intervals.
- [x] Derive `ground_001...` IDs left-to-right/canonical order.
- [x] Preserve occupied area exactly for automatic unions; require an explicit
      reviewed delta and exact source guard for any approved reauthoring.
- [x] Preserve stable prefab/chunk keys and human IDs in every strict target.
- [x] Keep revisions unchanged for representation-only equivalent migration.
- [x] Emit sorted automatic conversion, union, disconnected component,
      reviewed-reauthoring, and blocker records.
- [x] Extend the report with all 107 revision decisions and 99 deterministic
      prefab downstream-impact records covering all 50 placements.
- [ ] Add staged generated-artifact impact records once generator output exists.
- [x] Include exact legacy/planned occupied-area facts.
- [x] Include exact before-source paths and SHA-256 signatures in report v2.
- [x] Include after-migration canonical target SHA-256 signatures.
- [x] Make `--check` exit `1` for source, plan, target, drift, or report-write
      blockers.
- [x] Decide and implement post-cutover `--check` behavior so current-schema
      source reports zero pending migration instead of entering the legacy
      parser.
- [x] Require current-schema source to pass strict v3/v2 decoding, exact
      canonical-byte equality, Core-owned canonical geometry review, placement
      reference validation, and the same fresh SHA-256 drift audit.
- [x] Reject mixed legacy/current schema generations before returning or
      writing a partial report.
- [ ] Make `--write` require a complete blocker-free plan generated from the
      same source fingerprints.

## 16) Migration Write Transaction And Recovery

- [x] Build and strictly byte-round-trip every target file in memory without
      exposing a source-write path.
- [x] Show the exact nine-file target plan with before/after SHA-256 values.
- [x] Provide a pure, deterministic audit that rejects missing, changed, or
      ambiguously canonicalized source paths against the reviewed SHA-256 set.
- [x] Stage temporary files on the same volume.
- [x] Recheck every source fingerprint immediately before replacement.
- [x] Recheck every source SHA-256 immediately before emitting a readiness
      result or optional report artifact.
- [x] Preserve existing newline/encoding policy and canonical JSON formatting.
- [x] Replace files through the repository's safe-write primitives.
- [x] If any replacement fails, restore every already-replaced source from the
      transaction backup and report the failure.
- [x] Never leave mixed prefab/chunk schema versions after a failed batch.
- [x] Permit an explicit machine-readable check report only at a
      workspace-relative `.json` path outside `assets/authoring`.
- [x] Add the machine-readable write-transaction/rollback artifact.
- [x] Re-running `--check` after success reports nine validated targets and
      zero pending migrations without invoking legacy conversion.
- [ ] Re-running `--write` after success must be a no-op.

The normal editor export remains document-scoped and source-drift guarded. The
batch transaction exists only for the one-time schema migration.

`WorkspaceWriteTransaction` now stages exact UTF-8 bytes to unique sibling
files, rechecks optimistic concurrency through a pre-replacement callback,
moves every original to a sibling backup, verifies installed bytes, and runs a
caller-supplied post-install validator while rollback remains possible. A later
install failure and a post-install validation failure both restore the complete
original set without transaction debris.

`PolygonAuthoringMigrationTransaction` binds that primitive to one complete
blocker-free `PolygonAuthoringMigrationCheck`. It verifies source/target path
and SHA-256 coverage, repeats the source digest audit immediately before any
move, requires the installed repository to load as one blocker-free canonical
v3/v2 generation, and returns deterministic machine-readable committed/no-op
evidence. Reapplying a fresh current-schema check is byte-identical and writes
nothing.

Transaction failures now emit deterministic report-v1 evidence with distinct
`blocked`, `rolledBack`, `rollbackFailed`, and `committedCleanupFailed` states.
The report includes stable code/message/path facts and intentionally excludes
host-specific exception and temporary-path text.

This is deliberately an unreachable transaction foundation: the CLI still
rejects `--write`, the repository remains prefab-v2/chunk-v1, and normal stores
cannot consume a migrated workspace yet. CLI authorization, report-file
emission, and `--write` idempotence stay open until the normal editor cutover
is ready.

## 17) Shared Polygon Interaction Model

Build shared non-widget command/state primitives under the editor's shared
scene/domain seams before wiring either route.

Required tools:

- [x] select shape/vertex/edge
- [x] create polygon by ordered vertex clicks
- [x] close valid polygon explicitly and expose draft/gesture cancellation
- [x] move one vertex
- [x] translate one complete shape
- [x] insert a vertex on a selected edge
- [x] delete a vertex when at least three valid vertices remain
- [x] delete/duplicate a shape with deterministic unique ID allocation
  - [x] choose a deterministic nearest conservative free duplicate offset,
        snapped once and closed-bound filtered for direct chunk owners, instead
        of a fixed nudge that normally self-overlaps
- [x] edit collision mode and optional metadata through one shared dialog on
      both explicit staging routes
- [x] explicit Normalize quick fix

Interaction rules:

- [x] preserve shared `Ctrl+drag` pan and `Ctrl+scroll` zoom behavior
- [x] primary drag remains tool-driven
- [x] expose a visible snap selector: owner grid or exact `0.5 px`
  - [x] Prefab-v3 staging exposes `1 px` owner-grid and exact `0.5 px`
        choices; changing it cancels any active preview without session history.
  - [x] Chunk-v2 staging exposes the same choices and binds them to the
        selected direct chunk owner without changing source on selection.
- [x] never permit arbitrary non-half-pixel vertex values
- [x] shared inspector numeric fields accept integer/`.5` text and display exact
      values on both explicit staging routes
- [x] one pointer gesture produces one undo entry, not one entry per event
- [x] cancellation restores committed geometry; commit runs validation once
- [x] selection changes produce no semantic commit or history entry
- [x] wire Escape cancellation and prove viewport changes do not bump document
      revision in both routes
- [x] a temporarily invalid drag can render local diagnostics, but export and
      gesture commit policy must never silently repair topology
- [x] project committed shapes, active previews/drafts, and selection into a
      shared scene painter with structural repaint equality
- [x] map exact half-pixel source ticks to canvas space one-way; inverse pointer
      coordinates remain fractional until the reducer applies its snap policy
- [x] keyboard delete/undo/redo and focus behavior are tested
- [x] wire the shared scene semantics into explicit Prefab-v3 and Chunk-v2
      staging routes; normal source-page replacement remains in Sections 18-19

Multi-shape selection, boolean authoring operations, rotation, arbitrary scale,
curves, and holes are not required for the baseline tool.

## 18) Prefab Creator Polygon Workflow

- [ ] Replace rectangle overlay handles with the shared polygon interaction
      layer in obstacle and platform prefab workflows.
- [ ] Show visual source, anchor, all collision fills, edge modes, vertices,
      and selected-shape diagnostics in prefab-local coordinates.
- [x] Keep atlas/platform-module image-size caches workspace-scoped.
- [x] Preserve slice/module selection, prefab operations, tags, and status in
      the explicit write-locked Prefab-v3 workspace.
- [x] Compose retained prefab-owner controls over the explicit v3 staging
      document: create, edit status/kind/visual source/anchor/tags, duplicate,
      stable-key-preserving rename, and delete all dispatch typed stale-checked
      commands. Owner selection survives undo/redo and lifecycle replacement,
      the zero-owner state can create again, polygon source is preserved, and
      source apply remains visibly locked.
- [x] Reuse the retained visual atlas slicer for Prefab-v3 atlas and tile
      slices. Create/update and confirmed unreferenced delete dispatch typed
      catalog commands, tags use the domain canonicalizer, referenced deletion
      is blocked without an implicit cascade, undo/redo resynchronizes the
      form, and guarded local drafts cannot be lost through selection or view
      changes.
- [x] Reuse the retained visual platform-module form/grid for Prefab-v3 module
      create/update/duplicate/rename/status/delete and paint/erase/move/cell
      delete. Empty creation starts deprecated, reactivation requires a cell,
      referenced deletion fails closed, rename preserves referencing prefab
      polygons through the typed cascade, and legacy/v3 routes share one
      canonical cell reducer.
- [x] Provide shape list ordering by stable ID and focus from diagnostics.
- [x] Show exact collision extent beyond visual bounds without clipping.
- [x] Keep page-local selection/tool/viewport drafts projected over the
      plugin-owned prefab document.
- [x] Route every committed geometry edit through `PrefabDomainPlugin` and
      `PrefabStore`; no page-local JSON write path.
- [x] Add a prefab-owned polygon commit policy that rejects stale, invalid,
      unordered, or unresolved-bound commits before session history and bumps
      the accepted owner revision exactly once.
- [x] Stage the prefab-v3 plugin command and document boundary with immutable
      pending diffs and a hard source-write lock; the live loader and route
      remain v2 until the single schema cutover.
- [x] Stage a Prefab route-local polygon coordinator and focusable scene
      surface over the shared reducer/painter, with owner rejection kept out of
      history and widget tests for drag, Escape, Delete, undo/redo, and pan;
      the normal Prefab Creator still selects its v2 rectangle workflow.
- [x] Add an explicit read-only store/plugin staging loader that strictly
      composes prefab-v3 with retained tile-v2 source, atlas metadata, and one
      shared atlas/module visual-bounds resolver; normal v2 load/save remains
      selected and changed staging export remains locked.
- [x] Add an explicitly selected prefab-v3 staging workspace with owner-local
      draft isolation, all shared polygon tools, session undo/redo, metadata,
      exact shape/vertex readout, stable diagnostics focus, atlas/platform
      visual sources, and a visibly disabled source-apply action. Ordinary v2
      loads still select the rectangle page.
- [x] Stage immutable existing-owner metadata and typed create/duplicate/
      rename/delete policies. Metadata cannot mutate stable identity or polygon
      source; lifecycle owns deterministic key allocation; accepted owner
      changes bump exactly once and rejected/no-op candidates preserve document
      identity.
- [x] Stage retained prefab/tile slice and platform-module operations behind
      one complete-source freshness token. Module updates/renames own revision
      propagation, referenced deletes fail closed unless an explicit safe slice
      cascade is requested, visual bounds are recomputed, and prefab/tile
      pending diffs remain source-write locked.
- [x] Route exact numeric vertex edits through the shared reducer and prefab
      owner policy. Parse integer/`.0`/`.5` text without floating point, retain
      invalid typed values and diagnostics locally, and commit one accepted
      vertex replacement as one revision/history entry.
- [x] Bump revision exactly once per committed semantic edit.
- [x] Make a drag one pending semantic change even if it has many pointer
      updates.
- [x] Preview downstream referencing chunks/placements affected by a prefab
      change without mutating those chunk source revisions.
- [x] Keep decoration prefabs with no collision valid and unchanged.

## 19) Chunk Creator Polygon Workflow

- [ ] Replace flat ground profile/gap inspector sections with direct chunk
      collision-shape tools.
- [x] Render chunk-local shapes as editable and resolved prefab shapes as
      read-only overlays with source prefab/placement lineage.
- [x] Keep prefab instance transform editing at the placement level only; the
      staged form can replace the prefab owner and edit translation, layer,
      snap, exact supported scale, and reflection, but never prefab vertices.
- [ ] Provide an action to open the owning prefab workflow for shape edits
      instead of creating per-instance overrides.
- [ ] Preserve chunk create/duplicate/rename/deprecate, metadata, prefabs,
      markers, visual layers, level scope, and pending diff behavior.
- [ ] Preserve `groundBandZIndex` preview until Phase 5 replaces its renderer.
- [ ] Fill the visible ground preview from direct terrain polygons where
      possible; label it preview-only, not runtime collision authority.
- [x] Show transformed/quantized coordinates and chunk-bound violations.
- [x] Show source-shape and expanded-shape/edge capacity separately.
- [ ] Recompile only affected draft/placement data during interaction, then run
      full chunk validation on gesture commit/export.
- [ ] Route every semantic edit through `ChunkDomainPlugin` and `ChunkStore`.
- [ ] Preserve source-drift, case-insensitive filename collision, and atomic
      one-file-per-chunk save rules.
- [x] Stage a Chunk route-local polygon controller and focusable scene surface
      over the shared reducer/painter. Keep previews and rejected diagnostics
      owner-local, dispatch only accepted typed plugin commits, and synchronize
      session undo/redo by immutable document identity.
- [x] Add an explicitly selected chunk-v2 staging workspace with active-level
      owner isolation, all shared polygon tools, owner-grid/half-pixel snap,
      closed chunk bounds, shared exact shape/vertex editing, retained rejected
      text, owner diagnostics, session history, and visibly disabled
      reload/source-apply actions.
- [x] Compose retained chunk-owner controls over the explicit v2 staging
      document: create, edit status/level/difficulty/assembly group/canonical
      tags/render-band Z, duplicate, stable-key-preserving rename, and delete
      all dispatch typed stale-checked commands. Identity/dimensions,
      composition, markers, placements, and polygon source remain protected;
      selection resynchronizes after lifecycle changes and undo/redo. Deleting
      a level's final owner leaves level switching and undo recovery available
      and explains why creation lacks a locked dimension template.
- [x] Compose retained tile-layer, prefab-placement, and enemy-marker forms over
      the strict Chunk-v2 composition command. Create/edit/delete rebuilds all
      three lists in canonical order, uses active Prefab-v3 owners, exact
      placement-scale steps, Core enemy IDs, accepted marker intents and
      bounds, advances the chunk revision once, preserves owner metadata and
      polygons, and resynchronizes through session undo/redo.
- [x] Keep the ordinary v1 Chunk Creator route and its ground/gap reload/export
      path unchanged until the coordinated source cutover.
- [x] Make an accepted direct-owner gesture one revision bump and one pending
      chunk change even when the preview receives multiple pointer updates.

### 19.1 Placement And Navigation Authoring Diagnostics

- [x] Overlay Éloïse, Grojib, and Hashash eligible surfaces and the accepted
      Grojib/Hashash walk/jump/drop graph edges. Éloïse intentionally has no
      pathfinding graph because Core owns no player graph profile.
- [x] Overlay Unoco solid blockers/local-hover candidates without constructing
      a flight graph.
- [x] Overlay Derf perch eligibility and the independent 32-pixel support span.
- [x] Resolve existing ground/highest-surface/obstacle-top marker previews
      through the accepted Phase 3 placement query and actor/item policy.
- [x] Preserve marker order, chance, salt, and source placement intent; preview
      must consume no RNG and mutate no marker.
- [x] Distinguish an intentionally optional rejected spawn from malformed or
      impossible authored placement instead of treating every miss alike.
- [x] Keep reachability/placement evidence advisory in Phase 4 unless it
      violates an already-blocking source contract. Phase 5 owns full
      streamed gameplay/content acceptance and may promote reviewed diagnostics.
- [x] Record projectile terrain as the existing later-phase disposition; the
      editor must not imply ballistic terrain support is already delivered.

### 19.2 Normal V3/V2 Cutover Execution Slices

The explicit polygon workspaces prove geometry editing but deliberately do not
yet preserve the complete normal authoring surface. Do not migrate repository
source or enable `--write` until these slices close in order:

1. **Typed domain mutation parity, still write-locked.**
   - Prefab v3 must preserve create, duplicate, rename, deprecate/delete,
     lifecycle status, kind, visual source, anchor, tags, atlas slices, tile
     slices, and platform modules. Polygon commits remain the only collision
     mutation; no rectangle compatibility field enters the v3 model.
   - Chunk v2 must preserve create, duplicate, rename, deprecate/delete,
     general metadata, `groundBandZIndex`, tile layers, prefab placements,
     enemy markers, and active-level scope. It intentionally drops only
     `update_ground_profile`, `add_ground_gap`, `update_ground_gap`, and
     `remove_ground_gap`.
   - Reuse existing deterministic allocation, ordering, revision, and no-op
     rules rather than cloning them into route widgets.
   - Landed first: existing-owner Chunk v2 metadata/status/ground-band edits
     and tile-layer/placement/marker composition use immutable before/after
     contracts with stale rejection, strict canonical values, mutually
     protected fields, complete candidate validation, and one revision bump.
     Chunk owner metadata plus create/duplicate/rename/delete forms now compose
     those staged policies with active-level selection and undo/redo. Granular
     tile-layer/placement/marker forms now compose the strict composition
     replacement; owning-prefab navigation remains open.
     Prefab-v3 owner metadata, create/duplicate/rename/delete, prefab/tile
     slices, and platform-module create/update/duplicate/rename/delete are also
     staged through immutable stale-checked commands. All source writes remain
     behind the cutover lock.
2. **Normal validation and pending-change parity.**
   - Run owner validation, expanded prefab collision, marker placement,
     scheduler-reachable seam analysis, and global capacity checks on every
     semantic commit/export.
   - Preserve load-time baselines, changed stable keys, downstream prefab
     placement impact, and canonical one-file-per-owner diffs.
   - Prefab-v3 staging now validates the complete retained prefab/tile catalog
     in memory: deterministic ordering, identities/revisions, atlas bounds,
     module cells/references, visual-owner references, and polygon-owner rules.
     Strict chunk-v2 placement reads produce stable-key impact counts for every
     prefab; the staging route previews affected placements/chunks while
     preserving all chunk bytes and revisions.
   - Every changed Prefab-v3 and Chunk-v2 staging candidate now crosses its
     complete document validator plus deterministic save-plan ownership before
     entering session history. Polygon and metadata edits can no longer bypass
     expanded prefab collision, marker, capacity, or scheduler-reachable seam
     blockers; lifecycle/catalog/composition edits retain the same gate.
     Staging export validates before its clean/no-op result or changed-source
     write lock, so invalid source cannot masquerade as a successful no-op.
3. **Store/export parity without repository migration.**
   - Add exact v3/v2 save plans, final source-drift checks, case-insensitive
     path collision checks, sibling staging, byte verification, and rollback.
   - Exercise writes only in temporary all-current fixtures. The checked-in
     v2/v1 source and CLI remain read-only.
   - `ChunkStore` builds a deterministic v2 plan and pending diff for
     clean/current, create, managed move, and delete states entirely from
     immutable source baselines. Its explicit staging proof rechecks the whole
     source set after staging, applies writes/moves/deletions through one
     rollback-safe transaction, strictly verifies the final file set, and
     reloads byte-identically. Normal plugin export remains locked.
   - `PrefabStore` now builds the exact paired prefab-v3/tile-v2 plan from
     strict load-time baselines. Its explicit staging proof rechecks both files
     after staging, installs only changed artifacts through the shared
     rollback-safe transaction, byte-verifies and strictly decodes the
     installed pair before cleanup, and reloads byte-identically in temporary
     all-current fixtures. Normal plugin export and migration writes remain
     locked.
4. **Route replacement.**
   - Compose existing prefab/module and chunk metadata/placement/marker forms
     over the v3/v2 plugin documents, replace rectangle/ground-gap controls
     with the proven polygon surfaces, and restore reload/source-apply actions.
   - Add the owning-prefab navigation action from selected placed collision;
     never add per-instance vertex overrides.
   - Prefab-v3 staging now composes owner create/edit/duplicate/rename/delete
     forms over the typed plugin commands, including status, kind, visual
     source, anchor, and canonical tags. These controls preserve polygon source
     and session history, resynchronize selection after lifecycle changes and
     undo/redo, and retain the source-write lock. The retained visual atlas and
     platform-module forms are also composed over typed catalog commands, with
     reference-safe deletion and guarded local drafts. Normal route selection,
     reload, and source apply remain open.
   - Chunk-v2 staging now composes active-level owner selection, metadata/status/
     render-band editing, create/duplicate/stable-key rename/delete, and
     lifecycle-safe undo/redo over the typed plugin commands. The final-owner
     empty-level state remains recoverable without inventing dimensions. A
     second retained view now composes canonical tile-layer, prefab-placement,
     and enemy-marker create/edit/delete forms over the strict composition
     command. Owning-prefab navigation plus normal route selection, reload, and
     source apply remain open.
5. **Current-schema normal-loader proof.**
   - In a complete temporary v3/v2 workspace, normal plugin loading—not an
     explicit staging API—must select polygon documents, support every retained
     operation, export, reload byte-identically, and preserve session history.
   - Legacy source must then report one explicit migration-required state; it
     must not silently select the rectangle/ground-gap page.
6. **Coordinated repository cutover.**
   - Register current-schema generator/seam/staged-terrain outputs, run the
     complete read-only migration and generated-impact gates, enable `--write`
     with external report emission, replace all nine source files atomically,
     and immediately regenerate/verify the bounded legacy projection.
   - Remove `Staging` names, legacy normal models/forms/commands/stores, and the
     temporary source-write locks in the same cutover. Legacy codecs remain
     reachable only from the offline migration checker.

Current command-gap audit (August 9, 2026):

| Domain | Normal legacy command surface | Explicit polygon document today | Cutover requirement |
| --- | --- | --- | --- |
| Prefab | `replace_prefab_data`, covering prefab/slice/module lifecycle and metadata | Write-locked `commit_prefab_polygon`, `commit_prefab_v3_metadata`, `commit_prefab_v3_lifecycle`, and `commit_prefab_v3_catalog` cover collision, existing-owner metadata, prefab lifecycle, slices, and platform modules | Typed mutation and explicit-staging form parity are complete with deterministic allocation/order, protected collision fields, complete-source freshness and validation, owner/module revision rules, recomputed visual bounds, reference-safe deletion, canonical two-file pending diffs, guarded local drafts, visual atlas/module editing, and read-only stable-key chunk-placement impact. Normal loader/route selection, reload/source apply, and source migration remain disabled. |
| Chunk lifecycle | `create_chunk`, `duplicate_chunk`, `rename_chunk`, `deprecate_chunk`, `delete_chunk` | write-locked `commit_chunk_v2_lifecycle` covers stale-checked create/duplicate/rename/delete; metadata status covers deprecation | Typed lifecycle and explicit-staging form parity are complete with stable `chunkKey`, canonical IDs/paths, explicit created/baseline ownership, reviewed v2 revision/default-status rules, selection resynchronization, and recoverable final-owner deletion. Normal loader/route selection, reload/source apply, and source migration remain disabled. |
| Chunk metadata | `update_chunk_metadata`, `update_ground_band_z_index`, active-level selection | active-level selection plus write-locked `commit_chunk_v2_metadata` for status, level, difficulty, assembly group, canonical tags, and render-band Z | Existing-owner metadata and explicit-staging form parity are complete with identity/dimensions/composition/marker/placement/polygon protection and one accepted revision bump. Retain render-band Z until Phase 5; normal loader/route selection, reload/source apply, and source migration remain disabled. |
| Chunk tile layers | retained tile-layer source | write-locked strict `commit_chunk_v2_composition` replacement | Explicit-staging create/edit/delete form parity is complete with non-empty retained fields, unique IDs, canonical order, and visibility state. Normal loader/route selection, reload/source apply, and source migration remain disabled. |
| Chunk placements | add/move/replace/settings/remove prefab placement | read-only expanded overlay plus write-locked strict `commit_chunk_v2_composition` replacement | Existing-owner mutation and explicit-staging form parity are complete with active-owner replacement, translation/Z/snap/exact scale/reflection, canonical order, exact expansion/full validation, and no per-instance vertex override. Owning-prefab navigation and normal cutover remain open. |
| Chunk markers | add/move/type/settings/remove enemy marker | read-only Core placement diagnostics plus the same write-locked strict composition replacement | Existing-owner mutation and explicit-staging form parity are complete with canonical order, Core enemy IDs, bounds/chance/salt/intent contracts, zero-RNG authoring, and advisory placement projection. Normal loader/route selection, reload/source apply, and source migration remain disabled. |
| Removed terrain commands | ground-profile update plus add/update/remove gap | `commit_chunk_polygon` | Delete the legacy commands/forms rather than mapping them to approximate polygons. |

This audit is a technical preservation gate, not a request for new gameplay
rules. Existing Phase 0-3 player, enemy, navigation, marker, and determinism
contracts remain authoritative throughout the cutover.

## 20) Scheduler-Aware Seam Validation

A seam is validated against the transitions the generated level scheduler can
actually produce, not directory order or an arbitrary editor neighbor.

- [x] Derive canonical left/right boundary signatures from transformed,
      quantized, compiled chunk geometry.
- [x] Include ordered boundary vertices/coverage intervals, collision mode, and
      geometry needed for physical edge cancellation/continuity.
- [x] Treat a fully open boundary as an explicit empty signature.
- [x] Enumerate every possible adjacent pair within a tier/group pool.
- [x] Enumerate transitions at early/easy/normal/hard tier boundaries.
- [x] Enumerate within-run and between-run transitions from authored level
      assembly schedules.
- [x] Respect existing distinct-chunk/group eligibility without changing
      selection behavior.
- [x] Validate both directions where the scheduler can emit both orders.
- [x] Block mismatched physical coverage/vertices that would create an
      unintended seam wall, overlap, ledge, or hole.
- [x] Report level ID, scheduler transition, left/right chunk keys, side,
      expected/actual signature, and exact mismatch coordinates.
- [x] Keep render material-phase mismatch as Phase 5 evidence unless a current
      material key makes it unambiguous now.
- [x] Show compatible candidate neighbors and failing pairs in Chunk Creator.
- [x] Add a workspace/global validation path so a valid individual chunk cannot
      be exported while it breaks a reachable level transition.
- [x] Golden the reachable adjacency set so validator/editor/generator cannot
      disagree about which seams matter.

The pure-Dart Core boundary now owns the canonical `authoring-seams-v1`
transition record, sort, duplicate rejection, and SHA-256. The editor maps its
exact scheduler enumeration through that contract, while the staged generator
strictly decodes the same checked-in eight-transition golden and verifies its
derived record/digest (`9681ffb1…93b`). Ambiguous delimiter-bearing identities,
duplicate transitions, schema drift, record drift, and digest drift fail
closed. Section 21 now carries that verified transition set through the shared
Core compiled-boundary comparator before it can construct a renderable staged
batch. Normal chunk-v1 generation and runtime selection remain unchanged.

Do not add new neighbor metadata or change procedural selection merely to make
an incompatible chunk pass. Any requested scheduling change is a separate
gameplay/content decision.

## 21) Generator Refactor And Staged Terrain Output

- [x] Keep `tool/generate_chunk_runtime_data.dart` the single repository
      generation entry point.
- [x] Refactor polygon parsing/transform/compile/render steps into focused
      testable pure-Dart files rather than growing the monolith further.
- [ ] Parse only current prefab v3/chunk v2 in normal generation.
- [x] Expand prefab placements with stable placement/source lineage.
- [x] Validate all direct/expanded shapes and scheduler seams before rendering
      any output.
- [x] Feed exact quantized polygons through the accepted Core compiler.
- [x] Generate normalized local polygon loops and precompiled exposed local
      edges with collision/render metadata.
- [x] Deterministically triangulate each normalized simple polygon during
      generation, never independently inside Flame.
- [x] Use exact integer orientation/containment predicates and a stable ear
      tie-break based on canonical vertex index.
- [x] Require exactly `vertexCount - 2` non-degenerate triangles whose signed
      area sum equals the source polygon exactly.
- [x] Store triangle indices into the same normalized polygon loop used by
      collision/source signatures.
- [x] Generate source identity lineage: chunk key, placement key when present,
      prefab key/revision, shape ID, and local edge identity.
- [x] Preserve runtime chunk index/version binding for Phase 5; do not bake a
      fake streamed chunk index into authoring identities.
- [x] If the accepted Core compiler requires an instance chunk index during
      local preview, use a reserved internal value, strip it from generated
      local records, and assert it is never serialized as runtime identity.
- [x] Include deterministic compiler/signature format versions.
- [x] Generate collision and render inputs from the same normalized source in
      one pass.
- [x] Never rebuild collision edges from render triangles.
- [x] Keep generated data generated; no hand edits.
- [x] Sort all maps/lists explicitly before Dart rendering.
- [x] Keep generated numeric output integer/fixed rational where authoritative.
- [x] Produce the bounded legacy rectangle/gap projection only for migrated
      orthogonal production content until Phase 5 removes that need.
- [x] Deterministically decompose orthogonal solid polygon unions into
      non-overlapping canonical rectangles without changing occupied area.
- [x] Derive legacy flat ground/gaps only when the direct chunk coverage has the
      exact flat representable form.
- [x] Record the explicit decision to abandon pre-reset collision parity and
      prove the cleared source projects exactly to the cleared generated
      authority; no decomposition seams exist in the empty result.
- [x] Reject runtime-selected diagonal or one-way content that the legacy
      authority cannot express exactly.
- [x] Fail rather than approximate a slope into rectangles.
- [x] Make `--dry-run` render every output in memory and compare it byte-for-byte
      with committed generated files after validation.
- [x] Report sorted missing/stale/unexpected output files and exit nonzero on
      drift.
- [x] Stage every generated output beside its target, replace the complete set
      through a byte-verified rollback-safe transaction, and remove transaction
      files after success or rollback.

The staged terrain output should use a narrowly named API/file that cannot be
mistaken for the current `ChunkPattern` production source.

The existing entry point now renders its five legacy generated outputs into an
immutable, path-sorted artifact plan before either checking or writing. Dry-run
compares the UTF-8 render with committed file bytes, reports stable
`generated_output_missing`, `generated_output_stale`,
`generated_output_unexpected`, or `generated_output_unreadable` diagnostics,
and performs no writes. Unexpected-file discovery is restricted to files under
the generator's declared output roots that carry its ownership marker, so
unrelated Dart sources are not treated as generated drift. Current prefab-v2,
chunk-v1, and runtime output contracts are unchanged; staged polygon output
registration in the live plan remains open below.

The current-schema generator foundation now lives in focused pure-Dart
source/compile/render files without being selected by the legacy entry point. It
strictly parses prefab v3/chunk v2 fixture source, requires Core-canonical
loops, expands anchor-relative prefab collision with exact scale tenths and
stable placement/prefab revision lineage, compiles polygons and exposed edges
through `TerrainCompiler`, enforces closed chunk bounds, and derives render
triangle indices from the same normalized Core polygon loops. Exact BigInt ear
tests require `vertexCount - 2` positive triangles and an area sum identical to
the polygon. Checked-in shared fixtures bind generator and editor
`authoring-polygons-v1`, `source-v1`, `edges-v1`, and
`authoring-placement-v1` signatures plus the generator's
`authoring-triangles-v1` signature, and bind both processes to the exact
`authoring-seams-v1` reachable transition set.

Core now also owns `authoring-boundary-v1` derivation and physical comparison,
replacing the editor-local implementation without changing its record or
diagnostics. The staged generator validates every manifest transition against
the compiled left/right boundaries. Missing, duplicate, or case-colliding
chunks, wrong level ownership, and exact coverage/continuation mismatches
produce sorted blocking issues and no renderable batch. Material differences
remain advisory evidence. `polygon_terrain_render.dart` accepts only the
validator's privately constructed batch, so callers cannot render raw compiled
chunks while bypassing this gate.

`polygon_terrain_render.dart` now projects an accepted validated chunk set into
the narrowly named future `staged_authored_terrain.dart` contract. Immutable
Core-side staged records retain chunk revision/metadata, the exact authored
owner/shape digest, canonical half-pixel source loops, transformed physics
loops, compiler-owned exposed edges,
triangle indices, placement/prefab revision lineage, and all signature format
labels. The artifact additionally retains `authoring-seams-v1` plus its exact
reachable-adjacency digest; this advances only the disconnected staged artifact
schema from format 2 to 3. The reserved compiler index is checked and stripped;
generated source
identities contain no streamed chunk index. Chunks and every derived record
family are sorted explicitly, authoritative numeric fields remain integers,
and empty, duplicate, or case-colliding chunk sets fail before output.

The checked-in executable Dart fixture is compared byte-for-byte through
`GeneratedArtifactPlan`, imported as typed data, regenerated from fresh
compiles, and invariant under reversed chunk input. A construction-import audit
keeps the staged record/output names unreachable from Core gameplay, Flutter,
the replay validator, and the live generator. Normal source remains
prefab-v2/chunk-v1; the live five-output plan does not register a production
staged terrain file until the coordinated source migration and legacy
projection are ready.

`polygon_terrain_legacy_projection.dart` now provides the isolated exact
compatibility primitive. It cell-decomposes accepted orthogonal polygons with
integer predicates, verifies exact occupied area, reproduces the current
16-pixel rectangle snap, unions snapped solid rectangles into deterministic
non-overlapping records, recognizes only exact direct `ground_*` bottom bands,
and derives canonical grid-aligned gaps from their complement. Diagonal edges,
non-rectangular one-way shapes, and snap-created one-way/one-way or
one-way/solid overlaps fail closed. The projector is not imported by the live
generator or runtime.

The old collider set exposed 24 `polygon_area_overlap` diagnostics across six
chunks. The accepted resolution was complete content reauthoring, so the 70
collision-bearing prefab definitions were cleared and all eight chunks now
encode no ground with a full-width `collision_cleared` gap. Prefab visuals,
kinds, metadata and stable keys, 50 placements, and two markers remain; the 70
cleared owners receive one revision bump.

All eight empty migration targets now compile and project exactly to the
checked-in collision-cleared `ChunkPattern` records: one full-width gap, no
solid pixels, and no one-way tops. This closes deterministic projection of the
intentional empty state without relaxing overlap validation or adding a union
policy. It deliberately does not preserve the pre-reset playable collision
baseline; polygon content, seam, support/navigation, and normal-run acceptance
remain open.

## 22) Authoring/Runtime Parity Fixtures

Create small checked-in fixtures that cover:

- [x] one prefab-local rectangle migrated to a polygon
- [x] concave union of overlapping/touching rectangles
- [x] disconnected union components and derived IDs
- [x] direct chunk slope and flat-to-slope seam
- [x] pit/open boundary and finite ground coverage
- [x] solid and one-way shapes
- [x] optional surface/material metadata
- [x] half-pixel coordinates
- [x] asymmetric X/Y reflection
- [x] minimum/maximum rational placement scale
- [x] internal shared-edge cancellation
- [x] cross-shape exact shared boundary
- [x] allowed cross-chunk seam pair
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

The representative artifact fixture crosses all six stages for one concave
direct solid, one direct one-way polygon, retained surface/material metadata,
and one exactly transformed prefab polygon. Prefab-v3 and Chunk-v2 editor
models encode/decode to stable canonical JSON; the editor Core adapter and the
strict generator reproduce `authoring-polygons-v1`, `source-v1`, `edges-v1`,
`authoring-placement-v1`, and Core-owned `authoring-triangles-v1`. The emitted
local records and typed Dart artifact remain exact.

A separate canonical transform/terrain fixture exercises odd half-pixel source
ticks, independent X-only and Y-only reflections, exact `0.3` and `3.0` scale
limits, one-quantization transformed vertices, a surviving flat-to-slope edge,
finite ground on both sides of a pit, and an exact shared solid boundary whose
internal edge cancels. Generator and editor reproduce source
`6e5e8bbf…fe8`, edge `ed707fc7…d31`, authored polygon `60ca88ca…c3f`,
placement `4f07473d…1c2`, and triangle `41ee501d…f36` signatures for six
polygons, 21 exposed edges, and 14 triangles. The original reviewed artifact
fixture and its bytes remain unchanged.

The migration-origin fixture binds the real `LegacyPrefabColliderUnion`
planner to the same cross-stage contract. It covers an isolated odd-sized
rectangle, the concave union of two overlapping rectangles, and two
edge-disconnected components. Reversing every legacy collider list preserves
the exact planned loops and `collision_001`/`collision_002` derived IDs; those
loops equal the canonical Prefab-v3 source before editor and generator compile
them. Both consumers reproduce four polygons, 20 exposed edges, 12 triangles,
and source `8b70a09b…bd96`, edge `1e605569…a1c6`, authored polygon
`355242dd…b57c`, placement `edc8b921…780f`, and triangle
`fcdff387…0ec5` signatures. Only the broad major-blocking-diagnostic fixture
gate remains open in this section.

## 23) Determinism And Golden Signatures

- [x] Add `authoring-polygons-v1` for canonical owner/shape/vertex/metadata
      records.
- [x] Add `authoring-placement-v1` for exact transformed/quantized placement
      records.
- [x] Reuse accepted Core `source-v1`/`edges-v1` signatures for compiled facts.
- [x] Add `authoring-seams-v1` for sorted reachable adjacency/signature records.
- [x] Add `authoring-migration-v1` for the sorted migration report.
- [x] Add `authoring-triangles-v1` for polygon IDs and deterministic triangle
      index triples.
- [x] Rebuild signatures from fresh objects and fresh Dart processes.
- [x] Reverse input file/map/shape order and prove canonical equality.
- [x] Rotate/reverse equivalent valid loops and prove explicit normalization
      reaches the same signature.
- [x] Mutate one coordinate, mode, metadata field, placement transform,
      reachable seam, or source identity and prove the relevant digest changes.
- [x] Prove Windows/Linux path normalization cannot change source-path ordering.
- [ ] Never update a reviewed golden merely to hide nondeterminism or semantic
      drift; record the cause in §26 first.

`authoring-polygons-v1` is owned by the pure-Dart Core terrain boundary. Each
length-prefixed record contains owner domain (`chunk`/`prefab`), stable owner
key and human ID, positive owner revision, stable shape ID, collision mode,
optional surface/material metadata, vertex count, and ordered half-pixel
integer ticks. Records sort by owner domain/key/shape ID and duplicate
owner-local identities fail closed. Per-chunk signatures include direct chunk
shapes plus each collision-contributing prefab owner once; placement count and
transforms remain exclusively in `authoring-placement-v1`. Empty collision
source has the explicit SHA-256 empty digest. The current shared fixture binds
Core, the staged generator artifact, and the editor adapter to digest
`679f918e4180e6192bf6b6285fba332df8c24e7a331b37490628fddb8261e9db`.
The pure-Dart `polygon-terrain-signature-probe-v1` rebuilds this contract plus
Core source/edge, placement, triangle, reachable-seam, isolated-seam, and exact
staged-artifact hashes from fresh objects. Two standalone Dart processes must
match the in-process records byte-for-byte. The staged artifact's reviewed
UTF-8 digest is
`434ae70aa2c2d89b81886589aa6a3734de864f41d1f5fc2d32cb643897f8ca84`.
Compiled chunks snapshot and canonically sort placement lineage and triangle
records, reject duplicate derived identities, and therefore cannot inherit
caller collection order. Core loop rotation/reversal tests assert both source
and edge signature equality after explicit normalization, while mutation
matrices bind every placement, triangle, seam-transition, and authored polygon
field to the relevant digest. Generator source identities use canonical
workspace-relative `/` paths and reject absolute, dot-segment, empty-segment,
drive-prefixed, or otherwise ambiguous spellings; Windows and POSIX separator
spellings therefore produce identical records and ordering.

`authoring-triangles-v1` is also owned by the pure-Dart Core terrain boundary.
`TerrainTriangulator` consumes only the compiler-normalized clockwise physics
loop, chooses the first valid ear in surviving canonical-index order with exact
`BigInt` predicates, and proves `n - 2` positive triangles plus exact doubled
area before returning immutable indices. The shared triangle record sorts by
chunk/placement/shape/index identity and rejects exact duplicates. Generator
and editor parity use the same triangulator and record/signature functions;
the reviewed digest remains
`c1a718727f1a6c2f17cd4498b367a1a96989b4d3f5f455096e3e243bc5bc07d3`.

`authoring-migration-v1` is owned by the editor migration domain. Its sole
length-prefixed record contains the format label and the exact canonical
readiness-report-v2 JSON, so it transitively binds sorted source SHA-256 facts,
target before/after digests, revision decisions, prefab impacts, planned
polygon source, and blockers without adding a self-referential field to the
report. The collision-reset legacy state goldens to
`c355c5de8af15880881e147a031c054f60642f75f5102d23a2691b97a24d0beb`;
its equivalent canonical current-schema state goldens to
`d98983c44505bbdbdbe3f1f4482006be9ea67060091613b1b0f8b3b2ca198153`.
Changing only reviewed source bytes changes the digest. Existing short FNV
fingerprints remain compatibility/display evidence, and the CLI report bytes
and write authorization are unchanged. Two standalone migration-check Dart
processes over the same temporary workspace must emit byte-identical canonical
reports and reproduce the reviewed legacy digest above.

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
- [x] staged v3/v2 schema versions, canonical round-trip, and strict legacy
      field rejection
- [x] strict prefab-v1/v2 and chunk-v1 parsing of the complete repository
      without normal-store defaults or normalization
- [ ] normal-store `migration_required` behavior after source cutover
- [x] stable shape IDs/list order/equality/copy behavior
- [x] canonical winding/start and explicit normalization

Geometry/compiler:

- [ ] simple/concave polygons and every invalid topology class
- [x] shared boundaries versus positive-area overlap
- [ ] minimum edge/area and hard limits
- [x] transform order, reflection, rational scale, quantization
- [x] Core preview/generator signature parity

Migration:

- [x] isolated/multi/overlapping/touching/disconnected rectangles
- [x] hole and point-only ambiguity blockers
- [x] flat ground with zero/one/multiple gaps
- [x] exact corrected audit counts and zero unclassified blockers
- [x] stable report/order/IDs across repeated and permuted checks
- [x] exact source SHA-256 binding plus changed/missing/ambiguous drift audit
- [x] stable unchanged revision decisions and deterministic prefab placement
      impact records across repeated checks
- [x] default/explicit check, report-only write, usage/blocker exit codes,
      malformed source, invalid target, and authored-path rejection
- [x] post-cutover current-schema no-op, mixed-generation rejection,
      canonical-byte enforcement, Core geometry re-review, and zero-pending
      report idempotence
- [ ] write transaction, source-drift abort, rollback, and write idempotence

Stores/plugins:

- [ ] load/validate/edit/pending diff/export for prefab v3 and chunk v2
- [ ] atomic paired prefab/tile writes and one-file chunk writes
- [ ] route/session/workspace switching with polygon draft state
- [x] create/duplicate/rename/deprecate revision semantics in the explicit
      write-locked Prefab-v3 and Chunk-v2 documents
- [x] downstream prefab impact preview without chunk mutation
- [x] invalid/global-seam issue export gating

UI/interactions:

- [ ] create/close/cancel polygon
- [x] shape/edge/vertex selection
- [x] drag vertex/shape with grid and half-pixel snap
- [ ] insert/delete/duplicate/normalize
- [x] one undo entry per gesture and deterministic redo
- [x] diagnostics focus the exact shape/vertex/edge
- [x] shared scene control parity on explicit Prefab and Chunk staging routes
- [x] read-only expanded prefab overlay in Chunk Creator
- [x] Core-owned actor eligibility/navigation and marker-placement overlays
- [x] preview consumes no marker RNG and preserves source ordering
- [ ] accessibility labels, keyboard controls, and narrow-window behavior

Generator/seams:

- [x] current-schema strict parsing
- [x] unknown prefab/source/scale/bounds diagnostics
- [x] staged polygon/edge/lineage output golden
- [x] concave triangulation count, winding, exact area, ordering, and golden
- [x] legacy orthogonal decomposition, flat-ground/gap projection,
      collision-reset parity, and diagonal/one-way rejection
- [x] all scheduler-reachable within/between pool/run transitions
- [x] dry-run generated drift/missing/unexpected output detection
- [x] staged sibling writes, post-write byte verification, rollback, and cleanup
- [x] fresh-process signatures and permutation invariance

The staged compiler diagnostic fixture proves unknown and cross-key/ID
ambiguous prefab resolution without fabricated output, with identical evidence
under reversed catalog order. Direct chunk and expanded prefab source-range
failures retain exact source, shape, and placement lineage. Invalid scale below
`0.3`, above `3.0`, or off the `0.1` step fails during strict parsing. A single
fixture with both direct and transformed prefab vertices outside closed Chunk
bounds produces the complete canonically sorted issue list and no compiled
product. These tests bind the generator boundary only; they do not close the
broader blocking-diagnostic inventory in §13.

The expanded staged matrix now also freezes strict malformed/missing/enum/
half-pixel/shape-ID failures and exact Core topology mappings for repeated
closing vertices, consecutive duplicates, too-few vertices, collinearity,
minimum area/edge, noncanonical start/winding, self-intersection, occupied
overlap, and post-transform minimum-edge collapse. Every compiled-path case
returns no product and retains exact source, placement, shape, element, code,
and canonical issue order. Lowercase-only stable shape IDs make a case-only
collision structurally unrepresentable: uppercase variants fail the ID grammar
and exact duplicates fail strict ordering. The broad §13/§22 gate remains open
because seam/output-drift, migration, remaining editor domains, and normal
export/cutover boundaries do not yet share the new explicit
severity/owner-key envelope. Self-touch/hole plus complete generator-facing
capacity/signature-mismatch evidence also remain incomplete.

The legacy-projection unit matrix covers exact orthogonal decomposition,
flat-ground/gap recognition, current 16-pixel snapping, input-order
invariance, fail-closed diagonal/one-way cases, and the exact full-chunk
collision-cleared exception. All eight repository targets are now represented
by a passing parity fixture. The complete editor, Core, generator, and replay
validator regressions also accept this intentional empty state while Docker
continues to run.

Regression:

- [x] all existing editor domains and route/session tests
- [x] full Core package and root Core tests
- [x] normal legacy game construction accepts the intentional empty collision
      state and remains deterministic through the resulting run end
- [x] replay-validator analysis/tests unchanged

## 26) Implementation Findings

Record every discovered contract mismatch or non-obvious design consequence
before changing the accepted plan.

| Finding | Resolution | Later-phase impact |
| --- | --- | --- |
| Current chunk selection draws from tier/group pools and authored runs, so file adjacency does not describe runtime adjacency. | Seam validation enumerates the scheduler's actual possible pair set. | Phase 5 can stitch only combinations already proven compatible without changing procedural pacing. |
| Legacy chunk rename changes source content/path without advancing revision, and a blank active chunk could enter scheduler pools before polygon authoring is complete. | Chunk v2 treats rename as a semantic owner edit and advances revision exactly once. A blank create starts deprecated at revision 1; a duplicate copies reviewed source and starts active at revision 1. | Normal forms must expose deliberate activation/deprecation. No new blank owner can affect procedural scheduling before terrain/seam review. |
| Prefab geometry changes can affect many chunks while those chunk JSON records remain untouched. | Pending changes report downstream placement/output impact, but only the prefab revision/source changes. | Phase 5 runtime identities must include referenced prefab revision/signature without forcing mass chunk revision churn. |
| Existing placement scales are decimal tenths; multiplying half-pixel source coordinates with binary doubles would make identity platform-sensitive. | Parse scale into an exact integer rational and quantize once after reflection/scale/translation. The initial editor-to-Core source adapter remains identity-transform-only until that primitive replaces the current double transform. | Generated world geometry and validator replay receive the same physics ticks on every platform. |
| Source-point construction multiplied an unchecked authored tick by the source-to-physics factor before range validation, so native integer overflow could occur before rejection. | Validate against an explicit source-tick limit before conversion and use overflow-safe comparison bounds. Promote exact authoring/compiler area, orientation, overlap, and line-key products to `BigInt`; keep this work outside per-tick contact. | Migration and editor validation can safely exercise the accepted coordinate limits without platform-dependent wraparound. |
| Phase 4 must stage polygon data while production still reads rectangles. | Source cuts over once; generation emits an unreachable staged terrain artifact and a bounded exact legacy projection for orthogonal current content. | Phase 5 removes the projection when streaming consumes staged terrain; no runtime toggle is introduced. |
| Phase 3 moved enemy AABBs into top-level constants so legacy collision and staged capsules share one definition, but the entity editor only parsed inline collider expressions. | Resolve a directly referenced top-level `ColliderAabbDef` initializer and bind edits to that initializer; keep unresolved/indirect shapes non-writable. | Enemy authoring remains operational through the Phase 4 source migration without duplicating capsule/AABB dimensions. |
| The earlier Phase 0 topology audit did not run the accepted one-world-unit minimum-edge predicate. Exact Core revalidation finds `0.5 px` exterior edges in `dark_menhir_01`, `dark_menhir_03`, and `ruin_stone_00`; 67/70 collision prefabs and 85/88 candidate loops pass unchanged. | Keep the global rule. Apply reviewed minimal outward corrections adding 34, 25, and 36 half-pixel-square ticks, guarded by exact expected collider lists. | All 70 prefabs / 88 loops now plan successfully with zero unclassified blockers. The correction catalog is migration-only and is removed after verified v3 source write; production source/runtime remain unchanged meanwhile. |
| Normal editor stores intentionally normalize compatibility input, so using them for migration checks could hide malformed legacy fields or bind a report to different semantics than the reviewed bytes. | Add a separate read-only legacy codec with exact prefab-v1/v2 and chunk-v1 fields/types/order, explicit v1 promotion, and SHA-256 of the parsed UTF-8 text. Report v2 records all nine source digests and exposes a pure canonical-path drift audit. | The future CLI must build from these strict documents and call the digest audit immediately before replacement; normal store behavior remains unchanged until cutover. |
| The strict prefab migration path reused normal rectangle-based `PrefabDef`, so replacing the normal model with polygon source would either break the frozen checker or retain `colliders` as a second editable authority. | Isolate immutable `LegacyPrefabDef`/`LegacyPrefabData` and the prefab-v2 total order in the migration layer; make strict parsing, planning, and v3 target conversion consume those types. | Normal `PrefabDef` can move to `collisionShapes` while the read-only legacy report keeps its exact reviewed semantics and fingerprints. |
| A polygon can touch the resolved visual rectangle only at an edge or point without occupying any of the visible source. | Define the required visual intersection as exact positive-area overlap. Preserve intentional outside extent and report each side in exact integer/`.5 px` units as a warning; do not clip. | Prefab export can distinguish malformed/unrelated collision (blocking) from deliberate oversized collision (visible, non-blocking) without inventing a render-based geometry test. |
| A normal authoring record must preserve malformed/noncanonical input for diagnostics, while a migration target must emit deterministic canonical bytes. | `PrefabV3Def` and `PrefabV3FileData` snapshot supplied order without rewriting it; `PrefabV3FileCodec` canonicalizes copied records only while encoding. | The future strict v3 store can diagnose source order before save, while migration output and revision comparisons stay deterministic. |
| Leaving prefab-v3 parsing inside the migration layer after promoting the normal model would create two structural authorities before store cutover. | Promote strict JSON/retained-metadata primitives to the neutral authoring domain and make the normal `PrefabV3FileCodec` the only v3 parser/serializer; the migration facade delegates to it. | `PrefabStore` can adopt the proven codec without importing migration code, while chunk-v2 migration parsing remains isolated until its own normal-store promotion. |
| `AuthoringDomainPlugin.applyEdit` returns only the next document and has no rejected-command diagnostic channel; putting a temporarily invalid drag into the document would create an invalid undo entry. | Keep gesture previews and their diagnostics page-local. Pass only a shared reducer commit to `PrefabV3CollisionCommitPolicy`; it verifies the before snapshot, owner rules, canonical order, resolved visual bounds, and revision before a plugin command is dispatched. | Prefab route wiring must display rejected policy issues without calling `applyEdit`; the plugin reuses the same policy as a defensive authority check for accepted commands. |
| The live prefab loader still constructs a v2 `PrefabDocument`, but plugin command, pending-diff, and export semantics need proof before the source-write gate opens. | Add a temporary `PrefabV3StagingDocument` that only explicit pre-cutover callers can supply. The normal loader never selects it, and exporting a changed staging document throws `prefab_v3_source_write_disabled` before any filesystem mutation. | At cutover, replace the v2 document with the v3 document and remove the staging name/type; the Prefab route can reuse the already-tested typed command and owner policy. |
| Inverse viewport projection yields fractional half-pixel coordinates, and rounding to a half-pixel before applying a coarser owner grid can select the wrong cell near the grid midpoint. | Add one shared snap-policy entry point that divides the fractional coordinate by the final exact grid step and rounds ties away from zero only once. | Prefab and Chunk pointer adapters must call the shared fractional snap rather than layering route-local rounding over integer snapping. |
| `EditorSessionController` notifies listeners for loading/export flags as well as document replacements, so blindly resynchronizing a route-local polygon controller on every notification would discard an active preview during a no-op export. | Track the observed document identity and resynchronize local geometry only when that immutable document instance changes; accepted local dispatches update the identity explicitly. | Future live Prefab/Chunk route controllers must keep transient session notifications from resetting selection, tools, drafts, or gestures. |
| Prefab-v3 still depends on the unchanged tile/module source file, but loading it through rectangle-era `PrefabData` would silently normalize malformed fields and keep legacy prefab parsing in the new path. | Add `PrefabTileFileData` and one strict normal-layer tile-v2 codec. The explicit v3 store loader composes the two strict file payloads directly and never calls the compatibility parser. | At cutover, normal Prefab load/save can adopt these two structural authorities together; the offline migration still owns legacy prefab parsing only. |
| Platform-module visual bounds were derived privately inside v2 validation, so implementing v3 owner bounds independently would create two geometry rules and could disagree for negative cells or non-tile-sized slices. | Promote one fail-closed `PrefabVisualBoundsResolver` and make existing v2 validation consume it. The v3 loader resolves every atlas/module owner through the same integer calculation. | Prefab scene placement and future Chunk expanded previews must consume this resolver rather than rebuilding module extents in widgets. |
| `ChunkCreatorPage` normally reloads v1 source after mounting, which would replace an explicitly supplied chunk-v2 staging document before its route-local workspace could bind an owner. | Select the page by staged scene type before the post-frame reload, disable shell reload/source apply for that type, and keep normal v1 load/reload behavior unchanged for every ordinary session. | At cutover, make the v2 document the normal plugin result and remove the temporary staging type/locked branch instead of retaining two route authorities. |
| A function-local metadata dialog disposed its `TextEditingController`s as soon as `showDialog` returned, but Flutter could still build the route during its exit animation. | Make the shared dialog a stateful route widget and let its State own/dispose both controllers when the widget is actually removed. Return an immutable metadata value; keep all owner mutation outside the dialog. | Future shared authoring dialogs must bind controller lifetime to widget lifetime, especially when route animations outlive the awaited result. |
| The initial Duplicate buttons translated copies by a fixed 2 px, so any wider polygon retained positive-area overlap with its source and the correct owner policy rejected the action. | Derive snap-aligned candidate offsets from current owner bounds, order them deterministically, choose the nearest conservative AABB-free candidate, and apply closed Chunk bounds before dispatch. Keep exact reducer/owner validation authoritative. | Prefab and Chunk duplication now starts from a useful safe default without introducing boolean geometry, silent overlap repair, or route-specific collision rules. |
| Prefab-v3 collision loops are stored relative to the prefab anchor, while the generic Core transform can also subtract a source anchor. Passing `anchorXPx`/`anchorYPx` during chunk expansion would therefore shift collision twice even though artwork preview looked correct. | Keep visual-anchor handling in the visual projection. Pass a zero Core source anchor for prefab-v3 collision, then apply reflection, exact scale, and placement translation through the shared transform. Lock the rule with a nonzero-anchor asymmetric fixture. | Generator placement expansion must consume the same anchor-relative schema rule and fixture; it must not copy the artwork-origin calculation into collision compilation. |
| Source-loop edges are not the same set as runtime collision edges after collinear splitting, internal-solid cancellation, and one-way filtering. A source-boundary inspector would confidently display edges that Core does not expose. | Paint and select only `TerrainGeometry.edges`. Keep nearest-segment hit testing as a read-only editor selection rule with canonical edge-ID ties, then read slope from `TerrainTraversalCache` and all other facts from the selected Core edge. | Actor eligibility, navigation, seams, and generated debug views must consume the same compiled edges rather than source fill or render triangles. |
| The Phase 4 overlay wording grouped Éloïse with walk/jump/drop graph evidence, but Phase 3 deliberately publishes graph profiles only for Grojib and Hashash; player movement is command-driven and Core owns no Éloïse pathfinding graph. | Show Éloïse's exact accepted 60-degree support eligibility only. Reuse the immutable Phase 3 runtime bundle for Grojib/Hashash graph views, and label the absent player graph explicitly instead of synthesizing jump/drop reachability in the editor. | A future player pathfinding or grounded-ability feature must first add its own Core-owned profile/query contract; the editor cannot become that gameplay authority by preview convention. |
| `PlacedMarkerDef.y` exists for editor positioning, but generated `SpawnMarker` deliberately omits it and runtime derives body Y from the selected support. Treating the editor anchor as a body transform would produce a new placement authority. | Retain and display authored X/Y, but use only marker X, level `groundTopY`, exact compiled support identity, the catalog capsule, and the Phase 3 placement resolver for physics evidence. Missing level ground context is a blocking staged marker-contract error. | Phase 5 streaming must carry exact support identity while preserving the existing rule that marker Y is not a gameplay transform. |
| Hashash authored markers consume a roll and contribute a count, but runtime later places each accepted count at the visible camera-right chunk edge; the authored marker X/placement is not a direct body candidate. Procedural item candidates likewise have no authored marker records. | Classify Hashash as guaranteed/conditional deferred without invoking placement or RNG. Do not fabricate collectible/restoration candidates. State explicitly that projectile terrain is later-phase work and not previewed. | Phase 5 may preview deferred Hashash and procedural item candidates only from a scheduler/runtime harness that preserves camera state, candidate loops, attempt counts, and RNG ordering. |
| Legacy `obstacleTop` searches static solids, while staged polygon source has no general authored semantic saying that an arbitrary direct chunk polygon is an obstacle. | During the locked Phase 4 staging bridge, select the highest solid upward placed-prefab surface at marker X for `obstacleTop`; select direct solid terrain at exact level `groundTopY` for `ground`; select the physically highest upward surface before actor filtering for `highestSurfaceAtX`. Equal heights use canonical edge identity. | Before normal cutover, generated terrain/source semantics must keep this distinction explicit or replace it with a reviewed stable surface classifier; widgets must not infer it from render layers. |
| A directory neighbor is not a runtime neighbor: tier fallback can skip empty early/easy/normal/hard pools, assembly groups filter each requested tier independently, variable authored runs cross tier boundaries, and distinct selection removes same-chunk pairs only while the resolved pool remains identical. | Snapshot immutable `LevelDef` scheduler data with chunk-v2 staging and enumerate finite tier-window, tier-boundary, within-run, between-run, loop/non-loop hard-tail, group, fallback, direction, and distinct-pool transitions without sampling RNG or changing selection. A differential fixture proves every sampled Core transition is contained. Core owns the canonical `authoring-seams-v1` record/signature, and editor plus staged generator verify the same checked-in transition golden. | The §21 generator must consume that verified manifest to compare actual compiled boundaries before rendering; it must not reconstruct adjacency from file order. |
| Physical seam cancellation, traversal stitching, and render material phase do not have the same compatibility key. Core traversal joins require collision mode and `surfaceKind`, while material continuity remains a Phase 5 render concern. | Core owns exact compiled boundary derivation/comparison. Block coverage or continuation-vertex differences keyed by collision mode and surface kind in both editor and staged generator. Retain full edge geometry and `materialKey` in canonical evidence, but do not make material differences a Phase 4 physical blocker. The renderer accepts only a privately constructed seam-validated batch. | Phase 5 can promote reviewed material-phase evidence when world-anchored rendering exists without weakening the already-proven collision/navigation seam. |
| Authored assembly tier windows and run counts currently have no small schema cap, so a malformed but parseable level could make exhaustive finite-window analysis consume unbounded editor time. | Enumerate non-assembly tiers in constant structural time and fail closed above 256 finite pre-hard chunks when assembly is enabled; still enumerate the structurally complete hard tail and report `chunk_v2_scheduler_analysis_capacity_exceeded`. | A future higher authoring limit requires a reviewed symbolic scheduler or measured capacity change, not silently removing the guard. |
| Deprecated chunk-v2 records remain useful migration/history owners but should not become new scheduler candidates. | Preserve and display deprecated owners while excluding them from active seam pools, matching existing active assembly-count semantics. | The §21 current-schema generator must apply the same status filter; normal legacy generation is deliberately unchanged in this staging slice. |
| The generator's former `--dry-run` returned immediately after source validation, so it could not detect deleted, stale, or orphaned committed outputs. Treating every Dart file below broad output directories as owned would also create false positives. | Render all five expected outputs into one immutable artifact plan, compare exact UTF-8 bytes without writing, and discover unexpected files only by the generator ownership marker. Sort diagnostics by canonical display path and fail nonzero for missing, stale, unexpected, or unreadable expected files. | Every staged terrain artifact must be registered in the same plan and carry the ownership marker. The one-time source migration retains its separate source-fingerprint and transaction gates. |
| Replacing generated files sequentially could leave a mixed old/new output set after a later write failed; a single filesystem operation cannot atomically replace files in multiple directories. Alias paths such as `nested/../output.dart` could also target the same file twice. | Reject canonically duplicate absolute paths, flush every render to a unique sibling file, move existing targets to sibling backups, install and re-read every output byte-for-byte, then remove backups. On failure, restore in reverse order and report whether rollback was complete; cleanup failure after a verified commit is distinguished explicitly. | Staged polygon artifacts inherit the transaction automatically when added to the artifact plan. This does not satisfy or replace the migration CLI's source-drift recheck and nine-file schema write transaction. |
| Current repository source is still prefab-v2/chunk-v1, so selecting strict v3/v2 parsing in the live generator before the coordinated migration would make every normal generation fail. Importing editor code into the root generator would also reverse the editor/tool boundary and pull Flutter-oriented package structure into repository generation. | Add focused pure-Dart staged source and compilation files plus one checked-in v3/v2 fixture. Keep them unreachable from `generate_chunk_runtime_data.dart` until the source transaction is ready, and compare their Core signatures with the editor's existing strict codecs/expansion over the same bytes. | The cutover must wire these functions into the single entry point in the same change as source migration, legacy projection, seam validation, and staged Dart artifact registration; the fixture does not authorize an alternate production flag. |
| Legacy collider unions defaulted every migrated loop to `solid`, even though the current generator treats platform prefabs as top-only one-way collision. | Apply prefab-kind sidedness after geometric union: 66 repository obstacles are `solid`, 4 platforms are `oneWay`, and colliding decoration/unknown kinds fail closed. Reapply the rule during v3 target construction as a defensive boundary. | The legacy projector and Phase 5 terrain consumer may trust authored collision mode instead of consulting prefab kind again; canonical migration fingerprints intentionally change with the corrected physical contract. |
| The pre-reset repository compilation rejected 24 positive-area overlaps across six migrated chunks. The user chose clean reauthoring instead of defining a solid-owner union rule. | Keep overlap diagnostics strict. Delete every authored static collider, preserve visuals/metadata/placements/markers, encode no ground in all eight chunks, and prove the collision-cleared targets project exactly with zero blockers. | Reauthor polygon ground, slopes, platforms, and obstacles before Phase 5/playable acceptance; close enemy support/navigation and marker placement against that new terrain. Any future overlap, especially involving `oneWay`, remains rejected. |
| Chunk width is 600 pixels, which is not divisible by the legacy 16-pixel gap grid, but the collision reset must express exactly zero ground without changing chunk dimensions. | Permit only the exact `x = 0`, `width = chunkWidth` full-ground-removal gap as a grid exception and project it with stable ID `collision_cleared`. Keep every partial gap on the existing grid. | Chunk v2 represents empty direct terrain without a sentinel; remove the legacy exception with the flat-ground/gap source bridge. |
| `TerrainCompiler.compile` intentionally canonicalizes safe loop winding/start, which is correct for runtime safety but could hide noncanonical current authoring bytes during generation. | Pre-review every staged input with `TerrainSourceCanonicalizer(requireCanonical: true)` and fail on its stable diagnostics before accepting compiled output. Parsing retains exact authored half-pixel values; Core range failures become staged generator issues rather than raw parser exceptions. | Normal generation can reject authoring drift while still using the accepted compiler as the sole topology/transform/edge authority. An explicit editor Normalize action remains the only path that rewrites a loop. |
| Render triangulation must not become a second polygon normalization or collision-edge authority. | Core owns `TerrainTriangulator` and the `authoring-triangles-v1` record/signature. Ear-clip only the normalized `TerrainGeometry.polygons` loop with exact BigInt orientation/containment, choose the first surviving canonical vertex ear, retain indices into that loop, require `n - 2` positive triangles, and prove exact doubled area. Generator and editor consume the same Core contracts. | Phase 5 rendering consumes these indices; it must never triangulate independently or reconstruct collision edges from triangles. |
| The standalone migration CLI imported full Prefab/Chunk stores only to reuse two source-path constants. Later staging growth made the Chunk store transitively import Flutter models, so `dart run tool/migrate_polygon_authoring.dart` lost access to `dart:ui` even though migration logic remained pure. | Move the two canonical paths into a Flutter-free `RepositoryAuthoringPaths` contract. Stores retain their public constants as aliases; migration check/command import only the pure path contract. Add a subprocess test that locates the standalone Dart SDK from `flutter_tester` and compiles the real `--help` entrypoint. | Offline migration/generator tools must not import store/plugin graphs for constants. Any future store dependency is caught by the standalone-Dart regression before source-write authorization can rely on a broken checker. |
| Placement-lineage and triangle signatures were canonical only while callers happened to preserve parser order, and Core source identity retained host-specific path separators. | Make the immutable compiled chunk own canonical sorting and duplicate-identity rejection for both derived record families. Normalize generator source paths to safe workspace-relative `/` identities before compilation, then bind all signature families and exact rendered bytes in a standalone-Dart probe with permutation and one-field mutation tests. | Live generator cutover must derive every source identity through the same canonical helper and must not use filesystem-native path spelling as authored or runtime identity. |
| Extending the original staged artifact fixture with transform extrema and terrain-topology cases would change already-reviewed artifact bytes for coverage unrelated to that fixture's render contract. | Add a second independent canonical Prefab-v3/Chunk-v2 fixture and signature golden for transform/terrain parity; keep the original artifact fixture byte-identical. | Future parity coverage must extend the fixture whose contract it changes, or add another focused fixture, instead of silently rewriting an established golden. |
| The §13 prose describes one diagnostic envelope with explicit severity and owner key, but strict current-schema parsing still throws path-rich `FormatException`s while Core and staged-generator issues use different fields and infer blocking severity from context. | Add pure-Dart Core `TerrainAuthoringIssue` as the portable envelope and Core-diagnostic adapter. Normalize strict prefab/chunk parse failures at the staged generator raw-source boundary, use the envelope throughout staged compilation, and preserve its owner key through Chunk-v2 collision `ValidationIssue`. Keep the broad gate open for unadapted domains rather than adding JSON/editor/filesystem concepts to Core. | Normal editor export and the coordinated generator cutover must still route seam, output-drift, migration, and remaining editor-domain failures through the same actionable envelope without weakening their layer-specific authorities. |
| Stable polygon shape IDs are lowercase by grammar, so two accepted IDs cannot differ only by case. | Reject uppercase/mixed-case IDs at strict parsing, reject exact duplicates through canonical ordering, and test both paths instead of adding a redundant case-folded accepted-ID map. | Normal v3/v2 stores and migration output must retain the lowercase stable-ID grammar; a future grammar expansion would require an explicit case-collision rule and migration. |

Append rows during implementation. Do not silently relax source, compiler,
seam, determinism, or performance contracts.

## 27) Documentation

During implementation:

- [x] document the delivered pre-schema source/canonicalization/overlap/exact
      placement boundary in `docs/tdd/polygon_terrain_authoring_foundation.md`
- [ ] create a focused TDD for source schema ownership, transform order,
      migration, generation, identity lineage, diagnostics, and staging
- [x] update `docs/tdd/sloped_navigation_and_enemy_terrain.md` only for the
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
| 2026-07-29 / `49247e45` | Reviewed prefab collision corrections | Flutter test VM on Windows | Editor analysis clean; 10 focused planner tests and all 209 editor tests pass. Exact source guards and approved positive area deltas resolve the three minimum-edge records; all 70 collision prefabs / 88 loops pass Core with no authored-source or runtime writes. |
| 2026-07-29 / `a8eff1e5` | Read-only legacy chunk ground planner | Flutter test VM on Windows | Editor analysis clean and all 217 editor tests pass, including 8 chunk migration tests. Zero/one/multiple/adjacent/full-width pits, invalid bounds/types, nested overlaps, exact area, and current-repository output are covered; 8 chunks produce 9 Core-valid ground shapes. |
| 2026-07-29 / `e1fa53f1` | Aggregate polygon-authoring check plan and canonical report | Flutter test VM on Windows | Editor analysis clean and all 220 editor tests pass. The complete current plan reports 99 prefabs, 70 collision prefabs, 88 prefab shapes, 8 chunks, 1 legacy gap, 9 ground shapes, 3 reviewed corrections, and 0 blockers. Report fingerprint is `f2a9c639`; input reversal and host path separators do not change it. No CLI, schema, source, or runtime write path is enabled. |
| 2026-07-29 / `0a7d8a40` | Isolated prefab-v3 and chunk-v2 target documents/codecs | Flutter test VM on Windows | Editor analysis clean; 5 focused target-codec tests and all 225 editor tests pass. The complete 99-prefab/8-chunk planned output strictly round-trips. Legacy versions/fields, unknown fields, noncanonical order, off-grid coordinates, off-step scales, and wrong numeric types reject. Normal stores, source files, and runtime authority remain unchanged. |
| 2026-07-29 / `feb925fa` + `da334c3f` | Shared fail-closed migration JSON and retained-metadata parsing | Flutter test VM on Windows | Focused analysis clean and all 5 target-codec tests remain green. Structural/type/order/default rules now have one migration-scoped implementation shared by legacy and target codecs. |
| 2026-07-29 / `1caced16` | Strict legacy prefab-v1/v2 and chunk-v1 source codecs | Flutter test VM on Windows | Focused analysis clean and 9 legacy/target codec tests pass. All 99 current prefabs and all 8 chunks parse directly from repository text; unknown fields, wrong numeric types, invalid scales, and noncanonical current-schema order reject. Prefab-v1 defaults are promoted only after strict parsing. |
| 2026-07-29 / `7ef9c92d` | Exact source-digest plan binding and drift audit | Flutter test VM on Windows | Editor analysis clean and all 231 editor tests pass. Report v2 contains canonical path plus SHA-256 for the prefab file and all 8 chunks, remains invariant under input reversal/path separators, and has fingerprint `cc2ed2e6`. Missing, malformed, changed, absent, and ambiguously canonicalized signatures fail closed. `crypto` was promoted from transitive to direct editor dependency; no authored JSON, normal store, CLI write, or runtime authority changed. |
| 2026-07-29 / `c3637865` | Complete read-only repository check and in-memory targets | Flutter test VM on Windows | Focused migration analysis clean and 14 migration/check/target tests pass. The current check strictly builds 9 target files, records 107 unchanged revision decisions and 99 prefab impact records covering 50 placements, rejects unknown placement references, and reports strict target failures without source writes. Readiness report v1 fingerprint is `90fbd996`. |
| 2026-07-29 / `15b2aa56` + `afa5c7d9` | Pure-Dart model boundary and read-only migration CLI | Dart VM and Flutter test VM on Windows | Plain `dart tool/migrate_polygon_authoring.dart --check` succeeds with 99 prefabs, 8 chunks, and 9 validated targets. Editor analysis is clean and all 241 editor tests pass; root chunk-generator dry-run still validates 8 chunks, 2 levels, and 2 themes. Six command tests cover default/explicit check, report-only output, usage and blocker exit codes, malformed source, invalid target, and authored-path protection. `--write` remains unavailable; authored JSON and runtime authority are unchanged. |
| 2026-07-30 / `20f04846` + `65fde7f6` | Post-cutover read-only migration idempotence | Dart VM and Flutter test VM on Windows | Editor analysis is clean and all 250 editor tests pass. Legacy v1/v2+v1 still yields nine pending targets and report-v2 fingerprint `14297a48`; a fully current v3+v2 fixture yields the same 107 revision and 99 impact records covering 50 placements, nine byte-identical targets, zero pending files, and fingerprint `4116ae04`. Focused tests reject partial cutover, mixed chunk generations, malformed or byte-noncanonical current source, unsafe Core geometry, unknown prefab references, and source drift. `--write` remains unavailable; authored JSON and runtime authority are unchanged. |
| 2026-07-30 / `9ad77ce4` + `5627d069` | Shared polygon interaction state and scene projection | Dart VM and Flutter test VM on Windows | Editor analysis is clean; all 273 editor tests and 23 focused interaction/projection tests pass. The pure reducer covers selection/tool state, ordered drafts, exact half-pixel/owner-grid snap, vertex/shape gestures, provisional edge insertion, cancellation, one before/after history commit, deterministic duplication, metadata edits, explicit Normalize, and Core geometry/overlap rejection. The framework-neutral scene projection exposes draft/preview/selection state; hit tests use closest vertex, edge, then fill with stable selected/topmost/index/ID tie-breaks. Migration check still reports nine legacy pending files and generator dry-run validates 8 chunks, 2 levels, and 2 themes. No route, store, authored JSON, generator output, or runtime authority changed. |
| 2026-07-30 / `a7ad6a9f` | Shared polygon viewport transform and source-scene painter | Flutter test VM on Windows | Editor analysis is clean and all 278 editor tests pass. Five focused painter tests cover exact half-pixel projection, fractional inverse pointers, invalid transform inputs, structural repaint decisions, solid/one-way styles, selected/preview shapes, and open drafts. The migration check still reports nine legacy pending files without writing source; generator dry-run still validates 8 chunks, 2 levels, and 2 themes. Compiled collision-edge diagnostics and Prefab/Chunk route wiring remain pending. |
| 2026-07-30 / `02452ba9` | Migration-owned legacy prefab model isolation | Dart VM and Flutter test VM on Windows | Editor analysis is clean and all 278 editor tests pass; 33 focused legacy-codec/plan/target/check/command tests pass. Strict prefab-v1/v2 parsing, deterministic ordering, migration planning, and prefab-v3 target conversion now use migration-owned rectangle records instead of normal `PrefabDef`. The CLI still reports 99 prefabs, 8 chunks, nine validated pending targets, and no source write. Normal editor/source/runtime behavior is unchanged. |
| 2026-07-30 / `67f606a3` | Prefab-v3 polygon owner validation | Dart VM and Flutter test VM on Windows | Editor analysis is clean and all 285 editor tests pass. Seven focused tests cover colliding/decoration contracts, Core canonical policy, occupied overlap versus shared boundaries, Core prefab capacity, exact anchor-relative visual intersection, outside-extent warnings, and unresolved-bound argument safety. The migration check still reports nine legacy pending files without writing source; generator dry-run still validates 8 chunks, 2 levels, and 2 themes. Normal `PrefabDef` and source remain v2 pending the model/store cutover. |
| 2026-07-30 / `bf45dda0` | Normal prefab-v3 polygon record and migration-target reuse | Dart VM and Flutter test VM on Windows | Editor analysis is clean and all 289 editor tests pass. Four focused tests cover immutable source snapshots, preserved author order, equality/copy/revision semantics, v3 JSON, and target-only shape/tag canonicalization. The read-only CLI still reports 99 prefabs, 8 chunks, and nine pending target files without source writes; generator dry-run still validates 8 chunks, 2 levels, and 2 themes. The v2 store, UI, authored JSON, and runtime authority are unchanged. |
| 2026-07-30 / `a3ded392` | Normal strict prefab-v3 file model/codec authority | Dart VM and Flutter test VM on Windows | Editor analysis is clean and all 293 editor tests pass. Four new focused tests cover immutable file snapshots, copy-only canonical ordering, strict v3 rejection, duplicate stable-key rejection, invalid-model serialization refusal, and byte-stable round trips. Shared strict JSON/metadata and terrain-shape parsing moved out of migration ownership; the migration facade delegates prefab-v3 work to the normal codec. The CLI still reports 99 prefabs, 8 chunks, and nine pending targets without writes; generator dry-run still validates 8 chunks, 2 levels, and 2 themes. `PrefabStore`, UI, source JSON, and runtime authority remain v2. |
| 2026-07-30 / `ea2ba62c` | Prefab-owned polygon commit/revision policy | Dart VM and Flutter test VM on Windows | Editor analysis is clean and all 300 editor tests pass. Seven focused policy tests cover one accepted revision bump, no-op identity, stale gesture rejection, obstacle/decoration contracts, warning-only outside extent, stable owner lookup, canonical shape order, and unresolved visual bounds. The policy returns the original immutable document for every rejected/no-op edit so session history cannot record invalid geometry. The CLI and generator guards remain unchanged and read-only; plugin/page dispatch is still pending. |
| 2026-07-30 / `f039cedc` | Read-only prefab-v3 plugin command staging | Dart VM and Flutter test VM on Windows | Editor analysis is clean and all 304 editor tests pass. Four focused plugin tests cover typed accepted commits, revision/pending-diff projection, invalid/stale/malformed/no-op identity, unresolved visual bounds, clean no-op export, and the changed-document source-write lock with an empty temporary filesystem. Migration check still reports 99 prefabs, 8 chunks, and nine pending target files without writes; generator dry-run still validates 8 chunks, 2 levels, and 2 themes. The normal loader, Prefab route, authored JSON, and runtime authority remain v2. |
| 2026-07-30 / `56334aef` | Staged Prefab polygon route coordinator and scene surface | Dart VM and Flutter test VM on Windows | Editor analysis is clean and all 311 editor tests pass. New focused tests cover direct fractional grid snapping, local multi-update previews, one accepted plugin/session commit and revision bump, owner rejection with immutable diagnostics, active-preview-first undo, session undo/redo resynchronization, transient export notifications, shared painter projection, tool-driven vertex drag, Escape, Delete, Ctrl-Z/Ctrl-Shift-Z, and Ctrl-drag pan without document mutation. Migration check still reports 99 prefabs, 8 chunks, and nine pending target files without writes; generator dry-run still validates 8 chunks, 2 levels, and 2 themes. The surface requires an explicit staging document and is not selected by the normal v2 Prefab Creator route. |
| 2026-07-30 / `474c6d98` | Strict read-only prefab-v3 staging loader | Dart VM and Flutter test VM on Windows | Editor analysis is clean and all 318 editor tests pass. Four retained tile-v2 codec tests cover current-source byte round-trip, copy-only canonicalization, strict type/field/order rejection, duplicate module identity, and duplicate cell position. Three fixture tests cover strict prefab-v3/tile-v2 composition, atlas and negative-cell platform bounds, immutable atlas metadata, scene projection, clean pending/export behavior with byte-identical files, legacy-version rejection, and missing-tile failure. The migration and generator guards remain unchanged and read-only. Normal `loadFromRepo`, save, current authored JSON, and runtime authority remain v2/legacy. |
| 2026-08-01 / `2c480d17` | Anchor-aligned prefab polygon visual-source projection | Flutter test VM on Windows | Editor analysis is clean. Focused tests prove atlas slices use `(-anchorX, -anchorY)` prefab-local placement and negative platform-module cells normalize against complete module bounds before the same anchor transform. Decoded images stay in a workspace-scoped cache; missing images render deterministic fallbacks. No source/store/runtime authority changed. |
| 2026-08-01 / `01824736` | Explicit prefab-v3 polygon staging workspace | Dart VM and Flutter test VM on Windows | Editor analysis is clean and all 321 editor tests pass. The route test covers explicit scene routing, locked source apply, owner-local draft isolation, route-shortcut cancellation, atlas/module selection, visible `1 px`/`0.5 px` snap, exact odd half-pixel ticks, one revision/undo entry, undo/redo synchronization, stable diagnostic focus, and staged pending owner IDs. Migration check still reports 99 prefabs, 8 chunks, and nine pending targets without writes; generator dry-run still validates 8 chunks, 2 levels, and 2 themes. Ordinary v2 load/save, authored JSON, and runtime authority remain unchanged. |
| 2026-08-01 / `e3a07975` | Exact numeric polygon vertex editing | Dart VM and Flutter test VM on Windows | Editor analysis is clean and all 325 editor tests pass. Parser tests cover signed integer, `.0`, `.5`, comma-decimal, malformed, fractional, overflow, and canonical formatting cases. Reducer and route tests prove exact odd ticks, invalid-loop rejection, retained vertex selection after canonical ordering, owner-policy dispatch, and one accepted revision increment. Migration check and generator dry-run remain clean and read-only; normal v2 source/runtime authority is unchanged. |
| 2026-08-01 / `a0da6638` | Normal strict chunk-v2 file model/codec authority | Dart VM and Flutter test VM on Windows | Editor analysis is clean and all 329 editor tests pass. Four direct normal-layer tests cover immutable author-order snapshots, copy semantics, copy-only canonical tag/layer/placement/marker/shape ordering, retained metadata, byte-stable round trips, strict legacy/unknown/type/order/grid/scale rejection, and invalid-model serialization refusal. Migration aliases/facades now delegate chunk-v2 structure to the normal chunk layer; the read-only check still reports 99 prefabs, 8 chunks, and nine pending targets without writes, while generator dry-run still validates 8 chunks, 2 levels, and 2 themes. `ChunkStore`, live UI, authored JSON, generator input, and runtime authority remain v1. |
| 2026-08-01 / `d96b6509` | Explicit strict chunk-v2 staging workspace | Dart VM and Flutter test VM on Windows | Editor analysis is clean and all 334 editor tests pass. Five fixture tests prove an all-v2 chunk tree composes with strict prefab-v3/tile-v2 data, immutable source baselines, deterministic active-level scene projection, Core-reviewed direct geometry, closed direct-owner bounds, known prefab references, canonical pending diffs, clean no-op export, and a changed-source lock that preserves every fixture byte. Legacy v1 normal loading remains selected and explicit staging rejects v1/case-colliding sources. The migration check still reports 99 prefabs, 8 chunks, and nine pending targets without writes; generator dry-run still validates 8 chunks, 2 levels, and 2 themes. Placement expansion, chunk polygon commands/UI, normal schema cutover, authored JSON, generator input, and runtime authority remain unchanged. |
| 2026-08-01 / `cdd09292` | Chunk-owned polygon commit and revision policy | Dart VM and Flutter test VM on Windows | Editor analysis is clean and all 343 editor tests pass. Nine new policy/plugin tests cover one accepted direct-owner replacement and revision bump, retained metadata, no-op and stale identity, closed bounds, Core occupied-area overlap, duplicate IDs, canonical shape order, malformed/missing-owner rejection, one canonical pending diff, and the changed-source export lock on an empty filesystem. Document validation and commits now reuse one owner validator. Migration check remains read-only with 99 prefabs, 8 chunks, and nine pending targets; generator dry-run still validates 8 chunks, 2 levels, and 2 themes. Chunk route UI, placement expansion, remaining v2 metadata commands, normal source cutover, generator input, and runtime authority remain unchanged. |
| 2026-08-01 / `e3565e7e` | Staged Chunk polygon route controller and scene surface | Dart VM and Flutter test VM on Windows | Focused analysis is clean and 16 related tests pass, including six new tests for local multi-update preview, one accepted revision/history entry, exact rejected-owner diagnostics, explicit staging enforcement, shared painter projection, tool-driven selection/drag, Escape, Delete/history, and Ctrl-drag pan without document mutation. Generic diagnostics now retain shape/element identity. Normal v1 loading, source JSON, generator input, and runtime authority remain unchanged. |
| 2026-08-01 / `603178ee` | Explicit chunk-v2 polygon staging workspace | Dart VM and Flutter test VM on Windows | Editor analysis is clean and all 350 editor tests pass. The route test proves explicit staged type dispatch without a legacy reload, active-level owner filtering/rebinding, a locked shell reload/source-apply boundary, one revisioned direct-owner deletion, pending diff projection, and route-level undo restoration; the complete legacy Chunk Creator suite remains green. Migration check still reports 99 prefabs, 8 chunks, and nine pending targets without writes; generator dry-run still validates 8 chunks, 2 levels, and 2 themes. Placement expansion, normal schema cutover, authored JSON, generator input, and runtime authority remain unchanged. |
| 2026-08-01 / `5a893dd5` | Shared exact polygon vertex inspector | Dart VM and Flutter test VM on Windows | Editor analysis is clean and all 350 editor tests pass. Prefab and Chunk staging now use one exact coordinate field widget without changing existing Prefab keys/behavior. The expanded Chunk route test covers malformed quarter-pixel rejection before dispatch, accepted odd half-pixel ticks with one revision/pending owner, undo restoration, and an out-of-bounds owner rejection that retains typed text and diagnostic while creating no history. Migration check remains read-only with 99 prefabs, 8 chunks, and nine pending targets; generator dry-run still validates 8 chunks, 2 levels, and 2 themes. Normal v2/v1 source and runtime authority remain unchanged. |
| 2026-08-01 / `c3be3ed2` | Shared polygon metadata dialog | Dart VM and Flutter test VM on Windows | Editor analysis is clean and all 350 editor tests pass. Prefab and Chunk staging now share one state-owned collision-mode/surface/material dialog. The Chunk route test proves trimmed optional metadata, a `oneWay` semantic commit with exactly one revision/pending owner, undo restoration, and safe text-controller disposal after the dialog exit animation. Migration check remains read-only with 99 prefabs, 8 chunks, and nine pending targets; generator dry-run still validates 8 chunks, 2 levels, and 2 themes. Normal v2/v1 source and runtime authority remain unchanged. |
| 2026-08-01 / `704e2c67` | Deterministic safe polygon duplicate placement | Dart VM and Flutter test VM on Windows | Editor analysis is clean and all 354 editor tests pass. Four pure tests cover nearest right-side selection, odd half-pixel extent rounding to the owner grid, input-order invariance around occupied candidates, and a closed owner with no free slot. The Chunk route test proves a wide terrain shape duplicates without occupied overlap, stays in bounds, receives the lowest-free ID, changes one revision/pending owner, and restores through undo. Migration check remains read-only with 99 prefabs, 8 chunks, and nine pending targets; generator dry-run still validates 8 chunks, 2 levels, and 2 themes. Normal source and runtime authority remain unchanged. |
| 2026-08-01 / `561e7353` | Exact staged prefab collision expansion and read-only Chunk overlay | Dart VM and Flutter test VM on Windows | Editor analysis is clean and all 360 editor tests pass. Six pure expansion tests prove anchor-relative collision with a nonzero visual anchor, exact reflection/rational scale/translation, stable placement/prefab/shape lineage, combined direct/placed occupied-overlap rejection, retained post-quantization bounds evidence with exact coordinates, missing/ambiguous reference and off-step scale rejection, Core prefab-shape capacity, and input-order edge-signature parity. The Chunk route test proves the quantized overlay is present, locked and lineage-labelled, reports direct/expanded shape and exposed-edge capacity separately, and leaves direct editing/history intact. Migration check still reports 99 prefabs, 8 chunks, and nine pending targets without writes; generator dry-run still validates 8 chunks, 2 levels, and 2 themes. Normal v1/v2 source, authored JSON, generator input, and runtime authority remain unchanged. |
| 2026-08-01 / `8e7d7a8b` | Core-compiled edge overlay and exact read-only inspection | Dart VM and Flutter test VM on Windows | Editor analysis is clean and all 364 editor tests pass. Four pure tests cover exact signed physics/slope fixed-point formatting, nearest finite-segment selection, canonical corner ties, no-hit and malformed-input behavior, and Core traversal-cache angle lookup. The Chunk route test proves Core exposed edges render independently of source fills, inspection selects/highlights the canonical direct edge, displays exact ID/tangent/normal/slope/mode/lineage/joins/adjacency/diagnostics, creates no revision or pending change, and returns to normal direct editing when disabled. Migration check remains read-only with 99 prefabs, 8 chunks, and nine pending targets; generator dry-run still validates 8 chunks, 2 levels, and 2 themes. Normal source, generator input, and runtime authority remain unchanged. |
| 2026-08-02 / `f9818787` | Core-owned actor terrain and navigation diagnostics in Chunk staging | Dart VM and Flutter test VM on Windows | Editor and Core analysis are clean; all 366 editor tests and all 10 focused Derf placement regressions pass. Two new pure projection tests prove Éloïse 60-degree, Grojib 45-degree, Hashash 60-degree, Unoco solid/local-hover, and Derf solid/15-degree/32-pixel evidence, shared Core graph identity, no invented player/flight graph, and signature parity under source permutation. The Chunk route test proves the opt-in five-actor overlay and selected-edge facts create no revision or pending diff. Migration check still reports 99 prefabs, 8 chunks, and nine pending targets without writes; generator dry-run still validates 8 chunks, 2 levels, and 2 themes. Normal source, marker data/RNG, generator input, and runtime authority remain unchanged. |
| 2026-08-02 / `960cf052` + `3c83c446` | Core-backed authored marker placement diagnostics in Chunk staging | Dart VM and Flutter test VM on Windows | Editor and Core analysis are clean and all 369 editor tests pass. Three pure projection tests cover authored-order/stable-key retention, chance/salt preservation, ground/highest/obstacle source selection, exact Grojib/Unoco/Derf Core outcomes, Derf's 32-pixel rejection, Hashash deferral, disabled markers, malformed contracts, and missing level ground context. Staging validation blocks malformed markers; the route test proves the opt-in overlay, selected capsule/support/blocker/diagnostic evidence, zero RNG/revision/pending changes, and explicit item/projectile dispositions. Migration check still reports 99 prefabs, 8 chunks, and nine pending targets without writes; generator dry-run still validates 8 chunks, 2 levels, and 2 themes. Normal source, generated marker records, RNG, generator input, and runtime authority remain unchanged. |
| 2026-08-02 / `540d1e9e` | Scheduler-aware compiled chunk seam validation | Dart VM and Flutter test VM on Windows | Editor and Core analysis are clean and all 379 editor tests pass. Ten focused seam tests cover matched slopes, explicit open boundaries, exact interval/endpoint/mode/surface mismatch, advisory material evidence, input-order invariance, tier fallback/boundaries/directions, variable assembled runs, distinct pools, sampled Core-scheduler containment, global mismatch gating, a fixed `authoring-seams-v1` record/digest, and bounded pathological schedules. The staging load snapshots immutable `LevelDef` data; Chunk Creator lists compatible/failing directed neighbors without mutation. Migration check still reports 99 prefabs, 8 chunks, and nine pending targets without writes; generator dry-run still validates 8 chunks, 2 levels, and 2 themes. Normal prefab-v2/chunk-v1 source, generated runtime data, scheduler behavior, and collision authority remain unchanged. Generator consumption of the seam golden remains open in §21. |
| 2026-08-02 / `f7d14a16` | Exact generated-output dry-run drift gate | Dart VM and Flutter test VM on Windows | Repository analysis is clean; 23 focused level-definition/artifact-plan/generator tests and all 432 root Core tests pass. The real dry-run validates 8 chunks, 2 levels, and 2 themes, then confirms all five committed outputs byte-for-byte. Fixtures cover missing, stale, unexpected owned, invalid-UTF-8 stale, deterministic ordering, plan immutability, no-write behavior, and clean generation-followed-by-check. Generated bytes, prefab-v2/chunk-v1 input, runtime contracts, and collision authority are unchanged. Staged polygon output, seam-fixture consumption, and atomic writes remain open. |
| 2026-08-02 / `bf7f0554` | Rollback-safe generated-output write transaction | Dart VM and Flutter test VM on Windows | Repository analysis is clean and 24 focused level-definition/artifact-plan/generator tests pass. Success fixtures cover existing and missing targets, exact bytes, and complete temp/backup cleanup; the failure fixture proves a later invalid target restores an earlier original and leaves no transaction files. Canonical alias output paths reject before filesystem access. Real five-file generation followed by dry-run is clean and creates no generated-file diff. Source schemas, generated bytes, runtime contracts, and collision authority are unchanged. |
| 2026-08-02 / `6de37b6e` | Strict staged polygon terrain compiler foundation | Dart VM and Flutter test VM on Windows | Root and editor analysis are clean; 30 focused level/artifact/generator tests, all 432 root Core tests, and the complete 380-test editor suite pass. Six new generator tests cover strict v3/v2/legacy/unknown/off-grid parsing, fresh-object determinism, unresolved prefab and Core range diagnostics, canonical-source rejection, exact placement lineage, Core polygon/edge compilation, and concave triangle count/area/order goldens. The shared editor fixture reproduces source `ad2ecbb…e635`, edge `20fb3ca9…3351`, and placement `bacff9da…7211`; triangles bind to `c1a71872…07d3`. Migration check remains read-only at 99 prefabs, 8 chunks, and nine pending targets; live dry-run remains clean. No authored source, generated runtime file, normal generator input, or production authority changed. |
| 2026-08-02 / `a8c45814` | Typed staged terrain Dart artifact boundary | Dart VM and Flutter test VM on Windows | Root, Core-package, and editor analysis are clean; all 34 root tool/generator tests, all 310 Core-package tests, all 432 root Core tests, and the focused editor parity test pass. The executable golden contains 3 canonical source/physics polygons, 13 compiler-owned exposed edges, 10 render triangles, exact placement lineage, and all four reviewed signature labels/hashes. Fresh compilation reproduces its bytes through `GeneratedArtifactPlan`; reversed chunk input is identical; empty/duplicate sets fail; the reserved compiler index is absent from generated local records. A production import audit keeps the staged types/output unreachable. Live dry-run still validates 8 chunks, 2 levels, and 2 themes; migration check remains read-only at 99 prefabs, 8 chunks, and nine pending targets. Normal source, five-output registration, generated production bytes, and collision authority remain unchanged. |
| 2026-08-02 / `b646f320` | Legacy prefab collision-mode preservation | Flutter test VM on Windows | Editor analysis and all 382 editor tests pass. Two focused semantic tests prove obstacle/platform overwrite of an incorrect input mode, geometry/metadata preservation, and fail-closed colliding decoration/unknown owners. Repository plan and strict target tests prove all 66 obstacle prefabs emit `solid` and all 4 platform prefabs emit `oneWay`; canonical plan/legacy/current fingerprints are now `d75ba69e`, `4c1243df`, and `2da9f6ab`. The read-only CLI still reports 99 prefabs, 8 chunks, and nine pending targets without writes. Authored source, live generated bytes, and production collision authority are unchanged. |
| 2026-08-02 / `5d540e77` | Exact fail-closed legacy terrain projector | Dart VM and Flutter test VM on Windows | Root and editor analysis are clean; all 40 root tool tests and all 383 editor tests pass. Unit fixtures prove exact orthogonal cell decomposition/area, deterministic solid-union rectangles, exact bottom-band gaps, legacy 16-pixel snapping, permutation invariance, and diagonal/non-rectangular or snap-overlapping one-way rejection. Repository parity is exact for two accepted chunks; the test freezes 24 `polygon_area_overlap` blockers across the other six. The migration check remains read-only at 99 prefabs, 8 chunks, and nine pending targets, and live dry-run still validates 8 chunks, 2 levels, and 2 themes. No live generator/runtime import, authored source, generated byte, or production authority changed. |
| 2026-08-03 / `15b5618a` | Explicit collision-cleared authoring state | Dart VM and Flutter test VM on Windows under Docker RAM pressure | Empty obstacle/platform collider lists and prefab-v3 polygon lists are warning-only; deleting the final collider is supported; normal generation preserves visuals with no solids; and an exact full-width gap is the sole legacy grid exception. Twelve focused Core/generator/projector tests pass, as do seven isolated prefab commit tests. A broader 35-test editor run exposed one stale invalid-empty test expectation, which was corrected to use invalid topology. A retry of that single plugin test file timed out before first output after 90 seconds; full analysis and suites remain pending. |
| 2026-08-03 / `a3b665cb` | Clear all authored static collision for polygon reauthoring | Windows structural audit under Docker RAM pressure | Exact before/after audit proves the only prefab changes are empty collider lists plus revision bumps on the 70 former collision owners; all 99 visuals/kinds/metadata remain. The only chunk changes are one revision bump and one full-width `collision_cleared` gap in each of 8 chunks; all 50 placements and 2 markers remain. Generated patterns contain 8 full-width gaps and zero static solids. Migration classification reports 70 `collisionCleared`, 29 decorations, zero prefab/ground shapes, and zero blockers with plan/legacy/current fingerprints `51630457`, `086d00a8`, and `7f4fc90e`. The generated-asset commit hook passed; full migration/parity/analyzer suites remain pending because of memory pressure. |
| 2026-08-03 / `8aa880a6` | Collision-reset regression closure | Dart VM and Flutter test VM on Windows with Docker still running | Root, Core-package, editor, and replay-validator analysis are clean. All 385 editor tests, 42 root tool/generator tests, 310 Core-package tests, 433 root Core tests, and 80 replay-validator tests pass. The stale prefab-v3 test now rejects genuinely invalid self-intersecting topology instead of valid final-shape deletion; real-level determinism stops submitting commands once collisionless runs freeze; the jump-buffer unit test disables live track streaming. The read-only migration check validates 99 prefabs, 8 chunks, and nine pending representation targets without writes, and generator dry-run validates 8 chunks, 2 levels, and 2 themes with no drift. |
| 2026-08-03 / `a0338973` | Guarded polygon migration write transaction foundation | Dart VM and Flutter test VM on Windows with Docker running | Targeted analysis of the two transaction implementations and two focused test files is clean; all 8 focused tests pass. Fixtures prove sibling staging, exact byte verification, final pre-move callback ordering, rollback before moves, rollback after an earlier replacement, rollback after post-install validation, a complete 9-file legacy-to-current conversion in a temporary workspace, repeated current-schema no-op, drift rejection, and transaction-file cleanup. The real read-only CLI check still reports 99 prefabs, 8 chunks, 9 pending targets, and no source write. `--write` remains unavailable. |
| 2026-08-03 / `f343336e` | Deterministic migration failure/rollback evidence | Dart VM and Flutter test VM on Windows with Docker running | Targeted analysis is clean and all 4 migration-transaction tests pass. Report-v1 failure evidence distinguishes pre-write blocking, successful rollback, incomplete rollback, and committed-output cleanup failure; source paths are canonical and host-specific cause/temp-path text is excluded. This closes the machine-readable result contract only—CLI report-file emission and `--write` authorization remain disabled. |
| 2026-08-04 / `9eec2039` | Write-locked Chunk v2 existing-owner metadata commits | Dart VM and Flutter test VM on Windows with Docker running | Targeted analysis of the policy, plugin, and focused test file is clean; all 5 Chunk-v2 plugin tests pass. The immutable before/after contract rejects stale, invalid, unknown, and noncanonical values; accepted status/level/difficulty/assembly-group/tag/ground-band changes preserve identity, dimensions, composition, markers, placements, and polygons while advancing the owner revision exactly once and producing its canonical pending diff. Changed v2 export remains hard-locked, normal v1 loading/source is unchanged, and lifecycle/placement/marker/tile-layer command parity remains open. |
| 2026-08-04 / `77513d30` | Write-locked Chunk v2 composition commits | Dart VM and Flutter test VM on Windows with Docker running | Targeted policy/plugin/test analysis is clean and all 7 Chunk-v2 plugin tests pass. One immutable before/after contract now covers canonical tile layers, prefab placements, and enemy markers for an existing owner. Accepted changes preserve identity, metadata, dimensions, and polygons, advance the revision once, and produce one pending owner diff; stale/noncanonical/no-op edits, unknown prefab references, invalid enemy markers, and any complete-document placement/marker/seam/geometry blocker preserve document identity. The source-write lock and normal v1 authority remain unchanged; granular route forms and lifecycle paths remain open. |
| 2026-08-04 / `7b42595c` | Read-only Chunk v2 source-ownership/save plan | Dart VM and Flutter test VM on Windows with Docker running | Targeted analysis is clean and all 15 save-plan/plugin/staging-loader tests pass. Staged documents now distinguish explicitly created owners from baseline-backed owners; the deterministic plan covers clean no-op, canonical new files, managed ID/level path moves, and baseline deletions, with portable pending paths and old/new diff headers. Missing baselines/paths, workspace escapes, case-insensitive final-target collisions, and reuse of a pending deleted path fail closed. No v2 save method or filesystem mutation exists, changed export stays locked, and normal v1 source remains authoritative. |
| 2026-08-04 / `fbee0d37` | Write-locked Chunk v2 lifecycle commits | Dart VM and Flutter test VM on Windows with Docker running | Targeted lifecycle/store/plugin analysis is clean and all 18 save-plan/plugin/staging-loader tests pass. One immutable ownership/level snapshot and typed operation family now covers create, duplicate, rename, and delete. Tests prove deprecated blank creation, active revision-1 duplication, stable-key rename with one revision bump and managed move, exact loaded deletion, unsaved create/delete cancellation, created-owner path refresh, typed plugin dispatch, and stale/invalid/colliding/missing/no-op identity. Every accepted candidate passes complete staged validation plus the ownership plan; export remains hard-locked and normal v1 source/routes are unchanged. |
| 2026-08-09 / `b2a9db0c` | Write-locked Prefab v3 owner mutations | Dart VM and Flutter test VM on Windows with Docker running | Targeted owner-policy/plugin/test analysis is clean; all 8 Prefab-v3 domain tests plus the 3 strict staging-loader tests and route-local staging workspace test pass. Immutable metadata cannot mutate stable identity or polygons; create/duplicate/rename/delete own deterministic keys and revisions; accepted changes recompute visual bounds and rejected stale/invalid/noncanonical/no-op commands preserve document identity. Normal v2 loading/source and changed-v3 export remain locked. |
| 2026-08-09 / `e3b3e8a1` | Write-locked Prefab v3 visual-catalog mutations | Dart VM and Flutter test VM on Windows with Docker running | Targeted catalog/plugin/test analysis is clean and the final focused set covers 13 Prefab-v3 domain cases, 3 strict staging-load cases, and the route-local staging workspace. Typed prefab/tile slice and platform-module operations use a complete two-file freshness token, canonical ordering, deterministic duplicate IDs, exact module/prefab revision propagation, reference-safe deletion/cascade, recomputed bounds, and portable prefab/tile pending diffs. A tile-only mutation proves changed export remains hard-locked with zero filesystem output; normal v2 authority is unchanged. |
| 2026-08-09 / `b0eb64e7` | Transactional Prefab v3 save/reload proof | Dart VM and Flutter test VM on Windows with Docker running | Targeted store/plugin/test analysis is clean and all 5 focused save-plan tests pass. Strict paired baselines produce canonical fixed-path plans; clean plans are no-ops; paired and tile-only edits install through the shared rollback-safe workspace transaction and reload byte-identically; source drift, missing/legacy baselines, incomplete plans, and noncanonical outputs fail before replacement. Transaction artifacts are cleaned, the normal plugin remains changed-export locked, and checked-in v2 source is untouched. |
| 2026-08-09 / `52328d1d` | Rollback-safe workspace deletion artifacts | Dart VM and Flutter test VM on Windows with Docker running | Targeted shared-transaction analysis is clean and all 7 transaction tests pass. A deletion now stages no replacement bytes, retains the original as a sibling backup, verifies target absence with the installed set, and restores the deleted file if later post-install validation fails. Existing write ordering, byte verification, drift callback timing, canonical-path rejection, and cleanup behavior remain unchanged. |
| 2026-08-09 / `de67b22b` | Transactional Chunk v2 save/reload proof | Dart VM and Flutter test VM on Windows with Docker running | Targeted store/test analysis is clean; the focused 30-test set covers 7 shared transactions, 11 Chunk-v2 save/lifecycle plans, 7 plugin commits, and 5 strict staging loads. Clean plans are no-ops; managed moves and create/delete batches commit atomically and reload byte-identically; full-tree byte/set drift and stale plans reject before replacement. Post-install verification requires the exact canonical file set and strict v2 decoding. Normal v1 authority and the changed-v2 export lock remain unchanged. |
| 2026-08-09 / `2fef7eb0` | Complete Prefab v3 catalog validation and downstream impact preview | Dart VM and Flutter test VM on Windows with Docker running | Targeted analysis is clean and all 27 focused plugin/load/controller/projection/route tests pass. One shared validator now covers canonical prefab/tile slice and module ordering, identities, revisions, atlas bounds, cell references/positions, visual-owner references, and polygon-owner rules for both commit and plugin validation. Explicit staging strictly reads all-current Chunk-v2 placements, resolves stable keys with legacy-ID fallback, reports deterministic placement/chunk counts, and previews changed-owner impact without changing chunk bytes or revisions. Paired baselines remain mandatory, changed export stays locked, and normal v2/v1 source is untouched. |
| 2026-08-09 / `336cf6ab` | Whole-document current-schema commit/export gates | Dart VM and Flutter test VM on Windows with Docker running | Targeted plugin/test analysis is clean and all 46 focused Prefab-v3/Chunk-v2 plugin, strict-load, controller, and route tests pass. Every accepted staged candidate now passes complete document validation and save-plan ownership before session history; tests prove a locally valid chunk polygon edit that breaks a scheduler-reachable seam, metadata edits against invalid global state, and prefab owner edits against an invalid retained module all preserve original identity. Both staging exporters validate before clean/no-op or the changed-source write lock. The Chunk route fixture's synthetic rock was moved away from duplicated direct terrain after the new expansion gate correctly rejected their positive-area overlap. Normal source and write locks remain unchanged. |
| 2026-08-09 / `052f15dc` | Prefab-v3 owner-form composition in explicit staging | Flutter test VM and Dart analyzer on Windows with Docker running | Full editor analysis is clean and all 27 focused staging-route, polygon-controller, Prefab-v3 plugin, and strict-load tests pass. The route now creates and edits owner status/kind/visual source/anchor/canonical tags, duplicates, preserves stable keys while renaming, deletes with downstream-impact warning, survives zero-owner recreation, and resynchronizes selection across lifecycle commands and undo/redo. The end-to-end widget test proves every metadata/lifecycle operation preserves committed polygon source. Unchanged forms are no-ops, controller disposal follows dialog lifecycle, source apply remains disabled, and normal v2 source/route authority is unchanged. |
| 2026-08-09 / `d25b3003` | Prefab-v3 atlas/tile-slice form composition | Flutter test VM and Dart analyzer on Windows with Docker running | Full editor analysis is clean and all 59 focused Prefab route, legacy-form, polygon-controller, Prefab-v3 plugin, and strict-load tests pass. The retained visual atlas slicer now creates/updates both prefab and tile slices through typed catalog commits, uses domain-canonical tags and atlas bounds, resynchronizes across session undo/redo, confirms unreferenced deletion, and blocks referenced deletion without exposing destructive cascade. Local drafts block workspace switching, normal v2 atlas tests remain green, source apply remains disabled, and checked-in source is unchanged. |
| 2026-08-09 / `2d3be519` | Prefab-v3 platform-module form composition | Flutter test VM and Dart analyzer on Windows with Docker running | Full editor analysis is clean and all 60 focused Prefab tests pass. The retained module list/form/visual grid now covers deprecated-empty create, update, paint, reactivation, stable reference-cascading rename, deterministic duplicate, reference-safe delete, and session undo/redo through typed catalog commits. Legacy and v3 routes share one pure canonical paint/erase/move/delete reducer; guarded slice/module forms cannot lose drafts through selection, status, cell, delete, or workspace changes. The widget proof preserves referencing prefab polygons, source apply stays disabled, and normal v2 source/route authority is unchanged. |
| 2026-08-09 / `c54b2b9f` | Chunk-v2 owner-form composition in explicit staging | Flutter test VM and Dart analyzer on Windows with Docker running | Full editor analysis is clean and all 40 focused Chunk route, polygon-controller, lifecycle/save-plan, plugin, strict-load, and legacy-route tests pass. The active-level route now creates deprecated empty owners from locked dimensions; edits status, level, difficulty, assembly group, canonical tags, and render-band Z; duplicates complete owners; preserves stable keys while renaming; and stages loaded or unsaved deletion through typed commands. Widget proofs preserve identity, dimensions, tile layers, placements, enemy markers, and polygons across metadata edits, verify deterministic revisions/defaults, avoid source reloads, and retain undo recovery after deleting a level's final dimension authority. Source apply remains disabled and normal v1 source/route authority is unchanged. |
| 2026-08-09 / `668b11e9` | Chunk-v2 composition-form parity in explicit staging | Flutter test VM and Dart analyzer on Windows with Docker running | Full editor analysis is clean and all 41 focused Chunk route, polygon-controller, lifecycle/save-plan, plugin, strict-load, and legacy-route tests pass after the final change. A guarded second staging view now creates, edits, and confirms deletion of tile layers, prefab placements, and enemy markers through the one strict composition command. Forms use canonical ordering, active Prefab-v3 owners, exact placement scale steps, Core enemy IDs, marker bounds/chance/salt/intents, and one accepted revision bump. The widget proof covers every form and session undo/redo while preserving owner identity, metadata, dimensions, and polygon source; it performs no reload or source write. Owning-prefab navigation, normal loader/route selection, reload/source apply, and repository migration remain open. |
| 2026-08-09 / `3d59d746` + `96300954` + `b49eca6c` | Shared `authoring-polygons-v1` editor/generator parity | Dart VM and Flutter test VM on Windows with Docker running | Root, Core-package, and editor analysis are clean. All 313 Core-package tests and all 436 editor tests pass, plus ten focused root current-schema compilation/render tests. One Core contract owns length-prefixed records, canonical ordering, duplicate rejection, empty-set behavior, and SHA-256; mutation tests cover every owner/shape/vertex/collision-metadata field. The generator records direct shapes plus each referenced collision prefab once, emits digest `679f918e…e9db`, and advances the disconnected staged artifact schema to v2. The editor derives the same digest from strict v3/v2 fixture models and an accepted expansion, rejecting stale prefab revision evidence. Live generation registration, authored source, normal routes, and runtime authority remain unchanged. |
| 2026-08-09 / `edf5d815` | Canonical `authoring-migration-v1` readiness signatures | Dart VM and Flutter test VM on Windows with Docker running | Targeted migration analysis is clean and all 10 repository migration-check tests pass. The signature hashes one length-prefixed format label plus the existing canonical readiness-report-v2 bytes, preserving the reviewed legacy/current short fingerprints while adding stable SHA-256 digests `c355c5de…0beb` and `d98983c4…8153`. A temporary-workspace mutation proves even semantically harmless reviewed source-byte drift changes the digest. Report JSON, CLI output, source files, `--write` authorization, and runtime authority remain unchanged. |
| 2026-08-10 / `94123b9a` | Restore standalone-Dart migration CLI boundary | Dart VM and Flutter test VM on Windows with Docker running | Full editor analysis is clean and all 438 editor tests pass. Direct `dart run tool/migrate_polygon_authoring.dart --help` and `--check` both succeed; the real check remains legacy-ready with 99 prefabs, 8 chunks, 9 validated pending targets, and zero source writes. One Flutter-free repository-path contract now supplies the existing Prefab/Chunk store aliases and the migration command/check, removing the transitive `dart:ui` dependency. The 21 focused migration command/check tests include a standalone Dart subprocess regression. No path bytes, report bytes/signatures, source, write authorization, or runtime authority changed. |
| 2026-08-10 / `fd543b63` | Shared scheduler seam signature and generator golden | Dart VM and Flutter test VM on Windows with Docker running | Root, Core-package, and editor analysis are clean. Three Core contract tests, two staged-generator manifest tests, and all ten editor seam tests pass. Core now owns the immutable sorted `authoring-seams-v1` transition set and digest; duplicate or delimiter-ambiguous identities fail closed. The strict generator manifest decoder consumes the exact editor eight-transition golden, recalculates record/digest `9681ffb1…93b`, and rejects schema or derived-field drift. The editor no longer implements the hash separately. Compiled-boundary validation before staged rendering remains open; live generator registration, source, scheduler behavior, and runtime authority are unchanged. |
| 2026-08-10 / `e3309704` | Shared compiled-boundary gate for staged terrain output | Dart VM and Flutter test VM on Windows with Docker running | Root, Core-package, and editor analysis are clean; all 319 Core-package tests, all 438 editor tests, and all 48 root tool/generator tests pass. Core now owns unchanged `authoring-boundary-v1` derivation/comparison. Four staged-generator seam tests cover compatible directed pairs, canonical chunk order, exact mismatch ticks/digests/profiles, missing chunks, wrong level, duplicate and case-colliding keys; material evidence remains advisory through the Core matrix. The renderer accepts only a privately constructed validated batch and emits `authoring-seams-v1` format/digest evidence, advancing only the disconnected staged fixture schema to v3. Live current-schema registration, authored source, normal generation bytes, scheduler behavior, and runtime authority remain unchanged. |
| 2026-08-10 / `7ba0b636` | Fresh-process staged signature determinism | Dart VM and Flutter test VM on Windows with Docker running | Root, Core-package, and editor analysis are clean; all 320 Core-package tests, all 439 editor tests, and all 55 root tool/generator tests pass. Two standalone generator-probe processes reproduce every reviewed signature and exact staged artifact SHA-256 `434ae70a…ca84`; two standalone migration checks reproduce canonical report bytes and `authoring-migration-v1` `c355c5de…0beb`. Reversed caller collections, every valid loop rotation/winding, Windows/POSIX source spelling, and one-field polygon/placement/triangle/seam/source mutations are explicit. The compiled product owns placement/triangle sorting and duplicate rejection. Authored source, live output registration, generated production bytes, and runtime authority are unchanged. |
| 2026-08-10 / `c31bdd82` | Staged generator blocking-diagnostic matrix | Dart VM and Flutter test VM on Windows with Docker running | Targeted analysis is clean and all 58 root tool/generator tests pass. Strict scale diagnostics cover below-minimum, above-maximum, and off-step values. Unknown and ambiguous prefab references, direct and prefab source-range failures, and simultaneous direct/expanded Chunk-bounds failures return no compiled product while retaining exact source/placement/shape/element lineage and canonical issue ordering; reversed prefab catalog input is identical. Reviewed fixture records, signatures, artifact bytes, authored source, and live runtime authority are unchanged. |
| 2026-08-10 / `a3b0504b` | Core-owned deterministic terrain triangulation | Dart VM and Flutter test VM on Windows with Docker running | Root, Core-package, and editor analysis are clean; all 325 Core-package tests, all 58 root tool/generator tests, and all 439 editor tests pass. Core's exact first-ear triangulator and shared `authoring-triangles-v1` contract replace the generator-private algorithm/serializer. Convex/concave order, all rotations/reversed windings after compiler normalization, malformed-product rejection, immutable output, record ordering, duplicate rejection, and empty digest are explicit. Editor strict model round-trips and Core preview reproduce the generator's triangle digest `c1a71872…07d3`; staged artifact bytes/hash remain unchanged. Authored source, live registration, collision/runtime authority, and replay behavior are unchanged. |
| 2026-08-10 / `017cd01a` | Transform and terrain feature parity fixture | Dart VM and Flutter test VM on Windows with Docker running | Root and editor analysis are clean; all 59 root tool/generator tests and all 440 editor tests pass. Exact canonical source covers odd half-pixel ticks, X-only reflection at `0.3`, Y-only reflection at `3.0`, one-quantization output, a flat-to-slope edge, finite pit coverage, and cross-shape internal solid-edge cancellation. Generator and editor agree on six polygons, 21 exposed edges, 14 triangles, and source/edge/authored/placement/triangle digests `6e5e8bbf…fe8`, `ed707fc7…d31`, `60ca88ca…c3f`, `4f07473d…1c2`, and `41ee501d…f36`. The original reviewed artifact bytes, authored source, live registration, and runtime authority are unchanged. |
| 2026-08-10 / `80c3cf98` | Migration-origin authoring/runtime parity fixture | Dart VM and Flutter test VM on Windows with Docker running | Root and editor analysis are clean; all 60 root tool/generator tests and all 441 editor tests pass. The real legacy prefab union planner produces the fixture's isolated odd rectangle, concave overlapping-rectangle union, and two disconnected components exactly; reversed collider input preserves canonical loops and derived IDs. Generator and editor agree on four polygons, 20 exposed edges, 12 triangles, and source/edge/authored/placement/triangle digests `8b70a09b…bd96`, `1e605569…a1c6`, `355242dd…b57c`, `edc8b921…780f`, and `fcdff387…0ec5`. Existing fixture families, authored source, live registration, and runtime authority are unchanged. |
| 2026-08-10 / `7b427390` | Staged structural/topology diagnostic matrix | Dart VM on Windows with Docker running | Root analysis is clean and all 63 root tool/generator tests pass. Strict parsing freezes malformed JSON, missing schema/shape fields, invalid collision mode, off-grid coordinates, lowercase ID grammar, and duplicate IDs. Core mapping freezes complete ordered diagnostics for repeated closing/consecutive duplicate vertices, too-few vertices, minimum area/edge, collinearity, noncanonical start/winding, self-intersection, occupied overlap, and transformed minimum-edge collapse with exact source/placement/shape/element lineage and no compiled product. Editor source was unchanged; the preceding 441-test editor result remains applicable. Authored source, fixture signatures, generated bytes, and runtime authority are unchanged. |
| 2026-08-10 / `3a61654d` | Core terrain-authoring issue envelope | Dart VM on Windows with Docker running | Core-package analysis is clean and all 328 tests pass. The immutable pure-Dart contract validates required identity, derives blocking severity from existing Core diagnostics, retains source/owner/placement/shape/element lineage, and returns an immutable canonical order across every field except display message. Core gains no JSON, filesystem, or editor dependency. |
| 2026-08-10 / `9979e03f` | Staged-generator issue normalization | Dart and Flutter test VMs on Windows with Docker running | Root analysis is clean and all 64 root tool tests pass. Valid raw source compiles to the identical reviewed records/signatures as the decoded entry point. Independent malformed prefab and chunk inputs become sorted `prefab_source_invalid`/`chunk_source_invalid` errors; reference, Core, transform, and bounds findings use the same owner-aware envelope with exact chunk-versus-prefab ownership and no partial output. Live generator registration, generated bytes, authored source, and runtime authority are unchanged. |
| 2026-08-10 / `8e96d57d` | Editor terrain-diagnostic ownership bridge | Dart and Flutter test VMs on Windows with Docker running | Editor analysis is clean and all 442 tests pass. Generic `ValidationIssue` now optionally retains an owner key, while Chunk-v2 collision expansion routes every terrain finding through the strict shared envelope. Focused proofs bind direct and placement-source failures to `forest_test`, expanded/Core failures to `prefab_rock`, and preserve canonical severity/lineage ordering. Normal source selection, export locks, generated data, and runtime authority are unchanged. |

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
therefore incomplete rather than a different topology result.

The accepted resolution keeps the global minimum and supplies three reviewed
minimal outward replacements. Their exact positive area deltas are 34, 25, and
36 half-pixel-square ticks. Each is guarded by the full expected collider list,
so stale source blocks instead of inheriting an obsolete correction. The final
read-only prefab result is 70/70 prefabs and 88/88 loops accepted with zero
unclassified blockers. No authored source or runtime data had been changed at
this historical baseline point.

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

### 28.5 Current Collision-reset State

On August 3, 2026, the user explicitly chose complete collision deletion and
later polygon reauthoring instead of preserving or unioning the legacy collider
layout. The exact structural audit records:

- 99 prefab records: 66 obstacles, 4 platforms, and 29 decorations
- 70 former collision owners classified as `collisionCleared`; zero collider
  or planned polygon shapes
- all visuals, kinds, metadata, stable keys, and decoration revisions retained;
  only those 70 collision owners receive one revision bump
- 8 chunks with one full-width `collision_cleared` gap each and zero finite
  ground shapes
- all 50 prefab placements and 2 enemy markers retained
- generated `authored_chunk_patterns.dart` contains zero `SolidRel` records and
  8 full-width gaps
- migration plan/legacy/current fingerprints are `51630457`, `086d00a8`, and
  `7f4fc90e`

This is deliberately not a playable content milestone. Legacy authority is
still selected, but it now has no static support geometry. Éloïse, grounded
enemies, navigation graphs, and terrain-relative marker resolution cannot be
accepted against repository content until polygon terrain is reauthored.

The full regression closure is recorded under `8aa880a6`: analysis is clean in
every affected Dart package; all editor, generator, Core, and replay-validator
tests pass; the repository migration check remains read-only and blocker-free;
and generator dry-run reports no drift. This validates the reset itself but
does not close the Phase 4 source cutover or polygon reauthoring gates.

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
dart run tool/migrate_polygon_authoring.dart --check
flutter drive --profile `
  --driver=test_driver/integration_test.dart `
  --target=integration_test/polygon_interaction_benchmark_test.dart `
  -d windows
Pop-Location

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
