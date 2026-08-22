# Unified Chunk Scene Strategy

Date: August 14, 2026
Updated: August 22, 2026
Status: Implemented; manual UX/accessibility acceptance remains

Related documents:

- [Chunk Creator high-level plan](plan.md)
- [Unified Chunk Scene implementation checklist](unified-chunk-scene-implementation-checklist.md)
- [Editor UI system](../../../tdd/editor_ui_system.md)
- [Polygon terrain authoring foundation](../../../tdd/polygon_terrain_authoring_foundation.md)

## Decision Summary

Keep Chunk-v2 in one persistent chunk-authoring workspace, with chunk ownership
separate from terrain and composition inspection:

```text
+---------------+-- Terrain | Prefabs | Markers | Layers ---------------+----------------------+
| Chunk owners  |              Chunk creation scene                    | Active sections      |
|               |  One persistent viewport for terrain, prefab         |                      |
|               |  visuals, markers, and previews                      | One of Terrain,      |
|               |                                                       | Prefabs, Markers,    |
|               |  The active tab determines primary-pointer behavior | or Layers            |
+---------------+-------------------------------------------------------+----------------------+
```

On a wide window, the scene is the primary surface between a scrollable owner
rail on its left and a tab-filtered authoring sidebar on its right. Persistent
visual/viewport controls sit above the Terrain, Prefabs, Markers, and Layers
tabs. The tabs mount only their matching flat group of right-side sections and
never replace the
scene. On a narrow
window, the owner rail and authoring sidebar sit beside each other below a
bounded scene. The scene remains mounted across tab and expansion changes.
Viewport state and per-domain selection are retained, while active source
operations lock tab changes. Tentative inline Prefab placement editing is not
an active source operation.

This is a workflow redesign, not a label-only or layout-only change. The
existing scene already previews most chunk visuals, but its input path authors
only direct terrain polygons. The target scene coordinates terrain, prefab
placement, marker placement, and the existing layer metadata workflow without
creating a second persistence authority in the page. Spatial tile painting is a
separate future contract, not hidden scope in this migration.

The work has two independently gated delivery milestones:

1. **Workspace consolidation** (Phases 0-1) delivers the requested persistent
   scene, owner rail, and authoring cards without changing source schema or
   runtime output. It is independently shippable.
2. **Direct scene authoring** (Phases 2-5) adds operation-scoped identity,
   typed selection, prefab manipulation, and marker manipulation without
   changing Chunk source schema or runtime lineage. These phases may follow
   after the layout lands.

Tile-layer content and painting are explicitly outside both milestones. They
require a separate strategy once a concrete source contract and runtime/render
consumer exist.

## Why This Change Is Needed

The current route presents one chunk through two disconnected workspaces:

- `ChunkPolygonWorkspace` owns the header, selected chunk, terrain viewport,
  terrain tools, shape selection, seam evidence, diagnostics, and viewport
  state.
- `ChunkV2CompositionWorkspace` replaces that entire view with a visual-stack
  summary and three form-based panels for layers, prefab placements, and enemy
  markers.
- `_ChunkV2WorkspaceView` and two `ChoiceChip`s make the author switch context
  even though both workspaces edit the same `ChunkV2FileData` owner.
- the composition panels use dialogs and full-list composition snapshots while
  the terrain scene has route-local gesture drafts and a specialized polygon
  controller.

The split hides the most important spatial context while placements are being
edited. It also makes the composition page look like a peer of the scene even
though the scene already renders:

- level parallax and terrain-material previews
- placed prefab visuals partitioned around the ground visual z-index
- expanded prefab collision
- direct terrain polygon previews
- Core-compiled edges
- optional Core-backed actor-terrain eligibility
- optional resolved marker-placement evidence

The viewport is therefore already the natural shared chunk preview. What is
missing is a coordinated selection and interaction model for the non-terrain
content.

## Goals

- Keep the selected chunk visible while managing owners, collision, layers,
  prefabs, and markers.
- Make the scene the spatial source of context for all chunk-authoring tasks.
- Keep repository load, validation, pending-diff, and export authority in the
  existing Chunk plugin/store/session path.
- Preserve deterministic ordering, strict schema handling, atomic source
  application, source-drift checks, and fail-closed migration behavior.
