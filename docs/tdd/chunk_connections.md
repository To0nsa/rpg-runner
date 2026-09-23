# Chunk Connection Scheduling And Authoring

## Status And Scope

Chunk connections are implemented as an exact, deterministic terrain-selection
contract. The editor, repository generator, normal `GameCore`, and authored Play
all use the same Core boundary-signature and scheduling code. A connection is
therefore more than two chunks having similar ground heights: the compiled exit
of the first chunk must equal the compiled entrance of the next, and the
resulting choice must still permit the level to continue indefinitely.

This document covers:

- how compiled polygon terrain becomes an entrance and exit profile;
- how Flow, difficulty, group, distinctness, and future continuations restrict
  the available successors;
- how a seed selects from the proven choices at runtime;
- how the editor inspects and creates connections; and
- which validation and compatibility rules protect generated content and
  replay determinism.

The connection system never moves or vertically aligns chunk geometry. Chunks
remain in their ordinary fixed-width track slots. Elevation names are editor
guides; compiled geometry is the authority.

## End-To-End Data Flow

```text
Chunk-v2 polygons + Prefab-v3 collision + Level-v3 Flow
                         |
                         v
              compile exact Core geometry
                         |
                         v
       derive left/right physical boundary profiles
                         |
                         v
    build complete finite-state connection schedule
       |                 |                    |
       v                 v                    v
 editor diagnostics   generator admission   GameCore / authored Play
 and joined preview   + seam signature       seeded streaming cursor
```

The repository generator and editor use
`packages/runner_content_pipeline` to decode and compile current-schema source.
The reusable connection authority itself remains in `runner_core`:

| Responsibility | Authority |
| --- | --- |
| Exact boundary evidence and comparisons | `TerrainBoundarySignature` in `terrain_boundary_signature.dart` |
| Entrance, exit, and valid-opening derivation | `buildTerrainChunkConnection` in `terrain_chunk_connections.dart` |
| Complete schedule construction and seeded selection | `TerrainConnectionSchedule` in `terrain_connection_schedule.dart` |
| Editor/generator reachability projection | `enumerateTerrainAuthoringReachability` in `terrain_authoring_scheduler.dart` |
| Runtime binding from authored patterns to compiled terrain | `ConnectedChunkPatternSource` in `connected_chunk_pattern_source.dart` |
| Source compilation, publication gating, and seam validation | `packages/runner_content_pipeline` |

No editor cache or generated adjacency list becomes gameplay authority. Normal
Core reconstructs the same schedule from the generated level definition,
authored chunk patterns, and admitted compiled terrain when it creates a
`ConnectedChunkPatternSource`.

## Physical Connection Contract

### Boundary profiles

For each compiled chunk, Core inspects the local left boundary at `x = 0` and
the right boundary at `x = chunkWidth`. Coordinates use deterministic physics
ticks, where one world pixel is 1,024 ticks.

The physical profile contains two kinds of facts:

- **coverage intervals**: merged positive-length vertical intervals occupied
  by a boundary edge, including its collision mode; and
- **continuation vertices**: points where a non-boundary terrain edge reaches
  the boundary, including collision mode, `surfaceKind`, and exact Y.

An exit connects to an entrance only when those physical records are equal.
This supports flat, raised, open, compound, one-way, and custom boundaries
without reducing them to one height label. For example, a solid continuation
and a one-way continuation at the same Y are different connections.

The full signature also retains exact boundary-edge records and material keys
for evidence. A material mismatch can be reported to an author, but material is
visual metadata and does not make physically equal boundaries incompatible.
The signature is derived after Prefab collision expansion and terrain
compilation, so placed Prefabs that reach a chunk edge participate in the same
comparison as direct Chunk polygons.

### Opening eligibility

The first streamed chunk has an extra `canStart` requirement. At the Level's
Normal `groundTopY`, the compiled chunk must provide:

- solid entrance coverage beginning at the Normal ground line;
- a flat upward-facing solid edge supporting the interval from
  `playerStartX - 16` through `playerStartX + 16`; and
- 64 px of unobstructed space above that landing.

Normal runtime and authored Play supply the actual
`TrackTuning.playerStartX`. Repository generation and editor analysis currently
use 300 px, matching the shipped Level tuning; these values must remain aligned
if start-position tuning becomes authored. The 32-by-64 px envelope covers both
current characters. A configured `firstChunkKey` must also belong to the
resolved first pool and satisfy this opening rule. Unsupported or elevated
openings are rejected rather than translated into place.

Filtered Chunk Play is an isolated tooling exception for horizontal
spawn placement. It tries the configured X first, then nearby half-pixel X
positions within the opening chunk. Each candidate still needs the same flat
solid support and clear 32-by-64 px spawn envelope at the Level's normal ground
height; the entrance must still begin at that height. The selected X is frozen
into the playtest scenario and used by Core on every restart. Normal runs,
whole-Level Play, and repository generation retain the configured X rule.

## Complete Schedule Admission

`TerrainConnectionSchedule` builds an immutable graph before any seed is used.
Its state records:

