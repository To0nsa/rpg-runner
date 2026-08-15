# Entity Catalog Authoring Strategy

Date: August 15, 2026
Status: Deferred to a separate future work pipeline; Phase 0 safety hardening is
implemented with its repository-wide validation gate still open

Related documents:

- [Phase implementation checklist](entity_catalog_authoring_implementation_checklist.md)
- [Runner Core hardening plan](../../runnerCoreHardening/plan.md) (does not own or
  schedule this editor program)
- [Entities section audit](../../../audit/editor-entities-section-audit-2026-08-15.md)
- [Current entity source-authoring contract](../../../tdd/editor_entity_source_authoring.md)
- [Editor UI system](../../../tdd/editor_ui_system.md)
- [Character stats design](../../../gdd/combat/stats/character_stats_system_design.md)
- [Combat system design](../../../gdd/combat/combat_system_design.md)

## Decision Summary

This entity-creation program is not active. The strategy below is retained as
planning input only and does not authorize implementation, source-format work,
catalog migration, generation, or editor creation UI. A separately authorized
future pipeline must re-audit and rebaseline it before any phase after the
existing safety hardening begins.

The retained proposal envisioned full character, enemy, and projectile
authoring as one **Entity Catalog Authoring** program inside the existing
**Entities** route. A future pipeline may revise or reject that structure; it is
not a current delivery commitment.

The target workflow is data-first:

- strict, versioned repository records become the authoring source of truth;
- one deterministic generator publishes the Dart catalogs and metadata used by
  Core, Flame, UI, and other checked-in consumers;
- the editor writes only authoring records through plugin/store and
  transaction boundaries;
- generated Dart is never edited by the editor or treated as validation input;
- gameplay behavior remains authored code and is selected through supported,
  typed policy or ability references.

The migration will not leave two authorities for the same entity. Current Dart
catalogs remain authoritative until the data-first cutover phase passes semantic
parity and generated-drift gates. At cutover, the affected handwritten catalog
data and AST patch path are removed in the same phase.

Delivery is intentionally staged: harden the existing Entities workflow,
freeze contracts, migrate the source of truth, build shared authoring UX, then
ship projectiles, enemies, and characters as vertical slices. A phase is not
complete until its runtime consumers and validation gates pass.

## Problem Statement

The existing Entities route is a focused source-bound adjustment tool. It can
discover players, enemies, and projectiles and edit collider dimensions,
offsets, selected animation anchor/render-scale values, and caster origin
offsets. It cannot create a complete entity record, configure most gameplay
fields, assign animations through an asset picker, manage identity, or safely
retire an existing record.

Expanding the current AST patcher field by field would scale poorly. A complete
entity currently spans several shapes and consumers:

- ID enums and registries;
- Core character, enemy, and projectile definitions;
- render animation metadata and renderer registries;
- UI display text, selection, icons, and asset preloading;
- level/chunk enemy references and character loadout references;
- replay and run-ticket character/projectile names;
- backend character defaults and ownership state.

The point-in-time Entities audit also found two High-severity write-boundary
risks and recommended hardening before broadening supported source shapes. The
first delivery phase therefore protects the current workflow before more data
is placed under its control.

## Goals

- Let a non-developer create, duplicate, configure, preview, validate, and apply
  supported characters, enemies, and projectiles from the existing Entities
  route.
- Replace manually typed image paths with a repository PNG picker, search,
  dimensions, frame-region configuration, and animation preview.
- Preserve one source of truth for identity, gameplay configuration, animation
  metadata, and presentation metadata owned by the entity catalog.
- Keep Core authoritative for deterministic gameplay rules and keep Flutter and
  Flame out of Core.
- Generate stable, reviewable runtime artifacts with a `--dry-run` drift gate.
- Preserve replay, save, leaderboard, and enum-index compatibility through
  explicit stable identity and ordinal rules.
- Validate cross-catalog references before authoring records can be applied or
  generated.
- Reuse the existing plugin/session, shared toolbar, scene controls, PNG
  discovery, pending preview, and guarded transaction infrastructure.
- Make every implementation phase independently testable and leave the editor
  usable at its completion boundary.

## Non-goals

- Do not draw, paint, rig, or generate art inside the editor. Artwork is
  produced externally and selected from repository-owned asset roots.
- Do not create an ability, weapon, spell-book, status-effect, gear, or AI
  scripting editor as part of this program.
