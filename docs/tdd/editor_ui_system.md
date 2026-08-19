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
  second top-level panel. It supports natural-height, presentation-only
  collapse and an optional trailing action while its containing sidebar owns
  scrolling.
- `EditorListCard` gives owner, catalog, and composition rows one optional
  selected-state, leading/preview, details, and trailing-action structure.
- `EditorWorkspaceCard` owns the outer outlined route surface and workspace
  padding without taking over route sizing or scroll state.

## Shared action toolbar

`EditorHomePage` owns the single toolbar rendered above every top-level route:
page selector, Reload, Apply To Files, Undo, and Redo. Route pages do not
render duplicate copies of those actions. A trailing status area projects the
session's loading/exporting state, pending item/file counts, pending-summary
failure, and validation counts without introducing route-specific meaning.

The shell delegates Reload through `EditorPageReloadHandler`, Undo/Redo through
`EditorPageSessionShortcutHandler`, and Apply To Files through
`EditorPageApplyHandler`. This preserves route-local safeguards and result
handling—for example, active polygon-operation guards and Level-to-Parallax
handoff reconciliation—without coupling the shell to individual route ids.
Plugins and `EditorSessionController` remain the only repository write path.

`EditorPanelCard` has explicit natural, expanded, and scrollable body modes.
Expanded and scrollable modes require a bounded parent height. Collapsible
cards require natural-height bodies and delegate overflow to their containing
sidebar; this prevents nested vertical scroll views from competing for pointer
input. Expansion is local presentation state and never changes authoring
selection, source history, validation, or pending diffs.

## Current adoption

The current-schema Chunk route uses a persistent `Chunk creation scene`, owner
rail, and right sidebar. Wide layouts place the rail and bounded sidebar around
the scene; narrow layouts keep all subtrees mounted while placing them below
the scene. A four-way `Terrain`, `Prefabs`, `Markers`, and `Layers` segmented
tab strip stays at the top of the scene. The sidebar is the sole vertical
scroll owner and mounts only the `EditorPanelCard` for the active tab. Terrain
contains the creation and existing-shape authoring sections, Prefabs and
Markers contain their retained placement forms, and Layers contains the visual
stack plus tile-layer metadata. Seam evidence and route diagnostics are not
separate sidebar sections. Tab changes preserve the scene subtree, viewport,
and per-domain selection; an active draft or gesture disables tab changes.

Chunk terrain creation may reserve an optional designer-supplied shape name
before drawing; blank input delegates to deterministic ID allocation. Creation
also chooses `solid`, `oneWay`, or **No collision (visual only)**; the last role
remains visible in source/material preview but has no compiled-edge overlay.
Existing shape rows expose the stable source ID as an editable name. Exact
geometry fields retain their text inside the mounted editor, while a shared edit
controller reports pending state and routes save/discard requests from the
workspace. Re-selecting the active row closes it immediately when clean or
opens a non-dismissible Save/Discard/Cancel decision when its name or geometry
has changed. Save dispatches the pending identity and geometry as one semantic
owner edit; Discard clears both local drafts; Cancel preserves the open editor.
Pending inspector text prevents source apply until it is resolved.

Prefab polygon, atlas-slice, and platform-module workspaces use the same panel,
section, list-row, and token primitives. Prefab-specific widgets remain only
where they encode domain semantics such as create/edit banners, scene controls,
or fixed three-panel labels; the former prefab-only card shells and spacing
registry have been removed.

Chunk, Prefab, and Level root workspaces use `EditorWorkspaceCard`. Chunk
composition is partitioned by the active Chunk workspace tab. Its rows and
retained dialogs share typed selection and the same validated composition
command with the scene's direct prefab and marker gestures. Terrain, Prefabs,
and Markers own explicit primary-input domains. Layers is deliberately passive
because `TileLayerDef` is metadata-only; compiled edges remain a non-interactive
visual reference. Chunk and Prefab owner and shape rows, plus Chunk composition
records, use `EditorListCard`; evidence and diagnostic cards remain
route-specific because they communicate status instead of list ownership.
Explanatory route-intro cards compose the same panel shell. The fail-closed
polygon-migration route keeps its specialized warning content inside the shared
workspace surface.

Parallax uses the shared workspace and bounded panel cards for Layers, Preview,
and Inspector. Layer rows use `EditorListCard` with their asset thumbnail
in the leading slot, preserving selection and edit ownership in the page while
removing its custom border, fill, and padding implementation.

Level Creator uses one compound Level/Parallax session document. Its new-Level
form makes create-new versus reuse intent explicit, its inspector exposes
reference repair and create-and-assign, and pending state can contain exact
diffs for both authoring sources. Apply remains one confirmation and one
rollback-safe transaction. After successful apply and canonical reload, the
page may pass a typed Level/theme target to the shell; the shell atomically
loads it through the Parallax plugin before changing routes. Page-local form
drafts and handoff intent are transient and never become persistence authority.

Entities uses the shared outer workspace, Entries panel, load-error panel, and
bounded Validation, Pending File Diff, and Apply Result panels. The scene and
inspector remain domain widgets because they own specialized interactive
viewport and field composition; their authoring state still belongs to the
Entities page and plugin paths.
