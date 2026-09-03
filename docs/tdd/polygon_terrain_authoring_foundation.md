# Polygon Terrain Authoring Foundation

## Status And Authority Boundary

The exact polygon-source foundation is implemented in `runner_core`, the root
generator, standalone editor, and Flame renderer. Checked-in authoring now uses
Prefab-v3 and complete Chunk-v2 trees. Polygon terrain drives normal gameplay
collision, navigation, placement, and render snapshots.

The source and streamed gameplay handoff are current. The legacy generator
projection, rectangle runtime authority, and migration-only adapters are
deleted:

- prefab authoring persists schema v3 `collisionShapes`
- chunk authoring persists schema v2 direct `collisionShapes`; the compatible
  `collisionMode: none` value marks a direct polygon as render-only
- normal Prefab/Chunk plugin loads expose no legacy editable data, commands,
  pending diffs, or export; the shared migration route provides only a
  read-only readiness command and atomic source recheck
- normal streamed `GameCore(...)` and replay validation use the same admitted
  polygon terrain authority
- all 99 prefab records retain visuals, kinds, metadata, and identity;
  `anvil_00` has one authored collision polygon while the remaining reset
  owners remain empty for authoring
- the repository contains three active chunks, one per active level; Forest
  retains only `forest_early_flat`, with one continuous `ground_001` polygon
  at its established 224px ground line and no Prefab or enemy markers
- every ground polygon carries `surfaceKind: ground` and
  `materialKey: grass_dirt`; all reachable scheduler seam combinations compile
  with identical boundary coverage
- staged terrain contains the three retained ground polygons; generated
  scheduler data contains no rectangle solids, raised forest obstacles, or
  ground gaps
- the normal generator registers the staged Dart artifact as its sixth output;
  normal Core/replay construction admits it and publishes a complete
  collision/navigation/placement/render candidate whenever the existing
  scheduler selection changes; Flame consumes that candidate directly; the
  isolated terrain harness may publish an admitted staged candidate's
  immutable Core render snapshot alongside its collision/navigation bundle;
  that snapshot retains exact source-lineage collision edges for later render
  diagnostics without reconstructing them from polygon loops
- Flame caches Core's exact loops and triangle indices, applies the centralized
  `grass_dirt` fill/surface/foreground material, and consumes upward-facing
  compiler edges for surface strips; the legacy ground bands, rectangle debug
  views, and temporary floor mask are deleted

Final Phase 4 acceptance work remains tracked in
[the Phase 4 checklist](../building/slopes/phase4-implementation-checklist.md).

## Ownership

| Contract | Owner | Implemented consumer |
| --- | --- | --- |
| Exact half-pixel source vertex and shape values | `tools/editor/lib/src/terrain_authoring/terrain_source_models.dart` | Shared editor geometry, model tests, migration/transform support, and the Core adapter; normal Prefab and direct Chunk codecs admit only even ticks |
| Source validation and canonicalization | `runner_core` `TerrainSourceCanonicalizer` | `TerrainCompiler` and editor adapter |
| Portable terrain-authoring issue envelope | `runner_core` `TerrainAuthoringIssue` | staged generator raw-source/compile, seam validation, typed artifact/output-drift verification, migration plan/check/write adapters, editor Prefab/Chunk polygon validation, and Chunk-v2 collision expansion |
| Positive-area polygon overlap | `runner_core` `TerrainPolygonOverlap` | `TerrainCompiler` and editor owner validation |
| Exact placement and physics-grid quantization | `runner_core` `TerrainSourceTransform` | `TerrainCompiler`, Core fixtures, and editor adapter |
| Editor-to-Core conversion | editor `TerrainSourceCoreAdapter` | migration checks, shared interaction reducer, and normal current-schema Prefab/Chunk routes |
| Shared polygon interaction state | editor `TerrainPolygonInteractionReducer` | pure-Dart selection/draft/gesture/semantic-edit tests plus normal current-schema Prefab and Chunk routes |
| Chunk contact-constrained terrain input | editor `TerrainPolygonContactConstraint` / `ChunkPolygonAuthoringController` | direct rectangle, vertex, insertion, and whole-shape previews against direct and expanded prefab collision |
| Chunk prefab-to-terrain surface contact | editor `ChunkPrefabSurfaceSnap` / `ChunkPrefabSceneGesture` | whole-pixel Place/Move origins, exact compatible-scale support projection, exposed direct-terrain targets, and overlap-free edge-contact preview |
| Exact grid-aware inspector text | editor `TerrainHalfPixelText` / `TerrainPolygonVertexEditor` / `TerrainPolygonInteractionReducer.editSelectedVertex` | one shared exact field widget and semantic commit path; current Prefab and direct Chunk editing both require whole pixels |
| Polygon collision metadata dialog | editor `TerrainPolygonMetadataDialog` / `TerrainMaterialPreviewCatalog` / `TerrainPolygonInteractionReducer.editSelectedShapeMetadata` | one owner-neutral collision-mode/surface/material selector used by both current-schema routes; material choices preview their fill/surface/foreground workspace assets, unknown retained values remain selectable, and owner controllers retain commit authority |
| Polygon duplicate placement default | editor `findTerrainPolygonDuplicateOffset` | deterministic nearest conservative AABB-free, snap-aligned candidate on both current-schema routes; exact owner validation remains final authority |
| Render projection and source-space hit testing | editor `TerrainPolygonSceneProjection` / `TerrainPolygonSceneHitTest` | framework-neutral scene tests and both current polygon surfaces |
| Canvas projection and source-loop overlay | editor `TerrainPolygonViewportTransform` / `TerrainPolygonScenePainter` | shared Flutter painter tests and both current polygon surfaces; the Chunk route layers Core edges, actor-terrain evidence, and marker-placement diagnostics above it |
| Prefab polygon owner validation | editor `validatePrefabCollisionShapes` | Core compiler, exact visual-bounds tests, and normal current-schema Prefab commits/export |
| Immutable prefab-v3 polygon record | editor `PrefabV3Def` | migration target, normal current-schema store/plugin/UI, and model-contract tests |
| Strict prefab-v3 file structure and canonical serialization | editor `PrefabV3FileData` / `PrefabV3FileCodec` | delegated migration checks plus normal current-source load, transactional save, and exact reload |
| Retained tile-v2 structure and canonical serialization | editor `PrefabTileFileData` / `PrefabTileFileCodec` | current-source byte round-trip plus normal v3 paired load/save |
| Prefab visual-source bounds | editor `PrefabVisualBoundsResolver` | normal v3 atlas-slice/platform-module loading and offline migration target review |
| Prefab visual alpha projection | editor `PrefabPolygonVisualProjection` / `PrefabVisualAlphaMaskLoader` / `EditorUiImageCache` | one digest-bound atlas/module layout shared by scene rendering and pixel-derived collision; exact authored-order alpha composition, bounded normalized masks, stale-source rejection, and owned image disposal |
| Pure Prefab collision fitting | editor `PrefabAlphaMask` / `PrefabCollisionFitter` | deterministic bounds, outline, hole-safe partition, Platform-support generation, component ordering, coverage evidence, and hard-capacity diagnostics without Flutter or repository I/O |
| Prefab polygon commit and revision policy | editor `PrefabV3CollisionCommitPolicy` | shared reducer, defensive plugin command, and normal current-schema route tests |
| Prefab-v3 plugin document | editor `PrefabV3Document` / `PrefabDomainPlugin` | normal strict current-source selection, typed commits, immutable pending diffs, read-only Chunk snapshots, transformed downstream collision review, transactional apply with Chunk-drift recheck, and exact reload |
| Prefab polygon route-local projection | editor `PrefabPolygonAuthoringController` / `PrefabPolygonSceneSurface` / `PrefabPolygonWorkspace` | normal strict-v3 routing, owner isolation, visual sources, tools, snap, diagnostics, focus, keyboard, rejection, and history; legacy/missing source selects no rectangle workflow |
| Legacy/missing editor source gate | editor `PolygonAuthoringMigrationRequiredDocument` / `PolygonAuthoringMigrationRequiredScene` | shared fail-closed Prefab/Chunk route, blocking validation, command/export refusal, read-only readiness command, and atomic source recheck |
| Fail-closed authored JSON and retained-metadata parsing | editor neutral domain plus `StrictTerrainSourceCodec` | legacy migration plus normal prefab-v3 and chunk-v2 codecs |
| Legacy prefab occupied-area union and reviewed corrections | editor prefab migration domain | offline aggregate check/write plan only |
| Legacy flat-ground/gap conversion | editor chunk migration domain | offline aggregate check/write plan only |
| Strict legacy prefab-v1/v2 and chunk-v1 source parsing | editor migration-owned `LegacyPrefabDef`, `PrefabColliderDef`, and chunk-v1 models | offline aggregate planner input only; normal rectangle models/stores are removed |
| Cross-domain canonical migration report | editor migration domain | read-only checks, explicit externally reported writes, strict in-memory targets, and exact source SHA-256 audit |
| Guarded migration write transaction | editor `WorkspaceWriteTransaction` / `PolygonAuthoringMigrationTransaction` | explicit CLI `--write`, rollback/no-op evidence, and the completed nine-file source cutover |
| Strict chunk-v2 file structure, canonical serialization, and ownership planning | editor `ChunkV2FileData` / `ChunkV2FileCodec` / `ChunkStore.buildV2SavePlan` | migration facade delegation plus normal complete-current-tree load, pending plans, rollback-safe apply, and exact reload |
| Chunk-v2 plugin validation, mutation, and lifecycle policy | editor `ChunkV2Document` / `ChunkV2CollisionCommitPolicy` / `ChunkV2MetadataCommitPolicy` / `ChunkV2CompositionCommitPolicy` / `ChunkV2CompositionOperation` / `ChunkV2LifecycleCommitPolicy` / `ChunkDomainPlugin` | normal strict current-source composition; complete Core/editor validation; owner/revision/snapshot freshness, operation-scoped canonical targeting, ordering, typed polygon/metadata/composition/lifecycle commits, and transactional export |
| Chunk route-local projection | editor `ChunkAuthoringWorkspace` / `ChunkSceneCoordinator` / `ChunkSceneSurface` / `ChunkPolygonAuthoringController` | persistent complete-v2 scene and four tab-filtered cards, typed domain routing, direct terrain/prefab/marker tools, mandatory whole-pixel terrain coordinates with optional tile-grid snap, bounds, keyboard, rejection, history, default-off tile-grid/compiled-edge/actor-terrain overlays, and an editor-overlay-free visual preview; legacy/missing source selects no ground/gap workflow |
| Chunk level visual preview | editor `ChunkV2Document` / `ChunkV2Scene` / `ChunkPolygonLevelVisualSource` | `ChunkDomainPlugin` reads the parallax theme set, resolves the active level's `visualThemeId`, and renders its background/foreground around persisted or local-preview terrain material art selected by direct polygon `materialKey`; it adds no source mutation or gameplay authority |
| Chunk actor terrain projection | editor `ChunkV2ActorTerrainProjection` | shared Core surface/graph and enemy-policy evidence for the default-off actor-terrain overlay and marker placement; Éloïse is the default inspection profile and no source mutation is possible |
| Chunk marker contract and placement projection | editor `chunk_v2_marker_contract.dart` / `ChunkV2MarkerPlacementProjection` | immutable level ground context, staged marker validation, exact Phase 3 enemy placement evidence, Hashash deferral, authored-order/stable-key retention, and zero RNG/source mutation |
| Scheduler-aware chunk seam analysis | editor `chunk_v2_seam_analysis.dart` | immutable `LevelDef` snapshot, canonical compiled boundary signatures, runtime-contract adjacency enumeration, global staged validation, and read-only compatible/failing neighbor evidence |
| Strict staged generator source and compilation | root `polygon_terrain_source.dart` / `polygon_terrain_compilation.dart` | live Prefab-v3/Chunk-v2 parsing, render/collision partitioning, Core compilation, placement lineage, and exact triangulation |
| Staged local generated-record contract | `runner_core` `staged_terrain_data.dart` | live generated artifact consumed by normal/replay Core through strict catalog/binding; Flame consumes only its Core snapshot projection |
| Staged Dart terrain rendering and signature verification | root `polygon_terrain_render.dart` / `polygon_terrain_artifact_validation.dart` | registered sixth output, artifact-plan byte drift, and owner-aware typed artifact/fresh-compile signature checks |

Core has no dependency on editor models, JSON, widgets, or filesystem state.
The editor depends on Core through a one-way local package dependency and does
not reimplement geometric predicates.

### Render-only terrain partition

`collisionMode: none` is an authoring and staged-render role, not a third Core
physics mode. `TerrainCollisionMode` therefore remains `solid`/`oneWay` and no
collision, navigation, support, placement, seam, or blocker consumer needs a
special-case non-collider.