- the saturated global progression phase;
- the current Flow section;
- the number of chunks remaining in that section occurrence;
- the previously selected chunk; and
- the chunk identities already used when that section requires distinct
  chunks.

For each selection state, candidate resolution happens in this order:

1. Keep only active chunks owned by the target Level; sort them by stable
   `chunkKey`.
2. Apply the current Flow group, if the Level has a Flow.
3. Resolve difficulty. An explicit section difficulty requires that exact
   tier; a section without one, or a Level without Flow, follows global
   early/easy/normal/hard progression and Core's existing tier fallback.
4. At index zero, apply `firstChunkKey` when present and require `canStart`.
5. Otherwise require the previous exit profile to equal the candidate entrance
   profile.
6. Reject an identity already used in the current distinct section.
7. Retain only choices whose target state has a proven future continuation.

Group and difficulty belong to the slot being filled, not to the preceding
chunk. When Flow advances to another section, its new group and difficulty
apply. If an otherwise eligible current-section chunk has no physical route
into that next pool, the graph removes that earlier choice before the seed can
select it; it never skips the required section or fabricates a terrain match.

Flow section lengths are also graph choices. Counts are represented in
ascending order from `minChunkCount` through `maxChunkCount`; none may be
discarded merely because a particular count dead-ends. At a section boundary,
the distinct-identity set resets. `loopSegments: true` returns to the first
section after the last. `loopSegments: false` repeats the final section.

After graph construction, a greatest-fixed-point pass removes dead states:

- a section-length node is viable only when **every** authored count remains
  viable, because any count can be selected by the seed; and
- a chunk-selection node is viable when **at least one** candidate remains
  viable.

The saturated Hard phase and the finite Flow state make the indefinitely
repeating tail representable as cycles in a finite graph. Surviving cycles are
the proof that streaming can continue forever; a finite look-ahead or sampled
set of seeds is not accepted as a substitute.

Exact analysis fails closed at 32,768 states or 262,144 transitions. The finite
automatic progression prefix is limited to 256 chunks. Exceeding a limit is a
content-readiness error, not a reason to shorten the analysis.

## Deterministic Runtime Selection

The admitted graph is seed-independent. Each run or preview creates a fresh
`TerrainConnectionCursor`; the cursor chooses only among viable graph edges.

Chunk candidates are already ordered by stable key. For chunk index `i`, the
choice hash is:

```text
mix32(seed ^ (i * 0x9e3779b9) ^ 0x85ebca6b)
```

For Flow occurrence number `r`, section length uses:

```text
mix32(seed ^ (r * 0x9e3779b9) ^ 0x27d4eb2d)
```

The modulo of each hash selects from the ordered edges. Seed samples expose the
complete `availableChunkKeys` list for that exact occurrence before identifying
the selected chunk.

The cursor retains only its current state, section occurrence, and latest
selection. Forward streaming advances once per chunk. Repeating the latest
query returns the cached result; querying an older index resets and replays the
same deterministic choices. Different runs and previews do not share cursor
state.

`ConnectedChunkPatternSource` is installed before normal track prewarming, so
the initial chunks and later streamed chunks use one cursor and one contract.
Whole-Level Play builds the same source. The Core focused-scenario factory can
ask the schedule for a witness consisting of a supported opening, a path through
the selected chunk, and a proven repeating suffix. Chunk Creator Play instead
uses the exact filtered pool, including when only one owner matches; a lone
owner must have a compatible exit-to-entrance seam to repeat itself.

## Generation And Failure Semantics

Repository generation validates every current-schema Chunk and its individual
geometry, including chunks in excluded Levels. Runtime scheduling contains only
active chunks in Levels with `includeInBuild: true`; deprecated chunks cannot
satisfy a pool or enter the published runtime batch.

For included content, generation performs these fail-closed stages:

1. Decode and compile all source owners.
2. Check global identity uniqueness and individual compiled geometry.
3. Derive every active chunk's connection profiles.
4. Build the complete schedules and enumerate their reachable directed pairs.
5. Compare every reachable exit/entrance seam again against compiled geometry.
6. Publish a `validatedBatch` only when every stage succeeds.

Structurally compiled chunks remain in the result for owner diagnostics when
schedule admission fails, but `validatedBatch` is null and the root generator
publishes nothing.

The editor applies the same distinction:

| Condition | Save | Play | Included Build |
| --- | --- | --- | --- |
| Malformed source, invalid geometry, or invalid identity/configuration | Blocked | Blocked | Blocked |
| No complete schedule or a reachable seam mismatch | Allowed so the work can be repaired incrementally | Blocked | Blocked |
| Active chunk has no reachable occurrence | Allowed with a warning | Focused Play for that chunk is blocked | Allowed when the Level schedule itself is complete |
| Level is excluded from the build | Still structurally validated | Uses authored readiness when requested | Its schedule and chunks are omitted from publication |

Water regions, markers, enemy placement, projectiles, and terrain publication
have their own validation. A compatible terrain connection proves structural
continuation; it does not promise that an arbitrary authored encounter is
player-completable.

## Elevation Guides And Connecting-Chunk Creation

