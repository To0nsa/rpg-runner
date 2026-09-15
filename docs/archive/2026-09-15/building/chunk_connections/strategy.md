# Chunk connections and three terrain heights

Status: Complete in the repository. Deployment remains a separate drain-and-switch operation.

Date: September 15, 2026.

## Outcome

Authors can create a chunk that ends above the normal ground, create a matching
successor directly from it, and assemble a level that chooses only compatible
chunks. The first release includes **Create connecting chunk**, three standard
ground elevations, connection previews, and scheduler validation across the
complete level flow.

Example:

```text
Normal -> uphill -> Raised -> uphill -> High -> downhill -> Raised -> downhill -> Normal
```

The words Normal, Raised, and High describe terrain elevation. They are separate
from the existing Early/Easy/Normal/Hard difficulty settings; the editor must
label elevation and difficulty explicitly wherever both appear.

This strategy tracks the authorized implementation. Reuse the existing editor cards, forms, navigation guards, and Undo/Save workflows. Current behavior remains described
in the linked TDD/GDD documents until each milestone is delivered. This document
contains the workstream's single implementation checklist.

## Current implementation and change points

| Area | Implemented behavior | Required change |
| --- | --- | --- |
| [Chunk selection](../../../../../packages/runner_core/lib/track/chunk_pattern_source.dart) | Seeded selection resolves difficulty, group, section length, and distinctness. It does not choose using the previous terrain edge. | Select among matching chunks that permit a valid continuation. |
| [Scheduler analysis](../../../../../packages/runner_core/lib/collision/terrain/terrain_authoring_scheduler.dart) | Enumerates scheduler-reachable pairs without RNG, including section transitions and the continuing Hard tail. | Analyze scheduling states with terrain compatibility and remaining choices. |
| [Boundary comparison](../../../../../packages/runner_core/lib/collision/terrain/terrain_boundary_signature.dart) | Compares exact physical coverage and continuation points. Material differences are retained as visual evidence. | Reuse this authority to derive connections. |
| [Repository compilation](../../../../../packages/runner_content_pipeline/lib/src/polygon_terrain_repository_generation.dart) | Compiles geometry, enumerates scheduler pairs, then rejects incompatible seams. | Derive compatibility before schedule admission and publish the admitted result consistently. |
| [Chunk seam analysis](../../../../../tools/editor/lib/src/chunks/chunk_v2_seam_analysis.dart) | Wraps Core boundary and scheduler results for editor validation. | Expose matches, usable continuations, and actionable failures from the shared rules. |
| [Starter creation](../../../../../tools/editor/lib/src/chunks/chunk_level_target.dart) | Creates flat terrain at the Level ground reference through a retained intent and plugin command. | Extend the creation pattern to matching entrances and selected exits. |
| [Level workspace](../../../../tdd/editor_level_workspace.md) | Contents, Flow, Appearance, seeded samples, and guarded Chunk handoffs already exist. | Add connection status and repair actions to these surfaces. |
| [Chunk Play](../../../../../packages/runner_core/lib/playtest/chunk_playtest_scenario.dart) | Builds a focused path with a repeating tail from scheduler transitions. | Construct a valid witness through scheduling states, including distinctness and elevation. |

The current physical seam rule is stricter than equal ground height. It compares
solid coverage, collision modes, and continuation surface kinds at exact Y
coordinates. Equal empty boundaries are also compatible. Reuse these rules;
neither a height label nor equality of the entire evidence digest is a substitute
for physical comparison.

Related implemented contracts:
[terrain authoring](../../../../tdd/polygon_terrain_authoring_foundation.md),
[content pipeline](../../../../tdd/runner_content_pipeline.md),
[Core construction](../../../../tdd/runner_core_simulation_contract.md),
[authored Play](../../../../tdd/editor_chunk_playtest_host.md), and
[level composition](../../../../gdd/level_composition.md).

## Chosen approach

Three approaches were considered:

