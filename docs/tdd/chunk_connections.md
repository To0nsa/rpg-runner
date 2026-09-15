# Chunk connections and elevation authoring

The editor, generator, normal Core, and authored Play share Core's exact terrain
connection schedule. It admits complete continuations before seeded selection.
Equal elevation labels alone never establish compatibility.

## Physical and scheduling authority

`buildTerrainChunkConnection` derives entrance and exit from compiled geometry.
Equality uses `TerrainBoundarySignature.physicalRecord`: collision-mode coverage
and surface-kind continuation points at exact 1/1024 px coordinates. Materials
remain visual evidence and do not change a physical connection. Open, compound,
and custom profiles remain valid scheduling inputs.

The opening additionally needs Normal entrance ground and a flat solid landing
across X=300 ±16 px with 64 px of unobstructed space above the Level ground.
Runtime uses the actual `TrackTuning.playerStartX`. The envelope covers both
current characters. An elevated or unsupported opening blocks admission even
when its entrance matches another chunk. Terrain coordinates are never shifted
to accommodate a spawn.

`TerrainConnectionSchedule` resolves group and difficulty fallback before
matching entrances. Explicit difficulty has no fallback. Graph states contain
the progression index (saturated at the Hard tail), section, remaining count,
previous chunk and distinct identities used in the current section. Boundary
nodes choose a section length; selection nodes choose a chunk. A greatest fixed
point removes a length node if **any** authored count fails, and a selection
node if **all** choices fail. Surviving cycles prove continuing tails, including
Repeat all and Continue last. Distinct identities reset at each section boundary.

Exact analysis stops at 32,768 states or 262,144 edges. The finite automatic
progression prefix remains limited to 256 chunks. Exceeding a budget blocks
Play/Build; no sampling or shortened lookahead substitutes for admission.
Canonical profile indexes and memoized resolved pools avoid repeated pair scans.

`ConnectedChunkPatternSource` binds this graph to the existing compiled catalog
and authored patterns. Normal `GameCore` creates the source before streaming and
uses it for both preparation and live selection. Whole-Level Play and seed
samples use the same factory. Focused Chunk Play uses a full-state witness from
a supported opening, through the selected chunk, into a proven repeating suffix.
An unused chunk can remain saved, but has no focused Play witness.

## Deterministic selection and evidence

Candidates are sorted by stable chunk key. Selection uses `mix32(seed ^
index*0x9e3779b9 ^ 0x85ebca6b)`. Section-length selection uses run sequence in
place of index and salt `0x27d4eb2d`; counts are ascending and none are removed.
The canonical `terrain-connections-v1` contract digest covers Level progression,
first chunk, section order/settings, active identities, tiers/groups, physical
profiles and spawn eligibility. Adjacency transition IDs carry that digest, so
the generated seam signature changes even when altered counts emit the same
chunk pairs. Geometry retains its existing separate source/edge signatures.

A cursor retains the current graph node, section occurrence and latest result.
Forward streaming advances once per chunk; repeated latest queries are cached.
Older queries restart and replay deterministically. New seeds and previews have
independent cursors. There is no unbounded history cache. Sampling reports the
exact available choices at that occurrence, before the hash selects one.

The pipeline retains structurally accepted chunks for source-owner diagnostics
when schedule admission fails. `validatedBatch` remains null on every blocker;
the root generator publishes nothing unless the entire operation succeeds.
Structural validation still covers excluded/deprecated source.

## Level schema and starter command

Level schema **v3** requires integer `terrainHeightStepPx` in 1..32, default 24.
Normal is `groundTopY`, Raised subtracts one step, High subtracts two. The field
is authoring data; generated runtime collision continues to come from polygons.
`tool/migrate_level_build_inclusion.dart --check/--apply` explicitly upgrades
canonical v1/v2 Level source, preserving identities, inclusion and coordinates.
Normal loaders accept only v3. Copy/create, serialization and Undo retain the
step. Changing it updates guides and future starters; existing polygons stay
fixed. Settings list the edges that become custom heights under the entered step.

`ChunkConnectionCreation` freezes a fresh key, predecessor geometry signature,
Level ground and step, exit elevation, group and difficulty. The domain command
rechecks current dependencies/settings, group membership, identity uniqueness,
source validity and the full compiled entrance. Failed attempts retain the form's
key; a collision with an existing owner cannot duplicate or overwrite it.

The initial starter supports one solid interval at a standard elevation. It
inherits solid depth, ground surface semantics and available terrain material,
uses the runtime chunk width, and creates ordinary independently editable source.
Flat or adjacent-height ramps have 64 px landings and at most a 1:1 slope.
Compound, open, custom, one-way or otherwise unrepresentable entrances report
manual authoring guidance. Full comparison remains the final check. Creation is
one existing session command/Undo step; cancellation performs no write, and Save
uses the normal canonical store transaction.

## Editor presentation

Connections is a collapsible existing-style card below the Chunk owner library.
It derives entrance/exit labels, Previous/Next terrain matches, a read-only joined
preview and exact profile details. Availability lists the valid Flow contexts;
excluded pairs explain the required group or resolved difficulty, an already-used
identity, or a future dead end. The Ground
heights toggle draws three canvas guides. Boundary inspection reveals its side.
Opening a neighbor offers a guarded return to the original Chunk and viewport.
View restoration retains the guide toggle, side and expansion state.

Create connecting chunk uses the existing naming, group and difficulty controls
in a dialog with a joined preview. Flow keeps its existing section controls and
adds full-schedule readiness, Inspect connection and Create connecting chunk
repair actions. Repair creation carries the affected section's group/difficulty
through guarded navigation and preserves the Level return context. Seed samples
show joined entrances and occurrence-specific choices. Structural errors block
Save; incomplete schedules block Play and included Build while remaining saveable.

## Compatibility release

This changes seeded gameplay and requires **2026.09.0** across app tickets,
Functions defaults/boards and the replay worker. The new worker rejects both
2026.03.0 and 2026.08.0 before replay. It must not replay old inputs with new Core.
No wire schema, score version, kill plane or camera mode changes accompany it.

Deploy as a drain-and-switch release: stop issuing old tickets, leave the old
worker serving its existing queue, wait for the 24-hour ticket lifetime plus
allowed clock skew, and use the existing compatibility-retirement audit to prove
no old sessions/leases/submissions or settlement work remain. Then publish the
matching worker/content and Functions defaults/boards before enabling new app
traffic. Remove stale `RUN_SUPPORTED_GAME_COMPAT_VERSIONS` overrides. Keep old
board/ghost artifacts under their original version. Roll back the matching
app/backend/worker/content set together. This repository change does not deploy.

## Evidence

The elevation fixture creates Normal → Raised → High → Raised → Normal with
an extra flat High chunk, verifies exact seams and Undo/Save/reload, and traverses
the loop for 1,800 ticks with each character at both the 24 px default and 32 px
maximum step. A jump at High stays inside the
locked 270 px viewport; replayed commands yield equal positions. A ten-chunk,
four-distinct selection fixture uses 482 states / 3,451 edges: approximately
5 ms analysis and 0.51 s for 200,000 choices on the development Windows host.
These are diagnostic measurements, not timing-dependent gameplay rules.
Existing water, marker, enemy, projectile and terrain publication checks remain
separate from schedule readiness; compatible terrain is not a promise that an
arbitrary authored encounter can be completed by a player.
