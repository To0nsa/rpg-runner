# Hardcoded traps with Chunk Creator placement

Status: Planned. No trap gameplay or editor implementation is complete.

Date: September 23, 2026.

## Outcome

Authors choose a hardcoded Spike, Swinging Axe, or Poison Darts trap in a new
**Traps** tab of Chunk Creator. They place its sprite and independently move and
resize one axis-aligned rectangular activation trigger. Core-owned damage
hitboxes and dart projectile collision remain separate. Save, Undo/Redo, Build,
Chunk Play, Level Play, normal runs, and replay validation consume the same
placement. Players and enemies can both activate traps and take their damage
and Poison status.

Core owns trap definitions, timing, activation, damage, and Poison rules. Chunk
source owns only placements and trigger geometry. The editor never authors trap
damage, cooldowns, projectile behavior, or animation timing.

## Current boundaries and chosen approach

| Boundary | Existing contract | Planned extension |
| --- | --- | --- |
| [Chunk source](../../../tools/editor/lib/src/chunks/chunk_v2_file_data.dart) | Strict v2 source stores prefabs, enemy markers, terrain, and optional water. | Add an optional `traps` list; absent means empty. Keep the current schema version, as with the optional water extension. |
| [Content pipeline](../../../packages/runner_content_pipeline/lib/src/chunk_runtime_materialization.dart) | Strict decoding and typed `ChunkPattern` materialization are shared by generation and Play. | Validate and compile trap placements into typed Core data. |
| [Core](../../../packages/runner_core/lib/track/chunk_pattern.dart) | The streamed pattern owns prefab visuals and enemy spawn markers. | Add a separate trap placement list and deterministic trap lifecycle. |
| [Editor scene](../../../tools/editor/lib/src/app/pages/chunkCreator/v2/chunk_scene_coordinator.dart) | Terrain, water, prefabs, markers, and layers have explicit input ownership. | Add a Traps domain with its own selection, gestures, and overlay. |
| [Renderer](../../../lib/game/runner_flame_game.dart) | Flame reads Core snapshots and uses render registries. | Render trap snapshots through a trap registry; Core decides every active and hit frame. |

Do not encode traps as terrain prefabs: prefab collision is solid physical
terrain, while the trap trigger is an overlap area. Do not encode them as
enemy markers: marker chance, enemy placement, and enemy AI have different
semantics. Extend the current chunk composition command and plugin transaction
path rather than adding a page-level write path.

## Reuse and code organization

Before implementing each boundary, inspect its current owner and record whether
the existing API can express the trap behavior. Extend an existing semantic API
when it fits. If a useful operation is trapped inside a water-, marker-, enemy-,
or projectile-specific module, extract the domain-neutral part to its owning
shared layer and migrate the original caller in the same change. Keep
feature-specific policy in the feature module. Do not copy a gesture, codec,
animation timer, collider, or damage path into a second implementation.

Specific reuse targets to check:

| Concern | Existing code to reuse or extract |
| --- | --- |
| Rectangle drawing, moving, resizing, snapping, and numeric edits | Chunk water authoring gestures and shared terrain rectangle controls; extract shared geometry/interaction helpers only where both water and traps use the same rule. |
| Selection, scene input, Undo/Redo, revision checks, Save, and Play | Chunk scene coordinator, composition operations/commits, domain plugin, and existing captured Play path. Extend their typed contracts instead of creating a separate trap document or writer. |
| Sheet extraction and fixed-tick visual selection | Existing render animation definition/loader and snapshot timing. Generalize explicit-frame support where needed for these nonuniform sheets; keep Core phase authority separate from Flame image loading. |
| Damage, status, invulnerability, hit ordering, and dart motion | Core damage queue/status system, shared hit resolver, projectile stores/systems, and projectile render registry. Add only trap-specific activation and spawn policy. |
| Validation and generation | Existing strict Chunk-v2 codec, shared content pipeline, generator, and source/build fingerprint flow. Keep one canonical trap contract and test editor/generator parity. |

