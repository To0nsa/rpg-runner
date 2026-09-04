# Editor UI System

## Scope

The standalone Flutter editor uses shared presentation primitives under
`tools/editor/lib/src/app/pages/shared/` for workspace cards and spacing. These
widgets own presentation only: route state, validation, commands, history, and
repository writes remain with their existing page, controller, plugin, and
store owners.

## Shared primitives

- `EditorUiTokens` is the single source for workspace padding, panel padding,
  gaps, radii, and list-row spacing.
- `EditorPanelCard` owns the outlined card, title/description/trailing header,
  body padding, optional vertical scrolling, and optional collapse semantics.
- `EditorSectionCard` groups related inspector controls without creating a
  second top-level panel. It supports natural-height, presentation-only
  collapse and an optional trailing action while its containing sidebar owns
  scrolling.
- `EditorListCard` gives owner, catalog, and composition rows one optional
  selected-state, leading/preview, details, and trailing-action structure.
- `EditorWorkspaceCard` owns the outer outlined route surface and workspace
  padding without taking over route sizing or scroll state.
- `EditorOwnerDraftState<T>` is the neutral create/edit/rename draft-state
  contract shared by Prefab and Chunk. It owns no widgets, domain commands, or
  persistence; each route decides when to resolve a draft and how Save is
  dispatched.
- `showEditorPendingChangesDialog` is the single non-dismissible
  Save/Discard/Cancel presentation used by Prefab and Chunk owner and polygon
  guards. Callers provide stable keys and retain all resolution behavior.

## Shared action toolbar

`EditorHomePage` owns the single toolbar rendered above every top-level route:
page selector, Reload, Apply To Files, Undo, and Redo. Route pages do not
render duplicate copies of those actions. A trailing status area projects the
session's loading/exporting state, pending item/file counts, pending-summary
failure, and validation counts without introducing route-specific meaning.

The shell delegates Reload through `EditorPageReloadHandler`, Undo/Redo through
`EditorPageSessionShortcutHandler`, and Apply To Files through
`EditorPageApplyHandler`. This preserves route-local safeguards and result
handling—for example, active polygon-operation guards and Level-to-Parallax
handoff reconciliation—without coupling the shell to individual route ids.
Plugins and `EditorSessionController` remain the only repository write path.

`EditorPanelCard` has explicit natural, expanded, and scrollable body modes.
Expanded and scrollable modes require a bounded parent height. Collapsible
cards require natural-height bodies and delegate overflow to their containing
sidebar; this prevents nested vertical scroll views from competing for pointer
input. Bounded catalog grids may own their local item scroll inside a natural
section, but they do not become a second sidebar scroll owner. Expansion is
local presentation state and never changes authoring selection, source history,
validation, or pending diffs.

## Current adoption

The current-schema Chunk route uses a persistent `Chunk creation scene`, owner
rail, and right sidebar. Wide layouts place the rail and bounded sidebar around
the scene; narrow layouts keep all subtrees mounted while placing them below
the scene. A four-way `Terrain`, `Prefabs`, `Markers`, and `Layers` segmented
tab strip stays at the top of the scene. The sidebar is the sole vertical
scroll owner and mounts only the flat group of sibling `EditorSectionCard`s for
the active tab; no redundant domain-level `EditorPanelCard` wraps them. Terrain
contains the creation and existing-shape authoring sections, Prefabs contains
the visual catalog plus creation and existing-placement sections, Markers
contains the enemy catalog plus creation and retained-placement sections, and
Layers contains the visual stack plus tile-layer metadata. Owner, domain,
visual-stack, and
Diagnostics sections start collapsed; expansion is presentation-only and each
mounted section retains it locally. Seam evidence is not a separate sidebar
section. Tab changes preserve the scene subtree,
viewport, and per-domain selection; an active source gesture or retained dialog
disables tab changes.
The Prefabs section group starts with one persistent
`ChunkPrefabCatalogBrowser`. It uses immutable Prefab-v3 and tile/module
projections plus a browser-owned,
workspace-path-scoped image cache for thumbnail rendering, token search across
identity/kind/tags, and route-local kind/usage filters. Its
stable-key selection feeds the scene Place tool and inline placement form but
does not enter the plugin document, history, validation, or pending diff. The
selected retained placement, whether chosen from the list or scene, reveals a
sibling editor directly below its row and composes the same browser with
row-local selection and transform drafts. Unselected rows expose no Edit/Delete
icon cluster. The editor owns labeled Open and Delete actions; Delete dispatches
one immediately undoable revision-aware composition operation without a modal.
Apply uses the same captured operation. The expanded form is not itself a
route-wide operation: selecting the row again, Cancel, or a domain, owner, or
source-revision change discards its un-applied draft without changing the route
catalog choice or source. Genuine composition dialogs and scene gestures
continue to lock conflicting scene tools and route operations.

