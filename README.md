# RPG-Runner (Flutter + Flame)

Deterministic 2D runner prototype, ported from an SFML/C++ version into Flutter (Dart) + Flame.

The goal is to adapt a desktop version to a mobile one, preserving the gameplay while having a "production-grade" repo that can scale up. I tried to focus on mobile performance, clean boundaries, and future online-ready determinism (replay, ghost run, multiplayer). Except for the parallax (that doesnt fit the game view perfectly), I used placeholder geometric shapes to keep the focus on architecture and gameplay for this prototype.

This package is designed to be embedded into an existing Flutter app.

---

## TL;DR

* **Core** (`lib/core/`): pure Dart, deterministic simulation (authoritative gameplay).
* **Render** (`lib/game/`): Flame-only visuals, reads snapshots.
* **UI** (`lib/ui/`): Flutter overlays + controls, sends Commands.
* **Public embedding API**: `lib/runner.dart`.
* **Dev host app**: `lib/main.dart`.

---

## Run (standalone dev host)

```bash
flutter pub get
flutter run
```

The dev host launches a minimal menu (`DevMenuPage`) which routes to a
development menu (`RunnerMenuPage`) where you can select a level and start a
run.

---

## Embed (host app)

Import the public embedding API (`lib/runner.dart`) and push the route:

```dart
import 'package:rpg_runner/runner.dart';

Navigator.of(context).push(
  createRunnerGameRoute(
    seed: 123,
    levelId: LevelId.forest,
  ),
);
```

---

## Architecture

### 1) Core — deterministic simulation (`lib/core/`)

* Fixed-tick simulation (e.g. 60 Hz); ticks are the only time authority.
* Inputs are **Commands** scheduled per tick.
* RNG is seeded and owned by Core.
* Output is an immutable `GameStateSnapshot` + transient `GameEvent`s.

Core must **not** import Flutter or Flame.

### 2) Render — Flame (`lib/game/`)

* `RunnerFlameGame` reads the latest snapshot each frame.
* Rendering is intentionally non-authoritative.
* Pixel-friendly camera/viewport components live here (parallax, ground band, aim ray, etc.).

### 3) UI — Flutter overlays (`lib/ui/`)

* HUD + game over overlay + leaderboard.
* Touch controls (joystick + action buttons + directional action buttons).
* UI sends **Commands** to the controller; UI does not mutate simulation state directly.

---

## Controls

Current control surface (mobile-friendly), (no debug keys for keyboard as I tested directly on mobile):

* movement joystick / axis
* Jump
* Dash
* Melee strike (directional)
* Projectile/spell aim + cast (directional)