Chunk validation and generation first map every source shape into an
authoring-only review input. That pass owns canonical topology, bounds,
positive-area no-overlap, material references, and normalized loops. The
pipeline compiles three deliberate products: gameplay `TerrainGeometry` from
direct collidable shapes plus placed Prefab collision, fill geometry from only
direct Chunk shapes including `none`, and material-edge geometry from only
direct collidable Chunk shapes. Prefab `none` remains forbidden. Triangulation
uses the direct fill geometry. Staged polygon serialization retains the union
of gameplay polygons and direct render-only polygons, while gameplay edges,
Core `source-v1`/`edges-v1` signatures, seam evidence, traversal caches, and
actor projections continue to use only gameplay geometry. A separate
`edges-v1` render-edge signature covers the direct material boundaries.
`authoring-polygons-v1` still hashes every direct source shape, including its
`none` role, and `authoring-triangles-v1` covers every rendered fill.

At runtime the staged catalog rejects a gameplay edge owned by a `none`
polygon and rejects any material edge owned by a placed Prefab or `none`
polygon. World binding omits `none` polygons but retains placed Prefab
collision. The render-snapshot builder proves every collidable staged loop
matches that world geometry, then emits fills only for direct Chunk polygons
and binds the separately compiled direct material edges. Candidate publication
remains atomic: simulation receives complete gameplay geometry while Flame
receives Chunk-owned terrain visuals at the same geometry version.

The Chunk authoring workspace loads parallax themes only as preview input. Its
plugin snapshot resolves the active `LevelDef.visualThemeId` to one theme, then
the route draws ordered background layers, collision-polygon terrain material
art, and foreground layers in separate read-only z-bands beneath and above the
editable overlays. Missing preview assets or an unresolved theme leave the
authoring surface usable; they neither change Chunk validation nor permit an
editor export to alter parallax or terrain source.

The shared polygon metadata dialog draws its material selector and three-part
asset preview from the same editor material projection as the Chunk scene.
Surface semantics are selected from `ground` and `obstacle`, with an explicit
empty option. Existing unregistered surface or material values remain available
as the current selection so merely opening and applying the dialog is
non-destructive; missing preview files display a broken-image placeholder and
do not change validation or commit policy.

Chunk-local pointer and typed-vertex input clamp to the closed source bounds
`0..width × 0..height` before it reaches shared polygon interaction. During a
whole-shape drag, the route constrains the translation delta against every
vertex of the original shape, so the pointer cannot shift any part of the
shape beyond the owning Chunk. Prefab authoring intentionally keeps its own
owner-specific bounds policy.

## Chunk V2 Existing-Owner Metadata Contract

`ChunkV2MetadataCommit` carries immutable `before` and `after` snapshots for
only the metadata fields retained by schema v2: status, level, difficulty,
assembly group, canonical tags, and `groundBandZIndex`. The plugin resolves the
owner by stable `chunkKey`; the policy then requires the `before` snapshot to
equal the current owner and rejects unknown levels/groups, invalid enum values,
and tags that are not already trimmed, unique, and lexically ordered.

An accepted semantic change creates one replacement owner and increments its
revision exactly once. A stale, malformed, rejected, or no-op command preserves
the original document identity, so it cannot enter session history or pending
changes. The command cannot express changes to chunk key/ID, dimensions, tile
layers, prefab placements, markers, or collision shapes. Those protected fields
therefore survive the metadata replacement unchanged rather than being
reconstructed by a route widget.

This contract is part of the normal complete-v2 workflow. Changed current
source crosses the same complete validation, ownership plan, drift audit, and
rollback-safe transaction as polygon edits. Legacy or missing Chunk source
resolves to the migration-required document before any v1 command can run.

The Prefab and Chunk routes project their owner metadata contracts through
row-local forms rather than edit modals. Each form captures the stable owner
key and immutable metadata snapshot when opened. Apply submits that captured
snapshot through `PrefabV3MetadataCommit` or `ChunkV2MetadataCommit`; it never
reconstructs protected geometry, composition, dimensions, or identity from
widget state. Accepted commands close the editor after the canonical session
document arrives. Rejected or stale commands retain the local field values and
surface the command diagnostic inline. Cancel and clean closure do not create
a revision, history entry, or pending diff.

Dirty owner forms are part of the route's local-draft projection. Source apply
and session undo/redo cannot bypass them: undo cancels the local form before
session history and redo is unavailable. Owner, level, or Prefab workspace
navigation must resolve Save/Discard/Cancel first. Prefab owner selection is
also unavailable while the polygon controller owns an active draw or gesture
operation. This prevents replacing the route-local controller from silently
discarding unfinished collision work.

Prefab and Chunk lifecycle creation is also route-local. A collapsed creation
section captures the document snapshot used by the existing lifecycle command;
Prefab creation reuses the owner source/kind/anchor/tag form, while Chunk
creation exposes only its validated human ID and explains the locked template
dimensions and deprecated initial status. Cancel or Discard removes the draft
without source/history changes, and a stale rejection keeps it mounted.

Rename, Duplicate, and Delete are contextual to the expanded stable owner key.
Rename uses a dedicated inline human-ID form and cannot run concurrently with
a dirty metadata form, keeping its separate revision-producing lifecycle
command explicit. Duplicate deterministically selects the new key. Delete
retains the owner-impact confirmation and rebinds to the deterministic
remaining owner. The old create/edit/rename owner dialog entry points are not
part of either normal current-schema route.

Normal Prefab-v3 owner navigation is a visual projection over the immutable
Prefab and tile documents. Atlas-slice and platform-module thumbnails share a
workspace-scoped image cache with Chunk prefab selection; filtering and search
never enter source, history, validation, or export. Header, library, scene, and
inline-editor context all retain the same stable owner key. Selecting through
either the library or compact header rebinds the collision controller only
after local owner drafts and active polygon operations have been resolved.

Prefab collision creation now supplies the shared reducer with an optional
validated shape ID plus kind-derived collision mode, surface, material, and a
fixed whole-pixel snap policy. These values remain local until the draft is
saved. Retained shapes expand below their row. The shared exact rectangle view
recognizes axis-aligned four-corner polygons; Prefab routes can then replace all
four corners and the shape ID in one reducer result while arbitrary polygons
retain exact vertex editing. Pending identity/coordinate text is guarded across
row, owner, and workspace-view navigation. The former Prefab metadata dialog
has no production entry point.

The same section owns pixel-derived creation and retained-shape refit. Atlas
slices and platform modules resolve into one immutable, anchor-relative alpha
mask whose dimensions and tile destinations match the scene projection. The
pure fitter thresholds alpha inclusively, labels four-connected components in
stable top/left order, and emits integer pixel-cell boundaries. **Fit visible
bounds** emits one spanning rectangle; **Trace visible outline** emits exact
concave loops or a deterministic rectangle partition when an inner ring cannot
be represented by the source polygon schema; **Detect platform surface** emits
downward-closed profiles with left-to-right active support edges. Hole-free
outlines and open platform profiles are reduced against their original points
to the explicit maximum-vertices-per-shape budget while retaining whole-pixel
points; closed contours additionally preserve extents, winding, and simple
topology. The default settings are cutoff 1, minimum island area 1 pixel, and a
24-vertex per-shape budget capped at Core's hard limit of 64. Evidence reports
the maximum introduced boundary or vertical-support deviation.
The synchronous pure fit accepts at most 1,048,576 normalized pixels; larger
visuals fail before allocating the mask.

Fit settings, masks, evidence, and methods never enter Prefab JSON. Generated
candidates remain route-local and editable, with explicit component inclusion,
coverage/support evidence, fit-local undo/redo, source-digest and generation-
token guards, and one atomic final collision commit. Refit keeps the selected
shape ID on the first included result, deterministically allocates additional
IDs, copies the selected surface/material metadata, and preserves unrelated
shapes exactly.

Prefab kind is authoritative for collision semantics in both editor validation
and strict content-pipeline parsing: obstacle shapes are `solid`, Platform
shapes are `oneWay`, and decoration Prefabs have no collision shapes. The scene
uses the Core-aligned clockwise/Y-down edge rule to distinguish active one-way
support from inert closure edges.

`PrefabV3Document` also retains immutable source snapshots for current Chunks.
Before any manual or generated collision commit, the plugin substitutes the
candidate Prefab catalog into every referencing snapshot and compares shared
content-pipeline compilation errors with that Chunk's baseline errors. This
detects transformed overlap, bounds, topology, and capacity regressions without
giving the Prefab domain Chunk write authority. Export re-reads affected Chunk
source bytes, blocks stale snapshots, repeats candidate compilation, and only
then continues the existing atomic Prefab/tile write.

Prefab collision sections are mounted as flat, independently collapsed sidebar
siblings. The active draft or selected shape forces only its owning section
open. Session Diagnostics remains independent of owner selection: it includes
catalog and collision findings for every owner, uses stable owner/shape fields
to navigate through the same draft guards as direct selection, and treats
expansion/focus as source-neutral presentation state. Narrow layouts preserve
the mounted scene above both sidebars, so a responsive resize cannot replace
the polygon controller or discard viewport, selection, or exact-field drafts.
The scene retains keyboard parity with the shared authoring reducer: Enter
saves a ready polygon draft and Escape cancels an active operation without a
source command. Row and section semantics preserve scene-first reading order
in the narrow Prefab layout.

## Chunk V2 Existing-Owner Composition Contract

`ChunkV2CompositionCommit` is the complementary immutable before/after
contract for tile layers, prefab placements, and enemy markers. It cannot
express changes to owner identity, revision, metadata, dimensions, or collision
shapes. Freshness comparison is structural across every retained field, so an
edit based on an outdated placement or marker list is rejected rather than
merged by list position.

The policy first requires source-canonical layer IDs, placement ordering and
scales, and marker ordering/fields through the same strict retained-metadata
codec used by chunk-v2 JSON. It then installs a candidate owner with one
revision increment into an immutable candidate document and runs complete
staged validation. This keeps exact prefab expansion, Core geometry/bounds and
overlap, enemy-marker identity/placement settings and level ground context,
seam analysis, and Core-owned hard limits outside route widgets. Any blocking
diagnostic returns the original owner and document identity; warnings may
accompany an accepted commit.

The single contract backs the granular placement, marker, and layer forms
without cloning mutation rules into widgets. Changed current source crosses
complete validation and the transactional Chunk store; lifecycle/path
semantics remain owned by their separate typed contract.

## Chunk V2 Source Ownership Plan

`ChunkV2Document.createdChunkKeys` distinguishes new in-memory owners
from owners loaded with exact baseline bytes. Every current owner still has one
workspace-relative source path. A loaded owner must have a baseline; a created
owner must not. Deleted loaded owners remain in the source-path/baseline maps
while absent from the current chunk list, which preserves the evidence needed
to describe deletion without consulting mutable filesystem bytes.

`ChunkStore.buildV2SavePlan` is pure planning. Existing custom source
paths remain stable, while editor-managed paths follow the canonical
`assets/authoring/level/chunks/<level>/<id>.json` rule. Therefore a retained
owner's level or display-ID change is represented as one write with an explicit
previous path; stable `chunkKey` remains the owner identity. New owners require
their canonical path, and deleted owners produce an exact baseline-backed
delete entry. Pending diffs use repository-portable `/` paths and show distinct
old/new paths for moves.

Planning rejects absent baselines, absent ownership paths, absolute or escaping
paths, case-insensitive final-path collisions, and reuse of a path still owned
by a pending deletion. The last rule deliberately favors an explicit two-step
delete/reload/create flow over ambiguous same-transaction ownership transfer.
`ChunkStore.applyV2SavePlan` rechecks the complete source set after
sibling staging, applies writes/moves/deletions through one rollback-safe
transaction, verifies the exact final file set and strict v2 bytes, and then
lets the session reload the installed source.

## Chunk V2 Lifecycle Contract

`ChunkV2LifecycleCommit` combines a typed create, duplicate, rename, or delete
operation with an immutable snapshot of current owners, revisions, created
state, source paths, exact baseline contents, active level, and level
revision/group tokens. Any intervening owner, metadata/composition/polygon
revision, ownership, active-level, or relevant level-definition change makes
the command stale. Rejected, malformed, missing-owner, colliding, and no-op
operations preserve the original document identity.

Create requires a canonical lowercase stable ID and an existing owner in the
active level to supply locked tile size and dimensions. It allocates a stable
key against all current and retained baseline ownership, creates empty
composition/polygons at revision 1, and deliberately starts deprecated. This
prevents an unfinished blank chunk from entering scheduler/seam pools. The
default assembly group is `default` when declared, otherwise the first lexical
declared group.

Duplicate copies the complete source owner, allocates a fresh ID/key/path,
resets revision to 1, and starts active because its terrain has already passed
source validation. Rename preserves `chunkKey`, advances revision exactly once,
and lets the ownership plan describe a managed file move. This intentionally
strengthens legacy behavior, where rename changed source bytes without a
revision bump. A created owner's path is updated directly because it has no old
baseline; a loaded owner retains its old path as move evidence.

Deleting a loaded owner removes it from the current set while retaining exact
path/baseline deletion evidence. Deleting a newly created unsaved owner removes
its provisional ownership and changed key, returning to a clean plan when no
other edits exist. Every accepted candidate passes complete current-document
validation and the ownership plan before plugin dispatch. Confirmed export can
write only against the strict current-source baselines.

## Chunk V2 Composition Operation Contract

