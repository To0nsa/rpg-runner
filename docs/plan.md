# Mini-Game Architecture Plan

This document defines the **architecture baseline** for a pixel‑art mini‑game embedded inside a Flutter app, built with **Flame**, and designed to scale to **online multiplayer later**.

The goal is:

* clean separation of concerns
* mobile‑safe performance (Android + iOS)
* no rewrite when adding online features

This file is a **living document** and will evolve as the project grows.

---

## 1. High‑Level Architecture

The project is split into **three hard layers**:

1. **Game Core (Dart)** – simulation & rules (authoritative truth)
2. **Flame Render Layer** – visuals only
3. **Flutter UI Layer** – menus, navigation, overlays

These layers must never leak responsibilities into each other.

---

## 2. Online-Ready Constraints

Even in offline mode, follow these rules:

* Commands are the only inputs
* Fixed tick simulation
* Seeded RNG
* Serializable state
* Stable entity IDs

This enables:

* authoritative server later
* replays
* deterministic debugging

---

### 2.1 V0 Vertical Slice (Playable Runner)

V0 goal: a fully playable offline runner with the final architectural boundaries (core authoritative, Flame as view, Flutter UI for menus/HUD).
Implementation milestones and checklists live in `docs/v0-implementation-plan.md`.

World:

* A continuous ground band (the default collision surface).
* Platforms (jumpable/landable) and obstacles (must avoid / collide).
* Parallax background (at least 2 layers).

Player:

* Can run, jump, sword hit, and cast an ice bolt.
* Has `health`, `mana`, and `stamina` (V0: jump/dash spend stamina).

Enemies:

* One flying enemy: follows the player and casts a lightning bolt.
* One ground enemy: follows the player and can hit the player (melee hitbox). (Fire cone can be added later.)

Collectible:

* At least one collectible type (e.g., coin or resource pickup).

V0 definition of done:

* Deterministic run given the same `seed` and the same command stream.
* HUD shows health/mana/stamina and at least one progression stat (distance/score).

---

## 3. Game Core (Pure Dart)

**Rules:**

* No Flutter imports
* No Flame imports
* No rendering or audio code

### Responsibilities

* Fixed-tick simulation (30 or 60 Hz)
* Entity state (position, velocity, health, etc.)
* Collision & gameplay rules (core-owned for determinism)
* AI decisions
* RNG (seeded, deterministic)
* Difficulty scaling

Note:

* Flame’s collision system is excellent for local gameplay and tooling, but using it as the authoritative collision/physics layer would require Flame imports and may reduce determinism for future networking. Prefer keeping authoritative collision in core; Flame collision can still be used for debug visualization and editor-like tooling.

### Entity Architecture: Composition over Inheritance

**Default rule:** Use a *data-oriented* entity model with **components** (composition). Avoid deep inheritance trees.

#### Why composition

* Skins/cosmetics and future online logic require you to serialize/replicate state cleanly.
* Composition keeps entities small, testable, and makes features reusable (e.g., Health + Hitbox + DamageOnContact).
* Inheritance tends to mix concerns (render/audio/AI) and becomes rigid when features combine.

#### Recommended model

* `EntityId` (stable)
* `EntityKind` (Player, Enemy, Projectile, Obstacle, Pickup…)
* `Map<ComponentType, Component>` (or a struct-of-components store)

Common components (examples):

* `Transform` (pos, vel)
* `Collider` (AABB + layer/mask)
* `Health`
* `AnimatorState` (logical state only, not textures)
* `Lifetime` (despawn timer)
* `DamageOnContact`
* `Projectile`
* `AI` (state machine variables)

#### Systems

Systems operate over entities that have required components:

* `PlayerMovementSystem`
* `CollisionSystem`
* `CombatSystem`
* `AISystem`
* `SpawnerSystem`

**Hard rule:** systems live in core; Flame components are just views.

### Core Concepts

#### Fixed Tick

* Simulation runs on a fixed timestep
* Tick count is the single time authority

#### Commands (Inputs)

  * Player and system actions are expressed as commands
  * Commands are queued with a tick index
  
  Examples:
  
  * MoveLeft
  * Jump
  * Attack
  * Pause

  V0 aiming notes:
  * Aim is pointer-driven: UI computes `AimDir(dir)` from (playerWorldPos -> pointerWorldPos).
  * Touch: tap triggers `CastPressed` (aim dir computed from the tap position).
  * Mouse/keyboard/controller mappings are debug-only or post-V0.

  #### State Snapshots

