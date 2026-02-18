# AGENTS.md - UI Layer

Instructions for AI coding agents working in the **UI** layer (`lib/ui/`).

## UI Layer Responsibility

The UI layer is responsible for **Flutter widgets**: menus, overlays, navigation, settings, and HUD elements.

**Critical rule:** UI **never modifies gameplay state directly**. It sends **Commands** to the game controller.

## House Style (Clean UI Code)

Default conventions in this repo aim for **clean, theme-driven, low-surface-area widgets**.

### Component Theming

- Use `ThemeExtension` for global tokens (`UiTokens`) and for component themes (e.g. `UiButtonTheme`, `UiHubTheme`).
- **Do not add component-specific sizing/colors to `UiTokens`**. If something is specific to a component, it belongs in that component’s theme extension.
- Prefer a single “resolved spec” object for components (e.g. `resolveSpec(...) → UiButtonSpec`) to keep widget build methods small and avoid scattered lookups / local “resolved*” variables.

### Component APIs

- Expose **semantic inputs only** (`variant`, `size`, `enabled`, callbacks, ids). Avoid ad-hoc styling knobs (`width/height/padding/textStyle/colors`) unless explicitly requested.
- Prefer enums (`Variant`, `Size`) + theme-defined presets (width/height/typography/padding) over per-call overrides.
- If the user asks for “theme”, “cleanup”, or “make it consistent”, assume it’s OK to do the full refactor in one pass: add the theme extension, migrate all call sites, and delete the legacy tokens/params.

### Modern Flutter APIs

- Use `WidgetState` / `WidgetStateProperty` (not `MaterialState*`).
- Use `Color.withValues(alpha: …)` (not `withOpacity`).

### System UI

- Avoid calling `SystemChrome` inside widget `build` methods.
- Prefer app-level orchestration (route observer / lifecycle) for global fullscreen behavior.
- Use `ScopedSystemUiMode` only when a behavior truly needs to be scoped to a subtree/route.

## Command Pattern

### Sending Commands to Core

UI interacts with Core gameplay through the Command pattern:

```dart
class PauseButton extends StatelessWidget {
  final GameController controller;
  
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.pause),
      onPressed: () {
        // Send command to Core
        controller.enqueueCommand(
          PauseCommand(tickNumber: controller.currentTick)
        );
      },
    );
  }
}
```

**Rules:**
- Never access Core state directly
- Never mutate gameplay state from UI code
- Always use Commands for gameplay interactions
- Examples: pause, resume, level selection, ability activation

### Command Examples

Common UI → Core command patterns:

- **Level selection** → `LoadLevelCommand(levelId: 'level_2')`
- **Pause/Resume** → `PauseCommand()` / `ResumeCommand()`
- **Settings changes** → `UpdateSettingsCommand(volume: 0.8)`
- **Player actions** → Typically from Game input, but UI can also send them (e.g., virtual buttons)

## Widget Organization

### HUD Components

HUD (Heads-Up Display) elements are overlays that show game state:

- **Health bars** (`lib/ui/hud/`) - Display player health from snapshots
- **Score display** - Show current score, combo, multiplier
- **Progress indicators** - Level progress, distance traveled
- **Ability cooldowns** - Visual timers for abilities
- **Mini-map** (if applicable) - Simplified world view

**Pattern:**
```dart
class HealthBar extends StatelessWidget {
  final GameStateSnapshot snapshot;
  
  @override
  Widget build(BuildContext context) {
    final health = snapshot.player.health;
    final maxHealth = snapshot.player.maxHealth;
    
    return LinearProgressIndicator(
      value: health / maxHealth,
      backgroundColor: Colors.red[900],
      valueColor: AlwaysStoppedAnimation(Colors.red),
    );
  }
}
```

### Menu Screens

Menu screens for navigation and settings:

- **Play hub + setup** (`lib/ui/pages/`) - Start run, setup, meta routes
- **Pause menu** - Resume, restart, quit to menu
- **Game over screen** - Score, retry, quit
- **Level selection** - Choose which level to play
- **Settings** - Audio, graphics, controls

### Controls

Input widgets that send commands:

- **Virtual joystick** (`lib/ui/controls/`) - Directional input
- **Action buttons** - Jump, strike, ability buttons
- **Touch zones** - Swipe gestures, tap-to-jump areas

## State Management

### UI State vs Gameplay State

**Separation of concerns:**

- **Gameplay state** - Lives in Core, authoritative, deterministic
- **UI state** - Lives in UI layer, ephemeral, non-deterministic
  - Examples: menu visibility, animation states, selected options

### RunnerGameUIState

UI-specific state management:

```dart
class RunnerGameUIState {
  bool isPaused = false;
  bool isMenuOpen = false;
  String? selectedLevel;
  
  // UI state only - not part of Core
}
```

**Rules:**
- Keep UI state separate from gameplay state
- UI state can be mutable and non-deterministic
- Gameplay state must go through Core and Commands

### Scoped State

Use scoped state management (`lib/ui/scoped/`) for widgets that need shared UI state without affecting Core:

- Provider/InheritedWidget patterns for UI state
- Never use for gameplay state
- Keep scope narrow (menu-level, screen-level)

## Embedding Contract

### Public API

The game is embeddable via a stable public API:

- **`lib/runner.dart`** - Public entry point, exports main widgets/routes
- **`RunnerGameWidget`** - Main game widget component
- **`RunnerGameRoute`** - Flutter route for navigation

**Usage:**
```dart
// In another app
import 'package:rpg_runner/runner.dart';

Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => RunnerGameWidget(levelId: LevelId.field),
  ),
);
```

### Dev Host

- **`lib/main.dart`** - Development host/demo app only
- Treat as a development harness, not part of the public API
- Safe to modify for development/testing without affecting embedding

## Viewport Integration

### Letterboxing & Safe Areas

UI overlays must respect the game viewport:

```dart
class GameOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          // Game viewport (rendered by Flame)
          GameWidget(),
          
          // UI overlay (respects safe areas)
          Positioned(
            top: 16,
            left: 16,
            child: HealthBar(),
          ),
        ],
      ),
    );
  }
}
```

**Rules:**
- Use `SafeArea` to avoid notches/system UI
- Position HUD elements outside the game viewport if needed
- Respect letterboxing (black bars) in layout
- Don't cover critical gameplay areas with UI

## Snapshot Consumption

UI can read snapshots for display purposes:

```dart
class ScoreDisplay extends StatelessWidget {
  final GameStateSnapshot snapshot;
  
  @override
  Widget build(BuildContext context) {
    return Text(
      'Score: ${snapshot.score}',
      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
    );
  }
}
```

**Rules:**
- Read snapshot data for display only
- Never mutate snapshots
- Never simulate or extrapolate gameplay from snapshots in UI

## Level Selection

Level selection is a UI concern that sends commands to Core:

```dart
class LevelSelectScreen extends StatelessWidget {
  final GameController controller;
  
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        LevelButton(
          levelId: 'level_1',
          onTap: () {
            controller.enqueueCommand(
              LoadLevelCommand(levelId: 'level_1')
            );
            Navigator.push(context, GameRoute());
          },
        ),
        // ... more levels
      ],
    );
  }
}
```

**Pattern:**
- Display level metadata (name, preview, locked state)
- Send `LoadLevelCommand` when level is selected
- Navigate to game route after command is sent
- Core handles actual level loading deterministically

## Common UI Subsystems

- **Controls** (`lib/ui/controls/`) - Input widgets (joystick, buttons)
- **HUD** (`lib/ui/hud/`) - In-game overlays (health, score, progress)
- **Assets** (`lib/ui/assets/`) - UI preview asset lifecycle (hub/run cache + warmup)
- **App** (`lib/ui/app/`) - App shell, routes, navigation
- **Bootstrap** (`lib/ui/bootstrap/`) - Loader + startup tasks
- **State** (`lib/ui/state/`) - Menu selection state + persistence
- **Pages** (`lib/ui/pages/`) - Menu/meta screens (hub, setup, meta, lab)
- **Levels** (`lib/ui/levels/`) - Level selection UI
- **Leaderboard** (`lib/ui/leaderboard/`) - Score display and rankings
- **Scoped** (`lib/ui/scoped/`) - Scoped state management
- **Viewport** (`lib/ui/viewport/`) - Viewport and safe area management

## What NOT to Do in UI Layer

- ❌ **Do not modify gameplay state directly** - use Commands
- ❌ **Do not simulate gameplay** - that's Core's job
- ❌ **Do not access Core internals** - use snapshots and commands
- ❌ **Do not mix UI state with gameplay state** - keep them separate
- ❌ **Do not mutate snapshots** - they are read-only

## Best Practices

✅ **Send Commands** for all gameplay interactions
✅ **Read snapshots** for display purposes only
✅ **Separate concerns** - UI state vs gameplay state
✅ **Respect viewport** - use SafeArea and letterboxing
✅ **Keep embedding API stable** - `lib/runner.dart` is public
✅ **Use Flutter best practices** - StatelessWidget, composition, etc.

---

**For cross-layer architecture and general rules**, see [lib/AGENTS.md](file:///c:/dev/rpg_runner/lib/AGENTS.md).
