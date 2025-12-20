# Implementation Plan (V0 Checklist)

This document turns `docs/plan.md` into an executable checklist for getting a playable V0 running end-to-end.

## V0 Decisions (Locked)

* Runner model: player moves in world coordinates; camera auto-scrolls right and the player must stay within the view to survive (player can pull the camera forward but not backward).
* Input mapping:
  * Left: on-screen joystick (move left/right).
  * Right: three buttons (Jump, Dash, Attack).
  * Tap/click on the game view: reserved for aiming + casting spells (exact cast rules defined later).
  * Optional hardware input (V0):
    * Keyboard: debug/dev only (not required for V0).
    * Controller/gamepad: planned post-V0 (not required/supported in V0).
* V0 target platforms: **mobile only** (iOS + Android).
* Ability specs, enemy AI rules, and spawn rules: iterate after "run + jump" is working.

## V0 Success Criteria

* Ground band + platforms + obstacles are collidable.
* Parallax background renders behind the world.
* Player: run, jump; (dash/attack/cast can be placeholder wired until specs are chosen).
* Enemies exist (can be placeholder visuals until AI/combat is implemented):
  * one flying follower that casts a lightning bolt
  * one ground follower that can melee hit and cast a fire cone
* One collectible type is spawnable and collectible.
* Deterministic core given the same `seed` and command stream.

---

## Milestone 0 - Scaffold & Wiring

- [x] Create folder layout:
  - `lib/core/` (pure Dart simulation)
  - `lib/game/` (Flame view)
  - `lib/ui/` (Flutter widgets/overlays)
- [x] Expose the mini-game as an embed-friendly Flutter entrypoint:
  - a reusable `Widget` and/or route builder (e.g., `RunnerGameWidget`, `RunnerGameRoute`)
  - keep `lib/main.dart` as a development host/demo only
- [x] Add dependencies (as needed by code you write):
  - Controller injection + UI state: keep host/app choice; avoid imposing a DI/state system from the embeddable widget.
- [x] Add `GameCore` skeleton (no Flutter/Flame imports).
- [x] Add `GameController` skeleton (owns core + fixed tick loop + command queue + snapshots/events).
- [x] Add a minimal `FlameGame` that displays *something* and can be launched from `main.dart`.

Acceptance:
- App launches into a menu and can start/exit the game route without leaks/crashes.
- The game can be mounted by a host app by importing a widget/route, without relying on `main.dart` code.

---

## Milestone 1 - Camera, Viewport, Parallax

- [x] Lock V0 render constants (and keep Core/Render consistent):
  - virtual resolution: **480×270 (16:9)**
  - world units: `1 world unit == 1 virtual pixel`
  - axes/origin: `(0,0)` top-left, `+X` right, `+Y` down
  - camera view size: fixed `(480,270)` in world units (letterbox instead of showing extra world)
- [x] Implement the pixel-perfect viewport policy from `docs/plan.md`:
  - compute scale using **physical pixels** (`logicalPx * devicePixelRatio`)
  - scale must be integer-only; never fractional
  - letterbox fill: solid black for V0
- [x] Add the parallax set (placeholder art is fine; use real assets if available):
  - `assets/parallax/field/Field Layer 01.png` ... `Field Layer 10.png`
  - enforce pixel-art filtering (no blur); if source art doesn't match 270px height (or an integer multiple), pre-scale offline with nearest-neighbor
- [x] Treat `Field Layer 09.png` as the **ground band reference**:
  - rendered between parallax layers 08 and 10 (moves 1.0× with the camera)
  - record its top edge as `groundTopY` (canonical spawn reference)
  - collision comes in Milestone 2 (Milestone 1 is visual reference + camera sanity)
- [x] Add scrolling camera follow (player moves in world coords; camera follows):
  - snap the camera position used for rendering to integer world coordinates (prevents shimmer)
  - snap final render positions to the pixel grid (after any interpolation)
- [x] Parallax implementation note (V0):
  - World/camera rendering stays snapped to integer pixels (avoid shimmer).
  - Background parallax is allowed to use sub-pixel scroll for smoother motion (expect shimmer tradeoff).
  - `PixelParallaxBackdropComponent` is mounted under `game.camera.backdrop` and uses `FilterQuality.none`.

Acceptance:
- On different window sizes/aspect ratios, the world stays pixel-crisp (no blur/shimmer) and letterboxes correctly.
- Camera follow does not jitter when the player moves (camera snapping works).

