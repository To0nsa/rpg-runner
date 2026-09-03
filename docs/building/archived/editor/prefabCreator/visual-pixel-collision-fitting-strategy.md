# Visual-Pixel Collision Fitting Strategy

Date: September 3, 2026
Status: Implemented and validated

Related documents:

- [Implementation checklist](visual-pixel-collision-fitting-implementation-checklist.md)
- [Prefab and Chunk Creator UX alignment](prefab_chunk_ux_alignment_strategy.md)
- [Editor UI system](../../../../tdd/editor_ui_system.md)
- [Polygon terrain authoring foundation](../../../../tdd/polygon_terrain_authoring_foundation.md)

## Decision Summary

Add pixel-derived collision to Prefab authoring as an inline draft generator,
not as a new collision format. The **Create collision shape** section presents
one explicit creation-method choice:

| Creation method | Generated geometry | Availability |
| --- | --- | --- |
| **Rectangle** | One manually drawn or numerically authored rectangle | Obstacle and Platform |
| **Polygon** | One manually authored polygon | Obstacle and Platform |
| **Fit visible bounds** | One tight rectangle around accepted pixels | Obstacle and Platform |
| **Trace visible outline** | One or more simplified polygons following visible components | Obstacle and Platform |
| **Detect platform surface** | One or more closed polygons whose upward-facing edges follow the detected support profile | Platform only |

The last three methods read pixels from both atlas-slice Prefabs and composed
platform-module Prefabs. **Fit visible pixels** is the umbrella term in
documentation; the UI uses the specific method labels above so authors do not
have to open a second selector to discover what will be generated.

The generated result remains an unsaved, editable draft. The author can inspect
it over the artwork, move vertices, use exact fields, change fit settings and
regenerate, then Save or Cancel. Saving uses the existing Prefab collision
commit path and creates one owner revision and one undo entry.

This deliberately separates two concerns:

- pixel fitting proposes geometry
- the existing authored polygon contract controls gameplay collision

Runtime compilation never reads PNG pixels and no fit settings enter source
JSON. The committed whole-pixel polygons remain the only runtime authority.

## Why The Feature Is Not Rectangle-Only

Ignoring transparent padding needs only a bounding rectangle, but matching the
actual artwork does not. A single rectangle fills empty corners, arches, gaps,
and irregular silhouettes. That is useful as a reliable option, not a complete
definition of **Fit visible pixels**.

The feature therefore treats **Fit visible bounds** as the simple method and
**Trace visible outline** as the fidelity method. **Detect platform surface**
is a semantic projection of the visible artwork: it proposes the surface an
actor should stand on while keeping the collision one-way.

Manual rectangle and polygon authoring remain first-class. Automatic fitting is
an accelerator, not a replacement for intentional gameplay geometry.

## Requirement Traceability

| Requested capability | Delivery gate |
| --- | --- |
| Rectangle | Existing manual behavior retained and integrated with the direct method selector in Phase 4 |
| Polygon | Existing manual behavior retained and integrated with the direct method selector in Phase 4 |
| Fit visible bounds | Raster-to-rectangle vertical slice in Phase 4 |
| Trace visible outline | Multi-component polygon and hole-safe partition work in Phase 5 |
| Detect platform surface | Platform-only one-way profile and active-edge evidence in Phase 6 |
| Apply fitting to an existing shape | Explicit component-scoped refit in Phase 7 |

## Outcomes

- Transparent atlas padding no longer forces authors to estimate collider
  extents by eye.
- Irregular Prefabs can start from a polygonal silhouette instead of a large
  box.
- Platform modules can retain one-way behavior while their support geometry is
  authored against the image rather than a nominal `32 x 32` cell.
- Atlas slices and composed modules use the same fitting workflow.
- Every generated point stays on the current mandatory whole-pixel Prefab grid.
- Authors can review and edit every generated result before it affects source.

## Current Baseline

The implementation must build on these existing contracts:

- Prefab-v3 owns anchor-relative `collisionShapes` with stable shape IDs.
- Prefab collision source uses one whole-pixel grid. JSON still stores doubled
  integer coordinates internally, but odd half-pixel ticks are rejected.
- `PrefabPolygonVisualProjection` already places atlas slices and every module
  cell into Prefab-local visual coordinates.
