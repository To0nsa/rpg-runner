# Implementation Plan (V0 Checklist)

This document turns `docs/plan.md` into an executable checklist for getting a playable V0 running end-to-end.

## V0 Decisions (Locked)

* Runner model: player moves in world coordinates; camera scrolls to follow.
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
  - [x] `MovementSystem` (accel/decel, gravity, coyote time, jump buffer, dash; writes velocities only)
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
- [x] Add `CastSystem` (or `AbilitySystem` split into focused systems):
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
- [x] Add `MeleeSystem` + hit resolution:
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

- [ ] Flying enemy:
  - follows player with a target offset
  - periodically casts a lightning bolt projectile toward player
- [ ] Ground enemy:
  - follows player on ground (simple horizontal pursuit)
  - melee hit when in range
  - fire cone: approximate with a short-lived AABB hitbox area in front
- [ ] Damage rules + invulnerability ticks in core.

Acceptance:
- Enemies can damage the player, and the player can defeat them (or at least interact via hits).

---

## Milestone 8 - Deterministic Spawning (First Pass)

- [ ] Define chunk size and a deterministic “track” generator driven by `seed`.
  - Start simple: a fixed list of hand-authored chunk patterns (ground + platforms + obstacles + pickups).
- [ ] Spawn the two enemy types and collectibles via deterministic rules.

Acceptance:
- Same seed produces the same sequence of chunks/spawns and the same outcomes given the same inputs.

---

## Milestone 9 - UX Polish + Debugging

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
