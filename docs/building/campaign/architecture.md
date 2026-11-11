# Campaign architecture proposal

Status: design reference for the implemented campaign platform. The
[current technical contract](../../tdd/campaign_runtime.md) and
[game behavior](../../gdd/campaign.md) supersede tentative choices below.
The [single checklist](implementation.md) records local evidence and remaining
production-layout/device acceptance; this document is not a second task ledger.

## Domain and ownership

| Concept | Proposed responsibility |
| --- | --- |
| Campaign chapter | Stable ID, location/map anchor, ordered mission IDs, introduction, chapter completion |
| Mission | Stable ID, presentation keys, route, objectives, rules, score policy, reward policy references, prerequisites |
| Route occurrence | Stable instance ID referencing one source chunk at an exact sequence position |
| Source chunk | Existing reusable geometry, scenery, and authored gameplay definitions |
| Mission attempt | Ticket/content binding, selected build, fixed-tick state, objective state, terminal outcome |
| Account campaign progress | Verified clears, mission/chapter reward entitlements, character availability, and versioned personal best records |

Chapter, mission, source-level, and source-chunk identities remain distinct.
The existing `forest` runner level and its persisted identity are not renamed or
repurposed. Campaign missions stay out of ordinary runner selection and board
catalogues. Display titles and route indexes are never persistence keys.

| Owner | Changes within its boundary |
| --- | --- |
| `runner_core` | Finite mission definitions and simulation, camera policy, entity lifetime, objectives, outcomes, score calculation |
| `runner_content_pipeline` | Explicit authored strings to validated typed mission/chunk data; no repository I/O |
| `run_protocol` | Mission ticket/replay/result payloads and strict codecs; no gameplay or database authority |
| `tool` | Source discovery, dependency capture, generation, fingerprints, navigation preparation |
| `tools/editor` | Source editing, semantic commands, validation presentation, save/history, authored play |
| `lib/game` | Snapshot rendering, input/controller bridge, camera presentation, visible-area culling |
| `lib/ui` | Navigation, localized presentation, run lifecycle, account projection, submission recovery |
| `functions/src` | Authenticated mission admission, prerequisites, trusted reward policy, canonical progress/settlement |
| Replay validator | Trusted content resolution, deterministic replay, completion/score verification, settlement handoff |

Keep `ui -> game -> core`. Campaign should reuse existing semantic services and
systems; the exact types are settled at M0 after inspecting their consumers.
Do not make Training Field's unrewarded factory the production mission entry.

## Fixed route and content identity

A route contains an exact finite list of occurrences. An occurrence references
the source owner and chunk key without transferring ownership. Sequence position
determines its world transform; its stable instance ID identifies gameplay state.
Reordering changes geometry/content revision but does not silently retarget
objectives to a different occurrence. Repeated references instantiate separate
enemies, pickups, encounters, and trigger state.

Resolve sources into immutable compiled data before play. Bind every attempt to
the mission revision and an effective content fingerprint covering its route,
referenced chunk/prefab/material dependencies, gameplay rules, and scoring policy.
The same trusted artifact is available to the app and validator. Editing a shared
chunk invalidates dependent mission artifacts even if mission JSON is unchanged.

There is no random selection, tier fallback, wrapping, or continuation beyond
the last occurrence. Validate each actual adjacent join. Source-level ownership
checks remain intact for runner content; campaign compilation adds an explicit
reference path rather than globally weakening those checks. Reuse existing world
units, supported chunk dimensions, and placement compilation for the first version.

## Bounded movement and terrain lifetime

Core owns a campaign camera policy that follows left and right, clamps to the
authored mission bounds, and handles routes narrower than the viewport. Automatic
scrolling and the runner's behind-camera death condition do not apply. Health,
hazards, and authored kill planes retain their normal authority.

Movement bounds must also be physical rules: camera clamping alone does not stop
the player or a dash/teleport leaving the world. Define consistent behavior for
players, enemies, summons, projectiles, and knockback at the boundaries. Falling
into authored pits remains possible. Arena locks must be explicit, temporary,
and released on their successful conclusion.

Retain authoritative mission state for the whole attempt. Terrain publication can
remain local only if it can revisit either direction and retain every area needed
by active actors, attacks, and in-progress navigation. An active actor must never
lose its supporting collision because it is off-screen. Publish required terrain
before simulation advances, preserving the existing preparation/freeze boundary.