`ChunkV2CompositionCommit` carries the expected `chunkKey`, expected owner
revision, complete before snapshot, and complete after snapshot. The plugin
still routes the command by its payload `chunkKey`; the policy compares that
resolved owner with the commit identity and revision before canonical structure
or full-document validation. Owner, revision, and composition mismatches share
the `chunk_v2_composition_commit_stale` diagnostic and preserve document
identity, history, revision, and pending diffs.

`ChunkV2CompositionOperation` is the immutable UI-operation token used by the
retained dialogs and future scene gestures. It captures the owner identity and
revision, all three composition lists, the targeted list, add/replace/delete
kind, and, for an existing record, its canonical source index and current
projection key. Candidate construction changes only that captured index or
appends one record, then runs the shared deterministic canonicalizer. A
semantic no-op returns no commit and therefore produces neither a command nor a
rejection message. Comparator-equal duplicates continue to fail the strict
composition policy.

Tile-layer, prefab, and marker equality and canonicalization live in one pure
domain seam shared by the operation token and commit policy. Derived placement
and marker keys remain projection-local: accepted candidates can retain
selection only through one unique full-record equality match, while undo,
redo, and reload reconciliation resolves only an exact current key. Dialog-open
state participates in the route's local-operation guard, disabling apply,
reload, session history, owner mutation, and other composition mutations until
the dialog cancels or submits. No Chunk-v2 JSON field or Core placement lineage
changes in this contract.

## Source Coordinates And Canonicalization

Editor terrain coordinates are stored as integer half-pixel ticks: two source
ticks equal one world unit. Normal Prefab and direct Chunk JSON accept only
whole-pixel collision coordinates, represented by even source ticks. The
shared representation retains half-pixel precision for migration, exact
transforms, and other internal geometry contracts. Serialization emits the
canonical numeric form for the domain being written.

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
reducer exposes that operation as one undoable before/after commit, and both
current Prefab and Chunk workspaces expose the action.

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
and scale as integer tenths. Chunk-v2 JSON retains the user-facing decimal
scale, while strict parsing converts only accepted `0.1` steps to the exact
integer-tenths Core boundary used by both editor preview and generation.

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

The pre-reset repository audit produced 88 topological candidate loops from 70
collision-bearing prefabs. Core accepted 85 loops across 67 prefabs unchanged.
`dark_menhir_01`, `dark_menhir_03`, and `ruin_stone_00` each produce an exact
one-source-tick (`0.5 px`) exterior edge below the accepted one-world-unit
minimum. The accepted resolution keeps the shared geometry rule and provides a
closed migration-only catalog of minimal outward replacements. They add 34,
25, and 36 half-pixel-square ticks (`8.5 px²`, `6.25 px²`, and `9 px²`) and are
bound to the complete expected collider lists. Any source drift blocks rather
than applying a stale correction. All 70 collision prefabs and 88 planned
loops now pass Core. The migration then applies rectangle-era prefab semantics:
all 66 obstacle owners emit `solid` loops and all 4 platform owners emit
`oneWay` loops. A decoration or unknown owner with collision fails closed.
Target conversion reapplies the same rule defensively, so a caller cannot turn
a platform solid by supplying a default-mode loop. That audit remains the
historical migration baseline. The current v3 file intentionally contains zero
collision shapes; the migration report retains 70 former collision owners as
`collisionCleared`, distinct from the 29 true decoration prefabs.

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
order does not affect the report. Before the collision reset, the report
contained 99 prefabs, 88 prefab shapes, 8 chunks, and 9 ground shapes with zero
planning blockers; its final pre-reset report fingerprint was `d75ba69e` after
binding prefab-kind collision modes.

The current reset report contains 99 prefabs (66 obstacles, 4 platforms, and
29 decorations), zero prefab shapes, 70 explicitly `collisionCleared` owners,
8 chunks, 8 full-width legacy gaps, and zero ground shapes or blockers. Its
plan fingerprint is `51630457`.

The plan exposes a pure pre-write audit for freshly computed SHA-256 values.
Changed, missing, or ambiguously canonicalized paths reject deterministically.

`PolygonAuthoringMigrationCheck` is the read-only repository orchestrator. It
classifies the complete source set before selecting a parser. Prefab v1/v2 plus
chunk v1 enters legacy planning; prefab v3 plus chunk v2 enters strict current-
schema validation; every partial or mixed generation fails closed. Legacy mode
builds all nine targets in memory and requires strict byte-stable target round
trips. Current mode requires source to already equal its canonical bytes,
rechecks Core geometry and placement references, and emits the same nine files
as byte-identical no-op targets. Readiness report v3 records source state, all
nine before/after SHA-256 pairs, 107 unchanged revision decisions, 99 Prefab
impact records covering 50 placements, and eight generated-artifact impact
records covering the same placements by owning Chunk. Each generated record
binds the shared staged output path and artifact format version, canonical Chunk
key/source path, sorted referenced Prefab keys, and exact placement count.
Legacy and equivalent current source produce identical records. They describe
dependencies only; final artifact bytes remain owned by seam-validated staged
generation and its output gate. For the current reset source, the legacy
readiness fingerprint is `f74fa5f0` and its equivalent strict current-state
fingerprint is `12475a2a`.

The editor migration domain also exposes `authoring-migration-v1` as the
reviewed SHA-256 contract. Its single UTF-8 length-prefixed record contains the
format label followed by the exact canonical readiness-report-v3 JSON. The
digest therefore binds the report's sorted source paths and source SHA-256
values, target before/after digests, revision decisions, impact records,
generated-artifact impacts, planned polygon source, and blockers without
embedding a circular signature field in the report. The collision-reset legacy
report signs as
`561d49b28eba5f6a86e78c212798a7c40e483d71b9484f76b1b2ac82bf6a2597`;
the strict current-schema no-op signs as
`3264cf7a0d276f851bcd19eb98c63a5d35aa473fdc5dcdeb82b21cee642dc15d`.
Changing only exact source bytes changes the signature. The existing short FNV
fingerprints remain compatibility/display tokens. The CLI emits the canonical
report. Explicit `--write` requires an external JSON report path and the same
complete blocker-free fingerprint-bound plan.

Migration retains its report-specific issue types and also exposes a shared
blocking-envelope view. Plan/check blockers and source-digest audits preserve
their source, decoded owner, element, code, and message while adding explicit
error severity and null placement/shape lineage. A source-loading exception
that aborts before owner decoding uses its canonical source path as owner.
These adapters are excluded from report JSON and `authoring-migration-v1`, so
diagnostic unification cannot silently revise reviewed readiness evidence.

Rectangle-era prefab records used by this path are isolated as
`LegacyPrefabDef`/`LegacyPrefabData` inside the migration layer. The strict
codec, migration planner, reviewed union, and v3 target conversion no longer
depend on normal `PrefabDef`. This preserves the frozen legacy interpretation
while the immutable normal `PrefabV3Def` record establishes polygon ownership
without retaining a second editable rectangle authority. Compatibility records
remain only in the active cleanup/test surface and are not selected by normal
current-source loading.

`tool/migrate_polygon_authoring.dart` defaults to check mode. It returns `0`
for a complete blocker-free readiness plan, `1` for source/plan/target/drift or
report-write failure, and `64` for invalid usage. Immediately before reporting,
it rereads and rehashes every source. The only optional write is an explicitly
requested workspace-relative `.json` report outside `assets/authoring`.
`--write` requires such a report path, applies the guarded transaction, and
records committed, no-op, or stable failure evidence. The command dependency
chain is pure Dart: shared model immutability annotations use `package:meta`
rather than pulling `dart:ui` into offline tooling.

Canonical prefab/chunk source paths likewise live in the Flutter-free
`RepositoryAuthoringPaths` contract. `PrefabStore` and `ChunkStore` retain
compatibility aliases, while migration code imports no store/plugin graph. A
subprocess regression compiles the real `--help` entrypoint with the standalone
Dart SDK, preventing future Flutter-backed store growth from silently
reintroducing `dart:ui` into the offline checker.

## Guarded Migration Write Foundation

The editor workspace layer now has one synchronous multi-file transaction for
the future one-time schema replacement. Every complete UTF-8 output is flushed
and byte-verified in a unique sibling file. Immediately before any source
moves, the caller runs its final optimistic-concurrency check. Existing files
then move to sibling backups, all replacements install and verify, and a
post-install callback runs while every backup is still recoverable. Failure at
any staging, move, byte verification, or post-install validation point restores
the complete original set in reverse order. Cleanup failure after a verified
commit is reported separately from a successful rollback.

`PolygonAuthoringMigrationTransaction` accepts only a complete blocker-free
`PolygonAuthoringMigrationCheck`. It requires one target for every reviewed
source path, binds every before/after SHA-256 to exact canonical bytes, repeats
the reviewed source audit in the transaction's final pre-move callback, and
loads the installed files through the strict current-schema checker before
backups are deleted. Success returns a deterministic report-v1 committed
record. Applying a fresh current-schema check returns a report-v1 no-op without
creating transaction files.

Failure evidence uses the same report version and stable write-mode envelope.
It distinguishes `blocked` before replacement, `rolledBack`, `rollbackFailed`,
and `committedCleanupFailed`. Stable code, message, and canonical source paths
are serialized; raw exception causes and unique transaction paths are excluded
so two equivalent failures do not drift by host or process.
The parallel terrain-authoring view emits one blocking issue per retained
source path; transaction-wide failures without file evidence use the stable
`migration/write` source and owner. It does not change rollback or report
semantics.

The migration command reaches this boundary only through explicit `--write`
with a required external report path. The completed source cutover installed
all nine current files and strictly reloaded them before backup cleanup; a
fresh repeated write is a byte-preserving no-op. Ordinary `--check` remains
read-only. At the migration checkpoint the old runtime authority remained
selected while the just-installed source described intentionally sparse
terrain; the later content pass and Phase 6 direct cutover replaced that
temporary state.

## Polygon Target Schemas And Normal Records

`PrefabV3Def` is the immutable normal-model record for the intended prefab-v3
shape. `PrefabV3FileData` snapshots the complete v3 file payload.
`ChunkV2FileData` snapshots one complete chunk-v2 file with its retained
composition metadata and direct polygons. Migration target names are aliases
for these normal records. Prefab v3 replaces only the legacy `colliders` field
with anchor-relative `collisionShapes`; chunk v2 replaces only
`groundProfile`/`groundGaps` with direct chunk-local `collisionShapes`. Existing
identity, revision, lifecycle, visual source, dimensions, composition,
placement, marker, tag, and ground-band metadata is preserved.

The normal records snapshot their lists but deliberately preserve supplied
shape, tag, layer, placement, and marker order. This lets validation diagnose
noncanonical authored input instead of silently repairing it.
`PrefabV3FileCodec` and `ChunkV2FileCodec` sort and normalize copied records
only while encoding, then strictly decode their own result before returning it.
Read-only planned output therefore remains deterministic without mutating the
source record or allowing an invalid enum/source model to escape.

`PrefabV3FileCodec` and `ChunkV2FileCodec` are the single current-schema
structural authorities in their normal domain layers.
`PolygonAuthoringTargetCodec` delegates both formats to them and adds no
compatibility behavior. Both require exact target versions and field sets,
canonical list/ID/tag ordering, exact integer fields, known enums, and accepted
placement-scale steps. Prefab collision and direct Chunk coordinates must be
whole pixels. Unknown and legacy fields reject rather than default.
Geometry/topology acceptance remains Core-owned and is not duplicated in
structural codecs.

All planned current repository output—99 prefab records and 8 chunk files—has
been encoded, decoded strictly, and re-encoded byte-for-byte in tests. The
normal editor layers own both current source structures. Normal plugin loading
selects strict Prefab-v3 or a complete Chunk-v2 tree, and changed current source
applies transactionally and reloads byte-identically. Legacy or missing source
selects the shared migration-required document without decoding editable
compatibility data. The generator and checked-in source JSON are current;
normal and replay collision consume the admitted polygon artifact.

The current load composes prefab v3 with the unchanged `tile_defs.json` v2
contract through `PrefabTileFileData` and `PrefabTileFileCodec`; it never sends
v3 source through rectangle-era `PrefabData` or its compatibility parser. The
tile codec strictly checks the retained field/type/version/order contract,
module identities, and unique cell positions, and byte-round-trips the current
repository tile source. It performs no filesystem writes.

`PrefabVisualBoundsResolver` is the single visual-rectangle rule used by the
v3 workflow and offline migration target review. Atlas owners use
authored slice width and height. Platform owners use an integer bounding
rectangle over module cells, their exact grid positions, and referenced slice
dimensions; negative cells
are supported and missing references fail closed. The strict plugin loader
also carries workspace-scoped atlas paths/sizes and both source baselines into
the current document/scene. A clean export is a no-op; changed current source
uses the paired transactional apply path.

## Chunk-v2 Current-Schema Validation

The chunk current-schema plugin composes strict prefab-v3/tile-v2 data with
every strict chunk-v2 file, its workspace-relative path, and its load-time
contents.
The current document and scene snapshot all collections, retain a
deterministic active-level projection, and never pass future records through
the ground-profile/gap compatibility model. Pending diffs compare canonical v2
encoding against immutable baselines. A clean export is a no-op; changed files
cross complete validation, final whole-tree drift checks, rollback-safe apply,
and exact reload. The temporary `Staging` type name is removed at cutover.

