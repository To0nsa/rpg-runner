# Terrain Material Authoring Plan

## Problem

Polygon `materialKey` currently selects one entry duplicated between a runtime
Dart registry and an editor-only preview list. The metadata dialog shows the
fill, top strip, and foreground files independently, but does not expose the
registered cap art, unsupported wall/underside orientations, asset alignment,
or a workflow for adding another material. Runtime only decorates upward-facing
edges, and the registered caps are not loaded or drawn.

That makes `materialKey` look like free metadata even though it is a strict
render-content reference. Adding a material currently requires coordinated
source edits that the editor neither explains nor validates.

## Ownership

- `assets/authoring/level/terrain_material_defs.json` is the source of truth.
- `packages/terrain_materials` owns the pure-Dart schema, strict decoder,
  canonical encoder, and deterministic key ordering shared by tools.
- The editor owns repository I/O, image inspection, previews, validation, and
  author commands through a dedicated plugin/store.
- The root content generator owns the generated Flame registry. Generated Dart
  is never hand-edited.
- Core continues to own exact polygons, exposed edges, normals, joins, and
  material-key propagation. It does not know image paths or rendering rules.
- Flame maps manifest profiles onto the exact Core edge snapshot without
  deriving collision geometry.

## Material Contract

Every material has:

- a stable lower-snake-case key, display name, and positive revision;
- one required repeating fill texture;
- one required top profile used by horizontal and sloped upward-facing edges;
- optional left-wall, right-wall, and underside profiles;
- an optional paired top-start/top-end cap set.

An edge profile contains a required base layer and optional detail layer. Each
layer records the source-image Y coordinate aligned to the exact terrain edge.
A cap records the source-image X/Y point aligned to its top-edge endpoint.
Missing optional orientations mean “fill only,” not an implicit texture
fallback. The editor must make that coverage visible.

## Runtime Classification

Core outward normals select profiles:

- negative Y: top/slope;
- zero Y and negative X: left wall;
- zero Y and positive X: right wall;
- positive Y: underside.

Top caps render only where an adjacent edge is absent or does not itself use a
top profile. Smooth/connected top-to-top continuations, including resolved
streaming seams and slope joins, do not receive cliff caps. This decision uses
the snapshot's exact edge IDs, normals, and join topology.

## Editor Workflow

The Terrain Materials route will support create, duplicate, edit, and guarded
delete. Asset selection is limited to normalized PNG files under
`assets/images/terrain/`. Apply remains disabled for duplicate keys, missing
required fields/files, invalid anchors, dimensions smaller than anchors, or a
material referenced by source being deleted.

The material inspector and polygon selector show:

- a composed fill/top/cap sample;
- every source asset and alignment value;
- explicit Top/Slope, Left wall, Right wall, Underside, and Caps coverage;
- clear missing-file and unsupported-orientation diagnostics.

## Completion Criteria

- Adding or duplicating a material requires no Dart source edit.
- Editor and generator consume the same strict contract.
- Polygon selectors are manifest-backed and retain unknown legacy values
  without silently replacing them.
- Existing `grass_dirt` fill and top layers render unchanged.
- Configured caps do not appear on smooth chunk seams.
- Configured wall/underside profiles render only on matching exact Core edges.
- Analyzer, package tests, editor tests, generator drift checks, and relevant
  game/UI asset tests pass.
