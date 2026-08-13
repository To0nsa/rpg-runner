# Animation Authoring Strategy

- Status: proposed
- Owner: content/editor + Core/render maintainers
- Last reviewed: August 13, 2026

## Purpose

Provide one repository-backed workflow for authoring the visual animation data
of playable characters, enemies, and the existing renderable gameplay content
without moving gameplay authority into Flutter, Flame, or the editor.

The intended outcome is an `Animations` route in `tools/editor` that lets a
content author inspect and edit sprite-sheet clips, timing, pivots, scale, and
art-facing direction; validates the result against current Core behavior; and
exports deterministic source data plus generated Core definitions.

This plan describes proposed work. It does not claim that an animation
authoring domain, an NPC runtime entity, or generated animation content exists
today.

## Current baseline

Animation is deliberately split across layers today:

- Core picks a logical `AnimKey` and deterministic tick-relative frame through
  `AnimResolver` and `AnimSystem`.
- `RenderAnimSetDefinition` holds frame size, source path, grid metadata,
  frame count, and visual step duration.
- Flame converts the snapshot frame hint into a source rectangle and renders
  the selected sprite.
- Player and enemy render metadata is currently declared as Dart constants in
  their Core catalogs.
- The Entities route parses a subset of that metadata for preview. It can
  select a key and step a frame, but does not own or export clip definitions.

The authoritative timing and ownership contract is
[`docs/tdd/animation_data_flow_and_timing.md`](../tdd/animation_data_flow_and_timing.md).
This plan extends its source-authoring workflow; it must not change the Core
to renderer authority direction.

## Locked design decisions

1. Core remains the sole authority for animation-state selection, frame origin,
   fixed-tick advancement, collision, damage, despawn, progression, and replay
   outcomes. The editor never runs a competing gameplay state machine.
2. The editor owns visual clip data only: sprite source, regular-grid slicing,
   frame count, per-clip step duration, pivot, render scale, art-facing
   direction, and declared playback mode.
3. Animation authoring data is checked-in JSON under `assets/authoring/`, not
   direct source patches to the current Dart maps. A deterministic generator
   produces the Core render definitions. Generated files are never hand-edited.
4. The first version supports only source layouts the current Flame loader can
   represent exactly: fixed-size cells, horizontal strips or regular grids,
   contiguous frames, and one constant duration per clip. It does not support
   trimmed/rotated atlas regions, arbitrary per-frame durations, bones, or
   editor-side image manipulation.
5. Existing images remain checked in below `assets/images/` and are created in
   an external art tool. The editor selects and verifies repository paths; it
   is not a generic asset manager.
6. `AnimKey` remains a protocol-stable Core enum. It is the state namespace
   for Core-snapshotted actors and must not be renamed, reordered, or extended
   casually. Visual-only props use a separate local state-id namespace when
   that runtime surface is introduced.
7. A change to frame count or step duration is gameplay-adjacent whenever Core
   derives a lifecycle window from that strip. The editor must make this
   visible and the change requires Core timing/regression coverage.

Changing a locked decision requires updating this plan and the animation timing
TDD in the same change.

## Scope by renderable content

| Content | Animation-set identity | Editor responsibility | Core/runtime responsibility |
| --- | --- | --- | --- |
| Playable character | stable character visual-set id, bound to `PlayerCharacterId` | full clip set, pivot, scale, art-facing, action timing diagnostics | selected character, `AnimProfile`, ability `animKey`, hit/spawn/death lifecycle |
| Enemy archetype | stable enemy visual-set id, bound to `EnemyId` | full clip set, pivot, scale, art-facing, sheet preview | AI, combat, spawn, death behavior, logical facing, profile support |
| Projectile/pickup/impact | stable catalog visual-set id | spawn/idle/hit strips and one-shot preview | lifetime, collision, event emission, cleanup |
| World prop | stable prop visual-set id | visual states such as `idle`, `open`, `broken` | only added when a prop renderer has an explicit state input |
| NPC | no current runtime binding | no implementation in the first pass | in-world NPCs require a separate Core/snapshot design; town/UI presentation remains UI-owned unless explicitly migrated |

The current Entities editor type list contains player, enemy, and projectile
only. Do not imply that NPCs or generic animated world objects are already
spawnable Core entities as part of this work.

## Authoring source and generated output

### Source layout

Use one animation-set file per actor/content entry to keep ownership and code
review focused:

```text
assets/authoring/animation/
  manifest.json
  sets/
    player.eloise.json
    enemy.grojib.json
    enemy.hashash.json
    enemy.derf.json
```

`manifest.json` owns schema versioning and the canonical ordered list of set
ids. A set file contains the target binding and all clips for that one visual
set. File order, set order, and clip order are canonicalized by the store.

