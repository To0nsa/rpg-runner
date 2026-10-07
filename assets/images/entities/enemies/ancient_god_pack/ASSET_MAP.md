# Ancient God pack art

Source archive: `resources/Ancient God pack.zip`.
The complete pack is extracted to
`resources/enemies_and_creatures/ancient_god_pack/`, preserving the original
folder names, individual PNG frames, Aseprite files, sprite sheets and licenses.
Like other source packs, `resources/` is ignored by Git.

Runtime copies are under `assets/images/entities/enemies/ancient_god_pack/`:

| Character | Source sheet relative to the extracted pack | Runtime sheet relative to this folder | Sheet size (pixels) |
| --- | --- | --- | --- |
| Shoggoth | `Shoggoth/Shoggoth_SpriteSheet.png` | `shoggoth/sprite_sheet.png` | 1788 x 1938 |
| Voidborn Goddess | `Voidborn Goddess/Voidborn Goddess-SpriteSheet.png` | `voidborn_goddess/sprite_sheet.png` | 4140 x 1302 |
| Voidcaller | `Voidcaller/voidcaller_SpriteSheet.png` | `voidcaller/sprite_sheet.png` | 2907 x 3128 |

Each character folder includes an unchanged copy of its source `License.txt` as
`license.txt`. The runtime sprite sheets are also copied without modification.

These assets are registered in the Flutter bundle by
`dart run tool/sync_assets.dart`. Core catalogs and Flame registries reference
all three bosses and both summons at 1.5x scale, matching Bringer of Death.
Choose the required boss in Chunk Creator's mandatory arena metadata. Production
level placements remain unchanged. See [gameplay](../../../../../docs/gdd/ancient_god_bosses.md)
and [implementation](../../../../../docs/tdd/ancient_god_bosses.md).

## Exported animation layout

Rows and columns below are zero-based. Each strip starts at column zero unless
specified. Frame counts and pixel regions were checked against the individual
PNG exports, which all match the copied sheets. Some Aseprite tags include
additional frames absent from the PNG exports; use the exported counts below
when indexing these runtime sheets. All Aseprite source frames use 100 ms timing.

### Voidborn Goddess

Frame size: **138 x 93 pixels**; sheet grid: **30 columns x 14 rows**.

| Animation | Row | Frames |
| --- | --- | --- |
| Idle | 0 | 8 |
| Forward | 1 | 8 |
| Cast 1 | 2 | 11 |
| Vanish (`Despawn`) | 3 | 4 |
| Spawn | 4 | 5 |
| Cast 2 preparation (`Cast2 Idle`) | 5 | 6 |
| Cast 2 casting | 6 | 30 |
| Attack | 7 | 19 |
| Spell 1 (pink blob / eruption) | 8 | 17 |
| Spell 2 startup | 9 | 3 |
| Spell 2 orb loop | 10 | 8 |
| Spell 2 explosion | 11 | 6 |
| Hit | 12 | 3 |
| Death | 13 | 14 |

Cast 2's total of 36 frames comprises the preparation and casting strips.
Spell 2's total of 17 frames comprises startup, orb loop and explosion; its
source frames are not one contiguous row. Runtime Spell 1 is a captured ground
eruption; Spell 2 is a projectile with separate startup, loop and impact states.

### Shoggoth and minion

Frame size: **149 x 114 pixels**; sheet grid: **12 columns x 17 rows**.
Minion exports use the same canvas size despite their smaller visible bodies.

| Animation | Row | Frames |
| --- | --- | --- |
| Idle | 0 | 8 |
| Forward | 1 | 8 |
| Vanish | 2 | 6 |
| Spawn (`Arise`) | 3 | 9 |
| Attack 1 | 4 | 11 |
| Attack 2 | 5 | 12 |
| Cast 1 (`Cast`) | 6 | 11 |
| Spell 1 orb loop | 7 | 6 |
| Spell 1 explosion | 8 | 5 |
| Cast 2 (`Invok`) | 9 | 9 |
| Minion idle | 10 | 4 |
| Minion forward (`Run`) | 11 | 4 |
| Minion attack | 12 | 6 |
| Minion hit | 13 | 3 |
| Minion death | 14 | 5 |
| Hit | 15 | 3 |
| Death | 16 | 8 |

Attack 2 has an authored spinning loop at columns 3 through 7 of row 5.
Spell 1 has 11 total frames across its orb and explosion strips.

### Voidcaller and tentacle

Frame size: **171 x 136 pixels**; sheet grid: **17 columns x 23 rows**.
Tentacle exports use the same canvas size as the caster.

| Animation or effect component | Row | Frames |
| --- | --- | --- |
| Idle | 0 | 8 |
| Forward | 1 | 8 |
| Cast 1 version 1 | 2 | 17 |
| Cast 1 version 2 | 3 | 17 |
| Cast 2 | 4 | 10 |
| Spell 1 vertical startup | 5 | 5 |
| Spell 1 initial beam middle | 6 | 1 |
| Spell 1 beam middle loop | 7 | 2 |
| Spell 1 ground impact | 8 | 6 |
| Spell 1 portal | 9 | 6 |
| Spell 2 diagonal startup | 10 | 5 |
| Spell 2 initial beam middle | 11 | 1 |
| Spell 2 beam middle loop | 12 | 2 |
| Spell 2 ground impact | 13 | 6 |
| Spell 2 portal | 14 | 6 |
| Spell 3 | 15 | 8 |
| Tentacle spawn | 16 | 5 |
| Tentacle idle | 17 | 6 |
| Tentacle attack | 18 | 7 |
| Tentacle hit | 19 | 3 |
| Tentacle death | 20 | 6 |
| Hit | 21 | 3 |
| Death | 22 | 9 |

Each beam has 20 component frames, not a single sequential 20-frame effect.
The portal, beam middle and ground impact have separate source regions.
Spell 3 has an authored loop at columns 2 through 4 of row 15.
The pack provides no dedicated Voidcaller spawn or vanish strip.
