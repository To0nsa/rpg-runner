# Editor Workspace Maintainability Refactor Implementation Checklist

Date: September 4, 2026
Status: Implemented

Archived after the completed implementation and audit.

Source strategy:
[Editor workspace maintainability refactor strategy](editor_workspace_refactor_strategy.md)

## Contract Freeze And Baseline

- [x] Inventory the largest production and test files.
- [x] Identify current duplicated workflow methods and dialog contracts.
- [x] Confirm existing plugin/store persistence boundaries.
- [x] Record behavior-preserving invariants and measurable file-size targets.
- [x] Run the three focused route suites before structural edits (57 passed).

## Milestone 1 — Shared Draft Workflow

- [x] Add a typed owner create/edit/rename draft-state primitive.
- [x] Add one shared Save/Discard/Cancel dialog contract.
- [x] Replace Prefab owner and shape pending-action duplication.
- [x] Replace Chunk owner and shape pending-action duplication.
- [x] Add focused tests for state transitions and dialog outcomes.
- [x] Run shared and focused Prefab/Chunk tests.

## Milestone 2 — Prefab Composition

- [x] Extract the ordered Prefab workspace view selector.
- [x] Extract the selected-Prefab visual preview.
- [x] Extract collision setup, selection, and empty-state presentation.
- [x] Keep view guards, selection, controller binding, and commands in the
      parent coordinator.
- [x] Preserve existing keys and wide/narrow mounted-layout behavior.
- [x] Reduce `prefab_polygon_workspace.dart` to at most 2,500 lines.
- [x] Run the focused Prefab workspace suite.

## Milestone 3 — Chunk Composition

- [x] Move responsive layout into a typed presentation file.
- [x] Move the owner preview into a typed presentation file.
- [x] Move Chunk grid/bounds painters into a typed presentation file.
- [x] Keep gesture, projection, selection, and command orchestration in the
      parent coordinator.
- [x] Reduce `chunk_authoring_workspace.dart` to at most 3,200 lines.
- [x] Run focused Chunk workspace, scene, and controller tests.

## Milestone 4 — Level Composition

- [x] Extract the Level catalog presentation.
- [x] Extract new-Level form presentation with semantic callbacks.
- [x] Keep form controllers, validation, and command dispatch in the page.
- [x] Reduce `level_creator_page.dart` to at most 1,750 lines.
- [x] Run the focused Level Creator suite.

## Milestone 5 — Documentation, Validation, And Audit

- [x] Format all touched Dart files.
- [x] Update the editor architecture TDD with delivered ownership boundaries.
- [x] Update editor contributor documentation if navigation guidance changes.
- [x] Run `dart analyze` in `tools/editor`.
- [x] Run the complete `flutter test` suite in `tools/editor`.
- [x] Run `git diff --check` for the refactor scope.
- [x] Audit final line counts against the targets.
- [x] Audit pending-action enums/dialog trees and duplicated helpers.
- [x] Audit imports, public API docs, deterministic command paths, and dead code.
- [x] Confirm unrelated dirty-worktree content was not rewritten.
- [x] Record validation results, close every checklist item, and archive these
      planning documents.

## Validation And Audit Record

- `dart format`: all touched Dart source and focused test files were already
  canonical after the final pass.
- `dart analyze`: clean for the complete `tools/editor` package.
- Focused regression command: 99 passed across shared draft/dialog, Prefab,
  Chunk workspace/scene/controller, and Level Creator tests.
- Additional Level domain slice: 27 passed.
- Complete `flutter test`: 604 passed, 16 failed. The failures reproduce the
  existing authored-source drift in `phase4_authoring_baseline_test.dart`, the
  polygon migration check/command/plan/transaction suites, and
  `prefab_tile_file_codec_test.dart`; no changed route or shared-workflow test
  failed.
- Physical coordinator lines: Prefab 2,382; Chunk 3,178; Level 1,746.
- Largest extracted source: `level_catalog_pane.dart` at 346 lines; all new
  files remain below 1,000.
- Pending-action enums and dialog trees: one shared enum and one shared dialog;
  both routes retain only domain-specific resolution branches.
- Ordering helpers: Prefab and Chunk owner comparators are each single-sourced.
- Extracted presentation files have no session controller, store, export, or
  command-dispatch dependency. Analyzer found no unused imports or dead code.
- `git diff --check` found no whitespace errors. Existing unrelated worktree
  changes and authored-source migrations were left intact.
