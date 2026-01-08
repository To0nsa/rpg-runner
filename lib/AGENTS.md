# AGENTS.md

Instructions for AI coding agents (Codex, ChatGPT, etc.) when working in this repo.

## Project mission

Build and evolve this **Flutter (Dart) + Flame** runner into a **production-grade** game (mobile performance, clean architecture, deterministic Core, future online-ready), with a **scalable level system** that supports at least **two distinct playable levels** and makes adding more levels straightforward and low-risk.

## Working style (how to collaborate)

## Consent before changing code

When the user asks a question (e.g. “how do I…?”, “why…?”, “is it possible…?”) or explicitly says “no code / just answer”:

- **Do not make code changes or run refactors.** Provide an answer with options/tradeoffs only.
- If implementation would help, **ask for confirmation first** (e.g. “Want me to implement option A?”) before editing files.

Only implement changes when the user clearly requests it (e.g. “please implement”, “make the change”, “can you do X in the repo?”).

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

## Level system (content scaling)

Goal: support multiple distinct levels without forking gameplay code or entangling assets/UI.

Rules:

- Levels are **data-first**: define a `LevelId` + `LevelDefinition` (and optional level-specific systems) behind stable Core contracts.
- Level switching resets Core deterministically (seeded RNG, tick counter, entity world) and is driven by a **Command** from UI.
- Spawning/layout rules live in **Core** (authoritative). Render/UI only visualize and present selection/progress.
- Assets are organized and loaded **per level/scene**; avoid global “load everything at boot”.

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

Prefer small, testable increments that move toward “multiple levels”:

1. Define the Core level contracts (`LevelId`/`LevelDefinition`, load/reset flow).
2. Add level selection entry points (UI + dev menu) that send Commands only.
3. Make level-specific spawning/layout data-driven and deterministic.
4. Ship a second level that differs meaningfully (layout/spawns/tempo) without special-casing.
5. Add/extend Core tests to lock determinism per level (same seed ⇒ same snapshots/events).

## Code quality rules (Dart/Flutter)

- Keep the codebase modular and scalable:
  - prefer small, cohesive modules with clear boundaries
  - avoid tight coupling across Core/Render/UI; depend on stable contracts instead
  - keep public embedding API stable (`lib/runner.dart`), treat internal folders as refactorable
- Keep responsibilities narrow; avoid "god" classes that mix input/sim/render.
- Prefer explicit data flow: Commands in, snapshots/events out.
- Keep Core allocation-light: avoid per-tick new Lists/Maps in hot loops.
- Prefer `final`, `const`, and value types for small structs (e.g. `Vec2`).
- No `dynamic` in gameplay code (prefer typed payloads; if a temporary map is unavoidable, confine it to UI/debug only).
- Make side effects explicit: Core returns events; render/UI consume them.
- Keep changes consistent with existing style; avoid renames/reformatting unrelated code.
- Add/extend tests when relevant (especially when new behavior is introduced or existing behavior changes):
  - Core behavior: unit tests in `test/core/**` (`dart test`)
  - UI/viewport/widget behavior: widget tests where appropriate
- Keep docs in sync with code: update relevant docs whenever behavior, contracts, milestones, or public APIs change.

## What an agent must do on each task

When asked to implement/fix something:

1. Identify which layer it belongs to (Core vs Render vs UI).
2. Check for an existing solution/pattern that already fits the goal (repo + Flame + packages).
3. Propose a minimal plan (1-3 steps) and acceptance criteria.
4. Implement with deterministic rules intact.
5. Update docs/comments whenever a change affects behavior, contracts, milestones, or usage:
   - update `docs/building/plan.md` if architecture rules/contracts change
   - if no existing doc fits, add a short doc under `docs/building/` and link it from `docs/building/plan.md`
   - update `docs/building/TODO.md` if milestone checklist/follow-ups change
   - treat `docs/building/v0-implementation-plan.md` as historical unless asked to revise it
   - update top-of-file docs and public API docs (`lib/runner.dart`, route/widget docs) when embedding/API expectations change
6. Add/extend relevant tests when new behavior is introduced or existing behavior changes (especially Core determinism and systems).
7. Provide:
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
- `lib/ui/`      - menus, overlays, UI state, input widgets
- `test/`        - Core unit tests

---
If anything here conflicts with repo docs, treat repo docs as the source of truth.