- Preserve shared scene controls: `Ctrl+drag` pans, `Ctrl+scroll` zooms, and
  primary input follows the active tool.
- Make one accepted direct-manipulation gesture produce at most one semantic
  document command, one revision increment, and one undo-history entry.
- Keep view-only overlays and evidence inspection free of source mutations.
- Allow the workspace to grow to additional marker families without turning
  the editor into a generic map editor.

## Non-goals

- Do not move gameplay authority out of `runner_core`.
- Do not create a page-local import, save, or export path.
- Do not add per-placement collider overrides; prefab collision remains owned
  by the Prefab source and is expanded read-only in the Chunk scene.
- Do not introduce arbitrary rotation or unconstrained freeform transforms.
- Do not add tile-cell content or tile painting; `TileLayerDef` remains
  metadata-only in this initiative.
- Do not build a generic scene framework for hypothetical authoring domains.
- Do not combine this UI migration with unrelated runtime terrain or level
  assembly changes.

## Current Contract Constraints

### Terrain shapes already have stable identity

Direct terrain polygons use stable shape IDs and an existing route-local draft
controller. Their pointer workflow can remain authoritative while the outer
workspace is reorganized.

### Prefab and marker editing uses operation-scoped identity

`PlacedPrefabDef` and `PlacedMarkerDef` have no immutable instance key. Their
current UI selection keys are derived from content including coordinates and a
same-location ordinal. Moving an instance therefore changes its derived key,
and colocated records with the same prefab/marker key base are distinguished by
their position in canonical ordering.

Those derived keys must not be treated as persistent identity across document
versions. They are sufficient for list rows and the current semantic model.
Completely identical records are not a valid ambiguity: the strict source codec
and composition policy reject comparator-equal duplicates.

The strategy deliberately keeps Chunk-v2 unchanged. A prefab or marker gesture
captures an operation token containing:

- the complete `ChunkV2CompositionSnapshot` used as `before`
- the selected owner's `chunkKey` and expected revision
- the operation kind and target list
- for edit, move, or delete, the canonical source index of the existing record
- the current derived selection key for presentation only when an existing
  record is targeted

Pointer-up appends, replaces, or removes against the captured list as required,
canonicalizes the changed list, and submits the existing
`ChunkV2CompositionCommit`. The command is extended with expected owner key and
revision, and the policy requires the identity, revision, and composition
`before` snapshot to match. A misrouted payload cannot edit another owner with
coincidentally equal composition, and an intervening terrain, metadata,
lifecycle, or composition commit fails stale even when the three composition
lists did not change. Canonical index still matters for colocated records that
share a selection-key base but differ in z-index, transform, chance, salt,
placement mode, or another canonical field.

After an accepted add, move, or edit, selection is recomputed from the accepted
canonical list by full record equality. The accepted strict list must contain
exactly one match; otherwise the defensive result is no selection. An accepted
delete clears the deleted source selection.
After undo, redo, reload, or another document replacement, selection may be
retained only when the prior derived key still resolves exactly; there is no
fuzzy rematch, and otherwise it is cleared.

This avoids a source migration and, critically, preserves the existing derived
Core `placementKey` used by terrain lineage, edge IDs, generated signatures, and
parity fixtures. A future feature that introduces per-instance references or
requires selection continuity independent of record values must propose stable
authored identity in a separate schema plan.

The operation-token contract covers:

- exact target capture from the current canonical list
- stale rejection after any intervening composition change
- stale rejection after any intervening owner revision
- selection recomputation after an accepted coordinate change
- defensive selection clearing unless an accepted candidate has exactly one
  full-equality match
- exact-key selection reconciliation after undo, redo, or same-owner reload,
  and unconditional selection clearing on owner switch
- deterministic handling of overlapping and same-location records, plus
  fail-closed rejection of comparator-equal duplicates
- keyboard delete and inspector edits against a fresh current snapshot

### Placement coordinates need one explicit interaction policy

Prefab and marker coordinates are stored as integer source pixels. Prefab
`snapToGrid` is persisted and participates in canonical ordering, but the live
Chunk-v2 form currently does not apply one shared snapping function when a
coordinate is edited. Direct manipulation must not invent a scene-only
interpretation.

This initiative freezes one pure coordinate-policy module for both the scene
and the prefab inspector:

