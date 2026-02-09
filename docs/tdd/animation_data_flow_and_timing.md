# Animation Data Flow And Timing (Core -> Snapshot -> Render)

This doc explains how authored animation data is consumed, which layer owns each decision, and why gameplay timing can diverge from visual strip length.

## 1) Ownership: who controls what

- `AbilityDef` (`lib/core/abilities/ability_def.dart`)
  - Owns gameplay action timing: `windupTicks`, `activeTicks`, `recoveryTicks`, `totalTicks`.
  - Owns logical action animation choice: `animKey`.
- `ActiveAbilityPhaseSystem` (`lib/core/ecs/systems/active_ability_phase_system.dart`)
  - Advances `elapsedTicks` and phase each tick.
  - Clears active abilities when finished or forcibly interrupted.
- `AnimSystem` + `AnimResolver` (`lib/core/ecs/systems/anim/anim_system.dart`, `lib/core/anim/anim_resolver.dart`)
  - Convert gameplay state into `(AnimKey, animFrame)` in deterministic Core ticks.
- `RenderAnimSetDefinition` (`lib/core/contracts/render_anim_set_definition.dart`)
  - Defines frame count and step time per animation key.
- Flame render components (`lib/game/components/sprite_anim/*.dart`)
  - Map `animFrame` to sprite frame index using `ticksPerFrame`.

## 2) Tick pipeline (authoritative flow)

Per fixed tick in `GameCore.stepOneTick` (`lib/core/game_core.dart`):

1. `ActiveAbilityPhaseSystem.step` updates active ability elapsed/phase.
2. Gameplay systems run (movement, combat, death, etc.).
3. `AnimSystem.step` runs near end of tick and writes `world.animState.anim` + `world.animState.animFrame`.
4. `SnapshotBuilder.build` copies these fields into `EntityRenderSnapshot`.
5. Render consumes the snapshot and applies deterministic frame selection.

Important: render does not decide gameplay phase. It only displays what Core already resolved.

## 3) Resolver behavior and frame-origin policy

`AnimResolver.resolve` priority is:

1. Stun
2. Death
3. Hit react
4. Active action (ability-driven key/frame)
5. Locomotion (jump/fall/spawn/idle/walk/run)

Frame-origin policy:

- Relative-to-start frame origin:
  - stun, death, hit, spawn, active action
- Global tick frame origin:
  - jump, fall, idle, walk, run

This policy is locked by resolver tests in `test/core/anim_resolver_test.dart`.

## 4) How render computes visible frame

In `DeterministicAnimViewComponent.applySnapshot` (`lib/game/components/sprite_anim/deterministic_anim_view_component.dart`):

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

## 5) Why same animation can look wrong across abilities

If two abilities share one `AnimKey` (for example `AnimKey.cast`) but have different authored gameplay durations, they still use the same strip step time and frame count.

That can cause:

- early cutoff (ability ends before strip reaches later frames), or
- hold/freeze on last frame (one-shot clamp), or
- repeated loop segments (looping keys).

This is expected unless you align gameplay duration and visual duration by design.

## 6) Practical tuning rules

- If you want 1:1 visual-to-gameplay timing for an action:
  - set `abilityTotalTicks` close to the strip length in ticks.
- If you want fixed visual speed across abilities:
  - keep strip step times constant and balance with cooldown, damage, costs, and phase split.
- If abilities need different visual rhythms:
  - give them separate `AnimKey`s and strips (or separate render keys mapped from authored actions).

Useful estimate:

```text
fullStripTicks = frameCountsByKey[key] * ticksPerFrameFor(key, tickHz)
```

## 7) About remaining player anim tuning fields

`AnimTuning` currently keeps:

- `hitAnimSeconds`
- `deathAnimSeconds`
- `spawnAnimSeconds`

These are still used by Core lifecycle windows:

- hit-react visibility window in `AnimResolver`
- death animation freeze/end handling in `GameCore` and enemy death systems
- player spawn animation window in `AnimResolver`

They are not the per-ability action speed control.

## 8) Debug checklist

When animation behavior looks wrong, check in this order:

1. Ability has the intended `animKey` in catalog/definition.
2. `ActiveAbilityPhaseSystem` is updating `elapsedTicks` as expected.
3. Resolver priority is not being overridden by stun/death/hit.
4. Snapshot has expected `anim` and `animFrame`.
5. Render set contains that key in `sourcesByKey`, `frameCountsByKey`, and `stepTimeSecondsByKey`.
6. Compare `abilityTotalTicks` vs `fullStripTicks` for that key.
