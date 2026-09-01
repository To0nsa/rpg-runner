# Prefab And Chunk Creator UX Alignment Strategy

Date: August 25, 2026
Status: Implemented and archived on August 26, 2026

Current-contract note (September 1, 2026): Prefab collision authoring now uses
one mandatory whole-pixel grid. Half-pixel requirements below describe the
historical alignment scope, not the current Prefab-v3 source contract.

Related documents:

- [Implementation checklist](prefab_chunk_ux_alignment_implementation_checklist.md)
- [Chunk Creator plan](../../../editor/chunkCreator/plan.md)
- [Editor UI system](../../../../tdd/editor_ui_system.md)
- [Polygon terrain authoring foundation](../../../../tdd/polygon_terrain_authoring_foundation.md)

## Decision Summary

Make authored records in Prefab Creator and Chunk Creator follow one interaction
model:

```text
library or existing-record list
  -> select a row or scene element
  -> expand one editor directly below that row
  -> Apply, Cancel, or a contextual lifecycle action
```

Creation uses a separate collapsible section. Existing-record actions live with
the selected record rather than in a detached toolbar. Sidebar sections start
collapsed, except that an actively edited record keeps its containing section
open. The scene remains mounted and visible while sidebars are inspected on
wide and narrow layouts.

The migration includes both Prefab-v3 and Chunk-v2 owner metadata. Chunk owner
metadata is not an exception to the inline-edit rule. Creation, renaming,
duplication, deletion, metadata, geometry, and diagnostics continue to dispatch
the existing typed plugin commands; the page remains transient UI state rather
than a second persistence authority.

## Scope Baseline

The following comparison is the complete agreed scope. The last row is an
intentional domain difference rather than a parity defect.

| UX area | Chunk Creator | Prefab Creator | Alignment needed |
| --- | --- | --- | --- |
| Existing item editing | Selecting terrain, prefab placement, or enemy marker expands an editor directly below its row | Prefab owner uses a separate **Edit** button and modal | High |
| Selection library | Searchable visual cards with thumbnails, filters, and clear selection | Prefab owners are a long text-only list | High |
| Actions | Edit/Delete actions appear beside the selected object | New/Edit/Duplicate/Rename/Delete are detached at the top of the owner panel | High |
| Creation | Dedicated collapsible inline creation cards | Creating a prefab owner opens a modal | High |
| Rename | Part of the object editing context where applicable | Separate Rename button and separate modal | Medium |
| Collision shape editing | Selected terrain shape expands immediately below its row | Prefab shape details appear after the entire list | High |
| Shape metadata | Collision, surface, material, and name are edited inline | Metadata opens another modal | High |
| Rectangle editing | Compact position/width/height editor | Prefab rectangles must be edited through individual vertices | Medium |
| Panel organization | Separate **Create**, **Existing**, and **Diagnostics** sections | Shapes, creation controls, selected editor, and diagnostics share one long panel | High |
| Panel collapsing | Sidebar sections start minimized | Most Prefab panels and nested sections remain permanently open | High |
| Narrow layout | Scene remains visible above the two sidebars | Owners/Scene/Shapes become exclusive tabs, hiding the scene while inspecting | Medium |
| Selected-owner context | Header owner selector plus preview owner cards | Selection is indicated only in the owner list | Medium |
| Draft safety | Owner/level switching is blocked during an active authoring operation | Clicking another prefab owner can replace the active controller without the same guard | Critical |
| Diagnostics | Independent collapsed section with counts and complete session issues | Attached to the bottom of the shape panel and focused on the current owner | Medium |
| Scene features | Runtime visual preview, grid, edges, actor terrain and marker overlays | Focused collision/source preview | Intentional difference |

## Goals

- Give Prefab and Chunk owners the same row-local inline editing model as
  terrain shapes, prefab placements, and enemy markers.
- Replace the Prefab owner text list with a searchable visual library that uses
  stable-key selection, source thumbnails, kind/status/tag filters, and clear
  empty states.
- Keep creation separate from existing-record editing and collapse both by
  default.
- Put Rename, Duplicate, Delete, and other owner-specific actions inside the
  selected owner's expanded context.
- Make Prefab collision creation and editing use separate sibling sections,
  row-local expansion, inline metadata, and compact rectangle controls.
- Keep complete validation visible in a dedicated collapsed Diagnostics
  section with severity counts.
- Keep the scene mounted and visible across section, library, and responsive
  layout changes.
- Prevent owner, level, workspace-view, reload, apply, undo, redo, or route
  changes from silently discarding a local form or geometry draft.
- Preserve deterministic commands, revision policy, source drift checks,
  pending diffs, undo/redo, and atomic export.

## Non-goals

- Do not copy Chunk runtime evidence overlays into Prefab Creator. Prefab
  Creator remains a focused source-art and collision editor.