- a prefab with `snapToGrid: true` snaps its authored anchor to the selected
  chunk's positive `tileSize` grid
- a prefab with `snapToGrid: false` resolves to the nearest integer source
  pixel
- marker anchors resolve to the nearest integer source pixel because markers
  have no grid-snap field
- exact half-way values round away from zero, matching the repository's
  existing deterministic terrain snap convention
- exact inspector fields remain an explicit integer-pixel override and are
  never silently rounded; `snapToGrid` governs direct prefab gestures, not
  strict source validity
- the complete candidate still passes existing Chunk plugin validation; the
  scene does not create a weaker or competing bounds rule

The implemented follow-up adds a default-on, route-local **Surface snap** pass
after this coordinate policy. It keeps X on the selected tile/pixel grid and
may refine only Y to another whole-pixel origin when the Prefab's transformed
lowest horizontal collision edge can share an exact interval with an exposed
upward-facing direct-terrain edge within eight screen pixels. Compatible Scale
choices are derived from Core's reflected exact-tenth transform: the support Y
must land on a whole pixel after the authoritative `1/1024 px` quantization.
The candidate must remain in bounds and pass the exact positive-area predicate
against direct terrain and every other placement. Edge contact stays legal;
penetration does not. Existing incompatible saved scales are retained and
explained, and unsupported/no-collision Prefabs keep unrestricted visual scale.
No authored schema, runtime geometry contract, or final compiler rule changes.

Phase 0 still scans current authored sources and fixtures so the baseline is
known. The planning audit found no `snapToGrid: true` prefab mismatch in
checked-in JSON under `assets/`, `test/`, or `tools/editor/test/`. A later
mismatch is reported as characterization evidence but is not normalized during
decode/load and does not silently turn an interaction preference into a new
source/generator invariant. The layout milestone preserves current data
unchanged.

### Tile layers are metadata, not painted content

The current `TileLayerDef` stores only:

- `id`
- `kind`
- `visible`

There is no authored tile-cell or placed-tile collection to render, hit-test,
paint, erase, or reorder spatially. The unified workspace moves the existing
layer metadata forms into the right sidebar and labels them accurately. A real
layer-painting workflow requires a separate building plan covering source
representation, stable tile identity, coordinates, z-order, validation,
generator/runtime consumption, and migration.

## Target Information Architecture

### Global header

The route header remains global. Its visible badge changes from
`Chunk v2 polygon authoring` to `Chunk v2 authoring`, while the scene panel uses
the requested `Chunk creation scene` title. The header continues to own:

- current level selection
- current chunk-owner selection
- source apply
- undo and redo
- pending-change summary
- source-generation and migration status

Owner switching, reload, apply, and route switching remain blocked while any
domain has an active gesture or guarded route-local draft. The expanded Prefab
placement form is deliberately non-blocking and discards its un-applied values
when its domain, owner, or source revision changes.

Because the scene and active sections share one operation boundary, the guard is
route-wide: while one domain has an active operation, tab changes and mutating
actions in every other domain are disabled. Read-only evidence toggles and
viewport controls remain available. While a local operation exists, session
undo and redo are blocked:
undo invokes that domain's defined local undo/cancel behavior, and redo is
available only when that domain has a local redo. Only when no local operation
exists may either action delegate to session history.

The header owner selector remains the fast switcher. The owner list in the left
rail remains the lifecycle surface for create, duplicate, rename, and delete.
Both project one `_selectedChunkKey`; neither keeps independent owner selection.

Deleting the selected owner preserves the current lifecycle behavior: bind the
first remaining owner in canonical order and reset owner-scoped scene state. If
no owner remains, clear the selection, dispose owner-scoped controllers, and
show the existing empty state; creation remains unavailable until undo restores
a dimension template.

### Chunk creation scene

The center panel becomes `Chunk creation scene`. It owns only viewport
presentation and route-local interaction dispatch; it does not own repository
serialization.

Global scene controls remain visible regardless of the active domain:

- zoom and reset
- pan behavior
- a default-off owner tile-grid overlay, clipped to Chunk bounds
- view-only overlay visibility

Domain tools are contextual:

- terrain shape selection and polygon tools
- independent tile-snap switches inside terrain creation and selected-shape
  editing
- prefab selection, placement, and movement tools
- marker selection, placement, and movement tools