Keep new Core code in a focused trap domain, editor authoring behavior in
bounded Chunk Creator modules, and Flame code in a trap render registry and
component. Avoid growing `GameCore`, `chunk_authoring_workspace.dart`, or
`runner_flame_game.dart` with feature internals; those files should coordinate
small collaborators. Refactors should serve a demonstrated second use and
retain existing behavior through relevant regression tests.

## Supplied art and timing evidence

The runtime PNGs have these dimensions: Spike 1920 × 256, Swinging Axe
2816 × 512, and Poison Darts 1536 × 1152 pixels. All are divisible into
candidate 128 × 128 cells, but sheet dimensions alone do not define animation
order or active frames. The Spike sheet has 27 occupied candidate cells and its
reference GIF has 27 frames with both 10 cs and 4 cs delays. The Axe sheet has
50 occupied candidate cells while its reference GIF has 74 frames with several
delay values; its visual poses cannot be assigned a uniform cadence by counting
cells.
The Poison Darts sheet contains launcher, dart, and impact art in distinct
regions, so it is not one launcher animation strip. The implementation must
record explicit source rectangles, sequence order, per-frame tick durations,
stable anchors, dart muzzle position, and frame-specific damage windows after
comparing PNG cells with the reference GIFs. Preserve the intended animation
pace when converting centiseconds to fixed ticks; document the rounding rule
and cumulative timing error. Do not infer gameplay hit timing from Flame's
elapsed frame time.

## Source and trigger contract

Each placement has a stable `trapId`, chunk-local whole-pixel sprite anchor
`x, y`, a bounded orientation where the trap needs one, and a `trigger`
rectangle with whole-pixel `offsetX, offsetY, width, height`. The offsets are
relative to the sprite anchor. Moving the trap moves its trigger with it;
dragging the rectangle changes only its offsets or dimensions. Each new
placement receives a hardcoded default rectangle that is then saved explicitly,
so later catalog-default changes cannot silently move old triggers.

Illustrative source shape, subject to final naming in the shared codec:

```json
{
  "traps": [
    {
      "trapId": "poison_darts",
      "x": 160,
      "y": 96,
      "facing": "left",
      "trigger": {"offsetX": -96, "offsetY": -12, "width": 88, "height": 48}
    }
  ]
}
```

The resolved rectangle must have positive width and height and fit inside its
owning chunk. The sprite anchor and full rendered footprint must also fit.
Offsets may be negative so authors can position the trigger anywhere around the
sprite within that chunk. Fail closed on unknown IDs, invalid orientation,
fractional or noncanonical values, out-of-bounds rectangles, and exact duplicate
placements. Specify one canonical ordering and use it in editor export, both
decoders, generation, and replay-sensitive runtime iteration. Trap source does
not change polygon terrain, seams, or navigation.

The complete Core-owned Spike/Axe damage sweep must also fit inside the owning
chunk; a fired dart may cross chunk seams. Facing mirrors the rendered sprite,
pivot, muzzle, and Core-owned damage geometry around the sprite anchor. The
authored trigger remains at its saved offset when facing changes, because its
rectangle is independently positioned; the editor shows both before commit.

The authored rectangle is an **activation trigger**, shown in the editor. Core
tests it against living player and enemy bodies after movement and the
spatial-grid rebuild. An idle trap may activate only while both its resting
sprite footprint and catalog-owned warning cue have positive overlap with
Core's fixed camera viewport for that tick.
Use Core camera bounds, never Flutter widget size or renderer visibility, so
editor Play, app runs, and validator replay agree. Partial viewport overlap
counts. This is a camera-framing rule, not an occlusion or line-of-sight test:
terrain and obstacles never block trap activation or damage, even when they
visually cover a trap. The trigger does not directly apply damage:

- **Spike:** eligible overlap by either actor kind starts the hardcoded
  warning/extension/retraction cycle. A separate Core-owned spike hitbox
  applies damage to overlapping players and enemies only while the spikes are
  exposed. Its placement follows the visible spike tips, not the transparent
  128 × 128 frame bounds.