The Markers section group starts with `ChunkEnemyCatalogBrowser`. Its immutable
entries project `EnemyId`, `EnemyCatalog` render-animation metadata, and the
catalog-owned `EnemyTerrainMotionKind`; editor labels and filters do not become
Chunk source. A shared idle-frame projection applies Core's source path, frame
width, height, row, start offset, optional wrapping columns, anchor, and uniform
render scale. Workspace-scoped decoded-image caches feed both the catalog
thumbnail and marker overlay without introducing editor-owned sprite tuning.
Search covers display name,
protocol-stable ID, and movement role, with role and current-Chunk usage
filters. The route-local selected ID feeds both `ChunkMarkerSceneGesture` Place
and the controlled `ChunkV2MarkerForm`. The expanded retained-marker editor
composes the same browser with row-local tentative selection. Selecting or
filtering an enemy creates no revision, history entry, validation event, or
pending diff.
Prefab and enemy browsers compose the neutral `EditorVisualCatalogLayout` and
`EditorVisualCatalogCard` primitives for identical search, filter, count, grid,
selection, keyboard, semantics, and card chrome; each browser retains only its
domain filtering, identity, and thumbnail projection. Selecting an existing
marker in the list or scene opens one row-local draft. Apply dispatches the
captured stale-checked replacement; Cancel, re-click, domain changes, and Delete
close the draft and clear marker selection. Delete follows the same immediate,
undoable composition commit used by Prefab and terrain inline editors. Tile
layers retain their dialog workflow.

With resolved marker evidence enabled, the marker painter first draws every
recognized outcome's decoded, in-bounds idle frame, then draws support,
connection, capsule, and authored-anchor evidence above it. Accepted art uses
Core's exact resolved body center at full opacity. Rejected art is muted at its
attempted body center. Deferred Hashash and other body-less outcomes use muted
art at the authored marker anchor as a reference, not as a claim that runtime
will spawn there; Hashash still chooses the visible camera-right Chunk edge
later.

Marker creation owns one shared enemy-aware placement default. Derf initializes
to `obstacleTop` in the inline form and direct scene Place because Core accepts
its kinematic perch only through that support intent; all other recognized and
unknown IDs initialize to `ground`. The form follows enemy-selection changes
only while its placement is untouched. Manual placement choices and retained
marker edits preserve their exact stored value.

Chunk terrain creation may reserve an optional designer-supplied shape name
before drawing; blank input delegates to deterministic ID allocation. Creation
also chooses `solid`, `oneWay`, or **No collision (visual only)**; the last role
remains visible in source/material preview but has no compiled-edge overlay.
Existing shape rows expose the stable source ID as an editable name. Exact
geometry fields retain their text inside the mounted editor, while a shared edit
controller reports pending state and routes save/discard requests from the
workspace. Re-selecting the active row closes it immediately when clean or
opens a non-dismissible Save/Discard/Cancel decision when its name or geometry
has changed. Save dispatches the pending identity and geometry as one semantic
owner edit; Discard clears both local drafts; Cancel preserves the open editor.
Pending inspector text prevents source apply until it is resolved.