The active domain must be explicit. The scene must not guess between an
overlapping prefab, marker, compiled edge, and terrain shape on every click.
Terrain is the initial source-editing domain for a newly bound owner. Choosing a
prefab/marker tool or selecting a prefab/marker source row changes the domain;
clicking an element refines selection only inside that domain. Expanding or
collapsing a card/section is presentation-only and never changes domain,
selection, history, or pending changes. Tile-layer metadata never owns canvas
input. Compiled-edge inspection remains an explicit read-only inspection mode,
not a source-editing domain.

### `Chunk owners` rail

The left rail contains the existing compact, collapsible owner workflow:

- chunk owner list and lifecycle actions
- selected-owner metadata and status
- fit-to-chunk visual thumbnails using the normal scene render projections

### `Terrain` card

The right-side terrain card contains the direct-collision workflow:

- terrain tool selection and direct-shape actions
- exact rectangle dimensions for axis-aligned four-vertex shapes
- selected shape details, inline metadata selectors, and a read-only material
  preview dialog

The scene keeps tool guidance only; collision-count, seam-count, source-fill,
and marker-count summary rows do not compete with the canvas. A shared,
document-wide Diagnostics section appears below the active Terrain, Prefabs,
Markers, or Layers sections and does not filter findings by the selected tab.

Neither rail may become a second long vertical page. Each is independently
scrollable; sidebar-internal groups use natural-height `EditorSectionCard` or
equivalent expansion sections with stable keys rather than nested expanded
panel cards. Every owner, domain, visual-stack, and Diagnostics section starts
collapsed. Expansion remains local presentation state.

### `Prefabs`, `Markers`, and `Layers` sections

The composition workflow is partitioned into three tab-specific section groups:

- Layers: visual-stack summary plus tile-layer metadata list and actions
- Prefabs: prefab placement list, catalog/add action, selection, and inspector
  actions
- Markers: enemy marker list, add action, selection, and inspector actions

Initially, add/edit operations may retain their existing dialogs. Later phases
may promote coordinates and common transforms into an inline inspector once the
typed selection and gesture model exists. Both list selection and scene
selection must converge on the same route-local selection state.

The section group and scene must also consume the same per-document selection
projection: canonical source index, derived presentation key, and source record
are computed once for each prefab or marker. Do not independently sort and
reconstruct equivalent selection rows in the sidebar and hit tester.

## Responsive Layout

Wide layout:

- the scene receives the majority of horizontal space
- the left owner rail and right authoring sidebar use bounded, usable widths
  rather than equal flex with the scene
- the owner rail and the terrain/composition sidebar each keep their own
  vertical scroll view so their state and semantics remain mounted
- the scene remains height-bounded and never scrolls with the sidebar

Narrow layout:

- do not replace the scene with mutually exclusive terrain/composition pages
- place the owner rail and authoring sidebar beside each other below a bounded
  scene in the workspace body
- use a height-bounded column with the two scroll areas receiving the remaining
  height
- keep the scene mounted while the tab-specific sidebar sections change
- preserve keyboard focus, selection, viewport, and draft state when inspector
  sections open or close

Exact breakpoints and sidebar width should follow measured widget behavior, not
be frozen in this strategy.

## State And Ownership Model

| Concern | Owner | Invariant |
| --- | --- | --- |
| Loaded document, validation, pending diff, export | `ChunkDomainPlugin`, store, and `EditorSessionController` | The page never writes repository files directly. |
| Active level and chunk owner | Route workspace/coordinator projected over the loaded scene | Switching cannot discard an active domain gesture. |
| Viewport zoom, pan, and overlay visibility | Route-local scene state | View changes never create document revisions. |
| Active canvas domain and typed scene selection | A focused Chunk-scene coordinator | At most one of terrain, prefab, or marker owns source-editing primary input. |
| Route-wide active-operation and undo/redo routing | Chunk-scene coordinator over focused domain controllers | Cross-domain mutations cannot interleave with a guarded draft or gesture; tentative inline Prefab values are discarded on context change instead. |
| Page-level local-draft/shortcut reporting | Route workspace projected through `EditorPageLocalDraftState` and shortcut handlers | Every source operation participates in reload guards and blocks session history until it commits or cancels. |
| Terrain polygon draft/gesture | Existing polygon authoring controller | Existing snap, validation, and exactly-once commit rules remain intact. |
| Prefab placement draft/gesture | Focused prefab-placement interaction state | Pointer movement is preview-only until one accepted commit. |
| Marker draft/gesture | Focused marker interaction state | Authored anchor and resolved placement evidence remain distinct. |
| Composition list mutation | Existing `ChunkV2CompositionCommit` through the Chunk plugin, extended with expected owner key and revision | Owner, revision, and composition stale checks, canonical ordering, and full candidate validation run before acceptance. |

