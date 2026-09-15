# Entity Catalog Authoring Implementation Checklist

Date: August 15, 2026
Status: Deferred to a separate future work pipeline; Phase 0 safety hardening is
implemented with broad validation pending, and Phases 1-7 must not start

Strategy: [Entity Catalog Authoring Strategy](entity_catalog_authoring_strategy.md)

Boundary reference:
[Runner Core Hardening Plan](../../runnerCoreHardening/plan.md). That plan does
not own, schedule, or authorize the deferred editor phases below.

This checklist is the live implementation record. Check items only when the
code, tests, and documentation named by the item exist. Add dated evidence to
the phase notes when a phase is completed or its scope materially changes.

## Phase Status

| Phase | Outcome | Status |
| --- | --- | --- |
| 0 | Existing Entities safety gate | Implementation complete; repository-wide editor validation blocked by unrelated worktree errors |
| 1 | Contract inventory and source design | Deferred; separate future pipeline |
| 2 | Data-first cutover and generator | Deferred; separate future pipeline |
| 3 | Shared entity workspace and visual authoring | Deferred; separate future pipeline |
| 4 | Projectile vertical slice | Deferred; separate future pipeline |
| 5 | Enemy vertical slice | Deferred; separate future pipeline |
| 6 | Character vertical slice | Deferred; separate future pipeline |
| 7 | Lifecycle, integration, and release closure | Deferred; separate future pipeline |

The unchecked Phase 1-7 tasks are retained planning input, not accepted design
or queued work. A separately authorized future pipeline must re-audit and
rebaseline them before implementation.

## Phase 0 — Existing Entities Safety Gate

### Entry gate

- [x] Reconfirm the open findings in the August 15, 2026 Entities audit against
  the implementation baseline used for this phase.
- [x] Confirm overlapping user changes in `tools/editor` and agree on the exact
  files owned by this phase before editing.

### Persistence hardening

- [x] Replace player collider multi-node range bindings with per-scalar
  expression bindings.
- [x] Replace projectile collider multi-node range bindings with per-scalar
  expression bindings.
- [x] Preserve interleaved arguments, comments, formatting, and unrelated
  expressions byte-for-byte outside edited scalar ranges.
- [x] Move persistent `.bak` and source replacements into one
  `WorkspaceWriteTransaction` artifact set.
- [x] Verify every planned source baseline in `beforeReplace` immediately
  before any target replacement.
- [x] Verify installed source bytes and reparse the changed definitions while
  rollback remains possible.
- [x] Distinguish rollback failure, applied-but-cleanup-required, normal no-op,
  validation failure, drift, and successful apply through typed outcomes.
- [x] Show immediate and consistent Apply failure feedback through the shared
  toolbar/page contract.

### Domain and interaction hardening

- [x] Decode entity update commands into a typed update value and reject
  malformed or mixed-validity payloads deterministically.
- [x] Introduce one domain-owned numeric comparison/change-set policy used by
  gestures, dirty detection, pending planning, and export.
- [x] Move repository reading and Dart parsing off the UI interaction path.
- [x] Resolve and cache asset availability per loaded workspace/document rather
  than checking the filesystem during widget build.
- [x] Keep the existing collider, anchor, cast-origin, history, and pending
  behavior unchanged for valid edits.

### Tests and documentation

- [x] Add player and projectile preservation regressions with reordered fields,
  interleaved unrelated arguments, and comments.
- [x] Add final-drift and first/middle/last replacement failure tests.
- [x] Add existing-backup, verification-failure, rollback, and cleanup-state
  tests.
- [x] Add controller/widget coverage for a failed shared-toolbar Apply.
- [x] Add malformed-command and epsilon-boundary coverage across gesture,
  document, pending, and export paths.
- [x] Add scene pointer-cancel, hit-testing, coalesced-undo, and local-draft
  lifecycle coverage identified by the audit.
- [x] Create a focused `docs/tdd/**` contract for current entity source binding,
  optimistic concurrency, backups, transactions, and export outcomes.
- [x] Update the Entities audit statuses with dated implementation evidence.

### Validation

- [x] Run `cd tools/editor && dart analyze`.
- [x] Run the focused entity editor tests.
- [ ] Run `cd tools/editor && flutter test`.

### Exit gate

- [x] Both High and both Medium audit findings are closed or are removed by an
  already-landed replacement with equal or stronger evidence.
