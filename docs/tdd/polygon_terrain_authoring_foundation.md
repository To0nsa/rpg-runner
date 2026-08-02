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
| Editor-to-Core conversion | editor `TerrainSourceCoreAdapter` | migration checks, shared interaction reducer, and explicit Prefab/Chunk staging routes |
| Shared polygon interaction state | editor `TerrainPolygonInteractionReducer` | pure-Dart selection/draft/gesture/semantic-edit tests plus explicit Prefab and Chunk staging routes |
| Exact half-pixel inspector text | editor `TerrainHalfPixelText` / `TerrainPolygonVertexEditor` / `TerrainPolygonInteractionReducer.editSelectedVertex` | one shared exact field widget and semantic commit path used by both explicit staging routes |
| Polygon collision metadata dialog | editor `TerrainPolygonMetadataDialog` / `TerrainPolygonInteractionReducer.editSelectedShapeMetadata` | one owner-neutral collision-mode/surface/material dialog used by both explicit staging routes; owner controllers retain commit authority |
| Polygon duplicate placement default | editor `findTerrainPolygonDuplicateOffset` | deterministic nearest conservative AABB-free, snap-aligned candidate on both explicit staging routes; exact owner validation remains final authority |
| Render projection and source-space hit testing | editor `TerrainPolygonSceneProjection` / `TerrainPolygonSceneHitTest` | framework-neutral scene tests and both explicit staging surfaces |
| Canvas projection and source-loop overlay | editor `TerrainPolygonViewportTransform` / `TerrainPolygonScenePainter` | shared Flutter painter tests and both explicit staging surfaces; Chunk staging layers Core edge, actor-terrain, and marker-placement diagnostics above it |
| Prefab polygon owner validation | editor `validatePrefabCollisionShapes` | Core compiler plus exact visual-bounds tests; normal `PrefabDef` integration is pending |
| Immutable prefab-v3 polygon record | editor `PrefabV3Def` | migration target and model-contract tests; normal store/UI integration is pending |
| Strict prefab-v3 file structure and canonical serialization | editor `PrefabV3FileData` / `PrefabV3FileCodec` | delegated migration checks and explicit read-only store staging; normal load/save cutover is pending |
| Retained tile-v2 structure and canonical serialization | editor `PrefabTileFileData` / `PrefabTileFileCodec` | current-source byte round-trip and explicit v3 staging load; normal load/save cutover is pending |
| Prefab visual-source bounds | editor `PrefabVisualBoundsResolver` | existing v2 validation plus explicit v3 staging load for atlas slices and platform modules |
| Prefab polygon commit and revision policy | editor `PrefabV3CollisionCommitPolicy` | shared reducer, defensive plugin command, and staged route-coordinator tests; normal page cutover is pending |
| Prefab-v3 plugin command staging | editor `PrefabV3StagingDocument` / `PrefabDomainPlugin` | explicit strict load, typed commit, immutable pending diff, validation, and hard export lock; normal loader/page cutover is pending |
| Prefab polygon route-local projection | editor `PrefabPolygonAuthoringController` / `PrefabPolygonSceneSurface` / `PrefabPolygonStagingWorkspace` | explicit staged-scene routing, owner isolation, visual sources, tools, snap, diagnostics, focus, keyboard, rejection, and history tests; normal v2 loads still select rectangles |
| Fail-closed authored JSON and retained-metadata parsing | editor neutral domain plus `StrictTerrainSourceCodec` | legacy migration plus normal prefab-v3 and chunk-v2 codecs |
| Legacy prefab occupied-area union and reviewed corrections | editor prefab migration domain | aggregate check plan; removal follows verified prefab v3 write |
| Legacy flat-ground/gap conversion | editor chunk migration domain | aggregate check plan; removal follows verified chunk v2 write |
| Strict legacy prefab-v1/v2 and chunk-v1 source parsing | editor migration-owned `LegacyPrefabDef` / chunk-v1 models | read-only aggregate planner input; compatibility stores and normal `PrefabDef` are bypassed |
| Cross-domain canonical migration report | editor migration domain | read-only CLI, strict in-memory targets, and exact source SHA-256 audit; source writes remain pending |
| Strict chunk-v2 file structure and canonical serialization | editor `ChunkV2FileData` / `ChunkV2FileCodec` | migration facade delegation, complete-repository round-trip, and explicit strict store staging; normal load/save cutover is pending |
| Chunk-v2 plugin staging, direct-owner validation, and commit policy | editor `ChunkV2StagingDocument` / `ChunkV2CollisionCommitPolicy` / `ChunkDomainPlugin` | strict future-source composition, Core direct-shape/bounds validation, freshness/order/revision enforcement, typed commits, immutable pending diffs, hard export lock, and read-only direct/placed collision expansion; remaining metadata commands and normal cutover are pending |
| Chunk polygon route-local projection | editor `ChunkPolygonAuthoringController` / `ChunkPolygonSceneSurface` / `ChunkPolygonStagingWorkspace` | explicit staged-scene routing, active-level owner isolation, tools, snap, bounds, diagnostics, keyboard, rejection, history, compiled-edge inspection, actor-terrain, and marker-placement overlays; normal v1 loads still select ground/gap authoring |
| Chunk actor terrain projection | editor `ChunkV2ActorTerrainProjection` | Core surface extraction; Éloïse/Grojib/Hashash eligibility; published Grojib/Hashash graphs; Unoco solid/local-hover evidence; Derf 15-degree/32-pixel perch evidence; no player/flight graph or source mutation |
| Chunk marker contract and placement projection | editor `chunk_v2_marker_contract.dart` / `ChunkV2MarkerPlacementProjection` | immutable level ground context, staged marker validation, exact Phase 3 enemy placement evidence, Hashash deferral, authored-order/stable-key retention, and zero RNG/source mutation |

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
canonical list/ID/tag ordering, exact integer fields, half-pixel coordinates,
known enums, and accepted placement-scale steps. Unknown and legacy fields
reject rather than default. Geometry/topology acceptance remains Core-owned and
is not duplicated in structural codecs.