The coordinator is a route seam, not a replacement document model. It should
route input and reconcile selections after accepted session commands. Terrain,
prefab, and marker logic may use focused controllers when their invariants
differ; do not force them into one generic gesture abstraction merely because
they share a canvas.

## Selection And Input Contract

The unified scene needs a typed selection, conceptually:

- terrain shape or vertex
- prefab placement
- marker instance
- compiled edge/evidence selection, which is read-only

Rules:

- one source-editing selection is active at a time
- read-only evidence selection must not silently replace source selection
- card expansion and tile-layer metadata actions do not change canvas domain
- card selection and scene selection update the same typed state
- selection survives a non-mutating rebuild and viewport change
- selection is reconciled after commit and retained across document replacement
  only when its current derived key still resolves; otherwise it is cleared
- an accepted add/move/edit selects the unique full-equality match in the
  accepted canonical list, clearing selection if uniqueness is violated; an
  accepted delete clears source selection
- `Escape` cancels the active domain operation before clearing selection
- `Delete` targets only the explicit source selection in the active domain
- `Enter` completes only a domain operation that defines an explicit draft
  completion contract
- domain shortcuts do not intercept text-entry or open-dialog keyboard events
- `Ctrl+drag` and `Ctrl+scroll` retain their shared pan/zoom meaning in every
  domain
- mutating sidebar actions outside the active operation's domain remain disabled
  until that operation commits or cancels

Hit-test ordering must be deterministic within a domain. The prefab projection
retains canonical source index, paints by the existing canonical comparator
(whose first key is visual z-index) and then source index, and hit-tests that
exact sequence in reverse so the topmost painted placement wins. Marker anchor
ties use reverse canonical source order from the existing projection. Derived
keys map the chosen record to presentation state; they do not define a second
stacking order. Terrain continues using the existing vertex/edge hit radii and
source-shape ordering.

## Render And Evidence Contract

The scene should use one projection of the current candidate chunk. It must not
render a stale composition snapshot beside a newer terrain draft.

Required distinctions:

- authored source visuals versus Core-compiled collision evidence
- direct terrain shapes versus read-only expanded prefab shapes
- authored marker anchors versus Core-resolved spawn placements
- persisted visibility fields versus editor-only overlay toggles

Marker authoring particularly depends on this distinction. The existing
`ChunkMarkerPlacementOverlayPainter` already renders an authored anchor, its
connection to the resolved body where available, and the result evidence. The
unified scene reuses that projection, painter, and derived selection key and adds
anchor hit testing; it does not create a second marker overlay. Marker anchors
are visible whenever the marker domain is active. The existing overlay is
extended so resolved body/support evidence can remain an independent view
toggle without hiding the selectable source anchors. A ground, highest-surface,
or obstacle-top marker stores an authored query position, so dragging always
changes the anchor rather than the resolved evidence point.

During a marker add or move preview, render the candidate authored anchor but
hide the targeted record's old connection and resolved body/support evidence.
Other markers may keep their accepted evidence. Recompute the targeted evidence
only after the composition commit is accepted, or from an explicitly
candidate-scoped projection if performance measurements justify live preview;
never connect a candidate anchor to evidence resolved from its old coordinate.

Prefab visual hit testing must reuse bounds extracted from
`ChunkPolygonVisualProjection`. Painter and hit tester cannot maintain separate
anchor/scale/flip rectangle math. The shared projection returns deterministic
world-space bounds and canonical source index, and both consumers transform
those bounds through the same viewport transform.

Visual-stack ordering remains deterministic. Any selection outline or draft
ghost is an editor overlay and must not affect saved z-order or runtime
collision.

## Command, History, And Validation Contract

- Pointer-down captures the current owner key and revision, a fresh composition
  snapshot, the operation kind, and any existing target's canonical source
  index and presentation selection key.