- [x] No current valid entity edit can delete unrelated source or partially
  commit a multi-file apply.
- [ ] The current Entities route remains usable and all phase validation passes.

### Evidence and notes

- August 16, 2026: completed the bounded safety implementation without adding
  entity creation or broader catalog fields. Added scalar source bindings,
  transactional Apply, typed outcomes/updates, shared change policy,
  isolate-backed parsing, and immutable asset-availability snapshots.
- August 16, 2026: focused parser/export, document, controller, shared-toolbar,
  scene interaction, local-draft, and existing entity tests pass. Full editor
  suite reached 432 passing tests but could not pass because unrelated active
  Chunk/terrain/Prefab work introduced a Chunk v2 syntax error, a missing
  terrain reducer method, and missing non-entity controls. The full-suite and
  final exit check remain open until that separate worktree state is coherent.

## Phase 1 — Contract Inventory and Source Design

### Current-contract inventory

- [ ] Inventory every field in `PlayerCharacterDefinition`, `PlayerCatalog`,
  `PlayerTuning`, and their nested deterministic types.
- [ ] Inventory every field in `EnemyArchetype`, animation/terrain profiles,
  and supported enemy policy enums.
- [ ] Inventory every field in `ProjectileItemDef`, projectile render metadata,
  stats, and proc references.
- [ ] Map every character, enemy, and projectile ID consumer across Core,
  Flame, Flutter UI, authored levels/chunks, protocol/replays, replay validator,
  and Firebase Functions.
- [ ] Classify every field as authored data, derived data, generated metadata,
  typed policy reference, external catalog reference, or developer-owned code.
- [ ] Record hard-coded enum switches and lists that would block a new generated
  ID from compiling or behaving generically.

### Identity and lifecycle contract

- [ ] Define stable ID grammar and case-insensitive path/symbol collision rules.
- [ ] Define immutable `enumOrdinal` rules for characters, enemies, and
  projectiles, including the fixed projectile sentinel.
- [ ] Freeze the current ordinal assignments before any generated enum replaces
  handwritten order.
- [ ] Define revision semantics for create, duplicate, edit, retire, and restore.
- [ ] Define draft discard, pre-apply ID correction, post-apply immutability,
  retirement, restoration, and exceptional destructive migration behavior.
- [ ] Identify all persisted/protocol surfaces that make ID removal or enum
  reorder unsafe.

### Source contract and generation design

- [ ] Consume the accepted Core source-format ADR before choosing an entity
  directory layout or codec.
- [ ] Define strict current source contracts for common facets and all three
  typed records without a nullable catch-all model.
- [ ] Define canonical source ordering, numeric formatting, filename allocation,
  revision, and schema-version rules for the accepted format.
- [ ] Define the complete generated artifact plan and ownership markers.
- [ ] Decide whether the entity generator is a focused command composed by a
  root content command or an extension of the existing root generator.
- [ ] Define normal and `--dry-run` behavior using
  `GeneratedArtifactPlan`.
- [ ] Define semantic parity fixtures that compare migrated source with current
  runtime definitions without treating old Dart as a permanent authority.
- [ ] Define how generated character metadata reaches Firebase Functions while
  preserving backend authority and avoiding manual duplicate lists.
- [ ] Define how asset-bundle inclusion and `tool/sync_assets.dart --check`
  participate in validation.

### Behavior and reference contract

- [ ] List supported behavior policies available to enemy/projectile records.
- [ ] Define the failure shown when an author needs an unsupported code policy.
- [ ] Define reference catalogs and selector sources for abilities, weapons,
  spell books, projectiles, statuses/procs, gear stats, terrain policies, tags,
  and loadout defaults.
- [ ] Define candidate cross-reference validation order and stable issue codes.
- [ ] Define how retired targets behave when referenced by historical versus
  newly authored content.

### Prototype and durable design documentation

- [ ] Implement isolated strict-codec fixtures for one representative record of
  each entity kind.
- [ ] Prove deterministic parse/serialize round trips and case-insensitive path
  collision rejection.
- [ ] Prove ordinal-sorted enum generation and generated-symbol collision
  rejection.
- [ ] Prove the generator can represent all current complex animation layouts,
  including row, frame-start, and grid-column variants.
- [ ] Create the focused entity catalog authoring TDD with source ownership,
  schemas, generation, references, lifecycle, and determinism invariants.