| Approach | Benefit | Limitation |
| --- | --- | --- |
| Dedicated uphill/elevated/downhill groups in ordered Flow | Uses the current assembly model. | Requires separate groups and manual sequencing for every terrain transition. |
| Manually assigned entrance/exit height tags | Easy to filter and display. | Tags can disagree with geometry and cannot describe platforms or multiple boundary intervals. |
| Derived physical connections plus three authoring presets | Reuses exact geometry, supports random variation, and makes creation predictable. | Requires schedule analysis that prevents future dead ends. |

Use derived physical connections plus three presets. Groups continue to organize
content such as grove, ruins, or camp. Compatibility is an additional selection
constraint, applied after the authored group and difficulty rules.

## Elevation contract

### Three standard elevations per Level

Use the existing `groundTopY` as Normal. Store one positive whole-pixel elevation
step in the Level source; the proposed field name is `terrainHeightStepPx`.

| Elevation | Height above Normal | World Y |
| --- | --- | --- |
| Normal | 0 | `groundTopY` |
| Raised | one step | `groundTopY - terrainHeightStepPx` |
| High | two steps | `groundTopY - 2 * terrainHeightStepPx` |

World Y increases downward. Presets must remain representable on the existing
authoring and Core physics grids. Choose the numeric step during milestone 1
using camera, character, jump, and slope evidence; example values discussed in
conversation are not accepted tuning constants.

The presets apply to the main ground at chunk entrances and exits. Interior
slopes, dips, platforms, ceilings, and obstacles remain freely authored.
Existing custom and compound boundaries remain supported by exact comparison;
show their actual profile instead of assigning an inaccurate preset label.
This avoids turning the three convenient ground presets into a restriction on
every collision vertex in the level.

The default creation choices are same-height or one-step transitions. A direct
Normal-to-High or High-to-Normal transition can be deliberately authored, with
the same geometry checks and playtesting as other terrain.

### Ownership and later changes

Level settings own the step. The Chunk canvas shows the three guides and the
actual world Y values. Entrance/exit labels are derived from compiled geometry;
do not persist a second set of height tags on each Chunk.

Authored polygon coordinates remain absolute within the existing chunk space.
Changing a preset value changes the guides and future starter creation. It must
not silently move existing terrain, Prefabs, markers, or water. Before saving a
step change, show which existing edges will no longer correspond to a preset.
They retain their geometry and physical matches. Automatic reshaping of existing
chunks is outside this release.

Define an explicit current-schema Level migration when introducing the required
field. Migrate existing Levels without changing terrain coordinates or IDs, and
update every Level parser, copy/create flow, serializer, and source fixture.
Do not add normal-runtime legacy parsing. Chunk schema changes are needed only
if the implementation introduces persisted Chunk data beyond existing polygons.

## Editor workflow

### Connections in Chunk Creator

Add a Connections section to the chunk-level inspector. Clicking the left or
right boundary on the canvas opens the corresponding side. Keep polygon-edit
controls with the selected polygon, and use the existing workspace and scene
input conventions.

The panel shows entrance and exit elevation summaries, a small boundary profile,
and Previous chunks / Next chunks. For a selected side, show:

- **Terrain matches:** active chunks in this Level whose opposite physical edge
  matches. This is a geometry result, independent of Flow placement.
- **Available in Flow:** matching chunks with a valid continuation in the
  selected section or sampled occurrence. Without an occurrence, state which
  section contexts the result covers; do not imply a chunk is always eligible.
- **Excluded:** the concrete reason, such as difficulty, group, already used in
  this section, or no route through the remaining section.

Choosing Preview renders the neighbor beside the current chunk, faded and
read-only, at its actual position. Highlight the shared boundary and any mismatch
when inspecting a rejected candidate. Opening the neighbor uses existing guarded
navigation and returns to the original selection and view.

### Create connecting chunk: included in the first release

The first release creates a successor from the selected chunk's right edge.
Previous-chunk inspection is included; reverse creation can follow later.

