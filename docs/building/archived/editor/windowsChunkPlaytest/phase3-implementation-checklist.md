# Windows Chunk Playtest Phase 3 Implementation Checklist

Date: August 19, 2026

Status: Complete (August 19, 2026)

Source plan: [Windows Chunk Playtest and Reusable Desktop Input Plan](plan.md)

Phase 2 evidence:
[Phase 2 implementation checklist](phase2-implementation-checklist.md)

This checklist implements Phase 3 only: establish one device-neutral gameplay
action lifecycle above `RunnerInputRouter`, migrate the existing touch host to
that lifecycle, and add a reusable Windows keyboard/mouse adapter with local
focus and viewport-aware aim. It does not mount desktop input in the shipping
game or add the editor playtest host.

## Completion gate

Phase 3 is complete only when:

- touch and desktop translate device events into one semantic dispatcher, and
  neither device adapter schedules Core commands directly
- all admitted ability modes preserve their existing press, hold, aimed
  commit, release, and cancel semantics
- projectile `holdMaintain` and non-tap spell/jump modes fail explicitly
  instead of falling through to incidental widget behavior
- alternate physical keys, opposing directions, key repeat, mouse chords, and
  pointer cancellation cannot duplicate an edge or leave input latched
- mouse aim excludes letterbox space and derives its normalized vector from
  the rendered player point using the shared viewport/camera mapping
- one adapter-owned `FocusNode` supports explicit request, release, focus-loss,
  pause, and disposal cancellation
- existing touch-control and router characterization tests remain green and
  desktop implementation files import no touch-control modules

## Scope boundaries

### In scope

- source-neutral semantic gameplay action dispatch beside the input router
- authoritative HUD-mode resolution at each new ability press
- semantic tap, begin, commit, end, release, aim, movement, and `cancelAll`
- existing `GameOverlay`/`RunnerGameWidget` touch migration
- a Windows keyboard/mouse adapter, fixed bindings, and pressed-state tracking
- reusable viewport/player aim geometry and normalization
- adapter-local focus ownership and lifecycle methods
- focused unit/widget tests and an input-boundary TDD update

### Out of scope

- mounting desktop controls in `RunnerGameWidget` or changing its public API
- editor F5/F6/Escape/P/Enter shortcut ownership
- backend-free playtest host, Flame asset injection, or editor integration
- configurable or persisted bindings, controller/gamepad input, or web policy
- changes to Core ability rules, command payloads, replay frames, or backend
- touch visual, gesture, affordability, cooldown, or radial-layout redesign

## Chosen input boundary

| Concern | Phase 3 owner |
| --- | --- |
| Pointer gesture recognition and previews | existing touch controls |
| Physical key/button/focus state | desktop adapter |
| Viewport/player coordinate conversion | desktop aim geometry |
| Ability mode lifecycle and cancellation | semantic dispatcher |
| Tick buffering, held-slot exclusivity, same-tick aim commit | `RunnerInputRouter` |
| Command coalescing and deterministic input frames | `GameController` |
| Pause/start/restart/stop | later host lifecycle |

Touch callbacks remain shaped around the leaf widgets' established ordering.
Directional release commits before hold-end, while the existing non-directional
hold-release widget ends its hold before invoking its release callback. Both
edges retain their current same-tick command result; pointer cancellation never
commits.

## Step 0 — Baseline and ownership audit

- [x] Re-read game/UI layer and code-documentation guidance.
- [x] Trace touch leaf callback ordering through `GameOverlay` and the router.
- [x] Confirm `RunnerFlameGame` only pumps the low-level router and remains
      independent of device adapters.
- [x] Confirm the fixed binding table excludes editor host actions.
- [x] Identify unrelated dirty terrain/editor files and keep them outside every
      Phase 3 commit.

## Step 1 — Add the semantic dispatcher

- [x] Add a Flutter/device-free dispatcher beside `RunnerInputRouter`.
- [x] Resolve each ability mode from the current HUD snapshot when its press
      lifecycle begins and retain that mode through release/cancel.
- [x] Support one-shot tap, held begin, explicit commit, non-committing end,
      desktop release, movement directions/axis, aim, and held-input pumping.
- [x] Preserve router-owned latest-hold-wins and same-tick aimed commit
      behavior; do not enqueue commands from the dispatcher itself.
- [x] Make repeated begin/end/cancel calls idempotent.
- [x] Make `cancelAll` neutralize movement, clear aim, release every hold, and
      pump the neutral state.
- [x] Reject unsupported action/mode pairs with stable diagnostics.

## Step 2 — Prove semantic action behavior

- [x] Test tap actions for primary, secondary, projectile, mobility, spell, and
      jump.
- [x] Test `holdAimRelease`, `holdMaintain`, and `holdRelease` for every
      supported ability slot.
- [x] Test commit/end ordering, cancel-without-commit, and mode retention when
      the HUD mode changes mid-hold.
- [x] Test opposing directions and alternate-source reference behavior.
- [x] Test duplicate edges and repeated idempotent `cancelAll` calls.
- [x] Test explicit rejection of projectile `holdMaintain` and non-tap
      spell/jump modes.

## Step 3 — Migrate the existing touch host

- [x] Make `RunnerGameWidget` own one semantic dispatcher per controller.
- [x] Pass semantic actions, not `RunnerInputRouter`, into `GameOverlay`.
- [x] Translate current touch callbacks without changing leaf widgets,
      affordability, cooldowns, previews, or release/cancel order.
- [x] Replace the run widget's manual router clear sequence with dispatcher
      cancellation plus preview cleanup.
- [x] Cancel before controller/preview disposal without changing shipping
      lifecycle resume policy.
