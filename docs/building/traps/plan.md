# Hardcoded traps with Chunk Creator placement

Status: In progress. Shared accepted-hit status eligibility and terminal DoT
pulses are implemented and validated. Trap gameplay and editor authoring are
not complete.

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
  applies **5.0 HP physical** base damage to overlapping players and enemies
  only while the spikes are exposed. Its placement follows the visible spike
  tips, not the transparent 128 × 128 frame bounds.
- **Swinging Axe:** eligible trigger overlap starts its hardcoded swing. Core uses
  frame/phase-specific hitbox positions around the authored pivot so the
  damaging region follows the visible blade and deals **8.0 HP physical** base
  damage. Test the swept region between successive poses if a fast swing can
  cross the player between ticks.
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
frames and queue at most one hit attempt per target per activation cycle,
including attempts canceled by invulnerability or defense middleware; the
first actor hit must not shield other actors. A nonpiercing dart hits the first
eligible actor along its actual movement sweep, then despawns; entity ID breaks
equal-contact ties. Extend the shared projectile hit resolver for that
ordering, with regression coverage for existing projectiles. Dead/dying
entities cannot activate a trap or take a new trap hit.

On the first visible tick, an already-overlapping living actor activates an
idle trap; an entry before visibility is not lost. Activation starts one
warning/attack/cooldown cycle. The catalog gives every trap at least 0.5
seconds of warning before its first harmful frame and a 1.0-second cooldown
after its attack animation. Other entries during that cycle do not queue a
second activation. A completed cycle rearms only after the trigger is empty of
all eligible actors and, for Poison Darts, its earlier dart has despawned; the
next overlap starts a new cycle. A sustained overlap never auto-repeats.

The camera gate remains active throughout the warning and harmful phases. If
either the sprite footprint or warning cue fully leaves Core's viewport before
the dart fires or the Spike/Axe harmful frame, cancel that cycle; require an
empty trigger before a fresh activation and full warning. If visibility is
lost during a Spike/Axe harmful phase, stop new hit attempts and enter cooldown
immediately. No launcher fires after it leaves view. A dart already fired is
independent of launcher visibility and chunk lifecycle. Keep the warning cue
visible through harmful frames, with a distinct active appearance: an actor
entering during an enemy-started attack may be hit immediately but sees the
active hazard. All visibility and cancellation decisions use Core ticks and
the same viewport rectangle as activation.

Reuse the existing projectile entity store, fixed-tick motion, capsule hit
resolver, damage queue, lifetime, snapshots, and Flame projectile registry for
the dart. Add a small trap-specific Core spawn path because
`ProjectileLaunchSystem` currently consumes caster ability intents and the
ordinary `ProjectileCatalog` describes equippable slot items. Give the dart a
distinct `ProjectileId` for the shared store and render registry, appended to
preserve existing enum ordinals. Keep its gameplay definition in the trap
catalog, not the player `ProjectileCatalog`. Add one explicit Core list of
player-equippable projectile spell IDs and use it for shop candidates,
ownership normalization, and loadout validation instead of treating every
`ProjectileId` as an item. The Functions store and ownership commands must
enforce their matching allowlist for purchase, learn, and equip; add a parity
test for both lists. Preserve all currently equippable spells, including
Thunder Bolt, which the current catalog and Functions store expose to players.
Exclude the unknown sentinel and trap dart; enemy use alone does not make a
projectile enemy-only. No existing spell ownership or loadout migration is
needed. The render preload may still iterate every renderable projectile ID.
Add an explicit environmental target policy to the shared hit filtering so
trap damage can reach player and enemies without changing ordinary combat
friendly-fire rules. Reuse the existing damageable target cache and stable
candidate order; audit all faction/filter call sites before choosing the
narrowest representation. Retain trap source identity for attribution, and
keep an already-fired dart alive after its launcher chunk is culled until its
own hit or lifetime ends. Use the existing straight-projectile motion, which
already ignores terrain. Improve the shared projectile hit path to compare
first contact along the previous-to-current-position sweep rather than picking
an overlapping target by entity ID alone. Store a `firstHitTick` or equivalent
eligibility field on the common projectile entity. A trap dart spawned on tick
`T` has `firstHitTick = T + 1`; ordinary projectiles retain their existing
launch-tick hit behavior. Existing Core order moves projectiles before launch
but resolves hits after launch, so the trap-specific guard is necessary. The
dart's first eligible sweep runs from its muzzle position to its first moved
position and includes actors overlapping the muzzle. Do not create a second
dart movement or hit-resolution system.

