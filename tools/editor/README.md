# Runner Editor

Standalone authoring tool for `rpg_runner` content workflows.

This app is intentionally separate from gameplay runtime authority. Core gameplay
truth remains in `packages/runner_core/lib/**`.

## Run

```bash
cd tools/editor
flutter run -d windows
```

## Current Capabilities

Implemented authoring domains:

- entity collider/source-bound authoring for players, enemies, and projectiles,
  with runtime-faithful capsule and broad-phase previews
- prefab (obstacle/platform/decoration), tile-slice, platform-module, and exact
  half-pixel polygon-collision authoring, including tagged atlas/tile slices
  and searchable slice selection; Prefab atlas slicing supports configurable
  cell dimensions, origins, gutters, and arbitrary manual pixel rectangles
- chunk authoring with whole-pixel direct terrain polygons, expanded
  placed-Prefab collision, searchable visual Prefab and enemy libraries,
  active-level parallax and terrain-material scene preview, Core-backed
  actor-traversability and marker-placement previews, scene-based composition,
  shared pan/zoom/grid controls, and Prefab transform editing
- level metadata authoring with list/inspector editing, lifecycle controls,
  assembly segment sequencing, explicit new/existing visual-theme assignment,
  atomic Level-plus-theme pending/apply, repair of unresolved references, and
  guarded handoff to Parallax
- parallax theme authoring scoped by active level, with ordered layer editing,
  deterministic save output, validation, preview pan/zoom, and an absolute
  numeric all-layer Y-offset preview/save control (`0` is the viewport bottom)

Editor foundations shared across those domains:

- one shared top toolbar for page selection, reload, apply, undo, redo, pending
  file state, validation counts, and operation progress
- startup workspace binding and plugin-backed route selection
- session-managed load, validation, pending-change previews, and direct-write export
- undo/redo history for entity edits, chunk edits, and committed prefab/module edits
- shared outlined workspace, panel, subsection, and list-row cards with one
  spacing system; Chunk owner, terrain, and composition cards expand independently
- shared pan/zoom scene controls, inspector forms, and deterministic export summaries
- shared atlas PNG discovery, integer region/grid math, grid/manual selection,
  image viewport controls, selection painters, and exact-region thumbnails

## Windows Chunk Play Mode

Chunk Creator can run the selected current-schema chunk through the real Core
simulation and Flame renderer without leaving the editor. On Windows, use the
**Play** button or press `F5`. Valid accepted pending changes are included in
the in-memory snapshot; entering, restarting, and stopping Play mode do not
apply source files, regenerate Dart, create a replay, or contact the backend.

Play is unavailable until the current chunk validates and every route-local
draft, gesture, dialog, or unsaved inspector edit has been saved or discarded.
Preparation uses fixed scenario seed `4401`, Eloise, and an empty loadout.
Other platforms, custom seeds/characters/loadouts, remapping, and gamepads are
not supported by this editor mode.

Gameplay controls:

| Action | Keyboard/mouse |
| --- | --- |
| Move left | `A` or Left Arrow |
| Move right | `D` or Right Arrow |
| Jump | Space, `W`, or Up Arrow |
| Mobility | Left or Right Shift |
| Primary | Left Mouse Button or `J` |
| Projectile | Right Mouse Button or `K` |
| Secondary | `Q` |
| Spell | `E` or `L` |

Playtest lifecycle controls:

| Action | Key |
| --- | --- |
| Enter Play / stop and return to Edit | `F5` |
| Start from Ready | Enter |
| Pause or explicitly resume | `P` |
| Restart the same immutable scenario | `F6` |
| Stop and return to Edit | Escape |

Start/Resume actions give gameplay focus to the keyboard and mouse; clicking
the active game surface reacquires it if needed. Mouse aim is active only
inside the fitted game viewport; editor chrome and letterbox bars are excluded.
Losing focus or deactivating the app cancels every held input and pauses the
run. Returning to the app does not resume automatically: click **Resume** or
press `P` explicitly.

The host is always labelled **PLAYTEST - NO REWARDS/REPLAY**. It creates no
run ticket, score submission, reward, leaderboard entry, ghost, replay spool,
or player-state mutation. Stopping restores the same Chunk Editor selection,
tab, viewport, undo/redo history, and pending diff.