All planned current repository output—99 prefab records and 8 chunk files—has
been encoded, decoded strictly, and re-encoded byte-for-byte in tests. The
normal layers now own both future source structures, but normal
`PrefabStore.loadFromRepo`/save, `ChunkStore`, UI, generator, source JSON, and
runtime authority still use their existing legacy paths. `PrefabStore`
additionally exposes an explicit strict staging load that normal route
selection cannot call accidentally. `ChunkStore.loadV2Staging` now provides the
same explicit separation for an all-v2 chunk tree; ordinary
`ChunkDomainPlugin.loadFromRepo` still constructs only the v1 document.

The staging load composes prefab v3 with the unchanged `tile_defs.json` v2
contract through `PrefabTileFileData` and `PrefabTileFileCodec`; it never sends
v3 source through rectangle-era `PrefabData` or its compatibility parser. The
tile codec strictly checks the retained field/type/version/order contract,
module identities, and unique cell positions, and byte-round-trips the current
repository tile source. It performs no filesystem writes.

`PrefabVisualBoundsResolver` is the single visual-rectangle rule used by both
existing v2 validation and v3 staging. Atlas owners use authored slice width and
height. Platform owners use an integer bounding rectangle over module cells,
their exact grid positions, and referenced slice dimensions; negative cells
are supported and missing references fail closed. The explicit plugin loader
also carries workspace-scoped atlas paths/sizes and both source baselines into
the staged document/scene. A clean staged export is a no-op and changed export
remains hard-locked.

## Chunk-v2 Staging Validation

The chunk staging plugin composes strict prefab-v3/tile-v2 data with every
strict chunk-v2 file, its workspace-relative path, and its load-time contents.
The temporary document and scene snapshot all collections, retain a
deterministic active-level projection, and never pass future records through
the ground-profile/gap compatibility model. Pending diffs compare canonical v2
encoding against immutable baselines. A clean export is a no-op; any changed
file fails with `chunk_v2_source_write_disabled` before filesystem mutation.
The staging type must replace the v1 document at cutover rather than remain as
a parallel source authority.

`validateChunkV2StagingDocument` requires stable unique chunk identities,
complete source baselines, a known active level, and known prefab references.
Each direct polygon vertex must remain inside the closed chunk rectangle in
exact half-pixel ticks. Core reviews every loop under the canonical source
policy and compiles each accepted direct-owner set for exact overlap and hard
limits. Placement expansion is intentionally not approximated here: exact
transform, post-quantization bounds, expanded-owner limits, and preview parity
remain blocking Phase 4 work before normal cutover.

`ChunkV2CollisionCommitPolicy` is the direct-owner boundary between one shared
interaction commit and staging history. It requires the commit's before-shapes
to match the current immutable chunk, requires stable canonical shape order,
and reuses `validateChunkV2CollisionShapes` for closed bounds and Core review.
Every rejected or no-op attempt returns the original chunk instance. An
accepted semantic change replaces only `collisionShapes` and increments that
chunk revision exactly once.

