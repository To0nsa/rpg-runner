# AGENTS.md

Repository-wide instructions for AI coding agents working in `rpg_runner`.

## What This Repo Is

This repo is no longer just a prototype of a runner architecture. It is a working Flutter + Flame game slice with a deterministic simulation core, a real Flutter app shell, and a Firebase Functions backend for authenticated profile and ownership state.

Current implemented scope includes:

- Deterministic Core gameplay in `packages/runner_core/lib/`
- Flame rendering bridge in `lib/game/`
- Full Flutter app shell, setup flow, hub, town/meta pages, HUD, and run route in `lib/ui/`
- Backend-authenticated profile and loadout ownership state via Firebase Functions + Firestore
- Two playable levels and two selectable characters
- Loadout, gear, projectile/spell, and progression state flowing through local UI + remote backend contracts

Roadmap work still exists, but AGENTS guidance must describe the code that exists today. Do not write docs that assume future systems already exist.

## Read These First

Use the most specific AGENTS file that matches the area you are touching:

- `AGENTS.md`: repo-wide rules and cross-cutting quality bar
- `lib/AGENTS.md`: app-level architecture and layer boundaries
- `packages/runner_core/lib/AGENTS.md`: deterministic simulation layer
- `lib/game/AGENTS.md`: Flame renderer and controller bridge
- `lib/ui/AGENTS.md`: Flutter app shell, pages, state, HUD, and theming
- `functions/AGENTS.md`: Firebase Functions backend in TypeScript

Also consult:

- `docs/rules/documentation_and_commenting_guide.md` for comment and API doc standards
- `.agent/workflows/` when the task matches an existing workflow

## Repo Map

- `lib/`: Flutter package and embeddable runner implementation
- `functions/`: Firebase Functions backend in TypeScript
- `test/`: Dart tests across core, game, UI, and integration slices
- `docs/building/`: implementation plans and checklists
- `assets/`: runtime art/audio/fonts content

## Current Architectural Split

- `packages/runner_core/lib/` is the authoritative deterministic gameplay layer
- `lib/game/` is the Flame rendering and input bridge layer
- `lib/ui/` is the Flutter app shell, menu/meta UI, HUD, state orchestration, and backend client layer
- `functions/src/` is the server-side authority for authenticated profile, ownership, and account deletion flows

When a feature crosses Flutter and backend boundaries, update both ends in the same change:

- backend callable contract in `functions/src/**`
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
- Backend changes: `corepack pnpm --dir functions build` and `corepack pnpm --dir functions test`
- Cross-layer contract changes: validate both the Flutter client side and the backend side

If you cannot run a relevant check, state that clearly in the final handoff.

## Documentation Upkeep

Keep docs in sync when contracts, boundaries, or behavior change:

- update the relevant `AGENTS.md` file when working rules or boundaries drift
- update `README.md` when public capabilities or setup steps change
- update `docs/building/plan.md` or the relevant checklist when milestone scope shifts
- update public API docs around `lib/runner.dart`, `lib/ui/runner_game_widget.dart`, and `lib/ui/runner_game_route.dart` when embedding behavior changes

## Practical Guardrails

- Prefer existing repo patterns before inventing new abstractions
- Keep generated files generated
- Ignore unrelated dirty-worktree changes unless they conflict with the task
- Do not weaken determinism, auth checks, or revision/idempotency rules to make a feature "work"

---

For implementation detail, always drop into the closest layer-specific `AGENTS.md` before editing.