- **Swinging Axe:** eligible trigger overlap starts its hardcoded swing. Core uses
  frame/phase-specific hitbox positions around the authored pivot so the
  damaging region follows the visible blade. Test the swept region between
  successive poses if a fast swing can cross the player between ticks.
- **Poison Darts:** eligible overlap by either actor kind starts the launcher
  warning and fire sequence. The launcher has no contact-damage hitbox. At the
  mapped fire frame/tick, Core creates a dart at the defined muzzle with its
  own projectile entity, velocity, collision shape, damage, Poison status, and
  despawn rules.
  The dart can hit a player or enemy only through authoritative projectile
  collision and an at-most-once hit. Like the other trap attacks, it passes
  through solid terrain and obstacles.

One trap has one activation state even when multiple actors enter together.
Resolve same-tick entries in stable entity-ID order if an activator identity is
needed. Spike and Axe evaluate all eligible overlapping actors during harmful
frames, with per-target rehit gating; the first actor hit must not shield other
actors. A nonpiercing dart hits the first eligible actor along its actual
movement sweep, then despawns; entity ID breaks equal-contact ties. Extend the
shared projectile hit resolver for that ordering, with regression coverage for
existing projectiles. Dead/dying entities cannot activate a trap or take a new
trap hit.

On the first visible tick, an already-overlapping living actor activates an
idle trap; an entry before visibility is not lost. Activation starts one
warning/attack/cooldown cycle. Other entries during that cycle do not queue a
second activation. A completed cycle rearms only after the trigger is empty of
all eligible actors and, for Poison Darts, its earlier dart has despawned; the
next overlap starts a new cycle. A sustained overlap never auto-repeats.
Visibility gates the start of a cycle; a started cycle completes on Core ticks
even if the camera later moves past it. An
already-fired dart remains independent of launcher visibility and lifecycle.

Reuse the existing projectile entity store, fixed-tick motion, capsule hit
resolver, damage queue, lifetime, snapshots, and Flame projectile registry for
the dart. Add a small trap-specific Core spawn path because
`ProjectileLaunchSystem` currently consumes caster ability intents and the
ordinary `ProjectileCatalog` describes equippable slot items. Give the dart a
distinct render/projectile ID without making it selectable in player loadouts.
Add an explicit environmental target policy to the shared hit filtering so
trap damage can reach player and enemies without changing ordinary combat
friendly-fire rules. Reuse the existing damageable target cache and stable
candidate order; audit all faction/filter call sites before choosing the
narrowest representation. Retain trap source identity for attribution, and
keep an already-fired dart alive after its launcher chunk is culled until its
own hit or lifetime ends. Use the existing straight-projectile motion, which
already ignores terrain. Improve the shared projectile hit path to compare
first contact along the previous-to-current-position sweep rather than picking
an overlapping target by entity ID alone. A newly spawned dart starts moving
and becomes eligible to hit on the next Core tick; that first sweep includes
actors overlapping its muzzle. Do not create a second dart movement or
hit-resolution system.

Keep the visual sprite bounds, editable trigger, and Core damage/projectile
hitboxes distinct in the model and editor overlay. The editor should preview
the current frame and read-only damaging hitbox at that frame so authors can
position the sprite and trigger without guessing where the actual hit lands.

The catalog fixes repeat policy, hit gating, damage, timing, and any facing or
mount restrictions per type. Both player and enemies can trigger and be hit by
all three trap types. Pause and death freeze trap timing with the rest of Core.
One sustained overlap must not deal accidental damage every tick; repeat hits
follow the catalog cooldown and each target's invulnerability rules. Choose
explicit stable trap identity from chunk selection/index plus canonical
placement ordinal for state and events. Current run scoring counts every enemy
death, regardless of attacker; preserve and test that rule for trap-killed
enemies unless scoring is deliberately changed in the same release. Traps are
indestructible environmental objects: no health, combat target, or player/enemy
AI target. Trap hits use no player or enemy source entity, so they cannot grant
attacker on-kill gear procs or retaliation against a fictional attacker.
For darts, normalize the projectile store's ownerless sentinel to a nullable
source before queuing damage; retain the trap placement identity separately
for hit/death feedback and diagnostics. Audit defensive proc targets and score
updates under that source policy.