1. Accept valid visible input and capture the selected chunk, compiled exit,
   Level presets, and source dependencies from the current session.
2. Open a creation form with the matching entrance read-only. Default the exit
   to the same elevation; offer adjacent elevation choices with arrow previews.
3. Collect a fresh chunk name/key, group, and difficulty. Use the target Flow
   section when launched from its repair action; otherwise default to the
   current chunk's group and difficulty. Use the Level's runtime chunk width.
4. Preview both chunks together. Generate ordinary flat or ramped ground,
   retaining compatible solid depth and surface semantics. Reuse the entrance
   material when available and validate its authored resources.
5. Compile the proposed successor and compare its full entrance profile with
   the captured exit. A height-only match cannot enable Create.
6. Create one ordinary authored Chunk through a domain command with one Undo
   step. Open it for editing; Save uses the existing store and write transaction.

```text
Create connecting chunk

Entrance elevation: Raised (matched from current chunk)
Exit elevation:     [Normal, descending] [Raised, flat] [High, ascending]
Group:              rocky_grove
Difficulty:         Easy

[Joined terrain preview]
[Cancel]                                      [Create]
```

For the initial generator, support the ordinary single solid ground profile
that can be continued exactly as a flat or ramped polygon. Give ramps short
level landings at their ends and validate available width and supported slope.
The complete entrance comparison remains the final authority, including the
lower extent of the solid interval.

Compound, open, off-preset, or one-way-only boundaries need an explicit outcome:
show the exact profile and offer manual authoring with a boundary guide when
the starter cannot reproduce it. Never flatten away additional collision or
claim an automatically matching starter was created. General synthesis of
arbitrary boundary geometry is outside the first starter's scope.

Reserve a fresh identity once per creation intent and retain it across retries;
do not reuse an unrelated existing starter. Capture the predecessor's geometry
and dependency fingerprints. Recheck them before Create, and require a refreshed
preview if they changed. Cancellation leaves no new owner. After creation, the
successor is independently authored: later predecessor edits update diagnostics,
not the successor's geometry.

### Level Creator integration

Add the three elevation settings/guides to Level settings. Contents can show
derived entrance/exit summaries and a filter for chunks matching a selected edge.
Flow retains Automatic / Ordered sections, existing counts, difficulty, and
distinctness controls.

Each Flow section shows schedule readiness. Diagnostics identify the affected
section, chunk, and connection, for example:

> This section can reach High, but its remaining unused chunks cannot return
> to an entrance available in the next section.

Provide Inspect connection, Edit chunk, and Create connecting chunk actions.
Creation can resolve missing content but does not automatically change section
order, length, difficulty, or group membership of existing chunks.

Extend the existing sample preview with joined terrain and selectable seams.
Sampled explanations come from the same selection result as gameplay. Sampling
demonstrates a seed; complete schedule validation establishes readiness.

Preserve operation-aware admission: malformed source blocks Save; incomplete
connections or schedules permit Save and block affected Play and included Build.
An active chunk unreachable in every valid schedule receives an actionable
unused-content diagnostic. Its mere presence should not invalidate an otherwise
valid Level, but focused Chunk Play must explain why it cannot reach that chunk.

## Scheduler strategy

### Compatibility before selection

Compile each chunk once, derive its physical boundary profiles, and build a
directed compatibility relation within the Level. Index by canonical physical
profile to avoid comparing every pair unnecessarily. Full comparison and
collision semantics remain owned by Core; names, materials, and elevation labels
do not override them.

The pipeline then supplies compiled facts and authored schedule settings to Core
analysis. Runtime and authored Play consume the same admitted selection model.
Keep artifact signatures tied to geometry, active membership, schedule settings,
and the selection contract. Continue validating every transition the admitted
scheduler can emit; incompatible candidates omitted by the scheduler are normal
exclusions, not global seam errors.

### Prevent future dead ends

