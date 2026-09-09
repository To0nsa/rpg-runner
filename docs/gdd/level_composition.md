# Level composition

Levels can use automatic difficulty progression or an authored sequence of
sections. A section chooses a chunk group, difficulty and length in chunks.
The author sets the section order; seeded selection chooses chunks inside it.

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
