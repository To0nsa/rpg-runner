# Swimmable water

Status: implemented. September 13, 2026.

## Ownership and source

Chunk-v2 has an optional `waterRegions` array. Each region has `id`, `x`, `y`,
`width`, `height`, and `materialKey`. Coordinates are whole world pixels with
positive dimensions, contained within the chunk. IDs and material keys use
lowercase snake_case keys. IDs are unique and sorted; overlapping rectangles
are rejected, while touching rectangles are allowed. An absent array means no
water; explicit null and unknown fields fail validation.

`WaterRegionData` and collection validation belong to Core. The shared content
pipeline owns strict JSON decoding. Water remains separate from `solid`,
`oneWay`, and visual-only `none` polygons. It produces no collision edges,
triangles, support surfaces, or enemy navigation links. Materials never grant
swimming. Solid polygons provide banks and floors.

The optional records extend staged artifact format 4 without changing existing
geometry semantics. Dry generated chunks retain their existing representation.
`waterSignature` hashes canonical ordered water records separately from polygon
and edge signatures. Source/artifact parity validation compares this digest too.
Changing water therefore invalidates content parity even when solid edges match.

## Publication and simulation

The stream candidate binds water to the same chunk instance identity and X
origin as terrain, converting bounds to 1/1024-world-unit physics ticks. Its
immutable water list publishes atomically with the terrain runtime bundle and
render snapshot. Version rebinding and prepared/captured Play preserve those
same records. Water is never looked up from repository files during a run.

Players receive a registered `SwimStateStore` at spawn. `WaterImmersionSystem`
classifies the facing-aware capsule centre column before ability activation,
movement and gravity, then refreshes it after terrain motion. Immersion is the
vertical intersection divided by capsule height, in thousandths. Half-open X
bounds avoid ambiguity between adjoining pools; maximum vertical immersion is
independent of query order. Invalid/disabled/kinematic bodies become dry.

Swimming starts at 450/1000 immersion and ends below 250/1000. The state does
not place the player on a support edge. Horizontal acceleration is multiplied
by 0.5 and deceleration by 0.45; maximum running speed is preserved because the
camera continues scrolling. Gravity is multiplied by 0.12, with downward speed
capped at 42 px/s. Upward strokes are not clamped to the sinking speed.

Jump input while swimming requests an upward 260 px/s stroke, with a minimum
0.20-second interval rounded upward to simulation ticks. Jump action locks,
loadout ability admission, cooldowns and ground-jump resource costs still apply.
Strokes do not spend or reset air jumps. Ground contact retains ordinary jump
reset behavior. Entering water cancels active/pending dash motion and its
gravity suppression; a new dash cannot commit while swimming. Other combat
and control rules remain owned by their existing systems.

Snapshots expose `isSwimming` and `waterImmersion1000`. HUD affordability uses
stroke timing and ground-jump costs, and disables mobility while swimming.
Existing jump/fall character clips remain in use. Only players swim in this
version; enemies, pickups and projectiles retain their current motion rules.

## Presentation

Terrain-material-v3 edge layers optionally supply 1–63 `additionalFrames` and
`frameDurationMs` (1–60000, initially 160 in the editor). `region` is frame zero. All frames
must have identical source dimensions; PNG bounds validation and traversal cover
every frame. Fill and cap roles remain static. Shared integer frame selection
rounds milliseconds to the nearest tick, with a one-tick minimum.

The `biome_water` material uses the canonical atlas
`assets/images/level/atlases/fantasy_environment/mixed_biomes.png`: three 32×32
surface frames at (784,432), (832,432), (880,432), with anchor Y 6 and a 1×1
fill at (784,450). At 60 Hz it advances every 10 ticks. Animation follows the
snapshot tick, so pausing the run freezes it. Animated pixels do not move the
gameplay surface.

`StagedTerrain` owns extracted/cached atlas images and their disposal. The shared
water compositor repeats in world X, clips to the pool and replaces fill alpha
with surface alpha. It paints behind actors, then a world foreground component
adds a 32% tint over entities. Debug overlays retain their higher priority.
Chunk previews use the same compositor and frame math. Editor preview clocks
are visual tickers, independent of gameplay authority.

## Authoring and validation