- Pointer-move updates route-local preview state only.
- Pointer-up builds one typed command against the captured before-state.
- The Chunk plugin validates the complete candidate through the existing
  authority before accepting it.
- Rejection restores the current document projection and reports an actionable
  diagnostic without adding history or changing revision.
- A semantic no-op ends the local gesture without revision, history, or pending
  changes; the adapter detects it before dispatch so it is not reported as a
  rejected command.
- Acceptance increments the owner revision exactly once, creates one pending
  diff, and adds one undo-history entry.
- Undo and redo restore content and typed selection coherently.
- Source apply continues to recheck the complete chunk source set and write it
  atomically.
- The route-wide active-operation guard prevents any second domain command from
  changing the composition snapshot during a local gesture; optimistic stale
  checking remains the final fail-closed defense.

Expanded Prefab edits, Marker dialogs, and direct manipulation all use the
existing full-list `ChunkV2CompositionCommit`, extended with expected owner key
and revision. Operation start captures both plus the complete composition
`before` snapshot; submission changes only the affected canonical list in
`after`. The policy must reject an owner or revision mismatch before checking
structure, then retain its composition stale check, strict structure checks,
full-document validation, and exactly-one revision behavior. All stale cases
retain the existing `chunk_v2_composition_commit_stale` diagnostic family so
the route has one actionable retry path. Extract a shared route adapter for
constructing this commit rather than adding prefab- or marker-specific document
commands. Do not create separate "fast" scene writes.

## Delivery Strategy

### Phase 0 — Contract freeze and characterization

- characterize current terrain and composition behavior with focused tests
- freeze target layout, narrow behavior, terminology, and input domains
- freeze the operation-token, selection-reconciliation, and stale-rejection
  rules above
- record tile-layer painting as a separate follow-on, not optional work inside
  this initiative
- record the final ownership and command model in the relevant TDD before
  direct manipulation begins

Gate: no implementation phase treats a derived selection key as persistent
source identity or depends on an undefined tile-content model.

### Phase 1 — Persistent scene and sidebar sections

- remove the two route-level view chips and `_ChunkV2WorkspaceView`
- rename the route root from the polygon-specific `ChunkPolygonWorkspace` to
  `ChunkAuthoringWorkspace`, updating its page key and tests in the same phase
- keep one scene mounted
- compose the existing owner controls into the left rail and collision and
  composition controls into the right sidebar sections
- extract the retained composition sections and remove the standalone
  `ChunkV2CompositionWorkspace` root rather than leaving a parallel page
- retain tile-layer and Marker edit dialogs and semantic commands; move Prefab
  creation and existing-placement editing inline without adding a second write
  path
- rename the visible panel to `Chunk creation scene`
- rename the route badge to `Chunk v2 authoring`
- label layers as metadata and expose no spatial tile controls
- preserve wide and narrow usability without reintroducing workspace tabs

Gate: every existing owner, collision, layer, prefab, marker, diagnostics,
history, and apply action remains reachable while the scene stays present.

### Phase 2 — Composition gesture adapter and operation identity

- extract one route adapter that captures `ChunkV2CompositionSnapshot` and
  constructs the existing full-list composition commit
- extend that commit with expected owner key/revision and reject either
  mismatch before candidate validation
- address an existing target by current canonical list index inside the
  captured snapshot; add operations have no target index
- recompute derived selection after acceptance and clear it when a later
  document version cannot resolve it safely
- prove stale, overlapping, same-location, exact-duplicate rejection, moved,
  deleted, undone, redone, and reloaded cases without changing source schema
- prove generator output and Core placement lineage are unchanged

Gate: direct composition gestures can target one current record safely,
composition and owner-identity/revision staleness fail closed, and no new
source/runtime identity contract exists.

### Phase 3 — Unified domain and selection coordination

- introduce explicit active-domain and typed-selection state
- make card and scene selections bidirectional
- generalize the scene input surface only as far as needed to route domain
  input while preserving shared pan/zoom behavior
- reuse the existing marker anchor/evidence overlay and add shared-projection
  prefab selection bounds
- keep non-terrain source manipulation disabled until its focused controller is
  ready

Gate: selection is deterministic through rebuild and viewport change, and is
recomputed or cleared after undo/redo, cleared on owner switch, and never causes
document mutations.