`validateChunkV2Document` requires stable unique chunk identities,
complete source baselines, a known active level, and known prefab references.
Each direct polygon vertex must use even half-pixel ticks, corresponding to a
whole-pixel coordinate, and remain inside the closed chunk rectangle. Core
reviews every loop under the canonical source policy and compiles each accepted
direct-owner set for exact overlap and hard limits. Exact placement expansion,
transform, post-quantization bounds,
expanded-owner limits, preview parity, marker rules, and scheduler-reachable
seams are part of the same blocking document validation.

`ChunkV2CollisionCommitPolicy` is the direct-owner boundary between one shared
interaction commit and session history. It requires the commit's before-shapes
to match the current immutable chunk, requires stable canonical shape order,
and reuses `validateChunkV2CollisionShapes` for closed bounds and Core review.
Every rejected or no-op attempt returns the original chunk instance. An
accepted semantic change replaces only `collisionShapes` and increments that
chunk revision exactly once.

`ChunkDomainPlugin.commitChunkPolygonCommandKind` performs owner lookup and
accepts only the typed shared commit. It returns the original current document
for missing, malformed, stale, invalid, and no-op input; a successful command
replaces only the addressed chunk, records its key, and produces one canonical
file diff against the load baseline. Complete validation plus the transactional
store remain the final filesystem defense. Route-local diagnostics and previews
remain outside the generic command result, matching the established Prefab
pattern.

`ChunkPolygonAuthoringController` projects exactly one chunk owner over the
shared reducer. Tool, selection, draft, gesture preview, snap policy, and
rejected diagnostics remain local. The controller verifies a semantic commit
through `ChunkV2CollisionCommitPolicy` before dispatching the typed plugin
command, and synchronizes only when the immutable session document identity
changes. An active preview receives first refusal on undo, so cancellation
cannot consume committed session history.

`ChunkSceneSurface` reuses the shared painter, projection, terrain hit test, and
focused keyboard contract. `ChunkSceneCoordinator` owns route-local input
domain and typed selection. The current workspace exposes terrain, prefab, and
marker source domains and never activates the coordinator's read-only
compiled-edge inspection branch. Terrain input delegates to
`ChunkPolygonAuthoringController`; prefab bounds and marker anchors resolve
through deterministic per-document projections. Escape, Enter, Delete, and
Backspace route to the active domain, while Ctrl-drag pans and Ctrl-scroll
zooms without mutating source. The owner bounds painter is display-only;
closed-bound validation remains in the chunk owner policy.

When a normal strict `ChunkV2Scene` is loaded, `ChunkCreatorPage` selects
`ChunkAuthoringWorkspace`; the v1 coordinator and the standalone composition
workspace no longer exist. `Chunk creation scene` stays mounted beside the
owner rail while persistent visual/viewport controls sit above the
Terrain/Prefabs/Markers/Layers selector. That selector filters the right sidebar
to one matching flat group of sibling authoring sections with no domain-level
wrapper card. Every owner, authoring, visual-stack, and Diagnostics section
starts collapsed. On narrow layouts, the same
scene and sidebar subtrees are repositioned; tab changes replace only the
sidebar section group. The tabs and section rows share typed per-domain prefab
and marker selection. The Prefab and Marker groups each begin with a searchable
visual library whose route-local selection feeds the matching scene Place tool
and controlled creation form. The enemy library projects stable `EnemyId`,
Core terrain-motion role, and the first idle frame from `EnemyCatalog` animation
metadata; its labels, search, filters, thumbnails, and selection never enter
Chunk source. Retained Marker edits use the same library with dialog-local
tentative selection. Prefab hit testing reverses the exact canonical
paint order, including the source-index tie break; marker anchor hit testing
reverses canonical source order and never targets resolved placement evidence.
Selection overlays and section expansion are route-local presentation state and
cannot create revisions, history entries, or pending diffs. Composition still
uses the shared validated forms for exact and non-spatial fields: creation is
inline in the sidebar, retained Prefab selection reveals an inline sibling
editor, and Marker/tile-layer edits use those forms in dialogs. Prefab list and
scene selection share the same selected editor. Its labeled Delete action uses
the normal immediately undoable composition command without a confirmation
modal.
Prefab select, place, and move tools use `ChunkPrefabSceneGesture`:
pointer-down captures the current composition operation token, pointer movement
changes only a local candidate, and pointer-up returns at most one existing
`ChunkV2CompositionCommit`. Grid-enabled anchors quantize to the current
chunk's tile size; free anchors quantize to integer pixels; exact form fields
preserve entered integer pixels. Both policies use deterministic half ties away
from zero. A default-on route-local surface-contact pass may then refine only Y
to another whole-pixel origin. It derives the Prefab's post-reflection/scale
lowest horizontal collision edge, requires a positive-length horizontal
interval against a Core-exposed upward-facing direct-terrain edge within eight
screen pixels, and accepts the candidate only when every transformed loop stays
inside Chunk bounds and Core's exact predicate finds no occupied-area overlap
with direct terrain or another placement. The moved source placement is omitted
from that gesture snapshot by its captured placement key. Rejection restores
the accepted projection without revision, history, or pending-diff changes.

Marker Select, Place, and Move tools follow the same operation-token and
exactly-once command boundary through `ChunkMarkerSceneGesture`, but quantize
only to integer source pixels. A marker preview is always the authored query
anchor. During a move, the prior record's accepted connection, resolved body,
and support evidence are suppressed so candidate source is never paired with
stale Core evidence. The marker-evidence toggle controls those resolved facts;
authored anchors remain visible whenever the marker domain is active. Accepted
commands rebuild the Core placement projection, while unsupported, deferred,
disabled, malformed, and rejected outcomes remain read-only diagnostics.

The realistic Windows profile fixture renders 16 direct shapes, 43 placed
prefabs, 256 compiled edges, and 24 marker outcomes while dragging terrain.
The unified workspace fingerprints only sidebar-relevant controller state, so
pointer-only terrain previews repaint through `ChunkSceneSurface` without
rebuilding the owner/composition sidebar. Marker placement evidence is also
cached by accepted chunk, its internal terrain projection, and ground-top input. The
August 14, 2026 profile run reports vertex/shape update p95 of `239/242 us`,
build p99 of `1.866/1.854 ms`, and no missed input, build, or raster budget.
Reload and confirmed current-source apply route through the normal session and
transactional store. Active-level changes still use the plugin command and
rebind to the first canonical owner in the new scene. Owner changes dispose the
old route-local controller, preventing
an unfinished preview from leaking across chunks. Legacy or missing plugin
loads return the shared migration-required state, so v1 ground/gap editing and
export are not normal source paths.

The Chunk workspace's right authoring column owns one vertical scroll surface.
The `Terrain`, `Prefabs`, `Markers`, and `Layers` tabs sit below the persistent
visual/viewport controls and mount only the matching right-side section group
while leaving the scene and viewport mounted. Terrain
contains creation and existing-shape authoring. Prefabs and Markers each use a
foldable visual library, inline creation form, and separate existing-placement
list; add commits no longer require modal navigation, while existing Prefab
edits render below the selected row and Marker edits retain the shared validated
form and enemy library in a dialog. Layers contains the visual stack and
tile-layer metadata. One shared Diagnostics section follows
the active domain sections and presents the complete session issue projection
on every tab without owner or domain filtering. Per-domain selection survives
tab changes, and an active operation locks the tabs. Layers is a passive scene-input
domain because tile layers remain metadata-only. Compact owner-row previews
reuse the scene's background, terrain-material, placed-prefab, and foreground
visual projections with a fit-to-chunk transform; they remain read-only and do
not introduce a second authoring or persistence path.

The Chunk shape inspector uses the same `TerrainPolygonVertexEditor` as Prefab
staging. Its integer/`.0`/`.5` parser never sends malformed fractions to the
controller. A valid whole-pixel coordinate override enters the active direct
terrain snap policy, then the shared reducer and chunk bounds/Core owner
validation. With tile snap enabled, vertex values and both opposing rectangle
corners round to the nearest owner tile-grid intersections before the semantic
commit.
Rejected out-of-bounds text remains visible with its exact diagnostic and does
not change revision, pending diffs, or history; an accepted replacement creates
one owner revision/history entry.

Collision mode, optional `surfaceKind`, and optional render `materialKey` use
one shared owner-neutral dialog on both current routes. Optional text is trimmed
and empty text becomes `null`; the dialog returns only a value object and never
mutates the document. Each route sends that value through its controller,
shared reducer, owner policy, and typed plugin command. The dialog state owns
its text controllers until the route-removal animation completes, avoiding an
early-disposal race after `showDialog` resolves.

## Prefab Polygon Owner Validation

`validatePrefabCollisionShapes` is independent of the retained compatibility
`PrefabDef`, allowing one rule set to serve normal Prefab-v3 authoring and the
migration target. It requires collision shapes for obstacle/platform owners and forbids
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
The plugin handler reuses this policy defensively and returns the original
document for a stale, invalid, malformed, or no-op command. An accepted command
creates one immutable document replacement, advances the owner revision once,
and records the owner key for deterministic pending diffs. This keeps invalid
drags and empty commits out of session undo/redo.

The handler is exercised through `PrefabV3Document`. Normal loading constructs
it only after strict v3
generation detection; legacy v2 or missing source instead constructs the
shared migration-required document. Clean export is a no-op. Changed current
source crosses complete validation and the paired source-drift-guarded,
rollback-safe store transaction, then reloads the installed bytes. The
temporary `Staging` type and route names were removed after source cutover.

`PrefabPolygonAuthoringController` proves the route boundary against that
current document. It keeps tool, selection, draft, gesture preview, and rejected
diagnostics local; runs the same owner policy before dispatch; and sends one
typed plugin command only for an accepted semantic change. It synchronizes
after session undo/redo by immutable document identity, not every session
notification, so loading/export flag notifications cannot discard an active
preview. Undo during an active operation cancels that preview before touching
committed history.

`PrefabPolygonSceneSurface` projects the controller through the shared scene
painter and hit test. Primary input is tool-driven; Escape cancels, Delete acts
on the selected shape/vertex, Ctrl-Z/Ctrl-Shift-Z use session history, and
Ctrl-drag delegates pan without mutating the document. The viewport transform
remains display state. Normal Prefab loading selects this surface for strict v3
source. Legacy or missing source exposes only the migration-required workspace
and cannot render or write the v2 rectangle workflow.

When the strict current scene is present, `PrefabCreatorPage` selects
`PrefabPolygonWorkspace`. The normal plugin returns the current document or
the no-data migration state; rectangle-era documents, coordinators, forms,
commands, and stores no longer exist on the normal path. The polygon workspace
owns prefab
selection, tool/snap/viewport state, exact shape readout, metadata actions, and
diagnostic focus. Switching owners disposes the old route-local coordinator,
which discards any uncommitted preview instead of transferring it to another
prefab. Route-level shortcuts delegate back to that coordinator so an active
preview still receives first-refusal cancellation before session undo.

`PrefabPolygonVisualProjection` establishes one visual coordinate rule for the
current route. Atlas slices start at `(-anchorXPx, -anchorYPx)`. Platform-module
cells first normalize against the complete module bounds, including negative
grid cells and actual slice dimensions, then apply the same anchor-relative
origin. `PrefabPolygonVisualSource` decodes images in a cache whose lifetime is
the current workspace widget state, resets that cache on workspace changes,
and draws deterministic fallback cells for unavailable files. It paints only
visual evidence, bounds, grid, and anchor beneath the shared collision painter;
it never derives or mutates collision authority.

The Prefab staging page uses one fixed `1 px` collision grid and exposes no
precision selector. The fixed policy performs the only pointer-to-source
rounding. Shape rows sort by stable shape ID. Diagnostics retain
shape/edge/vertex identity where available and focus the corresponding element
without creating history. Geometry is painted outside the visual-source
outline rather than clipped to it. Decoration owners remain selectable for
inspection but disable collision creation and retain empty collision source.

Numeric vertex fields use `TerrainHalfPixelText`, which converts signed
integer, `.0`, or `.5` pixel strings directly to integer source ticks without a
floating-point intermediate. Comma decimal input is normalized for editor
ergonomics; other fractions, malformed text, and values beyond Core's authored
coordinate range remain field-local errors. Both current Prefab and Chunk
routes reject parsed odd ticks with a whole-pixel field error. A parsed
coordinate is an explicit numeric override, so it does not pass through pointer
snapping. The shared reducer replaces the selected vertex, re-runs Core
canonicalization and cross-shape overlap checks, preserves the selected vertex
by exact value after canonical reordering, and emits at most one semantic
commit. The prefab route then applies the usual owner visual-bounds and
revision policy before session history. Rejected geometry leaves both the
committed document and typed field state unchanged while exposing actionable
diagnostics.