- Platform-module visual bounds use actual referenced slice dimensions, not a
  fixed collider derived from the module's nominal tile size.
- `PrefabPolygonAuthoringController` owns route-local tools, selections, drafts,
  navigation safety, and dispatch to `PrefabV3CollisionCommitPolicy`.
- `PrefabV3CollisionCommitPolicy` checks the complete before/after shape list,
  canonical ordering, visual bounds, Core validity, and exactly-once revision
  behavior.
- Core accepts at most 64 shapes per placed Prefab and 64 vertices per shape;
  the normal authoring targets are 16 shapes and 24 vertices per shape.
- Core compiles a one-way polygon by exposing only its authored upward-facing
  edges. Its side and bottom edges close the source loop but do not collide.

No fixed cell-sized platform collider exists in this target design.

## Product And UX Contract

### Entry points

The existing **Create collision shape** section exposes the five creation
methods directly: Rectangle, Polygon, Fit visible bounds, Trace visible
outline, and Detect platform surface. The fifth method is present only when the
selected Prefab is a Platform. A selected retained shape gains a contextual
**Refit from pixels** action in its expanded inline editor; refit offers only
the pixel-derived methods valid for that Prefab kind.

No fitting modal is introduced. Activating either action expands an inline fit
editor in the section already associated with the draft or selected shape.

### Inline fit editor

The fit editor for the three pixel-derived methods contains:

- the selected creation/refit method
- live generated shape/component/vertex counts
- visible-pixel coverage, transparent-area addition, and omitted-pixel evidence
  measured on the source pixel grid
- an include/exclude control for each generated component when the method
  produces more than one candidate
- a regenerate action when settings change
- an Advanced subsection for alpha cutoff, minimum island area, and outline
  simplification
- primary shape name, surface kind, material, and read-only kind-derived
  collision behavior
- Save and Cancel actions using the established draft language

Defaults are conservative and reversible:

- a pixel is accepted when `alpha >= cutoff`; the default cutoff is `1`, so any
  nonzero alpha is visible
- no visible island is discarded by default
- generated contours default to at most 24 vertices per shape, with an explicit
  selectable range up to Core's hard limit of 64
- reduction retains original whole-pixel boundary points and minimizes global
  deviation from the source contour instead of applying a local tolerance
- Platform Prefabs default to **Detect platform surface**
- obstacle Prefabs default to **Trace visible outline**
- decoration Prefabs do not expose collision fitting

Advanced values are route-local generator inputs. They are not persisted after
the resulting geometry is saved, and they reset to defaults when a clean owner
or visual-source switch completes.

### Scene feedback

The Collision scene overlays four distinct pieces of evidence:

- source artwork at its existing unmodified rendering position
- accepted alpha-mask pixels or their boundary preview
- complete generated polygon boundaries
- physically active one-way edges for Platform results

The preview must make clear that a closed one-way polygon can have inert side
and bottom edges. Fit overlays must not alter terrain or Prefab rendering.
Coverage counts and active-edge evidence are recomputed after every local
candidate edit, so the inspector never describes the pre-edit generated shape.

### Draft lifecycle

Generating a fit does not change the document, pending diff, owner revision, or
session history. A fit draft owns a before snapshot and one or more candidate
shapes.

The author may:

- adjust generated vertices with existing scene and exact-coordinate tools
- switch pixel-derived methods or settings and explicitly regenerate
- include only the components that should become collision
- Save all included candidate shapes as one semantic collision command
- Cancel and restore the exact pre-fit state

Owner changes, view changes, Reload, Apply to Files, undo, and redo must pass
through the existing Save/Discard/Cancel guard while a fit draft is active.
Changing to another creation method after drawing, generating, excluding, or
editing a candidate uses the same guard; it cannot discard a draft directly.

### Creating versus refitting

Create mode initially includes every generated component and adds only the
included candidate set to the current owner's committed shapes when saved. The
author can exclude decorative or already-covered components before Save. At
least one valid candidate must remain included.

Refit mode replaces the selected shape only after confirmation in the inline
draft. Pixels have no authored ownership relationship with existing collision
shapes, so refit must not guess that every visible component belongs to the
selection. It initially includes only generated components whose pixel-cell
area intersects the selected shape; the author can change that inclusion. If
none intersect, Save stays disabled until the author explicitly chooses at
least one component.

