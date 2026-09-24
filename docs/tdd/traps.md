# Trap placement and animation contracts

The Core catalog, Chunk-v2 placements, fixed-tick gameplay, Flame rendering and
Chunk Creator Traps tab are implemented. See the
[completed plan](../archive/2026-09-24/building/traps/plan.md) and
[validation record](../archive/2026-09-24/verification/traps.md).
Per-placement tuning has its own
[verification record](../archive/2026-09-24/verification/trap-placement-tuning.md).

## Ownership and source

`runner_core/traps` owns immutable IDs, placements, geometry and frame maps.
`runner_content_pipeline` owns the single strict JSON decoder used by both the
editor codec and generator. `ChunkPattern.traps` carries the compiled placements;
Chunk Play and Level Play capture immutable lists and validate them against
their captured terrain dimensions. Traps do not alter terrain signatures or
connection seams.

Source order is lexicographic by x, y, trap enum ordinal, facing enum ordinal,
trigger offsetX, offsetY, width, height, effective damage100 and windupMs.
Exact duplicates and more than eight placements per chunk are rejected.
Positions and rectangle coordinates must be integers. The full sprite rectangle,
anchor, trigger and all damage envelopes
must fit in the chunk. Spike omits `facing`; the other types require `left` or
`right`. Facing mirrors art and damage geometry about the anchor, but leaves
the independently saved trigger unchanged. An absent `traps` field means empty;
explicit null fails. Export omits an empty collection, preserving existing
trap-free bytes.

Each placement optionally overrides `damage100` (integer hundredths of HP,
1–100000) and `windupMs` (integer milliseconds, 0–30000). Omitted values resolve
to the catalog defaults; explicit defaults serialize away. Equality, hashing,
canonical ordering and editor selection use effective values. Strict decoding
rejects null, non-integer and out-of-range overrides. These fields flow through
the shared codec, materializer, generated constructors and captured Play; no
separate tuning document or migration path exists.

Editor composition snapshots and operations include traps. Existing layer,
prefab and marker edits retain them, and trap operations use the same optimistic
revision policy and whole-document validation as those existing domains.

## Reviewed art map

All coordinates below are source pixels. Spike and Axe use 128-pixel cells.
Their reference GIFs were compared against PNG cells using nontransparent source
pixels. The GIFs include a background and floor; the Spike comparison excludes
pixels at or below the floor at local y=95. Original archives remain under the
ignored `resources/traps` directory; runtime PNGs are under
`assets/images/entities/traps`.

| Trap | Sequence | Durations | Anchor | First harmful time |
| --- | --- | --- | --- | --- |
| Spike | 27 row-major cells, 15 columns; GIF 0–26 | 100 ms except cells 7–9 at 40 ms | (64,96) | 700 ms |
| Axe | Occupied cells 10–31, then 32–36 repeated three times, then 37–49, then 0; GIF 23–73 | 100 ms through 31; 350 ms for 32–36; 70 ms for 37–40; 150 ms for 41–49; 300 ms for 0 | (64,26) | 800 ms |
| Dart launcher | Cropped row 1 cells 0–4, row 2 cell 0, row 3 cells 0 and 2 | 200 ms for first two poses, then 100 ms | (32,24) in cropped frame | 500 ms |

Axe occupied-cell numbering follows rows with 10, 22, 5 and 13 occupied cells.
GIF 0–22 is ambient motion and is excluded from the triggered cycle. Blade
capsules follow each visible blade pose; the two blurred release poses use
elongated capsules. Spike capsules follow the exposed tips during cells 7–21.

The Poison Darts pack has no reference GIF. Its initial safe timing is explicit
catalog tuning. Launcher rectangles are 52×64, offset (32,48) within each
128-pixel sheet cell. This crops the baked flying darts from the launcher art.
The muzzle is (22,-2) relative to the anchor. The independent flight rectangle
is the full cell (0,640,128,128), with pivot (15,72), retaining native pixel size.
Impact uses row 6 cells 0–11 at 60 ms each, with its own pivot (64,76).
The shared animation loader supports explicit rectangles and per-animation
anchors, so flight and impact do not inherit the launcher's crop or pivot.
The launcher sequence fires exactly once. Idle Axe art uses occupied cell 0;
the triggered cycle begins at cell 10.

