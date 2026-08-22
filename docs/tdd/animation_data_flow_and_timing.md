# Animation Data Flow And Timing (Core -> Snapshot -> Render)

This doc explains how authored animation data is consumed, which layer owns each decision, and why gameplay timing can diverge from visual strip length.

## 1) Ownership: who controls what

- `AbilityDef` (`packages/runner_core/lib/abilities/ability_def.dart`)
  - Owns authored gameplay action timing: `windupTicks`, `activeTicks`, `recoveryTicks`.
  - These values use 60 Hz authoring-tick semantics; activation systems resolve
    them to the run's tick rate before committing an action.
  - Owns logical action animation choice: `animKey`.
- `ActiveAbilityStateStore` (`packages/runner_core/lib/ecs/stores/active_ability_state_store.dart`)
  - Owns runtime action timing state: `startTick`, `elapsedTicks`, `phase`, `totalTicks`.
  - Its timing fields are the committed values after tick-rate and applicable
    action-speed scaling. `totalTicks` may also be adjusted by hold/recovery flow.
- `ActiveAbilityPhaseSystem` (`packages/runner_core/lib/ecs/systems/active_ability_phase_system.dart`)
  - Advances `elapsedTicks` and phase each tick.
  - Clears active abilities when finished or forcibly interrupted.
- `AnimSystem` + `AnimResolver` (`packages/runner_core/lib/ecs/systems/anim/anim_system.dart`, `packages/runner_core/lib/anim/anim_resolver.dart`)
  - Convert gameplay state into `(AnimKey, animFrame)` in deterministic Core ticks.
- `RenderAnimSetDefinition` (`packages/runner_core/lib/contracts/render_anim_set_definition.dart`)
  - Defines frame count and step time per animation key.
- Flame render components (`lib/game/components/sprite_anim/*.dart`)
  - Map `animFrame` to sprite frame index using `ticksPerFrame`.

## 2) Tick pipeline and snapshot flow

On a normal fixed tick, `GameCore.stepOneTick`
(`packages/runner_core/lib/game_core.dart`) does the following:

1. `ActiveAbilityPhaseSystem.step` updates active ability elapsed/phase.
2. Gameplay systems run (movement, combat, death, etc.).
3. `AnimSystem.step` runs near end of tick and writes `world.animState.anim` + `world.animState.animFrame`.
4. After the Core step, `GameController.advanceFrame` calls
   `GameCore.buildSnapshot`; `SnapshotBuilder.build` copies the animation fields
   into `EntityRenderSnapshot`.
5. Render consumes that snapshot and applies deterministic frame selection.

Player death is a deliberate exception to the normal path. The gameplay tick
that detects player death schedules the death animation and returns before the
normal `AnimSystem` step. Each following death-freeze tick runs animation only
until the run ends; the controller still builds a snapshot after each Core step.

Important: render does not decide gameplay phase. It only displays what Core already resolved.

## 3) Resolver behavior and frame-origin policy

`AnimResolver.resolve` priority is:

1. Stun
2. Death
3. Hit react
4. Active action (ability-driven key/frame)
5. Locomotion (jump/fall, spawn, idle, dash, walk, run)

Frame-origin policy:

- Relative-to-start frame origin:
  - stun, death, hit, spawn, active action
- Global tick frame origin:
  - jump, fall, idle, locomotion dash, walk, run

An ability-driven dash is an active action and therefore uses the active
action's relative elapsed-tick origin; only the locomotion dash uses global
tick origin.

This policy is locked by resolver tests in `test/core/anim_resolver_test.dart`.

## 4) How render computes visible frame

In `DeterministicAnimView.applySnapshot` (`lib/game/components/sprite_anim/deterministic_anim_view.dart`):

1. Read `anim` and `animFrame` from snapshot.
2. Compute `ticksPerFrame` from `SpriteAnimSet.ticksPerFrameFor(key, tickHz)`.
3. Convert:

```text
rawIndex = animFrame ~/ ticksPerFrame
```

4. Final index:
  - one-shot keys: clamp to last frame
  - looping keys: modulo frame count

`ticksPerFrame` comes from render step time:

```text
ticksPerFrame = max(1, round(stepTimeSecondsByKey[key] * tickHz))
```

So visual playback speed is controlled by `stepTimeSecondsByKey`, not by ability cooldown/damage values.
Core lifecycle windows that cover a full hit, death, or spawn strip use the
same quantized duration:

```text
fullStripTicks = frameCountsByKey[key] * ticksPerFrame
```

This prevents fractional frame steps from leaving a completed strip on its last
frame after its Core lifecycle window should have ended.

## 5) Why same animation can look wrong across abilities

If two abilities share one `AnimKey` (for example `AnimKey.cast`) but have
different committed gameplay durations, they still use the same strip step
time and frame count.

That can cause:

- early cutoff (ability ends before strip reaches later frames), or
- hold/freeze on last frame (one-shot clamp), or
- repeated loop segments (looping keys).

This is expected unless you align gameplay duration and visual duration by design.

## 6) Practical tuning rules

- If you want 1:1 visual-to-gameplay timing for an action:
  - compare the committed `ActiveAbilityStateStore.totalTicks` to the strip
    length in runtime ticks, rather than comparing only the authored values.
  - authored ability timings are 60 Hz ticks. They are rescaled for a run with
    another tick rate; for attack/cast slots, action speed can also adjust
    windup and recovery. The active window is tick-rate-scaled but is not
    action-speed-scaled.
  - for hold-maintain abilities, compare the actual hold window plus recovery
    against strip length, because release or stamina depletion can enter
    recovery early.
- If you want fixed visual speed across abilities:
  - keep strip step times constant and balance with cooldown, damage, costs, and phase split.
- If abilities need different visual rhythms:
  - give them separate `AnimKey`s and strips (or separate render keys mapped from authored actions).

Useful estimate:

```text
fullStripTicks = frameCountsByKey[key] * ticksPerFrameFor(key, tickHz)
```

## 7) About remaining player anim tuning fields

`AnimTuning` currently keeps authored fallback durations:

- `hitAnimSeconds`
- `deathAnimSeconds`
- `spawnAnimSeconds`

When the selected player's `RenderAnimSetDefinition` supplies the matching
strip, Core derives these lifecycle windows from the strip's quantized tick
duration. The `AnimTuning` seconds values remain the fallback for content
without that strip timing. The resulting player windows control:

- hit-react visibility window in `AnimResolver`
- player death animation freeze/end handling in `GameCore`
- player spawn animation window in `AnimResolver`

They are not the per-ability action speed control. Enemy hit, spawn, and death
durations are configured by their `EnemyCatalog` entries and use their render
strip timing when available; the enemy `*AnimSeconds` fields are the fallback.

`EnemyArchetype.renderScale` is the positive uniform presentation scale paired
with `renderAnim`. The Flame enemy registry converts it to its `Vector2` scale,
and repository tools may use the same value with the frame anchor to reproduce
the runtime sprite footprint. It is render metadata only and does not enter
simulation collision, placement, timing, or replay authority.

## 8) Debug checklist

When animation behavior looks wrong, check in this order:

1. Ability has the intended `animKey` in catalog/definition.
2. `ActiveAbilityPhaseSystem` is updating `elapsedTicks` as expected.
3. Resolver priority is not being overridden by stun/death/hit.
4. Snapshot has expected `anim` and `animFrame`.
5. Render set contains that key in `sourcesByKey`, `frameCountsByKey`, and `stepTimeSecondsByKey`.
6. Compare the committed runtime action timing (`totalTicks`, or the current
   hold window plus recovery) vs `fullStripTicks` for that key.