Bound authoring to at most eight trap placements per chunk. At runtime, allow
at most one live dart per Poison Darts launcher; a launcher waits for its dart
to hit or expire before another activation. Reject over-budget source in the
shared codec and show the same diagnostic in Chunk Creator. Require at least
0.5 seconds of visible warning between activation and the first harmful tick;
hold a warning pose if the reference art's native timing is shorter. Render
that warning cue at the threat area above covering terrain/obstacles so a
hidden trap still gives the player a readable tell. The cue must be on screen
when the trap starts its warning. Validate authored trap combinations in
Chunk/Level Play with both characters at run speed, including spawn safety and
overlapping damage paths. A warning or dodge route must remain usable; terrain
may hide a trap but may not make the hit unavoidable.

## Poison contract

Introduce a distinct Poison damage/status identity for attribution, stacking,
and visuals. A dart hit applies one `poisonOnHit` profile containing both:

- Poison damage over time at a base **2.0 HP per second for 5 seconds**, below
  the current Fire `burnOnHit` base of 3.0 HP per second for 5 seconds.
- **25% movement slow for 5 seconds**, using the existing Slow status rules.

The damage-over-time application uses the existing fixed-point DoT preset with
`DamageType.poison`; the slow application reuses the current slow preset. Both
start on a successful projectile hit against a player or enemy and obey
existing status resistance, refresh/stronger-effect, cleanse, ward, and
tick-order contracts. Fire and
Poison occupy separate damage-type DoT channels. The comparison with Fire is
between base magnitudes; actual damage can differ with resistance and other
combat modifiers. The dart's direct impact uses a conservative hardcoded
**1.0 HP** base (`amount100: 100`) through the existing damage queue. It is
separate from and not counted as Poison DPS. A nonzero impact request allows
the existing on-hit status path to apply Poison and Slow; ordinary
invulnerability, defense, resistance, ward, refresh, and cleanse rules still
decide the outcome. The first Poison pulse and later pulses follow the existing
DoT period/tick ordering, without an immediate extra pulse. Show persistent
Poison and Slow feedback through the existing status UI/snapshot path, with
Poison distinguishable from Fire.

This replaces the earlier Acid-style Vulnerable proposal: Poison does **not**
apply Vulnerable. For this first release, Poison direct damage and DoT use the
existing Acid resistance value, avoiding a new gear stat while preserving a
distinct Poison damage identity. Make this explicit in Core and GDD. Append new
enum cases where enum order is observable, and update exhaustive consumers.

## Implementation checklist

### 1. Shared contract and assets

- [ ] Inventory relevant Core, Game, pipeline, and editor helpers before
  writing trap code. Record the chosen extension points and any bounded
  extraction in the implementation review; migrate the original caller with
  tests when a shared helper is extracted.
- [ ] Reconcile the candidate 128 × 128 sheet cells with the source GIFs;
  create reviewed per-trap frame maps, durations, stable pivots, muzzle
  coordinates, hitbox tracks, and fire ticks. Treat Poison launcher, flying
  dart, and impact as separate sequences. Keep tracked runtime PNGs under
  `assets/images/entities/traps/`; original packs remain in ignored
  `resources/traps/`.
- [ ] Add `TrapId`, hardcoded trap definitions, default trigger geometry,
  orientation rules, animation and warning timing, one-dart-per-launcher
  limit, and rendering metadata in Core without Flutter or Flame imports.
  Keep editor display labels in an editor projection of the Core IDs.
- [ ] Add optional `traps` to Chunk-v2 source, strict editor codec, shared
  content-pipeline decoder, canonical comparison/export, and generator
  materialization. Preserve existing trap-free chunk bytes on unrelated saves.