- [ ] Update the strategy and this checklist if the prototype changes a chosen
  boundary.

### Exit gate

- [ ] Every current field and consumer has one documented target owner.
- [ ] No authorable field requires arbitrary code serialization.
- [ ] The schema and generator prototype represents all existing entity shapes.
- [ ] Identity, ordinal, lifecycle, and cross-layer character rules are
  approved and frozen for implementation.

### Evidence and notes

- Pending.

## Phase 2 — Data-First Cutover and Generator

### Authoring models and stores

- [ ] Add strict common and type-specific source models under a bounded editor
  or shared pure-Dart package location chosen in Phase 1.
- [ ] Add canonical codecs for character, enemy, and projectile records.
- [ ] Add deterministic directory discovery, stable ordering, and
  case-insensitive filename collision checks.
- [ ] Add immutable source baselines, fingerprints, candidate documents, and
  save plans.
- [ ] Add validation/export gating and rollback-safe multi-file apply through
  `WorkspaceWriteTransaction`.
- [ ] Rewire `EntityDomainPlugin` to load and validate the new authoring records.
- [ ] Preserve the existing scene/collider workflow against the new document
  model before adding more editable fields.

### Migration

- [ ] Build an explicit offline migration command that reads the complete
  current Dart definitions and writes candidate authoring records.
- [ ] Make check mode the default and require an external evidence report for
  any write mode.
- [ ] Record source fingerprints, target paths, identity/ordinal mappings, and
  semantic before/after signatures.
- [ ] Reject partial, mixed-generation, stale, or ambiguous source layouts.
- [ ] Migrate all checked-in characters, enemies, and projectiles in one
  reviewed cutover.
- [ ] Verify every migrated gameplay, animation, presentation, and reference
  value against the frozen inventory.

### Runtime generator

- [ ] Generate stable character, enemy, and projectile ID surfaces with frozen
  ordinals.
- [ ] Generate Core catalogs and animation definitions from admitted records.
- [ ] Generate Flame/UI data-only registries identified in Phase 1.
- [ ] Generate or single-source Functions character-known/default metadata as
  designed in Phase 1.
- [ ] Use transactional generated output, ownership markers, deterministic
  formatting, and stale/unexpected output detection.
- [ ] Support `--dry-run` without modifying any file.
- [ ] Fail generation for invalid source, missing assets/references, ordinal
  drift, or generated-symbol collisions.

### Cutover cleanup

- [ ] Switch Core, renderer, UI, replay validator, and Functions consumers to
  the generated artifacts as applicable.
- [ ] Remove handwritten catalog data replaced by generation.
- [ ] Remove the old AST entity catalog parser, source bindings, patch writer,
  and persistent backup path once no record depends on them.
- [ ] Remove migration-only normal-load compatibility; keep only the explicit
  offline migration command if it remains useful for audit evidence.
- [ ] Update generated-file headers, AGENTS rules, and editor user guidance.

### Parity and validation

- [ ] Add semantic parity tests for every migrated character, enemy, and
  projectile definition.
- [ ] Add deterministic generation and round-trip source tests.
- [ ] Add replay-sensitive tests for enemy ordinal/kill-count alignment and ID
  name decoding.
- [ ] Run the entity generator in normal mode.
- [ ] Run the entity generator in `--dry-run` mode and confirm zero drift.
- [ ] Run `dart run tool/sync_assets.dart --check`.
- [ ] Run `dart analyze packages/runner_core` and Core tests.
- [ ] Run focused Flutter/Game/UI tests for generated registries.
- [ ] Run `cd tools/editor && dart analyze` and `flutter test`.
- [ ] Run Functions and replay-validator checks if their generated consumers
  changed in this phase.

### Exit gate

- [ ] Strict authoring records are the only source of truth for migrated entity
  data.
- [ ] Existing runtime behavior and animation metadata have semantic parity.
- [ ] The current collider/preview editor works through the new store.
- [ ] No handwritten and generated authority coexist for the same record.
- [ ] Normal generation followed by `--dry-run` is clean.

### Evidence and notes

- Pending.

## Phase 3 — Shared Entity Workspace and Visual Authoring

### Typed commands and shared UI

- [ ] Add typed create, duplicate, update, retire, restore, and discard-draft
  commands with deterministic rejection diagnostics.