- Do not allow arbitrary Dart expressions or executable behavior to be entered
  through form fields.
- Do not move simulation rules or runtime policy execution into
  `tools/editor`.
- Do not automatically deploy Firebase Functions, the replay validator, or the
  Flutter application from the editor.
- Do not promise that every imaginable enemy or projectile behavior can be
  created without code. The editor composes the supported behavior policies;
  a new policy still requires a normal Core implementation.
- Do not silently rename or delete an applied stable ID that may appear in
  replays, profiles, authored levels, or backend records.
- Do not build a generic asset-management platform. The picker is scoped to
  the entity workflow and reuses repository discovery primitives.

## What “Create From Scratch” Means

Within this program, creating from scratch means an author can:

1. Choose Character, Enemy, or Projectile and create a draft from safe defaults
   or duplicate an existing compatible record.
2. Assign a new stable ID and immutable ordinal before the first apply.
3. Configure every data field supported by that entity type.
4. Select existing repository art and configure animation strips without
   typing a path.
5. Preview animation, origin, facing, scale, and runtime-shaped collision.
6. Resolve required ability, projectile, gear, terrain-policy, proc, tag, and
   other catalog references through selectors.
7. Review deterministic pending files and apply the authoring record.
8. Run the explicit generator and validation workflow to publish playable
   runtime artifacts.

It does not mean that an author can define a new algorithm or create new image
pixels without developer/art-tool work.

## Current Baseline

The existing implementation already provides useful seams that should be
extended rather than replaced wholesale:

- `EntityDomainPlugin` is the single session-facing owner for the route.
- `EntityDocumentPipeline` owns immutable document edits, validation, dirty
  detection, and deterministic scene ordering.
- the Entities page already groups player, enemy, and projectile records and
  presents runtime-shaped collider previews;
- `RepositoryPngCatalog` provides deterministic repository PNG discovery and
  header dimensions;
- `EditorSessionController` provides route-coherent load, undo, redo, pending,
  and apply orchestration;
- `WorkspaceWriteTransaction` is available for guarded multi-file replacement;
- `tool/generated_artifact_plan.dart` provides generated-output drift and
  transactional publication infrastructure;
- `tool/sync_assets.dart` keeps Flutter asset-directory declarations current.

The current source parser reads handwritten Dart across Core and render files.
The existing source patcher is an interim authority only; it is not the target
format for full CRUD.

## Provisional Architecture

The route, typed-facet, behavior-code, and one-authority principles below are
provisional historical planning input. The Runner Core hardening plan will not
choose the entity source syntax or file layout. A future work pipeline may keep,
replace, or discard these proposals after a new decision review.

### One route with typed entity facets

The Entities route remains one plugin-backed workspace with three type filters:
Characters, Enemies, and Projectiles. Shared panels own identity, animation,
presentation, and collider authoring. Type-specific panels own only the fields
that genuinely differ.

The domain model must use typed records/facets instead of one large object whose
meaning depends on dozens of nullable fields. A conceptual shape is:

```text
EntityDocument
├── CharacterRecord
│   ├── Identity
│   ├── Animation + Presentation + Collider
│   └── Character catalog, tuning, loadout references
├── EnemyRecord
│   ├── Identity
│   ├── Animation + Presentation + Collider
│   └── Vitals, body, combat, terrain and behavior-policy references
└── ProjectileRecord
    ├── Identity
    ├── Animation + Presentation + Collider
    └── Motion, lifetime, damage, proc and stat data
```

Shared UI components operate on the shared facets. Stores, validators, and
generators keep type-specific contracts explicit.

### Candidate authoring source of truth

The current candidate is one strict JSON record per entity under:

```text
assets/authoring/entities/characters/*.json
assets/authoring/entities/enemies/*.json
assets/authoring/entities/projectiles/*.json
```

Phase 1 inventories the exact schemas after a complete field/consumer review.
It must not accept the syntax or layout until the upstream Core format prototype
and ADR have passed. The paths above do not authorize a production cutover.
Each record must include at least:

- `schemaVersion` for strict parsing;
- `revision` for semantic authored changes;
- `entityKind`;
- stable `id`;
- immutable `enumOrdinal` where a Dart enum remains part of the runtime
  contract;
- lifecycle state;
- typed gameplay, animation, collider, and presentation sections appropriate
  to its kind.

