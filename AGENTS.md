# AGENTS.md

Repository-wide instructions for AI coding agents working in `rpg_runner`.

## What This Repo Is

This repo is no longer just a prototype of a runner architecture. It is a working Flutter + Flame game slice with a deterministic simulation core, a real Flutter app shell, a Firebase Functions backend, and a Cloud Run replay-validation service.

Current implemented scope includes:

- Deterministic Core gameplay in `packages/runner_core/lib/`
- Shared run/replay/board/leaderboard protocol contracts in `packages/run_protocol/lib/`
- Flame rendering bridge in `lib/game/`
- Full Flutter app shell, setup flow, hub, town/meta pages, HUD, and run route in `lib/ui/`
- Backend-authenticated profile, ownership, run-session, board, leaderboard, ghost, and account state via Firebase Functions + Firestore
- Uploaded replay validation, reward settlement, leaderboard projection, and ghost artifact publishing via `services/replay_validator/`
- Repository-backed content authoring workflows in `tools/editor/`
- Two playable levels and two selectable characters
- Loadout, gear, projectile/spell, and progression state flowing through local UI + remote backend contracts

Roadmap work still exists, but AGENTS guidance must describe the code that exists today. Do not write docs that assume future systems already exist.

## Read These First

Use the most specific AGENTS file that matches the area you are touching:

- `AGENTS.md`: repo-wide rules and cross-cutting quality bar
- `lib/AGENTS.md`: app-level architecture and layer boundaries
- `packages/runner_core/AGENTS.md`: Core package scope, generated-content, and
  validation rules
- `packages/runner_core/lib/AGENTS.md`: deterministic simulation layer
- `packages/run_protocol/AGENTS.md`: shared run/replay/board protocol contracts
- `packages/terrain_materials/AGENTS.md`: shared terrain-render material source
  contract
- `lib/game/AGENTS.md`: Flame renderer and controller bridge
- `lib/ui/AGENTS.md`: Flutter app shell, pages, state, HUD, and theming
- `functions/AGENTS.md`: Firebase Functions backend in TypeScript
- `services/replay_validator/AGENTS.md`: Cloud Run replay-validation worker
- `tools/editor/AGENTS.md`: standalone Flutter content authoring tool

Also consult:

- `docs/rules/code-documentation-policy.md` for comment and API doc standards
- `.agent/workflows/` when the task matches an existing workflow

## Repo Map

- `lib/`: Flutter package and embeddable runner implementation
- `packages/runner_core/`: deterministic Dart gameplay package
- `packages/run_protocol/`: shared replay, board, leaderboard, run ticket, and submission-status contracts
- `packages/terrain_materials/`: pure-Dart terrain material authoring/render-source contracts
- `functions/`: Firebase Functions backend in TypeScript
- `services/replay_validator/`: Dart Cloud Run worker for replay validation and projection side effects
- `tools/editor/`: standalone Flutter editor for repository-backed content authoring
- `test/`: Dart tests across core, game, UI, and integration slices
- `docs/building/`: active implementation plans and checklists
- `docs/building/archived/`: implemented or otherwise closed building plans
- `docs/tdd/`: technical design documents for architecture, system behavior, and contracts
- `docs/gdd/`: game design documents for player-facing mechanics, content, and tuning
- `.agent/workflows/`: task-specific workflow notes
- `assets/`: runtime art/audio/fonts content

## Current Architectural Split

- `packages/runner_core/lib/` is the authoritative deterministic gameplay layer
- `packages/run_protocol/lib/` is the shared wire-contract layer for run tickets, replay blobs, validation results, boards, leaderboards, and ghosts
- `lib/game/` is the Flame rendering and input bridge layer
- `lib/ui/` is the Flutter app shell, menu/meta UI, HUD, state orchestration, and backend client layer
- `functions/src/` is the callable/scheduled backend authority for authenticated profile, ownership, run-session, board, leaderboard, ghost, and account deletion flows
- `services/replay_validator/lib/` is the asynchronous replay-validation worker that consumes run sessions, replays Core deterministically, and writes validation/projection outcomes
- `tools/editor/lib/` is the repository-backed content authoring UI; it writes deterministic source assets, not gameplay authority