- [ ] Add entity-kind filters and searchable deterministic record lists without
  adding separate top-level routes.
- [ ] Add shared identity/status, animation, presentation, and collider panels.
- [ ] Keep type-specific panels composed beside shared facets rather than
  duplicating common controls.
- [ ] Keep form drafts page-local and commit only semantic commands to plugin
  history.
- [ ] Define coherent behavior for toolbar Undo, Redo, Reload, Apply, route
  change, workspace change, and selection change while a local draft exists.
- [ ] Namespace pending item IDs by entity kind.

### Asset picker and animation preview

- [ ] Reuse `RepositoryPngCatalog` for approved character, enemy, and projectile
  roots.
- [ ] Add search, deterministic ordering, dimensions, missing/invalid indicators,
  and a visual PNG selection surface.
- [ ] Store canonical runtime-relative paths without requiring manual path entry
  in the primary workflow.
- [ ] Add controls for frame size, row, frame start, grid columns, frame count,
  step time, anchor, natural facing, and render scale where supported.
- [ ] Add animation-key creation/removal constrained by type-specific supported
  keys and required-key rules.
- [ ] Preview the selected animation with runtime frame-selection and anchor math.
- [ ] Overlay runtime-shaped collider, cast origin, facing, and frame bounds.
- [ ] Cache decoded/catalog metadata outside widget build and drag loops.

### Validation and persistence

- [ ] Validate PNG existence/dimensions, exact frame bounds, required animation
  keys, positive timing/counts, anchor bounds, and asset-bundle inclusion.
- [ ] Validate identity, ordinal, revision, lifecycle, and candidate duplicates.
- [ ] Validate complete candidate documents even when a local section is not
  currently visible.
- [ ] Make pending preview bytes identical to the bytes offered to apply.
- [ ] Confirm/reload through the plugin/store path after successful apply.
- [ ] Report saved-authoring versus stale-runtime-generation state explicitly.

### Tests and validation

- [ ] Add shared facet widget and typed-command tests.
- [ ] Add asset discovery/filtering and invalid-PNG tests.
- [ ] Add animation frame math, bounds, anchor, facing, and playback tests.
- [ ] Add create/duplicate/draft/undo/reload/apply lifecycle tests.
- [ ] Add wide/narrow layout and keyboard navigation coverage.
- [ ] Run focused editor tests, `dart analyze`, and the full editor test suite.

### Exit gate

- [ ] Shared creation and visual configuration exist once and work for all three
  entity kinds.
- [ ] A draft can select and preview art without typing a path.
- [ ] Type-specific full authoring remains unavailable unless its phase has
  completed, so the UI cannot apply a falsely complete record.
- [ ] Pending, history, validation, and apply remain session-coherent.

### Evidence and notes

- Pending.

## Phase 4 — Projectile Vertical Slice

### Authoring surface

- [ ] Expose weapon type, speed, lifetime, collider dimensions, ballistic flag,
  gravity scale, damage type, procs, and stat bonuses.
- [ ] Expose all supported projectile animation and presentation fields through
  the Phase 3 shared panels.
- [ ] Provide safe new-projectile defaults and type-compatible duplication.
- [ ] Preserve the reserved `unknown` identity/ordinal and prevent it from being
  selected as authored playable content.
- [ ] Provide typed selectors for damage, proc hook, status profile, and stat
  references.

### Consumer integration

- [ ] Replace hard-coded projectile display names/descriptions that block
  generic new IDs with generated metadata or a documented data-driven owner.
- [ ] Make renderer registration and asset preloading consume generated catalogs.
- [ ] Ensure character/loadout and enemy ability reference validation can see
  the candidate/generated projectile catalog.
- [ ] Define and expose whether a new projectile is player-usable,
  enemy-usable, or only catalog-available through its external references.

### Tests and validation

- [ ] Add full source codec/store/edit/export coverage for projectile fields.
- [ ] Add invalid speed/lifetime/collider/gravity/proc/stat reference tests.
- [ ] Add a fixture that creates a new projectile, generates runtime output,
  resolves it from Core, renders its animation, and executes it in a
  deterministic simulation.
- [ ] Add ballistic and non-ballistic regression coverage.
- [ ] Run the generator and clean `--dry-run` check.
- [ ] Run Core, Game/UI, replay-validator, and editor checks relevant to the
  slice.
- [ ] Update projectile TDD/GDD and editor README for implemented behavior.