`ChunkDomainPlugin.commitChunkPolygonCommandKind` performs owner lookup and
accepts only the typed shared commit. It returns the original staging document
for missing, malformed, stale, invalid, and no-op input; a successful command
replaces only the addressed chunk, records its key, and produces one canonical
file diff against the load baseline. The changed-document export lock remains
the final filesystem defense. Route-local diagnostics and previews remain
outside the generic command result, matching the established Prefab staging
pattern.

`ChunkPolygonAuthoringController` projects exactly one chunk owner over the
shared reducer. Tool, selection, draft, gesture preview, snap policy, and
rejected diagnostics remain local. The controller verifies a semantic commit
through `ChunkV2CollisionCommitPolicy` before dispatching the typed plugin
command, and synchronizes only when the immutable session document identity
changes. An active preview receives first refusal on undo, so cancellation
cannot consume committed session history.

`ChunkPolygonSceneSurface` reuses the shared painter, projection, hit test, and
focused keyboard contract. Primary input is tool-driven; Escape cancels,
Delete acts on the current selection, Ctrl-Z/Ctrl-Shift-Z/Ctrl-Y delegate
history, Ctrl-drag pans, and Ctrl-scroll zooms without mutating source. The
owner bounds painter is display-only; closed-bound validation remains in the
chunk owner policy.

When an explicit `ChunkV2StagingScene` is already loaded, `ChunkCreatorPage`
selects `ChunkPolygonStagingWorkspace` and deliberately skips its normal v1
post-frame reload. The shell reload/apply path is disabled for that staging
type, and the workspace's source-apply action is visibly locked. Active-level
changes still use the plugin command and rebind to the first canonical owner in
the new scene. Owner changes dispose the old route-local controller, preventing
an unfinished preview from leaking across chunks. Ordinary plugin loads still
return `ChunkDocument`, so v1 ground/gap editing and export remain the only
normal source path until the coordinated cutover.

The Chunk shape inspector uses the same `TerrainPolygonVertexEditor` as Prefab
staging. Its integer/`.0`/`.5` parser never sends malformed fractions to the
controller. A valid coordinate override bypasses pointer snap, enters the
shared reducer, and then passes through chunk bounds/Core owner validation.
Rejected out-of-bounds text remains visible with its exact diagnostic and does
not change revision, pending diffs, or history; an accepted replacement creates
one owner revision/history entry.

Collision mode, optional `surfaceKind`, and optional render `materialKey` use
one shared owner-neutral dialog on both staging routes. Optional text is trimmed
and empty text becomes `null`; the dialog returns only a value object and never
mutates the document. Each route sends that value through its controller,
shared reducer, owner policy, and typed plugin command. The dialog state owns
its text controllers until the route-removal animation completes, avoiding an
early-disposal race after `showDialog` resolves.

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
The plugin handler reuses this policy defensively and returns the original
document for a stale, invalid, malformed, or no-op command. An accepted command
creates one immutable document replacement, advances the owner revision once,
and records the owner key for deterministic pending diffs. This keeps invalid
drags and empty commits out of session undo/redo.

Before the source cutover, that handler is exercised through the temporary
`PrefabV3StagingDocument`. The normal loader never constructs this document
while repository source is v2. A clean staging document exports as a no-op;
exporting a changed one fails with `prefab_v3_source_write_disabled` before any
filesystem mutation. The staging document replaces the v2 `PrefabDocument` at
cutover and must not survive as a parallel authority.

`PrefabPolygonAuthoringController` proves the route boundary against that
staging document. It keeps tool, selection, draft, gesture preview, and rejected
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
remains display state. The surface and controller require an explicitly staged
v3 session today; the normal Prefab Creator route still renders and writes its
v2 rectangle workflow until the single source cutover.

When such a staged scene is explicitly present, `PrefabCreatorPage` selects
`PrefabPolygonStagingWorkspace` without running the v2 reload/save coordinator.
Ordinary plugin loads still return `PrefabDocument`, so this type dispatch does
not expose a second normal source path. The staging workspace owns prefab
selection, tool/snap/viewport state, exact shape readout, metadata actions, and
diagnostic focus. Switching owners disposes the old route-local coordinator,
which discards any uncommitted preview instead of transferring it to another
prefab. Route-level shortcuts delegate back to that coordinator so an active
preview still receives first-refusal cancellation before session undo.