When the included refit result contains multiple generated shapes:

- the first shape from the component with the smallest top, then left, then
  stable contour/partition order retains the selected shape ID
- additional shape IDs are allocated deterministically from that ID
- collision mode is derived from Prefab kind; surface kind and material key are
  copied to every result
- the UI states the replacement count before Save

Cancel keeps the original shape and selection unchanged. Refit never silently
overwrites a retained shape when the fit cannot be represented safely.

If a saved refit would be byte-equivalent to the original canonical shape
list, it closes as an accepted no-op with no revision or history entry.

Fit candidates receive final source IDs deterministically from the captured
owner snapshot and stable component/partition order. In create mode an optional
custom name applies to the primary generated shape and additional shapes use
the lowest free valid suffix. Without a custom name, the existing
`collision_001...` allocator is used repeatedly. In refit mode the primary
included shape retains the replaced shape ID and additional shapes use that
shape's valid numeric prefix when available, falling back to the normal
collision prefix. Regeneration reallocates from the same captured baseline, so
identical input and settings produce identical IDs.

## Collision Semantics By Prefab Kind

| Prefab kind | Manual authoring | Fitted result |
| --- | --- | --- |
| Obstacle | Solid rectangle or polygon | Solid shape set |
| Platform | One-way rectangle or polygon | One-way shape set |
| Decoration | No collision | Fit action unavailable |

Prefab kind is the collision-behavior authority in this workflow. The Collision
field remains visible as read-only context rather than offering an incompatible
choice: an Obstacle is solid, a Platform is one-way, and a Decoration has no
collision. Refit preserves surface/material metadata and shows any collision-
mode correction in the inline preview before Save.

Before enforcing the same rule across all retained source, implementation must
audit current Prefab-v3 data and tests. Any mismatched historical shape needs an
explicit migration or a documented exception; it must not be silently changed
by loading the editor.

The September 3 source audit found 56 colliding Obstacles and all of their
shapes are solid. The four current Platforms have no collision shapes yet, so
there is no live Platform shape to migrate. Empty obstacle/Platform Prefabs are
not bulk-fitted by this feature; authors opt into a method and review each
draft.

## Pixel Source Contract

Fitting reads only the visual source already referenced by the selected Prefab.
It does not open a system file picker or let a collision draft point at an
untracked image. Existing workspace-root and authored-source validation applies
before any file is decoded.

### Atlas slice

The raster adapter decodes the referenced PNG once, validates the authored
slice rectangle against the decoded image, and crops exactly that region. A
visible pixel is evaluated from its source alpha channel; RGB values do not
affect fitting. Static PNG content is the supported contract; if a decoder
reports multiple frames, fitting uses the same first frame as the existing
preview.

### Platform module

The adapter resolves every module cell through the same integer layout used by
the current visual projection. It composites referenced slice alpha into one
normalized module-local mask, including negative cell coordinates and slices
whose dimensions differ from the nominal module tile size.

Cell order and alpha compositing must be deterministic. Missing, undecodable,
or out-of-bounds sources produce a blocking fit diagnostic rather than a
fallback rectangle.

For overlapping module cells, alpha uses integer source-over composition in
authored cell order:

```text
out = source + ((destination * (255 - source) + 127) ~/ 255)
```

The result is clamped to `0...255`. This is specified independently of GPU
painting so fit output cannot vary by graphics backend.

Every loaded source is bound to a digest of its exact PNG bytes. The fit draft
captures the digest together with the visual-layout signature. Regenerate and
Save reject stale work if the Prefab source, anchor, slice/module definition,
or underlying PNG bytes changed after generation.

The preview image and fitting mask must come from the same digest-bound cache
record. A changed file at the same path replaces and disposes the older decoded
image instead of returning the current path-only cache entry. Reload also clears
failed-path entries so a repaired image can be retried. A module identity
combines every referenced PNG digest in authored cell order with its layout
signature.

### Coordinates

Mask coordinates use top-left image pixels. Each accepted raster pixel occupies
the closed-open cell `[x, x + 1) x [y, y + 1)`. Generated vertices lie on pixel
cell boundaries and are converted to Prefab-local coordinates by adding the
resolved visual bounds origin, which already includes the negative anchor.