* Core exposes immutable snapshots of game state
* Renderer and UI **read only**

#### Events

* Core emits events (hit, spawn, play sound, etc.)
* Events are transient and consumed once

---

## 4. Flame Render Layer

**Rules:**

* Never owns gameplay truth
* Never modifies core state directly

### Responsibilities

* Sprite rendering
* Animations
* Camera & parallax
* Visual effects
* Sound playback (triggered by events)

Pixel-art note:

* Prefer render-only tools that respect the pixel-perfect contract (integer scaling and snapping, nearest-neighbor filtering). Flame's `ParallaxComponent` is a good fit for background layers as long as it is configured to avoid blur and does not become gameplay-authoritative.

### Model

* One Flame component per entity ID
* Position/rotation/animation driven by core state
* Visual interpolation allowed (render-only)

---

## 5. Flutter UI Layer

**Rules:**

* UI never touches physics or rules
* UI sends high-level intents only

### Responsibilities

* App navigation
* Menus (pause, inventory, settings)
* Overlays (HUD, debug)
* Input routing (touch) into tick-stamped Commands
* Launching and closing the mini-game

V0 note:
* V0 targets mobile only (iOS + Android).
* Keyboard/mouse/controller support is debug-only or post-V0.

### State Management

* Keep the mini-game embeddable: pass the `GameController` explicitly to UI, and keep UI-only state local to widgets.
* If an app uses a DI/state solution, scope it explicitly at the app/route level (avoid the mini-game widget creating its own container).

---

## 6. Game Controller (Bridge Layer)

The GameController is the **only bridge** between layers.

### Responsibilities

* Owns the GameCore instance
* Owns the command queue
* Runs the fixed tick loop
* Exposes:

  * current GameState snapshot
  * event stream

UI and Flame talk **only** to the controller.

---

## 7. Procedural Infinite Runner Design

### World Generation

* Chunk‑based generation
* Spawn tables driven by difficulty
* Deterministic with seed

### Difficulty Scaling

* Function of distance and/or time
* Spawn budget system

---

## 8. Minimal Component Set (Runner)

This section defines the **minimum viable component + system set** for the runner so we can ship quickly while staying online-ready.

### 8.1 Core Entities (kinds)

* Player
* Enemy (e.g., Demon)
* Projectile (player or enemy)
* Obstacle / Platform piece
* Pickup (coins, health)
* Hazard (spikes, lava)
* Trigger (checkpoint / tutorial zone)

### 8.2 Minimal Components

#### Always-use

* **Transform**: position (x,y), velocity (vx,vy)
* **Body**: integration flags (gravityScale, maxSpeed, grounded)

#### Collision

* **ColliderAabb**: half-extents, offset, layer, mask
* **CollisionState**: grounded, hitNormal, touchingIds (optional for debug)

Notes:

* Authoritative collision uses these core colliders/systems.
* Flame hitboxes/collidables are optional and should be treated as a *render/debug* view (built from snapshots), not as gameplay truth.

#### Combat

* **Health**: current, max (and later: invulnTicks)
* **Mana**: current, max, regenPerSecond
* **Endurance**: current, max, regenPerSecond
* **Cooldowns**: remainingTicks per ability (sword, icebolt, enemy spells, etc.)
* **Spellbook/Loadout** (optional for V0): which `SpellId`s an entity can cast
* **SpellCatalog** (data, not a component): lookup table for spell stats by `SpellId`
* **DamageOnContact**: damage, knockback, faction filter
* **Projectile**: speed, lifetimeTicks, pierce, ownerId
* **Hitbox** (melee): shape, activeTicks, ownerId, hitOnceSet

Implementation note:

* Keep these as separate SoA component stores (`HealthStore`, `ManaStore`, `EnduranceStore`, `CooldownStore`, etc.) unless profiling shows a strong need to pack them together.

#### AI / Behavior

* **Brain**: state enum + timers (simple FSM variables)
* **Targeting**: targetId (usually Player), desiredRange

#### Lifetime / Spawn

