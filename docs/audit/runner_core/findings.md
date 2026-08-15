# Runner Core findings register

This register distinguishes a demonstrated defect from incomplete content,
design debt, and a risk that still needs a reproducer. Severity describes impact
and migration priority, not the number of affected lines.

## Summary

| ID | Severity | Type | Finding | Primary consequence |
| --- | --- | --- | --- | --- |
| RC-H01 | High | Correctness | Recycled integer entity IDs allow stale-reference aliasing and invalid recycling | Wrong owner, target, attribution, or component following |
| RC-H02 | High | Authoring blocker | Enemy identity is used as behavior policy | A catalog-created enemy is not executable by generic systems |
| RC-H03 | High | Determinism/architecture | Gameplay catalogs are not one validated, versioned content unit | Client and validator can replay against different facts |
| RC-M01 | Medium | Boundary defect | Public mutable `GameCore` state bypasses the stated command boundary | Accidental replay divergence and hard-to-audit external influence |
| RC-M02 | Medium | Validation | Content admission relies on debug-only assertions | Invalid generated content can escape editor/generator validation |
| RC-M03 | Medium | Gameplay defect | Reactive-proc cooldowns are raw 60 Hz ticks | Cooldown duration changes when `tickHz != 60` |
| RC-M04 | Medium | Protocol debt | Kill counts depend on `EnemyId.index` | Enum reordering/addition becomes a wire-contract hazard |
| RC-M05 | Medium | Maintainability | `GameCore` owns construction, orchestration, policy, state, and test seams | Changes have a large review and regression surface |
| RC-M06 | Medium | Incomplete/content debt | Generic player derivation is Eloise-specific; `eloiseWip` is an alias | Editor-created characters cannot select independent traversal policy |
| RC-M07 | Medium | Authoring blocker | Entity facts are duplicated across Core, Flame, UI, validator, and backend | Creation requires coordinated hand edits and can drift |
| RC-M08 | Medium | Content debt | Ability injection and special-case ability IDs are inconsistent | A versioned content bundle cannot fully control gameplay yet |
| RC-L01 | Low | Repository hygiene | Persistent `.bak` files are tracked beside production Dart | Searches and authoring inventory include stale source copies |
| RC-L02 | Low | Documentation | Several public comments/readmes no longer match implementation | Audits and editor design start from false contracts |
| RC-R01 | Risk | Determinism evidence | Cross-platform replay parity is not demonstrated by the inspected suite | Float-sensitive paths may differ across client/validator platforms |

## RC-H01: entity identity can alias after recycling