Keep the visual sprite bounds, editable trigger, and Core damage/projectile
hitboxes distinct in the model and editor overlay. The editor should preview
the current frame and read-only damaging hitbox at that frame so authors can
position the sprite and trigger without guessing where the actual hit lands.

Use fixed renderer layers rather than an authored z-index. In the existing
Flame priority scheme, idle trap machinery draws at `-6`, behind terrain at
`-5`; animated warning and harmful trap art draws at `-4`, above terrain but
behind actors; darts use the existing projectile priority `-1`. Name these
priorities beside the current render constants. Draw warning/active cues in a
dedicated world-space overlay pass after all world content, including authored
prefab sprites, water foreground, and actors, and before the screen-space HUD.
Use the same camera transform as the world. A numeric sibling priority such as
`3` cannot guarantee this ordering because authored prefab z-indices are not
bounded. Preserve those authored layers rather than clamping or migrating them.
Chunk Creator draws the same cues above its complete scene preview. Scenery may
cover trap machinery or attack art, but never the warning/active cue. Test a
covering prefab with a high positive z-index. Collision and camera visibility
use Core geometry regardless of draw order or terrain occlusion.

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
Define a small immutable `TrapSourceRef` containing the trap type and stable
runtime placement identity. Carry it independently of `sourceEntity` through
the damage queue, applied-damage record, and death feedback. Use a trap death
kind for direct Spike/Axe hits; dart impact retains projectile kind and its
trap source. For darts, normalize the projectile store's ownerless sentinel to
a nullable damage source. Defensive procs targeting an attacker receive no
target; ordinary mitigation and enemy-kill scoring still run.

Carry that same optional source from dart `DamageRequest` through the queued
on-hit `StatusRequest`, Poison DoT channel, and its pulse `DamageRequest`; a
later lethal Poison pulse can therefore identify the trap.
When a stronger Poison application replaces a channel, or an equal-strength
application extends its duration, the effective new application becomes the
recorded source. An ignored weaker or shorter application leaves the previous
source intact. Process same-tick applications in deterministic hit order, so
an equal-strength/equal-duration tie keeps the first source. A dart remains
valid after its launcher chunk is culled because its source is an immutable
value, not a pointer to active trap state. Extend LastDamage/DeathInfo and the
game-over presentation accordingly; generic non-trap DoTs retain null trap
source. Test two launchers refreshing the same Poison channel, death after
launcher culling, defensive proc targeting, and trap-kill score updates.

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
existing status immunity, refresh/stronger-effect, cleanse, ward, and tick
ordering. Fire and Poison occupy separate damage-type DoT channels. Fix the
shared DoT terminal-tick ordering: decrement the period and queue a due pulse
before removing a channel whose duration reaches zero on that tick. A new
five-second, one-second-period effect applied after tick `T` pulses at
`T + 60`, `T + 120`, `T + 180`, `T + 240`, and `T + 300` at the default 60 Hz.
Poison therefore deals **10.0 HP base total** over five pulses; the existing
Fire preset delivers **15.0 HP base total** over five pulses after the shared
fix. There is no immediate application pulse. This changes Fire behavior too,
so test both types and include the change in the coordinated compatibility
release. Refresh retains the existing period phase unless the current
stronger-effect rule replaces the channel; test the exact pulse ticks.

Acid resistance reduces Poison direct damage and each DoT pulse through the
existing damage resolver. The reused Slow preset is a separate status:
ordinary Acid resistance does not reduce its base 25% slow; status immunity,
invulnerability, cleanse, and the existing positive vulnerability scaling
still apply. The comparison with Fire is between base magnitudes; actual
damage can differ with resistance and other combat modifiers. The dart's
direct impact uses a conservative hardcoded **1.0 HP** base (`amount100: 100`)
through the existing damage queue. It is separate from Poison DPS.

Fix the shared accepted-hit status contract as part of this work. Currently,
`DamageSystem` queues on-hit statuses and grants post-hit invulnerability before
`StatusSystem.applyQueued` runs, so the player's default 15 post-hit ticks at
60 Hz suppress the statuses from the very hit that granted them. Capture
eligibility when damage processing accepts the hit, before granting its
post-hit invulnerability, and carry that accepted-hit origin in the queued
on-hit/on-crit status request. These requests retain their eligibility through
the existing queued-status phase; they still obey target-liveness, status
immunity, refresh, and cleanse rules. Hits blocked by pre-existing
invulnerability or canceled by defense middleware produce no on-hit status.
Standalone status requests retain the existing invulnerability check. Keep
post-hit invulnerability effective immediately against later damage requests;
do not move or remove it to make Poison work. Preserve the existing rule that
an accepted nonzero base-damage request may apply status even when resistance
reduces its actual damage to zero. Cover this shared behavior with ordinary
on-hit effects as well as Poison. Show persistent Poison and Slow feedback
through the existing status UI/snapshot path, with Poison distinguishable from
Fire.