Files use canonical formatting and deterministic field/list ordering. File
names are derived from stable IDs, collisions are checked case-insensitively,
and normal editor loading accepts only the current schema. Any one-time
migration is an explicit offline command with parity evidence, not a fallback
inside normal loading.

### Generated runtime artifacts

A repository generator compiles the admitted authoring records into the
existing typed runtime surfaces. The exact artifact list is frozen in Phase 1,
but it is expected to cover:

- Core ID enums and catalogs;
- Core animation definitions currently colocated with catalog data;
- Flame/render registry metadata that is purely data;
- UI display metadata that is currently hard-coded by enum switch;
- character availability/default metadata required by Flutter and Firebase
  Functions when a new character must be selectable and runnable.

The generator must use the existing generated-artifact transaction and expose
normal and `--dry-run` modes. Every output carries an ownership marker. A
generated file must not become an input to editor validation.

The editor apply and runtime generation remain separate operations. The UI must
distinguish **authoring saved** from **runtime generated**, show the required
commands, and never claim that a new entity is playable while generated output
is stale.

### Behavior boundary

Data records may select supported typed behavior, targeting, facing, death,
terrain-contact, ballistic, proc, and ability policies. The corresponding
algorithms remain in Core code.

If an author needs a behavior that is not representable by the current policy
catalog, the editor reports that a developer-defined policy is required. It
must not serialize Dart snippets or introduce generic script evaluation.

### Identity and compatibility

Stable IDs are serialized by name in run, replay, ownership, and authored
content flows. Enemy kill counts also currently align with `EnemyId.values`, so
enum order is behaviorally significant.

Therefore:

- an applied ID is immutable;
- an applied ordinal is immutable and never reused;
- generated enum order is ordinal order, not filename or display-name order;
- reserved sentinels such as `ProjectileId.unknown` keep their fixed ordinal;
- new ordinals append unless a documented compatibility migration proves a
  different change safe;
- an applied entity is retired/deactivated instead of physically removed when
  compatibility or references require its identity to remain resolvable;
- uncommitted drafts may be discarded freely;
- duplicate IDs, ordinals, generated Dart symbols, or case-insensitive paths
  are blocking errors.

### References and lifecycle

The editor validates the candidate entity set together with all owned external
references it can load. At minimum this includes abilities, weapons, spell
books, projectiles, statuses/procs, terrain policies, character loadouts,
chunk enemy markers, UI metadata, and backend-known character defaults.

Deletion is reference-aware. For an already applied record, the normal action
is **Retire**, which prevents new selection/spawning while keeping compatibility
data. A destructive removal is allowed only through an explicit migration that
proves no persisted or authored references remain.

### Assets and animation authoring

The asset picker reuses `RepositoryPngCatalog` and restricts each entity kind to
approved roots below `assets/images/entities/**`. It stores runtime-relative
paths in the canonical form expected by the existing asset loader.

For each supported animation key, authors can configure:

- PNG source;
- frame width and height;
- row, start frame, and grid columns where applicable;
- frame count and step time;
- anchor point;
- natural art-facing direction and render scale where owned by the entity.

Validation checks file existence, PNG dimensions, frame bounds, required keys,
positive timing/counts, anchor bounds, and asset-bundle inclusion. The preview
uses the same frame-selection math as runtime. Adding a new asset directory
also requires `dart run tool/sync_assets.dart` and its `--check` gate.

### Persistence and session ownership

`EntityDomainPlugin` remains the only plugin selected by the route. Repository
load, validation, pending plans, and export remain plugin/store responsibilities;
page widgets may own only transient selection, tool mode, viewport, and form
drafts.

Create, duplicate, update, retire, restore, and discard operations are typed
semantic commands. Accepted commands create one session-history entry. Rejected
commands leave the document unchanged and return an actionable diagnostic.

Stores build exact canonical save plans from immutable baselines. Apply uses
`WorkspaceWriteTransaction`, verifies all source baselines immediately before
replacement, verifies installed bytes and reparses the candidate while rollback
is possible, then reloads from installed source. Multi-record changes commit or
roll back together.

## Validation Model

Validation is layered and deterministic:

1. schema and source-loading issues;
2. identity, ordinal, revision, and lifecycle issues;
3. common animation, asset, presentation, and collider issues;
4. type-specific gameplay constraints;
5. cross-record and cross-catalog reference issues;
6. runtime-generation compatibility issues;
7. source-drift, transaction, and installed-output verification issues.

