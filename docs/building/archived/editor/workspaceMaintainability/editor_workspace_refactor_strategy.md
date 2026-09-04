# Editor Workspace Maintainability Refactor Strategy

Date: September 4, 2026
Status: Implemented

Related documents:

- [Implementation checklist](editor_workspace_refactor_implementation_checklist.md)
- [Editor UI system](../../../../tdd/editor_ui_system.md)
- [Editor README](../../../../../tools/editor/README.md)

## Decision Summary

Refactor the three largest editor routes incrementally without changing their
authoring behavior, source schemas, command payloads, or persistence paths.
The page states remain route coordinators, while reusable draft resolution and
bounded presentation move behind focused shared or domain-specific APIs.

The refactor follows two rules:

1. Share only behavior that is already duplicated by at least two current
   workflows.
2. Extract domain presentation into typed widgets before considering broader
   framework abstractions.

This avoids replacing large widgets with a speculative generic editor system.

## Baseline

The September 4 inventory found these production hotspots:

| File | Approximate lines | Mixed responsibilities |
| --- | ---: | --- |
| `chunk_authoring_workspace.dart` | 3,691 | owner lifecycle, scene gestures, composition, terrain shapes, layout, preview painters |
| `prefab_polygon_workspace.dart` | 2,947 | view routing, owner lifecycle, collision fitting, shapes, diagnostics, preview/layout |
| `level_creator_page.dart` | 2,030 | route orchestration, catalog, creation, inspector, assembly editing, diagnostics |

Prefab and Chunk also duplicate more than forty similarly named owner, shape,
selection, and viewport methods. The highest-confidence duplication is the
owner create/edit/rename draft state and the non-dismissible
Save/Discard/Cancel dialog contract.

Large tests mirror the production topology: the main Chunk and Prefab widget
test files exceed 4,000 and 3,000 lines respectively. Test extraction is useful
only where it follows a real production boundary; arbitrary test-file splitting
is not a goal.

## Locked Invariants

- Plugins and stores remain the only repository load, validation, command, and
  export authorities.
- This refactor changes no authored schema, canonical ordering, revision rule,
  stale-write guard, or runtime contract.
- Existing widget keys, labels, keyboard behavior, and draft prompts remain
  stable unless a focused test proves an intentional equivalent replacement.
- A route transition may not silently discard an active gesture, exact edit,
  owner draft, Atlas draft, Platform draft, or composition operation.
- Prefab and Chunk may share neutral workflow state and dialog presentation;
  domain selection, validation, and command dispatch remain domain-specific.
- Extracted widgets receive immutable values and semantic callbacks. They do
  not gain direct access to `EditorSessionController` unless session state is
  their established responsibility.
- New files stay focused and below 1,000 lines.

## Implementation Strategy

### Milestone 1 — Shared draft workflow

Introduce two small shared primitives:

- a typed owner-draft state object that enforces create/edit/rename state
  invariants for both Prefab and Chunk;
- one configurable Save/Discard/Cancel dialog function used by owner and shape
  guards.

The state object deliberately has no repository or Flutter build ownership. A
route wraps mutations in `setState` and retains responsibility for deciding
when a draft must be resolved and how Save is dispatched.

### Milestone 2 — Prefab composition boundary

Extract stable view chrome and collision-owner presentation from
`PrefabPolygonWorkspace`:

- ordered top-level view selector;
- visual-only Prefab preview;
- collision setup/selection sidebar and its empty states.

The parent keeps guarded view transitions, selected `prefabKey`, polygon
controller binding, fitting, and command dispatch. Extracted widgets cannot
mutate source directly.

### Milestone 3 — Chunk composition boundary

Move the already self-contained responsive layout, owner preview, grid painter,
and bounds painter into typed Chunk presentation files. Adopt the shared draft
state and dialog contract. The parent keeps scene coordination, gestures,
projection refresh, and command dispatch.

### Milestone 4 — Level composition boundary

Extract the Level catalog and creation presentation into typed widgets while
leaving form controllers, validation decisions, and commands in the page.
Reuse the existing shared workspace/panel primitives instead of adding another
page-local shell.

### Milestone 5 — Tests, documentation, and audit

Add unit/widget characterization for the shared draft and extracted
presentation seams. Run focused route tests, analyzer, and the complete editor
suite. Audit final line counts, duplicated workflow symbols, imports, public
API documentation, determinism boundaries, and dirty-worktree isolation.

## Acceptance Criteria

- Prefab and Chunk no longer define separate pending-action enums or duplicate
  full Save/Discard/Cancel dialog trees.
- Prefab and Chunk use one tested owner-draft state contract.
- `prefab_polygon_workspace.dart` is at most 2,500 lines.
- `chunk_authoring_workspace.dart` is at most 3,200 lines.
- `level_creator_page.dart` is at most 1,750 lines.
- No new source file exceeds 1,000 lines.
- Existing Prefab, Chunk, and Level focused widget tests retain their behavior.
- `dart analyze` is clean.
- The complete editor test result is recorded exactly, including any failure
  caused by pre-existing authored-source fixture drift.
- The delivered architecture is documented in `docs/tdd/editor_ui_system.md`.
- The checklist is fully closed and both planning documents are archived only
  after the audit passes.

## Non-Goals

- Redesigning editor UX or changing user-visible workflows.
- Replacing `EditorSessionController` or the plugin architecture.
- Moving domain validation or deterministic reducers into widgets.
- Combining Prefab and Chunk into a generic authoring route.
- Splitting files through Dart `part` directives while leaving the same
  responsibilities coupled.
- Refactoring unrelated terrain, parallax, entity, or runtime systems.

## Delivered Result

The September 4 implementation completed all five milestones without changing
authored schemas, persistence paths, or command contracts.

| Coordinator | Baseline | Delivered physical lines |
| --- | ---: | ---: |
| `prefab_polygon_workspace.dart` | ~2,947 | 2,382 |
| `chunk_authoring_workspace.dart` | ~3,691 | 3,178 |
| `level_creator_page.dart` | ~2,030 | 1,746 |

The shared owner-draft state and non-dismissible pending-change dialog now
replace the duplicated state/dialog contracts. Prefab, Chunk, and Level use
typed presentation siblings for their bounded catalogs, panels, previews,
layout, metrics, fit draft, diagnostics, and painters. Stable Prefab and Chunk
presentation ordering is also single-sourced. The largest new source file is
346 lines, below the 1,000-line ceiling.

Validation completed with clean analysis and 99 passing focused tests. The
complete editor suite reported 604 passing and 16 failing tests. All 16 were
reproduced in the pre-existing authored-source baseline, polygon-migration, and
tile canonical-round-trip checks; the refactored UI suites remained green.