`PrefabPolygonVisualProjection` establishes one visual coordinate rule for the
staged route. Atlas slices start at `(-anchorXPx, -anchorYPx)`. Platform-module
cells first normalize against the complete module bounds, including negative
grid cells and actual slice dimensions, then apply the same anchor-relative
origin. `PrefabPolygonVisualSource` decodes images in a cache whose lifetime is
the current workspace widget state, resets that cache on workspace changes,
and draws deterministic fallback cells for unavailable files. It paints only
visual evidence, bounds, grid, and anchor beneath the shared collision painter;
it never derives or mutates collision authority.

The staging page shows `1 px` owner-grid and exact `0.5 px` snap choices. A
snap-policy change cancels any active preview locally, and the selected policy
performs the only pointer-to-source rounding. Shape rows sort by stable shape
ID. Diagnostics retain shape/edge/vertex identity where available and focus the
corresponding element without creating history. Geometry is painted outside
the visual-source outline rather than clipped to it. Decoration owners remain
selectable for inspection but disable collision creation and retain empty
collision source.

Numeric vertex fields use `TerrainHalfPixelText`, which converts signed
integer, `.0`, or `.5` pixel strings directly to integer source ticks without a
floating-point intermediate. Comma decimal input is normalized for editor
ergonomics; other fractions, malformed text, and values beyond Core's authored
coordinate range remain field-local errors. A parsed coordinate is an explicit
numeric override, so it does not pass through the pointer snap selector. The
shared reducer replaces the selected vertex, re-runs Core canonicalization and
cross-shape overlap checks, preserves the selected vertex by exact value after
canonical reordering, and emits at most one semantic commit. The prefab route
then applies the usual owner visual-bounds and revision policy before session
history. Rejected geometry leaves both the committed document and typed field
state unchanged while exposing actionable diagnostics.

The source-apply action is intentionally disabled in the staging chrome.
Accepted edits still create session pending changes for validation/undo tests,
but the plugin's changed-staging export lock remains the final defense against
filesystem mutation. The enabled v2 page and its save behavior are unchanged.

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

Every transformed vertex is checked against the chunk's closed bounds in Core
physics ticks. A bounds issue retains source path, placement key, local shape
ID, vertex index, and an exact terminating decimal coordinate. Accepted
compiled geometry is retained when bounds evidence exists so the offending
shape remains visible; incomplete source resolution or a compiler failure does
not publish a partial overlay.

`ChunkV2StagingScene` owns the immutable result per active-level chunk. The
Chunk staging workspace draws accepted expanded prefab loops directly from
Core's quantized vertices beneath the editable direct-shape painter. This
overlay is wrapped in `IgnorePointer`, exposes no hit-test/editing API, and lists
prefab revision, placement key/transform, and local shape lineage with a lock
indicator. Expanded issues cannot focus a same-named direct shape. The scene
also reports direct, expanded, total-shape, and exposed-edge counts against
Core's hard limits separately.

The optional compiled-edge layer renders `TerrainGeometry.edges` above the
source-loop painters. It therefore shows Core's actual exposed result after
collinear splitting, internal-solid cancellation, and one-way filtering; it
never reconstructs edges from polygon fill. A separate inspection mode routes
ordinary primary taps to a read-only nearest-segment query while preserving
Ctrl-drag pan and Ctrl-scroll zoom. Distance ties use canonical
`TerrainEdgeId` order, and disabling inspection clears only route-local edge
selection.

Selected edges are highlighted and resolved back through the immutable Core
geometry and `TerrainTraversalCache`. The inspector shows the canonical edge
ID, direct or prefab/placement/shape lineage, exact `1/1024 px` endpoints,
integer tangent and outward-normal components, exact `1/1024 degree` absolute
slope, collision mode, surface/material, endpoint joins, previous/next IDs, and
related diagnostics. `TerrainPhysicsText` formats both fixed-point scales as
terminating decimals with integer arithmetic; display never feeds authority.
Normal-vector drawing remains pending.

The opt-in actor-terrain layer builds one immutable
`ChunkV2ActorTerrainProjection` only for the active staged chunk. It constructs
Core's `TerrainRuntimeBundle` with the accepted default Phase 3 grounded-enemy
profiles, so Grojib and Hashash reuse the exact shared `TerrainSurfaceSet`,
eligibility arrays, and walk/jump/drop graph publications. Éloïse uses the
accepted 60-degree `TerrainTraversalProfile` against that same surface set but
has no graph: Core does not own a player pathfinding profile, and the editor
must not manufacture one.

