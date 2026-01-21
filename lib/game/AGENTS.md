# AGENTS.md - Game Layer

Instructions for AI coding agents working in the **Game** rendering layer (`lib/game/`).

## Game Layer Responsibility

The Game layer is responsible for **visuals only**. It uses the Flame game engine to render the game state produced by Core.

**Critical rule:** Game layer is **never authoritative** for gameplay logic, collision, or state management. All gameplay truth lives in Core.

## Core Snapshot Consumption

### Read-Only Contract

- The Game layer receives `GameStateSnapshot` objects from Core
- **Treat snapshots as read-only** - never mutate snapshot data
- Never simulate or extrapolate gameplay logic in the Game layer

### Interpolation Pattern

For smooth visuals, interpolate between snapshots:

```dart
void render(GameStateSnapshot prevSnapshot, 
            GameStateSnapshot currSnapshot, 
            double alpha) {
  // alpha ranges from 0.0 (prevSnapshot) to 1.0 (currSnapshot)
  
  final prevPos = prevSnapshot.entities[id].position;
  final currPos = currSnapshot.entities[id].position;
  
  final renderPos = prevPos.lerp(currPos, alpha);
  
  // Update sprite position
  sprite.position = renderPos;
}
```

**Rules:**
- Use `prevSnapshot` and `currSnapshot` for interpolation
- `alpha` is the interpolation factor (0.0 to 1.0)
- **Never simulate** - only interpolate between known states
- Never predict future positions or run physics in Game layer

## Flame Component Patterns

### Entity View Components

Entity view components are Flame components that visualize Core entities:

```dart
class PlayerView extends PositionComponent {
  final int entityId;
  
  void update(GameStateSnapshot snapshot, double alpha) {
    // Read entity data from snapshot
    final entity = snapshot.entities[entityId];
    
    // Update visual representation
    position = entity.position;
    animationState = entity.animationState;
  }
}
```

### Component Organization

- **Entity views** (`lib/game/components/`) - Visual representations of Core entities
- **Camera management** - Viewport, camera follow, shake effects
- **Parallax backgrounds** - Multi-layer scrolling backgrounds
- **VFX** - Visual effects (particles, explosions, trails)
- **Debug visualization** (`lib/game/debug/`) - Collision boxes, debug overlays

## World & Camera Rules

### Virtual Resolution

- Pick one **virtual resolution** (world units == virtual pixels)
- Example: 320×180, 640×360, or 1920×1080 depending on art style
- All Core coordinates use this virtual resolution

### Integer Scaling + Letterboxing

- Use **integer scaling** to avoid fractional pixels (prevents shimmering)
- Add **letterboxing** (black bars) when aspect ratio doesn't match
- No fractional scaling - sprite pixels must be crisp

### Pixel Snapping

- Snap camera position to integer pixels inside the scaled viewport
- Snap entity render positions to integer pixels
- This prevents sub-pixel jitter in pixel-art games

```dart
// Example pixel snapping
final snappedX = (position.x).floor().toDouble();
final snappedY = (position.y).floor().toDouble();
sprite.position = Vector2(snappedX, snappedY);
```

## Asset Management

### Per-Scene Loading

- Assets are loaded **per scene**, not at boot
- Load assets when entering a game route/level
- Unload assets when leaving the route/level

**Example:**
```dart
class LevelScene {
  Future<void> load() async {
    await images.load('level1/background.png');
    await images.load('level1/tileset.png');
    // ... load level-specific assets
  }
  
  void unload() {
    images.clear();
  }
}
```

### No Loading During Gameplay

- **Never load assets during active gameplay**
- Load all required assets during a loading screen
- Preload critical assets before gameplay starts
- Use asset pools for frequently spawned entities

## Input Handling

### Convert Input to Commands

The Game layer can receive input (e.g., from Flame's input system), but it must **convert input to Commands** and send them to the controller.

```dart
@override
void onTapDown(TapDownEvent event) {
  // Convert Flame input to Core command
  final command = JumpCommand(
    tickNumber: controller.currentTick,
    playerId: 0,
  );
  
  // Send to controller
  controller.enqueueCommand(command);
}
```

**Rules:**
- Never modify Core state directly from input handlers
- Always use the Command pattern
- Let Core process commands during its tick execution

## Game Events

Game layer consumes `GameEvent` objects from Core to trigger visual/audio effects:

```dart
void handleEvents(List<GameEvent> events) {
  for (final event in events) {
    switch (event) {
      case HitEvent(:final position, :final damage):
        spawnHitVFX(position, damage);
        playSFX('hit.wav');
        break;
        
      case ScreenShakeEvent(:final intensity, :final duration):
        cameraShake(intensity, duration);
        break;
        
      // ... handle other event types
    }
  }
}
```

**Event types:**
- Spawn/despawn events → Create/remove entity views
- Hit/damage events → Spawn VFX, play sounds
- Screen shake events → Apply camera effects
- Reward events → Display score popups, notifications

## Flame API Preferences

### Use Flame for Render Concerns

Flame provides excellent tools for rendering. Use them:

- **Camera components** - `CameraComponent`, `Viewport`, camera follow
- **Parallax rendering** - `ParallaxComponent` for scrolling backgrounds
- **Effects** - `MoveEffect`, `ScaleEffect`, `OpacityEffect`, etc.
- **Sprite animations** - `SpriteAnimationComponent`
- **Particles** - `ParticleSystemComponent` for VFX

### Don't Use Flame for Gameplay

Flame also provides gameplay-adjacent features that we **do not use**:

- ❌ **Flame collision system** - Core handles all collision authoritatively
- ❌ **Flame physics** - Core handles all physics
- ❌ **Flame game loop timing** - Core uses fixed ticks, not Flame's variable dt

## Common Game Subsystems

- **GameController** (`lib/game/game_controller.dart`) - Bridges UI, Game, and Core
- **RunnerFlameGame** (`lib/game/runner_flame_game.dart`) - Main Flame game instance
- **Components** (`lib/game/components/`) - Entity views and visual components
- **Input** (`lib/game/input/`) - Input handling and command conversion
- **Themes** (`lib/game/themes/`) - Visual themes and color schemes
- **Debug** (`lib/game/debug/`) - Debug visualization and tools

## What NOT to Do in Game Layer

- ❌ **Do not simulate gameplay** - that's Core's job
- ❌ **Do not use Flame collision as gameplay truth** - Core is authoritative
- ❌ **Do not mutate Core state** - send Commands instead
- ❌ **Do not mutate snapshots** - they are read-only
- ❌ **Do not load assets during gameplay** - preload everything
- ❌ **Do not use variable dt for gameplay** - Core uses fixed ticks

## Best Practices

✅ **Interpolate for smooth visuals** using prev/curr snapshots
✅ **Use Flame components** for camera, parallax, effects
✅ **Convert input to Commands** before sending to Core
✅ **Consume events** to trigger VFX and SFX
✅ **Load assets per-scene** and unload when done
✅ **Snap positions** for pixel-perfect rendering

---

**For cross-layer architecture and general rules**, see [lib/AGENTS.md](file:///c:/dev/rpg_runner/lib/AGENTS.md).