## Level And Visual Theme Workflow

Level Creator no longer requires an invalid two-step Level-then-Parallax save.
For a new Level, choose **Create new theme** (the default) or **Use existing
theme**. Create-new stages a revision-1 empty Parallax theme and assigns its ID
to the Level as one undoable command. Reuse changes only Level source. Existing
Levels can also use **Create and assign new theme**, and a loaded missing
reference opens a repair state instead of a fake dropdown entry.

Applying a new Level/theme previews and commits
`assets/authoring/level/level_defs.json` and
`assets/authoring/level/parallax_defs.json` through one rollback-safe
transaction. After a successful canonical reload, **Open in Parallax** selects
the exact saved Level/theme so its first layer can be added normally.

Authoring apply does not regenerate runtime Dart. When Level and layer work is
complete, run from repository root:

```bash
dart run tool/generate_chunk_runtime_data.dart
dart run tool/generate_chunk_runtime_data.dart --dry-run
```

The first command publishes generated registries; the second verifies that no
generated drift remains.

## Entity Collider Preview

The entity scene presents combat geometry using the runtime field meanings:

- players and enemies show their upright capsule as the primary outline and
  its tight enclosing broad-phase AABB as the secondary outline;
- for actors, `halfX` is capsule radius and `halfY - halfX` is the vertical
  half-spine; `offsetX` mirrors with facing;
- projectiles show a canonical horizontal preview of their runtime
  direction-oriented capsule, where `halfX` is half-spine and `halfY` is
  radius;
- casters with an authored `castOriginOffset` show an amber dot at the
  selected preview angle. The inspector's 0–360° preview slider rotates that
  dot without changing authored data; at runtime, the projectile launches that
  many world units from the caster transform along its resolved aim direction;
- the **Origin point** and **Collider** checkboxes beside animation controls
  choose which overlapping scene handle renders in front;
- actor `halfY < halfX`, non-positive dimensions, and non-finite values are
  invalid and block export rather than previewing a different runtime shape.

Actor previews call Core's quantized AABB-to-capsule derivation. The editor
still writes the existing catalog-bound size and offset fields; it does not
introduce an independent combat-hurtbox schema.

Entity Apply edits only the bound numeric expressions, preserving surrounding
argument order, comments, formatting, and unrelated source. Patched sources
and their persistent `.bak` files are committed as one verified transaction
with a final source-drift check. A rejected Apply is rolled back and reported
immediately; if verified outputs commit but transaction cleanup cannot finish,
the result is reported as applied with exact recovery paths for review.

Entity source parsing runs outside the UI isolate, and referenced image
availability is cached in the loaded document. The collider editor therefore
does not perform repository parsing or repeated file-existence checks during
scene builds and handle drags.

## Polygon Source And Offline Migration

The checked-in source includes `anvil_00` with one Prefab collision polygon,
and all eight chunks with a continuous `ground_001` polygon carrying `ground`
/ `grass_dirt` metadata. Other collision-reset Prefab owners remain available
for authoring. Missing Prefab collision is therefore a visible, non-blocking
authoring warning.

Selecting an existing Prefab-v3 or Chunk-v2 owner row expands its metadata
editor directly below that row. These mounted forms are route-local drafts:
Apply dispatches the existing stale-checked metadata command, Cancel changes no
source or history, and a rejected command keeps the entered values and error
visible. Dirty owner forms block Apply-to-files and prevent undo/redo from
reaching session history: undo cancels the local form first and redo remains
unavailable. Owner, level, or Prefab-workspace navigation must resolve the
draft through Save, Discard, or Cancel.
Active Prefab polygon operations receive the same owner-switch protection.
Owner creation is a collapsed inline section. Rename, Duplicate, and Delete
are labeled contextual actions inside the expanded owner editor; Rename uses a
separate inline stable-key-preserving lifecycle form. Creation and rename no
longer open routine modals. Their dirty values use the same Save/Discard/Cancel
navigation guard, and deletion retains its reference-aware confirmation.

Polygon metadata uses selectors for supported surface semantics and terrain
materials loaded from the canonical terrain-material manifest. Prefab polygon
dialogs retain thumbnail selectors and an editable preview. Chunk Creator puts
the three selectors directly in the Shapes card; each selection is one
validated history edit, and its Material **Preview** button opens the composed
fill, top/detail bands, convex corner/endpoint caps, source assets, and explicit
wall/underside coverage in a read-only dialog.