Core frame boundaries use ceiling of cumulative milliseconds × tickHz / 1000.
This avoids accumulating per-frame rounding error. At 60 Hz the Spike sequence
is 152 ticks (2520 ms reference, +13⅓ ms); Axe is 563 ticks (9380 ms,
+3⅓ ms); launcher is 60 ticks (1000 ms, exact). Total error is less than one
tick. The catalog gives a one-second cooldown following each sequence.

A placement's wind-up retimes only frames before the first harmful pose (or
dart launch). Their cumulative boundaries are scaled by requested/original
wind-up, then rounded up once to a tick using integer rational arithmetic.
Subsequent frame boundaries shift by the wind-up difference, retaining authored
attack/recovery durations. Zero skips harmless wind-up frames. Default values
preserve the original schedule exactly; damage remains aligned with the same
visible poses. The editor accepts HP to two decimals and seconds to three,
converting directly to integer source units without silently rounding input.

`RenderFrameRect` is pure data for explicit sprite extraction. Frame selection
belongs to fixed-tick Core timing; renderers must not infer hit windows from
elapsed animation time.

## Runtime lifecycle and ordering

`TrapStore` binds selected chunk placements after terrain publication and retains
their state across selection refreshes. Culling retires only launcher state.
Already-fired darts and queued statuses retain their immutable source values.
Traps are separate state, not attackable entities.

`TrapSystem` queries the shared living-target cache after movement and self
defenses, before damage middleware. A trigger overlaps actor capsules; it never
deals damage itself. Both resting art and the catalog's
`activationVisibilityBounds` must positively overlap Core's camera bounds. These
bounds are simulation-only; they are never drawn. Losing either during the
non-damaging wind-up (`TrapPhase.warning`) or attack cancels the cycle into
cooldown. A finished cycle requires one second of cooldown, an empty trigger,
and no live dart before it can activate again. Pause and player-death freeze
skip the gameplay system with the rest of Core.

Spike and Axe resolve every target in stable entity-ID order and remember one
attempt per target per cycle, including blocked hits. Between harmful poses,
the shared hit resolver tests the convex hull of the capsule endpoints expanded
by the larger radius. Source validation bounds that complete conservative sweep.
Frame transitions into nonharmful art do not repeat the prior pose's damage.

Darts use the common projectile motion, nearest swept hit, damage, status and
lifetime systems. The trap spawn adapter gives them environmental targeting,
the placement's impact damage (default 1 HP Poison), speed 340 units/second and
three seconds of travel. Spawn copies damage so later launcher retirement cannot
change a live projectile. Contact traps also read the placement's damage.
They have no physical terrain body. A dart created on T first hits on T+1,
including actors overlapping its muzzle; ordinary projectiles retain their
existing launch-tick eligibility. Ownerless projectile source zero is converted
to null damage attribution. The launcher cannot create a second live dart.

Snapshots publish immutable trap identity, position, facing, phase and exact
frame. No elapsed renderer time controls attacks.

## Rendering

`TrapRenderRegistry` loads the catalog's explicit source rectangles through the
shared animation loader. `TrapRenderSystem` selects the snapshot frame directly,
mirrors around the catalog anchor and uses the existing camera-space pixel snap.
Idle/cooldown machinery has priority -6; warning/active art has priority -4.
Terrain remains -5 and darts retain projectile priority -1.

Gameplay renders the trap animation and projectiles without colored zones or
exclamation markers. `TrapHitboxOverlay`, under `lib/game/debug`, draws only
exact frame hitboxes when the existing non-release hitbox debug flag is enabled;
it is not mounted in release builds. Its Canvas painter is also used by Chunk
Creator's authoring guides. The default renderer produces no trap overlays in
any phase, verified by pixel tests; sprite frames and layer priorities remain
snapshot-driven.

All three trap sheets join run-start warmup and the game's awaited registry load.

## Chunk Creator

The Traps scene domain owns selection, catalog placement, sprite movement,
independent trigger movement/redrawing/corner resizing, and an inline numeric
inspector. Creation and existing placements use the same collapsible sections
and saved-item cards as the other Chunk domains. Catalog selection does not arm
placement; the explicit Place in scene action does. Scene tools live above the
canvas and snapping controls stay with creation or editing. Facing mirrors the
catalog art/damage preview while retaining the saved trigger. A frame slider
projects exact catalog poses, damage capsules and dart muzzle/path; blue
rectangles are authoring-only activation triggers. Idle/active art is partitioned
around terrain and prefab layers. Geometry guides render after the complete
editor scene only while authoring; Visual preview and Play show trap art without
colored zones or exclamation markers. The catalog's seconds-before-damage label
describes the animation wind-up, not a separate visual warning. Damage and delay
fields sit beneath the creation preview and in the selected placement's inline
editor. Creation values seed the next placement; selecting a different type
restores its catalog defaults. Reset to defaults changes only that local buffer.
For darts, delay is to launch; impact also depends on travel.