When a feature crosses Flutter and backend boundaries, update both ends in the same change:

- shared wire contract in `packages/run_protocol/lib/**` when run/replay/leaderboard payloads change
- backend callable contract in `functions/src/**`
- replay worker behavior in `services/replay_validator/lib/**` when validation, rewards, leaderboards, or ghosts depend on it
- client adapter in `lib/ui/state/**`
- local state/application flow in `lib/ui/**`
- docs for any changed contract or invariant

## Collaboration Rules

### Consent Before Editing

When the user is asking for explanation only, or explicitly says not to change code, do not edit files. Answer with options, tradeoffs, and concrete references.

### Non-Trivial Work

For non-trivial tasks:

- inspect the existing implementation before proposing changes
- consider 1-3 viable approaches and prefer the one that fits current repo patterns
- share a short plan with acceptance criteria before editing
- ask a clarifying question only when a wrong assumption would create risky churn

For surgical fixes, proceed directly after a brief inspection.

## Default Quality Bar

Treat every change as production-minded cleanup, not a quick patch:

- finish migrations in one pass; do not leave parallel legacy paths behind
- keep layer boundaries intact instead of solving issues by reaching across layers
- prefer semantic APIs over ad-hoc knobs, especially in Flutter widgets
- avoid deprecated Flutter APIs in new or edited code
- keep side effects out of widget `build` methods
- keep backend source-of-truth in `functions/src/**`; never hand-edit `functions/lib/**` or `functions/lib_test/**`
- keep comments high-signal and aligned with the documentation guide

## Validation Expectations

Run the smallest relevant checks for the slice you touched:

- Flutter/Dart changes: `dart analyze` and relevant `flutter test` targets
- Shared protocol changes: `dart analyze packages/run_protocol` and `dart test packages/run_protocol/test`
- Backend changes: `corepack pnpm --dir functions build` and `corepack pnpm --dir functions test`
- Replay validator changes: `dart analyze services/replay_validator` and `dart test services/replay_validator/test`
- Editor changes: `cd tools/editor && dart analyze` and `cd tools/editor && flutter test`
- Cross-layer contract changes: validate both the Flutter client side and the backend side

If you cannot run a relevant check, state that clearly in the final handoff.

## Commit Hygiene

For multi-step implementation work, make small, coherent commits after each
independently validated milestone.

- keep each commit focused on one logical change and its required tests/docs
- do not bundle unrelated worktree changes into a commit
- do not commit known failures, incomplete migrations, or generated output that
  is not meant to be tracked

## Documentation Upkeep

Documentation is part of the implementation. For every change, assess its
documentation impact and leave the relevant documentation complete and current;
do not defer necessary technical or game-design documentation to a later task.

- update an existing `docs/tdd/**` document, or create a focused one when none
  exists, for technical architecture, ownership/boundaries, data flow,
  persistence, APIs/wire contracts, determinism, ordering, lifecycle, security,
  or other implementation invariants
- update an existing `docs/gdd/**` document, or create a focused one when none
  exists, for player-facing mechanics, progression, levels, enemies, abilities,
  economy, rewards, UX gameplay rules, or balance/tuning decisions
- update both TDD and GDD documentation when a change affects both the technical
  implementation and the intended player experience
- keep TDD/GDD documents grounded in implemented behavior; record proposed or
  in-progress work in `docs/building/**` until it is delivered

- update the relevant `AGENTS.md` file when working rules or boundaries drift
- update `README.md` when public capabilities or setup steps change
- update the relevant `docs/building/**` plan/checklist when milestone scope shifts
- move implemented or closed building plans to `docs/building/archived/` and update active links
- update public API docs around `lib/runner.dart`, `lib/ui/runner_game_widget.dart`, and `lib/ui/runner_game_route.dart` when embedding behavior changes

## Practical Guardrails

- Prefer existing repo patterns before inventing new abstractions
- Keep generated files generated
- Ignore unrelated dirty-worktree changes unless they conflict with the task
- Do not weaken determinism, auth checks, or revision/idempotency rules to make a feature "work"

---

For implementation detail, always drop into the closest layer-specific `AGENTS.md` before editing.