* **Lifetime**: remainingTicks (despawn)
* **SpawnerTag**: spawnGroupId (optional for procedural systems)

#### Cosmetics / Animation (logical only)

* **Appearance**: skinId, variantId, layers (hat/weapon)
* **AnimState**: logical animation key (Idle/Run/Jump/Hit/Cast)

> Rendering assets/textures are NOT referenced in core.

### 8.3 Minimal Systems (tick order)

1. **InputSystem**: apply Commands to Player (and optionally AI)
2. **AISystem**: update Brain → writes desired actions
3. **PlayerMovementSystem**: compute velocities only (gravity, accel/decel, jump/dash state)
4. **CollisionSystem**: integrate positions + resolve collisions (sets grounded)
5. **ResourceRegenSystem**: regen hp/mana/stamina (tick-based)
6. **AbilitySystem** (split recommended): spend resources, apply cooldowns, spawn projectiles/hitboxes
7. **ProjectileSystem**: move projectiles + despawn on lifetime end
8. **CombatSystem**: apply hits/damage (projectiles + hitboxes), invuln, emits events
9. **SpawnerSystem**: procedural chunk/spawn budget
10. **CleanupSystem**: despawn by Lifetime/out-of-bounds

Rule:

* Do not rely on Flame collision callbacks to drive gameplay state. If Flame collision is used at all, it is for debug visualization/authoring and must not be authoritative.

### 8.4 Minimal Events

* SpawnEvent(entityId, kind)
* DespawnEvent(entityId)
* HitEvent(attackerId, victimId, damage, hitPos, hitDir)
* PlaySfxEvent(key)
* ScreenShakeEvent(intensityTicks)
* RewardEvent(type, amount)

---

## 9. World Storage Design (Core)

This project uses **Struct-of-Arrays (SoA) with sparse sets** as the definitive entity storage model.

### 9.1 EntityId strategy

* `EntityId` = monotonically increasing `int`
* IDs are **not reused** (simpler, deterministic, online-friendly)
* Dead entities are marked destroyed; their slots remain unused

Rationale:

* Avoids edge cases with stale references
* Simplifies replay, debugging, and networking
* Runner-scale entity counts make this acceptable

---

### 9.2 SparseSet<T> layout (canonical)

Each component type owns its own sparse set.

Internal layout:

* `List<EntityId> denseEntities` (dense list of entity ids that have this component)
* SoA arrays for component fields aligned with `denseEntities` (e.g. `posX[]`, `posY[]`, ...)
* `List<int> sparseIndexPlus1ById` (indexed by `EntityId`, value = `denseIndex + 1`, or `0` when absent)

Properties:

* O(1) add / remove / lookup
* Dense iteration (cache-friendly)
* Stable iteration order (by insertion unless explicitly sorted)

---

### 9.3 World API (strict)

The `World` is the *only* owner of component storage.

Mandatory API:

* `EntityId createEntity()`
* `void destroyEntity(EntityId id)`

Component access:

* `bool has<T>(EntityId id)`
* `T get<T>(EntityId id)` (asserts existence)
* `T? tryGet<T>(EntityId id)`
* `void add<T>(EntityId id, T component)`
* `void remove<T>(EntityId id)`

Queries:

* `Iterable<EntityId> query1<T>()`
* `Iterable<EntityId> query2<A, B>()`
* `Iterable<EntityId> query3<A, B, C>()`

**Rules:**

* Systems never touch sparse sets directly
* Systems never store references to dense arrays across ticks

---

### 9.4 System iteration rules

* Systems iterate entities via queries only
* No mutation of component membership while iterating the same query
* Structural changes (add/remove components, destroy entities) are queued and applied after system execution

This guarantees:

* deterministic order
* no iterator invalidation

---

### 9.5 Snapshot extraction

At the end of each tick:

* Build a **GameState snapshot** from SoA storage
* Snapshot contains only data required by renderer/UI
* No references to internal SoA arrays leak out

This snapshot boundary is critical for:

* render decoupling
* networking
* replay

---

## 10. Fixed Tick Loop (GameController)

This section defines how the simulation runs deterministically while rendering remains variable.

### 10.1 Core rules

