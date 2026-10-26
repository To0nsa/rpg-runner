# Editor authoring reference

Read the applicable domain below before editing its sources or editor behavior.
These rules supplement [editor instructions](../../tools/editor/AGENTS.md).
Full repository paths start with `tools/`, `packages/` or `assets/` below.
Short filenames and `src/`/`pages/` paths are relative to the named editor domain.

## Domain Ownership And Write Targets

### Entities Domain

- owner: `tools/editor/lib/src/entities/**`
- plugin: `EntityDomainPlugin`
- source parser: `entity_source_parser.dart`
- writes are direct source edits against authoritative Dart files using source
  bindings/range replacement guards
- keep drift safety and backup behavior intact; do not bypass plugin/export
  guardrails with ad-hoc file writes

### Prefab + Tile/Module Domain

- owner: `tools/editor/lib/src/prefabs/**` and
  `tools/editor/lib/src/app/pages/prefabCreator/**`
- plugin: `PrefabDomainPlugin`
- source-of-truth files:
  - `assets/authoring/level/prefab_defs.json`
  - `assets/authoring/level/tile_defs.json`
- `prefab_defs.json` uses strict schema v3 polygon `collisionShapes`; legacy
  Prefab parsing belongs to the explicit offline polygon migration command
- persist through `PrefabStore` so canonical ordering and atomic paired writes
  stay consistent
- present authored platform modules and their gameplay Prefabs as one Platform
  workflow: bounded modules receive a deterministic paired collision owner,
  while `tile_defs.json` and `prefab_defs.json` remain separate internal
  sources and ambiguous multi-Prefab module relationships are never rewritten
  by guesswork
- page-local form and scene state may stay in `prefabCreator/**`, but
  load/validate/export contracts still flow through the prefab plugin/store path
- validation is structural and contract-oriented; keep obstacle/platform
  contracts typed and deterministic

### Shared Atlas Authoring Foundation

- owner: `tools/editor/lib/src/atlas/**`,
  `tools/editor/lib/src/workspace/repository_png_catalog.dart`, and the neutral
  `tools/editor/lib/src/app/pages/shared/atlas_*.dart` widgets
- shared code owns integer pixel rectangles, configurable grid math, temporary
  selection state, per-workspace grid-setting caches, repository PNG discovery,
  view transforms, painters, manual fields, and exact-region previews
- shared code must remain independent of Prefab IDs, terrain roles, revisions,
  persistence commands, and domain-specific root policies
- Prefab and terrain callers translate between their domain values and the
  shared pixel rectangle; do not restore domain-specific copies of grid,
  coordinate, PNG-header, or thumbnail logic
- grid settings are editor-session state only and must not leak into source JSON
  or generated runtime contracts

### Terrain Material Domain

- owner: `tools/editor/lib/src/terrain_materials/**` and
  `tools/editor/lib/src/app/pages/terrainMaterials/**`
- plugin: `TerrainMaterialDomainPlugin`
- source-of-truth file:
  `assets/authoring/level/terrain_material_defs.json`
- source-image root: `assets/images/level/atlases/**`; terrain reuses the
  canonical level source atlases instead of maintaining terrain-only copies
- the manifest uses strict schema v3 explicit image regions and paired top and
  underside endpoint/corner caps; normal editor code must not accept older
  schemas or add a migration fallback
- source models, canonical validation, traversal, repeat/seam math, and
  normalized edge/cap placement math come from `packages/terrain_materials`;
  do not duplicate those rules in the editor
- discover image metadata through `RepositoryPngCatalog`, then fully decode and
  bounds-check referenced images again during apply
- persist through `TerrainMaterialStore` so canonical ordering, drift guards,
  revision semantics, and atomic writes remain authoritative
- atlas grid state is not material content; same-region assignment and grid-only
  changes must remain revision-neutral

### Chunk Domain

- boss arenas are owner metadata edited through the existing optimistic metadata
  command and Save path. Preserve their data across composition/history changes;
  use the shared boss decoder and Core placement for Build/Play readiness. Do not
  expose arena-only bosses in ambient marker or rescue enemy catalogs.

- encounter participants are owned by a group in one chunk; edit them through
  the existing composition command and stable group/member IDs. Shared pipeline
  decoding/readiness owns validation, and Core owns terrain placement evidence.
  Incomplete groups are saveable but block Play/Build. Marker conversion removes
  the ambient record and creates its required member in one transaction.
- trap placements and editable triggers use the existing chunk composition
  command, revision guard and Save path; Core owns the catalog and damage rules