The **Terrain Materials** route creates, duplicates, edits, validates, and
reference-safely deletes those definitions. Each material owns a stable key,
fill region, required top/slope profile, optional left/right wall and underside
profiles, and independent optional pairs of top cliff and underside corner
caps. Each visual role selects an exact
`X/Y/W/H` rectangle from a PNG below `assets/images/terrain/`. The picker offers
a configurable cell grid (32x32 is only its default) and arbitrary manual pixel
rectangles; selecting a region never creates a cropped asset. Edge regions use
their natural world-facing orientation in the atlas—left/right walls stay
vertical and undersides stay downward-facing—while previews and runtime apply
only the additional rotation needed for the actual polygon edge. The Chunk
Creator and composed preview share one canvas compositor. It extracts selected
atlas regions, paints full polygon fill, then applies ordered edge bases and
caps with source-alpha replacement. Transparent cap and edge pixels therefore
reveal the scene rather than lower terrain art, while detail can still reveal
its own base. Edge bands stop at their exact authored endpoints. Only internal
repeat joins receive destination-over material-fill backing, preventing small
atlas-cell gaps without flattening the rocky silhouette.
Applying writes
only `assets/authoring/level/terrain_material_defs.json`. Run the root content
generator afterward to refresh the generated runtime registry. The manifest is
strict schema v3; the editor and runtime do not contain older-schema
compatibility or migration paths.

The generator reviews and triangulates every source polygon into the staged
terrain artifact. Before collision compilation it partitions direct Chunk
shapes whose `collisionMode` is `none`: those shapes remain material-backed
render fills but never enter collision, navigation, placement, seam, support,
or exposed-edge geometry. Normal gameplay and replay validation consume the
same admitted candidate; there is no selectable legacy rectangle-terrain
runtime path. Prefab collision shapes remain `solid` or `oneWay` only.

The normal editor accepts only current Prefab-v3/Chunk-v2 source. Legacy
Prefab-v1/v2 and Chunk-v1 parsing is isolated to this offline check command:

```bash
cd tools/editor
dart run tool/migrate_polygon_authoring.dart --check \
  --report=.tmp/slopes-phase4-migration.json
```

Omitting `--check` still runs check mode. The command detects a complete legacy
or current generation, strictly parses it, builds and round-trips all target
files in memory, records before/after SHA-256 values plus revision and
placement-impact facts, and rechecks source digests before reporting. The
optional report must be a workspace-relative `.json` path outside
`assets/authoring`. Checked-in source now reports current with nine validated
targets and zero pending representation migrations.

Exit codes are `0` for a blocker-free readiness plan, `1` for a source,
planning, target-validation, drift, or report failure, and `64` for invalid
arguments. Explicit `--write` is retained for a complete blocker-free legacy
workspace and requires `--report=<external-path.json>`; it uses the guarded
nine-file transaction and emits committed/no-op/failure evidence. Re-running it
against current source is a no-op. Source migration does not activate polygon
collision at runtime.

## Polygon Interaction Profile Benchmark

The Phase 4 polygon authoring surface has a deterministic Windows profile
benchmark for vertex and whole-shape drag. It uses 120 warmup and 600 measured
frames per mode against the reviewed 16-shape/256-edge fixture:

```powershell
cd tools/editor
flutter drive --profile `
  --driver=test_driver/integration_test.dart `
  --target=integration_test/polygon_interaction_benchmark_test.dart `
  -d windows