Unoco's view marks every compiled solid edge as a blocker and every upward
solid navigation surface as a possible local-hover reference. It ignores
one-way terrain and constructs no flight graph. Derf's view applies the
catalog-owned solid/15-degree traversal rule and Core's public
`derfMinimumSupportSpanTicks` requirement independently. Each qualifying perch
draws an exact centered 32-pixel horizontal support bracket; the inspector
reports actual horizontal span, rule outcome, and final perch eligibility.

Grounded actor overlays draw only eligible Core surfaces. Grojib/Hashash graph
links connect the exact Core-published body-center takeoff and landing points
and retain walk/jump/drop type; the display line is not a reconstructed motion
trajectory. Selecting a compiled edge adds actor-specific eligibility,
outgoing-link counts, blocker/local-hover state, or perch evidence beneath the
same canonical lineage. Overlay selection, actor changes, and inspection are
route-local, consume no RNG, and cannot change a chunk revision, pending diff,
authored marker, source file, or runtime authority.

The opt-in marker layer reuses that exact actor projection and constructs a
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

Hashash markers are not resolved at authored X: an accepted runtime roll adds a
deferred count and later chooses the visible camera-right chunk edge. The
projection therefore records guaranteed or conditional deferral without a
placement query or RNG draw. Procedural collectible/restoration candidates
have no authored marker records and are not fabricated. Projectile terrain is
explicitly later-phase work and is not previewed.

The normal chunk-v1 route, prefab-v2 source, authored JSON, generator input,
and runtime collision authority remain unchanged. Generator parity, placement
editing, scheduler seams, and normal-schema cutover remain later Phase 4 gates.

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
position. Chunk staging additionally requires the translated bounds to remain
inside the closed owner rectangle. This search only chooses a useful default;
the shared reducer and exact Prefab/Chunk owner policy still validate the
actual translated polygon and allocate its lowest-free stable shape ID.

All stored and preview edit coordinates remain integer half-pixel ticks. The
half-pixel snap preserves each tick; owner-grid snap uses an integer pixel step
with exact ties away from zero. Scene hit testing accepts fractional
source-space pointer coordinates produced by inverse viewport transforms, and
the shared snap policy divides those fractional values by the final grid step
before rounding once. This avoids selecting a different owner-grid cell by
prematurely rounding to the half-pixel grid.

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
the Core compiler preview adapter. Both explicit staging routes install the
painter and plugin/session wiring. Normal Prefab/Chunk source cutover and Core
normal-vector drawing remain pending; Core-compiled edge selection,
placed-polygon lineage, and actor-terrain eligibility/navigation evidence are
already available in Chunk staging.

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
- explicit Prefab staged-scene routing, owner-local draft isolation, visible
  snap selection, exact half-pixel creation, route shortcuts, undo/redo, and
  diagnostic focus
- exact numeric vertex parsing, canonical formatting, range/fraction rejection,
  canonical-selection retention, and one-commit owner dispatch
- anchor-relative atlas and negative-cell platform-module visual projection
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
- explicit all-v2 chunk-tree loading, immutable future prefab/tile composition,
  active-level scene projection, direct Core geometry/bounds/reference
  validation, canonical pending diffs, and byte-preserving export locks
- chunk commit freshness, canonical owner order, exact bounds, Core overlap,
  no-op/rejection identity, exactly-once revision, typed plugin dispatch, and
  changed-source lock tests
- Chunk staged-scene routing without a legacy reload, active-level owner
  isolation, locked reload/apply, visible snap/tools, one direct-owner edit,
  route-level undo restoration, and unchanged normal v1 route regression tests
- shared Prefab/Chunk exact-coordinate fields, malformed-fraction rejection,
  accepted odd half-pixel chunk edits, retained out-of-bounds text/diagnostics,
  and no history or pending diff for either rejection class
- shared collision metadata dialog lifecycle, trimmed optional fields, one-way
  mode commit, exactly-once revision/pending projection, and undo restoration
- deterministic duplicate placement across owner-order permutations, outward
  owner-grid snap, occupied/no-space cases, Chunk bounds, stable shape ID,
  exactly-once revision, and undo restoration
- exact anchor-relative prefab expansion with reflection/rational scale/
  translation, stable placement/prefab/shape lineage, combined direct/placed
  overlap, post-quantization chunk bounds, ambiguous/missing reference and
  scale rejection, Core prefab-shape capacity, and input-order signature parity
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
- prefab owner commit freshness, canonical order, visual-bound resolution,
  warning/error handling, no-op identity, and exactly-once revision tests
- full Core geometry/signature goldens and fresh-process signature tests
- full editor regression tests

The latest command counts and revisions are recorded in the Phase 4 validation
ledger rather than duplicated here.