- [ ] Extend `ChunkPattern` and Play scenario copying/validation with typed
  placements. Regenerate Core output with the root generator; never hand-edit
  generated patterns.
- [ ] Test missing-list compatibility, exact round trips, invalid IDs and
  rectangles, complete Spike/Axe damage envelopes, the eight-trap limit,
  canonical order, duplicate rejection, and generator/Play parity.

### 2. Authoritative simulation and rendering

- [ ] Bind traps only after selected chunk terrain is admitted. Create and
  retire state with streamed chunk lifecycle, including prewarmed initial
  chunks, without double activation when selections refresh.
- [ ] Add a focused Core trap system/store for fixed-tick phase and cooldown
  state. Query living player/enemy targets after world motion and broadphase
  rebuild; resolve viewport-gated trigger activation and spike/axe
  frame-specific hitboxes separately, then queue all eligible target hits
  before damage processing. Add empty-trigger rearming, per-target rehit state,
  stable same-tick ordering, and environmental trap death attribution. Route
  hits through `DamageRequest` and status application.
- [ ] Give Poison Darts a separate launcher-to-projectile path: fire at the
  exact Core tick represented by the sheet, spawn at the muzzle, and use the
  existing projectile store, straight motion, hit resolver, hit-once, damage,
  status, snapshot, rendering, and expiry contracts. Add only a trap-specific
  spawning adapter; terrain does not stop trap darts. Extend shared hit
  filtering with an environmental policy admitting player and enemies while
  ordinary friendly-fire rules remain unchanged. Resolve first actor contact
  along the actual movement sweep, then entity-ID ties, in the shared
  nonpiercing projectile path. Convert ownerless darts to a null damage source
  while retaining trap attribution. Reject its ID from player loadout
  ownership/validation. Never make the trigger rectangle or launcher sprite
  the projectile collider.
- [ ] Add one Poison status profile with 2.0 DPS and 25% movement slow for
  5 seconds and 1.0 HP direct dart damage. Reuse the current DoT and Slow
  application/stacking paths, map Poison resistance to Acid resistance, and
  ensure the profile is applied exactly once per successful dart hit. Reuse
  current DoT pulse timing and add distinct persistent Poison feedback. Keep
  Acid's Vulnerable profile intact for Acid attacks.
- [ ] Publish stable trap identity, position, phase/frame, and orientation in
  immutable Core snapshots or events. Publish dart entities through the
  projectile snapshot path. Add Flame trap/projectile registry entries and
  asset loading/warmup. Draw warning cues above covering terrain. Flame must
  only display the Core frame, warning state, and projectile position.
- [ ] Cover trigger entry, sustained overlap, exit/re-entry, warning and active
  frame boundaries, first-visible-tick overlap, partial viewport visibility,
  offscreen activation suppression, spike/axe hitbox placement, fast axe
  sweeps, cooldown, invulnerability, dodge timing, lethal hit, dart muzzle
  spawn, next-tick travel, nearest actor and tie resolution, terrain pass-through,
  single hit, pause, death freeze, and chunk culling with deterministic Core
  tests. Cover Poison pulse timing, 1.0 HP direct hit, 2.0 DPS
  base versus Fire's 3.0 DPS, 25% movement reduction, resistance, simultaneous
  Fire/Poison channels, refresh, cleanse, and ward on player and enemies. Test
  enemy-triggered activation, simultaneous actors, multi-target Spike/Axe
  damage, enemy-hit darts, ordinary friendly-fire preservation, enemy death
  phases, indestructibility, no attacker on-kill proc, and trap-kill score
  counts. Add Game snapshot/render tests that compare displayed frames,
  warning cues, and hitbox/debug overlays with Core ticks.

### 3. Chunk Creator authoring

- [ ] Add the Traps tab and catalog previews alongside the existing Prefabs
  and Markers domains. Add trap selection, placement, drag, move, resize,
  numeric rectangle fields, orientation where applicable, and a clear overlay
  that distinguishes sprite, editable activation trigger, and read-only
  current-frame damage hitbox or dart muzzle/path. Reuse scene coordinate,
  snapping, and rectangle-handle patterns already used by water authoring.