This replaces the earlier Acid-style Vulnerable proposal: Poison does **not**
apply Vulnerable. For this first release, Poison direct damage and DoT use the
existing Acid resistance value, avoiding a new gear stat while preserving a
distinct Poison damage identity. Make this explicit in Core and GDD. Append new
enum cases where enum order is observable, and update exhaustive consumers.

## Regression and pre-release scope

The game is not live. Preserve existing player spells and use cancellation or
reset of disposable test runs for the compatibility cutover; historical-run
preservation, player-data migrations, and parallel old/new simulation support
are outside this feature's scope. Keep version checks so an old ticket is
never replayed under the new rules.

Three shared combat changes are intentional even in trap-free chunks: accepted
on-hit statuses survive their own hit's new invulnerability, periodic DoTs
receive their terminal due pulse, and nonpiercing projectiles use swept first
contact instead of lowest-ID overlap. Update the affected expectations and
document these changes; preserve unrelated behavior. Ordinary projectiles
retain launch-tick hit eligibility and existing friendly-fire rules.

Generator, Chunk Play, and Level Play must materialize the same trap placement
data from the same source. Focused Chunk Play deliberately changes the chunk
sequence and opening enemy suppression, so it is a placement/behavior harness,
not a replay-equivalence fixture for a normal run. Compare full outcomes only
with equivalent compiled level content, scheduler, opening suppression, seed,
character, loadout, tick rate, and command stream. Use such a Level Play fixture
for editor/app comparisons and a matching ticket/replay for app/validator
comparisons.

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
  orientation rules, 5.0 HP physical Spike and 8.0 HP physical Axe hits,
  one-hit-attempt-per-target-per-cycle gating, at least 0.5 seconds of warning,
  a 1.0-second post-attack cooldown, one-dart-per-launcher limit, and rendering
  metadata in Core without Flutter or Flame imports.
  Keep editor display labels in an editor projection of the Core IDs.
- [ ] Append the dart's `ProjectileId` for store/render identity, keep its
  gameplay definition outside `ProjectileCatalog`, and add an explicit Core
  player-equippable projectile list. Use that list for client shop offers,
  ownership normalization, and loadout validation. Enforce a matching
  Functions allowlist for offers, purchase, learn, and equip; parity-test the
  two lists. Preserve existing spells, including Thunder Bolt; reject the
  unknown sentinel and trap dart without migrating existing ownership.
- [ ] Add optional `traps` to Chunk-v2 source, strict editor codec, shared
  content-pipeline decoder, canonical comparison/export, and generator
  materialization. Preserve existing trap-free chunk bytes on unrelated saves.
- [ ] Extend `ChunkPattern` and Play scenario copying/validation with typed
  placements. Regenerate Core output with the root generator; never hand-edit
  generated patterns.
- [ ] Test missing-list compatibility, exact round trips, invalid IDs and
  rectangles, complete Spike/Axe damage envelopes, the eight-trap limit,
  canonical order, duplicate rejection, and generator/Play materialization
  parity.

### 2. Authoritative simulation and rendering

- [ ] Bind traps only after selected chunk terrain is admitted. Create and
  retire state with streamed chunk lifecycle, including prewarmed initial
  chunks, without double activation when selections refresh.
- [ ] Add a focused Core trap system/store for fixed-tick phase and cooldown
  state. Query living player/enemy targets after world motion and broadphase
  rebuild; resolve viewport-gated trigger activation and spike/axe
  frame-specific hitboxes separately, then queue all eligible target hits
  before damage processing. Check viewport visibility through warning and
  harmful phases; cancel an unfired/offscreen cycle or stop new Spike/Axe hits
  on visibility loss. Add empty-trigger rearming, one hit attempt per target
  per cycle, stable same-tick ordering, and environmental trap attribution.
  Route hits through `DamageRequest` and status application.
