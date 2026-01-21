# AGENTS.md

Repository-wide instructions for AI coding agents working on this Flutter + Flame runner game.

## Project Direction

This is a **Flutter (Dart) + Flame** runner game. The vision is to create a **complete vertical slice** with:

- **2-3 distinct playable levels** with varied gameplay
- **Advanced combat system** with mobility abilities, spells, weapons, and ultimates
- **2 playable characters** with unique characteristics
- **Character customization** via loadout menu (ability selection before each run)
- **5-6 enemy types** with distinct behaviors
- **Light narrative integration** to enhance player engagement
- **Firebase backend** for player data and progression
- **Ghost run feature** - race against other players' recorded runs
- **Multiplayer-ready architecture** - scalable for online races and future battle royale mode
- **Monetization pipeline** integration

**Implementation approach**: Step-by-step, with the deterministic Core architecture supporting all features (especially multiplayer/ghost replay).

**For detailed layer-specific guidance**, see:
- **[lib/AGENTS.md](file:///c:/dev/rpg_runner/lib/AGENTS.md)** - Architecture overview and cross-cutting concerns
- **[lib/core/AGENTS.md](file:///c:/dev/rpg_runner/lib/core/AGENTS.md)** - Pure Dart simulation layer (ECS, determinism, Core contracts)
- **[lib/game/AGENTS.md](file:///c:/dev/rpg_runner/lib/game/AGENTS.md)** - Flame rendering layer (visuals, snapshots, camera)
- **[lib/ui/AGENTS.md](file:///c:/dev/rpg_runner/lib/ui/AGENTS.md)** - Flutter UI layer (widgets, menus, commands)

## Collaboration Guidelines

### Consent Before Changing Code

When the user asks a question (e.g. "how do I…?", "why…?", "is it possible…?") or explicitly says "no code / just answer":

- **Do not make code changes.** Answer with options/tradeoffs only.
- If implementation would help, **ask for confirmation first** before editing any files.

Only implement changes when the user clearly requests it (e.g. "please implement", "make the change", "can you do X in the repo?").

### Non-Trivial Tasks

For any non-trivial task (anything that affects architecture, touches multiple layers/files, introduces a new subsystem, or changes a core contract):

- Brainstorm 1-3 viable approaches (with tradeoffs) before coding.
- Check whether a good solution already exists (repo patterns, Flame APIs, well-maintained packages).
- Write a short plan (steps + acceptance criteria) and align on it before implementing.
- Ask clarifying questions when requirements are underspecified.

For trivial/surgical changes (tiny refactors, obvious bug fixes), proceed directly but keep changes minimal and consistent with existing patterns.

## Documentation Upkeep

When you implement changes, keep documentation in sync (add new docs when needed, not just code):

- **Architecture/contract docs** when boundaries or APIs change: layer-specific `AGENTS.md`, `docs/building/plan.md`
- **Milestone/checklists** when scope shifts: `docs/building/TODO.md`
- **User-facing docs** when behavior changes: `README.md`, public API docs (e.g. `lib/runner.dart`)

## Antigravity Integration

### Workflows

Common development workflows are defined in `.agent/workflows/`. If you're performing a standard task, check if a workflow exists:

- **Adding a new level**: `.agent/workflows/add-new-level.md`
- **Creating ECS components**: `.agent/workflows/create-ecs-component.md`
- **Adding Core systems**: `.agent/workflows/add-core-system.md`

### Skills

Reusable skills for specialized tasks are available in `.agent/skills/`. Consult skills when working on complex patterns or domain-specific tasks.

---

**For implementation details, architecture rules, and layer-specific conventions**, always refer to the appropriate AGENTS.md file listed above.