Level schema v3 requires integer `terrainHeightStepPx` in the range 1–32; the
default and migration value is 24. With positive Y pointing downward, the
editor guides are:

| Guide | Y coordinate |
| --- | --- |
| Normal | `groundTopY` |
| Raised | `groundTopY - terrainHeightStepPx` |
| High | `groundTopY - 2 * terrainHeightStepPx` |

These values drive guides and starter creation only. Existing polygon vertices
do not move when the step changes, and generated collision continues to come
from compiled polygons. Normal loaders accept Level-v3 only;
`tool/migrate_level_build_inclusion.dart --check` and `--apply` are the explicit
v1/v2 migration path.

The editor's **Create connecting chunk** command supports one solid boundary
interval on the authored half-pixel grid. Its top may be a custom height: the
successor is flat at the predecessor's exact exit Y (for example, Y 162),
without changing the Level elevation step. The creator does not offer an
alternate exit height; authors can reshape the new chunk afterward. The
command freezes the new key, predecessor geometry signature, Level ground and
step, group, and difficulty. On apply it rechecks those dependencies, source
validity, group membership, identity uniqueness, and the final compiled
entrance.

The resulting Chunk-v2 owner:

- inherits the predecessor's solid depth, terrain material, and surface kind;
- preserves the runtime chunk width;
- has a flat top with both its entrance and exit at the predecessor's exact
  exit Y; and
- is an ordinary independently editable source owner.

Compound, open, one-way, or otherwise unrepresentable entrances return
manual-authoring guidance. A custom *height* alone is not a reason to reject a
single solid interval. The command never approximates a compound profile by
its top height. A full compiled boundary comparison is the final acceptance
check.
Creation is one normal session command and one Undo step; cancellation writes
nothing, and Save uses the standard canonical workspace transaction.

The Chunk workspace's Connections card shows entrance/exit labels,
Previous/Next matches, joined previews, exact profiles, Flow availability, and
Normal/Raised/High guides. Flow diagnostics can navigate to the affected
connection or carry the section's group and difficulty into connecting-chunk
creation. Return navigation preserves the inspected side, guide visibility,
expansion state, and viewport.

## Signatures And Compatibility

The canonical `terrain-connections-v1` digest commits to:

- selection-contract version and Level identity;
- global progression counts and optional `firstChunkKey`;
- Flow order, loop mode, group, exact difficulty, count range, and distinctness;
- active chunk identity, difficulty, and group; and
- every chunk's entrance, exit, and opening eligibility.

Reachable transition IDs contain this digest. The generated seam signature
therefore changes when scheduling rules change even if the resulting set of
chunk pairs happens to remain the same. Geometry source and edge signatures
remain separate evidence.

Connection-aware selection was released as game compatibility **2026.09.0**
across app tickets, Functions defaults and boards, and the replay worker. It did
not require a replay wire-schema, score-version, kill-plane, or camera-mode
change. The corresponding worker accepted 2026.09.0 and rejected older
2026.03.0 and 2026.08.0 runs rather than replaying old inputs through the new
selector. The later camera-grace outcome change advances the current coordinated
Core release to 2026.09.1 without changing this selector contract. Difficulty-
paced camera targets use the selector's resolved tier, including fallback and
explicit sections, and advance the coordinated Core release to 2026.09.2. They
do not change selector ordering, eligibility, salts, or the connection digest.

Any future change to profile equality, pool resolution, graph viability,
candidate ordering, or selection salts is replay-sensitive and requires a new
coordinated game-compatibility release. Rollout must use the existing
drain-and-switch process: stop issuing the old version, keep its worker for the
existing queue, wait for the 24-hour ticket lifetime plus allowed clock skew,
prove that no old sessions, leases, submissions, or settlement work remain,
then switch matching app, backend defaults/boards, content, and worker builds.
Board and ghost artifacts remain under their original compatibility version.

## Verification Evidence

The main executable specifications are:

- [`terrain_boundary_signature_test.dart`](../../packages/runner_core/test/collision/terrain/terrain_boundary_signature_test.dart) for exact physical profiles and material-only differences;
- [`terrain_connection_schedule_test.dart`](../../packages/runner_core/test/collision/terrain/terrain_connection_schedule_test.dart) for future-dead-end pruning across different Flow groups and difficulties, all-length admission, distinctness, deterministic query order, digest changes, and capacity failure;
- [`polygon_terrain_repository_generation_test.dart`](../../packages/runner_content_pipeline/test/polygon_terrain_repository_generation_test.dart) for fail-closed generation, excluded-Level behavior, deprecated chunks, and validated seam publication;
- [`chunk_connection_creation_test.dart`](../../tools/editor/test/chunk_connection_creation_test.dart) for exact flat custom-height continuation, Undo/Save/reload, both current characters, and 24 px and 32 px steps; and
- authored Level/Chunk Play tests under
  [`packages/runner_core/test/playtest`](../../packages/runner_core/test/playtest)
  for runtime-source parity and focused repeating witnesses.

Performance output from the long-stream scheduler test is diagnostic only.
Correctness is governed by deterministic results and the explicit graph
capacity limits, never by a wall-clock threshold.