### Phase 4 — Direct prefab placement authoring

- select prefab placements from the scene
- create/place from the active prefab catalog flow
- drag an existing placement through the shared tile-size/integer-pixel
  coordinate policy and existing full-candidate validation
- keep scale, flip, z-index, and exact values available through an inspector
- refresh visual and expanded-collision projections from the same candidate
- commit each accepted gesture exactly once

Gate: scene and list edits have identical canonical output, validation, pending
diff, revision, and undo/redo behavior.

### Phase 5 — Direct marker authoring

- reuse the existing overlay's visually distinct authored anchors and resolved
  placement evidence
- select, add, and move marker anchors through the scene
- retain chance, salt, and placement-mode editing in a typed inspector/dialog
- refresh Core placement evidence after accepted changes
- keep unsupported or invalid resolutions visible as diagnostics

Gate: direct marker editing never confuses authored coordinates with resolved
spawn positions, remains deterministic, and clears invalidated selection after
undo/redo or reload rather than guessing identity.

### Phase 6 — Close the tile-layer boundary

- re-audit the metadata-only layer management delivered in Phase 1 after the
  direct-interaction phases
- verify the capability remains labeled as layer metadata rather than tile
  painting
- record the trigger for a separate tile-content plan: a concrete authored
  representation and identified runtime/render consumer
- expose no paint, erase, tile-selection, or spatial layer affordance

Gate: the unified scene makes no unsupported tile-authoring promise, and any
future tile-content work begins from its own reviewed strategy.

### Phase 7 — Hardening and cleanup

- complete the redundancy pass across cards, controllers, projections, and
  commands
- update editor help, README, TDD, and active roadmap status
- run the full editor suite, generator dry-run, and the existing polygon scene
  performance fixture
- archive these planning documents only when all accepted scope is complete or
  explicitly closed

Gate: no legacy workspace switch, duplicate write path, stale documentation, or
known interaction ambiguity remains.

## File-Level Work Map

Primary existing UI seams:

- `tools/editor/lib/src/app/pages/chunkCreator/v2/chunk_polygon_workspace.dart`
- `tools/editor/lib/src/app/pages/chunkCreator/v2/chunk_v2_composition_workspace.dart`
- `tools/editor/lib/src/app/pages/chunkCreator/v2/chunk_polygon_scene_surface.dart`
- `tools/editor/lib/src/app/pages/chunkCreator/v2/chunk_polygon_authoring_controller.dart`
- `tools/editor/lib/src/app/pages/chunkCreator/v2/chunk_polygon_visual_source.dart`
- `tools/editor/lib/src/app/pages/shared/editor_panel_card.dart`
- `tools/editor/lib/src/app/pages/shared/scene_input_utils.dart`

Target route naming after the one-pass UI migration:

- `ChunkAuthoringWorkspace` is the route root; no
  `ChunkPolygonWorkspace` compatibility alias remains
- `ChunkSceneSurface` is the multi-domain input surface; the terrain-only
  surface is removed after Phase 3 parity coverage passes
- terrain-specific controller, reducer, and painter names remain polygon-based
  where they still own only terrain behavior
- `chunk_polygon_visual_source.dart` and its full-scene visual types become
  `chunk_scene_visual_source.dart` / `ChunkScene*` when shared prefab bounds are
  extracted; painter and hit tester consume the same projection and no
  compatibility alias remains

Composition command seams:

- `tools/editor/lib/src/chunks/chunk_domain_models.dart`
- `tools/editor/lib/src/chunks/chunk_v2_file_data.dart`
- `tools/editor/lib/src/chunks/chunk_v2_composition_commit.dart`
- `tools/editor/lib/src/chunks/chunk_domain_plugin.dart`
- `tools/editor/lib/src/chunks/chunk_v2_validation.dart`

Expected unchanged by this initiative:

- `tools/editor/lib/src/chunks/chunk_v2_file_codec.dart`
- `assets/authoring/level/chunks/**/*.json` schema shape
- `tool/generate_chunk_runtime_data.dart`
- `packages/runner_core/lib/**`

Suggested new route-local seams should be named during implementation after the
Phase 0 ownership review. Do not create a generic framework merely to match
placeholder names in a plan.

## Test Strategy

Characterization and widget coverage:

