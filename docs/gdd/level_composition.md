# Level composition

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
| Early | 75% | 150 world units/second |
| Easy | 80% | 160 world units/second |
| Normal | 90% | 180 world units/second |
| Hard | 95% | 190 world units/second |

The default targets use the 200-world-unit-per-second baseline derived from the
player's normal maximum speed. At an exact chunk seam, the entering chunk owns
the target. Existing acceleration smooths both increases and decreases; player
pull-forward behavior can still move the camera target ahead when the player
crosses the follow threshold.


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