The source-apply action is enabled only for committed current-schema changes
with no transient catalog draft. Confirmation routes through complete plugin
validation, the paired drift-guarded transaction, and exact reload. Legacy or
missing source cannot reach this chrome or its export boundary.

## Chunk Placement Expansion And Read-only Preview

`expandChunkV2Collision` is the single editor-domain projection for staged
chunk-v2 direct shapes plus resolved prefab-v3 placements. It is pure and
immutable: it accepts one chunk, the prefab catalog, stable source identity, and
the deterministic chunk index; it returns either an accepted Core geometry
bundle plus read-only prefab-shape lineage, or sorted validation issues. It does
not mutate chunk source, prefab source, revisions, generated data, or runtime
objects.

Placement selection uses `buildChunkPlacedPrefabSelections`, so every expanded
shape retains the existing `prefabRef|x|y|ordinal` placement key. Prefab
references resolve by stable key or retained ID; missing and ambiguous
references block complete projection. The existing `0.3..3.0` placement scale
must be finite, in range, and aligned to an exact tenth before it becomes the
Core transform's integer numerator.

Prefab-v3 collision vertices are already authored relative to the prefab
anchor. Placement expansion therefore supplies a zero source anchor to
`TerrainSourceTransform`; `anchorXPx`/`anchorYPx` remain artwork-projection
metadata and must not be subtracted from collision a second time. Core then
owns reflection, exact scale, placement translation, one `1/1024 px`
quantization, transformed canonicalization, occupied-area overlap, shape/vertex
limits, exposed-edge construction, and edge limits. Direct and expanded shapes
enter the same compile call, so a placed polygon cannot overlap direct terrain
or another placement unnoticed.

### Whole-pixel prefab surface contact

`ChunkPrefabSurfaceSnap` is an editor-only projection over accepted Core
geometry; it does not alter `PlacedPrefabDef`, Prefab-v3, Chunk-v2, or runtime
generation. Its terrain targets are compiled edges with no placement lineage,
zero vertical delta, non-zero length, and an upward Y-down outward normal. Its
moving support is derived after Core's exact reflection and tenth-scale
transform at zero translation: all non-render-only Prefab collision vertices
must lie on or above the global support Y, and at least one non-zero horizontal
edge must lie on that Y.

The gesture context recompiles only the already-accepted direct collision
polygons once at pointer-down. This preserves a terrain interval that the
combined compiler correctly canceled as an internal edge beneath the currently
accepted placement. Occupied-area obstacles still come from the complete
accepted geometry; only the captured moved placement is removed from them.

All authored placement origins remain integer pixels. A scale is contact-
compatible only when the derived support Y is divisible by
`terrainPhysicsTicksPerWorldUnit`; this is why forcing an integer origin alone
cannot make every half-pixel/scaled collider touch an integer terrain line.
Creation chooses the compatible scale nearest `1.0`, with the smaller scale as
the deterministic equal-distance tie. The Scale field lists compatible values
for a supported collider/flip state. It retains an already-saved incompatible
value as an explicitly explained current option, while Prefabs without
collision or without a derived support keep unrestricted visual scales.

Gesture resolution first applies the existing tile/integer quantizer. It keeps
X unchanged, searches terrain surfaces within `8 / zoom` world units, derives
the only whole-pixel Y that makes the support lines equal, and requires strict
horizontal interval overlap so a corner touch cannot masquerade as supported
edge contact. Candidate loops are translated from the same Core-quantized
profile and checked against closed Chunk bounds and
`TerrainPolygonOverlap.physicsLoops` for every accepted polygon except the
moved source. Deterministic choice orders by vertical distance, Core edge ID,
and support-edge index. Exact shared boundary remains legal; positive-area
penetration remains blocking in both preview and the unchanged final Chunk
compiler.

The expanded-collision painter suppresses the accepted loop being moved and
draws candidate Core ticks orange, or green after exact contact succeeds. The
preview owns no hit test or write path. Disabling **Surface snap** restores the
original grid/pixel gesture policy without changing persisted source.

Every transformed vertex is checked against the chunk's closed bounds in Core
physics ticks. A bounds issue retains source path, placement key, local shape
ID, vertex index, and an exact terminating decimal coordinate. Accepted
compiled geometry is retained when bounds evidence exists so the offending
shape remains visible; incomplete source resolution or a compiler failure does
not publish a partial overlay.

`ChunkV2Scene` owns the immutable result per active-level chunk. The current
Chunk workspace draws accepted expanded prefab loops directly from
Core's quantized vertices beneath the editable direct-shape painter. This
overlay is wrapped in `IgnorePointer`, exposes no hit-test/editing API, and lists
prefab revision, placement key/transform, and local shape lineage with a lock
indicator. Expanded issues cannot focus a same-named direct shape. The scene
also reports direct, expanded, total-shape, and exposed-edge counts against
Core's hard limits separately.

At-limit authoring fixtures now accept 64 vertices per shape, 64 shapes per
placed Prefab, 512 combined shapes per Chunk, and 4,096 exposed edges. Exact
one-over fixtures fail without a partial geometry product and preserve the
responsible owner. In particular, the 4,097-edge fixture contributes one
direct one-way edge beside an otherwise at-limit expanded Prefab, so the
limiting edge is proven to retain Prefab key, placement key, shape ID, edge
index, and source path through both the staged generator and editor adapter.
Core's private raw-edge representation carries source path through collinear
splitting and internal-edge cancellation solely for this diagnostic; runtime
`TerrainEdge` and signatures do not change.

Soft authoring capacity is a separate, non-blocking contract. Core publishes
the frozen targets of 16 shapes per Prefab, 24 vertices per polygon, and 1,024
compiled exposed edges per Chunk without applying them inside
`TerrainCompiler`. Prefab validation, direct Chunk commits, and complete Chunk
expansion emit `prefab_shape_soft_target_exceeded`,
`polygon_vertex_soft_target_exceeded`, or
`chunk_exposed_edge_soft_target_exceeded` only when the matching count is
strictly greater than its target. Each warning retains its Prefab/Chunk owner
and shape where applicable; a referenced Prefab is reported once per Chunk
validation rather than once per placement. The Prefab domain plugin preserves
that owner when adapting its issue into generic editor validation. Warnings
preserve accepted source, commits, compiled geometry, and overlays. There is
deliberately no soft combined-shapes-per-Chunk warning because Phase 0 accepted
no such target.

The default-off compiled-edge layer renders `TerrainGeometry.edges` above
the source-loop painters whenever compilation succeeds. It therefore shows
Core's actual exposed result after collinear splitting, internal-solid
cancellation, and one-way filtering; it never reconstructs edges from polygon
fill. Solid edges render pink and one-way edges yellow. The route-local
**Shape edges** chip changes only this painter's visibility.

**Visual preview** is a separate route-local presentation mode. It suppresses
the source polygon painter, Chunk bounds, viewport border, expanded collision,
compiled edges, Prefab selection, gesture previews, marker anchors, and marker
placement evidence. The remaining canvas is the runtime-facing composition of
parallax, terrain-material art, and placed Prefab visuals. Primary canvas and
sidebar authoring are disabled in this mode, while pan, zoom, and reset remain
available. Entering or leaving it cannot change selection, source, history,
pending diffs, or collision authority. The Chunk scene exposes no compiled-edge
inspection mode.

The default-off **Actor terrain** chip sits next to **Marker placement**. It
builds and caches `ChunkV2ActorTerrainProjection` from the accepted compiled
expansion and paints only Core-owned evidence. Éloïse is selected initially;
her cyan surface overlay is the exact traversal-profile eligibility answer for
the current accepted terrain. The selector also exposes Grojib and Hashash
surface/graph evidence, Unoco blocker and local-hover candidates, and Derf
perch evidence. Its summary and overlay are read-only and disappear in
**Visual preview** without changing the stored preference.

Marker placement reuses the same version-coherent surface set, graphs, solid
blockers, local-hover candidates, and Derf perch eligibility. The projection is
built when either actor-terrain or marker evidence requires it, and never
mutates source, history, revision, collision authority, or RNG state.

The opt-in marker layer uses that internal terrain projection and constructs a
`TerrainSpawnPlacementResolver` over its version-coherent Core geometry, edge
index, surface index, and surface-set identity. Explicit chunk-v2 staging also
loads each referenced level's `groundTopY` through `LevelStore` and snapshots
it into the immutable document/scene. A chunk with authored markers and no
finite, Core-quantizable level ground plane fails staged validation;
marker-free fixtures do not require synthetic level context.

Outcomes remain in original authored marker order. Stable selection keys reuse
`buildChunkPlacedMarkerSelections`; chance, salt, marker ID, placement string,
and authored X/Y are copied without normalization or mutation. The projection
does not roll chance. It classifies 100% and conditional accepted/rejected
placements separately, keeps 0% markers disabled, reports malformed source
contracts before Core invocation, and retains Core's typed validity plus its
canonical integer diagnostic.

Marker X enters the deterministic physics grid; marker Y does not. The latter
is editor anchor metadata and is intentionally absent from generated
`SpawnMarker`. Ground intent chooses a direct solid upward surface at marker X
whose exact Y equals the level ground plane. Highest-surface intent chooses the
physically highest upward surface before actor filtering. During this locked
staging bridge, obstacle-top intent chooses the highest solid upward surface
with placed-prefab lineage, matching the current static-solid content role
without inventing a new authoring tag. Equal-height candidates use canonical
edge-ID order.

The selected surface Y produces the historical body candidate from the
catalog-owned upright capsule and offset. Unoco instead uses Core's default
150-pixel hover offset; one-way terrain remains excluded from its clearance.
The request carries the exact intended edge ID and delegates slope, support
width, same-edge clamp, full-capsule clearance, support point, blocker, and
final body transform to the accepted Phase 3 resolver. The overlay draws the
authored anchor, intended support, requested or accepted upright capsule, and
rejection mark; selection exposes every exact ID, point, slope, clamp, and Core
diagnostic.

For accepted non-deferred outcomes, the same layer also decodes the first idle
frame and aligns its catalog animation anchor to the accepted body center at
the catalog-owned uniform render scale. Sprite art is drawn before the support
and capsule evidence so inspection remains legible. Outcomes without an exact
accepted static body center never receive a substitute position or sprite.

Hashash markers are not resolved at authored X: an accepted runtime roll adds a
deferred count and later chooses the visible camera-right chunk edge. The
projection therefore records guaranteed or conditional deferral without a
placement query or RNG draw. Procedural collectible/restoration candidates
have no authored marker records and are not fabricated. Projectile motion is
not a marker-placement concern and is not previewed here; runtime ballistic
projectiles sweep the admitted terrain edge index.

When this marker-staging bridge was introduced, source and runtime authority
were unchanged. The later collision reset and v3/v2 source cutover change
authored/generated content, not this marker resolver's ownership. Generator
parity and placement editing now retain the same zero-RNG marker contract.

## Scheduler-Aware Compiled Chunk Seams

Explicit chunk-v2 staging snapshots the complete immutable `LevelDef` records
loaded by `LevelStore`, rather than reconstructing scheduling from the chunk
directory. `ChunkV2SeamAnalysis` imports Core's `ChunkPatternTier` fallback
order directly. Active chunks are grouped by authored tier and, when assembly
is enabled, the selected segment's `assemblyGroupId`; deprecated owners remain
visible but are not scheduler candidates.

For levels without assembly, enumeration is structural and constant-size: it
adds within-window Cartesian pool pairs where a tier contains at least two
scheduled positions, each boundary between nonempty requested windows, and the
infinite hard-to-hard tail. Empty requested pools use Core's exact tier
fallback order. Both directions appear whenever independent pool selection can
emit both orders.

For authored assembly, a finite state set enumerates every segment/run
alignment through the early/easy/normal prefix, including variable run
lengths and tier boundaries inside a run. The hard tail is enumerated
structurally for every possible within-run transition and every directed
between-run segment transition, including loop-to-first and non-loop
last-to-last behavior. A distinct run excludes a same-chunk pair only when
both positions resolve to the same tier/group pool; changing fallback pools at
a tier boundary keeps the Cartesian pair set because Core resolves each
position independently. Every eligible pool used by a distinct segment must
contain at least its maximum run count. Analysis never samples or consumes
gameplay RNG and never changes scheduling/content.

Assembly-enabled finite prefixes above 256 chunks fail closed with
`chunk_v2_scheduler_analysis_capacity_exceeded` instead of allocating
unbounded state. The structurally complete hard tail is still reported. This
is an authoring-analysis capacity contract, not a gameplay pacing limit; a
larger supported window requires a reviewed symbolic implementation or a
measured bound change.

Each accepted `ChunkV2CollisionExpansion` produces canonical left and right
`authoring-boundary-v1` evidence from `TerrainGeometry.edges` in integer
`1/1024 px` ticks. The signature retains ordered compiled edge lineage,
endpoints, tangent, outward normal, collision mode, surface kind, and material
key. Its physical profile separately contains merged positive-length vertical
coverage intervals keyed by collision mode and non-collinear continuation
endpoints keyed by collision mode, surface kind, and exact Y. A boundary with
neither fact is explicitly `empty`.

