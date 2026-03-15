# Ghost Run Visual Layer Plan

## 1) Goal

Replace the ghost text-only HUD with in-world ghost visuals while preserving deterministic gameplay authority.

### In scope

- Render ghost `player`, `enemies`, and `projectiles` in grayscale.
- Keep level/parallax/static world rendering unchanged.
- Keep non-ghost runs behaviorally and visually unchanged.

### Out of scope

- Performance instrumentation (deferred unless needed).
- Accessibility/readability fine-tuning (deferred until first implementation pass lands).

---

## 2) Current State

- Ghost replay bootstrap is loaded before run start (when ghost run is explicitly requested).
- `RunnerGameWidget` advances `GhostPlaybackRunner` with live tick progression.
- HUD currently shows a ghost status label.
- No in-world ghost entity rendering yet.

---

## 2.1) Execution Progress

- [x] Phase 1 — Ghost Snapshot Contract
- [x] Phase 2 — UI → Flame Ghost Bridge
- [x] Phase 3 — Ghost Visual Style
- [x] Phase 4 — Ghost Entity Rendering Layer
- [x] Phase 5 — HUD Cleanup
- [ ] Phase 6 — Tests and Validation hardening

---

## 3) Confirmed Product Decisions

- Pickups are excluded from ghost rendering.
- Ghost hit VFX and death VFX are included.
- Ghost player uses full live status effect visuals.
- Ghost player visuals are authoritative from replay metadata (`playerCharacterId` + replay loadout snapshot).
- Ghost entities render:
  - behind live entities,
  - but in front of parallax/background/platform visuals.
- Ghost lifecycle follows live run lifecycle (pause/restart/game-over/exit parity).
- If ghost desync/render fails mid-run: continue live run and silently disable ghost visuals.

---

## 4) Engineering Defaults

### Preload contract

- Execute during leaderboard ghost-start preparation (before route navigation).
- Scope: ghost replay bootstrap + ghost render assets (player/enemy/projectile).
- Timeout budget: 2 seconds.
- If preload/bootstrap fails for ghost-start action: fail start with user-facing error.
- Non-ghost start path remains unaffected.

### Sync contract

- Advance ghost with `advanceToTick(liveTick)` (lockstep).
- Pause live run => pause ghost progression.
- Restart => reset ghost and replay from tick 0.
- Replay end => freeze ghost at final state (no extrapolation).

### VFX contract

- Ghost VFX source is ghost simulation event stream (not inferred from snapshots).

### Layer/depth default

- Use ghost priority band `-4`.
- This keeps ghost behind live `-3/-2/-1` and ahead of static/background layers `<= -5`.

### Observability

- Mid-run disable is silent to players.
- Emit structured debug logs with `reasonCode`, `runSessionId`, `boardId`, `entryId`.

### Execution safeguards

- Implement in small, reviewable PRs (one phase per PR when practical).
- Preserve existing layer boundaries from `AGENTS.md`/`lib/AGENTS.md`/`lib/game/AGENTS.md`.
- Prefer shared abstractions over copy/paste ghost branches.
- Avoid unrelated refactors in ghost-run PRs.

---

## 5) Architectural Constraints

- Core authority remains in `packages/runner_core/lib/`.
- Flame layer remains render-only.
- Ghost visuals must not mutate live simulation state.
- No side effects in widget `build` methods.
- Keep run submission and route contracts intact.

---

## 5.1) Render Parity Rule

To prevent renderer drift and branch-heavy maintenance:

- Any render change that affects `player`, `enemy`, or `projectile` visuals in live runs must be reviewed for ghost parity in the same change.
- Preferred implementation style is shared render logic + style/data variation:
   - shared component/registry behavior,
   - data source variation (live snapshot vs ghost snapshot),
   - visual style variation (normal vs ghost).
- Do not introduce separate long-lived ghost-only render branches when the behavior can be expressed via shared abstractions.
- Non-entity world visuals (level/parallax/static solids/ground) are excluded from ghost parity requirements.

---

## 6) Phased Implementation

### Definition of Ready (before Phase 1 starts)

- Ghost-start from leaderboard is confirmed stable in current branch.
- Failing ghost bootstrap shows actionable snackbar error.
- Existing run route tests and analyzer are green baseline.

## Phase 1 — Ghost Snapshot Contract

### Goal

Expose current ghost frame as render-safe snapshot data.

### Work

1. Add read-only current `GameStateSnapshot` accessor in `GhostPlaybackRunner`.
2. Keep ghost progression controlled only by `advanceToTick()`.

### Files

- `lib/game/replay/ghost_playback_runner.dart`

### Acceptance

- Renderer can read current ghost snapshot each frame.
- No gameplay logic consumes ghost snapshot as authority.
- Ghost snapshot accessor is read-only and side-effect free.

---

## Phase 2 — UI → Flame Ghost Bridge

### Goal

Feed ghost snapshots/events from run host into Flame renderer.

### Work

1. In `RunnerGameWidget`:
   - maintain a render-facing ghost snapshot channel (e.g., `ValueNotifier<GameStateSnapshot?>`),
   - update on ghost tick advance,
   - clear on reset/unavailable.
