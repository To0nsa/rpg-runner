# RPG Runner

A Flutter + Flame action runner focused on deterministic gameplay architecture.

This is a portfolio-style game project designed to demonstrate production-minded engineering for mobile games: clean layering, testable simulation, and systems ready for replay/online expansion.

## Why It Stands Out

- Deterministic ECS simulation loop in pure Dart (`lib/core/`)
- Snapshot-driven rendering pipeline in Flame (`lib/game/`)
- Command-based input flow and fixed-tick simulation (60 Hz)
- Clear separation between gameplay authority and visuals
- Strong automated test coverage for gameplay and UI behavior

## Current Scope (Implemented)

- 2 playable levels: `forest`, `field`
- 2 selectable character definitions
- 24 authored abilities (mobility, melee, ranged, defense, utility)
- 2 enemy archetypes (ground + flying)
- Gear/loadout setup flow before runs
- In-game HUD, pause, game-over, and scoring
- Local leaderboard persistence (SharedPreferences)
- 100+ Dart test files (`*_test.dart`) in `test/`
- Firebase app initialization configured for future backend features

## Architecture (Simple View)

- `lib/core/`: Authoritative deterministic simulation (ECS, combat, movement, AI, snapshots)
- `lib/game/`: Flame rendering and visual components that consume snapshots
- `lib/ui/`: Flutter menus, overlays, controls, and state orchestration

## Run Locally

```bash
flutter pub get
flutter run
```

Run tests:

```bash
flutter test --exclude-tags=integration
```

Run integration benchmark test:

```bash
flutter drive --driver=test_driver/integration_test.dart --target=test/integration_test/core-fixed-point/core_fixed_point_benchmark_test.dart -d <deviceId> --profile
```

## Tech Stack

- Flutter
- Dart
- Flame
- Firebase Core
- Provider
- SharedPreferences

## Roadmap Direction

- Expand to 3+ polished levels and more enemy types
- Add deeper character/loadout progression
- Implement metaloop, achievements based progression, and unlockables
- Implement ghost runs and online race-ready infrastructure
- Connect leaderboard/progression to backend services