- water/trap/encounter rectangle interaction shares `pages/shared/scene_rectangle_gesture.dart`;
  keep validation and commit policy in each domain

- owner: `tools/editor/lib/src/chunks/**` and
  `tools/editor/lib/src/app/pages/chunkCreator/chunk_creator_page.dart`
- plugin: `ChunkDomainPlugin`
- source-of-truth directory: `assets/authoring/level/chunks/*.json`
- checked-in chunks use strict schema v2 direct polygon `collisionShapes`;
  direct shapes may use `collisionMode: none` for render-only terrain, which
  must be partitioned before Core collision expansion while remaining in the
  generated render snapshot; Prefab collision shapes remain solid/one-way;
  legacy flat-profile/gap parsing belongs to offline migration only
- solid Prefab placements may overlap each other and direct solid terrain;
  Core owns their exposed collision union. Retain independent source owners
  and the terrain-to-terrain, within-Prefab, and one-way collision overlap checks.
  Render-only direct terrain may overlap any placed Prefab, including full
  containment of a one-way platform. Review direct terrain separately from
  gameplay collision, matching the shared pipeline. Editor
  snapping must not become an alternate runtime collision compiler.
- keep one-chunk-per-file semantics, explicit `chunkKey` identity edits that
  atomically rekey document ownership, deterministic save-plan output,
  source-drift checks, and case-insensitive path-collision protection

### Parallax Domain

- owner: `tools/editor/lib/src/parallax/**` and
  `tools/editor/lib/src/app/pages/parallaxEditor/**`
- plugin: `ParallaxDomainPlugin`
- source-of-truth file: `assets/authoring/level/parallax_defs.json`
- source images: `assets/images/parallax/<theme>/<sheet>.png`; theme and sheet
  names use lowercase snake_case, and ordered layer sheets use `layer_NN.png`
- parallax themes are visual-only render data keyed by stable `parallaxThemeId`
- active level selection resolves the current `parallaxThemeId` via
  authored `assets/authoring/level/level_defs.json`; generated runtime
  registries are output and must not become editor validation authority;
  multiple levels may reuse the same authored theme
- terrain materials own ground visuals, geometry, collision, traversal, spawn,
  and streaming; parallax themes must not define a ground material
- keep deterministic theme/layer ordering, canonical numeric formatting, and
  validation/export gating in the plugin/store path instead of page-local logic

### Level Domain

- owner: `tools/editor/lib/src/levels/**` and
  `tools/editor/lib/src/app/pages/levelCreator/**`
- plugin: `LevelDomainPlugin`
- source-of-truth file: `assets/authoring/level/level_defs.json`
- current scope includes the Level Creator route, list/inspector UI, store,
  validation, plugin, explicit create/reuse visual-theme workflow, compound
  pending diff, rollback-safe two-source write, and guarded Parallax handoff
- `levelId` remains stable identity, `visualThemeId` ownership belongs here, and
  gameplay authority stays in core/chunk systems
- create/use-existing intent must remain explicit; new themes are empty
  revision-1 Parallax records and must be staged in the same session command as
  their Level reference
- Level Creator export must compose `LevelStore` and `ParallaxStore` plans and
  verify both baselines through one `WorkspaceWriteTransaction`; never sequence
  independent store saves for this workflow
- keep canonical file ordering by `levelId`, stable `enumOrdinal`, source-drift
  checks, and export gating in the plugin/store path
- Flow composes ordered sections with optional exact difficulty, group, count
  range and per-occurrence uniqueness. Carry difficulty through Save, generated
  Core, seam admission and authored Play; exact pools must never tier-fallback.
  Runtime readiness permits saving incomplete designs and blocks Play/Build.

### Future Authoring Domains

New authoring domains are allowed when they represent a real current workflow,
for example animation authoring or additional gameplay-facing data authoring.

Each new domain should define:

- an owning folder under `tools/editor/lib/src/**`
- authoritative repo files or source bindings
- a plugin id and route mapping when the workflow is user-facing
- deterministic validation and export rules
- focused tests for load/edit/export/session behavior

Do not overload an existing plugin with unrelated concerns just to avoid adding
a well-bounded new domain.

## Determinism And Validation Rules

- preserve canonical ordering and serialization in stores/models
- keep validation/export gating strict: blocking errors must prevent writes
- keep migration behavior explicit, deterministic, and test-backed
- do not silently coerce identity fields (`chunkKey`, `prefabKey`, module IDs)
  in a way that breaks existing references
- keep pending-change previews coherent with actual export behavior; UI should
  not imply writes the plugin will not perform