- [ ] Route every accepted edit through the chunk plugin's revision-checked
  composition commit, Undo/Redo, Save, and pending-change guards. Keep pointer
  previews local until a valid commit; no writes in widget build methods.
- [ ] Use the shared codec/catalog to validate draft and saved rectangles.
  Show actionable diagnostics for unknown IDs, missing art, out-of-bounds
  trigger, sprite or damage sweep, the eight-trap limit, and invalid
  orientation. Preview facing changes without silently moving the trigger.
- [ ] Include trap PNGs in Build input fingerprints/watching and in captured
  Chunk/Level Play asset validation. Verify an edited unsaved chunk can be
  played through the existing captured-source path, then saved and built
  without mismatched runtime data.
- [ ] Test tab switching, scene selection, independent trigger movement and
  resizing, moving the sprite with its trigger, accurate damage/muzzle overlay
  across preview frames, revision conflict, Undo/Redo, Save/reload, Build, and
  Chunk/Level Play. Include water/marker/prefab regression coverage for any
  shared editor helper or command refactor.

### 4. Integration, documentation, and release

- [ ] Update the focused TDD for source ownership, lifecycle, ordering,
  snapshot/projectile contracts, and determinism. Add a GDD for trap tells,
  trigger behavior, damage, and timing; update combat/status/resistance GDD
  for Poison. Mark these initial safe defaults for playtest review and record
  the final tuned values when implemented and tested.
- [ ] Run `dart analyze` and relevant tests for Core and content pipeline,
  editor `dart analyze`/`flutter test`, root Flutter analysis and focused
  Core/Game/Play tests, generator `--dry-run`, and replay-validator analysis
  and tests. Validate client and worker replay the same trap-bearing run to
  the same outcome.
- [ ] Make a coordinated game-compatibility release across client,
  Functions/board defaults, authored content, and replay validator. No replay
  wire change is planned unless an actual payload changes. Stop issuing old
  tickets, cancel outstanding non-live runs that can be cancelled, and prove
  that no old submission/lease/settlement work remains. The existing
  [retirement gate](../../../functions/src/runs/compatibility_retirement.ts)
  also requires the ticket-lifetime interval; satisfy it or implement and
  test an explicit safe administrative invalidation before an immediate
  cutover. Never validate an old ticket with new trap rules.

## Completion criteria

- An author can place any of the three hardcoded traps and independently place
  and resize its visible rectangular activation trigger in Chunk Creator.
- Spike and Axe hitboxes line up with their harmful art frames. Poison Darts
  launches a separate moving projectile from its muzzle; the launcher and
  activation trigger never cause contact damage. All three trap attacks ignore
  solid terrain and obstacles.
- A trap starts only while its sprite and warning cue intersect Core's camera
  viewport; hidden traps still give an on-screen warning before their harmful
  phase.
- A successful dart hit applies 1.0 base direct HP damage, 2.0 base Poison DPS,
  and 25% movement slow for 5 seconds through the existing status pipeline to a
  player or enemy, with no Vulnerable effect.
- Player and enemies can each activate all three trap types and be damaged by
  them. Simultaneous targets and trap-killed enemies produce deterministic hit,
  death, and score results without changing ordinary friendly-fire behavior.
  Traps are indestructible, and trap kills do not grant attacker gear procs.
- The same saved chunk produces the same trap identities, phases, projectile
  outcomes, damage, and Poison status in editor Play, the app, and validator
  replay for the same seed and commands.
- Existing trap-free chunks continue to compile and play with unchanged
  behavior. No trap behavior is owned by Flame or editor widgets.
- Generated content and the active TDD/GDD describe the delivered rules, and
  all relevant validation gates pass before the compatibility switch.
- Existing water, marker, prefab, projectile, animation, and damage behavior
  still passes its relevant checks after shared-code extraction; no parallel
  trap-only copy of an equivalent subsystem remains.
