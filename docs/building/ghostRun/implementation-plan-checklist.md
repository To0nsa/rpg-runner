# Ghost Run — Implementation Plan Checklist

Derived from [docs/building/ghostRun/plan.md](docs/building/ghostRun/plan.md), compared against current codebase state.

## Baseline Comparison (Current vs Target)

### Already implemented

- [x] Leaderboard has `Ghost VS` action column and per-row play action.
  - [lib/ui/pages/leaderboards/leaderboards_page.dart](lib/ui/pages/leaderboards/leaderboards_page.dart)
- [x] Ghost start path is opt-in via `ghostEntryId`.
  - [lib/ui/state/app_state.dart](lib/ui/state/app_state.dart)
- [x] Ghost bootstrap is fetched before run navigation for ghost starts.
  - [lib/ui/state/app_state.dart](lib/ui/state/app_state.dart)
- [x] `RunnerGameWidget` advances `GhostPlaybackRunner` during run.
  - [lib/ui/runner_game_widget.dart](lib/ui/runner_game_widget.dart)
- [x] Mid-run ghost playback failure already degrades safely (runner nulled, run continues).
  - [lib/ui/runner_game_widget.dart](lib/ui/runner_game_widget.dart)

### Not implemented yet (main gaps)

- [ ] Flame renderer has no ghost entity layer yet.
  - [lib/game/runner_flame_game.dart](lib/game/runner_flame_game.dart)
- [ ] No ghost snapshot/event bridge from run host into Flame.
  - [lib/ui/runner_game_widget.dart](lib/ui/runner_game_widget.dart)
  - [lib/game/runner_flame_game.dart](lib/game/runner_flame_game.dart)
- [ ] No reusable monochrome ghost style mode in render components.
  - [lib/game/components/sprite_anim/deterministic_anim_view.dart](lib/game/components/sprite_anim/deterministic_anim_view.dart)
- [ ] Ghost still represented by HUD text label.
  - [lib/ui/hud/game/game_overlay.dart](lib/ui/hud/game/game_overlay.dart)

---

## Phase Checklist

## Pre-flight (Definition of Ready)

- [ ] Confirm current leaderboard ghost-start path works on latest branch.
- [ ] Confirm ghost-start failure snackbar is actionable.
- [ ] Record green baseline for `dart analyze` and relevant current tests.

---

## Phase 1 — Ghost snapshot contract

- [x] Add read-only current `GameStateSnapshot` accessor in `GhostPlaybackRunner`.
  - File: [lib/game/replay/ghost_playback_runner.dart](lib/game/replay/ghost_playback_runner.dart)
- [x] Add read-only access to ghost `GameEvent`s needed for hit/death VFX playback.
  - File: [lib/game/replay/ghost_playback_runner.dart](lib/game/replay/ghost_playback_runner.dart)
- [x] Ensure no gameplay-authoritative mutation leaks from ghost APIs.

Acceptance:
- [x] Renderer can read ghost snapshot each frame.
- [x] Renderer can consume ghost event stream for VFX.
- [x] Accessors are read-only and side-effect free.

---

## Phase 2 — UI → Flame bridge

- [x] Add ghost snapshot channel from `RunnerGameWidget` to `RunnerFlameGame`.
  - Suggested: `ValueNotifier<GameStateSnapshot?>`
- [x] Add ghost event channel for render-only VFX.
- [x] Clear bridge channels on restart/dispose/failure.

Files:
- [lib/ui/runner_game_widget.dart](lib/ui/runner_game_widget.dart)
- [lib/game/runner_flame_game.dart](lib/game/runner_flame_game.dart)

Acceptance:
- [x] Ghost data reaches Flame only for ghost runs.
- [x] Non-ghost runs pass `null` and remain unchanged.
- [x] Restart/dispose reliably clears all bridge notifiers/references.

---

## Phase 3 — Monochrome ghost style

- [x] Add reusable ghost visual mode in shared anim view component.
  - Grayscale + alpha
- [x] Preserve live entity combat/status visuals unchanged.
- [x] Ensure ghost supports all status effect visuals (same mask handling path).

