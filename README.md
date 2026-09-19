# RPG Runner

A Flutter + Flame action runner focused on deterministic gameplay architecture.

This is a portfolio-style game project designed to demonstrate production-minded engineering for mobile games: clean layering, testable simulation, and systems ready for replay/online expansion.

## Why It Stands Out

- Deterministic ECS simulation loop in pure Dart (`packages/runner_core/lib/`)
- Snapshot-driven rendering pipeline in Flame (`lib/game/`)
- Command-based input flow and fixed-tick simulation (60 Hz)
- Clear separation between gameplay authority and visuals
- Strong automated test coverage for gameplay and UI behavior

## Current Scope (Implemented)

- 2 authored level layouts: `forest`, `field`
- Generated polygon terrain is the collision, navigation, placement, and
  rendering authority for normal runs and replay validation
- Animated, authorable water regions with deterministic player swimming;
  see the [pool authoring guide](docs/gdd/swimming.md)
- 2 selectable character definitions
- 24 authored abilities (mobility, melee, ranged, defense, utility)
- 4 enemy archetypes (ground chaser, ambusher, flying demon, stationary caster)
- Gear/loadout setup flow before runs
- In-game HUD, pause, game-over, and scoring
- Board-backed leaderboards, replay validation, and ghost publication
- Backend-authenticated player profile plus ownership/progression persistence via Firebase Functions + Firestore
- 100+ Dart test files (`*_test.dart`) in `test/`
- Firebase Auth + callable backend integration
- Windows content editor with visual Level/Chunk authoring, authored Play,
  guarded source Save/recovery, and repository-wide generated-content Build

## Architecture (Simple View)

- `packages/runner_core/lib/`: Authoritative deterministic simulation (ECS, combat, movement, AI, snapshots)
- `lib/game/`: Flame rendering and visual components that consume snapshots
- `lib/ui/`: Flutter menus, overlays, controls, and state orchestration

## Run Locally

The supported development baseline is Flutter 3.47.1 (Dart 3.13.1). Android
builds use JDK 17 or newer with the checked-in Gradle 9.3.1 wrapper and Android
Gradle Plugin 9.1.0. Backend work uses Node 24 and pnpm 11.22.0 through
Corepack.

```bash
flutter pub get
flutter run
```

Android startup requires Play Games sign-in. On a new workstation, register
the debug signing certificate in Firebase and Play Games; a regenerated
debug keystore has a different SHA-1. See
[local Android sign-in troubleshooting](docs/tdd/authentication_flow_and_authorization.md#local-android-sign-in-troubleshooting)
for credential and tester setup checks.

The root app and shared Dart packages use one Pub workspace and the root
`pubspec.lock`. Run their dependency resolution and upgrades from the
repository root. The editor and Dart-only replay validator are independently
executable applications, so each intentionally retains its own lockfile and
toolchain-specific resolution.

See [Pub workspace and dependency resolution](docs/tdd/pub_workspace.md) for
the package boundary and validation commands.

Run tests:

```bash
flutter test --exclude-tags=integration
```

Run integration benchmark test:

```bash
flutter drive --driver=test_driver/integration_test.dart --target=test/integration_test/core-fixed-point/core_fixed_point_benchmark_test.dart -d <deviceId> --profile
```

## Author Content

Run `flutter run -d windows` from `tools/editor`. Level Creator connects Contents,
Flow, Appearance, Chunk/Parallax editing, seeded sample runs, and real Level Play.
New levels can be saved and tested before inclusion in generated game content.
The editor's Build action uses the existing repository generator and reports
source errors and generated freshness. See the [editor guide](tools/editor/README.md)
for creation, Save/recovery, inclusion, Play controls, and schema migration.

## Deploy The Web Client

Build the Flutter web client, then publish it to the configured Firebase
Hosting site:

```bash
flutter build web --release
firebase deploy --only hosting --project rpg-runner-d7add
```

## Tech Stack

- Flutter
- Dart
- Flame
- Firebase Core
- Provider
- SharedPreferences

## Documentation And Planning

The [documentation index](docs/README.md) links current audits, implementation
plans, technical contracts, and game design documents. Previous audit and
planning documents are retained in a dated archive after the September 15,
2026 planning restart.


Chunk/Level authoring includes three terrain elevation guides, exact connecting
chunk creation, joined previews and schedule readiness. See
[chunk connections](docs/tdd/chunk_connections.md) for the editor workflow and
the selector's 2026.09.0 compatibility rollout. The current gameplay
compatibility is 2026.09.2, which paces camera target speed by the resolved
chunk difficulty while retaining the 2026.09.1 fall-behind grace distance.