The conversion must produce whole integers before the existing source adapter
encodes them as doubled ticks. Fitting must never round a half-pixel result or
change the visual projection to make geometry fit.

## Deterministic Fitting Pipeline

All geometry analysis after raster decoding is a pure-Dart operation over an
immutable alpha mask. Identical mask bytes and settings must return identical
ordered shapes and diagnostics on every supported host.

The common pipeline is:

1. Validate dimensions, alpha length, settings, and Prefab capacity.
2. Apply the integer alpha cutoff.
3. Label visible components with four-way connectivity using top-to-bottom,
   left-to-right discovery order.
4. Apply the explicit minimum-island-area setting.
5. Run the selected fit method.
6. Remove duplicate and collinear vertices.
7. Apply deterministic, topology-preserving reduction to the selected
   maximum-vertices-per-shape budget.
8. Convert mask-boundary coordinates into anchor-relative whole pixels.
9. Allocate stable candidate IDs and canonical shape ordering.
10. Compare candidate coverage with the source mask for author-visible evidence.
11. Review the full prospective owner shape list with the existing editor/Core
    validation adapters before enabling Save.
12. Review every current downstream placement transform before enabling Save.

No failure path may return partially truncated geometry.

Coverage evidence uses exact positive-area intersection between each unit pixel
cell and candidate polygons in doubled integer coordinates. It reports raw
threshold-visible pixels, islands/pixels removed by the explicit filter,
accepted pixels covered, accepted pixels omitted, and transparent pixel cells
covered. Bounds fitting is expected to add transparent cells; outline fitting
at zero tolerance is expected to preserve exact accepted occupancy.
Detect-platform-surface evidence instead reports source columns, supported
columns, omitted columns, and maximum vertical deviation from the raw upper
envelope because its polygon area is only a closure for one-way edges.

### Fit visible bounds

Compute `minX`, `minY`, `maxX + 1`, and `maxY + 1` over all accepted pixels and
emit one rectangle. If no pixels survive the settings, generation fails with a
clear diagnostic.

This method intentionally spans transparent gaps between disconnected islands.
The preview states that fact and suggests Trace visible outline when it matters.

### Trace visible outline

Trace outer boundaries along pixel-cell edges for every accepted connected
component. The result may be concave and may produce several shapes. Stable
component ordering is top, left, bottom, right, then discovery order.

Transparent holes require special handling because one source polygon cannot
express an inner ring. Hole-free components use their traced outer loop. A
component with holes is partitioned deterministically from top-to-bottom
scanline runs into non-overlapping simple polygons; adjacent runs may be merged
only when the merge preserves the exact accepted-pixel occupancy and passes
Core review. If that exact partition exceeds a hard shape or vertex limit,
fitting blocks with a specific capacity diagnostic. It must never silently fill
a hole while claiming an outline fit.

Budgeted reduction ranks a candidate removal by the maximum point-to-segment
distance across every original contour point in the replaced arc. Recomputing
that error against the immutable original contour prevents the cumulative drift
of greedy local simplification. Comparisons use squared integer/rational
arithmetic, not floating point. Equal costs use stable area-impact and source-
index tie-breaks. Closed-contour removals are accepted only while winding,
simple topology, and all four original silhouette extents remain unchanged.
Every retained point remains an original whole-pixel boundary point.

If safe reduction cannot reach the selected budget, generation is blocked and
the UI offers a larger maximum, minimum-island filter, or Fit visible bounds.
The fitter never truncates a contour or accepts a result above the explicit
setting.

### Detect platform surface

Build an upper support profile from accepted pixels rather than assigning the
module's nominal cell rectangle. For each retained four-way-connected
component, scan columns from left to right and select the top boundary of the
uppermost accepted pixel in each column. Empty columns split profiles; the
algorithm never bridges a transparent gap automatically. Changes in height are
represented by integer vertical steps before the open profile is reduced to
the explicit per-shape vertex budget. Profile endpoints remain fixed and error
is always measured against the immutable original support profile.

Each accepted support profile becomes the upward boundary of a closed one-way
polygon. The profile is authored left-to-right, then closed down to that
component's bottom boundary and right-to-left along the inert bottom. This
orientation guarantees that only the profile's nonvertical segments face
upward; vertical steps, sides, and bottom closure are inactive under Core's
one-way rule. Prospective polygons still pass self-intersection and overlap
review, which catches interlocking components whose closures cannot coexist.

