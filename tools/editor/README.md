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
- chunk authoring with direct terrain polygons, expanded placed-Prefab
  collision, active-level parallax and terrain-material scene preview,
  actor/navigation/marker diagnostics, scene-based composition, shared
  pan/zoom/grid controls, and Prefab transform editing
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

Polygon metadata uses selectors for supported surface semantics and terrain
materials loaded from the canonical terrain-material manifest. Prefab polygon
dialogs retain thumbnail selectors and an editable preview. Chunk Creator puts
the three selectors directly in the Shapes card; each selection is one
validated history edit, and its Material **Preview** button opens the composed
fill, top/detail bands, endpoint caps, source assets, and explicit
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
only the additional rotation needed for the actual polygon edge. Applying
writes only `assets/authoring/level/terrain_material_defs.json`. Run the root
content generator afterward to refresh the generated runtime registry. The
manifest is strict schema v3; the editor and runtime do not contain
older-schema compatibility or migration paths.

The generator compiles every source polygon into the staged terrain artifact.
Normal gameplay and replay validation consume that admitted polygon artifact
through the direct terrain authority. Collision, navigation, placement, and
render publication share the same streamed candidate; there is no selectable
legacy rectangle-terrain runtime path.

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

Prefab and Chunk polygon scenes share the same controls:

- use **New polygon** in the Shapes card to start a draft, then use
  **Place vertex** in the scene to append snapped draft vertices
- use **New rectangle** in the Shapes card, then drag across opposite
  corners to create an editable four-vertex polygon draft
- committed axis-aligned four-vertex shapes are labelled **rectangle** and
  expose exact X, bottom, width, and height fields; height keeps the bottom
  edge fixed and moves both top corners in one source-history edit
- while a draft is open, **Place vertex**, **Move vertex**, and **Insert vertex**
  edit that draft; **Select shape** and **Move shape** remain disabled
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

In the Chunk Creator, new direct shapes start as solid `ground` terrain using
the first canonical material in the authored terrain-material catalog. A
freeform draft begins rendering that material after its third vertex; rectangle,
vertex, and whole-shape gestures update the material preview continuously. This
projection is visual only and does not enter source history until **Save**.

Rejected edits retain their draft/gesture and show diagnostics; they do not
enter source history. Draft **Save** removes redundant aligned middle vertices
before the single commit. For a rejected committed-shape gesture, **Normalize**
applies the visible preview or selecting another tool discards that preview.
**Apply current source** remains disabled until local work is resolved and is
the only normal file-write action; it always requires confirmation.

## Chunk Authoring Workspace Navigation

The Chunk Creator keeps one **Chunk creation scene** between an owner rail and
an authoring sidebar. On wide windows, **Chunk owners** sits to the scene's
left, while **Terrain collision** and **Layers, prefabs & markers** share the
right-side scroll area. On narrow windows, both scroll areas sit below a
bounded scene, with owners on the left. The old terrain/composition tabs do not
return. Expanding or collapsing cards and their natural-height sections changes
presentation only, not the selected owner, terrain draft, viewport, history,
or pending source state.

The scene domain selector makes primary input explicit. The Prefabs domain has
Select, Place, and Move tools backed by the active prefab catalog. Place and
move drags show a local ghost, then submit one normal validated composition
command on release; Escape cancels without changing source. Grid-enabled
placements snap to the chunk tile size, while exact placement fields remain
integer-pixel overrides in the existing dialog.

The Markers domain likewise provides Select, Place, and Move tools. These edit
only the authored query anchor at integer-pixel precision. Core-resolved spawn
positions and support are read-only evidence: they can be toggled independently
and are hidden for the record being moved until its accepted source is
reprojected. Marker ID, chance, salt, placement mode, and exact coordinates stay
available in the typed dialog.

Owner lifecycle and direct terrain collision remain in the first card. The
second card retains the visual-stack summary and validated dialog workflows for
tile-layer metadata, prefab placements, and enemy markers. `TileLayerDef` is
metadata-only, so this workspace exposes no tile painting or cell editing.
Direct scene gestures and the retained add/edit/delete dialogs both dispatch
the canonical Chunk composition command.

When an all-current workspace loads the Chunk-v2 polygon workflow, each
read-only expanded prefab collision exposes **Open prefab**.
The action goes through the editor shell's unsaved-work guard, loads the
current Prefab-v3 document, and selects the exact stable source owner for shape
editing. Chunk placements continue to own transforms only; the editor does not
create per-instance polygon overrides.

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
