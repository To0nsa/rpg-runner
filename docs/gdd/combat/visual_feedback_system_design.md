# Combat Visual Feedback

## Purpose

Defines how Core emits semantic visual cues and how render maps them to pulse/tint visuals.

## Architecture Split

### Core

Core emits cue events with:

- `entityId`
- `kind` (`directHit`, `dotPulse`, `resourcePulse`)
- `intensityBp` (`10000 == 1.0`)
- optional metadata (`damageType`, `resourceType`)

Core intensity comes from `GameCore`:

```dart
static const int _visualCueIntensityScaleBp = 10000;
static const int _damagePulseMaxAmount100 = 1500;
static const int _resourcePulseMaxAmount100 = 1200;
static const int _damagePulseMinIntensityBp = 1800;
static const int _resourcePulseMinIntensityBp = 2000;
```

### Render Layer

Render styling lives in `CombatFeedbackTuning`:

- pulse duration/alpha curves
- fade exponent
- colors by damage/resource/status type

## Core Intensity Formulas

### Damage pulses (`directHit` and `dotPulse`)

```text
scaled = floor(appliedAmount100 * 10000 / 1500)
intensityBp = clamp(scaled, 1800, 10000) if appliedAmount100 > 0 else 0
```

### Resource pulses

```text
scaled = floor(restoredAmount100 * 10000 / 1200)
intensityBp = clamp(scaled, 2000, 10000) if restoredAmount100 > 0 else 0
```

## Same-Tick Coalescing

`EntityVisualCueCoalescer` keeps one cue per `(entityId, kind)` per tick:

- highest `intensityBp` wins
- metadata from the winning cue is kept

This is independent from `PlayerImpactFeedbackGate` (camera/haptics/border throttling).

## Current Render Mapping

`intensity01 = clamp(intensityBp / 10000.0, 0.0, 1.0)`

Pulse mapping uses linear interpolation between min/max values.

Current defaults (`lib/game/tuning/combat_feedback_tuning.dart`):

- `directHitPulse`: duration `0.14..0.22`, alpha `0.35..0.65`, exponent `2.0`
- `dotPulse`: duration `0.14..0.22`, alpha `0.35..0.65`, exponent `2.0`
- `resourcePulse`: duration `0.14..0.22`, alpha `0.35..0.65`, exponent `2.0`

## Persistent Status Tint

Always-on status tint uses `EntityStatusVisualMask` bits:

- `slow`, `haste`, `ward`, `vulnerable`, `weaken`, `drench`, `stun`, `silence`

Alpha combines by active status-type count:

```text
alpha = clamp(statusBaseAlpha + (count - 1) * statusAdditionalAlphaPerEffect,
              0.0, statusMaxAlpha)
```

Current defaults:

- `statusBaseAlpha = 0.35`
- `statusAdditionalAlphaPerEffect = 0.025`
- `statusMaxAlpha = 0.45`

## Source of Truth

- Core cue emission/intensity:
  - `lib/core/game_core.dart`
  - `lib/core/events/entity_visual_cue_coalescer.dart`
  - `lib/core/events/feedback_events.dart`
- Render mapping/tuning:
  - `lib/game/tuning/combat_feedback_tuning.dart`
  - `lib/game/runner_flame_game.dart`
  - `lib/game/components/sprite_anim/deterministic_anim_view_component.dart`