* Simulation tick rate is fixed: `TICK_HZ = 60` (or 30 if needed).
* Core updates by integer ticks only.
* Renderer reads snapshots at variable frame rate.
* Commands are time-stamped with a tick index.

---

### 10.2 GameController responsibilities

* Owns:

  * `GameCore core`
  * command queue `Map<int tick, List<Command>>`
  * latest snapshots: `prev`, `curr`
  * event buffer (drained by render/UI)

* Exposes:

  * `GameStateSnapshot get snapshot`
  * `GameStateSnapshot? get prevSnapshot`
  * `double get alpha` (render interpolation factor 0..1)
  * `void enqueue(Command cmd)`
  * `List<GameEvent> drainEvents()`

---

### 10.3 Accumulator model (variable frame → fixed ticks)

Let:

* `dtFrame` = time since last frame (seconds)
* `dtTick = 1.0 / TICK_HZ`

Maintain:

* `accumulator += clamp(dtFrame, 0, dtFrameMax)`

Tick loop:

* while `accumulator >= dtTick`:

  1. `applyCommandsForTick(core.tick + 1)`
  2. `core.stepOneTick()`
  3. `prev = curr; curr = core.buildSnapshot()`
  4. `accumulator -= dtTick`

Interpolation:

* `alpha = accumulator / dtTick`

**Important:** clamp `dtFrame` to avoid spiral-of-death when app resumes.

---

### 10.4 Command timing rules

* `Command` includes a `tick`.

* For local play:

  * controller assigns `tick = core.tick + inputLead`
  * `inputLead` default = 1 (queue for next tick)

* For future online:

  * server validates tick window
  * client may predict + reconcile

**Rule:** commands are applied *only* at their declared tick.

---

### 10.5 Determinism rules

* RNG is seeded and owned by core.
* Any randomness must be derived from core RNG.
* No time-based randomness using wall-clock.

---

### 10.6 Pause behavior

Two modes:

#### Mode A (recommended): freeze simulation

* When paused:

  * do not advance accumulator into ticks
  * keep rendering the last snapshot

#### Mode B: UI-only pause

* Core continues (useful for online)
* Not used initially

---

### 10.7 App lifecycle behavior (mobile)

* On background/resume:

  * clamp `dtFrame`
  * optionally force `accumulator = 0` to avoid massive catch-up

**Rule:** never run 1000 ticks to catch up after resume.

---

## 11. GameState Snapshot Schema (Renderer Contract)

This section defines the **immutable snapshot** sent from core → render/UI. This is the most important contract in the architecture.

### 11.1 Principles

* Snapshots are **read-only** and **immutable**.
* Snapshots contain **only what the renderer/UI needs**.
* No internal SoA arrays, indices, or component references may leak.
* Snapshots are **serializable** (for future networking/replays).
* Core remains authoritative: renderer may *interpolate* but never *simulate*.

---

### 11.2 Snapshot timing

* Core sim runs at fixed tick rate.
* After each tick, core produces `GameStateSnapshot`.
* Renderer reads the latest snapshot each frame.

Optional (for smoother visuals):

* keep **previous snapshot** as well and interpolate positions at render time.

---

### 11.3 Types

#### 11.3.1 Scalar types

* `EntityId`: `int`
* `Vec2`: `{ double x, double y }`
* `Angle`: `double` (radians) or `int` (quantized). Decide once.

**Pixel-art note:** core can use doubles for physics, renderer can snap to pixels.

---

### 11.4 Core → Render data model

#### 11.4.1 GameStateSnapshot

Fields (minimum viable):

* `int tick`
* `int seed`
* `double distance` (or `int distancePx`)
* `bool paused`
* `PlayerHudSnapshot hud`
* `List<EntityRenderSnapshot> entities`
* `List<DespawnedEntity> despawned` (optional; can be inferred by missing IDs)

Notes:

* `entities` is a flat list: renderer maps `entityId -> view component`.
* Avoid nested graphs; keep it easy to serialize.

---

#### 11.4.2 PlayerHudSnapshot

* `double hp`
* `double hpMax`
* `double mana`
* `double manaMax`
* `double stamina`
* `double staminaMax`
* `int score`
* `int coins`
* `int combo` (optional)

HUD is separated from entity list so UI can update without scanning entities.

---

#### 11.4.3 EntityRenderSnapshot

