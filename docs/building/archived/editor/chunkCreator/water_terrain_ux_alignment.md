# Terrain and Water UX alignment

Status: implemented and closed. September 13, 2026.

## Strategy

The first water drawer reused snapping and persistence but introduced different
controls and an always-active draw interaction. Align with the existing Terrain
workflow by sharing presentation and field behavior. Keep water's rectangular,
non-solid runtime contract; a polygon/collision schema migration is unnecessary.

## Checklist

- [x] Share the creation card, material picker/preview, snap switches, status and actions.
- [x] Share Terrain/Water creation snap preferences.
- [x] Start in Select and require Draw rectangle; Save/Cancel restores Select.
- [x] Support optional region names and exact drawn-draft dimensions.
- [x] Use outlined existing-region rows and scene/sidebar selection.
- [x] Replace the water modal with Terrain's inline rectangle fields and Save edit.
- [x] Commit name, material and geometry together with stale revision checks.
- [x] Protect pending input on selection/tab/owner changes, Save, Play and Undo.
- [x] Reuse Terrain painter style and remove the separate controls/modal paths.
- [x] Update current authoring and technical documentation.
- [x] Complete analysis, focused regressions and the full editor suite.

Acceptance: equivalent creation/edit controls have one implementation, ordinary
scene input selects, exact edits remain reviewable, and saved water still uses
one typed water transaction without introducing solid collision.

## Validation

- Editor analysis: no issues.
- Focused workspace, water geometry/edits, scene coordinator and Terrain
  controller regressions: all 72 passed.
- UI coverage confirms shared creation components, material preview without a
  source write, retained snapping preferences across tabs, Select as default,
  explicit drawing, inline fields, atomic metadata/geometry edits, overlap
  rejection, Save/Discard/Cancel navigation, global Save preparation and Undo.
- Full editor suite: 776 passed, two skipped, two existing failures. Preparation
  performance passed in the full run. The remaining failures are the previously
  recorded accepted-Play projection fixture (missing Forest source) and new-level
  preparation fixture; see [baseline evidence](../../swimmable_water_validation.md).
- `git diff --check` passed. No runtime schema, generated content or gameplay
  changes. Existing prefab/tile source edits remain outside this change.

The [pool authoring guide](../../../../gdd/swimming.md) and
[technical contract](../../../../tdd/swimmable_water.md) describe the current UX.