There is no hidden grass, color, filename, or fixed-cell heuristic. Alpha
cutoff and minimum island area determine the source pixels, while the explicit
vertex budget reduces narrow peaks by their global profile error. The author
sees the raw mask, support profile, active edges, and maximum deviation and can
then flatten noise or adjust ledge extents with normal vertex tools.

The detected Platform result is always one-way. A result without an
upward-facing edge is invalid and cannot be saved.

## Downstream Placement Safety

Fine pixel outlines can contain one-pixel edges that are valid on the Prefab but
collapse or become shorter than Core's minimum after a Chunk placement scale as
low as `0.3`. Reflection can also change which geometric boundary faces upward.
Local Prefab validation alone is therefore insufficient for automatically
generated geometry.

Before Save, the candidate Prefab is expanded through every currently
referencing Chunk placement using the shared content-pipeline transform and
compilation path. The review covers scale, reflection, translation,
quantization, chunk bounds, overlaps, shape/edge capacity, and one-way exposed
edges. A blocking downstream diagnostic names the Chunk and placement and keeps
the fit draft editable.

The review compiles the baseline Chunk first. If that baseline is already
invalid, the editor cannot prove the candidate safe and blocks the collision
commit with a link to the existing Chunk issue; it does not hide or attribute
the old failure to the fit. Candidate compilation uses the complete current
Prefab session snapshot so other pending Prefab edits are not ignored.

The Prefab document may retain immutable read-only Chunk snapshots or an
equivalent typed validation projection loaded by the Prefab plugin. It must not
become the authority for writing Chunk files. Apply to Files rechecks current
referencing Chunk sources; drift requires Reload instead of exporting Prefab
geometry validated against stale placements.

Unreferenced Prefabs still receive local Core review. The Chunk Creator remains
the authoritative visual preview for each transformed placement.

## Architecture And Ownership

### Pure fitting domain

Add a bounded Prefab fitting package under `tools/editor/lib/src/prefabs/**`
that owns:

- immutable alpha masks and fit settings
- connected-component and boundary analysis
- bounds, outline, and platform-surface generation
- deterministic simplification and ordering
- candidate diagnostics independent of Flutter widgets and repository I/O

The fitting domain consumes integer dimensions and alpha bytes. It must not
import `dart:ui`, read files, know editor routes, or dispatch session commands.

### Visual raster adapter

Use one adapter at the Flutter/editor boundary to:

- resolve the Prefab visual layout
- load/crop atlas images through the existing decoded-image infrastructure
- compose module-cell alpha
- convert `ui.Image` RGBA into the pure alpha-mask input
- cache completed masks by PNG-content digest and integer-layout signature

The current visual projection and the raster adapter must share one integer
layout resolver. Do not copy anchor, module normalization, or slice-destination
math into a second implementation.

Image decode and byte extraction are asynchronous and must remain outside
widget `build` methods. Cache invalidation follows workspace/reload/source
digest, and every owned `ui.Image` is disposed by the existing cache owner. The
existing `image` dependency is sufficient; this feature must not add another
PNG or geometry package without a focused dependency review.

PNG decode/crop and `ui.Image` byte extraction stay on the supported Flutter
boundary. Component analysis and geometry generation run synchronously over a
normalized mask capped at 1,048,576 pixels. The largest current authored atlas
slice is 68,628 pixels and the largest current platform module is 4,096 pixels,
so isolate startup and serialization would dominate the measured repository
workload. Every request still carries a monotonically increasing generation
token so a late image result cannot revive a cancelled or replaced draft. A
future content expansion that approaches the cap must re-profile this decision
before raising it.

### Authoring controller

Extend the Prefab polygon authoring state with one fit-draft-set model rather
than creating a parallel page-level save path. It owns:

- original shape-list snapshot
- create or refit intent
- fit settings and async loading/generation status
- ordered candidate shapes, inclusion state, and selected candidate
- transient fit diagnostics

The fit draft maintains a local prospective owner-shape list: retained shapes
plus included create candidates, or retained shapes with the selected refit
target replaced by included candidates. Existing polygon interaction and exact
editors operate on that local list. Their intermediate commits update route-
local fit history only; they are never dispatched to the session. UI actions
cannot edit or delete retained non-candidate shapes while the fit draft is
active.