Required fields:

* `int id`
* `EntityKind kind`
* `Vec2 pos`
* `Vec2 vel` (optional but useful for animation / facing)
* `double z` (optional sort layer)
* `Facing facing` (Left/Right)
* `AnimKey anim` (Idle/Run/Jump/Hit/Cast/Death…)
* `int animFrame` (optional; usually renderer owns frame timing)

Collision debug (optional, behind a flag):

* `AabbSnapshot? aabb`

Cosmetics / appearance:

* `AppearanceSnapshot appearance`

Health display (optional):

* `HealthBarSnapshot? healthBar`

---

#### 11.4.4 AppearanceSnapshot

This is *logical* appearance, not textures.

* `String skinId` (e.g., "default", "skin01")
* `String variantId` (optional)
* `Map<String, String> layers` (e.g., {"hat": "cap01", "weapon": "wand02"})

Renderer maps these IDs to sprites/atlases.

---

#### 11.4.5 Enums

* `EntityKind`: Player, Enemy, Projectile, Obstacle, Pickup, Hazard, Trigger
* `AnimKey`: Idle, Run, Jump, Fall, Hit, Cast, Death, Spawn
* `Facing`: Left, Right

Keep enums stable because they become network protocol.

---

### 11.5 Interpolation policy (render-only)

Renderer may render smooth motion by interpolating between snapshots:

* keep `prevSnapshot` and `currSnapshot`
* compute `alpha` from frame time within tick
* interpolate `pos` only (not gameplay state)

**Pixel-art rule:** final rendered position is snapped to integer pixels.

---

### 11.6 Snapshot size & performance

* Avoid sending full component data.
* Only include fields needed for visuals/HUD.
* If entity count grows, add an optimization later:

  * delta snapshots (only changed entities)
  * quantized positions (ints)

Start with full snapshots; optimize when needed.

---

### 11.7 Event delivery (separate from snapshots)

Events are delivered separately from snapshots:

* `List<GameEvent> drainEvents()`

Renderer/UI consumes them once.

---

## 12. Camera Scaling Policy (Pixel-Perfect Rules)

This section defines how the game renders pixel art without blur, shimmer, or distortion across devices.

### 12.1 Goals

* Pixel art is never blurred or filtered.
* World rendering uses integer scaling only.
* World motion is snapped to pixel grid at final render.
* Aspect ratio differences are handled without fractional scaling (crop or letterbox).
* Background parallax may optionally allow sub-pixel scrolling for smoother motion (tradeoff: shimmer).

---

## 12.1.1 Orientation Policy (V0)

V0 is designed for **landscape** gameplay only.

Guidelines:

* The embeddable `RunnerGameWidget` does not force a global orientation policy.
* The route helper `createRunnerGameRoute` can optionally lock the device to landscape while the route is active.
* Host apps must ensure platform orientation support includes landscape (Android manifest / iOS Info.plist), otherwise Flutter cannot rotate into landscape.

### 12.2 Virtual resolution & world units

* Choose one base virtual resolution (V0: `480×270` for 16:9).
* Core/world coordinates are expressed in *virtual pixels*.
* Rule: `1 world unit == 1 virtual pixel`.
* Coordinate convention (recommended): `(0,0)` is top-left, `+X` right, `+Y` down.
* Camera view size is fixed to `(virtualWidth, virtualHeight)` in world units.

---

### 12.3 Viewport scaling & letterboxing

Given:

* `screenWidth`, `screenHeight` (physical pixels)
* `virtualWidth`, `virtualHeight`

Compute:

* `scale = floor(min(screenWidth / virtualWidth, screenHeight / virtualHeight))`
* `renderWidth = virtualWidth * scale`
* `renderHeight = virtualHeight * scale`

Rules:

* Always use integer `scale` (no fractional scaling).
* Center the game viewport in the screen.
* If you choose **contain**, fill remaining space with letterbox/pillarbox (solid color or themed background).
* If `scale < 1` (extremely small window), clamp to `scale = 1` and prefer cropping over fractional scaling.

Alternative (optional):

* To avoid letterboxing, use an integer-scale **cover** mode (scale up until the viewport fully covers the screen, then crop the excess). This fills the whole screen, but cuts off some world content on the long axis.

Flutter note:

* Compute `screenWidth/screenHeight` using physical pixels: `logicalPx * devicePixelRatio`.

---

### 12.4 Pixel snapping rules

* Core may use doubles internally (physics, interpolation inputs).
* Renderer may interpolate between snapshots (`prev`, `curr`) for smooth motion.
* Final rendered positions are snapped to integer pixels inside the scaled viewport.
* Camera position used for rendering is snapped to integer world coordinates.

---

### 12.5 Zoom policy

* Default zoom is `1x`.
* Optional zoom levels are integers only (`2x`, `3x`, ...).
* No fractional zoom.

---

### 12.6 UI vs world rendering

* World rendering follows the virtual resolution, integer scaling, and snapping rules above.
* Flutter UI (menus/HUD) renders in device logical pixels and may scale freely.
* UI that must align with world pixels (pixel frames, in-world UI) is rendered inside the game viewport using the same integer scale.

---

## 13. Asset Strategy (Pixel Art)

### Virtual Resolution

* Choose one virtual resolution (e.g. 320×180 or 480×270)
* World units == pixels at virtual resolution
* Follow section 12 scaling rules (integer scaling + letterboxing)

### Asset Formats

* Sprites: PNG (pixel art)
* Animations: sprite sheets / atlases
* Audio: OGG
* Data: JSON

### Atlases

* game atlas (characters, enemies, VFX)
* UI atlas (icons, buttons)

---

## 14. Asset Loading & Lifecycle

Assets are loaded **per scene**, not at app boot.

### Scene Bundles

* Boot: minimal UI
* Menu: UI atlas + fonts + menu music
* Game: game atlas + backgrounds + SFX

### Rules

* No asset loading during gameplay
* Unload game assets when leaving mini‑game

---

## 15. Cosmetics Strategy

Planned for later but supported from day one.

### Supported Models

* Layered sprites (body, head, accessory)
* Optional full skin atlas swap

### Data‑Driven

* Cosmetics defined in JSON
* Core validates cosmetics
* Renderer applies visuals

---

## 16. App Integration (Mini‑Game in App)

* Mini-game is **not** a separate app
* It is a route/screen inside the host Flutter app
* Router-agnostic (Navigator or go_router)

Embedding rule:

* The game must be exposed as a reusable Flutter **Widget/Route** (e.g., `RunnerGameRoute` / `RunnerGameWidget`) so another app can import and mount it.
* `lib/main.dart` is a development host/demo only; it must not contain assumptions that would prevent embedding (navigation, global state, app-level singletons).

### Lifecycle

1. Enter route
2. Load game assets
3. Start simulation
4. Exit route
5. Dispose controller and unload assets

---

## 17. Save / Restore Strategy (Runner)

This mini-game does not require mid-run persistence.

### 17.1 Rules

* No in-run save states.
* No restoring a run after app restart/kill.
* A run always starts from a clean initial state.

### 17.2 App lifecycle expectations

* Background/pause uses the existing pause policy (freeze simulation).
* If the OS kills the app while in a run, the run is considered lost and the player returns to menu on next launch.

### 17.3 What is allowed to persist (outside the run)

* User settings (audio, controls, accessibility).
* Cosmetic selections / unlock flags.
* Best score / lifetime stats (optional, updated only on run end).

### 17.4 Where persistence lives

* Persistence is owned by the Flutter UI layer (app profile), not the game core.
* Core remains deterministic and ephemeral per run.

---

## 18. Debug & Tooling (Early Priority)

* Debug overlay: FPS, tick, entity count
* Seed display
* Command recording (for replay)
* Logging hooks

---

## 19. Networking Message Schema (Future)

This section sketches a future network protocol that preserves the deterministic core while allowing server authority and optional client prediction.

### 19.1 Goals & invariants

* Server is authoritative and runs the same fixed-tick `GameCore`.
* Clients never send state; they send **commands** only.
* All simulation time is expressed in **ticks** (no wall-clock in gameplay logic).
* Snapshots (`GameStateSnapshot`) remain the primary server -> client contract.
* Enums (`EntityKind`, `AnimKey`, etc.) are treated as protocol-stable.

---

### 19.2 Terminology & identifiers

