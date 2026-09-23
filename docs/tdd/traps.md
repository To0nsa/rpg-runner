# Trap placement and animation contracts

The Core trap catalog and optional Chunk-v2 `traps` collection are implemented.
Runtime activation, damage, renderer integration and the Traps authoring tab
remain in [the implementation plan](../building/traps/plan.md).

## Ownership and source

`runner_core/traps` owns immutable IDs, placements, geometry and frame maps.
`runner_content_pipeline` owns the single strict JSON decoder used by both the
editor codec and generator. `ChunkPattern.traps` carries the compiled placements;
Chunk Play and Level Play capture immutable lists and validate them against
their captured terrain dimensions. Traps do not alter terrain signatures or
connection seams.

Source order is lexicographic by x, y, trap enum ordinal, facing enum ordinal,
trigger offsetX, offsetY, width, height. Exact duplicates and more than eight
placements per chunk are rejected. Positions and rectangle coordinates must be
integers. The full sprite rectangle, anchor, trigger and all damage envelopes
must fit in the chunk. Spike omits `facing`; the other types require `left` or
`right`. Facing mirrors art and damage geometry about the anchor, but leaves
the independently saved trigger unchanged. An absent `traps` field means empty;
explicit null fails. Export omits an empty collection, preserving existing
trap-free bytes.

Editor composition snapshots and operations include traps. Existing layer,
prefab and marker edits retain them, and trap operations use the same optimistic
revision policy and whole-document validation as those existing domains.

## Reviewed art map

All coordinates below are source pixels. Spike and Axe use 128-pixel cells.
Their reference GIFs were compared against PNG cells using nontransparent source
pixels. The GIFs include a background and floor; the Spike comparison excludes
pixels at or below the floor at local y=95. Original archives remain under the
ignored `resources/traps` directory; runtime PNGs are under
`assets/images/entities/traps`.

| Trap | Sequence | Durations | Anchor | First harmful time |
| --- | --- | --- | --- | --- |
| Spike | 27 row-major cells, 15 columns; GIF 0–26 | 100 ms except cells 7–9 at 40 ms | (64,96) | 700 ms |
| Axe | Occupied cells 10–31, then 32–36 repeated three times, then 37–49, then 0; GIF 23–73 | 100 ms through 31; 350 ms for 32–36; 70 ms for 37–40; 150 ms for 41–49; 300 ms for 0 | (64,26) | 800 ms |
| Dart launcher | Cropped row 1 cells 0–4, row 2 cell 0, row 3 cells 0 and 2 | 200 ms for first two poses, then 100 ms | (32,24) in cropped frame | 500 ms |

Axe occupied-cell numbering follows rows with 10, 22, 5 and 13 occupied cells.
GIF 0–22 is ambient motion and is excluded from the triggered cycle. Blade
capsules follow each visible blade pose; the two blurred release poses use
elongated capsules. Spike capsules follow the exposed tips during cells 7–21.

The Poison Darts pack has no reference GIF. Its initial safe timing is explicit
catalog tuning. Launcher rectangles are 52×64, offset (32,48) within each
128-pixel sheet cell. This crops the baked flying darts from the launcher art.
The muzzle is (22,-2) relative to the anchor. The independent flight rectangle
is (0,704,32,16). The launcher sequence fires exactly once.

Core frame boundaries use ceiling of cumulative milliseconds × tickHz / 1000.
This avoids accumulating per-frame rounding error. At 60 Hz the Spike sequence
is 152 ticks (2520 ms reference, +13⅓ ms); Axe is 563 ticks (9380 ms,
+3⅓ ms); launcher is 60 ticks (1000 ms, exact). Total error is less than one
tick. The catalog gives a one-second cooldown following each sequence.

`RenderFrameRect` is pure data for explicit sprite extraction. Frame selection
belongs to fixed-tick Core timing; renderers must not infer hit windows from
elapsed animation time.