Save constructs one public `TerrainPolygonInteractionCommit` from the captured
committed owner list to the final prospective list and delegates to
`PrefabV3CollisionCommitPolicy`. Fit-local undo/redo is consumed before session
undo/redo, and Regenerate records one local history step after confirmation if
manual candidate edits would be replaced.

### Persistence and runtime

No source-schema field is added for alpha threshold, fit mode, simplification,
or source pixel data. Only the resulting canonical `collisionShapes` persist.

No gameplay renderer, collision kernel, or runtime image loader changes for
this feature. The existing content pipeline continues to expand the committed
polygons through placement scale, reflection, and translation.

### Likely file map

Primary existing seams:

- `tools/editor/lib/src/app/pages/prefabCreator/shared/prefab_polygon_visual_source.dart`
- `tools/editor/lib/src/app/pages/shared/editor_scene_view_utils.dart`
- `tools/editor/lib/src/app/pages/prefabCreator/shared/prefab_polygon_authoring_controller.dart`
- `tools/editor/lib/src/app/pages/prefabCreator/v3/prefab_polygon_workspace.dart`
- `tools/editor/lib/src/prefabs/domain/prefab_domain_models.dart`
- `tools/editor/lib/src/prefabs/domain/prefab_domain_plugin.dart`
- `tools/editor/lib/src/prefabs/domain/prefab_v3_collision_commit.dart`
- `tools/editor/lib/src/terrain_authoring/terrain_polygon_interaction.dart`

New pure fitting code belongs under
`tools/editor/lib/src/prefabs/collision_fitting/`, split by mask analysis,
outline/platform generation, settings/results, and deterministic coverage
evidence. Flutter raster loading remains under the shared editor-page surface.
Tests mirror those boundaries instead of concentrating algorithms in one
workspace widget test.

Expected unaffected runtime seams:

- `packages/runner_core/lib/collision/terrain/**`
- gameplay rendering under `lib/game/**`
- Prefab and Chunk source schemas

The content pipeline may gain reusable candidate/downstream review entry points,
but its runtime materialization output does not change.

## Compatibility And Migration

The feature adds no source field and performs no automatic content migration.
Existing polygons load, render, compile, and export unchanged until an author
chooses a manual or pixel-derived edit and saves it.

Making Prefab kind authoritative for collision mode does tighten validation.
Implementation must update both editor validation and current-schema content-
pipeline validation so hand-edited JSON cannot bypass the rule. The current
authored source needs no migration, but incompatible test or migration fixtures
must be corrected deliberately and remain available only where they test
rejection. Applying this rule must not rewrite valid source during load.

## Alternatives Considered

- **Only fit a rectangle:** simple, but does not meet irregular-outline or
  Platform-surface needs. It remains the fast Fit visible bounds option.
- **Persist the alpha mask or fitting recipe:** would create a second collision
  authority and make runtime depend on art files. Rejected in favor of committed
  polygons.
- **Generate and save immediately:** fast but unsafe for decorative pixels,
  topology limits, and downstream scales. Rejected in favor of an editable
  draft with explicit Save.
- **Duplicate visual-layout math inside the fitter:** smaller initial diff but
  likely to drift from rendering. Rejected in favor of one integer resolver.
- **Add a new geometry/image dependency immediately:** unnecessary before the
  existing cache, Core predicates, and `image` package are exhausted.

## Main Risks And Mitigations

| Risk | Mitigation |
| --- | --- |
| Pixel outlines exceed shape/vertex limits | Global-error budgeted reduction, exact counts/deviation, hard blocking, explicit settings, no truncation |
| Decorative pixels create poor gameplay collision | Raw-mask/edge preview, zero-loss defaults, editable drafts, no hidden semantic heuristic |
| Holes are silently filled | Exact deterministic partition or blocking capacity diagnostic |
| Preview and generated coordinates drift | One shared integer visual-layout resolver with parity fixtures |
| Async image results target the wrong Prefab | PNG/layout digests, generation tokens, cancellation, stale-result rejection |
| Locally valid detail breaks scaled Chunk placements | Shared downstream transform/compiler review before Save and export |
| Mode tightening rewrites historical content | Baseline audit, explicit validation migration, no mutation during load |
| Large masks freeze or exhaust the editor | Cropped allocation, 1,048,576-pixel hard budget, digest cache reuse, and required re-profiling before that budget can increase |