Existing Prefab-v3 and Chunk-v2 owner metadata uses the same row-local draft
contract. Selecting an owner expands a reusable typed form directly beneath
that owner's `EditorListCard`; opening, closing, or editing the form is
presentation state until Apply dispatches the existing metadata command with
the captured stable key and before snapshot. A clean re-selection closes the
editor immediately. A dirty re-selection or owner/level change requests
Save/Discard/Cancel, while a rejected or stale command leaves the mounted form,
values, and diagnostic intact. Dirty owner forms participate in
`EditorPageLocalDraftState`, block source apply, consume undo before it can
reach session history, disable redo, and guard Prefab workspace-view changes.
An active Prefab polygon gesture also blocks
owner replacement, so route-controller disposal cannot discard authored work.
Owner creation mounts in an independently collapsed inline section and reuses
the typed Prefab field form or the shared human-ID lifecycle form. Rename,
Duplicate, and Delete are available only inside the expanded owner context and
capture that owner's stable key. Rename is deliberately separate from metadata
Apply: entering rename mode replaces the metadata form, dispatches one
lifecycle command, and preserves the stable key. Dirty create and rename forms
join the same local-draft guard. Destructive deletion remains a contextual but
reference-aware confirmation rather than becoming an unguarded icon action.

The Prefab Creator presents these records simply as **prefabs**. Separate
**Prefabs** and **Collision** views distinguish visual/identity authoring from
collision geometry authoring, while labels such as **Prefab library** and
**Create prefab** keep the internal owner/`ownerKey` vocabulary out of the
workflow. Owner terms remain implementation language for stable diagnostic and
mutation contracts.

Obstacle and decoration owner forms choose their atlas slice through an inline
visual catalog rather than a text dropdown. Token search covers slice identity,
source path, dimensions, tags, usage state, and referencing owner IDs. All,
Unused, and Used filters remain presentation-only. Atlas-source filtering uses
a compact file-explorer popover that groups repository paths by directory,
shows per-file slice counts, and preserves an explicit all-sources root. Every
card shows its exact region and whether existing Prefab owners reference it.
Usage is informative rather than exclusive because multiple owners may
intentionally share one authored visual source. Selecting a card remains part
of the local owner draft and recenters its anchor from the chosen slice bounds.

The Prefabs library and Collision selector compose the same neutral visual-
catalog controls and thumbnail renderer as Chunk prefab selection. Prefabs
shows all kinds and retains row-local owner editing; Collision is selection-only
and receives only Obstacle and Platform records because Decoration collision is
forbidden. One owner-neutral token filter searches ID, stable key, kind,
status, source type/reference, and tags, while each route retains its own
filters and usage labels. A browser-owned decoded-image cache projects both
atlas-slice and platform-module sources and degrades to a deterministic
missing-image preview. Search text, kind/status filters, and expansion are
presentation-only. Deterministic ID/key ordering and Enter selection return the
exact immutable owner record.

Prefab selection is synchronized exclusively by `prefabKey`: the Prefabs
visual card and preview, Collision visual card and scene context chip, polygon
controller, and inline owner editor cannot diverge.
The selected editor occupies the Prefabs card's detail slot, so lifecycle and
metadata actions remain visually attached to their target. Its contextual
**Set up collision** or **Edit collision** action carries the same selection
into Collision. An active polygon operation still routes attempted card or view
navigation through the workspace guard rather than replacing the controller.

Platform authoring is one user-facing workflow over two internal source
records. `tile_defs.json` retains the visual tile composition and
`prefab_defs.json` retains stable gameplay identity, anchor, collision, tags,
and placement compatibility. A bounded new or duplicated module receives a
paired Platform Prefab in the same stale-checked catalog command. The paired
Prefab uses `<moduleId>_platform` with deterministic collision suffixing,
inherits lifecycle status, and begins collisionless unless duplication has one
unambiguous source pair whose collision and metadata can be copied safely.
Status changes synchronize the unambiguous pair. Module rename always rewrites
visual-source references and also follows the conventional paired display ID
when that rename cannot collide; stable `prefabKey` identity never changes.
Modules with several custom Prefab variants remain valid and are not
destructively collapsed or arbitrarily synchronized.

