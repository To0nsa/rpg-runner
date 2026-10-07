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
- Animated, authorable water regions with deterministic player and ground-enemy swimming;
  see the [pool authoring guide](docs/gdd/swimming.md)
- 2 selectable character definitions
- Pose-aligned combat capsules, shared fixed-tick animation clocks, and exact
  [combat debug geometry](docs/tdd/combat_pose_geometry.md)
- Authored abilities (mobility, melee, ranged, defense, utility)
- 5 enemy archetypes: ground chaser, ambusher, flying demon, transforming cultist,
  and Bringer of Death in a mandatory [Forest boss arena](docs/gdd/bringer_of_death.md),
  deployed with shared attack knockback and a 60% victory resource blessing in
  [gameplay 2026.10.8](docs/verification/forest_boss_arena.md#production-release-2026108)
  (source `2026.10.9` adds 1.5x boss/column size, faster attacks, 20% faster
  pursuit and a 20% easy-chunk blessing; coordinated deployment is pending)
- 3 additional [Ancient God bosses](docs/gdd/ancient_god_bosses.md) selectable in
  Chunk Creator arena metadata: Voidborn Goddess, Shoggoth and Voidcaller, with
  damageable summons, teleports and spell effects at Bringer's 1.5x scale;
  production level placements remain unchanged
- 3 allied NPC archetypes with animated combat, chunk-bound rescue encounters,
  surviving section guards and Huntress throw/stab/slash combat,
  editable targeting/rewards in Chunk Creator, and replay-validated rescue scoring
- Reusable world interactions with a Forest regeneration shrine, persistent fire,
  and level-duration resource bonuses; [manual configuration](docs/tdd/world_interactions.md)
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

Production web builds require the public, domain-restricted App Check key:

```bash
flutter build web --release --dart-define-from-file=web/production_defines.json
```

The [release workflow](docs/tdd/deployment_workflow.md) passes this configuration
automatically and includes it in artifact-cache validation.

Startup preserves the 1.8-second studio splash and a minimum two-second game
loader. Initialization and player-data failures remain on the loader with an
explicit retry; the hub opens only after bootstrap and required name setup.
See [startup and authentication](docs/tdd/authentication_flow_and_authorization.md).

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

## Test Level Traversal

Run the reusable enemy traversal suite from the repository root:

```powershell
dart run tool/generate_chunk_runtime_data.dart --dry-run
Push-Location packages/runner_core
dart test test/navigation/level_enemy_traversal_test.dart test/navigation/level_enemy_traversal_harness_test.dart --reporter expanded
Pop-Location
```

It exercises actual navigation, movement and collision for Grojib, Hashash,
twisted Derf and Unoco on seeds `7`, `42`, `2026`: Forest's complete authored
assembly and the first 32 chunks of Field and `new_level`. Derf's normal-form
explosions, first-visibility transformation and tentacle combat have separate
checks. See [Derf gameplay](docs/gdd/derf.md). Failures report
the chunk sequence, movement limits and motion trace. Passing requires crossing
the actual route boundary; an extra continuation chunk supports the chase
target beyond it. This isolates traversal;
combat, spawn markers, camera pressure and player playthroughs need separate
checks.

The [level testing workflow](.agent/workflows/test-level-traversal.md) explains
single-case commands, adding levels/seeds, adapting targets and budgets, and
distinguishing chunk, navigation and movement failures. New compiled levels
must declare a scenario in the matrix.

## Author Content

Run `flutter run -d windows` from `tools/editor`. Level Creator connects Contents,
Flow, Appearance, Chunk/Parallax editing, seeded sample runs, and real Level Play.
New levels can be saved and tested before inclusion in generated game content.
The editor's Build action uses the existing repository generator and reports
source errors and generated freshness. See the [editor guide](tools/editor/README.md)
for creation, Save/recovery, inclusion, Play controls, and schema migration.

## Deploy A Release

Use the [coordinated release workflow](docs/tdd/deployment_workflow.md) for
Functions, Firestore rules/indexes, the replay worker and web Hosting:

~~~powershell
.\tools\release\release.ps1 -Action Plan
.\tools\release\release.ps1 -Action Prepare
~~~

The default Plan is offline and selects the required deployment scope. Prepare
reuses a persistent component cache, including built web/Functions artifacts.
Checkout freezes a commit; ImportCI reuses a successful exact-commit CI bundle.
CI runs client tests in four shards and records slow-test timings. Hosting-only
and backend-only changes use verified baseline checks; gameplay changes retain
the coordinated cutover. The same entry point
provides live inspection, asynchronous image builds, and explicit issuance
pause/deploy/resume stages. Follow the workflow before invoking those production
actions; a gameplay compatibility change requires matching client, Functions,
worker and board versions.

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
the selector's 2026.09.0 compatibility rollout. The repository's gameplay
compatibility is 2026.10.2, adding Huntress distance-based attacks, per-enemy
stab history, and furthest-progress run distance at 25 world units per metre
(`score-v3`) alongside projectile auto aim, surviving NPC section
combat, the latest Forest grove/terrain refinements and grounded-placement repair,
rescue scoring and slower camera pacing.
The [recorded October 2 production release](docs/verification/game-compat-2026.10.1-production.md)
uses frozen `0cb94b94`. Source compatibility `2026.10.2` requires a matching
coordinated release; this branch does not deploy it.
The [documentation index](docs/README.md) distinguishes pending compatibility
work from the latest verified production release.