A reachable seam compares the left chunk's right physical profile with the
right chunk's left profile. Exact coverage or continuation differences block
with level ID, structural scheduler transition, directed chunk keys/sides,
both canonical digests/profiles, and sorted exact mismatch coordinates. Equal
open boundaries are compatible. Surface-kind differences block traversal
continuity; material-key differences remain retained endpoint evidence for
Phase 5 rendering and do not block the Phase 4 physical gate.

The global staged validator expands all chunks once and applies every
scheduler-reachable comparison, so an individually valid owner cannot pass
while breaking another reachable transition. The active-level scene consumes
the same immutable result only for its compact neighbor/directed-seam summary;
the Terrain collision sidebar does not list transition cards. This summary
exposes no edit, revision, pending-diff, RNG, or scheduling authority.

Sorted reachable transitions form `authoring-seams-v1`. The pure-Dart Core
boundary owns both finite scheduler reachability and the immutable transition
record, total order, duplicate rejection, canonical set record, and SHA-256.
Its source-neutral level/chunk inputs cover tier fallback, assembly runs,
distinct selection, deprecated-owner exclusion, loop behavior, and the bounded
hard tail. The editor adapts its immutable domain models into that boundary and
compares the result with the checked-in eight-transition
`reachable_seams.json` golden. Sampled Core assembly runs remain required to be
subsets of the enumerated set.

The staged generator's strict manifest decoder consumes those same fixture
bytes and recalculates the exact record and digest
`9681ffb17f61812ec63f1522f9da99340fd1a3ba05b0103f7d8a5f0ffd76393b`.
Unknown/missing schema fields, duplicate transitions, delimiter-ambiguous
identities, canonical-record drift, and digest drift fail closed. This proves
cross-process adjacency-set parity. The staged generator then resolves every
transition against the shared Core compiled-boundary comparator before it can
construct the renderer's accepted batch, as detailed below. The live
current-schema generator consumes the same enumerator without importing editor
code or duplicating scheduler logic. Runtime scheduling consumes the generated
catalog and does not execute this offline enumeration or spend gameplay RNG.

## Generated Artifact Plan And Dry-Run Drift Gate

`tool/generate_chunk_runtime_data.dart` remains the single repository
generation entry point. After strict current-source compilation and seam
validation, it renders all six Dart outputs completely in memory and snapshots
them in one immutable artifact plan sorted by path. Five outputs retain their
established record shape; the sixth is the generated polygon artifact admitted
by normal and replay Core construction.

Dry-run compares each rendered UTF-8 byte sequence with the corresponding file
bytes. It emits stable, path-sorted diagnostics for missing, stale, or
unreadable expected files. It also scans only the declared generated-output
roots for the entry point's ownership marker and reports a marked file that is
not in the expected plan as unexpected. The marker restriction prevents an
unrelated Dart source below `lib/` or `packages/runner_core/lib/` from becoming
a false generated-output diagnostic.

Drift inspection never creates, replaces, or deletes a file and exits nonzero
when any diagnostic exists. Normal generation writes the same already-rendered
plan through a rollback-safe multi-file transaction. Canonically equivalent
absolute target paths are rejected before filesystem access. Each rendered
byte sequence is flushed to a unique sibling staging file, keeping the rename
on the target volume; existing targets then move to unique sibling backups.
After all staged files are installed, the writer re-reads and verifies every
byte before deleting backups.

Any staging, backup, replacement, or verification failure restores changed
targets in reverse order and removes transaction files. The surfaced exception
distinguishes a complete rollback, an incomplete rollback needing manual
recovery, and cleanup failure after every output was already verified and
committed. This is the generated-output transaction only: it does not replace
the migration CLI's pending source-fingerprint recheck and nine-source schema
transaction. Polygon-schema selection, staged-output registration,
seam-manifest consumption, and compiled-boundary gating are now delivered.

## Strict Staged Generator Compiler And Artifact Foundation

The live generator selects the current Prefab-v3/Chunk-v2 repository source.
Six focused pure-Dart files implement that boundary without adding an alternate
compiler or runtime-selection flag:

- `polygon_terrain_source.dart` strictly parses prefab-v3 and chunk-v2
  structures as written, including field sets, exact types, canonical list
  order, Prefab and direct Chunk whole-pixel coordinates,
  exact scale tenths, collision metadata, and retained placement fields;
- `polygon_terrain_compilation.dart` resolves stable prefab references and
  placement ordinals, applies the accepted anchor-relative Core transform,
  pre-reviews canonical source, compiles complete gameplay geometry plus
  direct-only fill and material-edge geometry, enforces closed chunk bounds,
  and retains prefab key/id/revision lineage;
- `polygon_terrain_seam_manifest.dart` strictly decodes the shared scheduler
  adjacency golden and recalculates its Core-owned record/digest;
- `polygon_terrain_seam_validation.dart` resolves every directed transition to
  compiled chunks, checks level ownership, and compares exact Core-owned
  right/left boundary evidence before constructing a renderable batch;
- `polygon_terrain_render.dart` validates chunk-local compiler identity, sorts
  every rendered record family, accepts only that validated batch, and emits
  typed staged Dart records in memory;
- `polygon_terrain_artifact_validation.dart` compares a typed artifact with the
  fresh seam-validated compile and returns no selectable artifact on any
  version, format, seam, Chunk membership/metadata, or signature mismatch.

Before a staged artifact can bind a scheduler selection, Core's
`StagedTerrainArtifactCatalog` independently checks the accepted compiler and
signature-format versions, lowercase SHA-256 digest shape, canonical chunk-key
order, and polygon/edge/triangle/placement-lineage membership. This is a
structural runtime guard, not a second compiler: fresh semantic source and seam
validation remain generator-owned.

Parsed coordinates remain generator values until the Core adapter boundary.
This matters because the canonical JSON number range is intentionally wider
than Core's safe source range: a structurally valid but physically oversized
coordinate becomes a stable `chunk_collision_source_value_invalid` or
`prefab_collision_source_value_invalid` issue instead of escaping as a raw
range exception. Safe loops are reviewed with `requireCanonical: true` before
compilation because `TerrainCompiler` normally canonicalizes winding/start for
runtime safety; generation must diagnose noncanonical current source instead
of silently rewriting it.

Core's `TerrainTriangulator` derives render triangles only from normalized
`TerrainPolygon` products. Exact BigInt orientation and inclusive containment
select the first valid ear in surviving canonical-index order. Every result
must contain exactly `vertexCount - 2` positive triangles whose exact
doubled-area sum equals the Core polygon. Triangle indices reference that same
normalized loop. The generator triangulates direct Chunk fill geometry,
including direct `none` roles. Gameplay edges come from complete collidable
geometry, while material edges come from direct collidable Chunk geometry.
Malformed or noncanonical compiled input fails rather than producing partial
triangles.

Core also owns the immutable `authoring-triangles-v1` record and SHA-256
contract. Records bind chunk, optional placement, shape, and the three
canonical-loop indices, sort by that identity, and reject exact duplicates.
The root generator maps Core triangle indices directly into these shared
records; the editor parity adapter calls the same triangulator and signature
function. Neither consumer reimplements ear selection or triangle
serialization.

The staged output path is owned by Core's
`stagedTerrainArtifactRepositoryPath` constant as
`packages/runner_core/lib/track/staged_authored_terrain.dart`. Offline migration
and generation share that workspace-relative identity. It is registered in the
generator plan. Normal and replay Core admit it for scheduler binding, atomic
collision/navigation publication, placement, and rendering. Its deliberately
narrow API is `StagedTerrainArtifactData`, defined in
`staged_terrain_data.dart`; `ChunkPattern` remains scheduler identity and spawn
intent only. The retained `Staged*` names describe the generated artifact and
publication format, not a disconnected or selectable runtime mode. The
artifact is self-describing with artifact and
compiler geometry versions plus `authoring-polygons-v1`, `source-v1`,
gameplay and render `edges-v1`, `authoring-placement-v1`,
`authoring-triangles-v1`, and
`authoring-seams-v1` labels and signatures. Adding the authored-source digest
advanced the generated artifact schema to format version 2; adding
the validated reachable-adjacency digest advanced it to format version 3;
separating direct render edges from placed Prefab collision advances it to
format version 4.
Each chunk record retains source revision/metadata, canonical source vertices
in half-world-unit ticks, transformed vertices and exposed edges in integer
physics ticks, collision/render metadata, deterministic triangle indices, and
exact prefab placement/revision lineage.

The artifact's declared values are not trusted merely because its Dart types
construct successfully. `validateStagedPolygonTerrainArtifact` compares the
artifact/compiler versions, all seven signature-format labels, the exact
reachable-seam digest, canonical Chunk membership and source metadata, plus
the authored-polygon, Core source, Core edge, render-edge, placement, and triangle
signatures for every Chunk against a fresh accepted batch. Findings use the
shared `TerrainAuthoringIssue` severity/owner envelope; a Chunk-local mismatch
owns that Chunk, while an artifact-global mismatch owns the canonical output
path. Any issue makes the returned artifact null. `GeneratedArtifactPlan`
continues to own exact rendered payload-byte validation, avoiding a second
polygon/edge serialization authority. The read-only
`validateStagedPolygonTerrainOutput` composition applies both gates, converts
missing/stale/unexpected/unreadable output findings to the shared blocking
envelope with the generated path as source and owner, and returns the complete
canonical issue set with no artifact if either side fails.

### Runtime Render Consumption

`GameCore` constructs one `StagedTerrainStreamCandidate` after the deterministic
scheduler changes its active selection. The candidate binds those exact chunk
indices/origins, builds one geometry/runtime bundle, and pairs it with one
immutable `StagedTerrainRenderSnapshot`. Normal collision, navigation,
placement, and rendering consume that same bundle/candidate rather than a
renderer-specific reconstruction. Anonymous custom chunks publish no candidate
and never borrow another chunk's geometry.

World binding also performs the compiled union operation that cannot exist in
chunk-local generated records. Exact reversed faces with matching collision
mode and surface kind are removed as internal seam faces. The retained
neighbors reconnect through their original edge IDs; equal tangents become
smooth joins and other valid turns become connected joins. Material differences
remain render metadata and do not prevent physical cancellation. Same-directed,
third, or physically incompatible coincident edges fail the whole candidate.

Flame's `StagedTerrain` component converts physics ticks to world units once
per geometry version and creates `ui.Vertices` with the supplied Core triangle
indices. It never triangulates, normalizes, stitches, or infers polygon edges.
`StagedTerrainRenderSnapshotBuilder` requires every solid/one-way staged loop
to match the published collision polygon exactly. A staged `none` loop must be
absent from collision geometry. Direct Chunk loops become terrain fills;
placed Prefab loops remain collision-only because their sprite layer owns
their appearance. Material decoration consumes the generated direct-only
render edges, so exact Prefab contact cannot split or cancel the terrain skin.
Fill texture phase is world anchored. The generated material registry maps
top/slope, left-wall, right-wall, and underside profiles onto exact retained
`TerrainEdge` outward normals; an absent optional profile intentionally leaves
that orientation fill-only. Paired top and underside caps render at Core
`exposed` endpoints. At a `connected` join, shared pure-Dart corner math uses
the incoming inward normal and outgoing tangent to distinguish convex from
concave turns. A convex turn receives exactly one available adjacent cap, with
top-facing art winning and the incoming end breaking equal-priority ties;
concave turns and `smooth` continuations remain band-only. Caps and corner
patches render in a final foreground pass after all repeating edge bands.
Terrain is composed in an isolated layer: fill covers the complete polygon,
ordered edge bases replace fill including source alpha, detail overlays its own
base, and ordered caps replace every lower terrain role. Transparent pixels
therefore reveal the scene without complementary clip-path boundaries. The
resulting visual priority is cap, top-facing band, wall/underside band, then
fill.
Internal edge repeats alone receive destination-over material-fill backing for
one source pixel on each side of their world-phased tile boundary. Endpoints
and all other transparent edge pixels remain unbacked; later edges and caps
still win by paint order.
Repeating bands stop at their exact Core edge endpoints; runtime and editor
rendering do not stretch one band beneath another to hide join wedges. A null
material is collision-only and not drawn; an
unknown non-null material fails through `TerrainMaterialRegistry` instead of
selecting a visual fallback.

`assets/authoring/level/terrain_material_defs.json` is the canonical visual
material source. The pure-Dart `terrain_materials` package owns its strict
schema and canonical encoding, and the root content generator verifies every
referenced image plus every polygon `materialKey` before generating
`authored_terrain_materials.dart`. This removes the former hand-maintained
runtime/editor registry duplication. The editor's Terrain Materials route owns
catalog CRUD, workspace-scoped PNG selection, composed previews, explicit
orientation coverage, reference-safe rename/delete, and manifest validation.
Polygon metadata selectors and the Chunk scene consume that same manifest. The
`grass_dirt` entry declares its fill, all four world-facing edge profiles, and
paired top and underside endpoint/corner caps. Its underside start/end roles
use the atlas bottom-right/bottom-left cells respectively. `StagedTerrain` is
the only terrain renderer: the old
`GroundSurface`, `GroundBandParallaxForeground`, `TemporaryFloorMask`, and
static-solid debug rectangle paths are deleted, and their obsolete snapshot
fields no longer cross the Core/Game boundary.

