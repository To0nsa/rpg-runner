# Campaign runtime foundations

Status: initial Core primitives only, November 11, 2026. No playable campaign
session, authored mission schema, menu or account progression is admitted yet.
The remaining integration is tracked in the
[campaign implementation plan](../building/campaign/implementation.md).

## Exact finite selection

[`FiniteChunkPatternSource`](../../packages/runner_core/lib/track/finite_chunk_pattern_source.dart)
captures a nonempty ordered list of occurrences. Each has a unique route-local
ID, source-level identity, chunk pattern and difficulty. A repeated source chunk
uses a different occurrence ID. Pattern collections are detached and immutable;
editing the source lists afterward cannot change the captured route. Selection
uses the requested index exactly, ignores seed/global difficulty for layout
choice and rejects indexes outside the route. There is no continuation or loop.

This is a scheduler contract, not playable-content admission. The future mission
compiler must check source ownership, matching compiled terrain, actual adjacent
seams, spawn support, required objectives and supported gameplay placements.
It must also enforce the measured resident-world content budget. No existing
runner pool or registered level has changed.

## Resident track lifetime

[`TrackStreamer`](../../packages/runner_core/lib/track/track_streamer.dart) recognizes
the finite source and selects the entire route on its first enabled step. Chunk
origins remain `index * chunkWidth`; existing terrain instance lineage remains
index-based. Active selections and newly spawned chunk batches also carry the
authored `occurrenceId` for future objective binding. Procedural selections leave
that field null.

Finite selections never cull on camera movement. Each occurrence emits its
initial spawn requests once. Future-selection projection exposes at most the one
initial resident state; it never emits spawns or consumes runtime state. No
selection is requested past the final occurrence, even if the camera moves far
outside the route. Disabled streaming remains a no-op.

Finite construction rejects opening enemy suppression. Marker probabilities
retain their existing deterministic seed/index/salt rolls; source content is not
stripped. Hashash uses the authored marker X and placement intent, instead of the
runner's deferred camera-edge placement. Encounter, boss, trap and visual metadata
are preserved. These facts do not establish that every such placement is ready
for a campaign session: mission admission and encounter-lifetime integration are
still required. Reporting for Duty's encounter-free layout remains author-owned.

Track residency alone does not preserve the ECS world. The future campaign host
must still address enemy/item culling, encounter expiry, active AI and attack
lifetimes, terrain publication, physical bounds, completion and replay outcomes.
The ordinary runner retains its forward streaming and cleanup policy.

## Bidirectional camera policy

[`FiniteFollowCamera`](../../packages/runner_core/lib/camera/finite_follow_camera.dart)
follows the player body center horizontally using fixed-tick exponential
smoothing, with no automatic scroll. Its center/target stay inside the horizontal
world framing. Worlds narrower than or equal to the viewport remain centered.
Y stays at the authored framing. A missing player freezes the current position
and clears camera speed; `speedX` otherwise records signed camera motion.

Construction rejects invalid/nonfinite bounds, dimensions and follow rate;
updates reject invalid tick durations and player coordinates before mutating
state. The duration must come from Core's fixed tick, not render time. This
camera does not constrain player movement and is not wired into `GameCore` yet.
The runner's `AutoscrollCamera` remains unchanged.

## Compatibility and validation limits

No run mode, command, ticket, terminal event, replay payload, reward or generated
content changes in this foundation. Existing registered runs do not construct
the finite source or follow camera. Campaign admission will require a later
coherent client/issuer/worker compatibility change.

Portable tests cover immutable exact selection, repeated occurrences, finite
termination, pure projections, retained selections and one-time spawn requests.
Camera tests cover both directions, stationary/missing players, narrow worlds,
deterministic inputs and 30/60/90 Hz ticks. These are component tests, not proof
of continuous player/enemy traversal, complete mission persistence, mobile
performance or editor usability. Evidence is recorded in the linked plan.