- persistent scene presence while switching all four authoring tabs
- owner lifecycle, collision tools, composition dialogs, history, and apply
- wide and narrow layout behavior
- keyboard focus and shared scene-control parity
- card/list and scene selection synchronization

State and contract coverage:

- operation-scoped prefab and marker targeting across duplicates and movement
- local preview versus exactly-once accepted commit
- rejection without revision, history, or pending-diff changes
- undo/redo selection reconciliation
- deterministic hit-test tie-breaks
- authored marker anchor versus resolved placement evidence
- unchanged Chunk-v2 codec output, generated runtime output, placement lineage,
  and geometry signatures
- stale rejection for owner-key mismatch or after an intervening terrain or
  metadata revision even when the composition lists are unchanged

Performance coverage:

- retain the existing realistic polygon scene fixture
- add representative prefab and marker counts before direct interaction ships
- compare drag responsiveness and rebuild counts against the characterized
  baseline

## Risks And Mitigations

| Risk | Mitigation |
| --- | --- |
| A layout-only rename overpromises scene editing | Keep phase capabilities explicit and do not expose unsupported tools. |
| The already-large workspace becomes a monolith | Extract focused card sections and domain controllers while keeping one route coordinator. |
| Card and scene derive different ordinals for equal records | Compute canonical source index and presentation key once per document projection and share it across both consumers. |
| Overlapping content makes clicks ambiguous | Require an explicit active domain and deterministic within-domain hit testing. |
| A derived key changes when an item moves | Capture canonical index plus the full stale-checked snapshot, then recompute or clear selection after acceptance. |
| Gesture and exact-field coordinate semantics drift accidentally | Keep both branches in one pure policy module: deterministic gesture quantization plus an explicit integer-pixel inspector override. |
| Pointer movement floods history and revisions | Keep gesture previews local and commit once on release. |
| Marker drag edits resolved evidence instead of source | Render and label authored anchors separately from Core placement evidence. |
| Marker preview connects a new anchor to stale evidence | Suppress the targeted record's accepted connection/evidence until acceptance or recompute it from the same candidate. |
| Tile painting expands into a speculative map editor | Keep it out of this initiative and require a separate plan with a concrete consumer. |
| Narrow layouts recreate the same hidden-context problem | Keep the scene mounted and let tabs filter only the right sidebar. |
| Refactoring creates a second write path | Require every mutation to pass through typed Chunk plugin commands. |
| A command is routed to the wrong owner with equal composition | Bind expected owner key and revision inside the composition commit and check both before candidate validation. |

## Acceptance Criteria

- The Chunk route has one persistent `Chunk creation scene` and no mutually
  exclusive terrain/composition workspace selector.
- `Chunk owners` occupies the left rail on wide layouts; Terrain, Prefabs,
  Markers, and Layers tabs mount one matching flat group of right-side sections
  plus shared all-issues Diagnostics without replacing the scene on either wide
  or narrow layouts. No redundant domain wrapper card is present, and every
  sidebar section starts collapsed.
- Every owner row includes a read-only visual thumbnail, and the scene toolbar
  does not expose a redundant `Place vertex` chip.
- **Show grid** exposes the owner tile grid on every domain tab, while the
  **Snap to grid** switches inside terrain creation and existing-shape editing
  independently control and quantize their affected vertices to those
  intersections.
- Prefabs and Markers split foldable inline creation from existing records;
  submitting a new record does not open a modal dialog.
- All currently implemented owner, terrain, composition, evidence, validation,
  history, and source-apply behavior remains available.
- The scene has one explicit active authoring domain and deterministic typed
  selection.
- Prefab and marker direct manipulation uses an operation-scoped canonical index
  plus the existing stale-checked composition snapshot; derived selection is
  recomputed or cleared after document replacement.
- Every accepted scene gesture produces exactly one validated semantic commit;
  rejected gestures produce none.
- Marker source anchors and resolved placement evidence remain visibly and
  behaviorally distinct.
- Tile-layer UI remains metadata-only and exposes no spatial painting controls.
- Chunk-v2 source shape, Core placement lineage, generated signatures,
  plugin/store ownership, deterministic serialization, source-drift protection,
  and atomic apply remain intact.
- Focused and full editor validation, generator dry-run where applicable, and
  the representative scene performance fixture pass before closure.
