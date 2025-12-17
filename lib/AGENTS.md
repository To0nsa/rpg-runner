# AGENTS.md

Instructions for AI coding agents (Codex, ChatGPT, etc.) when working in this repo.

## Project mission

Port an existing **SFML/C++ 2D runner** into **Flutter (Dart) + Flame** while preserving gameplay feel and making the result **production-grade** (mobile performance, clean architecture, future online-ready).

## Working style (how to collaborate)

For any non-trivial task (anything that affects architecture, touches multiple layers/files, introduces a new subsystem, or changes a core contract):

- Brainstorm 1-3 viable approaches (with tradeoffs) before coding.
- Check whether a good solution already exists (repo patterns, Flame APIs, well-maintained packages) and prefer it when it fits the goals.
- Write a short plan (steps + acceptance criteria) and align on it before implementing.
- Ask clarifying questions when requirements are underspecified or multiple designs are plausible.

For trivial/surgical changes (tiny refactors, obvious bug fixes), proceed directly but keep changes minimal and consistent with existing patterns.

## Non-negotiable architecture

This project has **three hard layers**:

1. **Core (pure Dart simulation)**: deterministic gameplay + physics + AI + RNG
2. **Render (Flame)**: visuals only (sprites/animations/camera/parallax/VFX)
3. **UI (Flutter)**: menus, overlays, navigation, settings

Rules:

- **Core must not import Flutter or Flame.**
- Flame must not be authoritative for gameplay/collision.
- UI must not modify gameplay state directly; it sends **Commands** to the controller.
- The game must be embeddable: expose a reusable widget/route entrypoint; keep `lib/main.dart` as a dev host/demo only.

## Prefer existing solutions (when they fit the goals)

Before building something custom, check if a better solution already exists:

- In this repo (search for an existing pattern/component first)
- In Flame APIs (camera, viewport, parallax, input, effects)
- In well-maintained Dart/Flutter packages

Rule of thumb:

- Prefer Flame for *render concerns* (camera components, parallax rendering, effects).
- Prefer UI (Flutter) for *UI/input widgets* (joystick/buttons/menus/overlays).
- Prefer Core for *authoritative gameplay concerns* (movement/physics/collision, ability timing, damage rules), especially when determinism/networking is a goal.

## Determinism contract

- Simulation runs in **fixed ticks** (e.g. 60 Hz). Ticks are the only time authority.
- Inputs are **Commands** queued for a specific tick.
- RNG is seeded and owned by the Core. No wall-clock randomness.
- On app resume, clamp frame dt and **never** try to "catch up" thousands of ticks.

## Core data model

### Entity storage

- Use **SoA + SparseSet** per component type.
- Entity IDs are monotonic and **never reused**.

Iteration rules:

- Systems iterate via queries (no direct sparse/dense fiddling).
- Do not add/remove components or destroy entities mid-iteration. Queue structural changes and apply after system execution.
- Do not keep references to dense arrays across ticks.

### Snapshots & events

Core outputs:

- Immutable `GameStateSnapshot` for render/UI (serializable, renderer-friendly).
- Transient `GameEvent`s (spawn/despawn/hit/sfx/screenshake/reward, etc.).

Renderer/UI must:

- Treat snapshots as read-only.
- Interpolate visuals using (`prevSnapshot`, `currSnapshot`, `alpha`) but **never simulate**.

## World / camera / pixel-art rules

- Pick one **virtual resolution** (world units == virtual pixels).
- Use **integer scaling + letterboxing**. No fractional scaling, no shimmering.
- Snap camera + render positions to integer pixels inside the scaled viewport.

## Asset rules

- Assets are loaded **per scene**, not at boot.
- No asset loading during active gameplay.
- Unload game assets when leaving the mini-game route.

## Implementation sequencing

Follow the V0 plan (small, testable increments):

1. Scaffold + wiring (`lib/core`, `lib/game`, `lib/ui`)
2. Camera/viewport/parallax
3. Core collision + player run/jump
4. Mobile controls
5. Abilities/resources
6. Enemies (simple AI)
7. Deterministic spawning

If you deviate, explain why and keep the same boundaries.

## Code quality rules (Dart/Flutter)

- Keep responsibilities narrow; avoid "god" classes that mix input/sim/render.
- Prefer explicit data flow: Commands in, snapshots/events out.
- Keep Core allocation-light: avoid per-tick new Lists/Maps in hot loops.
- Prefer `final`, `const`, and value types for small structs (e.g. `Vec2`).
- No `dynamic` in gameplay code (prefer typed payloads; if a temporary map is unavoidable, confine it to UI/debug only).
- Make side effects explicit: Core returns events; render/UI consume them.
- Keep changes consistent with existing style; avoid renames/reformatting unrelated code.
- Add unit tests for Core math/systems when possible (`dart test`).

## What an agent must do on each task

When asked to implement/fix something:

1. Identify which layer it belongs to (Core vs Render vs UI).
2. Check for an existing solution/pattern that already fits the goal (repo + Flame + packages).
3. Propose a minimal plan (1-3 steps) and acceptance criteria.
4. Implement with deterministic rules intact.
5. Update docs/comments when a change affects contracts or usage:
   - update `docs/plan.md` if architecture rules/contracts change
   - update `docs/v0-implementation-plan.md` if milestone checklist changes
   - update top-of-file docs and public API docs (`lib/runner.dart`, route/widget docs) when embedding/API expectations change
5. Provide:
   - files changed + why
   - how to run/verify (build + quick sanity checks)
   - follow-ups (next incremental step)

## What NOT to do

- Don't add Flutter/Flame imports into `lib/core/**`.
- Don't use Flame collision callbacks as gameplay truth.
- Don't introduce wall-clock timing in simulation (no `DateTime.now()`, no frame-dt gameplay).
- Don't "just make it work" by mixing UI/render/core responsibilities.

## Suggested folder layout

- `lib/core/`    - simulation, components, systems, RNG, commands, snapshots
- `lib/game/`    - Flame `Game`, entity view components, camera/parallax, render adapters
- `lib/ui/`      - menus, overlays, Riverpod providers, input widgets
- `test/`        - Core unit tests

---
If anything here conflicts with repo docs, treat repo docs as the source of truth.