A graph of chunk pairs is insufficient. A choice can match immediately yet
leave too few unused chunks or an impossible next section. Model the scheduling
state with the previous exit profile, section/phase, remaining count, progression
position while tiers change, and used chunk identities when distinctness applies.

Compute the states from which a valid continuation exists. At a chunk-selection
state, retain choices leading to another valid state. At a section-length choice,
require continuation for **every authored length in the range**; retain the
existing seeded length distribution instead of silently dropping impossible
lengths. An unsatisfiable configured range blocks Play/Build with the failing
length and entry context.

Handle the finite Early/Easy/Normal prefix and the continuing tail explicitly.
For repeated sections and the final continuing section, remove states that cannot
continue indefinitely until the valid set stops changing. This must include
distinctness resets at section boundaries and all permitted future length
choices. A chunk-level cycle or a fixed lookahead depth is not sufficient proof.

Resolve the existing difficulty fallback policy before compatibility filtering.
An exact difficulty never falls back. An Automatic pool with no viable matching
continuation reports a scheduling failure; it does not gain an extra fallback
because its terrain is incompatible.

Start with a bounded exact implementation and measure its state count, analysis
latency, memory, and artifact size. Distinctness can make the state space grow
rapidly even with only three ground heights. Reuse equivalent physical profiles,
memoized states, and compact identity sets. Define deterministic capacity errors;
exceeding a supported analysis budget blocks runtime admission instead of
substituting sampled evidence. The existing 256-chunk finite-prefix bound is
background evidence, not a proven limit for the new analysis.

### Determinism and consumption

Rank viable choices using Core's seeded facilities with stable chunk identity
tie-breaks. Specify length and selection salts and ordering as part of the new
simulation contract. Equal seed, content, and schedule must produce equal chunks
regardless of map order, preview calls, cache state, or preparation timing.

Selection currently accepts a chunk index. The new dependence on previous
choices requires a deterministic replay/checkpoint policy for repeated and
out-of-order queries, seed changes, prewarming, and long streamed runs. Select a
bounded cache policy during milestone 1; do not add an unbounded chunk-history
cache or make sampling mutate the live source.

Focused Chunk Play must carry a witness through full schedule states. A path
assembled from individually reachable pairs can violate distinctness or section
ordering. Preserve its tooling-only boundary and explain when the selected
chunk has no reachable valid witness. Include a valid opening and any required
climb before reaching an elevated selected chunk, with support at the actual
playtest spawn position. Do not place the player at Normal inside raised solid
ground or translate the terrain to disguise the mismatch. Whole-Level Play and
seeded samples use the actual level schedule.

## Spawn, framing, and gameplay checks

The normal player spawn uses the Level ground reference. Initially require the
official first chunk to provide Normal ground and valid support/clearance at the
actual spawn X; an entrance label alone cannot prove this. Apply the requirement
to automatic openers and pinned first chunks, while preserving first-slot pool
eligibility and distinctness.

Core currently has a 600 by 270 virtual viewport and supports both locked and
following vertical camera modes; default tuning locks Y. Choose preset spacing
for the existing framing first. Verify both playable characters, their relevant
jumps/mobility, and headroom at High. Include enemy support, marker placement,
projectiles, water, parallax, and the existing kill plane in the visual/gameplay
pass. Do not infer a new camera mode or move the kill plane from a chunk's height.

If useful spacing requires camera changes, record and implement that dependency
before accepting the height preset milestone. Arbitrary interior geometry still
requires gameplay testing. UI wording must distinguish Matching connection,
Valid schedule, and actual successful playtesting.

## Ownership, migration, and release

| Owner | Responsibility |
| --- | --- |
| `runner_core` | Physical comparison, schedule state transitions, continuation analysis, deterministic selection, and Play scenario admission. |
| `runner_content_pipeline` | Compile captured source and materialize the matching Core facts/artifacts used by generator and editor. No repository I/O. |
| Root `tool/` | Strict Level schema migration, generation orchestration, signatures, and coordinated generated output writes. |
| Editor Level domain | Elevation preset settings, Flow settings, persistence, reconciliation, and dependency refresh. |
| Editor Chunk domain | Connecting-starter intent, geometry generation, canonical validation, identity allocation, Undo, and Save. |
| Editor pages | Connection presentation, neighbor previews, forms, and guarded navigation using immutable domain results. |
| App and replay worker | Consume matching Core/content releases and preserve ticket compatibility enforcement. |