* `tick`: integer simulation step index.
* `tickHz`: fixed tick frequency agreed at handshake.
* `sessionId`: assigned by the server after handshake and identifies the session.
* `runId`: identifies a specific run instance.
* `playerId`: identifies a player within a run.
* `seq/ack`: message sequencing fields (transport-level), not simulation ticks.
* `inputLead`: recommended client-side tick offset for scheduling local commands (default `1`).

---

### 19.3 Transport & encoding

* Transport-agnostic: works over WebSocket (TCP) initially; can be adapted to UDP later.
* Encoding:

  * MVP: JSON (debuggable, easy iteration).
  * Later: binary (protobuf/flatbuffers) with quantization for bandwidth.

---

### 19.4 Message envelope (all messages)

All messages share a minimal envelope:

* `int v` protocol version
* `String type` message type discriminator
* `String? sessionId` (assigned by server; omitted in `ClientHello`)
* `int? seq` monotonically increasing per sender (optional for TCP, useful for UDP)
* `int? ack` last processed `seq` from the peer (optional)

Rule:

* For UDP, `seq/ack` become required and are used for loss/retry handling.

---

### 19.5 Connection & time sync

#### Client -> Server

* `ClientHello`

  * `String clientVersion`
  * `String desiredRegion` (optional)

#### Server -> Client

* `ServerHello`

  * `int tickHz`
  * `int serverTick`
  * `int inputLead` (recommended default = 1)
  * `int snapshotHz` (may be < `tickHz`)

Rules:

* Clients compute a `tickOffset` so local predicted tick can be mapped into server ticks.
* Wall-clock time is allowed for RTT/keepalive only; gameplay logic remains tick-based.

---

### 19.6 Run lifecycle

#### Client -> Server

* `JoinRun`

  * `String playerName`
  * `AppearanceSnapshot appearance` (optional; server validates)

* `LeaveRun` (optional)

  * `int runId`

#### Server -> Client

* `RunStart`

  * `int runId`
  * `int playerId`
  * `int seed`
  * `int startTick`

* `RunEnd` (optional)

  * `int runId`
  * `int endTick`

* `ServerError` (optional)

  * `String code`
  * `String message`

Rules:

* The run seed is server-assigned; clients treat it as read-only.
* Server validates/normalizes cosmetics (appearance) before applying.

---

### 19.7 Client -> Server: input commands

Commands are time-stamped with ticks. Clients send batches and may resend recent ticks until acknowledged.

* `InputBatch`

  * `int runId`
  * `int playerId`
  * `int fromTick`
  * `int toTick` (inclusive)
  * `List<CommandMsg> commands`

`CommandMsg` (serializable form; protocol-stable):

* `int tick`
* `String kind`
* `Map<String, dynamic> payload` (keep small; prefer ints/bools)

Rules:

* Server accepts commands only within a sliding window around `serverTick` (anti-cheat + sanity).
* Server ignores commands for ticks that are already finalized.
* Commands are applied only at their declared tick (same as local rule).

---

### 19.8 Server -> Client: snapshots & events

#### Snapshots

* `Snapshot`

  * `int runId`
  * `GameStateSnapshot snapshot`
  * `int lastProcessedClientTick` (per player; used for reconciliation)

Notes:

* Server may send full snapshots initially.
* Later optimization: delta snapshots (only changed entities) keyed by `tick`.

#### Events

* Events can be embedded in `Snapshot` or delivered separately:

  * `EventBatch { int runId, int tick, List<GameEvent> events }`

---

### 19.9 Client prediction & reconciliation (future)

* Client predicts its own player locally by applying local commands immediately in a predicted core instance.
* Client keeps a short history ring buffer:

  * commands per tick
  * predicted snapshots (or minimal local player state) per tick

On receiving `Snapshot` at tick `T`:

* If authoritative state differs from predicted at `T`, client rewinds to `T`, applies authoritative state, then replays stored commands up to current predicted tick.
* Renderer continues to interpolate between snapshots; reconciliation never changes core determinism.

---

### 19.10 Bandwidth & quantization (future)

* Positions can be transmitted as `int` virtual pixels (or fixed-point) to reduce size.
* Velocities/angles can be quantized if needed.
* If entity counts grow:

  * delta snapshots
  * entity ID reuse policies
  * per-entity relevance filtering (if applicable)