Chunk Creator's **Water** scene domain draws rectangles with a material picker,
tile-grid and neighbor-vertex switches, and a retained preview. Terrain and
Water compose the same `ChunkShapeCreationCard`, material selector/preview,
SwitchListTile controls, creation status and action row. Creation snap
preferences are shared. Water starts in Select; Draw rectangle explicitly arms
the tool, and Save/Cancel returns to Select.
The shared scene surface owns pointer routing, pan/zoom and keyboard handling.
`ChunkWaterDrawing` freezes the source revision, name, material, snap policy and
targets at pointer down; creation pointer release retains a candidate without
writing the session.
Enter/Save water publishes one `ChunkWaterCommit`; Escape/Cancel discards it.
Active water drafts block Save, Play and owner/domain switching. Undo cancels the
local draft before consuming committed history.

Existing water regions use the shared outlined list-card presentation and typed
`ChunkWaterSceneSelection`. Scene hits and sidebar rows open an inline inspector;
the former water modal and standalone drawing-controls widget are removed.
`ChunkWaterEditDraft` captures source identity/revision and buffers name/material;
`TerrainPolygonRectangleEditor` owns X/Bottom/Width/Height text through the shared
exact-edit controller. Its bottom anchor is identical to Terrain. Save edit
validates and publishes metadata plus geometry in one stale-checked transaction.
Source checks are shared with drawn water. Invalid or stale edits remain visible.
Selection, tab, owner and level changes resolve pending input through the existing
Save/Discard/Cancel dialog; global Save and Play validate the same mounted editor.
Clean selections reconcile with Undo/Redo, and discarding input remounts the
inspector from current source. Water outline/draft colors reuse Terrain's style.

Select also resizes saved water through `ChunkWaterDrawing.beginResize`.
Selected square handles use a ten-canvas-pixel nearest-corner hit radius, with
clockwise corner order breaking ties. The opposite source corner stays fixed;
the pointer-to-handle offset prevents an initial jump. Moving across the anchor
normalizes the rectangle. Returning to the grab position or clicking without
movement preserves off-grid source bounds without creating an undo entry.
The source collection replaces the selected record in place in material previews
and commits; its old outline is suppressed while the candidate is drawn.

A valid resize release publishes one typed commit and rebinds the inline
inspector to accepted source. Invalid release shows validation feedback and
restores the original. Escape, Cancel resize, pointer cancellation and Undo
cancel the local preview; active drags block Save, Play and owner/domain changes.
Pending inline input is resolved before a new resize gesture can begin. The
existing stale-revision gate rejects intervening session edits, and source
rebinding cancels route-local gestures when their owner is replaced.

Resize uses the existing Terrain edit-grid preference and shared neighbor switch;
creation retains its separate grid preference. Snapping affects only the moving
corner and excludes every corner of the region being resized. Both operations
otherwise use the same captured targets and snapping routine.

Neighbor snapping shares the terrain nearest-vertex routine and uses an eight
canvas-pixel radius divided by the current zoom. Targets are direct terrain
vertices, expanded prefab vertices and existing water corners inside the chunk.
Only exact whole-pixel targets qualify; equal-distance ties retain source order.
Neighbors take priority over grid snapping. Otherwise the shared grid policy
rounds to the tile size (or one pixel when disabled), clamping to the last
in-bounds grid intersection. Drag direction does not affect the result.

Creation shares local ID allocation, while creation, resize and inline edits
share Core codec validation with the commit adapter. Zero-area and overlapping
drafts remain uncommitted; material art previews valid candidates, with an outline
and snap-target overlay.
Typed edits carry the expected chunk revision and use the existing plugin,
Undo/Redo, Save and Build transaction path. No-op edits preserve revision.
Chunk copying preserves water.
Captured Play validates water material references and captures every animation
asset; missing references prevent partial scenario publication.

The [pool example](../examples/water_pool_chunk.json) contains one water region
and a concave solid bank/floor polygon. It is deliberately outside live level
selection. See the [gameplay and authoring guide](../gdd/swimming.md) to use it.

Tests cover source rejection, water/solid signature separation, atomic binding,
immersion boundaries and lifecycle, locks/costs/strokes, floor contact,
repeatable commands, validator protocol replay, frame timing, atlas rendering,
editor saves and captured background Play. Existing replay frames encode strokes
as jump presses; no network protocol extension is required. Client and validator
must ship the same Core/content version under the existing compatibility gate.