Update source models, compilation, generated data, authored Play, runtime, and
editor consumers together. Keep one canonical selector and one current schema;
retire superseded production selection/analysis paths in the cutover. Generate
Core/Game outputs through the existing generator.

The selection change affects replay outcomes even when polygon coordinates are
unchanged. Use the existing game-compatibility mechanism and coordinate client,
Functions issuance/allowlists, boards, ghosts, and validator rollout. Current
compatibility labels do not automatically select different Core implementations.
Define an actual policy for in-flight old tickets before release: drain them on
the matching old deployment before switching, or provide explicitly supported
version routing. Merely accepting both labels against new selection is unsafe.
Do not change replay encoding unless its payload needs to change.

Update implemented TDD/GDD documents at delivery, including terrain authoring,
content pipeline, Core simulation, Level workspace, authored Play, and level
composition. Add a focused terrain-elevation GDD if needed. Update replay/rollout
docs where compatibility handling changes and the editor README for the new
workflow. Update layer AGENTS only where ownership or working rules change.

## Implementation checklist and acceptance gates

Milestones 1 through 6 are implemented. See [validation evidence](validation.md)
and the current [technical contract](../../../../tdd/chunk_connections.md).
The deployment policy is documented; no production deployment was performed.

- [x] **1. Prove the height and scheduling contracts.** Select and record numeric
  step limits from camera/slope/spawn fixtures. Prototype exact continuation
  analysis with variable lengths and distinctness; record capacity and runtime
  cache policy. Confirm ordinary starter boundary shapes. Acceptance: Normal,
  Raised, and High are usable with current framing, and the algorithm correctly
  admits a repeating hill route and rejects a future dead end.
- [x] **2. Implement canonical compatibility and selection.** Integrate compiled
  profiles, complete scheduling states, deterministic choice, generated artifact
  admission, and both Play factories. Replace the previous production selection
  path coherently. Acceptance: all selected seams match, every admitted choice
  retains continuation, and preview/runtime/validator fixtures agree across
  section transitions and repeated queries.
- [x] **3. Deliver elevation presets and Create connecting chunk.** Add strict
  Level migration, settings/guides, starter intent, joined preview, full entrance
  verification, canonical creation, and Undo/Save. Acceptance: an author can
  create Normal-to-Raised, Raised-to-High, and descending successors without
  manually entering matching entrance coordinates; cancellation, retry, source
  drift, and unsupported profiles produce the specified outcomes.
- [x] **4. Deliver connection inspection and Flow repair.** Add the Connections
  panel, read-only neighbors, occurrence-aware availability, actionable Flow
  diagnostics, and seeded preview explanations. Acceptance: an author can find
  why a matching chunk is unavailable, create the missing successor, and return
  to the same Flow context with refreshed results.
- [x] **5. Verify the complete authoring and gameplay loop.** Exercise the
  fixtures below, measure analysis and long-run selection, and complete the
  relevant repository checks. Acceptance: no admitted sequence dead-ends, starter
  geometry plays correctly, incomplete work saves safely, and generated content
  matches authored Play and replayed outcomes.
- [x] **6. Complete release compatibility and documentation.** Record the actual
  rollout/drain policy, validate cross-layer compatibility changes, regenerate
  outputs, and update implemented TDD/GDD/README guidance. Acceptance: released
  tickets validate with the matching Core/content and every first-release
  capability above is delivered. Archive this completed plan and update links.

### Required fixtures