- Do not change Prefab-v3, Tile-v3, or Chunk-v2 source schemas.
- Do not combine rename and metadata into an unreviewed multi-command save that
  produces surprising revision increments.
- Do not weaken reference checks or remove confirmation from destructive owner,
  slice, or module deletion.
- Do not remove the final Apply-to-files confirmation.
- Do not replace half-pixel Prefab collision authoring with Chunk tile-grid
  rules. Shared interaction language does not imply identical domain values.
- Do not add page-level file writes or alternate plugin commands.
- Do not redesign atlas slicing or platform-module cell semantics beyond panel,
  selection, action-placement, and draft-safety alignment.

## Chosen Interaction Model

### Existing records

One row may be expanded in each list. Selecting a different row first resolves
the current local draft. Selecting the expanded row again requests closure.
When the draft is unchanged, closure is immediate. When it is changed, the
author chooses Save, Discard, or Cancel.

The expanded editor contains:

- an explicit `Edit <id>` heading and immutable key/revision context;
- editable fields owned by the relevant typed metadata command;
- `Apply changes` and `Cancel`;
- labeled contextual Rename, Duplicate, and Delete actions where supported;
- reference or downstream-impact information before destructive actions.

An editor is a route-local draft until Apply. Opening or closing it does not
create a pending diff, history entry, or revision.

### Creation

Creation lives in its own `EditorSectionCard`, collapsed by default. Prefab
owner creation reuses the same source/kind/anchor/tag field widget as editing,
with the human ID enabled and creation-specific validation. Chunk creation keeps
its locked-dimension policy visible in the inline section.

Creation submits the existing lifecycle command exactly once. Cancel resets the
draft without mutating source.

### Rename

Rename is presented inside the selected record's expanded context. It preserves
the stable owner key. The implementation may use a small inline sub-form or a
single combined form only if command semantics remain explicit and tested.
Closing the migration requires removing the detached Rename toolbar and its
modal path.

### Delete

Deletion is contextual, but owner deletion retains confirmation because it can
remove geometry and leave downstream stable-key references unresolved. The
confirmation must identify the selected owner and its reference impact. Shape
and placement deletion may remain an immediate undoable typed command when the
existing policy already supports that behavior.

## Prefab Owner Library

The Prefab owner library is a shared visual catalog rather than a second Prefab
document model. It consumes immutable Prefab-v3 and tile/module projections and
keeps search, filters, and selection route-local.

Required behavior:

- search token-by-token across human ID, stable key, kind, source reference,
  and tags;
- filter by kind and status;
- show atlas-slice or platform-module thumbnails through a workspace-scoped
  decoded-image cache;
- show revision, source, collision-shape count, and downstream usage compactly;
- preserve stable-key selection while filtering when the selected item remains
  eligible;
- provide deterministic ID/key ordering and first-result keyboard selection;
- create no source change merely by searching, filtering, or selecting.

The existing Chunk Prefab catalog is the nearest behavior pattern. Reusable
thumbnail, token-search, and filter primitives should move to an owner-neutral
shared location rather than being copied into Prefab Creator.

## Collision Shape Alignment

Prefab collision authoring is reorganized into three sibling sections:

1. **Create collision shape** owns name, collision defaults permitted by the
   selected Prefab kind, material/surface metadata, snap policy, drawing entry
   points, status, Save, and Cancel.
2. **Existing collision shapes** owns the count and list. The selected row
   expands metadata, lifecycle actions, vertices, and exact geometry directly
   below itself.
3. **Diagnostics** owns complete owner and session findings with severity counts
   and focus actions.

Axis-aligned rectangles use the shared compact rectangle editor for exact
position, bottom, width, and height. Arbitrary polygons retain vertex editing.
Prefab metadata editing becomes inline and removes the retained metadata modal
from the normal route.

## Panel And Responsive Layout

Sidebar authoring sections use `EditorSectionCard`, are independently
collapsible, and start collapsed. An active inline editor keeps its containing
section expanded and non-collapsible until the draft is resolved. The scene
retains `EditorPanelCard` as the primary bounded surface.

Wide layout:

```text
+----------------------+--------------------------------+----------------------+
| owner library        | persistent Prefab scene        | active authoring     |
| and creation         |                                | sections             |
+----------------------+--------------------------------+----------------------+
```

Narrow layout:

```text
+--------------------------------------------------------------------------+
| persistent bounded Prefab scene                                          |
+-----------------------------------+--------------------------------------+
| owner library / creation          | active authoring sections            |
+-----------------------------------+--------------------------------------+
```

The narrow layout repositions mounted subtrees. It does not use exclusive tabs
that hide or rebuild the scene.

## Selected-Owner Context

The selected Prefab owner is visible in:

- a compact header selector for fast navigation;
- the selected visual-library card;
- the scene heading or summary;
- the expanded editor when open.

All four resolve the same stable `prefabKey`. Selection itself remains
presentation state and never enters source, validation, or history.