### V1 set shape

The exact field names may evolve during implementation, but the contract must
represent this information without implicit defaults:

```json
{
  "schemaVersion": 1,
  "id": "enemy.grojib",
  "target": { "kind": "enemy", "coreId": "grojib" },
  "frameSizePx": { "width": 154, "height": 60 },
  "anchorPx": { "x": 77, "y": 30 },
  "render": { "scaleX": 1.5, "scaleY": 1.5, "artFacing": "right" },
  "clips": [
    {
      "key": "strike",
      "source": "entities/enemies/grojib/grojib.png",
      "row": 2,
      "firstFrame": 0,
      "frameCount": 8,
      "stepMilliseconds": 60,
      "playback": "once"
    }
  ]
}
```

Store clip duration as a positive integer number of milliseconds. The generator
emits the `double` seconds value required by `RenderAnimSetDefinition`; Core
and the editor both display the quantized tick value using the production
rounding rule. This avoids a separate floating-point authoring convention.

The target binding lets the generator emit typed, compile-time Core tables. It
must not require runtime string lookup in the fixed-tick hot path.

### Generated output

Add a generator, for example `tool/generate_authored_animation_data.dart`, that
accepts `--dry-run` and writes one clearly marked generated Core artifact, for
example:

```text
packages/runner_core/lib/generated/authored_animation_catalog.dart
```

The artifact supplies `RenderAnimSetDefinition` values, visual scale/facing
metadata, and playback metadata in a typed form consumed by the existing
player, enemy, projectile, pickup, and effect catalogs. Core catalogs retain
their gameplay definitions and reference the generated visual definition; the
generator does not begin to generate enemy AI, abilities, physics, or combat.

Player/enemy one-shot policy is currently partially duplicated in render
registries. Characterize its exact current behavior first, then migrate it to
the generated visual definition only when the generated field reproduces all
existing playback behavior.

## Editor architecture

### New domain

Add a bounded `tools/editor/lib/src/animations/` domain with:

- immutable document, set, clip, target, and validation models;
- parser, canonical serializer, store, and source-drift-safe export flow;
- `AnimationDomainPlugin` implementing `AuthoringDomainPlugin`;
- a route registration in the existing home-route registry and plugin registry;
- an `Animations` page with page-local selection, canvas, playback, and form
  draft state.

The plugin owns repository load, validation, canonical output, pending diffs,
undo/redo participation, and export. Widgets must not create alternate write
paths.

### Entities-route integration

The Entities route needs visual data only to show colliders against a selected
frame. After migration, it reads an immutable projection from the animation
source; it does not parse or write generated/Core Dart animation maps. The
Animation route is the sole writer of clips and visual metadata. Provide a
guarded navigation affordance from an entity to its owning animation set.

This preserves the existing separation between entity collider authority and
animation authority while avoiding two parsers and two persistence paths for
the same visual data.

### Authoring UI

The first page should include:

- category/set browser with stable id and Core target shown;
- image canvas with zoom, checkerboard, regular grid, frame-range highlight,
  and invalid-cell feedback;
- draggable anchor/pivot and optional read-only collider overlay;
- clip list keyed by the valid logical state keys for the target;
- inspector for source path, row, first frame, grid columns, count, duration,
  scale, facing, and playback;
- play, pause, scrub, mirror, and frame-step preview controls;
- a Core compatibility/timing panel that shows required/supported keys,
  current ability mappings, quantized ticks per frame, and full-strip ticks.

Preview selection is a presentation convenience. Selecting `strike` in the
editor must not simulate an ability or change the game state.

## Validation and timing rules

Blocking validation errors:

- unsupported or duplicate set id, target binding, or clip key;
- target that does not match the known catalog identity for its target kind;
- missing image, non-positive frame dimensions/count/duration/scale, or
  non-finite pivot;
- pivot outside the source frame;
- negative row/start, invalid grid column count, or any source rectangle past
  the decoded image bounds;
- a required Core profile/action/lifecycle key with no render clip;
- schema/source drift or noncanonical serialized order.

Warnings:

- a supported but intentionally omitted optional state;
- action/lifecycle duration that does not match the visual strip;
- `spawn` falling back to `idle` where that is intentionally retained;
- a visually unusual non-uniform scale.

The timing panel must show the same rule documented in the TDD:

```text
ticksPerFrame = max(1, round(stepTimeSeconds * tickHz))
fullStripTicks = frameCount * ticksPerFrame
```

It must not promise that a nominal duration maps to the same number of ticks at
every supported tick rate. Ability windup/active/recovery remains authored and
owned separately by the ability system; a duration mismatch is often valid but
must be intentional.

## Migration plan

### Phase 0 — contract and characterization