Blocking errors prevent apply and generation. Warnings are reserved for
conditions that remain valid at runtime but deserve author attention; warnings
must never substitute for a missing required reference or invalid deterministic
value.

Editor and generator validation must share pure model/validation code where
possible. Equivalent rules must have parity tests when shared code cannot cross
the tool/package boundary.

## Delivery Phases

### Phase 0 — Existing Entities safety gate

Close or explicitly supersede the open audit findings before expanding the
editable surface. Scalar source bindings, transactional writes, typed outcomes,
asynchronous/cached loading, typed commands, and one change policy form the
safe baseline. Add the focused TDD requested by the audit.

### Phase 1 — Contract inventory and source design

Freeze the complete authorable field matrix, consumer/reference graph, strict
schemas, identity/ordinal/lifecycle rules, generated artifact ownership, and
data-versus-behavior boundary. Prove the design with parser/codec/generator
fixtures before migrating production records.

### Phase 2 — Data-first cutover and generator

Migrate every existing character, enemy, and projectile record to the strict
authoring source, generate semantically identical runtime catalogs, rewire the
current collider/preview workflow to the new store, and remove the superseded
AST catalog patch authority. Preserve deterministic behavior with semantic and
replay-sensitive parity tests.

### Phase 3 — Shared entity workspace and visual authoring

Add typed CRUD/lifecycle commands, shared identity and animation panels,
repository asset picking, runtime-faithful animation/collider previews,
candidate reference selectors, deterministic pending summaries, and coherent
draft/undo/reload behavior. Type-specific full editing remains gated until its
vertical slice is complete.

### Phase 4 — Projectile vertical slice

Expose every supported projectile gameplay and render field, replace remaining
hard-coded projectile display metadata, validate procs/status/stat references,
and prove that a newly authored projectile generates, renders, and executes
deterministically through a focused runtime fixture.

### Phase 5 — Enemy vertical slice

Expose every supported enemy archetype, animation, terrain-contact, and policy
field; make chunk marker selection consume the generated enemy catalog; replace
hard-coded presentation names where required; and prove a newly authored enemy
can be placed, spawned, navigated, fought, scored, and rendered using supported
policies.

### Phase 6 — Character vertical slice

Expose character identity, catalog, tuning, animation, loadout, and ownership
defaults. Generate or otherwise single-source the Flutter and Firebase
character metadata required for selection and authenticated runs. Prove a new
character can be selected, started, replayed, validated, and projected without
manual catalog edits.

### Phase 7 — Lifecycle, integration, and release closure

Finish reference-aware retire/restore behavior, cross-domain diagnostics,
publication guidance, usability and performance passes, full cross-layer
validation, durable TDD/GDD/README/AGENTS updates, and removal of all temporary
migration seams. Archive this plan only after the from-scratch acceptance paths
pass from a clean checkout.

The detailed, evidence-tracked tasks and exit gates live in the linked
implementation checklist.

## Program Acceptance Criteria

The program is complete only when all of the following are true:

- one Entities route authors all three supported entity kinds without
  duplicated persistence paths;
- a new author can create each kind without typing an image path or editing
  Dart catalog data;
- all existing entities survive the source migration with proven semantic
  parity;
- generated artifacts are deterministic and `--dry-run` reports no drift;
- stable IDs and ordinals preserve replay/save compatibility;
- a new projectile executes and renders in a deterministic test run;
- a new enemy can be placed in authored content and completes its supported
  runtime lifecycle;
- a new character can complete the authenticated client/backend/replay flow;
- invalid assets, missing references, source drift, and transaction failures
  block safely with actionable feedback;
- applied identities can be retired without corrupting persisted references;
- analyzer and relevant editor, Core, Flutter, Functions, protocol, and replay
  validator tests pass;
- implemented behavior is documented in durable TDD/GDD documentation and this
  active plan is archived.

## Planning and Progress Rules

The [implementation checklist](entity_catalog_authoring_implementation_checklist.md)
is the progress ledger for this program.

- Check an item only after its implementation and stated evidence exist.
- Record completion dates and validation results in the checklist as phases
  advance.
- Update this strategy before implementing a material ownership, schema,
  lifecycle, or scope change.
- Add newly discovered work to the owning phase rather than hiding it in an
  untracked TODO.
- A checked phase exit gate means no required work remains in that phase.
- Proposed behavior stays in `docs/building/**`; durable TDD/GDD documents are
  updated only when the corresponding behavior is implemented.