Chunk owner selection retains its existing header selector and preview cards,
but owner metadata moves into the selected row. Detached Edit, Rename,
Duplicate, and Delete controls are removed after their contextual equivalents
land.

## Draft And Navigation Contract

Every inline form exposes whether it differs from its captured owner snapshot.
The containing workspace includes that state in `hasLocalDraftChanges` and
disables Apply-to-files while the draft is unresolved.

Before switching owner, level, workspace view, route, or source revision:

- unchanged editors close safely;
- changed editors offer Save, Discard, or Cancel when an immediate choice is
  appropriate;
- active scene gestures remain blocked until Save/Cancel as today;
- route-level guards continue to use `EditorPageLocalDraftState`;
- rejected or stale Apply leaves the editor open with its values intact and a
  visible error;
- undo first cancels a route-local draft when that is the established route
  contract, then reaches session history.

Only one accepted command may result from one inline Apply. The command uses
the existing metadata/lifecycle/collision policy and captured owner key,
revision, and before snapshot.

## Command And Ownership Boundaries

- `PrefabDomainPlugin` and `ChunkDomainPlugin` remain mutation authorities.
- Owner forms return or submit typed value objects; they never write files.
- Metadata Apply preserves identity, dimensions, geometry, and composition not
  owned by that form.
- Rename preserves the stable key and uses the lifecycle policy.
- Duplicate and Delete use existing lifecycle policies and deterministic ID/key
  allocation.
- Polygon edits use the existing authoring controller and collision commit.
- Search, filtering, expansion, viewport, and form drafts are presentation-only.
- Export remains atomic through the existing stores/session.

## Delivery Phases

### Phase 0 — Plan and characterize

Freeze this strategy, inventory modal paths and draft guards, and add focused
tests that describe the target row-local behavior.

### Phase 1 — Inline owner metadata and critical draft safety

Extract reusable Prefab and Chunk owner forms, render them below the selected
owner row, connect Apply/Cancel, protect navigation, and remove both metadata
edit modal paths.

### Phase 2 — Contextual lifecycle and inline creation

Move owner actions into expanded contexts, replace Prefab creation and both
owner rename modals with inline forms, and retain reference-aware deletion
confirmation.

### Phase 3 — Visual Prefab owner library

Generalize reusable catalog primitives, add Prefab owner thumbnails/search/
filters, synchronize header/library/scene selection, and remove the long plain
owner list.

### Phase 4 — Collision shape parity

Split creation/existing/diagnostics, move selected editing below its row, add
inline metadata and rectangle editing, and remove the Prefab shape-metadata
modal path.

### Phase 5 — Panels and responsive layout

Flatten nested authoring panels, make sections independently collapsed by
default, add the dedicated Diagnostics section, and keep the scene visible and
mounted on narrow layouts.

### Phase 6 — Atlas/module consistency and closeout

Apply the same panel/action/draft language to atlas slices and platform modules
without changing their domain semantics. Complete accessibility, keyboard,
docs, validation, and manual UX acceptance.

## Validation Strategy

Focused widget tests must cover:

- row selection, re-click closure, Apply, Cancel, Save/Discard/Cancel prompts;
- owner/level/view switching with clean and dirty inline forms;
- unchanged Apply producing no command;
- accepted Apply producing exactly one revision and one undo entry;
- stale/rejected commands preserving the draft and reporting failure;
- contextual rename/duplicate/delete targeting the expanded stable key;
- Prefab library search, filters, thumbnails, keyboard selection, and no-op
  presentation state;
- inline Prefab creation and collision-shape creation;
- row-local shape metadata, arbitrary polygon vertices, and rectangle fields;
- collapsed defaults and wide/narrow scene persistence;
- complete Diagnostics counts and focus behavior.

Required validation for each coherent milestone:

- `cd tools/editor && dart analyze`
- focused affected widget/domain tests
- `cd tools/editor && flutter test`

The final collision phase also runs the repository chunk generator dry-run if a
shared authoring/runtime seam is touched.

## Program Acceptance Criteria

- Every scope-baseline row marked Critical, High, or Medium is implemented and
  checked off, or the strategy is explicitly amended before closure.
- Both Prefab and Chunk owner metadata edit inline with no normal edit modal.
- Prefab owner creation, rename, selection, and lifecycle actions are inline and
  contextual.
- Prefab owners are selected through a searchable visual library.
- Prefab collision creation and existing-shape editing use separate collapsed
  sections and row-local inline editors.
- Prefab rectangles have compact exact geometry controls.
- Prefab Diagnostics is independent, collapsed, counted, and complete.
- Narrow Prefab layout keeps the scene mounted and visible.
- No owner or form draft can be silently discarded by navigation.
- Scene-feature differences remain intentional and documented.
- No source schema, deterministic ordering, revision rule, reference check,
  drift guard, history behavior, or export boundary is weakened.
- Analyzer, focused tests, full editor tests, docs, and manual UX/accessibility
  acceptance are complete.
