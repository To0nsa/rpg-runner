# Bounty Hunter assets

Original art by [Clembod](https://clembod.itch.io/). See [license.txt](license.txt).

The complete source pack, including individual frames, Aseprite files, previews,
and contact/license files, is preserved in the ignored local directory
`resources/characters/bounty_hunter/`. Its original archive is kept at
`resources/Bounty Hunter+Add.zip`.

Runtime PNGs are byte-for-byte copies of the supplied sheets and portrait.
Gun, crossbow, and shotgun variants share the following atlas dimensions:

| File | Cell size (pixels) | Grid (columns x rows) |
| --- | --- | --- |
| `sprite_sheet.png` | 73 x 54 | 8 x 30 |
| `add_on_sheet.png` | 89 x 65 | 13 x 9 |
| `run_shoot_sheet.png` | 73 x 54 | 8 x 3 |
| `hurt_no_effect_sheet.png` | 73 x 54 | 3 x 2 |

Shared art:

| File | Cell size (pixels) | Grid (columns x rows) |
| --- | --- | --- |
| `effects/dash_attack.png` | 105 x 59 | 3 x 1 |
| `effects/dust.png` | 63 x 20 | 7 x 5 |
| `effects/shoot.png` | 52 x 38 | 6 x 8 |
| `portrait.png` | 56 x 56 | 1 x 1 |

The add-on sheets contain the three-hit combo, double jump, bomb drop,
wall-slide aim/shoot, and the shared bomb idle/ignite/countdown/explosion frames.
The run-shoot sheets contain three shooting phases, each with eight run poses.
Some atlas cells are empty padding; grid capacity is not an animation's length.

All 715 individual animation frames in the source pack occur in these sheets.
The supplied Dash Attack has 10 frames; the base melee combo has 14 and the
add-on three-hit combo has 13. Original frame sizes and layouts are retained;
base/add-on pivots still need alignment when the character is integrated.
This import does not register a playable character or define gameplay timing.

Archive SHA-256: `21a64fa3fd9eec95d97a8207508d2f380df93b9da2772c1ee91e747f94de8651`.