M0 must settle the first implementation's residency policy with a short-route
prototype. Keeping the small mission's collision resident is an acceptable first
slice if measured startup/memory fit; rendering still culls invisible content.
If reversible terrain windows are required, document deterministic activation and
dormancy before introducing them. They must retain health, position, AI/action
state, cooldowns, status effects, trigger consumption, and pending encounter state,
with explicit elapsed-tick semantics. Do not combine entity reconstruction and a
new pause policy without replay evidence. Record a measured mission-size budget.

Audit all forward-camera assumptions, including `TrackStreamer`, track management,
terrain preparation/cache keys, encounter expiry, enemy/death cleanup, pickups,
traps, projectiles, boss framing, first-visibility behavior, audio, and indicators.
Frustum visibility may control rendering; it must not erase mission history or
become an unrecorded input to authoritative gameplay.

## Encounters and instance state

Give each placed gameplay element an identity scoped to the route occurrence and
source element. Activate a placement once under a Core-owned rule; viewing its
chunk again cannot create another instance. Defeated enemies stay defeated,
collected items stay collected, and rescued/failed encounters keep their result.
Living enemies retain their defined state when the player leaves and returns.

Required encounters and instructional resources use guaranteed placement. Disable
automatic runner spawn/item policies for missions unless explicitly admitted by
the mission rules. Mission one has no combat encounters: the user removes unwanted
ambient enemies, rescue groups, bosses, and combat spawn placements by editing the
copied chunks. Validate the resulting content; do not add a converter removal
option or a mission-specific runtime filter that hides retained encounters.
Keep source runner content intact. Source spawn probabilities, early-chunk enemy
suppression, and camera-edge spawns cannot
accidentally remove or relocate an objective target in later missions.
Reuse the seeded combat RNG, with deterministic initialization and activation
ordering; fixed layouts do not require removing crits or AI randomness.

Mission-defined enemies may pursue through appropriate adjoining areas. Restrict
an encounter only through explicit bounds/leash rules; do not fail a rescue merely
because the player walks left. Route occurrences with existing runner-only boss
or encounter behavior require adaptation or rejection before Play/Build.

## Objectives, completion, and attempt lifecycle

Start with typed objectives using existing gameplay events: reach an authored
region, defeat specified targets, or complete a specified rescue. Reference stable
instance IDs rather than source filenames, display text, or incidental ECS IDs.
Required and optional objectives are separate. Keep hints/prompt presentation
outside gameplay authority; introduce new command types only where an actual
gameplay interaction needs them.

Core tracks objective progress in snapshots and emits a single terminal outcome.
Success requires all mandatory objectives plus the authored exit condition.
Streaming the last chunk or reaching a distance threshold alone is insufficient.
At M0 specify within-tick ordering: resolve lethal/failure conditions before success
eligibility, and do not award success to a player who dies on the same tick.
Final stats freeze exactly once; repeated exit overlap cannot award twice.

Add a successful outcome across Core events, snapshots where needed, recorder,
replay/result codecs, validator, and results UI together. Preserve existing failure
reasons, death animation, abandonment, pause/background input cancellation, loading
recovery, and submission durability. Retry starts a fresh attempt with fresh
admission; Next Mission uses the newly eligible mission and a new ticket. Mid-run
save/resume and checkpoints are outside the first delivery.

## Run protocol and compatibility

Introduce an explicit campaign mode with no board requirement. Audit positive
ranked-mode checks: the current `requiresBoard` implementation treats every mode
other than Practice as ranked. Extend client/Functions/worker codecs and all mode
switches together, preserving existing serialized values and retained records.

Before implementation, specify campaign fields on requests, tickets, replay
headers, validation results, completion receipts, and canonical state. Cover
missing/null handling, bounds, unknown IDs, canonical ordering/digests, versions,
and old-record decoding. Preserve existing runner `levelId` semantics; settle the
campaign mission discriminator/compatibility representation in M0 before changing
any public payload. Do not temporarily send campaign runs as Practice.

