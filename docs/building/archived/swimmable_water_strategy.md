# Swimmable water strategy

Status: implemented. September 13, 2026. Feature commit: `c062ad40`.

## Outcome

Authors can place rectangular water regions in Chunk Creator, select a terrain
material, save/build them, and swim through them in authored Play and generated
runs. The `fantasy_environment/mixed_biomes.png` atlas supplies the first water
material. Its lower surface loop uses 32px frames at (784,432), (832,432), and
(880,432). Source art stays in the canonical atlas.

## Approach

Keep three independent responsibilities: the authored water rectangle defines
the fluid volume; Core defines swimming; the terrain material defines appearance.
Reuse chunk identity, source codecs, generation, atomic streamed candidates,
editor transactions, atlas extraction, and fixed-tick input. Existing `none`
polygons remain visual-only. A material name never enables gameplay.

An alternative was to add a water collision mode to polygons. That would mix
overlap volumes with the solid-edge compiler and navigation assumptions. Explicit
water regions provide a smaller, clearer boundary. Full fluid simulation is
outside this feature; pools have horizontal, fixed gameplay surfaces.

## Contracts and scope

- Chunk water regions have stable owner-local IDs, whole-pixel rectangle bounds,
  and a terrain material key. Source decoding rejects malformed dimensions and
  duplicate IDs. Runtime binds local coordinates to streamed chunk instances.
- Water publishes atomically with terrain, including background preparation and
  version rebinding. It creates no support or blocking edges. A separate solid
  polygon provides the pool floor and banks.
- Core computes player immersion before action/movement resolution and refreshes
  it after motion for snapshots. Hysteresis prevents surface-state flicker.
- Swimming uses horizontal drag, reduced gravity/terminal sinking speed and a
  jump-press upward stroke. Existing tick-stamped input and replay encoding stay
  intact. Stroke timing and mobility/control-lock interaction are explicit Core
  rules. Other actors retain their existing movement in this first version.
- Water art uses a repeating fill and tick-selected surface frames, with shared
  world phase. A translucent foreground body and surface make immersion visible.
  Gameplay surface height is independent of animated transparent pixels.
- Editor previews and game rendering consume the same material source and frame
  selection math. Atlas frame images are cached and disposed, not decoded per
  frame. Authoring uses the existing plugin/save/build/play paths.
- Initial pools must fit above the level kill plane; camera scrolling remains
  authoritative. Swimming tuning must permit forward progress against scrolling.
  There is no breath meter or water damage in this initial behavior.
- Existing registered dry-level content is preserved. A repository-backed example
  and automated playtest fixture demonstrate a pool without forcing a new pool
  into every live run.

## Validation and delivery

See [implementation checklist](swimmable_water_implementation_checklist.md).
Each coherent milestone is validated before commit. Tests cover source/runtime
parity, fluid boundaries, banks, stroke/control rules, streamed publication,
pause/frame timing, editor transactions, and deterministic replay. Implemented
contracts are recorded in the [TDD](../../tdd/swimmable_water.md) and
[gameplay guide](../../gdd/swimming.md). See the
[validation record](swimmable_water_validation.md) for checks and baseline issues.
