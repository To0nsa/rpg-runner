# Shared Editor Action Toolbar Checklist

Status: Superseded on September 9, 2026 by the shared Save and Build workflow.
The original boxes below are retained as historical progress at supersession;
unchecked verification boxes do not describe the current implementation.
Current behavior is documented in the
[Editor UI System](../../../../../tdd/editor_ui_system.md#shared-action-toolbar), and
delivered checks are recorded in the
[Level Creator implementation evidence](../../editor/levelCreator/implementation-verification.md).

## Implementation

- [x] Add the page-level apply action contract beside the existing shell action
  contracts.
- [x] Add Apply To Files, Undo, and Redo to the home-shell toolbar in the
  required order.
- [x] Add right-aligned progress, pending-file, and validation status shared by
  every route.
- [x] Delegate reload, apply, undo, and redo through page contracts without a
  route-id switch.
- [x] Wire Entities, Parallax, Level Creator, and Terrain Materials to the
  apply contract.
- [x] Wire Prefab Creator and Chunk Creator through their current-schema
  workspace state, preserving local-operation guards.
- [x] Remove duplicate in-page Apply, Undo, and Redo buttons while retaining
  domain-specific controls and status information.
- [x] Update editor user-facing documentation.

## Verification

- [ ] Add or update focused toolbar/delegation widget tests.
- [ ] Run `cd tools/editor && dart analyze`.
- [ ] Run `cd tools/editor && flutter test`.