## Failure And Diagnostic Contract

Generation remains unavailable or blocks Save for:

- missing or undecodable source image
- slice outside decoded PNG bounds
- unresolved or empty module composition
- source or visual-layout digest changed after generation
- raster dimensions or allocation size exceed the profiled editor safety budget
- no pixels surviving the current settings
- topology that cannot be safely partitioned into accepted simple polygons
- degenerate or self-intersecting candidate geometry
- candidate overlap rejected by current Prefab/Core rules
- prospective owner total above 64 shapes or any shape above 64 vertices
- a Platform result with no upward-facing edge
- a downstream placement rejected after scale/reflection/quantization
- source/owner/Chunk drift between fit start and Save

Soft-target excesses at more than 16 shapes or 24 vertices per shape remain
warnings, visible before Save. Diagnostics include the fit method, source ID,
component where applicable, and a concrete recovery action.

## Performance Budget

- Decode each distinct source PNG at most once per workspace cache generation.
- Cache alpha masks separately from painted thumbnails.
- Decode only required atlas regions and allocate only the normalized module
  mask needed by the selected Prefab.
- Reject dimensions and multiplication overflow before allocating RGBA or mask
  buffers.
- Keep pure fitting synchronous below the fixed mask budget; re-profile and add
  an isolate boundary before increasing that budget.
- Cancel or ignore stale async results when owner, source, workspace, or fit
  settings change.
- Show progress for work that is not complete in the current frame.
- Retain deterministic large-mask and overlapping/negative module fixtures;
  current authored-source dimensions remain well below the fixed budget.

No fixed millisecond promise is locked before baseline profiling. The UX gate
is that changing fit settings does not freeze pan, zoom, or navigation.

## Non-Goals

- Runtime collision derived dynamically from textures
- Persisting alpha masks or fit settings in Prefab JSON
- A fixed `32 x 32` platform collider
- Subpixel or half-pixel Prefab collision
- Automatically accepting generated geometry without preview
- Per-placement collision overrides in Chunk Creator
- Rotated collision shapes
- Inferring semantic surfaces from RGB color or asset naming
- Replacing manual rectangle or polygon authoring
- Automatically reauthoring every currently empty obstacle or Platform Prefab

## Delivery Strategy

The feature is delivered in gated vertical slices:

1. Freeze mask, coordinate, ordering, kind, and draft contracts.
2. Share integer visual layout and add cached alpha extraction for slices and
   modules.
3. Add the downstream-placement validation foundation shared by automatic and
   manual collision edits.
4. Implement Fit visible bounds end-to-end as the simplest complete draft
   workflow.
5. Add Trace visible outline, multi-component drafts, exact hole handling, and
   deterministic simplification.
6. Add Detect platform surface and active one-way edge preview.
7. Add retained-shape refitting.
8. Close accessibility, performance, and documentation gates.

Fit visible bounds is an intermediate implementation milestone, not the
completed feature. The program is complete only when polygonal outline fitting,
Platform surface detection, and downstream placement validation are delivered
and validated.

## Acceptance Criteria

- Rectangle, Polygon, Fit visible bounds, and Trace visible outline are visible
  creation methods; Detect platform surface appears for Platforms.
- Pixel-derived methods work for atlas-slice and platform-module Prefabs.
- Transparent padding is excluded according to the visible alpha settings.
- Irregular and disconnected artwork can produce multiple editable polygons.
- Platforms remain one-way and preview the exact upward-facing owner-local
  runtime edges.
- Generated vertices are anchor-relative whole pixels and visual rendering is
  unchanged.
- Create and refit results remain local until Save; Cancel is a complete no-op.
- One Save produces at most one Prefab collision command, revision increment,
  and undo entry.
- Missing pixels, unrepresentable topology, capacity excesses, stale source,
  and invalid geometry fail explicitly without truncation or hidden fallback.
- Every current referencing Chunk placement accepts the candidate through the
  shared transform/compiler path before Save and again before file export.
- Runtime consumes only committed polygons and never decodes source images.
- Analyzer, focused tests, full editor tests, generator dry-run, documentation,
  performance, and manual accessibility/UX gates are complete.