```

The driver writes the compact report to
`.tmp/slopes_phase4_polygon_interaction.json` at repository root. It records
the Git revision/dirty state, fixture signatures, interaction and frame
percentiles, missed-input counts, source-identity evidence, and each gate. The
benchmark is test-only: it cannot write authoring source or select the future
terrain artifact at runtime.

## Polygon Controls

Prefab and Chunk polygon scenes share the same geometry controls:

- use **New polygon** in Prefab authoring or **Draw polygon** in Chunk
  authoring to start a draft, then primary-click the scene to append snapped
  draft vertices
- use **New rectangle** in the Shapes card, then drag across opposite
  corners to create an editable four-vertex polygon draft
- committed axis-aligned four-vertex shapes are labelled **rectangle** and
  expose exact X, bottom, width, and height fields; height keeps the bottom
  edge fixed and moves both top corners in one source-history edit
- while a draft is open, **Move vertex** and **Insert vertex** edit that draft;
  in Chunk authoring, **Continue drawing** returns to vertex placement, while
  **Select shape** and **Move shape** remain disabled
- with no saved collision shape and no open draft, **Move vertex**, **Move
  shape**, and **Insert vertex** are disabled
- Undo and Redo traverse draft vertex placement, movement, and insertion locally
  without changing source history
- press Enter or choose **Save** to normalize, validate, and commit the complete
  draft as one source-history edit
- press Escape or choose **Cancel** to discard the active draft/gesture
- outside creation, use **Select shape**, **Move vertex**, **Insert vertex**, or
  **Move shape** before primary-clicking or dragging the corresponding element
- the chosen edit tool remains active after a completed gesture, so consecutive
  vertices, edges, or shapes can be edited without selecting the tool again
- press Delete/Backspace to delete the current selection
- use Ctrl+Z to undo and Ctrl+Y or Ctrl+Shift+Z to redo
- use Ctrl+drag to pan and Ctrl+wheel to zoom
- use **Normalize** explicitly to apply canonical winding/start and remove
  diagnosed collinear middle vertices

In the Chunk Creator, terrain creation and existing-shape editing are separate
sidebar sections. Both start folded. **Create terrain shape** keeps persistent
**Collision** and
**Material** dropdowns above **Draw polygon** and **Draw rectangle**. Collision
offers **Solid**, **One-way**, and **No collision (visual only)**. An optional
**Shape name** accepts a unique lowercase source ID; leaving it blank uses the
next deterministic `solid_###` name. Each named material row includes an eye
action for its read-only preview. The section folds independently without
discarding its selections or active draft. Initial values are solid `ground`
terrain and the first canonical material in the authored terrain-material
catalog. Polygon and rectangle drafts capture the current name and choices when
creation begins; the settings lock for that active operation and the collision
and material choices remain selected for the next shape after Save or Cancel.
Contextual status explains when the rectangle tool is ready, a rectangle is
being dragged, or a draft is ready. **Save shape** stays disabled until the
draft has at least three vertices.

**Existing terrain shapes** shows the saved-shape count and separates each
shape's collision mode, geometry type, material key, and vertex count. Selecting
a row expands its metadata, lifecycle actions, and geometry editor directly
below that row. Its material dropdown uses the same per-option eye previews as
creation. The shape name is editable under the same lowercase, owner-unique
rules. Rectangle dimensions and selected-vertex coordinates share one
contextual editor ending in **Save edit**; a name and exact geometry change are
committed together as one revision. Clicking the active shape row again closes
a clean editor. If the name or exact geometry fields have changed, the editor
instead offers **Save**, **Discard**, and **Cancel** before closing. A freeform
draft begins rendering its material after its third vertex; rectangle, vertex,
and whole-shape gestures update the material preview continuously. This
projection is visual only and does not enter source history until **Save
shape**.

Rejected edits retain their draft/gesture and do not enter source history.
Draft **Save** removes redundant aligned middle vertices
before the single commit. For a rejected committed-shape gesture, **Normalize**
applies the visible preview or selecting another tool discards that preview.
**Apply current source** remains disabled until local work is resolved and is
the only normal file-write action; it always requires confirmation.

## Chunk Authoring Workspace Navigation

The Chunk Creator keeps one **Chunk creation scene** between an owner rail and
an authoring sidebar. On wide windows, **Chunk owners** sits to the scene's
left, while one tab-specific group of sibling authoring sections occupies the
right-side scroll area above shared, document-wide **Diagnostics**. There is no
redundant Terrain, Prefabs, Markers, or Layers wrapper card. Owner rows include
a read-only thumbnail built from the same background, terrain-material, prefab,
and foreground projections as the scene. On narrow windows, both scroll areas
sit below a bounded scene, with owners on the left. Persistent
visual/viewport controls sit above the **Terrain / Prefabs / Markers / Layers**
selector, which swaps only the domain's sections; it never replaces or rebuilds
the scene or filters Diagnostics. Owner, authoring, visual-stack, and
Diagnostics sections start folded and retain presentation-only expansion state
while mounted. Tab changes preserve the viewport and each
domain's last selection. Active source gestures and retained dialogs lock the
tabs until that operation is finished or cancelled. Merely selecting a Prefab
or expanding its inline editor does not lock the workspace.