---

## Milestone 2 - Core Collision + Player Run/Jump (First "Real Gameplay")

- [x] ECS foundation (Core):
  - SoA + sparse-set storage (`EcsWorld`, component stores, swap-remove)
  - Monotonic, never-reused `EntityId`
- [x] Core components:
  - [x] `Transform` (pos/vel)
  - [x] `PlayerInput` (tick-scoped input decoded from Commands)
    - [x] `Movement` (timers/state: coyote/jump-buffer/dash; reads grounded from `CollisionState`)
  - [x] `Body`
  - [x] `ColliderAabb`, `CollisionState`
- [x] Core systems:
  - [x] `PlayerMovementSystem` (accel/decel, gravity, coyote time, jump buffer, dash; writes velocities only)
  - [x] `CollisionSystem` (integrates + resolves):
    - [x] ground band (V0 equivalent of the old clamp)
    - [x] one-way platform tops (AABB, vertical-only)
    - [x] obstacles + side walls (AABB, sideMask; horizontal-only for now)
- [x] Commands:
  - [x] `MoveAxis` (from keyboard)
  - [x] `JumpPressed`
  - [x] `DashPressed` (wired and has gameplay effect in Core)
- [x] Snapshot includes enough data to render player/platforms/obstacles and grounded state (for animation later).
- [x] Snapshot includes enough data to render player/platforms/obstacles (via `staticSolids`) and grounded state (via `EntityRenderSnapshot.grounded`).
- [x] Core unit tests for movement feel (accel, jump, buffer, dash)

Acceptance:
- Player can run left/right and jump; reliably lands on ground/platforms; cannot pass through obstacles.

---

## Milestone 3 - Touch Controls (V0)

- [x] Flutter overlay for:
  - joystick left
  - Jump/Dash/Attack buttons right
- [x] Debug-only keyboard mapping (dev convenience; not required for V0).
- [x] Command mapping:
  - joystick -> `MoveAxis`
  - Jump button -> `JumpPressed`
  - Dash button -> `DashPressed`
  - Attack button -> `AttackPressed` (wired, no gameplay effect until Milestone 6)
  - Aim (mouse/touch): pointer position is converted to an aim direction command:
    - `AimDir(dir)` where `dir = normalize(pointerWorldPos - playerWorldPos)`
  - Touch:
    - tap on game view -> `CastPressed` (aim dir is computed from the tap position)
  - Note (post-V0): controller aiming likely uses lock-on / aim assist, but it is out of scope for Milestone 3.

Acceptance:
- On iOS/Android: no keyboard required; player can run/jump/dash/attack and cast via touch controls.

---

## Milestone 4 - Resources (First Pass)

This milestone adds deterministic "combat plumbing" in Core: resources, cooldowns, regen, and costs.

Design goals:
* Keep it deterministic (tick-based, no wall-clock gameplay logic).
* Keep tuning/rules in Core (not UI-owned).

### 4.1 Core resources (ECS stores)

- [x] Add resource component stores (separate SoA stores; no "mega Stats struct"):
  - `HealthStore` (hp, hpMax, hpRegenPerSecond)
  - `ManaStore` (mana, manaMax, manaRegenPerSecond)
  - `StaminaStore` (stamina, staminaMax, staminaRegenPerSecond)
- [x] Add `ResourceRegenSystem`:
  - regen `mana/stamina/health` up to max each tick
  - keep all tuning/config in Core (no UI-owned rules)
- [x] Add snapshot fields + render/HUD plumbing:
  - core snapshot exposes health/mana/stamina for the player
  - Flame shows 3 horizontal bars (top-left): HP/Mana/Stamina
- [x] Apply stamina costs to movement:
  - jump costs `2` stamina
  - dash costs `2` stamina

Reference (from `tools/output/c++implementation.txt`):
* Player has hp/mana/stamina with regen; stamina is used for jump/dash costs.

Acceptance:
- Player HUD shows HP/Mana/Stamina and updates deterministically (regen + spending).

---

## Milestone 5 - Spells (Ice Bolt Projectile)

This milestone adds the first spell: cast -> projectile spawn -> lifetime -> (skeleton) damage plumbing.

Design goals:
* Keep it modular/scalable: abilities, projectiles, and damage should not become one giant system.

### 5.1 Spell data (catalog)