- [ ] Give Poison Darts a separate launcher-to-projectile path: fire at the
  exact Core tick represented by the sheet, spawn at the muzzle, and use the
  existing projectile store, straight motion, hit resolver, hit-once, damage,
  status, snapshot, rendering, and expiry contracts. Add only a trap-specific
  spawning adapter; terrain does not stop trap darts. Extend shared hit
  filtering with an environmental policy admitting player and enemies while
  ordinary friendly-fire rules remain unchanged. Resolve first actor contact
  along the actual movement sweep, then entity-ID ties, in the shared
  nonpiercing projectile path. Add `firstHitTick` to the common projectile
  store so a trap dart can hit only after moving on tick `T + 1` while ordinary
  projectiles keep their existing launch-tick hits. Convert ownerless darts
  to a null damage source while retaining trap attribution. Never make the
  trigger rectangle or launcher sprite the projectile collider.
- [ ] Add one Poison status profile with 2.0 DPS and 25% movement slow for
  5 seconds and 1.0 HP direct dart damage. Reuse the current DoT and Slow
  application/stacking paths, map Poison resistance to Acid resistance, and
  ensure the profile is applied exactly once per successful dart hit. Fix the
  shared DoT terminal-tick order so five one-second pulses occur in five
  seconds; test the changed Fire total too. Acid resistance mitigates direct
  and DoT damage, while the Slow status retains its existing immunity and
  vulnerability behavior. Add distinct persistent Poison feedback and keep
  Acid's Vulnerable profile intact for Acid attacks.
- [ ] Fix accepted-hit on-hit/on-crit status eligibility in the shared damage
  and status pipeline. Retain the existing queued-status phase and immediate
  post-hit damage protection. Test the player's default 15 post-hit ticks at
  60 Hz: an accepted 1.0 HP dart hit applies Poison and Slow once, a hit during
  pre-existing invulnerability applies neither, and standalone harmful status
  requests still respect invulnerability. Cover canceled hits, status immunity,
  fully resisted accepted hits, later same-tick damage, and ordinary on-hit
  effects; do not test only with post-hit invulnerability disabled.
- [ ] Extend damage, queued status, DoT channel, applied-damage, and death
  contracts with optional immutable `TrapSourceRef`. Preserve the effective
  application source on stronger replacement or equal-strength duration
  extension; retain the previous source on ignored applications. Cover
  trap-killed player feedback, multiple Poison launchers, and generic DoTs.
- [ ] Publish stable trap identity, position, phase/frame, and orientation in
  immutable Core snapshots or events. Publish dart entities through the
  projectile snapshot path. Add Flame trap/projectile registry entries and
  asset loading/warmup. Add named trap render priorities (`-6` idle, `-4`
  warning/active art) and use existing projectile priority `-1` for darts.
  Render warning/active cues in the separate world-space overlay pass after
  all world content and before the HUD. Preserve arbitrary authored prefab
  layers and test that high-z covering sprites cannot hide the cue. Flame must
  only display the Core frame, warning state, and projectile position.
- [ ] Cover trigger entry, sustained overlap, exit/re-entry, warning and active
  frame boundaries, first-visible-tick overlap, partial viewport visibility,
  cancellation when the cue or sprite leaves view, enemy-started attacks,
  late entrants seeing the active cue, spike/axe hitbox placement, fast axe
  sweeps, one 5.0/8.0 HP hit attempt per target per cycle, cooldown,
  invulnerability, dodge timing, lethal hit, dart muzzle spawn, no spawn-tick
  hit, next-tick travel, nearest actor and tie resolution, terrain
  pass-through, single hit, pause, death freeze, and chunk culling with
  deterministic Core tests. Cover Poison pulses exactly at 1/2/3/4/5 seconds,
  10.0 HP base total versus Fire's 15.0 HP base total, 1.0 HP direct hit, 25%
  movement reduction, Acid resistance on damage, Slow immunity, simultaneous
  Fire/Poison channels, refresh, cleanse, and ward on player and enemies. Test
  multiple launchers' Poison origin policy, ownerless damage, enemy-triggered
  activation, simultaneous actors, multi-target Spike/Axe damage, enemy-hit
  darts, ordinary projectile launch-tick preservation, friendly-fire
  preservation, enemy death phases, indestructibility, no attacker on-kill
  proc, and trap-kill score counts. Add Game snapshot/render tests that compare
  displayed frames, terrain occlusion, warning/active layers, and hitbox/debug
  overlays with Core ticks.

### 3. Chunk Creator authoring

- [ ] Add the Traps tab and catalog previews alongside the existing Prefabs
  and Markers domains. Add trap selection, placement, drag, move, resize,
  numeric rectangle fields, orientation where applicable, and a clear overlay
  that distinguishes sprite, editable activation trigger, and read-only
  current-frame damage hitbox or dart muzzle/path. Reuse scene coordinate,
  snapping, and rectangle-handle patterns already used by water authoring.
  Preview idle machinery behind terrain, active art above terrain, and the
  warning/active cue above obstacles and actors as in the game renderer.
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
  and draw layer across preview frames, revision conflict, Undo/Redo,
  Save/reload, Build, and Chunk/Level Play. Include water/marker/prefab
  regression coverage for any shared editor helper or command refactor.