The **Platforms** view reports whether each visual has collision configured and
opens its collision owner directly in **Collision**. The Collision sidebar
groups all remaining work under **Collision setup needed**: every unpaired
bounded module and every existing Obstacle or Platform Prefab with no collision shape.
Decoration Prefabs are excluded because their contract forbids collision.
Opening an unpaired module creates the missing status-matched Prefab and selects
it as one undoable two-file session edit; it then remains in the list as a
collider-free Prefab until a shape is saved. Existing Prefab rows select their
collision scene through the normal draft-safe navigation path. Empty visual
drafts remain unpaired because no anchor bounds exist yet. Deleting a platform
removes a sole paired Prefab in the same confirmed command, but stays blocked
for multiple variants or active Chunk placements. Source export remains the
existing atomic Prefab/tile transaction.

Prefab polygon, atlas-slice, and platform-module workspaces use the same panel,
section, list-row, and token primitives. Prefab-specific widgets remain only
where they encode domain semantics such as create/edit banners, scene controls,
or fixed three-panel labels; the former prefab-only card shells and spacing
registry have been removed.

Prefab collision authoring projects three sibling section contracts inside the
authoring sidebar: creation, retained shapes, and diagnostics. Creation state
owns optional identity, the Prefab-kind-derived collision mode, and the local
collision draft. It presents **Rectangle**, **Polygon**, **Fit visible bounds**,
**Trace visible outline**, and Platform-only **Detect platform surface** as
direct inline methods. Pointer input, exact fields, and generated
vertices share one fixed whole-pixel grid, so no precision selector is exposed.
Retained shapes use
`EditorListCard`'s detail slot for identity, fixed collision context, lifecycle
actions, and exact geometry; no Prefab collision-metadata modal remains. The mounted exact
editor and route-local shape-name draft report pending state through
`TerrainPolygonExactEditController`. Re-click, owner/view navigation, and
source apply must resolve Save/Discard/Cancel before the selection/controller
can change.

An axis-aligned four-corner loop uses `TerrainPolygonRectangleEditor` with
whole-pixel X/Bottom/Width/Height values. Other loops keep individual
whole-pixel vertex editing. Identity and one exact geometry change are passed
together to the shared polygon reducer, producing at most one owner-reviewed
collision commit, revision increment, and undo entry. Prefab collision does not
expose terrain `surfaceKind` or `materialKey`: new and regenerated shapes store
both as null, while obstacle/platform kind determines solid/one-way mode and
placed-Prefab lineage supplies navigation provenance. Legacy values remain
parseable and survive unrelated exact edits, but an explicit refit replaces the
target with canonical null metadata. Chunk terrain retains its independent
surface and material authoring controls.

Pixel-derived collision is a controller-owned draft set, not a persistence
path. The visual adapter crops an atlas slice or composites module cells with
the same layout consumed by the scene preview, using stable authored cell order
and integer source-over alpha. Decoded PNG bytes, RGBA data, and content digests
share the workspace image cache. A refresh re-reads bytes but reuses the decode
when the digest is unchanged; changed bytes replace and dispose the old image.
The normalized fitting mask is capped at 1,048,576 pixels before allocation.

Generation captures the Prefab revision, complete before-shape list, selected
refit target, method, settings, and visual-source digest. A monotonically
increasing token rejects late async results. Candidate geometry, component
inclusion, selection, exact edits, evidence, and fit-local undo/redo remain
outside the session until Save. Settings changes invalidate Save until an
explicit Regenerate; regeneration asks before discarding candidate edits.
Cancel restores the captured state without history. Save rechecks the visual
digest and dispatches the complete prospective list once, yielding at most one
Prefab revision and undo entry; a canonical no-op closes without either.

Fit visible bounds spans all retained alpha with one rectangle. Outline tracing
keeps disconnected four-connected components separate and reduces hole-free
concave contours to an explicit per-shape vertex budget. Reduction ranks each
removal by its maximum error against all original boundary points in the
replaced arc, preserves the original extents, winding, and simple topology, and
retains only original whole-pixel points. The default budget is 24 vertices and
the selectable maximum is Core's hard limit of 64. Components with holes still
use deterministic non-overlapping rectangle partitions so transparent holes
are not filled. Platform detection applies the same budget to the upper
accepted-pixel profile in each contiguous column run and closes the polygon
downward; the scene distinguishes the same left-to-right one-way support edges
exposed by Core. The inline evidence reports the resulting maximum source-pixel
deviation. Obstacle collision is always solid, Platform collision is always
one-way, and decoration Prefabs cannot author collision.