Water and traps share `SceneRectangleGesture` for pointer ownership, whole-pixel
or tile-grid snapping, neighbor snapping, movement, resize and chunk bounds.
Each domain retains its own validation and commit policy. Trap previews remain
local until pointer release or Save edit. Damage, delay, anchor, facing and
trigger fields form one local buffer through the shared exact-edit controller
and rectangle editor.
Selection, domain, owner and inspector-collapse changes resolve that buffer with
the shared Save/Discard/Cancel dialog. Shell Save/Play accepts valid input first;
Undo discards pending input before session history and Redo waits for resolution.
The mounted inspector retains its source revision across external document
changes, rejects stale saves and keeps the input visible until discarded.
Duplicate validates a one-tile right offset before adding the copy.
The full Core placement validator checks the candidate before the existing
revision-checked composition command, session Undo/Redo and atomic chunk Save path accept it. Navigation
restores selection by canonical placement value and reconciles against the
current document. No separate trap document or writer exists.

Build fingerprints and watching include `assets/images/entities/traps/**`.
Captured Chunk/Level Play freezes all three sheets and validates their decoded
dimensions against every catalog source region, including dart flight/impact.
The shared codec and materializer preserve traps in unsaved Play captures and
generated patterns. Missing/invalid art blocks Play with a source-path diagnostic.

## Player projectile boundary

`playerEquippableProjectileIds` explicitly retains all eight existing spells,
including Thunder Bolt. The environmental `poisonDart` enum case is appended
only for shared entity/render identity and has no player catalog item. Ownership
decoding/normalization, shop candidates, loadout validation and replay loadout
decoders use the explicit list. Functions derives store offers from its matching
list and rejects invalid learn/equip/purchase commands. A cross-language test
checks parity; no ownership migration is needed.

## Damage attribution and Poison

`TrapSourceRef` is an immutable value containing trap ID, chunk key, stream chunk
index and canonical placement ordinal. `ProjectileStore`, `DamageRequest`,
`DamageQueueStore`, `LastDamageStore` and `DeathInfo` retain it independently of
an attacker entity. Direct traps use `DeathSourceKind.trap`; dart impacts use
projectile kind; subsequent DoT damage uses status-effect kind. No fictional
attacker receives retaliation or attacker-targeted procs.

The accepted dart hit queues `poisonOnHit`: a 200-fixed-point DPS Poison channel
and the existing 2500-basis-point Slow, both lasting 300 ticks at 60 Hz. Poison
uses Acid resistance in both base entity resistance and resolved gear stats.
Its channel pulses at ticks 60/120/180/240/300 after application; no immediate
pulse occurs. Existing immunity, cleanse, ward and damage ordering apply.

The channel stores its own optional trap source. Stronger replacement resets
period phase and attribution. Equal DPS extending remaining duration retains
period phase but replaces attribution. Weaker or nonextending applications
retain the previous source; equal same-tick applications therefore keep the
first source. Generic status requests carry null attribution. Removing channels
or swap-removing an entity also removes the parallel provenance entry.

Snapshots expose a persistent Poison status bit alongside Slow. Flame consumes
it through the existing status tint path, with distinct Poison pulse color.
Game-over text uses the value attribution without looking up a live launcher.

## Pre-live compatibility cutover

Client, Functions ticket/board defaults and validator accept game compatibility
`2026.09.5`. Replay/command format 1 and the ranked rules/score/ghost versions
are unchanged: no replay wire fields changed. This release adds per-placement
damage and animation wind-up to compiled content and simulation. Catalog-default
placements retain their previous behavior; versions through `2026.09.4` cannot
interpret tuned content and are rejected. The existing trap, status and swept
projectile rules remain in effect.

The game is not live. At deployment, stop old ticket issuance and cancel open
disposable test runs. Let in-flight validation/settlement finish, then reset any
remaining disposable run/board state before switching the matching compiled
content, client, Functions and worker. Remove stale supported-version overrides
and use fresh tickets/boards for smoke runs. Cancellation/reset replaces an
old-run migration or a ticket-lifetime wait; it does not bypass lease or
settlement idempotency. Repository implementation does not deploy services or
reset remote state.