- [x] Add a minimal `SpellCatalog` in Core (pure data; deterministic; no assets):
  - `IceBolt` spell stats: `manaCost=10`, `damage=25`, `projectileId=iceBolt`
  - (later) `Lightning` spell stats: `manaCost=10`, `damage=10`, `projectileId=lightningBolt` (Milestone 7)
- [x] Add a minimal `ProjectileCatalog` in Core (pure data; deterministic; no assets):
  - `IceBolt` projectile stats: `speed=1600`, `lifetime=1.0s`, `colliderSize=(18,8)` (from C++ reference)
    - collider size is full extents; derive AABB half-extents `(9,4)` at runtime
  - (later) `LightningBolt` projectile stats: `speed=900`, `lifetime=1.2s`, `colliderSize=(16,8)` (Milestone 7)
- [x] Decide on time units:
  - store tuning as "per second" / "seconds" floats, but convert to integer ticks at runtime (or store both)
  - use `ceil(seconds * tickHz)` for tick conversions (matches existing tuning pattern)

### 5.2 Casting (player ability)

- [x] Add `CooldownStore` in Core:
  - start with `castCooldownTicksLeft` (later: melee cooldown)
  - decrement it each tick and clamp at 0
- [x] Add cast tuning:
  - set `castCooldownSeconds = 0.25` and store it as seconds
  - derive to ticks via `ceil(seconds * tickHz)`
- [x] Add `PlayerCastSystem` (or `AbilitySystem` split into focused systems):
  - reads `PlayerInput.castPressed` (edge-triggered) + `PlayerInput.aimDir`
  - checks `ManaStore` + `CooldownStore` (real cast cooldown)
  - spends mana, starts cooldown, directly creates projectile entities in core
- [x] Define cast semantics (match C++ first-pass):
  - cast is ignored if insufficient mana
  - aim dir defaults to facing direction if `aimDir` is zero
  - spawn origin: `origin = playerPos + aimDir * (playerRadius * 0.5)` (config constant)
  - render placeholder: projectile is a small `RectangleComponent` (no assets)

### 5.3 Projectile (ice bolt)

- [x] Add projectile components:
  - `ProjectileStore` (projectileId, faction/owner, dir, speed, damage)
  - `SpellOriginStore` (optional; only present for spell-spawned projectiles)
  - `LifetimeStore` (ticks remaining)
- [x] Add `ProjectileSystem`:
  - integrates projectile position each tick
  - lifetime end despawn is handled by a dedicated `LifetimeSystem`
  - (for now) projectile-vs-static collision can be skipped; projectile-vs-actors comes in Milestone 7 with enemies
- [x] Add `DamageSystem` (or `CombatSystem`) skeleton:
  - applies damage on projectile hits (later expanded for melee + enemy attacks)
  - keeps "damage rules" in core (invuln ticks, death, score hooks later)

### 5.4 Tests (add as behavior is introduced)

- [x] Resource tests: regen clamps to max; spending cannot go below 0.
- [x] Cast tests: insufficient mana => no projectile; sufficient mana => projectile spawn + mana decrease + cooldown set.
- [x] Determinism extension: include resources + ability outputs in snapshot hash.

Acceptance:
- Cast spawns an `IceBolt` projectile; HUD reflects resource changes; no melee yet.

---

## Milestone 6 - Melee (Sword Hit)

Melee is its own milestone because it needs different mechanics than projectiles (timing window, hit once per swing, facing/range rules).

- [x] Add melee components:
  - `FactionStore` (player/enemy; used for filtering damage)
  - `HitboxStore` (owner, faction, damage, AABB half-extents, offset)
  - `HitOnceStore` (per-hitbox fixed small buffer; deterministic, no hashing)
  - reuse `LifetimeStore` for active window
- [x] Add `PlayerMeleeSystem` + hit resolution:
  - on `AttackPressed`, checks stamina + melee cooldown, spawns a short-lived hitbox in front of the player (facing-only)
  - `HitboxDamageSystem` applies damage once per target per swing
- [x] Tick order rule:
  - `LifetimeSystem` runs last so hitboxes/projectiles get their full final tick to act
- [x] Add tests:
  - `AttackPressed` spawns hitbox for N ticks
  - hitbox damages only once per target per swing

Acceptance:
- Attack produces a deterministic short-lived melee hitbox entity and applies damage once per swing.

---

## Milestone 7 - Enemies (Basic AI + Attacks)

