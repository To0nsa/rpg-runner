# Level composition

The `2026.09.9` Forest content revision removes ten ambient enemy placements:
four in early chunks, one in an easy chunk and five in normal chunks. Authored
sources and generated runtime content carry this revision together.

The deployed `2026.09.10` release also refines seven early Forest
chunks: camp props use foreground layers, and trees, rocks, bushes, moss and
the opening bench have adjusted placements. Solid prefab collision follows
those authored positions; these are included in the matching regenerated
client and replay-worker content.

The `2026.10.1` source release adds three easy and three normal Forest grove
chunks and simplifies existing grove, ruin, training-camp and woodcamp layouts.
Prefab changes remove obstructing terrain pockets. Their authored solid
placements and generated collision/sprite records ship together to the client
and replay worker; scoring rules remain unchanged.

The hard chunk catalog was seeded with copies of all 24 normal chunks across
Field, Forest and New Level, with distinct chunk keys and hard difficulty.
The original normal chunks remain available for normal sections. Subsequent
authoring revisions change hard layouts independently. Rocky Grove's hard pool
contains nine layouts; its three older hard layouts have been removed.

The `2026.10.4` Forest assembly ends with nine distinct Rocky Grove hard
chunks, then repeats that final section with a fresh selection. The hard
layouts include the authored October 3 terrain, prop and encounter updates.
The exit terrain of `forest_rocky_grove_hard_003` retains its ground surface
classification so it connects to the rest of the pool without changing its
geometry or the nine-chunk section length.
An entrance platform in `forest_rocky_grove_hard_004` supplies a foothold
before its enlarged rock for the existing ground-enemy movement limits.
Its water gap remains open.

The `2026.10.8` source revision activates the easy boss chunk between the
last easy grove section and the easy enchanted forest. Its dedicated
`boss_bringer_of_death` assembly group contains one mandatory Bringer of Death
arena. The authored terrain and scenery from `2026.10.7` are retained; see
[the boss encounter](bringer_of_death.md) for framing, combat and the victory
blessing.

Forest's hard progression now alternates five distinct Rocky Grove sections of
3–6 chunks with one enchanted-forest chunk, all five remaining hard ruin chunks,
all four hard training-camp chunks, and all three hard woodcamp chunks, in that
order. The final 3–6-chunk grove section repeats with a fresh distinct selection.
The two removed hard ruin chunks are absent from the runtime catalog.

Revised hard layouts add a Hashash in the ruins, Unoco and Grojib in the training
camp, and a warrior/Grojib rescue encounter in the woodcamp. The revised grove,
ruin and training-camp layouts include swinging-axe, poison-dart and spike traps.
Hard terrain, water gaps, footholds and scenery placements are updated together;
the menhir prefab now has solid collision. These changes affect replay outcomes
and ship with matching regenerated client and replay-worker content.

The hard ruin statue uses its native size and ground-aligned placement so ground
enemies can clear its first jump. Hard training-camp repairs restore the wider
entrance landing, move the statue 32 units right, remove the small entrance rock
that trapped Grojib against its neighbor, and restore the lower neighboring rock.
The other camp's anvil moves 16 units left to open the crate approach. The hard
woodcamp's entrance rock uses 60% scale with its base at ground level.

Hard grove chunk 002 gains a 96-unit foothold over its gap. Chunk 007's foothold
is widened to 96 units, raised 28 units and moved 32 units left so Derf lands on
its flat surface. These repairs preserve the existing enemy jump, speed and
collision limits. Exact incoming transitions remain traversal regressions
alongside the complete seeded Forest assembly.

Levels can use automatic difficulty progression or an authored sequence of
sections. A section chooses a chunk group, difficulty and length in chunks.
The author sets the section order; seeded selection chooses chunks inside it.
An optional first-chunk choice fixes the opening Chunk for every seed. It must
be valid for the first automatic pool or first authored section; the rest of
the run continues with seeded selection. When the opening section requires
unique Chunks, the fixed opener cannot repeat within that section occurrence.

For a gradual tour through several environments, compose:

| Order | Group | Difficulty | Chunks |
| --- | --- | --- | --- |
| 1 | Default | Early | 3 |
| 2–4 | Grove, Ruins, Camp, one section each | Easy | 3 each |
| 5–7 | Grove, Ruins, Camp, one section each | Normal | 3 each |
| 8–10 | Grove, Ruins, Camp, one section each | Hard | 3 each |

These names illustrate reusable chunk groups; authors populate their own groups.
Exact difficulty selects only matching active chunks. It never substitutes a
different difficulty when content is missing. With uniqueness enabled, every
chunk in that section occurrence is different, so a three-chunk section needs
at least three matching sources. A source may appear again in a later section.
The editor flags insufficient content and prevents Play and included Build,
while allowing the incomplete composition to be saved.

Equal minimum and maximum counts produce a fixed length. A range lets the seed
choose the length. Sections can be duplicated and reordered; duplication keeps
their settings and assigns a new section identity.

After the final section, the author chooses either to repeat the full composition
or to continue repeating the final section. Both keep the run going. Each
occurrence starts a fresh unique selection and retains its authored difficulty.
Neither option ends the level or changes its background.

Automatic sections follow the Level's global Early, Easy and Normal windows,
then Hard indefinitely, with normal missing-tier fallback. Explicit sections
override that selection without resetting global chunk indexes. The enemy-free
opening still suppresses enemies only for the first configured number of chunks;
terrain hazards remain active.

## Camera pacing by difficulty

The chunk containing the camera center sets the horizontal auto-scroll target.
The target uses the chunk's resolved difficulty after automatic-pool fallback
or an explicit section override:

| Difficulty | Baseline multiplier | Default target |
| --- | ---: | ---: |
| Early | 75% | 120 world units/second |
| Easy | 80% | 128 world units/second |
| Normal | 90% | 144 world units/second |
| Hard | 95% | 152 world units/second |

The default targets use 80% of the player's 200-world-unit-per-second normal
maximum speed, for a 160-world-unit-per-second camera baseline. This gives the
player more time to traverse each chunk. At an exact chunk seam, the entering
chunk owns the target. Existing acceleration smooths both increases and
decreases. Player pull-forward behavior can still move the camera target ahead
when the player crosses the follow threshold.


## Ground elevations and connecting chunks

Normal, Raised and High are ground elevations, separate from difficulty. The
Level's default height step is 24 px: Raised is 24 px and High is 48 px above
Normal. Level settings can choose 1–32 px per step. Interior terrain remains
freely authored; custom ground heights still connect when their full edges match.

Use Chunk Creator's Connections card to preview matching neighbors, show Ground
heights, or Create connecting chunk. The form fixes the entrance from the current
exit and makes a flat chunk at that exact height, including custom heights.
Group and difficulty keep their existing meaning. Creation opens an ordinary
chunk that can be reshaped afterward, undone and saved. Unsupported compound
profiles show manual authoring guidance.

The opening must support the player's Normal spawn. After it, seeded selection
uses matching edges with a valid continuation through all future sections. A
matching chunk can be excluded because of group, difficulty, uniqueness or a
later dead end. Every allowed section length must work. Flow shows readiness and
repair actions; the seed preview shows choices for each sampled position.
Changing height presets leaves existing terrain in place and identifies edges
that now have custom heights. Scheduling readiness proves connections, while
Play remains necessary to judge jumps, enemies, hazards and encounter difficulty.
