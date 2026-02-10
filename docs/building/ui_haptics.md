# UI Haptics

This document defines the UI-layer haptics contract.

## Scope

- Applies only to `lib/ui/**`.
- Core never triggers platform haptics directly.

## Architecture

- `UiHapticsCue`: semantic cue enum (`lib/ui/haptics/haptics_cue.dart`).
- `UiHaptics`: service interface (`lib/ui/haptics/haptics_service.dart`).
- `UiHapticsDriver`: platform driver abstraction (`lib/ui/haptics/haptics_driver.dart`).

`UiHapticsService` maps cues to default intensities and delegates to the driver.

## Current Cue Mapping

- `chargeHalfTierReached` -> `selection`
- `chargeFullTierReached` -> `light`
- `holdAbilityStaminaDepleted` -> `medium`
- `holdAbilityTimedOut` -> `heavy`

## Usage Rules

- UI controls/events should request cues through `UiHaptics`.
- Avoid direct `HapticFeedback.*` calls outside the haptics driver.
- Prefer cue-based calls over hardcoded intensity so tuning remains centralized.