Every fit and every manual collision edit is reviewed against immutable Chunk
snapshots loaded with the Prefab document. Candidate Prefab data is substituted
into each referencing Chunk and passed through the shared content-pipeline
compiler, preserving scale, reflection, translation, bounds, overlap, and
capacity rules. Existing baseline errors are not attributed to the edit. Apply
to Files re-reads those Chunk sources and repeats review before the normal
atomic Prefab/tile write; drift blocks export with Reload guidance.

The Prefabs and Collision workspaces present flat sibling `EditorSectionCard`s
rather than placing section cards inside redundant panel cards. Prefabs uses a
creation sidebar, visual-only center preview, and owner-library sidebar.
Collision uses a missing-setup/selection sidebar, collision scene, and shape
authoring sidebar. Inactive owner creation, owner library, collision library,
shape creation, retained shapes, and Diagnostics sections start collapsed.
Controlled expansion is reserved for the section that owns an active owner
form, drawing operation, or selected shape editor; presentation-only expansion
remains in mounted section state and never enters session command/history.

Prefab Diagnostics consumes the session controller's complete validation
projection and merges only transient interaction findings from the active
polygon controller. It counts all three generic severities and retains issues
for non-selected owners. A focus action resolves `ownerKey`, falling back to a
stable owner suffix in `sourcePath`, then uses the guarded owner navigation
path before selecting and centering a retained shape. Unresolvable catalog
issues remain visible without a misleading focus action.

`PrefabEditorThreePanelLayout` owns the Prefab-specific responsive contract for
Prefabs, Collision, Atlas, and Platforms. The wide layout is `1:2:1`; the
narrow layout keeps the center preview or scene above two bounded sidebars.
Global-keyed panel hosts reparent the existing inspector, scene, and display
elements across the breakpoint, so responsive changes do not reset viewport or
route-local draft state. The generic three-panel component retains its tabbed
contract for non-Prefab callers.

Atlas and Platform views use that same mounted layout and flat sidebar
contract. Atlas Source, Slice Setup, and Selection are three separate collapsed
sections; all are controlled open while their shared slice draft is dirty. The
single Create/Update action sits below Selection instead of forming a fourth
section or sharing the selection card.
Atlas initialization selects the first available source image for visibility
but no slice. The read-only source field delegates to the platform-native PNG
picker, accepts only exact paths in the loaded repository atlas catalog, and
clears slice selection when the user chooses another source.
Shared auto-slice controls keep cell width and height visible while origin and
gutter values start collapsed under **Advanced grid settings**. Disclosure
state is presentation-only; hiding the fields preserves their session values.
For a new slice, the tag draft starts with the selected source image's immediate
parent-folder name and filename stem without its extension. Every slice save
merges both source tags with normalized user tags, so each remains present
exactly once even if the editable field omits or duplicates it. Selecting an
existing slice alone does not retrofit the tags or dirty the draft; the
invariant is applied when that slice is next saved.
The Slice ID draft for a new source begins with the normalized reusable atlas
collection plus `_`. Canonical paths resolve the collection immediately below
`assets/images/level/atlases/`; noncanonical retained paths fall back to their
immediate parent folder. Existing slice IDs and non-empty local drafts are never
rewritten by this suggestion. A Slice ID suffix action opens a read-only naming
convention dialog with the canonical pattern, examples, and identity rules; the
dialog never enters draft or session state.
Creation of a new Prefab Slice is rejected unless its ID uses lowercase ASCII
snake case, begins with the resolved collection prefix, includes an object
segment, and ends in `_01` through `_99`. The form reports the same rule inline
while the catalog commit policy enforces it independently. Tile Slice IDs and
updates to existing Prefab Slice IDs are exempt so retained content is not
silently migrated or stranded.
New Prefab Slice drafts expose an opt-in same-ID prefab creation control with a
mutually exclusive Decoration/Obstacle kind. The control is reset and disabled
for Tile Slices and cannot target an existing slice or case-insensitively
matching prefab ID. An accepted operation creates the slice and collisionless
revision-1 active prefab through one stale-checked catalog commit, derives the
prefab key through the existing collision-safe allocator, and centers its
integer-pixel anchor within the slice. The generated prefab copies the slice's
complete normalized tag set, including source-folder and filename tags.
Generated Obstacles become the selected owner in the Collision workspace so
geometry can be authored immediately; generated Decorations leave the Atlas
workflow active. Undo and redo always move the generated slice and prefab
together.
Atlas slice dirty state is derived from the current form values against the
loaded slice baseline. Mounting fields, synchronizing a retained slice, or
receiving a semantic no-op input callback therefore cannot block view or owner
navigation; restoring every edited value to the baseline clears the draft.
The existing-slice visual library is a separate collapsed section whose
selected row explicitly names the synchronized form. Platforms expose one
create-or-edit section based on stable selection: **New Platform** enters an
empty visual draft, while a selected platform permits Update, Rename,
Duplicate, status, and collision actions. Typing a new ID in edit mode cannot
silently create a parallel platform. The tile palette and existing-platform
visual library remain independent collapsed sections, and selected rows expand
their cell context.

