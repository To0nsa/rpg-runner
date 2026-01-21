---
description: Add a new playable level to the game
---

# Add New Level Workflow

This workflow guides you through adding a new playable level to the game following the data-first, deterministic architecture.

## Prerequisites

- Understand the level system contract (see [lib/AGENTS.md - Level System](file:///c:/dev/rpg_runner/lib/AGENTS.md))
- Understand Core determinism requirements (see [lib/core/AGENTS.md](file:///c:/dev/rpg_runner/lib/core/AGENTS.md))

## Steps

### 1. Define Level Data in Core

Create a new level definition in `lib/core/levels/`:

```dart
// lib/core/levels/level_2_definition.dart
class Level2Definition extends LevelDefinition {
  @override
  String get id => 'level_2';
  
  @override
  String get name => 'Mountain Pass';
  
  @override
  LevelLayout get layout => LevelLayout(
    trackWidth: 800.0,
    laneCount: 3,
    length: 5000.0,
  );
  
  @override
  SpawnConfig get spawnConfig => SpawnConfig(
    enemyDensity: 0.3,
    obstacleDensity: 0.2,
    pickupDensity: 0.15,
  );
}
```

**Key points** (from [lib/core/AGENTS.md](file:///c:/dev/rpg_runner/lib/core/AGENTS.md)):
- Level data must be deterministic (no random initialization in the definition)
- Use seeded RNG for spawn positions during gameplay, not in definition
- All gameplay parameters go in Core, not UI or Game layer

### 2. Register Level in Level Registry

Add the new level to the level registry:

```dart
// lib/core/levels/level_registry.dart
class LevelRegistry {
  static final levels = {
    'level_1': Level1Definition(),
    'level_2': Level2Definition(), // Add new level
  };
}
```

### 3. Create Level-Specific Assets

Organize assets per level (see [lib/game/AGENTS.md - Asset Management](file:///c:/dev/rpg_runner/lib/game/AGENTS.md)):

```
assets/
  levels/
    level_2/
      background.png
      tileset.png
      obstacles/
      enemies/
```

Update `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/levels/level_2/
    - assets/levels/level_2/obstacles/
    - assets/levels/level_2/enemies/
```

### 4. Add Level Selection UI

Create level selection button in UI (see [lib/ui/AGENTS.md - Level Selection](file:///c:/dev/rpg_runner/lib/ui/AGENTS.md)):

```dart
// lib/ui/levels/level_select_screen.dart
LevelButton(
  levelId: 'level_2',
  name: 'Mountain Pass',
  thumbnail: 'assets/levels/level_2/thumbnail.png',
  onTap: () {
    controller.enqueueCommand(
      LoadLevelCommand(levelId: 'level_2')
    );
    Navigator.push(context, GameRoute());
  },
)
```

**Remember:** UI never loads the level directly—it sends a Command to Core.

### 5. Implement Level Loading in Core

Ensure Core's level loading handles the new level deterministically:

```dart
// lib/core/game_core.dart
void handleLoadLevelCommand(LoadLevelCommand cmd) {
  final definition = LevelRegistry.levels[cmd.levelId];
  
  // Reset Core state deterministically
  resetState(seed: cmd.seed ?? defaultSeed);
  
  // Load level data
  currentLevel = definition;
  
  // Initialize level-specific systems
  spawnService.configure(definition.spawnConfig);
  trackManager.configure(definition.layout);
}
```

### 6. Test Determinism

Add determinism tests for the new level (see [lib/core/AGENTS.md - Testing](file:///c:/dev/rpg_runner/lib/core/AGENTS.md)):

```dart
// test/core/levels/level_2_test.dart
test('level 2 is deterministic with same seed', () {
  final game1 = GameCore(seed: 12345, levelId: 'level_2');
  final game2 = GameCore(seed: 12345, levelId: 'level_2');
  
  for (int i = 0; i < 100; i++) {
    game1.tick();
    game2.tick();
    
    expect(game1.snapshot, equals(game2.snapshot));
  }
});
```

// turbo
Run tests:
```bash
dart test test/core/levels/level_2_test.dart
```

### 7. Verify in Game

// turbo
Build and run the game:
```bash
flutter run
```

**Manual verification checklist:**
- [ ] Level appears in level selection UI
- [ ] Level loads without errors
- [ ] Gameplay runs smoothly
- [ ] Level-specific assets load correctly
- [ ] No visual glitches or asset loading during gameplay
- [ ] Can complete the level
- [ ] Can return to menu and select another level

## Common Issues

### Assets not loading
- Check `pubspec.yaml` includes all asset folders
- Verify asset paths match exactly (case-sensitive)
- Run `flutter pub get` to rebuild asset manifest

### Level not deterministic
- Ensure no `DateTime.now()` or unseeded `Random()` in level code
- Verify spawn positions use seeded RNG from Core
- Check that level reset clears all state properly

### Performance issues
- Profile asset loading (should be in loading screen, not during gameplay)
- Check for allocation-heavy code in level-specific systems
- Verify tick rate stays at 60 Hz

## Follow-Up

After adding a new level, consider:
- Adding level-specific achievements or scoring
- Creating level progression (unlock conditions)
- Adding level-specific tutorials or hints
- Extending test coverage for edge cases