Files:
- [lib/game/components/sprite_anim/deterministic_anim_view.dart](lib/game/components/sprite_anim/deterministic_anim_view.dart)

Acceptance:
- [x] Ghost entities are black/white and readable.
- [x] Live entities render exactly as before.
- [x] Ghost status mask visuals remain enabled.

---

## Phase 4 — Ghost entity render layer

- [x] Add ghost view pools/maps in `RunnerFlameGame`:
  - [x] ghost player
  - [x] ghost enemies
  - [x] ghost projectiles
- [x] Add per-frame ghost sync pass (interpolate + camera-space pixel snap).
- [x] Enforce scope rules:
  - [x] include player/enemy/projectile
  - [x] exclude pickups
  - [x] no ghost level/parallax/static solids/ground
- [x] Enable ghost hit/death VFX through ghost event stream.
- [x] Enforce depth band priority `-4` (behind live entities, ahead of background/static).
- [x] Use replay metadata for ghost player identity/loadout visuals.

Files:
- [lib/game/runner_flame_game.dart](lib/game/runner_flame_game.dart)
- Optional support in [lib/game/components](lib/game/components)

Acceptance:
- [x] In-world ghost entities visible and synchronized.
- [x] Layering policy matches plan.
- [x] Render scope matches plan.
- [x] Mid-run ghost render failure disables ghost visuals and run continues.

---

## Phase 5 — HUD transition

- [x] Remove/gate `ghostStatusLabel` from default HUD.
- [x] Keep optional debug-only fallback label if needed.

Files:
- [lib/ui/runner_game_widget.dart](lib/ui/runner_game_widget.dart)
- [lib/ui/hud/game/game_overlay.dart](lib/ui/hud/game/game_overlay.dart)

Acceptance:
- [x] Production UX no longer depends on text ghost label.
- [x] Optional debug-only label path is not enabled in production.

---

## Phase 6 — Tests and validation

- [x] Add/extend tests for ghost sync and lifecycle parity.
- [x] Add/extend tests for render scope filtering (no pickups).
- [x] Add/extend tests for failure behavior (silent disable + log path).
- [x] Add/extend tests for leaderboard ghost-start preconditions.
- [x] Run `dart analyze`.
- [x] Run targeted `flutter test` slices.

Likely test areas:
- [test/game](test/game)
- [test/ui](test/ui)
- [test/ui/state](test/ui/state)

---

## Cross-Cutting Rules (must hold throughout)

- [ ] Follow `AGENTS.md` boundaries (`core authoritative`, `game render-only`).
- [ ] Enforce Render Parity Rule from plan:
  - Any live render change for player/enemy/projectile must be reviewed for ghost parity in same change.
- [ ] Prefer shared abstractions over ghost-specific renderer branches.
- [ ] Keep patch size incremental; each PR should leave repo green.
- [ ] No unrelated refactors inside ghost-run PRs.

---

## Per-PR Quality Gate

- [ ] Scope matches one planned phase/sub-phase.
- [ ] Analyzer clean for changed files.
- [ ] Relevant tests added/updated and passing.
- [ ] Acceptance criteria for touched checklist items satisfied.
- [ ] Docs updated when behavior/contract shifted.

---

## Rollback Preparedness

- [ ] Temporary feature switch path identified for in-world ghost render layer.
- [ ] Leaderboard ghost-start contract remains intact even if renderer layer is disabled.
- [ ] Debug-only fallback label path documented for diagnosis builds.

---

## PR Sequencing Recommendation

1. PR-1: Phase 1 (ghost snapshot/event contract)
2. PR-2: Phase 2 (bridge)
3. PR-3: Phase 3 (style)
4. PR-4: Phase 4 (entity layer + VFX)
5. PR-5: Phase 5 (HUD cleanup)
6. PR-6: Phase 6 (test hardening + docs follow-up)

Each PR should include:
- scope-limited code changes
- targeted tests
- short changelog note in [docs/building/ghostRun/plan.md](docs/building/ghostRun/plan.md)