The scene tabs make primary input explicit. The Prefabs domain has Select,
Place, and Move tools backed by a persistent visual-library section at the top
of its sidebar group. The library searches token-by-token across Prefab ID,
stable key, kind, and tags, filters by kind or Prefabs already used in the
selected Chunk,
and renders atlas-slice or platform-module thumbnails through one browser-owned
decoded-image cache. Pressing Enter selects the first filtered result. Its
stable-key selection is route-local and shared by both the canvas Place tool
and inline creation form; it never creates a pending source change by itself.
Selecting an existing placement in the list or scene reveals its editor directly
below the row, matching existing-terrain-shape editing. Unselected rows have no
Edit/Delete icon cluster. The selected editor contains labeled **Open prefab**
and **Delete** actions plus the same visual browser and transform fields. Its
tentative owner and values stay row-local until Apply; selecting the row again
or pressing Cancel closes it without changing source or the route catalog
choice. Delete submits one immediately undoable composition edit without a
confirmation modal. Switching domains, owners, or source revision discards the
un-applied inline draft and keeps navigation available. Place and move drags
show a local ghost, then submit one
normal validated composition command on release; Escape cancels without
changing source. Grid-enabled placements snap to the chunk tile size, while
exact placement fields remain integer-pixel overrides in the sidebar creation
form and expanded existing-placement row. The Prefabs toolbar also has a
default-on **Surface snap** chip. Within eight canvas pixels, Place and Move
may refine only the candidate Y so the transformed lowest horizontal collider
edge shares a positive-length interval with an exposed upward-facing direct
terrain edge. X stays on its normal tile/pixel grid and the final X/Y origin
remains whole-pixel. The orange collision preview becomes green only after the
same Core geometry and occupied-area predicate accept exact contact; point-only
contact, positive-area penetration, another placement, and out-of-bounds
geometry do not snap.

The placement Scale control pairs a compact numeric field with a discrete
slider. When the Prefab has a usable support edge, each slider stop is an exact-
contact scale: Core's reflected, exact-tenth transform leaves that support
height on a whole pixel after the one `1/1024 px` quantization. A saved
incompatible scale remains selected when its placement opens so an old value is
never silently rewritten. Prefabs with no collision or no lowest horizontal
edge retain the full visual-scale range. Surface snap changes no Prefab/Chunk
schema and never weakens the final positive-area overlap validator.

The Markers domain likewise provides Select, Place, and Move tools. Its
foldable **Enemy library** searches Core enemy name, stable ID, and authoritative
terrain-motion role; role and current-Chunk usage filters narrow the visual
cards. Each thumbnail crops the first idle frame using Core's runtime animation
path, frame size, row, start offset, and render scale. The selected ID is route-
local and shared by the scene Place tool and inline creation form; selecting an
existing marker expands the same browser and form below its row for tentative
enemy changes. Missing image files show a safe placeholder and do not change
the Core-derived catalog. Marker
gestures edit only the authored query anchor at integer-pixel precision.
Enabling **Marker placement** draws each recognized enemy's first idle frame,
then keeps support/capsule evidence above the art. Accepted enemies use the
exact Core-resolved body position at full opacity. Rejected enemies use their
attempted body position with muted art, while deferred Hashash and other
body-less outcomes use their authored marker anchor as a muted reference; that
reference is not presented as Hashash's later camera-relative runtime spawn.
The resolved layer is hidden for the record being moved until its accepted
source is reprojected. Chance, salt, placement mode, and exact coordinates stay
available in the sidebar creation form and expanded existing-record editor.
New Derf selections default Placement to `obstacleTop` in both that form and
direct scene Place; other enemies default to `ground`. An explicit form choice
and every saved marker's existing placement remain unchanged.