- [x] Keep `RunnerFlameGame` wired to the low-level router for frame pumping.

## Step 4 — Add viewport-aware desktop aim

- [x] Add immutable aim geometry that accepts fitted viewport metrics, virtual
      dimensions, authoritative camera center, and rendered player position.
- [x] Exclude letterbox/editor-chrome positions before producing an aim vector.
- [x] Convert world player position through the shared world/view transform,
      scale it through the fitted viewport, normalize cursor delta, and let the
      existing router quantize it.
- [x] Clear aim for zero-length vectors and pointer exit.
- [x] Test centered and aligned viewports, scaling, letterbox exclusion,
      camera offsets, non-zero player positions, and zero-length aim.

## Step 5 — Add the Windows keyboard/mouse adapter

- [x] Keep Flutter key, pointer, and focus types under
      `lib/ui/input/desktop/**` only.
- [x] Own exactly one `FocusNode` and expose explicit `requestFocus`,
      `releaseFocus`, `cancelAll`, pause, and disposal operations.
- [x] Track physical keys so OS repeats emit no duplicate gameplay edge.
- [x] Reference-count alternate keys for the same action so releasing one does
      not release another still-held binding.
- [x] Resolve left+right to neutral and recompute immediately on either release.
- [x] Track mouse-button transitions from button masks, including chords,
      cancel, and lost-focus cleanup.
- [x] Update aim only inside the current fitted viewport; leaving it clears
      pointer-derived aim without changing keyboard movement.
- [x] Invoke a host callback after focus-loss cancellation so Phase 4 can pause
      without putting pause into gameplay actions.
- [x] Confirm the module imports no editor or touch-control implementation.

## Step 6 — Desktop focus and event tests

- [x] Test every fixed key and mouse mapping through the adapter.
- [x] Test alternate key rollover, opposing movement, key repeat, and release
      after another binding remains pressed.
- [x] Test mouse chords, secondary-button release, pointer cancel, pointer exit,
      and cursor re-entry.
- [x] Test keyboard ability use with and without a current mouse aim vector.
- [x] Test focus acquisition, focus loss, explicit pause cancellation,
      `releaseFocus`, disposal, and repeated cancellation.
- [x] Prove no command edge survives focus loss or adapter disposal.

## Step 7 — Documentation, validation, and commits

- [x] Add/update the input-boundary TDD with semantic, device, focus, viewport,
      cancellation, and host-lifecycle ownership.
- [x] Update this source plan with factual Phase 3 delivery status only.
- [x] Confirm no GDD or public embedding documentation change is needed because
      desktop input is not mounted in the product host yet.
- [x] Run `dart format` on changed Dart files.
- [x] Run root `dart analyze`; accept only the external Firebase CLI template
      errors under `functions/node_modules` and validate `lib test` directly.
- [x] Run focused semantic dispatcher, router, desktop adapter, viewport, touch
      controls, and run-widget tests.
- [x] Run the broader relevant Flutter test slice if focused gates are green.
- [x] Run `git diff --check` and an import-boundary search.
- [x] Commit the checklist, semantic/touch milestone, desktop milestone, and
      factual closeout as coherent validated commits.

## Evidence record

### Validation

| Date | Command/test | Result | Notes |
| --- | --- | --- | --- |
| August 19, 2026 | `dart analyze lib test` | Pass | No issues in the application/test workspace. Root `dart analyze` additionally enters Firebase CLI templates under `functions/node_modules` and reports six missing-template-package errors outside this Dart package. |
| August 19, 2026 | Focused Phase 3 plus existing router/touch suites | Pass (76 tests) | Semantic modes/order/cancel, router release behavior, fixed desktop bindings, geometry, adapter focus/events, and existing touch widgets. |
| August 19, 2026 | Full root `flutter test` | External baseline exception | 784 tests passed; the pre-existing malformed-record expectation in `packages/runner_core/test/track/staged_terrain_world_geometry_test.dart` remains the only failure. |
| August 19, 2026 | Desktop import boundary and `git diff --check` | Pass | Desktop code imports no touch controls or editor code; no whitespace errors. |

### Delivered contracts

- `RunnerSemanticActionDispatcher` snapshots HUD input mode per press, supports
  both existing touch release orders, and owns idempotent semantic cancellation
  without scheduling commands outside `RunnerInputRouter`.
- `RunnerGameWidget` and `GameOverlay` route touch through the dispatcher while
  `RunnerFlameGame` continues to pump the low-level router.
- `RunnerDesktopInputController` owns one focus node and aggregates fixed
  physical key/mouse sources before emitting semantic transitions.
- `RunnerDesktopAimGeometry` maps camera/player world data through the fitted
  logical viewport, excludes letterbox space, and normalizes pointer aim.
- Desktop aim is retained and reapplied across release commits while the cursor
  stays valid; focus loss, pause, pointer cancel, and disposal cannot leave a
  held action latched.

Planning commit: `d501db7e` (`docs(editor): plan phase three desktop input`).
Semantic/touch implementation commit: `03bd98d5` (`refactor(input): centralize
gameplay action semantics`). Desktop implementation commit: `99ac7a8b`
(`feat(input): add reusable Windows desktop adapter`).

## Closeout

- [x] Every Phase 3 checkbox is complete or explicitly accepted with evidence.
- [x] Update status to `Complete` with date and commit references.
- [x] Do not begin Phase 4 host work until touch parity and desktop stuck-input
      gates are green.

Phase 3 completion means a future playtest or product host can mount the same
Windows adapter over the shared gameplay semantics. It does not itself make the
Chunk Creator playable or enable desktop input in the shipping game.
