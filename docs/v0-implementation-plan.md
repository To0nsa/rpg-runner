# Implementation Plan (V0 Checklist)

This document turns `docs/plan.md` into an executable checklist for getting a playable V0 running end-to-end.

## V0 Decisions (Locked)

* Runner model: player moves in world coordinates; camera scrolls to follow.
* Input mapping:
  * Left: on-screen joystick (move left/right).
  * Right: three buttons (Jump, Dash, Attack).
  * Tap on the game view: reserved for aiming + casting spells (exact cast rules defined later).
* Ability specs, enemy AI rules, and spawn rules: iterate after “run + jump” is working.

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
  - [x] `Movement` (grounded + timers: coyote/jump-buffer/dash)
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

## Milestone 3 — Mobile Controls (Joystick + 3 Buttons + Tap-to-Aim)

- [ ] Flutter overlay for:
  - joystick left
  - Jump/Dash/Attack buttons right
- [ ] Command mapping:
  - joystick -> `MoveAxis`
  - Jump button -> `JumpPressed`
  - Dash button -> `DashPressed` (wired, no gameplay effect until milestone 4)
  - Attack button -> `AttackPressed` (wired, no gameplay effect until milestone 4)
  - tap/drag on game view -> `AimAt(screenPos)` or `AimAtWorld(worldPos)` (choose one; convert consistently)

Acceptance:
- No keyboard required; player can run/jump via touch controls.

---

## Milestone 4 — Resources + Abilities (Minimal First Pass)

Note: exact costs/cooldowns can be placeholders until tuned.

- [ ] Add core resources:
  - `Mana`, `Endurance`, `Cooldowns`
- [ ] Add `AbilitySystem`:
  - spends mana/endurance
  - applies cooldown ticks
  - spawns projectiles/hitboxes via core events
- [ ] Player abilities:
  - Sword hit: short-lived melee hitbox in front of player
  - Ice bolt: projectile with speed + lifetime
- [ ] HUD shows: health, mana, endurance.

Acceptance:
- Pressing Attack produces a melee hit; aiming + casting spawns an ice bolt; resources change accordingly.

---

## Milestone 5 — Enemies (Basic AI + Attacks)

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

## Milestone 6 — Deterministic Spawning (First Pass)

- [ ] Define chunk size and a deterministic “track” generator driven by `seed`.
  - Start simple: a fixed list of hand-authored chunk patterns (ground + platforms + obstacles + pickups).
- [ ] Spawn the two enemy types and collectibles via deterministic rules.

Acceptance:
- Same seed produces the same sequence of chunks/spawns and the same outcomes given the same inputs.

---

## Milestone 7 — UX Polish + Debugging

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