Parallax themes do not select or render ground materials. They remain visual
layer metadata only; terrain material selection belongs exclusively to the
published terrain snapshot and `TerrainMaterialRegistry`. The parallax
authoring schema is v2 and contains only theme identity/revision plus ordered
background or foreground layer definitions.

The dedicated parallax editor previews an authored layer `yOffset` against the
bottom of its game viewport: `0` means that layer's image bottom aligns with
the viewport bottom. Its shared numeric Y-offset control can temporarily
override every displayed layer with one absolute value, then commits that exact
value to every active-theme layer in one revisioned, undoable edit. It is not a
delta and does not use a chunk-bottom anchor, because parallax rendering is
viewport anchored rather than terrain anchored.

The shared pure-Dart `authoring-polygons-v1` contract hashes source before
placement expansion. A UTF-8 length-prefixed record contains the owner domain
(`chunk` or `prefab`), stable owner key and human ID, positive owner revision,
stable shape ID, authoring mode (`solid`, `oneWay`, or `none`), optional surface/material metadata, vertex
count, and every ordered half-pixel integer coordinate. Records sort by owner
domain, owner key, then shape ID; duplicate owner-local shape identities fail
closed. One chunk digest includes all direct shapes and every referenced prefab
owner that contributes collision exactly once. Placement multiplicity and
transforms are intentionally absent because `authoring-placement-v1` owns
those facts. An empty source set produces the standard SHA-256 empty digest.

Core compilation temporarily uses reserved local instance index zero. The
renderer accepts only a `PolygonTerrainValidatedBatch`. That type has a private
constructor owned by the seam validator, which returns no batch when compiled
chunk identities are missing, duplicate, case-colliding, assigned to the wrong
level, or physically incompatible at a reachable transition. The shared Core
`authoring-boundary-v1` primitive derives exact coverage, continuation, edge,
mode, surface, and material evidence; coverage/mode/surface mismatches block,
while material differences remain advisory. Seam blockers use
`TerrainAuthoringIssue`: identity/reference/level findings own each offending
Chunk, and a directed physical mismatch owns the entered/right Chunk while its
message retains the transition plus both exact boundary records. Missing or
wrong-level pairs emit one issue per owner and never an ownerless aggregate.
After that gate, the renderer
accepts only reserved local instance index zero and matching chunk keys, then
creates local source/edge IDs without an instance-index field. Runtime streaming must bind
the real instance index and geometry version in Phase 5. The checked-in output
golden contains no `chunkIndex` token, and a production-tree import audit proves
that normal Core construction, Flutter, and the replay validator cannot select
the staged records or output file. The live generator is the only production
importer of the renderer; this remains a one-way generation boundary, not a
runtime feature flag.

The shared checked-in fixture contains a concave direct solid, one-way source,
surface/material metadata, and an exactly scaled/reflected prefab placement.
Fresh generator parses bind exact `authoring-polygons-v1`, Core `source-v1`
and `edges-v1`, `authoring-placement-v1`, and `authoring-triangles-v1` hashes.
The editor's strict codecs and collision expansion consume the same bytes,
round-trip stable canonical Prefab-v3/Chunk-v2 JSON, and reproduce the
authored-source, Core source/edge, placement, and Core-owned triangle hashes.
Stale prefab key/ID/revision evidence fails before the editor can report an
authored source digest. The generated Dart fixture is executable typed data,
is reproduced byte-for-byte by fresh compiles through the normal artifact
drift plan, and remains identical when its compiled chunk input is reversed.
`UPDATE_POLYGON_TERRAIN_GOLDEN=1` is the explicit fixture-only update path;
ordinary tests are read-only. This proves the representative compiler and
render seam. Live generator wiring, tile-backed Prefab owner validation, source
cutover, and direct polygon runtime authority are delivered. The former exact
rectangle projection and its parity tests are deleted; scheduler output now
retains only Chunk identity/assembly, markers, and visual sprites.

A second checked-in fixture isolates transform extrema and terrain-topology
parity from the reviewed Dart artifact golden. Its canonical prefab source has
odd half-pixel ticks. One placement applies X-only reflection at the exact
minimum scale `0.3`; another applies Y-only reflection at the exact maximum
scale `3.0`. Generator tests freeze the exact physics vertices produced by the
single Core quantization step, while editor strict codecs reproduce the source
bytes exactly and the editor expansion reports the same placement lineage.
Direct terrain contains a flat-to-slope boundary, finite solid ground on both
sides of an open pit, and two shapes sharing the exact `x = 100`,
`y = 81..130` boundary. Core retains the slope edge and cancels that shared
internal solid edge. Both consumers agree on six polygons, 21 exposed edges,
14 triangles, and signatures `39e9349f…220` (source), `b561d136…6b7`
(edges), `cb55cc53…ecd` (authored polygons), `4f07473d…1c2` (placements),
and `41ee501d…f36` (triangles). The original staged artifact and its reviewed
SHA-256 remain byte-identical.

The migration-origin fixture begins one stage earlier. Its four Prefab-v3
shapes must equal `LegacyPrefabColliderUnion.plan` output for an isolated
odd-sized rectangle, the concave occupied union of two overlapping rectangles,
and two edge-disconnected components. Reversing each legacy collider list must
produce the same loops and preserve the canonical `collision_001` and
`collision_002` component IDs. The strict Prefab-v3 and Chunk-v2 codecs then
round-trip those source bytes exactly, and editor expansion plus staged
generator compilation agree on four polygons, 20 exposed edges, 12 triangles,
and signatures `8b70a09b…bd96` (source), `1e605569…a1c6` (edges),
`355242dd…b57c` (authored polygons), `edc8b921…780f` (placements), and
`fcdff387…0ec5` (triangles). This fixture does not depend on the now-cleared
repository colliders and does not authorize a migration write.

The immutable compiled product, rather than its callers, owns canonical
placement-lineage and triangle ordering and rejects duplicate derived
identities. Generator source paths are canonical workspace-relative identities:
backslashes normalize to `/`, while absolute paths, drive prefixes, empty or
dot segments, and ambiguous colon spellings fail closed. Consequently Windows
and POSIX spellings cannot alter Core source records, signatures, or sorting.

The pure-Dart `polygon-terrain-signature-probe-v1` reconstructs the complete
fixture from source bytes and emits the authored polygon, Core source/edge,
placement, triangle, reachable-seam, isolated-seam, and exact rendered-artifact
SHA-256 values. Tests compare the in-process result with two fresh standalone
Dart processes; the complete artifact bytes bind to
`434ae70aa2c2d89b81886589aa6a3734de864f41d1f5fc2d32cb643897f8ca84`.
Permutation tests reverse caller collections, Core tests assert signature
equality for every cyclic rotation and reversed winding after explicit
normalization, and mutation matrices cover every signed record field. The
editor migration command receives the same fresh-process treatment: two
standalone checks over one temporary workspace emit byte-identical canonical
reports and reproduce `authoring-migration-v1`
`561d49b28eba5f6a86e78c212798a7c40e483d71b9484f76b1b2ac82bf6a2597`.
These probes closed staged determinism before live output registration and
source migration were enabled through the guarded cutover.

The staged compilation failure contract is also explicit. Unknown references
and key/ID aliases that resolve to multiple prefabs produce stable placement
issues and no geometry, independent of prefab catalog order. Strict parsing
rejects placement scale outside `0.3-3.0` or off its `0.1` step. Both direct
Chunk and prefab-local source-range failures preserve source/shape/placement
lineage, while post-transform bounds checks enumerate every offending direct
or expanded vertex against the closed Chunk rectangle. Mixed bounds failures
sort by source path, placement, shape, element, then code and cannot coexist
with a compiled product. This generator matrix does not replace the editor and
migration diagnostic inventory.

The staged matrix also passes strict structural failures through their exact
source paths and freezes Core topology translation without fabricating partial
output. Covered topology includes repeated closing and consecutive duplicate
vertices (including their complete ordered related diagnostics), too-few
vertices, collinear middle vertices, minimum area/edge, noncanonical start and
winding, self-intersection, positive-area cross-shape overlap, and
post-transform minimum-edge collapse. Stable shape IDs are lowercase by
grammar; a case variant therefore fails parsing, while an exact duplicate
fails canonical list ordering.

One authored shape remains exactly one simple loop. The exact non-adjacent
segment predicate also rejects point self-touch and positive-length collinear
self-overlap. A bridged inner ring used to simulate a hole, or a zero-width
bridge used to join disconnected interiors, necessarily enters that same
blocking `self_intersection` path; it never reaches normalization,
triangulation, or partial preview geometry. Valid disconnected occupied regions
are authored as separate stable-ID shapes, as proven by the migration-origin
parity fixture. Generator and Chunk-editor adapter tests preserve the same
Chunk owner, shape, element, code, and related collinear findings.

Core now owns the portable `TerrainAuthoringIssue` boundary: explicit warning
or error severity, stable code/message, canonical source path, owner key, and
optional placement/shape/element lineage with deterministic immutable sorting.
Its `fromCore` adapter derives severity through the established blocking-code
predicate without replacing focused `TerrainDiagnostic` inside geometry.

The staged generator raw-source entry catches strict prefab and chunk
`FormatException`s independently, emits stable file-level codes, and uses the
canonical path as owner only when parsing failed before a repository owner
could be decoded. All later staged compilation findings use decoded Chunk or
Prefab ownership. The editor Chunk-v2 collision adapter constructs the same
strict envelope and then maps it into the broader plugin `ValidationIssue`,
which now preserves optional `ownerKey`; direct and placement-source findings
own the Chunk, while expanded-shape findings own the Prefab.

This is still not the universal user-facing boundary required for cutover.
Other editor validation domains and normal export/load entry points retain
their existing contracts and must be adapted without importing JSON,
filesystem, or editor types into Core.

## Exact Legacy Compatibility Projection

The temporary compatibility projector consumes only an accepted
`PolygonTerrainCompiledChunk`; it never parses source independently and cannot
invent output after a compiler diagnostic. Its authoritative output values are
integer world pixels plus an exact `BigInt` snapped-solid-union area.

For each accepted orthogonal polygon, coordinate compression classifies exact
interior cells and emits deterministic width-first, top-to-bottom,
left-to-right rectangles. The sum of their integer-physics-tick areas must
equal the source polygon area. Non-ground solid rectangles then reproduce the
legacy generator's 16-pixel ties-away-from-zero position/dimension snap. Their
occupied union is decomposed again into canonical non-overlapping rectangles
and rechecked against exact snapped union area; input and source ordering do not
affect the result.

Direct shapes named `ground_*` are the migration-owned compatibility marker.
They project only when each is one solid rectangle whose top equals the level's
legacy `groundTopY`, whose bottom equals chunk height, and whose horizontal
endpoints are whole pixels. Merged ground coverage is complemented to produce
stable `gap_1`, `gap_2`, ... records, and every gap endpoint/width must align to
the legacy grid. Ground bands do not also become finite solid rectangles
because the current runtime constructs the ground plane separately and cuts
these gaps from it.

The bridge rejects every diagonal edge before any bounding approximation,
requires each one-way owner to decompose to one rectangle, and rejects snapping
that creates one-way/one-way or one-way/solid positive-area overlap. Solid-only
snapped overlap is represented by its exact occupied union. This bridge does
not change the accepted compiler's earlier owner-overlap policy.

Against the current in-memory migration targets, all eight repository chunks
compile and project exactly. Each produces the stable full-width
`collision_cleared` gap with no solids or one-way tops, matching the checked-in
generated pattern. The former six-chunk/24-overlap blocker set was resolved by
the explicit content decision to delete the old collision and reauthor it, not
by weakening overlap validation or unioning independent owners. An exact
full-chunk gap is the sole legacy grid exception because the chunk width is
600 pixels; partial gaps remain grid-aligned.

This proves only that the intentional empty state is deterministic. Live
polygon generator registration and playable acceptance remain closed until
ground, slopes, platforms, obstacles, seams, actor support, enemy navigation,
and marker placement are reauthored and validated.

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

The duplicate UI does not use a fixed nudge: that would positively overlap most
source loops and make the action reject immediately. It derives X/Y candidate
translations from all current owner AABBs, snaps each candidate outward once to
the active authoring step, sorts the complete candidate set by stable distance
and direction rules, and selects the first conservatively non-overlapping
position. Current Chunk authoring additionally requires the translated bounds
to remain inside the closed owner rectangle. This search only chooses a useful default;
the shared reducer and exact Prefab/Chunk owner policy still validate the
actual translated polygon and allocate its lowest-free stable shape ID.