Direct terrain creation and existing shapes live in the **Terrain** sections.
The **Prefabs** and **Markers** groups each start with a foldable visual library,
followed by a foldable inline creation form and separate foldable
existing-record list. Adding a prefab or marker submits directly from its
section without opening a dialog; selecting a Prefab or Marker row reveals its
edit and delete controls below that row. Re-click and Cancel close the editor
and clear the matching scene selection. The **Layers** group
retains the visual-stack summary and validated tile-layer metadata workflow.
`TileLayerDef` is metadata-only, so Layers pauses primary scene authoring and
exposes no tile painting or cell editing. Direct scene gestures, inline adds,
expanded Prefab/Marker edits and deletes, and retained tile-layer dialogs all
dispatch the canonical Chunk composition command.

Direct-terrain rectangle, vertex, insertion, and whole-shape gestures cannot
enter another direct terrain shape or expanded prefab collision. This
authoring-only occupied-area rule also covers render-only shapes, preventing
ambiguous stacked fills even though they are removed before collision compile.
Within eight canvas pixels, vertices and solid shapes snap to a solid boundary;
the visual radius remains stable while zooming. Contact is allowed, including
exact shared solid edges. One-way shapes block overlap but do not attract seam
snapping; render-only shapes follow the same non-attracting rule. If a
transformed prefab boundary falls between whole-pixel direct-terrain
coordinates, snapping chooses the nearest authorable whole-pixel point that
stays outside it. Direct Chunk terrain always keeps the mandatory whole-pixel
source rule. Its two default-off **Snap to grid** switches raise their affected
creation or editing operations to the selected Chunk's tile-size grid. The
independent switches live inside **Create terrain shape**
and the expanded editor for the selected existing terrain shape: the first
affects only new drafts, while the second affects only saved-shape edits. Each
route-local choice is locked during an active operation. Moving or inserting a
vertex may refine exact collision contact to the mandatory whole-pixel terrain
lattice when a neighboring boundary falls between tile intersections; free
movement remains tile-snapped. Prefab-local collision authoring retains its
existing `1 px` and `0.5 px` choices.

Core-compiled collision edges are hidden by default. The **Shape edges** chip
shows their read-only overlay, with solid edges in pink and one-way edges in
yellow. The default-off **Actor terrain** chip beside **Marker placement**
highlights Core-eligible surfaces for the selected actor; it starts on Éloïse,
where cyan edges answer whether the accepted terrain is traversable by her.
The selector can expose the existing Grojib, Hashash, Unoco, and Derf evidence.
The default-off **Show grid** chip beside **Visual preview** displays a
tile-size grid clipped to the Chunk bounds on every domain tab. **Visual
preview** goes further: it hides that grid, authoring polygons and
handles, expanded collision, compiled edges, actor/marker previews, Chunk
bounds, and the viewport border. Only parallax, terrain-material rendering, and
placed Prefab art remain. Preview canvas input is view-only, while pan and zoom
remain available. These presentation controls do not change source, selection,
collision, or history. Render-only shapes have no compiled-edge overlay by
definition.

When an all-current workspace loads the Chunk-v2 polygon workflow, the selected
placement editor exposes **Open prefab**. The action goes through the editor shell's
unsaved-work guard, loads the current Prefab-v3 document, and selects the exact
stable source owner for shape editing. Chunk placements continue to own
transforms only; the editor does not create per-instance polygon overrides.

Normal loading now detects strict Prefab-v3 and complete Chunk-v2 source and
selects these polygon workflows. Changed current documents can be applied only
through their confirmed, source-drift-guarded transactional stores, then are
reloaded from the exact installed bytes. Legacy or missing source opens one
shared migration-required workspace with no editable data, pending diff, or
export path. It shows the read-only readiness command and can atomically
recheck source after an external migration; it never exposes Prefab-v2
rectangle or Chunk-v1 ground/gap controls. The one-time migration command is
complete; live polygon runtime authority remains unavailable.

The release-signoff walkthrough uses a disposable Git worktree so a
non-developer can exercise diagnostics, editing, apply/reload, narrow-window,
and keyboard behavior without changing the main workspace. See the
[Phase 4 manual polygon usability pass](../../docs/building/slopes/phase4-manual-usability-pass.md).

The release-signoff walkthrough uses a disposable Git worktree so a
non-developer can exercise diagnostics, editing, apply/reload, narrow-window,
and keyboard behavior without changing the main workspace. See the
[Phase 4 manual polygon usability pass](../../docs/building/slopes/phase4-manual-usability-pass.md).
