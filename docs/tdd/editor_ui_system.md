# Editor UI System

## Scope

The standalone Flutter editor uses shared presentation primitives under
`tools/editor/lib/src/app/pages/shared/` for workspace cards and spacing. These
widgets own presentation only: route state, validation, commands, history, and
repository writes remain with their existing page, controller, plugin, and
store owners.

## Shared primitives

- `EditorUiTokens` is the single source for workspace padding, panel padding,
  gaps, radii, and list-row spacing.
- `EditorPanelCard` owns the outlined card, title/description/trailing header,
  body padding, optional vertical scrolling, and optional collapse semantics.
- `EditorSectionCard` groups related inspector controls without creating a
  second top-level panel.
- `EditorListCard` gives owner, catalog, and composition rows one optional
  selected-state, leading/preview, details, and trailing-action structure.
- `EditorWorkspaceCard` owns the outer outlined route surface and workspace
  padding without taking over route sizing or scroll state.

`EditorPanelCard` has explicit natural, expanded, and scrollable body modes.
Expanded and scrollable modes require a bounded parent height. Collapsible
cards require natural-height bodies and delegate overflow to their containing
sidebar; this prevents nested vertical scroll views from competing for pointer
input. Expansion is local presentation state and never changes authoring
selection, source history, validation, or pending diffs.

## Current adoption

The Chunk polygon workspace uses `EditorPanelCard` for owners, scene, empty
states, Shapes, reachable seams, and Diagnostics. Its right sidebar remains the
single scroll owner, while the three authoring cards retain their stable widget
and expansion keys for tests and automation.

Prefab polygon, atlas-slice, and platform-module workspaces use the same panel,
section, list-row, and token primitives. Prefab-specific widgets remain only
where they encode domain semantics such as create/edit banners, scene controls,
or fixed three-panel labels; the former prefab-only card shells and spacing
registry have been removed.

Chunk, Prefab, and Level root workspaces use `EditorWorkspaceCard`. Chunk
composition uses `EditorPanelCard` for its visual-stack summary and its three
bounded lists. Chunk and Prefab owner and shape rows, plus Chunk composition
records, use `EditorListCard`; evidence and diagnostic cards remain
route-specific because they communicate status instead of list ownership.
Explanatory route-intro cards compose the same panel shell. The fail-closed
polygon-migration route keeps its specialized warning content inside the shared
workspace surface.

Parallax uses the shared workspace and bounded panel cards for Layers, Preview,
and Inspector. Layer rows use `EditorListCard` with their asset thumbnail
in the leading slot, preserving selection and edit ownership in the page while
removing its custom border, fill, and padding implementation.

Entities uses the shared outer workspace, Entries panel, load-error panel, and
bounded Validation, Pending File Diff, and Apply Result panels. The scene and
inspector remain domain widgets because they own specialized interactive
viewport and field composition; their authoring state still belongs to the
Entities page and plugin paths.