### Exit gate

- [ ] A projectile can be created completely without editing a Dart catalog or
  typing an image path.
- [ ] The generated projectile is resolvable, rendered, and deterministic.
- [ ] Missing usability references are clearly diagnosed rather than silently
  implying the projectile is equipped or spawned.

### Evidence and notes

- Pending.

## Phase 5 — Enemy Vertical Slice

### Authoring surface

- [ ] Expose body/physics, collider, health, mana, stamina, tags, resistances,
  immunities, animation profile, and timing data.
- [ ] Expose supported death, cast-target, facing, terrain-contact, art-facing,
  melee/combo, cast-ability, and cast-origin policies/references.
- [ ] Provide templates for supported grounded, flying, caster, and melee
  capability combinations without presenting them as arbitrary AI scripting.
- [ ] Validate incompatible policy/body/terrain/animation combinations.
- [ ] Provide safe creation defaults and compatible duplication.

### Consumer integration

- [ ] Make Chunk Creator enemy marker selection consume the generated active
  enemy catalog.
- [ ] Reject or repair missing/retired enemy references in authored chunks.
- [ ] Replace hard-coded enemy names/presentation switches that block generic
  new IDs.
- [ ] Inventory and convert hard-coded Core enemy branches to typed policies
  where they represent reusable behavior.
- [ ] Keep genuinely bespoke behavior code explicit and make the editor report
  its required policy key.
- [ ] Preserve enemy ordinal alignment for kill counts, scoring, events, and
  replay validation.

### Tests and validation

- [ ] Add full source codec/store/edit/export coverage for enemy fields.
- [ ] Add invalid body/vitals/policy/ability/terrain/tag/resistance tests.
- [ ] Add a fixture that creates a new enemy, places it in a chunk, generates
  content, spawns it, navigates/acts with a supported policy, takes/deals
  damage, dies, scores, and renders.
- [ ] Add deterministic spawn/combat and enemy ordinal regression coverage.
- [ ] Run the entity and chunk generators and confirm clean dry runs.
- [ ] Run Core, root gameplay, Game/UI, replay-validator, and editor checks
  relevant to the slice.
- [ ] Update enemy/terrain/combat TDD/GDD and editor README.

### Exit gate

- [ ] An enemy using supported policies can be created and placed without Dart
  catalog edits or a typed image path.
- [ ] The enemy completes its expected authored runtime lifecycle.
- [ ] Unsupported bespoke behavior is blocked with a clear developer-work
  requirement.
- [ ] Enemy ordinal/replay/scoring compatibility remains proven.

### Evidence and notes

- Pending.

## Phase 6 — Character Vertical Slice

### Authoring surface

- [ ] Expose display identity, body/collider, tags, resistances, immunities,
  facing, and cast origin.
- [ ] Expose movement, resources, ability, combat, and animation tuning with
  units and safe validation bounds.
- [ ] Expose default weapon, offhand, spell book, projectile source, ability
  slots, learned spell/projectile sets, and loadout-slot mask through typed
  selectors.
- [ ] Expose all character animation/presentation fields through shared panels.
- [ ] Provide safe creation defaults and compatible duplication without
  carrying another character's stable identity.

### Flutter, backend, protocol, and replay integration

- [ ] Make character selection and UI asset preloading consume the generated
  active character catalog.
- [ ] Remove hard-coded character lists/default-loadout assumptions that block a
  generated character.
- [ ] Single-source or generate Firebase Functions known-character and starter
  ownership/loadout metadata from the admitted character record contract.
- [ ] Preserve backend authorization and reject invalid character/loadout
  references rather than trusting client-authored state.
- [ ] Verify run tickets and replay blobs continue to serialize stable character
  names.
- [ ] Verify the replay validator resolves the generated character and produces
  identical deterministic outcomes.
- [ ] Define default/fallback behavior for retired characters already present in
  profiles, run sessions, replays, ghosts, and leaderboards.
- [ ] Keep deployment an explicit external step and surface source/generated
  readiness without claiming deployed availability.

### Tests and validation

- [ ] Add full source codec/store/edit/export coverage for character fields.
- [ ] Add invalid tuning, animation, gear, ability, projectile, spell-book,
  ownership, and loadout reference tests.
- [ ] Add a fixture that creates a new character, generates all consumers,
  selects it in Flutter state, starts a run, records a replay, and validates it
  through the replay worker.
