# Ability Slot UI Coupling Plan

Date: February 19, 2026
Status: Implemented

## Goal

Make Select Character action-slot buttons and in-run control buttons share one
UI contract so labels/icons/layout sizing stay consistent and future changes
ship once.

## Chosen Approach

1. Add a shared ability-slot presentation contract in `lib/ui/controls`.
2. Replace in-run hardcoded slot label/icon values with the shared contract.
3. Replace Select Character custom slot button visuals with the same control
   button widget style used in run HUD.
4. Replace Select Character grid layout with true radial placement derived from
   the in-run radial layout solver.
5. Add tests that lock slot mappings/order/layout sizing.
6. Consolidate slot metadata into one shared `AbilityRadialLayoutSpec`.

## Checklist

- [x] Added shared slot visual metadata (`label`, `icon`) per `AbilitySlot`.
- [x] Added shared slot row ordering constants for Select Character.
- [x] Added shared slot-to-radial-anchor and slot-to-size mapping helpers.
- [x] Migrated in-run controls to consume shared slot metadata.
- [x] Migrated Select Character action-slot buttons to `ActionButton`.
- [x] Migrated Select Character action-slot placement to true radial anchors.
- [x] Anchored Select Character radial cluster bottom-right like in-run HUD.
- [x] Removed ability-name labels from Select Character action-slot radial layout.
- [x] Removed duplicated slot label/icon/button-face logic from Select Character.
- [x] Added tests for shared slot contract and layout mapping.
- [x] Replaced per-screen slot mapping branches with shared `AbilityRadialLayoutSpec`.
- [ ] Run full project test suite (`flutter test`) before release branch merge.

## Acceptance Criteria

- Changing a slot icon/label in shared slot presentation updates both:
  - in-run control overlay
  - Select Character action-slot buttons
- Select Character radial positions are derived from `ControlsRadialLayoutSolver`.
- Select Character radial cluster is bottom-right anchored (matching run HUD).
- Slot sizing in Select Character button rendering uses in-run radial sizing
  mapping helper.
- Slot order, anchors, sizes, and slot family resolve from one shared spec.
- `dart analyze` is clean for touched files.
- Added/updated tests pass for touched UI controls.