Note: keep AI extremely simple for V0.

- [x] Add enemy data + components (Core):
  - `EnemyId` (`flyingEnemy`, `groundEnemy`)
  - `EnemyStore` (id + AI state/timers; keep SoA + scalar-only)
  - `V0EnemyTuning` (speeds/cooldowns/ranges in seconds; derived to ticks at runtime)
  - reuse existing `FactionStore` (`player` vs `enemy`) for filtering
- [x] Spawn enemies deterministically (Core):
  - for Milestone 7 keep spawns fixed/hardcoded (no RNG yet) so tests are stable
  - Milestone 12 will replace this with seeded deterministic generation
- [x] Flying enemy AI + ranged attack (Core):
  - movement goal: keep a desired X range from the player (C++: 100–250px) and face the player
  - vertical goal (V0): hover at `groundPlaneTopY - hoverOffset` (no per-X ground sampling until world-gen varies)
  - physics config: `isKinematic=false`, `useGravity=false`, `sideMask=0` (so it still integrates `pos += vel * dt` but doesn't resolve wall contacts)
  - periodically casts `SpellId.lightning` at the player (C++: 2.0s cooldown, origin = flyingEnemyPos + dir * 20)
  - use a shared core helper (e.g. `spawnSpellProjectile(caster, spellId, origin, dir)`) so player/enemy projectile spawn rules stay identical
- [x] Ground enemy (GroundEnemy) AI + melee / cone (Core):
  - simple horizontal pursuit toward player along ground, with a max speed cap
  - melee hit when in range using the same hitbox mechanism as the player (spawn hitbox with `Faction.enemy`)
  - (defer) fire cone spell: implement later as a new non-projectile spell type (do not mix into Milestone 7)
- [x] Add `ProjectileHitSystem` (Core):
  - resolves projectile-vs-actors via AABB overlap (projectile AABB derived from `ProjectileCatalog` collider size)
  - queues damage via `DamageSystem`
  - despawns projectile on hit (deferred destroy; no structural mutation mid-iteration)
- [x] Projectiles are real colliders (Core):
  - when spawning a projectile, also add `ColliderAabb` with half-extents from `ProjectileCatalog` (so hit resolution uses one data model)
  - (later) projectile-vs-static can reuse the same collider once desired
- [x] Damage rules (Core, minimal V0):
  - add `InvulnerabilityStore` (ticks left, player-only); `DamageSystem` ignores damage while invulnerable and sets invuln on hit
  - add `HealthDespawnSystem` (or extend `DamageSystem`) to despawn entities when HP reaches 0
- [x] Lock tick order (Core):
  - AI decide/steer (sets enemy velocities / triggers attacks)
  - movement + collision integration (applies to all non-kinematic bodies)
  - spawn attacks (projectiles/hitboxes) using post-move positions
  - projectile movement (for already-existing projectiles)
  - hit resolution (`ProjectileHitSystem` + `HitboxDamageSystem`)
  - apply damage + despawn
  - lifetime cleanup (last)
- [x] Micro-steps (recommended implementation sequence):
  - spawn 1 Flying enemy + 1 GroundEnemy deterministically (fixed positions; no RNG)
  - `ProjectileHitSystem` + invuln + death end-to-end with player `IceBolt` (player can kill enemy)
  - Flying enemy casts `SpellId.lightning` and damages the player
  - GroundEnemy melee hitbox damages the player (fire cone deferred)
- [x] Tests:
  - [x] enemy projectile damages player (`SpellId.lightning`)
  - [x] player ice bolt damages enemy and enemy despawns at 0 HP
  - [x] enemy melee hitbox damages player once per swing
- [x] Render placeholder (no assets):
  - render enemies as colored circles (type-stable color in snapshot later; temporary color by entity id is OK for V0)

Acceptance:
- A Flying enemy and GroundEnemy can be spawned deterministically, attack the player (projectile + hitbox), and can be defeated with projectiles/melee.

---

## Milestone 8 - Shared Ability Systems (Player + Enemy Reuse)

Goal: reduce duplicated ability logic across player/enemy by introducing intent components + shared execution systems. Player input and enemy AI emit **intents**; shared systems apply the **rules** (costs/cooldowns/spawn) deterministically.

Key idea: separate ability execution into 3 layers:
- **Intent** (player input / enemy AI decides *what* to do)
- **Execution** (shared systems apply the *rules*: costs, cooldowns, spawn)
- **Resolution** (shared hit resolution + damage rules)

- [x] Add intent components (Core):
  - `CastIntentStore` (SoA + scalar-only):
    - `SpellId spellId`
    - `double dirX/dirY` (raw aim/target vector; normalization happens in spawn helper)
    - `double fallbackDirX/fallbackDirY` (e.g. facing direction)
    - `double originOffset`
    - `int cooldownTicks` (how long to lock casting after a successful cast)
    - `int tick` (tick-stamp; only valid when `intent.tick == currentTick`; use `-1` for "no intent")
  - `MeleeIntentStore` (SoA + scalar-only):
    - `double damage`, `double halfX/halfY`, `double offsetX/offsetY`
    - `int activeTicks`
    - `int cooldownTicks`
    - optional costs: `double staminaCost` (player uses; enemies use 0 for now)
    - `int tick` (tick-stamp; only valid when `intent.tick == currentTick`; use `-1` for "no intent")
  - Intent lifecycle contract (Core):
    - at most one intent per entity per tick; last write wins
    - execution systems ignore stale intents where `intent.tick != currentTick`
    - execution systems invalidate consumed intents by setting `intent.tick = -1` (avoids accidental validity if tick 0 is ever used)
- [x] Add shared execution systems (Core):
  - `SpellCastSystem.step(world, currentTick: tick)` consumes `CastIntentStore` and owns:
    - cooldown gating (`CooldownStore.castCooldownTicksLeft`)
    - mana gating + spending (`ManaStore`)
    - projectile spawning via `spawnSpellProjectileFromCaster(...)` (direction normalization + projectile mapping)
    - invariant: spend mana + set cooldown **only if** a projectile was actually spawned
    - invalidates intent after processing (`intent.tick = -1`)
  - `MeleeAttackSystem.step(world, currentTick: tick)` consumes `MeleeIntentStore` and owns:
    - cooldown gating (`CooldownStore.meleeCooldownTicksLeft`)
    - optional stamina gating/spending (`StaminaStore` when present + `staminaCost > 0`)
    - hitbox spawning (`HitboxStore` + `HitOnceStore` + `LifetimeStore`)
    - hitbox `owner` and `faction` should be derived from the attacker entity + `FactionStore` (avoid intent/store mismatches)
    - invalidates intent after processing (`intent.tick = -1`)
- [x] Split "hitbox follows owner" into its own reusable system (Core):
  - `HitboxFollowOwnerSystem`:
    - updates hitbox transform from `owner Transform + Hitbox.offset`
    - runs before hit resolution each tick
  - `PlayerMeleeSystem` becomes a thin adapter (reads input, writes melee intent)
- [x] Refactor player systems into intent writers (Core):
  - `PlayerCastSystem` reads `PlayerInputStore` and writes `CastIntentStore` (no mana/cooldown logic here)
  - `PlayerMeleeSystem` reads `PlayerInputStore` and writes `MeleeIntentStore` (no stamina/cooldown logic here)
- [x] Refactor enemy logic into intent writers (Core):
  - keep steering separate (can remain in `EnemySystem.stepSteering` for V0)
  - enemy attack decisions write intents:
    - Flying enemy writes `CastIntentStore` (lightning at player)
    - GroundEnemy writes `MeleeIntentStore` (enemy faction hitbox)
  - goal: enemy code stops manually spending mana / setting cooldown / duplicating spawn rules
- [x] Lock tick order and determinism (Core):
  - define the contract: “at most one intent per entity per tick; last write wins; stale intents ignored by tick-stamp”
  - define a stable writer order (so “last write wins” stays deterministic):
    - enemy intent writer(s) run before player intent writers (or the reverse — pick one and lock it)
    - optional debug assert: player systems only write intents for the player entity; enemy systems only write intents for enemy entities
  - lock spawn activation semantics (refactor must not change behavior):
    - projectiles and hitboxes spawned by intent execution are allowed to hit on the same tick they spawn
    - newly spawned projectiles do not move until the next tick (projectile movement runs before intent execution)
  - recommended tick order:
    - cooldown timers + invulnerability
    - AI steering
    - movement + collision
    - projectile movement (existing projectiles)
    - intent writers (player input + enemy attack decisions)
    - intent execution (`SpellCastSystem`, `MeleeAttackSystem`)
    - hitbox follow owner (after execution, before hit resolution)
    - hit resolution + damage + despawn
    - lifetime cleanup (last)
- [x] Tests:
  - `SpellCastSystem`: spending/cooldowns happen only on successful spawn; determinism with identical inputs
  - `PlayerCastSystem` writes intent and relies on `SpellCastSystem` for cost/cooldown (regression for cast tests)
  - `MeleeAttackSystem`: hitbox spawn + HitOnce behavior unchanged; stamina spending handled in execution system
  - enemy casting/melee goes through the same execution systems (no duplicated rules)
  - `HitboxFollowOwnerSystem` keeps hitboxes attached to their owner across movement
  - spawn activation semantics are locked:
    - spawned projectile can hit on its spawn tick but does not move until the next tick
    - spawned hitbox can hit on its spawn tick

- [x] Micro-steps (recommended implementation sequence):
  - add `CastIntentStore`/`MeleeIntentStore` with `tick=-1` invalid state
  - implement `SpellCastSystem` and migrate player casting first (cast tests stay as regression)
  - implement `MeleeAttackSystem` and migrate player melee next (melee tests stay as regression)
  - migrate enemy attacks to intents (remove duplicated mana/cooldown/spawn logic from AI)

Acceptance:
- Player and enemy share one spell-cast execution path and one melee execution path via intents; systems remain deterministic and tests cover the shared behavior.

Naming:
- As part of this milestone, rename any system that is strictly player-only to `PlayerXSystem` (e.g. `PlayerCastSystem`, `PlayerMeleeSystem`) to keep responsibilities obvious as enemy reuse increases.

---

## Milestone 9 - Broadphase (Uniform Grid for Dynamic AABBs)

Goal: avoid O(projectiles × actors) and O(hitboxes × actors) narrow-phase checks by adding a deterministic broadphase.

- [x]Introduce reusable grid math (Core):
  - create `GridIndex2D`:
    - `cellSize` (world units)
    - `worldToCell(x, y) -> (cx, cy)` using `floor(x / cellSize)`
    - deterministic `cellKey(cx, cy) -> int` (do not use Dart tuple/hashCode)
    - `cellAabb(cx, cy)` (debug + geometry baking later)
    - `forNeighbors(cx, cy, diagonal: bool)` (future NavGrid/A* reuse; not used yet)
  - note: this is a generic indexing utility; it is *not* a “collision-only” structure
- [x]Add `BroadphaseGrid` for dynamic AABBs (Core):
  - built on top of `GridIndex2D`
  - rebuilt once per tick after movement/collision
  - stores buckets: `cellKey -> List<EntityId>` (or dense indices) for candidate lookup
  - insert only *damageable* colliders:
    - entities with `Transform + ColliderAabb + Health + Faction`
    - insert into all overlapped cells (AABB spans 1..N cells)
    - insertion order must be stable (iterate `health.denseEntities` order)
  - query API:
    - compute query AABB, enumerate overlapped cells in deterministic order (y then x increasing)
    - gather candidates from buckets, then run narrow-phase AABB overlap (existing rules)
- [x] Deduplicate candidates deterministically (Core):
  - use `List<int> seenStampByEntityId` (ensure capacity by max entity id seen)
  - per query: increment `stamp`, mark `seenStampByEntityId[targetId] = stamp` to avoid multi-cell duplicates
- [x] Determinism rules (Core):
  - projectile hit selection must be stable when multiple candidates overlap:
    - preserve insertion order (grid insertion is in stable dense order) and cell scan order, OR
    - collect unique candidates and sort by `EntityId` before picking the first hit
  - hitboxes that can hit multiple targets should apply damage in a stable order (same rule as above)
- [x] Integration (Core):
  - build the broadphase once per tick in `GameCore` after movement/collision and before hit resolution
  - pass the broadphase to both `ProjectileHitSystem` and `HitboxDamageSystem`
- [x] Future-proofing note (Core):
  - do not reuse `BroadphaseGrid` buckets for A* (it is rebuilt from dynamic AABBs and changes every tick)
  - later, build a separate `NavGrid/CostGrid` from static world geometry, reusing only `GridIndex2D` math
  - broadphase cell size and nav cell size can differ (often: broadphase smaller, nav larger)
- [x] Tests:
  - broadphase results match brute-force on a randomized-but-seeded layout (same hits, same order)
  - determinism: multiple overlapping targets yields stable chosen target for projectiles
  - performance sanity: large N (e.g. 500 targets, 500 projectiles) completes within a reasonable time budget (non-flaky)

Acceptance:
- Projectile and hitbox resolution no longer scales with the full actor list each time; behavior remains deterministic and matches previous logic.

---

## Milestone 10 - Hit Resolution Module (Shared Narrowphase + Rules)

Goal: centralize overlap + filtering + candidate ordering so projectile and hitbox interactions share identical rules and stay deterministic.

- [x] Create a shared hit resolution module (Core):
  - new module owns:
    - AABB computation (`Transform` + `ColliderAabb` -> min/max)
    - overlap test (AABB vs AABB)
    - friendly-fire / owner exclusion rules
    - deterministic candidate ordering contract ("first hit wins" or stable multi-hit order)
  - module does *not* mutate world mid-iteration; returns hit results or invokes callbacks
- [x] Integrate broadphase as the candidate source (Core):
  - hit resolver queries the Milestone 9 grid to obtain candidates
  - preserve determinism: stable cell scan order + stable per-cell insertion order (or sort by `EntityId`)
- [x] Refactor systems to use the module (Core):
  - `ProjectileHitSystem` becomes thin: "for each projectile, resolve first hit then despawn"
  - `HitboxDamageSystem` becomes thin: "for each hitbox, resolve hits then apply HitOnce gating"
  - ensure both systems share the same faction/owner exclusion logic
- [x] Tests:
  - brute-force equivalence: resolver results match brute-force on seeded layouts
  - determinism: multiple overlapping targets yields stable selected target for projectiles
  - determinism: multi-hit hitboxes apply damage in stable order (and HitOnce still works)

Acceptance:
- Projectile and hitbox hit resolution share one codepath for AABB math/filtering/ordering, and behavior remains deterministic.

---

## Milestone 11 - Autoscroll Camera + View Bounds (Player Must Stay In View)

Goal: match the reference runner feel where the camera is not centered on the player: the view auto-scrolls to the right, the player can fall behind, and leaving the view ends the run.

Reference behavior (from `tools/output/c++implementation.txt`):
- camera has a baseline auto-scroll target speed (slightly below player max speed), with ease-in acceleration
- camera center eases toward a target X that never moves backward
- if the player moves beyond a follow threshold (~80% from the left edge), the camera target is allowed to drift toward the player (clamped so it never decreases)
- if the player's right edge is left of the camera's left edge, the player is killed (run ends)

- [x] Add camera tuning/config (Core):
  - introduce `V0CameraTuning` (or similar simulation config) to hold:
    - `targetSpeedX` derived from `V0MovementTuning.maxSpeedX` (baseline auto-scroll speed, world units / second)
      - recommended: `targetSpeedX = maxSpeedX - speedLagX` (defaults mimic ref: `500 - 10 = 490`)
      - define `speedLagX` in the camera tuning/config (not in movement/combat tuning)
    - `accelX` (ease-in to target speed)
    - `followThresholdRatio = 0.80` (of view width from the left; locked)
    - smoothing params for camera center and target catchup (fixed-tick deterministic)
  - keep this separate from combat/ability tuning (camera is a simulation concern)
- [x] Add deterministic camera state in Core:
  - track camera `centerX`, `targetX`, and `speedX`
  - update each tick using fixed `dtSeconds` (no frame-dt logic in Core)
  - rule: `targetX` and `centerX` must never decrease (camera never moves backward)
- [x] Expose camera position to render (Core → Snapshot):
  - add `cameraCenterX` (and keep `cameraCenterY` fixed to current `v0CameraFixedY`)
  - renderer uses snapshot camera center, not player position, to position `CameraComponent`
  - keep pixel snapping rules for render (snap camera center to integer world coords before rendering)
- [x] Enforce "stay in view" rule (Core):
  - compute `cameraLeft = cameraCenterX - (v0VirtualWidth / 2)`
  - locked: if `playerColliderRight < cameraLeft`, the run ends
  - end-of-run contract (locked):
    - set an explicit `gameOver` flag in Core state and snapshot
    - emit a `GameEvent` (e.g. `RunEndedEvent(reason: fellBehindCamera, tick, distance)`) for UI/renderer
    - simulation should stop advancing after game over (pause/freeze), but snapshots remain readable
- [x] Tests (Core):
  - camera determinism: same seed + same commands => identical camera positions
  - kill rule: with no forward movement, camera eventually passes player and run ends deterministically
  - follow threshold: if player sprints ahead past threshold, camera target increases faster than baseline (still monotonic)

Acceptance:
- The camera auto-scrolls right independently of player input; the player can pull the camera forward but cannot pull it backward.
- If the player falls behind the left edge of the view, the run ends deterministically.
- Renderer camera follows snapshot camera state (not player-centered).

---

## Milestone 12 - Deterministic Spawning (First Pass)

- [x] Define V0 track spawning config (Core):
  - chunk width (world units), spawn-ahead margin, and cull-behind margin (relative to camera left/right).
  - collision-only for V0 (no lava/gaps/hazards yet); ground stays always safe/solid.
  - V0 defaults (recommended):
    - `chunkWidth = 480` (one view wide; V0 virtual width is 480 world units)
    - `spawnAheadMargin = 960` (two views ahead)
    - `cullBehindMargin = 480` (one view behind)
  - invariant: `spawnAheadMargin >= chunkWidth` to avoid “running out of track” at high speeds.
- [x] Add deterministic track generator (Core):
  - runtime contract: each chunk becomes a small list of `StaticSolid` relative to `chunkStartX`:
    - platforms: one-way top only (match current collision behavior)
    - obstacles: solid top + walls (match current collision behavior)
  - authoring contract: define a `ChunkPattern` library (relative solids + optional enemy spawn markers), then expand to `StaticSolid` at spawn time.
  - start simple: a fixed list of hand-authored chunk patterns.
    - recommended V0: 8 patterns total:
      - 2 recovery/flat patterns
      - 4 platforming patterns (1–3 platforms)
      - 2 obstacle patterns (1–2 blocks)
  - grid snapping (recommended): author all pattern offsets on a `16.0` world-unit grid.
  - determinism rule (locked): choose chunk pattern from `(seed, chunkIndex)` (not frame time), so spawn order is stable across refactors.
    - recommended implementation: a pure `mix32(seed, chunkIndex, salt)` hash -> `patternIndex = hash % patterns.length`
    - do not “step a global RNG” per chunk (refactor-prone).
- [x] Add streaming chunk spawner (Core):
  - maintain `nextChunkIndex` / `nextChunkStartX` and spawn chunks while `cameraRight + margin >= nextChunkStartX`.
  - cull chunks/solids when `chunkEndX < cameraLeft - margin` so the world stays bounded.
  - rebuild `StaticWorldGeometryIndex` only when geometry changes (spawn/cull), not every tick.
  - culling implementation detail (deterministic, chunk-based):
    - maintain an ordered queue/list of active chunks with `startX/endX` and their generated solids.
    - while the oldest chunk is fully behind the view (`endX < cameraLeft - cullBehindMargin`), pop it.
    - when chunks are spawned/culled, rebuild `StaticWorldGeometry.solids` by concatenating solids from active chunks (ground plane stays separate/always-on), then rebuild the index.
- [x] Add deterministic enemy spawns (Core):
  - no pickups/collectibles in V0.
  - recommended V0 policy: tie enemy spawns to chunk patterns via spawn markers.
    - each pattern declares 0–2 spawn markers (relative X/Y), chosen to be “safe” for that pattern layout.
    - decide which enemy (if any) to spawn using `(seed, chunkIndex, markerIndex, salt)` for determinism.
- [x] Tests (Core):
  - same seed + same commands => identical spawned chunk solids after N ticks (including after culling).
  - platform collision invariants unchanged (one-way top still works).

Acceptance:
- Same seed produces the same sequence of chunks/solids/enemy spawns and the same outcomes given the same inputs.
- World streaming stays bounded (culling works) and collision behavior matches the current static-geometry semantics.

---

## Milestone 13 - UX Polish + Debugging

- [ ] Pause overlay (freeze simulation).
- [ ] Debug overlay:
  - FPS, tick, entity count, seed
- [ ] Basic audio hooks via events (optional for V0).
- [ ] “Run end” condition and return to menu.

Acceptance:
- You can play a full run loop (start -> play -> pause -> end -> back to menu) repeatedly.

---

## Minimal Tests (Add When Core Exists)

- [x] Determinism test: same seed + same command stream => identical snapshots (or snapshot hash) after N ticks.
- [x] Collision test: jump/land results in grounded at expected ticks.
- [x] Platform collision tests: land, pass-through from below, walk off ledge.
- [x] Obstacle collision tests: side walls + sideMask.
