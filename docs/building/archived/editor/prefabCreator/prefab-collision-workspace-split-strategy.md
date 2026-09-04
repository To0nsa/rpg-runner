# Prefab And Collision Workspace Split Strategy

Date: September 3, 2026
Status: Implemented and archived on September 3, 2026

Related documents:

- [Implementation checklist](prefab-collision-workspace-split-implementation-checklist.md)
- [Editor UI system](../../../../tdd/editor_ui_system.md)
- [Prefab Creator README](../../../../../tools/editor/README.md)

## Decision Summary

Replace the combined **Prefabs & collision** view with two top-level Prefab
Creator views:

1. **Prefabs** owns prefab creation, a visual-only selected-prefab preview, the
   searchable prefab library, and inline owner metadata/lifecycle actions.
2. **Collision** owns the missing-collision backlog, collision-capable prefab
   selection, the collision scene, shape creation/editing, and diagnostics.

The two views share one stable `prefabKey` selection and one polygon authoring
controller. Changing views must move presentation only: it cannot write source,
create history, reset the viewport, or silently discard a draft. Atlas slicing
and Platform visual composition remain separate sibling views.

## Why This Split

The combined view currently mixes two different jobs. Creating or maintaining
a prefab is about identity, visual source, anchor, tags, lifecycle, and reuse.
Editing collision is a geometry workflow with its own tools, scene, fitting,
shape list, and diagnostics. Showing both at once makes the creation/library
sidebar compete with collision setup and makes the tab label ambiguous.

Dedicated views match the existing Platform workspace model: each top-level
view has one clear task, its own three-panel composition, and explicit handoff
actions when work crosses into another task.

## Information Architecture

The top-level order is:

```text
Prefabs | Collision | Atlas & tile slices | Platforms
```

### Prefabs view

```text
+----------------------+--------------------------------+----------------------+
| Create prefab        | Selected prefab preview        | Prefab library       |
|                      | visual source only             | inline owner editor  |
+----------------------+--------------------------------+----------------------+
```

- Creation stays in its own collapsed section.
- The center preview shows the selected visual without collision tools or
  collision geometry.
- The searchable visual library retains row-local owner editing and contextual
  Rename, Duplicate, and Delete actions.
- An empty catalog keeps the creation workflow available and shows explicit
  preview/library empty states.

### Collision view

```text
+----------------------+--------------------------------+----------------------+
| Collision setup      | Collision scene                | Create shape         |
| needed               |                                | Existing shapes      |
| Collision prefabs    |                                | Diagnostics          |
+----------------------+--------------------------------+----------------------+
```

- **Collision setup needed** includes unpaired bounded Platform visuals and
  existing Obstacle/Platform Prefabs with no shapes.
- **Collision prefabs** is a searchable visual selector limited to Obstacle and
  Platform Prefabs. Decorations are absent because collision is forbidden for
  them.
- Selecting a row changes only the shared stable owner selection.
- The current collision scene and shape authoring sections move intact into
  this view.
- If no collision-capable Prefab exists, the view explains how to create one
  instead of presenting decoration collision controls.

## Cross-View Navigation

- **Set up collision** from an unpaired Platform first creates its deterministic
  paired Prefab through the existing catalog command, then selects it in
  **Collision**.
- **Set up collision** for an existing collider-free Prefab selects that owner
  in **Collision** without mutating it.
- The selected Prefab's inline editor exposes **Set up collision** or
  **Edit collision** and carries that same owner into **Collision**.
- **Set Up Collision** and **Edit Collision** from the Platforms view switch to
  **Collision** and select the paired owner.
- Selecting or editing a Prefab in **Prefabs** keeps the same owner ready when
  entering **Collision**.

## Draft And State Safety

- Dirty prefab create/edit/rename forms block view changes until resolved.
- Active polygon, fitting, or exact-shape operations block view changes.
- Pending shape metadata or exact geometry uses the existing Save, Discard, or
  Cancel resolution before a view change.
- Dirty Atlas or Platform forms continue to block departure from their views.
- Cross-view collision navigation uses the same guards; it must never replace
  an active controller directly.
- Both view subtrees remain mounted in the `IndexedStack`, matching the current
  scene-preserving responsive contract.
- Entering Collision with a Decoration selected chooses the deterministic first
  collision-capable Prefab after guards pass. If none exists, selection remains
  unchanged and the Collision view shows its empty state.

## Persistence And Domain Boundaries

- No source schema, runtime contract, validation severity, revision rule, or
  command payload changes.
- The Prefab domain plugin/store remains the sole document and export
  authority.
- View selection, catalog filters, expansion state, and preview state remain
  transient UI state.
- The paired Platform creation path remains one stale-checked, undoable
  Prefab/tile catalog command.

## Responsive Behavior

Both new views reuse `PrefabEditorThreePanelLayout`. Wide layouts retain the
`1:2:1` composition. Narrow layouts keep the center scene/preview mounted above
the two independently scrollable sidebars. The split must not reintroduce
exclusive narrow-layout panel tabs.

## Non-Goals

- Do not change collision geometry, fitting, or validation rules.
- Do not add collision to Decoration Prefabs.
- Do not duplicate Prefab records for collision authoring.
- Do not replace the searchable libraries with long dropdowns.
- Do not move repository writes into page widgets.
- Do not redesign Atlas or Platform visual authoring beyond their collision
  handoff destination.

## Acceptance Criteria

- Four clearly named top-level views are visible in the locked order.
- Prefab creation and owner metadata are absent from Collision.
- Collision scene, shape tools, backlog, and diagnostics are absent from
  Prefabs.
- Prefabs has a visual-only selected-source preview and its existing searchable
  library with inline editing.
- Collision has a searchable visual selector containing only Obstacle and
  Platform Prefabs.
- Owner selection stays synchronized across Prefabs, Collision, header, scene,
  and external Platform collision handoffs.
- All view changes and handoffs preserve current draft guards.
- Wide and narrow layouts render without overflow and keep their center subtree
  mounted across breakpoint changes.
- Analyzer and focused editor tests pass; any unrelated repository-fixture
  failure is recorded precisely.