`EditorListCard` is the reusable semantics boundary for owner, atlas, module,
and composition rows. It reports button and selected state and accepts a
complete domain label, while nested icon actions retain tooltips. InkWell and
button traversal provide standard Enter/Space activation; polygon scene
shortcuts retain Enter-to-save and Escape-to-cancel. Text content wraps inside
bounded row columns, and full catalog metadata remains available through
semantic labels or retained tooltips at narrow sidebar widths.

Chunk, Prefab, and Level root workspaces use `EditorWorkspaceCard`. Chunk
composition is partitioned by the active Chunk workspace tab. Its rows and
expanded editors or retained dialogs share typed selection and the same
validated composition command with the scene's direct prefab and marker
gestures. Terrain, Prefabs, and Markers own explicit primary-input domains.
Layers is deliberately passive because `TileLayerDef` is metadata-only;
compiled edges remain a non-interactive visual reference. Chunk and Prefab
owner and shape rows, plus Chunk composition records, use `EditorListCard`;
evidence and diagnostic cards remain route-specific because they communicate
status instead of list ownership.
Explanatory route-intro cards compose the same panel shell. The fail-closed
polygon-migration route keeps its specialized warning content inside the shared
workspace surface.

The large current-schema route states are coordinators rather than complete UI
implementations. Prefab keeps guarded view/owner selection, polygon-controller
binding, collision fitting, and command dispatch; typed sibling widgets own
the ordered view selector, preview, owner/catalog panels, collision setup,
fit-draft presentation, and deterministic UI ordering. Chunk keeps scene
coordination, gesture/projection state, selection, and commands; sibling files
own its responsive layout, header, owner panels and preview, diagnostics, grid
and bounds painters, and shared owner ordering. These extracted widgets accept
immutable projections and semantic callbacks, not session or store write
authority.

Parallax uses the shared workspace and bounded panel cards for Layers, Preview,
and Inspector. Layer rows use `EditorListCard` with their asset thumbnail
in the leading slot, preserving selection and edit ownership in the page while
removing its custom border, fill, and padding implementation.

Level Creator uses one compound Level/Parallax session document. Its new-Level
form makes create-new versus reuse intent explicit, its inspector exposes
reference repair and create-and-assign, and pending state can contain exact
diffs for both authoring sources. Apply remains one confirmation and one
rollback-safe transaction. After successful apply and canonical reload, the
page may pass a typed Level/theme target to the shell; the shell atomically
loads it through the Parallax plugin before changing routes. Page-local form
drafts and handoff intent are transient and never become persistence authority.
The route state retains those controllers, validation decisions, command
dispatch, and handoff lifecycle, while `LevelCatalogPane`,
`LevelRuntimeMetrics`, and the small Level presentation widgets render the
catalog, creation form, metrics, errors, and validation rows through callbacks.

Entities uses the shared outer workspace, Entries panel, load-error panel, and
bounded Validation, Pending File Diff, and Apply Result panels. The scene and
inspector remain domain widgets because they own specialized interactive
viewport and field composition; their authoring state still belongs to the
Entities page and plugin paths.
