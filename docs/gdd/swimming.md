# Swimming and pool authoring

Status: implemented. September 13, 2026.

Players enter swimming automatically when their body is sufficiently immersed.
Horizontal cruising speed is 20% lower than on dry land, movement accelerates
more gently, sinking slows, and **Jump** gives an upward stroke. Repeated strokes
can lift the player above the surface and onto a bank. Strokes use the equipped
jump's normal ground-jump resource cost and respect action locks. Dashes end on
entry and are unavailable while swimming. Existing air jumps remain available
after leaving the pool.

The water animation and translucent foreground communicate immersion. There is
no breath meter, drowning timer, water damage, current, or fluid simulation.
The scrolling camera and ordinary
death rules still apply; water never makes falling below the kill plane safe.

## Enemies in water

Grojib and Hashash swim automatically at the same immersion thresholds as the
player. Their horizontal target speed is 80% of their own normal speed, with
the same slower acceleration, coasting and sinking as the player. Status and
combat movement modifiers still apply, so they can remain faster swimmers than
the player when their normal running speed is higher.

They pursue a submerged player's depth, or use upward strokes to reach the
surface and climb out toward a player on land. Strokes have a 0.20-second
cooldown and cost no resources; movement, navigation, jump and stun locks gate
their respective movement. Their existing attacks and Hashash teleport retain
their normal rules. Death stops active swimming propulsion.

Open rectangular pools and adjoining regions support direct pursuit. Land
navigation handles the approach; when no land route exists, an adjacent pool
up to 64 px below a bank permits entry. On immersion, old land-jump plans and
bank stopping bounds are cleared. Bank exits use strokes and normal solid
collision, then land navigation resumes. Walls still block movement: this is
not an underwater maze pathfinder. Author reachable bank exits near water
height and test both directions with both enemies.

Unoco continues flying through water without swimming penalties. Derf stays
stationary. Enemies reuse existing jump/fall animations and the shared water
foreground tint; there are no new swimming sprite sheets.

## Create a pool

1. In Chunk Creator, form an open basin with solid terrain: a floor and banks.
   Water does not carve out or replace solid polygons. A solid flat rectangle
   under the entire surface prevents the player from entering.
2. Select the **Water** tab and expand **Create water region**, like Terrain's
   creation card. Optionally name the region and choose **Biome water**
   (`biome_water`) in the shared material picker; its eye button previews the art.
   Press **Draw rectangle**, then drag opposite corners in the scene.
   **Snap to grid** uses the chunk's tile size. **Snap to neighbor vertices**
   captures nearby terrain, placed-prefab and water corners; an amber ring marks
   the captured corner. Both switches are independent of the visible grid.
   When both are enabled, an exact neighbor takes priority over the grid.
   Terrain and Water share these creation snap preferences.
3. Keep the pool inside the chunk, with a floor at its bottom. Bank tops at the
   surface height are an appropriate starting point. Touching pools may share a
   boundary; overlapping water rectangles are rejected.
4. Press **Enter** or **Save water** to accept the draft; **Escape** or
   **Cancel** discards it. The preview turns red for invalid rectangles.
   Finish or cancel the drawing before Save, Play, or switching tabs/owners.
   Then use **Play/F5**. Move with A/D or arrows and stroke with Space,
   W or Up. Check both bank exits and forward progress against the camera.
5. Save the chunk, then Build when ready to include it in generated runs.

Water starts in **Select** mode and returns to it after saving or cancelling a
drawing. Select a region in the scene or **Existing water regions** to open its
inline metadata and rectangle inspector. Name, material and dimensions are
accepted together with **Save edit**. The same dimension controls as Terrain
edit X, Bottom, Width and Height; changing Height keeps Bottom fixed. They also
let you refine a drawn draft before saving it. Water does not support arbitrary
polygon shapes or solid-collision modes.

To resize visually, select a saved region and drag any of its four square corner
handles in **Select** mode. The opposite corner stays fixed. Release to accept
one undoable edit; **Escape**, **Cancel resize**, or pointer cancellation restores
the original. The water art and outline preview the new size, and the dimension
fields refresh after release. A red preview indicates a zero-area or overlapping
rectangle; releasing it cancels the resize and shows the validation message.
A corner click without dragging leaves the size unchanged.

Choose **Move shape** to drag the whole water region from anywhere inside it.
Width and height stay fixed, and the whole region stays inside the chunk.
Release accepts one undo step; **Escape** or **Cancel move** restores the original.
Move shape remains selected for further moves. Return to **Select** to resize
corners. Grid snapping rounds the movement distance, preserving an initially
off-grid origin; neighbor snapping can align any of its four corners exactly.
Overlapping water is rejected on release, as with resizing.

The selected region's **Snap to grid** control shares Terrain's editing grid
preference, separate from creation. **Snap to neighbor vertices** shares the
creation preference and ignores this region's own corners. Only the dragged
corner snaps; the fixed corner keeps its original position. If there is pending
inline input, resolve Save/Discard/Cancel first, then start the drag again.

Switching away from unfinished inline input offers Save, Discard or Cancel.
Save and Play first validate that input, and Undo first discards local edits.
Each accepted creation or edit is one undoable transaction. Water uses whole
pixels; fractional collision vertices are skipped as exact snap targets. The
neighbor capture radius stays eight screen pixels when zoomed.

The [example chunk](../examples/water_pool_chunk.json) is 600×320, with a pool
at X 128, surface Y 224, width 320 and depth 64. Its banks are at Y 222 and floor
at Y 288. The outer sides match Field's Y 222–270 terrain seam; the centre
extends down to Y 320 beneath the basin. To load it, copy it to
`assets/authoring/level/chunks/field/water_pool_example.json` and Reload the
editor, or enter these values in a new chunk. Copying the file makes it eligible
for that level's normal pool selection on the next Build; leave it under docs
when only using it as a reference.

The default kill plane is 400 pixels below the level ground reference (Y 622
for Field ground Y 222), so the example is safely above it. Custom runtime levels can
override the kill plane; the editor's water panel does not change it. Verify
deep pools through Play before including them in a live route.

Terrain Materials can edit the surface loop's additional frames and timing.
The initial material uses the three lower water frames in the mixed-biomes
atlas. Changing appearance alone does not create a swimmable volume.