1. Update the animation timing TDD with source ownership, generated-content
   workflow, playback ownership, and the visual-versus-gameplay distinction.
2. Inventory every current player, enemy, projectile, pickup, and impact set.
3. Add tests that capture each existing generated-equivalent definition and
   current one-shot behavior before moving data.
4. Decide whether the generated output includes only `RenderAnimSetDefinition`
   or also the registry-owned scale/facing/playback metadata. Prefer one visual
   definition per set where characterization proves parity.

### Phase 1 — source, generator, and no-op migration

1. Implement the JSON schema, parser, canonical serializer, validator, and
   generator with `--dry-run` drift checking.
2. Mechanically populate source JSON from the current constants.
3. Generate Core output and migrate player/enemy catalog references with no
   intended runtime behavior change.
4. Prove parity for assets, frames, rows, starts, grid columns, anchors,
   scales, one-shot behavior, and quantized lifecycle durations.

This phase starts with playable characters and enemies only. It is complete
only after the generated tables replace the corresponding handwritten visual
maps without changing gameplay ownership.

### Phase 2 — editor route

1. Implement `AnimationDomainPlugin` and register the `Animations` route.
2. Add set/clip editing, image decoding, grid rendering, anchor editing,
   clip playback, undo/redo, diff preview, source-drift checks, and guarded
   export.
3. Convert Entities preview to consume read-only animation projections and add
   guarded navigation to the owning animation set.
4. Add editor tests for load/edit/undo/redo/export/reload and all validation
   severities.

### Phase 3 — existing non-actor render content

Migrate projectiles, pickups, spell impacts, and other already-rendered
catalog content one bounded family at a time. Preserve the existing
event-driven VFX path: an animation-set edit cannot make a renderer issue a
gameplay event, damage, or collision.

### Phase 4 — new content types, only with a consumer

Add prop or NPC animation support only alongside a concrete renderer and its
explicit state input. An in-world NPC requires a separate Core entity,
snapshot, and determinism design before it can use `AnimKey`. UI/town animation
does not automatically belong in this system.

## Non-goals

- skeletal animation, blend trees, inverse kinematics, or a generic timeline
  engine;
- per-frame hitboxes, damage markers, gameplay events, or collision editing;
- importing/copying/transcoding arbitrary art assets;
- editor-side simulation of AI, abilities, or Core animation resolution;
- a new generic NPC runtime entity;
- dynamic JSON loading in Core, Flame, the replay validator, or production
  client builds.

## Required tests and validation

### Generator and Core

- schema migration, canonical ordering, deterministic serialization, and
  `--dry-run` drift detection;
- each migrated definition matches its pre-migration visual metadata;
- invalid target/key/timing/grid definitions fail with stable diagnostics;
- player and enemy lifecycle timing remains correct at supported tick rates;
- `AnimResolver`, snapshots, death/despawn, and replay-sensitive Core behavior
  retain their documented outcomes.

### Editor

- plugin load, edit, undo, redo, validation, pending-diff, export, and reload;
- decoded-image boundary validation and anchor/collider preview projection;
- route/session switching has no unsaved-change bypass;
- Entities remains read-only with respect to animation content.

### Runtime

- Flame source-rectangle and deterministic-frame tests for strips and regular
  grids;
- player/enemy registry loading parity;
- first-frame asset warmup continues to discover the selected character and
  enemy asset paths through Core definitions.

Run the relevant checks for every implemented phase:

```powershell
dart analyze packages/runner_core
Push-Location packages/runner_core
dart test
Pop-Location

Push-Location tools/editor
dart analyze
flutter test
Pop-Location

flutter test test/core
flutter test test/game
```

Add replay-validator checks when a migrated timing field changes an output that
the validator relies on. A visual-only asset path/pivot/scale change does not
need a protocol change, but any change that affects Core lifecycle timing must
be treated as a Core content change and validated on both run client and
validator paths.

## Acceptance criteria

The strategy is delivered when all of the following are true:

- animation content has one checked-in source of truth and one deterministic
  generator;
- no handwritten player/enemy visual maps remain as a parallel authority after
  their migration;
- the editor can safely edit, validate, preview, diff, export, reload, and
  undo/redo player and enemy animation sets;
- Core still selects all logical states and frames, and Flame only renders the
  resulting snapshots;
- existing player/enemy visuals and timing are behaviorally unchanged by the
  first migration;
- existing projectile/pickup/effect work is migrated only after focused parity
  tests;
- NPCs and props have not gained unsupported implied gameplay authority;
- the animation timing TDD, editor instructions, generator workflow, and
  relevant public setup documentation describe the shipped behavior;
- the focused Core, editor, game, and replay-validator checks for the changed
  scope pass.
