# Swimming and pool authoring

Status: implemented. September 13, 2026.

Players enter swimming automatically when their body is sufficiently immersed.
Movement accelerates more gently, sinking slows, and **Jump** gives an upward
stroke. Repeated strokes can lift the player above the surface and onto a bank.
Strokes use the equipped jump's normal ground-jump resource cost and respect
action locks. Dashes end on entry and are unavailable while swimming. Existing
air jumps remain available after leaving the pool.

The water animation and translucent foreground communicate immersion. There is
no breath meter, drowning timer, water damage, current, or fluid simulation.
Other actors retain their existing movement. The scrolling camera and ordinary
death rules still apply; water never makes falling below the kill plane safe.

## Create a pool

1. In Chunk Creator, form an open basin with solid terrain: a floor and banks.
   Water does not carve out or replace solid polygons. A solid flat rectangle
   under the entire surface prevents the player from entering.
2. Open **Water regions → Add water rectangle**. Enter left X, surface Y,
   width and depth in world pixels, and select **Biome water** (`biome_water`).
3. Keep the pool inside the chunk, with a floor at its bottom. Bank tops at the
   surface height are an appropriate starting point. Touching pools may share a
   boundary; overlapping water rectangles are rejected.
4. Apply and use **Play/F5**. Move with A/D or arrows and stroke with Space,
   W or Up. Check both bank exits and forward progress against the camera.
5. Save the chunk, then Build when ready to include it in generated runs.

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
