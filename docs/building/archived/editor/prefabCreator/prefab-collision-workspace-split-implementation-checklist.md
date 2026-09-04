# Prefab And Collision Workspace Split Implementation Checklist

Date: September 3, 2026
Status: Implemented and archived on September 3, 2026

Source strategy:
[Prefab and Collision workspace split strategy](prefab-collision-workspace-split-strategy.md)

## Locked Invariants

- [x] Prefab plugin/store remains the only persistence authority.
- [x] Prefabs and Collision share one stable `prefabKey` selection.
- [x] Switching views is source/history/revision neutral.
- [x] Existing owner, shape, Atlas, and Platform draft guards remain effective.
- [x] Decoration Prefabs remain collider-free and absent from Collision
      selection.
- [x] Platform pairing remains deterministic and stale checked.
- [x] Wide and narrow layouts preserve mounted center content.

## Phase 1 — Workspace Composition

- [x] Replace **Prefabs & collision** with **Prefabs** and **Collision**.
- [x] Keep view order Prefabs, Collision, Atlas, Platforms.
- [x] Build the Prefabs three-panel composition.
- [x] Keep creation in a collapsed authoring section.
- [x] Keep the searchable Prefab library and row-local owner editor.
- [x] Add a visual-only selected Prefab preview.
- [x] Add explicit empty states for an empty Prefab catalog.
- [x] Build the Collision three-panel composition.
- [x] Move the missing-collision backlog to Collision.
- [x] Add a searchable Obstacle/Platform collision-owner library.
- [x] Keep the collision scene and shape/diagnostic panel intact.
- [x] Add explicit empty state when no collision-capable Prefab exists.

## Phase 2 — Selection And Navigation

- [x] Synchronize Prefab and Collision views by stable owner key.
- [x] Resolve a selected Decoration to the deterministic first colliding Prefab
      when entering Collision.
- [x] Route missing-collision Prefab actions to Collision.
- [x] Route unpaired Platform setup to Collision after paired-owner creation.
- [x] Route Platform view collision actions to Collision.
- [x] Preserve viewport state when only the top-level view changes.
- [x] Preserve clean inline owner expansion when it remains safe.
- [x] Keep active operations and dirty forms from being discarded by any
      cross-view handoff.

## Phase 3 — Tests

- [x] Cover the four tab labels and deterministic order.
- [x] Prove Prefab-only controls are absent from Collision.
- [x] Prove collision-only controls are absent from Prefabs.
- [x] Cover shared selection from Prefabs to Collision.
- [x] Cover Decoration fallback and no-colliding-Prefab empty state.
- [x] Cover collision library kind filtering by construction.
- [x] Cover collider-free Prefab and unpaired Platform handoffs.
- [x] Cover Platform view handoff to Collision.
- [x] Cover dirty owner and active polygon view-switch guards.
- [x] Cover narrow layout and live breakpoint subtree retention.
- [x] Confirm no view-only action creates a pending source change.

## Phase 4 — Documentation And Validation

- [x] Update `tools/editor/README.md`.
- [x] Update `docs/tdd/editor_ui_system.md`.
- [x] Run `dart format` on touched Dart files.
- [x] Run `dart analyze` in `tools/editor`.
- [x] Run focused Prefab workspace and navigation tests.
- [x] Run the complete editor test suite.
- [x] Review for duplicated catalogs, selection state, and guard logic.
- [x] Record unrelated dirty-worktree or repository-fixture failures without
      modifying user-owned data.
- [x] Mark the strategy and checklist implemented and archive both documents.

## Validation Result

- `dart analyze`: clean.
- Focused Prefab workspace and navigation tests: 49 passed.
- Complete editor suite: 610 passed; one pre-existing repository-fixture test
  failed because its migration snapshot expects 99 Prefabs while the current
  authored catalog contains 101.