- [ ] Add Functions default-state and loadout-authorization tests for the new
  generated character.
- [ ] Run `dart analyze packages/run_protocol` and protocol tests if contracts
  change.
- [ ] Run Core, root Flutter/Game/UI, Functions, replay-validator, and editor
  validation suites.
- [ ] Update character/loadout/progression TDD/GDD and editor README.

### Exit gate

- [ ] A complete character can be created without Dart catalog edits or a typed
  image path.
- [ ] The character can be selected and complete the authenticated
  run/replay-validation path after normal build/deployment steps.
- [ ] Backend ownership remains authoritative and historical retired-character
  data remains safely readable.

### Evidence and notes

- Pending.

## Phase 7 — Lifecycle, Integration, and Release Closure

### Lifecycle and reference safety

- [ ] Complete reference-aware Retire and Restore actions for all entity kinds.
- [ ] Prevent ordinal reuse and destructive removal of applied compatible IDs.
- [ ] Allow uncommitted drafts to be discarded without leaving files or
  generated output.
- [ ] Show inbound references grouped by source/domain before lifecycle changes.
- [ ] Define explicit migration-only destructive removal with proof/reporting if
  a real use case requires it.
- [ ] Validate references from chunks, levels, abilities, loadouts, profiles,
  backend defaults, and generated presentation metadata.

### Workflow and performance

- [ ] Add clear status for authoring saved, assets synced, runtime generated,
  backend built, and deployment still external.
- [ ] Add guarded shortcuts/handoffs to Chunk Creator or other owning routes
  where they materially improve verification without creating cross-plugin
  write authority.
- [ ] Run a non-developer usability pass for one new record of each kind.
- [ ] Measure reload, list/filter, animation preview, drag, pending-plan, and
  apply performance with a representative expanded catalog.
- [ ] Remove filesystem I/O and unnecessary allocations from interaction hot
  paths found by the performance pass.
- [ ] Verify wide/narrow layout, keyboard navigation, focus, and error recovery.

### Cleanup

- [ ] Remove temporary migration flags, adapters, fallback parsers, unused
  source-binding types, dead helpers, and duplicated validators.
- [ ] Perform the editor redundancy pass required by `tools/editor/AGENTS.md`.
- [ ] Confirm there is one owner for identifier normalization, ordinals,
  animation frame math, source ordering, revisions, and reference validation.
- [ ] Confirm generated files are clearly marked and no generated file is
  hand-edited.

### Full validation

- [ ] Run the entity generator and confirm clean `--dry-run` output.
- [ ] Run `dart run tool/sync_assets.dart --check`.
- [ ] Run the level/chunk generator and its `--dry-run` check when enemy marker
  integration changes its outputs.
- [ ] Run `cd tools/editor && dart analyze`.
- [ ] Run `cd tools/editor && flutter test`.
- [ ] Run `dart analyze packages/runner_core` and Core tests.
- [ ] Run relevant root `dart analyze`/`flutter test` targets.
- [ ] Run `dart analyze packages/run_protocol` and protocol tests when touched.
- [ ] Run `corepack pnpm --dir functions build`.
- [ ] Run `corepack pnpm --dir functions test`.
- [ ] Run `dart analyze services/replay_validator`.
- [ ] Run `dart test services/replay_validator/test`.
- [ ] Complete a clean-checkout from-scratch walkthrough for Character, Enemy,
  and Projectile and retain the evidence.

### Documentation and closure

- [ ] Update or create durable entity authoring/source/generation TDD documents
  to match implemented behavior.
- [ ] Update relevant GDDs for implemented character, enemy, projectile, and
  author-facing gameplay rules.
- [ ] Update `tools/editor/README.md`, root `README.md`, and applicable
  `AGENTS.md` files for delivered capabilities and commands.
- [ ] Update the Entities audit with closure/supersession evidence.
- [ ] Mark all phase statuses and validation evidence in this checklist.
- [ ] Move the completed strategy and checklist to
  `docs/building/archived/editor/entityAuthoring/` and repair incoming links.

### Program exit gate

- [ ] All program acceptance criteria in the strategy are satisfied.
- [ ] No required checklist item remains open.
- [ ] No legacy or parallel authoring authority remains.
- [ ] The repository is documentation-complete and all relevant validation
  passes from the final source state.

### Evidence and notes

- Pending.