2. In `RunnerFlameGame`:
   - accept ghost snapshot source,
   - accept ghost event source for ghost hit/death VFX.

### Files

- `lib/ui/runner_game_widget.dart`
- `lib/game/runner_flame_game.dart`

### Acceptance

- Ghost data reaches Flame only for ghost runs.
- Non-ghost runs pass `null` and remain unchanged.
- Restart/dispose always clear bridge channels.

---

## Phase 3 — Ghost Visual Style

### Goal

Introduce reusable grayscale ghost styling for animated entity views.

### Work

1. Add ghost visual mode to shared animation view:
   - grayscale,
   - partial alpha,
   - does not break deterministic animation stepping.
2. Ensure live combat feedback tinting remains unaffected for non-ghost entities.

### Files

- `lib/game/components/sprite_anim/deterministic_anim_view_component.dart`
  - or adjacent ghost-specific component in same module

### Acceptance

- Ghost entities are visibly grayscale and distinct.
- Live entities retain current visuals.
- Ghost status mask visuals still apply (same behavior as live equivalent).

---

## Phase 4 — Ghost Entity Rendering Layer

### Goal

Render ghost entities in-world as a separate layer.

### Work

1. Add ghost pools/maps in `RunnerFlameGame`:
   - ghost player view,
   - ghost enemy views,
   - ghost projectile views.
2. Reuse registries/anim sets where possible.
3. Add per-frame ghost sync pass:
   - read ghost snapshot entities,
   - interpolate/snap in camera space,
   - mount/update/remove views.
4. Enforce depth rules:
   - ghost priority `-4`,
   - behind live entities, ahead of background/static layers.
5. Enforce scope rules:
   - no ghost level/parallax/solids/ground,
   - no ghost pickups,
   - only player/enemy/projectile kinds,
   - include ghost hit/death VFX,
   - player identity from replay metadata (not local selection).

### Files

- `lib/game/runner_flame_game.dart`
- optional support files in `lib/game/components/**`

### Acceptance

- Ghost entities render in-world and track replay correctly.
- Layering and scope rules are respected.
- Non-ghost runs remain unchanged.
- Ghost render failures disable ghost visuals without affecting live gameplay loop.

---

## Phase 5 — HUD Cleanup

### Goal

Remove text-first ghost status from default UX after in-world ghost visuals land.

### Work

1. Remove/gate `ghostStatusLabel` in normal UI.
2. Keep optional debug-only status output if needed.

### Files

- `lib/ui/runner_game_widget.dart`
- `lib/ui/hud/game/game_overlay.dart`

### Acceptance

- Standard UX shows in-world ghost only.
- Optional debug fallback does not leak into production UX.

---

## Phase 6 — Tests and Validation

### Test targets

- `test/game/**`: ghost sync, reset/lifecycle parity.
- `test/ui/**`: route-level ghost/non-ghost parity, restart behavior.
- `test/ui/state/**`: ghost-start preload/bootstrap contracts.

### Coverage focus

1. Ghost mount/update/remove behavior.
2. Render scope filtering (no pickups, correct kinds only).
3. Visual mode correctness (grayscale ghost, unchanged live entities).
4. Failure behavior (silent mid-run disable + log emission).

### Commands

- `dart analyze`
- targeted `flutter test` for changed slices

### Acceptance

- Existing tests stay green.
- New behavior is covered by focused tests.
- Lifecycle parity validated.
- Structured logs exist for mid-run ghost disable path.

---

## 7) Risks and Mitigations

1. **Performance overhead** from duplicate render paths.
   - Mitigation: pool components, render only selected kinds, skip when ghost data missing.

2. **Visual clutter/readability** on some themes.
   - Mitigation: grayscale + alpha now; tune outline/contrast later.

3. **Asset mismatch** with replay identity.
   - Mitigation: derive from replay metadata and preload before run start.

4. **Tight coupling** between UI host and Flame.
   - Mitigation: one-way render data channels only.

---

## 8) Rollout Plan

1. Land snapshot contract + bridge.
2. Land ghost render layer (optionally behind temporary flag).
3. Validate on competitive + weekly ghost starts from leaderboard.
4. Remove text-first label from normal UX.

### Rollback strategy

- If regressions appear, gate in-world ghost rendering behind a temporary feature switch while keeping ghost-start contracts intact.
- Preserve current leaderboard ghost-start behavior and error surfacing even when renderer layer is disabled.
- Re-enable text-only debug label temporarily only for diagnosis builds, not production UX.

---

## 9) Definition of Done

- Ghost runs render grayscale in-world ghost entities.
- Included kinds: player, enemy, projectile.
- Excluded kind: pickups.
- Ghost hit/death VFX visible.
- Layer policy matches decision (behind live, ahead of background/static).
- Non-ghost runs unchanged.
- Relevant analysis/tests pass.

---

## 10) Post-Implementation Documentation Checklist

- Update this plan with final architecture notes and deviations.
- Add implementation summary under `docs/building/ghostRun/`.
- Update `AGENTS.md` guidance if boundaries changed.
- Update any public/developer docs affected by ghost run UX contract.