| Fixture | Expected evidence |
| --- | --- |
| Normal-only level | Remains playable through the new selector; any intentional seed-order change is versioned. |
| Normal -> Raised -> High -> Raised -> Normal | Starters match exactly; seeded selection can repeat the route indefinitely. |
| Matching height, different solid depth/collision semantics | Rejected as a physical match with exact mismatch evidence. |
| Material-only difference | Physically compatible; visual join remains inspectable. |
| Matching successor followed by a dead end | Unsafe choice excluded before selection; no valid opener blocks admission. |
| Distinct section with enough total chunks but no valid ordering | Reports the blocked schedule, including the used identities/context. |
| Variable length with one impossible configured count | Entire configured range rejected; length distribution is not silently narrowed. |
| Difficulty transition inside a section | Correct exact/fallback pools and used identities carried across the transition. |
| Repeat all and continue last | Repeated-state continuation proven with distinctness reset and valid seams. |
| Automatic or pinned opening at wrong height/unsupported spawn | Clear opening diagnostic before gameplay. |
| Compound/open/custom boundary starter request | Accurate profile shown; unsupported synthesis routes to manual authoring without a false match. |
| Create, cancel, retry, Undo, Save, source conflict, preset change | Stable fresh identity, no unintended writes, refreshed previews, and no silent terrain movement. |
| Reordered source input, repeated/out-of-order queries, seed reset | Equal results for equal inputs; bounded cache behavior over long runs. |
| Analysis capacity exceeded | Reproducible runtime-readiness error; no sampled success substituted. |
| Client/editor/worker same seed and commands | Equal selected chunks and replayed outcomes under the same compatibility release. |

### Validation commands during implementation

Run checks for the owning milestone; the final integration gate covers all
changed layers. Resolve workspace dependencies at the root. The editor and
validator retain their independent package resolutions.

```powershell
dart analyze packages/runner_core
Push-Location packages/runner_core
dart test
Pop-Location

dart analyze packages/runner_content_pipeline
dart test packages/runner_content_pipeline/test

dart run tool/generate_chunk_runtime_data.dart --dry-run
flutter test test/tool/level_definition_generation_test.dart
flutter test test/tool/generate_chunk_runtime_data_test.dart
flutter test test/core

Push-Location tools/editor
dart analyze
flutter test
Pop-Location

dart analyze services/replay_validator
dart test services/replay_validator/test
```

Add focused coverage to the existing boundary, scheduler, seam, Play-scenario,
editor creation/flow, and generator test suites. Run app/Game analysis and tests
when their source or generated contracts change. Run `corepack pnpm --dir
functions build` and `corepack pnpm --dir functions test` for compatibility
backend changes; run protocol analysis/tests if shared wire contracts change.
Record unavailable checks and unresolved failures before marking a milestone
complete.

## Delivered decisions

Implementation and relevant integration checks are complete. The existing
prefab-warning assertion on uncommitted source is recorded in the evidence; it
passes against committed assets. Release operators must complete the documented
drain before deploying this compatibility change.

Current implementation decisions:

- Level schema v3 requires `terrainHeightStepPx`; the explicit migration accepts
  canonical v1/v2 sources and preserves geometry, IDs, and inclusion.
- Default step is 24 px, maximum 32 px. High is 48 px above Normal by default.
  The generated ramp has 64 px landings and a maximum 1:1 slope. Gameplay
  acceptance passed for both characters at the default and maximum step.
- Exact admission has a 32,768-state / 262,144-edge budget. Every authored
  section length must retain an infinite continuation. Capacity is a blocker.
- Stable key order and `mix32` salts `0x27d4eb2d` (length) and `0x85ebca6b`
  (choice) define the new selection contract. Runtime cursors retain only the
  latest state/selection; older queries replay from the opening.
- Connections reuse `EditorSectionCard`, existing forms and composition previews.
  The card starts collapsed to preserve the existing library layout; the Ground
  heights toggle lives with the connection controls to fit smaller windows.
- No deployment is included in this repository implementation. Rollout/drain
  instructions and compatibility gates must be complete before release.
