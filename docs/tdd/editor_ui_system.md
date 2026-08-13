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
- `EditorSelectableCard` gives owner and catalog rows one selected-state,
  preview, details, and trailing-action structure.

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