**Evidence.** [`EntityId`](../../../packages/runner_core/lib/ecs/entity_id.dart)
is an `int`. [`EcsWorld.createEntity`](../../../packages/runner_core/lib/ecs/world.dart#L387)
returns a LIFO recycled integer, and
[`destroyEntity`](../../../packages/runner_core/lib/ecs/world.dart#L402) only
checks whether the integer is already in the free set. There is no active-ID
registry or generation.

Two failure modes follow from the implementation:

1. Destroy actor A while a projectile or hitbox still stores A as `owner`.
   Create actor B, which reuses A's integer. The old reference now identifies B.
   [`ProjectileHitSystem`](../../../packages/runner_core/lib/ecs/systems/projectile_hit_system.dart#L92)
   only detaches the owner when that integer lacks a faction. A newly reused
   actor normally has a faction, so the stale reference is accepted.
2. Call `destroyEntity(100)` before 100 was allocated. The method adds 100 to
   the free pool; the next creation returns 100 while `_nextEntityId` can still
   eventually allocate 100 again.

This can suppress a hit against the wrong entity, attach a hitbox to a new
transform, or attribute damage/procs/kills to an unrelated entity. Existing
recycling tests cover normal reuse, not stale owners or never-allocated IDs.

**Recommendation.** Add an explicit live-identity contract. The robust model is
an entity slot plus generation for every persisted reference. A smaller interim
option is monotonic IDs for one run, but it should only be selected after a
long-run allocation/memory benchmark because sparse stores grow with the
highest ID. In either model, reject or safely ignore IDs that were never live.

**Complete when:** stale-owner and invalid-destroy tests fail on the old model,
pass on the new one, and all owner/source/target stores use a reference form
whose liveness can be checked.

## RC-H02: concrete enemy IDs encode runtime behavior

**Evidence.** [`EntityFactory.createEnemy`](../../../packages/runner_core/lib/ecs/entity_factory.dart#L142)
adds flying, ground-navigation, and teleport components by comparing concrete
IDs. [`TerrainRuntimeBundle`](../../../packages/runner_core/lib/navigation/terrain_runtime_bundle.dart#L40)
requires Grojib and Hashash profiles and publishes named getters for their
graphs. [`TerrainEnemyNavigationSystem`](../../../packages/runner_core/lib/ecs/systems/terrain_enemy_navigation_system.dart#L94),
[`WorldMotionAuthority`](../../../packages/runner_core/lib/ecs/systems/world_motion_authority.dart#L247),
[`TrackStreamer`](../../../packages/runner_core/lib/track/track_streamer.dart#L347),
and [`GameCore`](../../../packages/runner_core/lib/game_core.dart#L289) also
branch on concrete enemy IDs.

**Consequence.** Generating a new enum and `EnemyCatalog` entry is insufficient.
The new enemy may lack motion components, a navigation graph, spawn placement,
or special behavior. An editor that says “created” would be misleading.

**Recommendation.** Introduce closed, reusable behavior capabilities such as:

- locomotion policy: ground surface navigation, flying steering, stationary;
- combat policy: chase/melee, ranged caster, teleport ambush;
- spawn placement policy: terrain support, air lane, deferred edge;
- navigation graph profile and score class;
- optional bespoke policy key for behavior that genuinely remains code.

Systems should switch on those closed policies/capabilities, not content IDs.
The editor may select supported policy templates; it should not author arbitrary
runtime scripts.

**Complete when:** adding a fixture enemy with an existing capability set
requires only an authored record and generated output, and the fixture passes
spawn, navigation, combat, snapshot, scoring, and replay tests without a new
`EnemyId.fixture` branch in a system.

## RC-H03: gameplay content is not a coherent versioned unit

**Evidence.** `GameCore` accepts separate projectile, spell-book, enemy,
weapon, and accessory catalogs, but it constructs the static
[`AbilityCatalog`](../../../packages/runner_core/lib/game_core.dart#L477)
internally. Player and level definitions arrive separately. Run admission has
compatibility/ruleset fields, but the authored gameplay records do not produce
one deterministic content signature consumed by both client and replay
validator.

**Consequence.** A gameplay edit deployed to the client and validator at
different times can replay the same commands against different definitions.
It also makes cross-catalog validation—such as a player's projectile or ability
reference—an ad hoc responsibility.

**Recommendation.** Generate an immutable `GameContentBundle` containing every
gameplay catalog, stable IDs/ordinals, explicit schema version, and a canonical
gameplay hash. Validate all references before generation. Carry the resulting
revision/hash through run ticket/session/replay admission or require an explicit
compatibility/ruleset bump that resolves to it. Visual-only metadata may use a
separate signature if it cannot affect simulation.

Backend price, entitlement, and publication remain backend authority. A valid
content record must not automatically make an item purchasable or ranked-active.

**Complete when:** client and validator select the same immutable bundle from
the run contract, reject mismatches before replay, and tests prove deterministic
hashes plus cross-reference validation.

## RC-M01: `GameCore` has public mutation outside commands

**Evidence.** The class-level contract says commands are the external influence
on simulation, but [`GameCore`](../../../packages/runner_core/lib/game_core.dart#L923)
exposes mutable `tick`, `paused`, `gameOver`, `distance`, and `collectibles`, as
well as `setPlayerVelXY`, a `playerFacing` setter, and an explicitly unsafe
position setter. The app controller directly mutates `paused`.

**Recommendation.** Make run state private with read-only getters. Give
pause/resume an explicit lifecycle API that is outside recorded simulation
ticks. Route gameplay influence through commands. Move unsafe positioning and
velocity mutation into a dedicated test harness rather than the public runtime
surface.

**Complete when:** production consumers cannot mutate simulation state directly
and the documentation accurately names every allowed influence channel.

## RC-M02: semantic validators disappear in release mode

**Evidence.** [`PlayerCharacterDefinition.assertValid`](../../../packages/runner_core/lib/players/player_character_definition.dart#L56)
is called inside an assertion in the registry. `AbilityDef`, reactive procs, and
other definitions express many constraints only as constructor assertions;
[`AbilityCatalog._validateIntegrity`](../../../packages/runner_core/lib/abilities/ability_catalog.dart#L42)
is also assertion-gated.

**Recommendation.** Add pure validators that return stable, field-addressed
diagnostics and run them in the editor and generator. Generated catalog
construction should fail fast for corrupt artifacts even when assertions are
disabled. Assertions can remain supplementary developer checks.

**Complete when:** malformed authoring fixtures produce deterministic
diagnostics in editor and generator tests, and cannot produce accepted generated
runtime content in release mode.

## RC-M03: reactive-proc cooldown duration depends on tick rate

**Evidence.** Most player and ability timing converts authored seconds or 60 Hz
ticks for the configured rate. In contrast,
[`ReactiveProc.internalCooldownTicks`](../../../packages/runner_core/lib/weapons/reactive_proc.dart#L62)
is consumed unchanged by
[`ReactiveProcSystem`](../../../packages/runner_core/lib/ecs/systems/reactive_proc_system.dart#L196).
Weapons and accessories author 30 seconds as `1800` ticks. At 30 Hz this lasts
60 seconds; at 120 Hz it lasts 15 seconds.

**Recommendation.** Author seconds or name the field `internalCooldownTicks60`
and scale it once during content derivation. Alternatively, make 60 Hz the only
valid run rate everywhere; that would be a larger product/protocol decision and
does not match the current configurable API.

**Complete when:** a parameterized 30/60/120 Hz test observes the same duration
in seconds with deterministic rounding.

## RC-M04: kill statistics use enum position as a protocol

**Evidence.** [`GameCore`](../../../packages/runner_core/lib/game_core.dart#L918)
allocates a list sized to `EnemyId.values` and increments by enum index.
[`RunStats`](../../../packages/runner_core/lib/events/run_events.dart#L65)
explicitly defines list indices as `EnemyId.values` order; the validator stores
that list.

**Recommendation.** Before general enemy creation, migrate the shared result to
stable keyed records, or at minimum generate an immutable append-only ordinal
and validate it separately from Dart enum order. Keyed counts are the healthier
long-term protocol; an append-only generated ordinal is a migration bridge.

**Complete when:** reordering generated declarations cannot reinterpret stored
or uploaded kill statistics, and compatibility tests cover old payloads.

## RC-M05: `GameCore` is an orchestration hotspot

`game_core.dart` is 2,134 lines with 122 imports. It constructs nearly every
system, owns derived tuning and catalogs, defines tick ordering, processes
commands, spawns entities, tracks run state, and emits output. Its explicit
order is valuable; the problem is the number of reasons the file changes.

**Recommendation.** Extract in parity-protected stages:

1. immutable `GameContentBundle` and derived content;
2. world/system construction (`CoreBootstrap` or equivalent);
3. an explicit `SimulationPipeline` that preserves the existing order;
4. private run state and output collection.

Do not hide the ordered tick behind a generic ECS scheduler. Keep the order
readable and test its signature.

## RC-M06: the generic player path is still Eloise-specific

**Evidence.** [`PlayerCatalogDerived.from`](../../../packages/runner_core/lib/players/player_catalog.dart#L204)
always creates an Eloise traversal profile. The second registered character,
[`eloiseWip`](../../../packages/runner_core/lib/players/characters/eloise_wip.dart),
reuses Eloise's animation, catalog, and tuning and changes only identity/display
metadata. The backend duplicates the two known IDs in
[`functions/src/ownership/defaults.ts`](../../../functions/src/ownership/defaults.ts#L8).

This is incomplete content, not a runtime defect: the selectable WIP character
is an alias rather than an independent gameplay definition.

**Recommendation.** Put a closed traversal/motion policy in the character
definition and generate character existence/default metadata for each consumer.
Keep backend ownership, pricing, and activation decisions explicit.

## RC-M07: entity facts are duplicated across layers

Projectile identity and behavior live in Core, while render scale/animation,
display text, loadouts, store entries, ownership defaults, and validator parsing
have separate maps or switches. Enemy render facts and backend character lists
show the same pattern. Adding a content item therefore means finding every
consumer by repository search.

**Recommendation.** Author typed facets once, then generate layer-specific,
data-only artifacts. Simulation facts remain Core-owned; Flame receives render
descriptors; UI receives localization keys; backend receives existence IDs only
where needed. Store price and publication are deliberately not generated from
the gameplay record.

## RC-M08: ability content is only partly injectable

`AbilityDef` is already close to a data record, and systems commonly depend on
an ability resolver. But `GameCore` constructs `AbilityCatalog` internally, and
parry/Hashash setup includes hard-coded ability keys. The entity-authoring
migration does not need a full ability editor now, but player/enemy records must
only reference admitted abilities and the special keys must become declared
policies before abilities are independently authorable.

## RC-L01: tracked backup files look like production sources

The repository tracks:

- `packages/runner_core/lib/players/characters/eloise.dart.bak`
- `packages/runner_core/lib/projectiles/projectile_catalog.dart.bak`

They are not analyzed as Dart but appear in broad searches and already contain
stale variants. Editor recovery artifacts should live in a dedicated recovery
location or be ignored, and should not be committed beside authoritative source.

## RC-L02: documentation drift

Examples found during the audit:

- the package README still describes a legacy rectangular `GameCore` path while
  the current terrain contract says polygon terrain is mandatory;
- `PlayerCatalog` documentation says the collider comes from movement tuning,
  while the implementation reads catalog collider fields;
- `WeaponDef.stats` is described as future use although
  `CharacterStatsResolver` consumes it;
- the command-only `GameCore` boundary is contradicted by public setters and
  mutable fields.

Correct these in the milestone that changes the relevant contract so the docs
do not race ahead of implementation.

## RC-R01: cross-platform replay parity needs stronger evidence

The inspected tests provide same-host deterministic and fresh-process coverage.
Core still has floating-point calculations in projectile direction, target
prediction, and some ability paths. This audit did not establish a mismatch,
so this is a risk rather than a defect.

Add CI that replays a canonical corpus on the client and Linux validator target
and compares a quantized outcome/event signature. If mobile architecture parity
cannot run in normal CI, retain signed reference fixtures produced on supported
targets and compare them on every gameplay-content change.