All stored and preview edit coordinates remain integer half-pixel ticks, but
normal Prefab and direct Chunk collision authoring admit only even ticks.
Prefab authoring hardcodes a whole-pixel step with exact ties away from zero.
Direct Chunk terrain hardcodes the same minimum and exposes no half-pixel
selector. Independent default-off route-local creation and saved-shape
tile-snap settings change their respective steps to the current owner's
positive `tileSize`. Creation owns
polygon/rectangle drafts and draft vertex insertion/movement; saved-shape
editing owns committed gestures, duplication spacing, and exact
vertex/rectangle commits. Both settings are locked during an active draft or
gesture so one operation cannot mix steps. Scene hit testing accepts fractional
source-space pointer coordinates produced by inverse viewport transforms, and
the shared snap policy divides those fractional values by the final grid step
before rounding once. This avoids selecting a different owner-grid cell by
prematurely rounding to the half-pixel grid. When a Chunk's right or bottom
bound is not tile-aligned, snapped pointer input clamps to the final complete
tile-grid intersection inside that bound rather than creating an off-grid
vertex at the raw owner edge.

Chunk terrain input adds a route-local contact constraint before the shared
reducer receives each pointer update. Its immutable target set contains current
direct source loops converted exactly to Core physics ticks and read-only
expanded prefab loops at their already-quantized transformed coordinates. An
eight-canvas-pixel radius is converted through the viewport so zoom does not
change the visual snap affordance. Point placement rejects strict interiors;
rectangle, vertex, insertion, and whole-shape candidates reject exact
positive-area overlap. Direct render-only loops participate in this authoring
constraint as occupied visual area, although they are later removed from
gameplay geometry. An invalid drag walks the authoring grid from the last
accepted preview to the requested point, stops at contact, and can continue on
an allowed axis along that boundary.

Only solid target boundaries participate in contact attraction. One-way and
render-only loops still reject occupied-area overlap, but are not weld targets
because they do not form removable solid seams. Direct boundaries that are representable on
the active source grid snap exactly. Move/insert vertex contact may refine an
optional tile-grid gesture to the mandatory whole-pixel direct-terrain lattice,
so a legal neighboring boundary between tile intersections remains reachable;
unconstrained movement continues to use the selected tile grid. A transformed
prefab boundary between whole-pixel source coordinates selects the nearest
deterministic authorable point that remains outside every collision loop. These
checks improve the preview; the normal Core canonicalization, owner bounds,
capacity, transformed overlap, and seam validation remain final commit
authority.

Exact opposing solid boundary segments are split and canceled by the Core
compiler, so two solids snapped into edge contact do not emit an internal
collision or navigation edge. Crossing edges and positive-area intersections
are never hidden as a repair strategy: authoring prevents those candidates and
the final owner validation rejects any alternate edit path that creates them.

`TerrainPolygonSceneProjection` exposes stable shape order, selected
edge/vertex indices, gesture-preview identity, and an open draft without
depending on Flutter. `TerrainPolygonSceneHitTest` uses vertex, edge, then fill
priority. It chooses the closest feature first and resolves equal distances by
selected shape, visually topmost canonical shape, local element index, then
shape ID. These are UI selection rules only; collision geometry remains Core-
owned.

Chunk authoring derives one material-preview shape list from that projection.
It substitutes committed-shape gesture candidates and appends a creation draft
once the draft has at least three vertices, while leaving the session document
unchanged. The material layer listens directly to authoring state so pointer
updates repaint without forcing unrelated Chunk workspace projections to
reconcile. Route-local creation settings select solid, one-way, or the
render-only `none` role, an optional key from the loaded authored material
catalog, and an optional custom
shape name before either a polygon or rectangle starts. Shape names are the
stable source IDs used by deterministic selection and compiled-edge lineage.
They must start with a lowercase letter, contain only lowercase letters,
numbers, and underscores, and be unique within the direct owner. Blank
creation input uses the reducer's deterministic `solid_###` allocation. Each
new draft captures those values, so changing future defaults cannot mutate an
active operation. The controls are disabled while that operation exists;
collision and material selections remain for consecutive shapes while the
custom name clears after a successful Save. New direct Chunk shapes initially
default to solid `ground` and the first canonical authored material key; a
missing material catalog fails visibly back to collision-only metadata instead
of inventing a key.

The Chunk sidebar renders creation and saved-shape management as sibling
sections. The creation section owns defaults, a collision dropdown, per-option
pre-draw material previews inside the material dropdown, polygon/rectangle
entry points, contextual operation status, and Save/Cancel. It is independently
collapsible without replacing or resetting the route-local authoring state;
Save remains unavailable until a draft contains the minimum three vertices.
The existing-shapes section owns the committed-shape count and list. Selecting
a list row expands that shape's metadata, lifecycle actions, and exact geometry
editor immediately below the row, so creation defaults cannot be mistaken for
selected-source metadata. Its material selector reuses the creation menu's
per-option preview action. Its editable name follows the same source-ID syntax
and owner-unique rules as creation. Rectangle dimensions or the selected exact
vertex render as one contextual editor below the vertex list and commit through
one bottom `Save edit` action. A simultaneous name and exact-geometry edit is
validated and committed as one owner replacement and one revision. Re-selecting
the active shape row closes a clean editor; pending name or geometry text opens
a Save/Discard/Cancel decision. Save uses that combined semantic commit,
Discard restores the accepted source values, and Cancel leaves the editor and
its local input untouched. This split changes presentation only; both sections
still use the same route-local controller and commit boundary.

`TerrainPolygonViewportTransform` maps exact source half-pixel ticks into
display-only canvas doubles. Its inverse deliberately returns fractional
source-space pointer coordinates; a semantic edit must still pass those values
through the reducer's integer snap policy. `TerrainPolygonScenePainter` renders
solid/one-way/render-only source fills and boundaries, vertices, selected
edges, gesture
previews, and open drafts from the shared projection. Projection, transform,
and style have structural equality so equivalent frames do not repaint.

This painter does not compile geometry and its fills are never collision or
navigation authority. Collision-edge/normal/lineage diagnostics must come from
the Core compiler preview adapter. Both current routes install the painter and
plugin/session wiring. The normal Prefab/Chunk source cutover is complete;
Core normal-vector drawing remains pending. Core-compiled edges are hidden by
default and may be shown independently of the clean Visual preview; the Chunk
workspace has no compiled-edge selection mode. Actor-terrain inspection is a
separate default-off Core evidence overlay.
The default-off Chunk tile grid is a route-local `EditorViewportGridPainter`
projection clipped to owner bounds. It remains visible across all four domain
tabs and is suppressed with every other editor overlay in Visual preview; it
does not affect snapping unless the applicable Terrain **Snap to grid** switch
is enabled. Separate settings are exposed in the terrain creation section and
selected-existing-shape editor, not by the global scene control strip; changing
one never changes the other.

The Phase 4 interaction acceptance harness is test-only and drives that real
Chunk authoring surface on Windows in Flutter profile mode. Its stable
`phase4-polygon-soft-budget-v1` fixture has a 600 x 270 active Chunk, 16 direct
shapes, one 24-vertex selected shape, 43 expanded Prefab shapes, 256 compiled
edges, and 12 compatible scheduler-reachable seams. Exact authored/source/edge/
seam signatures are frozen by a normal unit test before timing begins. Vertex
and whole-shape movement each receive 120 warmup and 600 measured pointer
frames. The JSON result contains repository identity, dirty state, runtime,
p50/p95/p99/max interaction and compact build/raster timings, missed-input and
engine-budget counts, affected geometry, and every gate result.

Pointer updates remain owner-local preview mutations: they do not dispatch a
plugin command, reload the repository, run generation, or replace the session
source document, complete Chunk list, or active Chunk. Flutter GC counts remain
diagnostic rather than being mislabeled as source-model allocations. The
accepted `0b9c95c3` profile records vertex p95/p99 `201/262 us`, whole-shape
`210/277 us`, build p99 `7.864/7.359 ms`, zero missed inputs, and zero missed
build/raster budgets. The ignored compact artifact is
`.tmp/slopes_phase4_polygon_interaction.json`; live authoring source and runtime
authority are not part of the benchmark.

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
- explicit Prefab staged-scene routing, owner-local draft isolation, fixed
  whole-pixel creation, route shortcuts, undo/redo, and diagnostic focus
- exact numeric vertex parsing, canonical formatting, range/fraction rejection,
  canonical-selection retention, and one-commit owner dispatch
- anchor-relative atlas and negative-cell platform-module visual projection
- deterministic shape IDs, exact snapping, explicit normalization, and
  positive-area duplicate rejection
- strict point-interior checks, zoom-stable solid contact snapping,
  transformed-prefab lattice fallback, no-tunneling gesture clamps, one-way
  non-attraction, and exact internal-solid seam cancellation
- shared render projection plus vertex/edge/fill hit-test priority and
  deterministic tie-breaks
- exact canvas/source transform, structural repaint, and widget-level source
  fill/selection/preview/draft painter tests
- a deterministic Windows profile fixture and real pointer trace for vertex and
  whole-shape p50/p95/p99/max, compact Flutter build/raster timing, missed-input
  detection, complete-overlay counts, and unchanged workspace source identity
- immutable prefab-v3 snapshots, value equality/copy/revision behavior,
  preserved authored ordering, and target-boundary canonicalization tests
- strict prefab-v3 file parsing, copy-only canonical serialization, duplicate
  identity rejection, invalid-model refusal, and delegated migration round trips
- normal all-v2 chunk-tree loading, immutable prefab/tile composition,
  active-level scene projection, direct Core geometry/bounds/reference
  validation, canonical pending diffs, transactional apply, and exact reload
- chunk commit freshness, canonical owner order, exact bounds, Core overlap,
  no-op/rejection identity, exactly-once revision, typed plugin dispatch, and
  current-source apply tests
- typed Chunk-v2 metadata freshness, strict enum/level/group/tag acceptance,
  protected composition/geometry fields, exactly-once revision, no-op identity,
  canonical pending projection, and transactional source apply
- typed Chunk-v2 composition freshness and canonical structure, exact prefab
  reference/expansion and enemy-marker validation, complete candidate-document
  blocking, mutually protected metadata/geometry, exactly-once revision,
  pending projection, and no-op/rejection identity
- Chunk-v2 ownership planning for canonical creation, managed-path
  moves, baseline deletion, portable old/new diffs, missing ownership,
  workspace escape, case-insensitive collision, and deleted-path reuse
- Chunk-v2 lifecycle snapshot freshness across owners/revisions/source/levels,
  deprecated blank create, active exact duplicate, stable-key/revisioned rename,
  loaded deletion, unsaved cancellation, canonical created-owner path refresh,
  full candidate validation, typed dispatch, and rejection/no-op identity
- Chunk current-scene routing without a legacy reload, active-level owner
  isolation, guarded reload/apply, visible snap/tools, one direct-owner edit,
  route-level undo restoration, and fail-closed legacy route tests
- shared Prefab/Chunk exact-coordinate fields, malformed-fraction and odd-tick
  rejection in both domains, retained out-of-bounds text/diagnostics, and no
  history or pending diff for either rejection class
- shared collision metadata dialog lifecycle, trimmed optional fields, one-way
  mode commit, exactly-once revision/pending projection, and undo restoration
- deterministic duplicate placement across owner-order permutations, outward
  owner-grid snap, occupied/no-space cases, Chunk bounds, stable shape ID,
  exactly-once revision, and undo restoration
- exact anchor-relative prefab expansion with reflection/rational scale/
  translation, stable placement/prefab/shape lineage, combined direct/placed
  overlap, post-quantization chunk bounds, ambiguous/missing reference and
  scale rejection, Core prefab-shape capacity, and input-order signature parity
- whole-pixel Prefab surface-scale filtering, exact direct-terrain shared-edge
  contact, point/penetration/blocker rejection, moved-source exclusion, local
  gesture preview/commit, and retained incompatible edit values
- a read-only quantized Chunk overlay with locked lineage rows, separate
  direct/expanded shape and exposed-edge capacity counts, and unchanged direct
  polygon interaction/history behavior
- Core-exposed edge rendering, nearest finite-segment selection, canonical
  corner ties, exact fixed-point coordinate/angle text, traversal-cache slope,
  identity/lineage/mode/material/join/adjacency/diagnostic inspection, selected
  highlighting, and inspection-mode isolation from direct source edits
- Core-owned Éloïse/Grojib/Hashash surface eligibility, shared-identity
  Grojib/Hashash graph views, Unoco solid/local-hover classification, Derf
  solid/15-degree/32-pixel perch evidence, input-permutation signatures, and an
  opt-in route overlay/inspector that creates no revision or pending diff
- authored-order marker projection with stable keys/chance/salt, exact
  ground/highest/obstacle support intent, Grojib/Unoco/Derf Core placement,
  Derf support-width rejection, Hashash deferral, disabled/malformed outcomes,
  level-ground validation, zero RNG draws, and no revision or pending diff
- canonical compiled boundary coverage/continuation signatures, explicit open
  seams, mode/surface blocking, advisory material evidence, tier fallback and
  boundary enumeration, assembly within/between runs, distinct pools,
  Core-scheduler containment, global staged gating, stable adjacency digest,
  bounded pathological schedules, and read-only neighbor diagnostics
- prefab owner commit freshness, canonical order, visual-bound resolution,
  warning/error handling, no-op identity, and exactly-once revision tests
- full Core geometry/signature goldens and fresh-process signature tests
- full editor regression tests

The latest command counts and revisions are recorded in the Phase 4 validation
ledger rather than duplicated here.