### 4. Integration, documentation, and release

- [ ] Update the focused TDD for source ownership, lifecycle, ordering,
  snapshot/projectile contracts, and determinism. Add a GDD for trap tells,
  trigger behavior, damage, and timing; update combat/status/resistance GDD
  for Poison. Mark these initial safe defaults for playtest review and record
  the final tuned values when implemented and tested.
- [ ] Run `dart analyze` and relevant tests for Core and content pipeline,
  editor `dart analyze`/`flutter test`, root Flutter analysis and focused
  Core/Game/Play tests, generator `--dry-run`, backend build/tests, and
  replay-validator analysis and tests. Compile the validator server and run
  `benchmark --ticks=36000 --strict`. Verify generator/Chunk/Level Play
  materialization parity, then full Level Play/app parity with equivalent run
  configurations. Validate client and worker replay the same trap-bearing run
  to the same outcome. Check backend trap-dart purchase/learn/equip rejection,
  continued Thunder Bolt availability, and Dart/Functions allowlist parity.
- [ ] Make one pre-release game-compatibility cutover across client,
  Functions/board defaults, authored content, and replay validator. Stop old
  ticket issuance, cancel outstanding test runs, and let any already-running
  validation/settlement finish before resetting remaining disposable test
  state and switching versions. Use fresh test tickets and boards afterward;
  reject old-version tickets/replays. No replay wire change is planned unless
  an actual payload changes. No production migration, old-run preservation,
  or ticket-lifetime retirement wait is required for this non-live reset.

## Completion criteria

- An author can place any of the three hardcoded traps and independently place
  and resize its visible rectangular activation trigger in Chunk Creator.
- Spike and Axe hitboxes line up with their harmful art frames and attempt at
  most one 5.0/8.0 HP physical hit per target per activation. Poison Darts
  launches a separate moving projectile from its muzzle; the launcher and
  activation trigger never cause contact damage. All three trap attacks ignore
  solid terrain and obstacles.
- A trap starts and remains harmful only while its sprite and warning cue
  intersect Core's camera viewport. Losing visibility cancels an unfired
  attack or stops new Spike/Axe hits. Hidden idle art remains behind terrain;
  its warning and active danger cues stay above all authored scenery and
  actors regardless of prefab z-index, with at least 0.5 seconds of visible
  warning before harm. An already-fired dart persists.
- A successful dart hit applies 1.0 base direct HP damage, five 2.0 HP Poison
  pulses over 5 seconds, and 25% movement slow for 5 seconds through the
  existing status pipeline to a player or enemy, with no Vulnerable effect.
  The hit's own post-hit invulnerability does not suppress its Poison or Slow;
  pre-existing invulnerability and status immunity still apply.
  The shared Fire preset delivers five 3.0 HP pulses after the DoT fix.
- Trap darts are absent from shop offers, persistent player ownership, and
  loadouts; existing spells, including Thunder Bolt, remain available. Trap
  darts cannot hit on their spawn tick; ordinary projectiles retain their
  launch-tick hit eligibility. Direct and Poison deaths retain deterministic trap
  attribution, including after launcher culling and multiple Poison refreshes.
- Player and enemies can each activate all three trap types and be damaged by
  them. Simultaneous targets and trap-killed enemies produce deterministic hit,
  death, and score results without changing ordinary friendly-fire behavior.
  Traps are indestructible, and trap kills do not grant attacker gear procs.
- The same saved chunk materializes the same trap data in generation and both
  editor Play paths. Equivalent Level Play/app/validator run configurations
  produce the same runtime trap identities, phases, projectile outcomes,
  damage, and Poison status. Focused Chunk Play retains its separate scenario.
- Existing trap-free chunks continue to compile without source migration.
  Shared status-eligibility, terminal DoT pulse, and nonpiercing projectile
  contact changes have explicit regression expectations; unrelated behavior
  remains unchanged. No trap behavior is owned by Flame or editor widgets.
- Generated content and the active TDD/GDD describe the delivered rules, and
  all relevant validation gates pass before the compatibility switch.
- Existing water, marker, prefab, projectile, animation, and damage behavior
  passes its relevant checks with the intentional shared combat changes
  reflected in expectations; no parallel trap-only copy of an equivalent
  subsystem remains.