The server resolves the mission and prerequisites, binds the current compatible
content/build to the ticket, and rejects locked missions or characters. The
validator resolves its own trusted artifact and simulates the recorded commands;
the client cannot supply a replacement route, completion flag, score, or reward.
Editor and Developer Practice mission play remain local and cannot grant account
progress. Existing web Developer Practice behavior remains isolated.

Follow the [cross-layer workflow](../../../.agent/workflows/change-cross-layer-contract.md).
Shared simulation/protocol/content changes require compatible app and worker
artifacts and the coordinated release assessment. This plan does not authorize
deployment. Retained run/profile data require explicit compatibility behavior;
do not assume a data reset.

## Scoring and canonical progression

Use a versioned mission scoring policy. Reuse eligible combat/rescue statistics
and add objective/completion or efficiency terms only where useful. Exclude
unbounded survival-time points. Revisited distance, already-consumed triggers,
and repeated rendering/spawning cannot increase score. If a time bonus is used,
derive it from simulation ticks, cap it, and avoid encouraging beginners to rush.
Personal bests are comparable only within a declared mission scoring/content
compatibility key. Preserve historic records when a revision breaks comparability.

Campaign XP has a declared trusted policy separate from personal-best score. The
user's first-chapter target is 224 cumulative XP on an intended fresh-account first
pass, reaching the start of level 3 under the unchanged account curve. Specify
the per-mission distribution and any collected-XP evidence before M3; do not
apply existing `floor(score / 200)` XP on top of a replacement campaign grant.
Use the same policy for local reward preview and verified settlement. Repeated
missions, skipped optional pickups, and failed attempts need explicit rules;
the introductory target must never reset or cap an existing account's XP.

Account progress records stable mission completion independently from best-score
versions. Successful verified completion unlocks the next mission; score is not
an introductory progression gate. A revision does not erase a clear or recreate
its first-clear reward entitlement. Chapter completion derives from its required
mission set, with explicit policy if that set later changes.

Extend the existing Functions settlement authority to atomically apply campaign
progress, gold/XP, skill/character grants, mission/chapter entitlements, and the
completion receipt using one canonical revision. Idempotency needs both run
identity and an account/mission first-clear entitlement: two different successful
tickets cannot both receive the first-clear bonus. Bind trusted reward-policy
identity at issuance; reward amounts
must never come from a client-authored completion report. Replays may receive only
the explicitly configured repeat reward.

Mission one grants Double Jump once, initially mapped to `eloise.double_jump`.
All four required clears grant the Willow character entitlement, retaining the
existing `bountyHunter` identity. Reuse canonical ability/inventory mutation logic
for typed rewards and add explicit character availability authority. Already-owned
skills and already-unlocked characters are no-ops for ownership, not a reason to
duplicate gold/XP or rebuild saved equipment. Character unlock prepares any missing
valid starter data without overwriting existing builds or changing active selection.
Initial provisioned Willow gear/abilities alone do not imply character availability.

The current game exposes both playable characters and fresh profiles already
contain Willow's starter branches. A visible lock alone is insufficient. Define
the canonical character entitlement, profile defaults/old-profile decoding, chapter
completion grant, and serialization/revision behavior together. Enforce availability
on character selection, saved-build restoration, all authenticated run modes,
restart, and Training Field. Catalogue or Admin browsing must not bypass the gate;
availability and ownership of individual items remain distinct. Developer Practice
may explicitly expose locked content only through its isolated local profile.

Plan compatibility for accounts already using Willow: preserve their builds,
gear, XP, and history while defining eligibility under the chapter gate and a
safe available-character selection when required. Resolve existing tickets under
the versioned admission/cutover contract; do not retroactively invent chapter
clears or erase account data. Any legacy exception must be explicit before release.
The character gate is a cross-mode behavior change and needs corresponding tests.

Reuse durable client submission and full canonical receipts. Treat local results
as presentation until verification settles prerequisites; a pending completion
cannot authorize the next mission. Support response loss, reconnect, duplicate
delivery, account changes/deletion, and deterministic reconciliation. Display
first-clear rewards from the entitlement state, not from a local best score.

Explicitly define eligibility for lifetime stats, achievements, Library discovery,
and other shared projections. Default to preserving existing ranked-only rules;
campaign never creates a ranked board result or unlocks Library locations merely
because their map artwork is reused. Proposed economy and eligibility decisions
are recorded in [Experience](experience.md).
