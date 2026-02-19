# Combat Visual Feedback

## Purpose

This document defines how combat visual feedback intensity is computed and
applied, so balancing changes stay predictable over time.

It covers:

- Core-side intensity computation from gameplay values.
- Event coalescing behavior (same-tick anti-spam).
- Render-side mapping from intensity to pulse timing/alpha/colors.

---

## Architecture Split

### Core (authoritative semantics + intensity)

Core emits semantic visual cues:

- `EntityVisualCueKind.directHit`
- `EntityVisualCueKind.dotPulse`
- `EntityVisualCueKind.resourcePulse`

Each cue includes:

- target `entityId`
- `kind`
- `intensityBp` in basis points (`10000 == 1.0`)
- optional metadata (`damageType` for DoT, `resourceType` for RoT)

Core computes the numeric intensity in `GameCore`:

- `_damagePulseIntensityBp(appliedAmount100)`
- `_resourcePulseIntensityBp(restoredAmount100)`

Current constants in `GameCore`:

```dart
static const int _visualCueIntensityScaleBp = 10000;
static const int _damagePulseMaxAmount100 = 1500;
static const int _resourcePulseMaxAmount100 = 1200;
static const int _damagePulseMinIntensityBp = 1800;
static const int _resourcePulseMinIntensityBp = 2000;
```

### Game (render style only)

Game maps semantic cues to visuals through `CombatFeedbackTuning`:

- colors by damage/resource/status type
- min/max pulse duration
- min/max pulse alpha
- fade exponent

Core does not depend on Flame/UI style details.

---

## Core Intensity Formulas

### Direct-hit and DoT pulses

```text
scaled = floor(appliedAmount100 * 10000 / 1500)
intensityBp = clamp(scaled, 1800, 10000) if appliedAmount100 > 0 else 0
```

Interpretation:

- Any positive damage produces at least 18% intensity.
- 15.00 damage (`1500`) reaches full intensity (100%).
- Above 15.00 damage saturates at 100%.

### Resource-over-time pulses

```text
scaled = floor(restoredAmount100 * 10000 / 1200)
intensityBp = clamp(scaled, 2000, 10000) if restoredAmount100 > 0 else 0
```

Interpretation:

- Any positive restore produces at least 20% intensity.
- 12.00 restored (`1200`) reaches full intensity (100%).
- Above 12.00 restore saturates at 100%.

### Quick reference examples

| Input (`amount100`) | Damage intensityBp | Resource intensityBp |
|---|---:|---:|
| 100 | 1800 | 2000 |
| 300 | 2000 | 2500 |
| 600 | 4000 | 5000 |
| 1200 | 8000 | 10000 |
| 1500 | 10000 | 10000 |

---

## Coalescing and Anti-Spam

Coalescing is done by `EntityVisualCueCoalescer` per tick:

- key = `(entityId, kind)`
- if multiple cues arrive in same tick for same key:
  - keep one cue only
  - keep the highest `intensityBp`
  - keep metadata from that highest-intensity cue

This prevents visual burst spam from simultaneous impacts in one tick.

Note: This is separate from player impact gate logic (`PlayerImpactFeedbackGate`)
used for camera shake/haptics/border throttling.

---

## Render-Side Mapping

`RunnerFlameGame` converts:

```text
intensity01 = clamp(intensityBp / 10000.0, 0.0, 1.0)
```

Then `DeterministicAnimViewComponent` applies pulse tuning from
`CombatFeedbackTuning`:

- `duration = lerp(minDurationSeconds, maxDurationSeconds, intensity01)`
- `alpha = lerp(minAlpha, maxAlpha, intensity01)`
- fade curve exponent (`fadeExponent`) controls tail shape

Current defaults:

- Direct hit:
  - duration `0.06 .. 0.16`
  - alpha `0.45 .. 0.95`
  - fade exponent `3.0`
- DoT pulse:
  - duration `0.14 .. 0.22`
  - alpha `0.24 .. 0.55`
  - fade exponent `2.0`
- RoT pulse:
  - duration `0.16 .. 0.24`
  - alpha `0.28 .. 0.60`
  - fade exponent `2.0`

---

## Status Tint Behavior (Always-On)

Persistent status visuals (`slow`, `haste`, `vulnerable`, `weaken`, `drench`,
`stun`, `silence`) are not intensity-scaled by gameplay magnitude.

Behavior:

- one active bit per status type (stack count of same type does not add layers)
- multiple active types blend by averaged color
- overlay alpha rises with number of different active statuses:

```text
alpha = clamp(statusBaseAlpha + (count - 1) * statusAdditionalAlphaPerEffect,
              0.0, statusMaxAlpha)
```

All status colors and alpha controls are defined in `CombatFeedbackTuning`.

---

## Balancing Workflow

When tuning visual readability:

1. Tune Core thresholds first if readability vs damage scale is wrong.
2. Tune render pulse curves second for feel (duration/alpha/fade).
3. Tune colors last for clarity and status differentiation.
4. Re-check same-tick multi-hit scenarios to ensure coalescing still reads well.

Recommended guardrails:

- Keep min intensity non-zero for tiny hits (already true).
- Avoid setting min alpha too high across all pulse types (visual noise).
- Keep direct-hit visually dominant vs DoT/RoT pulses.
- Keep status tint alpha capped to avoid washing out sprite silhouettes.

---

## Source of Truth

- Core intensity and event emission:
  - `lib/core/game_core.dart`
  - `lib/core/events/entity_visual_cue_coalescer.dart`
  - `lib/core/events/feedback_events.dart`
- Render tuning:
  - `lib/game/tuning/combat_feedback_tuning.dart`
  - `lib/game/runner_flame_game.dart`
  - `lib/game/components/sprite_anim/deterministic_anim_view_component.dart`
