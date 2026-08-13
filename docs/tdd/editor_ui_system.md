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

`EditorPanelCard` has explicit natural, expanded, and scrollable body modes.
Expanded and scrollable modes require a bounded parent height. Collapsible
cards require natural-height bodies and delegate overflow to their containing
sidebar; this prevents nested vertical scroll views from competing for pointer
input. Expansion is local presentation state and never changes authoring
selection, source history, validation, or pending diffs.

## Current adoption

The current-schema Chunk route uses one persistent `Chunk creation scene` and
one right sidebar. Wide layouts place the bounded sidebar to the scene's right;
narrow layouts keep both subtrees mounted while placing the scene above the
sidebar. The sidebar is the sole vertical scroll owner and contains exactly two
top-level `EditorPanelCard`s: `Owners & terrain collision` and `Layers, prefabs
& markers`. Owner, Shapes, reachable-seam, Diagnostics, visual-stack,
tile-layer metadata, prefab-placement, and enemy-marker groups use
natural-height `EditorSectionCard`s with stable expansion keys. Expansion state
is local presentation state and does not replace the scene or affect authoring
state.

Prefab polygon, atlas-slice, and platform-module workspaces use the same panel,
section, list-row, and token primitives. Prefab-specific widgets remain only
where they encode domain semantics such as create/edit banners, scene controls,
or fixed three-panel labels; the former prefab-only card shells and spacing
registry have been removed.

Chunk, Prefab, and Level root workspaces use `EditorWorkspaceCard`. Chunk
composition is embedded in the second Chunk sidebar card. Its rows and retained
dialogs share typed selection and the same validated composition command with
the scene's direct prefab and marker gestures. The scene owns the explicit
Terrain, Prefabs, or Markers input domain; compiled-edge inspection is a
read-only mode. Chunk and Prefab owner and shape rows, plus Chunk composition
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
