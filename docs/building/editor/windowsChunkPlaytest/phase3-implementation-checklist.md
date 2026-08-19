# Windows Chunk Playtest Phase 3 Implementation Checklist

Date: August 19, 2026

Status: In progress

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

- [ ] Add a Flutter/device-free dispatcher beside `RunnerInputRouter`.
- [ ] Resolve each ability mode from the current HUD snapshot when its press
      lifecycle begins and retain that mode through release/cancel.
- [ ] Support one-shot tap, held begin, explicit commit, non-committing end,
      desktop release, movement directions/axis, aim, and held-input pumping.
- [ ] Preserve router-owned latest-hold-wins and same-tick aimed commit
      behavior; do not enqueue commands from the dispatcher itself.
- [ ] Make repeated begin/end/cancel calls idempotent.
- [ ] Make `cancelAll` neutralize movement, clear aim, release every hold, and
      pump the neutral state.
- [ ] Reject unsupported action/mode pairs with stable diagnostics.

## Step 2 — Prove semantic action behavior

- [ ] Test tap actions for primary, secondary, projectile, mobility, spell, and
      jump.
- [ ] Test `holdAimRelease`, `holdMaintain`, and `holdRelease` for every
      supported ability slot.
- [ ] Test commit/end ordering, cancel-without-commit, and mode retention when
      the HUD mode changes mid-hold.
- [ ] Test opposing directions and alternate-source reference behavior.
- [ ] Test duplicate edges and repeated idempotent `cancelAll` calls.
- [ ] Test explicit rejection of projectile `holdMaintain` and non-tap
      spell/jump modes.

## Step 3 — Migrate the existing touch host

- [ ] Make `RunnerGameWidget` own one semantic dispatcher per controller.
- [ ] Pass semantic actions, not `RunnerInputRouter`, into `GameOverlay`.
- [ ] Translate current touch callbacks without changing leaf widgets,
      affordability, cooldowns, previews, or release/cancel order.
- [ ] Replace the run widget's manual router clear sequence with dispatcher
      cancellation plus preview cleanup.
- [ ] Cancel before controller/preview disposal without changing shipping
      lifecycle resume policy.
- [ ] Keep `RunnerFlameGame` wired to the low-level router for frame pumping.

## Step 4 — Add viewport-aware desktop aim

- [ ] Add immutable aim geometry that accepts fitted viewport metrics, virtual
      dimensions, authoritative camera center, and rendered player position.
- [ ] Exclude letterbox/editor-chrome positions before producing an aim vector.
- [ ] Convert world player position through the shared world/view transform,
      scale it through the fitted viewport, normalize cursor delta, and let the
      existing router quantize it.
- [ ] Clear aim for zero-length vectors and pointer exit.
- [ ] Test centered and aligned viewports, scaling, letterbox exclusion,
      camera offsets, non-zero player positions, and zero-length aim.

## Step 5 — Add the Windows keyboard/mouse adapter

- [ ] Keep Flutter key, pointer, and focus types under
      `lib/ui/input/desktop/**` only.
- [ ] Own exactly one `FocusNode` and expose explicit `requestFocus`,
      `releaseFocus`, `cancelAll`, pause, and disposal operations.
- [ ] Track physical keys so OS repeats emit no duplicate gameplay edge.
- [ ] Reference-count alternate keys for the same action so releasing one does
      not release another still-held binding.
- [ ] Resolve left+right to neutral and recompute immediately on either release.
- [ ] Track mouse-button transitions from button masks, including chords,
      cancel, and lost-focus cleanup.
- [ ] Update aim only inside the current fitted viewport; leaving it clears
      pointer-derived aim without changing keyboard movement.
- [ ] Invoke a host callback after focus-loss cancellation so Phase 4 can pause
      without putting pause into gameplay actions.
- [ ] Confirm the module imports no editor or touch-control implementation.

## Step 6 — Desktop focus and event tests

- [ ] Test every fixed key and mouse mapping through the adapter.
- [ ] Test alternate key rollover, opposing movement, key repeat, and release
      after another binding remains pressed.
- [ ] Test mouse chords, secondary-button release, pointer cancel, pointer exit,
      and cursor re-entry.
- [ ] Test keyboard ability use with and without a current mouse aim vector.
- [ ] Test focus acquisition, focus loss, explicit pause cancellation,
      `releaseFocus`, disposal, and repeated cancellation.
- [ ] Prove no command edge survives focus loss or adapter disposal.

## Step 7 — Documentation, validation, and commits

- [ ] Add/update the input-boundary TDD with semantic, device, focus, viewport,
      cancellation, and host-lifecycle ownership.
- [ ] Update this source plan with factual Phase 3 delivery status only.
- [ ] Confirm no GDD or public embedding documentation change is needed because
      desktop input is not mounted in the product host yet.
- [ ] Run `dart format` on changed Dart files.
- [ ] Run root `dart analyze`.
- [ ] Run focused semantic dispatcher, router, desktop adapter, viewport, touch
      controls, and run-widget tests.
- [ ] Run the broader relevant Flutter test slice if focused gates are green.
- [ ] Run `git diff --check` and an import-boundary search.
- [ ] Commit the checklist, semantic/touch milestone, desktop milestone, and
      factual closeout as coherent validated commits.

## Evidence record

### Validation

| Date | Command/test | Result | Notes |
| --- | --- | --- | --- |
| Pending | Root analysis | Pending | — |
| Pending | Semantic/touch tests | Pending | — |
| Pending | Desktop/focus/viewport tests | Pending | — |
| Pending | Import and whitespace checks | Pending | — |

### Delivered contracts

Pending implementation.

## Closeout

- [ ] Every Phase 3 checkbox is complete or explicitly accepted with evidence.
- [ ] Update status to `Complete` with date and commit references.
- [ ] Do not begin Phase 4 host work until touch parity and desktop stuck-input
      gates are green.

Phase 3 completion means a future playtest or product host can mount the same
Windows adapter over the shared gameplay semantics. It does not itself make the
Chunk Creator playable or enable desktop input in the shipping game.
