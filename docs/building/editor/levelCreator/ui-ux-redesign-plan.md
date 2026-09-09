# Level Creator UI/UX Redesign

Date: September 8, 2026  
Status: Implemented and regression verified; independent creator acceptance pending

Implementation update: September 9, 2026. The baseline was checkpointed in
`9d958389` before implementation. Current behavior and test evidence are recorded
in [implementation verification](implementation-verification.md). The evidence
and problem statements below describe the pre-redesign baseline.

Deliverables:

Composition extension: sections now accept explicit difficulty, retain exact
group/tier uniqueness, show fixed chunk positions and matching capacity, and
support duplication. Current semantics are recorded in
[Level workspace contracts](../../../tdd/editor_level_workspace.md) and
[level composition rules](../../../gdd/level_composition.md); the baseline
audit below describes the earlier global-difficulty-only design.

- [Implementation checklist](ui-ux-redesign-checklist.md)
- [Workflow audit and resolution map](ui-ux-workflow-audit.md)
- [Interactive layout concept](level-creator-ux-wireframe.html) — illustrative UI, not a running game

## 1. Outcome and scope

An author familiar with game creation must be able to create a level, add its
first playable chunk, choose its background, organize content, tune progression, press Play,
return to editing, and save without editing JSON, understanding generated Dart,
or using a terminal. Editing an existing level and creating ordered sections
receive the same attention as initial creation.

Assume a provisioned editor and valid repository workspace, plus familiarity
with chunks, Prefabs, layers, groups, and placement tools. Keep that vocabulary.
Beginner tutorials, a new launcher/installer, and a general asset importer are
outside scope. The editor must make the route to Levels visible and explain a
missing or invalid workspace without silently opening unrelated content.

Level Creator becomes the place to understand and test a whole level. Chunk
Creator continues to own chunk geometry, Prefab placements, and enemy markers;
Parallax continues to own background layers; terrain materials and Prefabs keep
their existing authoring routes. Direct, context-preserving navigation connects
these tasks.

**Level Play / F5 is required delivery scope.** It must run the actual level
selection and progression rules, including valid unsaved authoring changes and
levels that have never been generated into the application. Existing Chunk Play
must also work for those levels with its explicitly different focused test scope.

The target is the current Windows desktop editor. The layout must also work in
small desktop windows. Production deployment, backend administration, a campaign
editor, arbitrary chunk placement, and changes to combat/balance are outside this
initiative. Making local content ready for an application build is included;
releasing that application to players remains a developer/release task.

## 2. Evidence and current state

This plan follows the working tree inspected on September 8, including the
ongoing Chunk/Prefab UI improvements. The running Windows Level Creator was
also inspected through a window capture. The source implementation is authority
where older plans or game-design documents differ.

### Game model

The game streams deterministic chunks for an ongoing runner. A level is a
recipe for content selection, progression, and appearance. The following are
separate concerns:

| Concern | Implemented meaning | UI consequence |
| --- | --- | --- |
| Chunk | Authored terrain, Prefabs, and markers; current runtime width is 600 world units | Show a visual thumbnail and open Chunk Creator for spatial edits |
| Chunk group | A level-local pool such as `ruin` | Show membership and usable content; a group is not a background theme |
| Assembly segment | An ordered rule selecting a min/max number of chunks from one group | Present as a **section** with length in chunks |
| Difficulty | Consecutive Early, Easy, Normal windows, then Hard indefinitely | Present a separate progression strip; section changes do not reset it |
| Enemy-free opening | Suppresses authored enemy markers in the first N chunks | Say **No enemies for the first N chunks**; other hazards remain |
| Background theme | Shared visual layer definitions referenced by the level | Explain shared usage before editing; sections do not switch backgrounds |

With no assembly, runtime uses automatic level-based selection. With ordered
sections, a seed determines section lengths and chunk choices. Difficulty-tier
fallback still applies. Distinctness applies within one section occurrence and
must be possible in every resolved tier pool. The final-section behavior is
either **Repeat all sections** or **Continue the last section**; neither ends
the run. The player starts halfway into chunk zero, so a preview's chunk index
and world distance must not be presented as elapsed play time.

Sources:
[selection](../../../../packages/runner_core/lib/track/chunk_pattern_source.dart),
[progression](../../../../packages/runner_core/lib/track/track_streamer.dart),
[level definition](../../../../packages/runner_core/lib/levels/level_definition.dart),
[scheduler validation](../../../../packages/runner_core/lib/collision/terrain/terrain_authoring_scheduler.dart).

### Actual authored content

| Level | Active chunks | Chunk tier | Groups | Background layers | Ordered sections |
| --- | --- | --- | --- | --- | --- |
| Forest | 1 flat chunk | Early | Default populated; Ruin, Trainingcamp, Woodcamp empty | 3 | None |
| Field | 1 flat chunk | Normal | Default | 8 | None |
| New Level | 1 flat chunk | Normal | Default | 0 | None |

All three current chunks have one ground shape, no placed Prefabs, and no enemy
markers. These are the current working-tree facts, not permanent product limits.
The initial redesigned screen must remain useful with sparse content. It must
not require sections or fabricate rich thumbnails, populated groups, or
difficulty coverage.

Sources:
[levels](../../../../assets/authoring/level/level_defs.json),
[chunks](../../../../assets/authoring/level/chunks),
[backgrounds](../../../../assets/authoring/level/parallax_defs.json).

### Existing strengths and blockers

The editor already has shared cards, visual catalogs, viewport controls,
transactional source writes, undo history, guarded route loading, and a real
Windows Chunk Play host. Preserve these foundations.

The Level route currently has material workflow problems:

1. A permanently open creation form competes with the current level. Technical
   fields and raw diffs dominate one long inspector. Horizontal metric scrolling
   and fixed-height nested layouts hide controls.
2. Local text, accepted session changes, saved files, and generated runtime data
   are separate states with overlapping Apply/Saved language.
3. Level selection, Create, and Duplicate can overwrite local inspector drafts.
   Same-level undo/reload can leave stale visible values. File Apply can save an
   earlier accepted value while a newer visible value remains uncommitted.
4. Invalid numeric text may silently fall back to an old value. Some raw segment
   inputs are not represented consistently in dirty state.
5. The default new section requests 2–5 distinct chunks, which is unsuitable for
   every current one-chunk group. Aggregate group counts do not establish actual
   tier capacity or seam readiness.
6. New Level creates metadata and optionally an empty theme, but no chunk.
   Chunk Creator's creation form requires an existing chunk as its dimension
   template, leaving an empty level without a usable first-chunk action.
7. The current Chunk Play scenario uses compiled Level metadata, replaces one
   generated chunk, chooses a validated loop, and suppresses the level's normal
   enemy-free setting. It cannot stand in for whole-level Play.

Evidence:
[Level page](../../../../tools/editor/lib/src/app/pages/levelCreator/level_creator_page.dart),
[Level plugin](../../../../tools/editor/lib/src/levels/level_domain_plugin.dart),
[shell](../../../../tools/editor/lib/src/app/pages/home/editor_home_page.dart),
[Chunk workspace](../../../../tools/editor/lib/src/app/pages/chunkCreator/v2/chunk_authoring_workspace.dart),
[Chunk scenario](../../../../packages/runner_core/lib/playtest/chunk_playtest_scenario.dart).

The existing Level page, Level domain, and Level/theme workflow suites passed
22 tests during this research. They establish a useful baseline, but do not
cover the draft/undo/save failure cases above. No production code was changed
for this plan.

## 3. Design decision

Three approaches were considered:

| Approach | Benefit | Limitation | Decision |
| --- | --- | --- | --- |
| Reorganize the existing form | Smallest change | Does not show the level or close creation/Play gaps | Insufficient |
| Make an ordered-section timeline the entire workspace | Strong sequence editing | Current levels use automatic selection; appearance and content still need a home | Use as the Flow view |
| Persistent level preview with Contents, Flow, and Appearance views | Covers creation, editing, automatic generation, and sequence design | Requires read-only content projection and a full-level scenario | Recommended |

### Workspace composition

```text
Editor route     Save   Undo   Redo                  Unsaved changes / Saved
-------------------------------------------------------------------------
Levels        Forest                                      Play (F5)  ...
Search        -----------------------------------------------------------
+ New level   | Persistent level preview / sampled chunks               |
              | Seed: 4401   New variation   Fit   Preview settings       |
Forest        -----------------------------------------------------------
Field         Contents | Flow | Appearance             Selected settings
New Level     | Contextual visual workspace           | Friendly fields
              |                                      | Help where needed
              -----------------------------------------------------------
              1 issue to fix / 2 suggestions      Review changes / Build
```

- **Level library:** compact rows with friendly names, a small image, unsaved
  indicator, and meaningful readiness summary. Search/filter becomes useful as
  content grows. Technical identity, ordinal, and revision are secondary details.
  The library is the sole Level selector in this route; remove the duplicate
  active-level dropdown.
- **Persistent preview:** shows the selected chunk or a sampled part of the
  level. It remains mounted when tabs change. Selection highlights the
  corresponding content/section and contextual settings. The source scene is
  read-only here; **Edit chunk** opens its authoring route. Label a sampled
  occurrence separately from its reusable chunk source: editing that source
  changes every use. Copying a chunk creates a reusable variant in selection
  pools, not an override for one preview occurrence.
- **Contents:** visual chunk catalog, group filters, authored difficulty badges,
  active/deprecated status, search, and a clear Add chunk action. Empty groups
  state **No chunks yet** and offer Add/open actions.
- **Flow:** explicit **Automatic** / **Ordered sections** choice. Automatic
  shows the actual content pool and progression. Ordered sections shows
  reorderable cards, group thumbnails, length ranges, and repetition settings.
  The progression strip is available in both modes.
- **Appearance:** actual background preview, the assigned background, shared
  usage, and **Edit background**, **Choose background**, and **Make a copy**.
  Explain that terrain appearance is authored on chunks/materials.
- **Contextual inspector:** changes with level, chunk, or section selection.
  Technical identifiers and read-only camera/ground data sit in Advanced.
- **Diagnostics:** compact summary opens the full navigable issue list. Inline
  errors appear at their fields/cards. File paths, codes, and diffs remain
  available in details. No twelve-issue truncation without access to the rest.

Use the existing dark palette, blue action accent, shared spacing/cards, and
visual catalog conventions. Give Play and Save clear prominence without
duplicating shell actions. Color must supplement icons and text. Creation is a
focused dialog, not a permanent column-sized form.

### Responsive behavior and accessibility

Use available workspace width rather than device names. At approximately
1200 logical pixels and above, show the three regions. At intermediate widths,
collapse the level library into a chooser and retain the preview plus inspector.
At small widths, expose Preview/Content/Settings through accessible panel tabs
or drawers with the selected level and Play still reachable. Reuse the existing
layout primitives and improve their retention behavior only where necessary.

Keep one vertical scroll owner per panel, no horizontal scrolling for ordinary
forms, and stable mounted preview/edit state through resize. Test at 1440×900,
1280×800, 1024×768, and 800×600 logical pixels, plus 125% and 150% text scaling.
Provide visible focus, labeled controls, tooltip explanations for unavailable
actions, keyboard alternatives to dragging, and complete keyboard navigation.
Viewport gestures retain Ctrl+drag pan and Ctrl+scroll zoom. Ctrl+S saves;
text editing consumes its own undo before global document undo.

## 4. Author journeys and interaction rules

### Create a level and its first content

1. **New level** asks for a friendly name. Generate a unique stable identifier
   with the existing domain convention; Advanced permits review before creation.
   Renaming a display name later never changes identity or ordinal.
2. Show background thumbnails. Default to an explicit independent copy of a
   chosen existing background; also offer sharing an existing background or
   starting empty. Copying layer definitions is a bounded new Level/Parallax
   command; image files remain shared repository assets. Explain the effect of
   sharing before selection. Do not silently inherit the selected level's
   progression/camera defaults.
3. Use explicit standard starting settings or an explicitly selected **Copy
   settings from…** source. Standard creation uses the existing domain defaults:
   camera center 135, ground reference 224, Early 3 chunks, Easy 0, Normal 0,
   and an enemy-free opening of 3 chunks. Resolve these from their authoritative
   constants rather than duplicating literals in widgets. The initial selection
   mode is Automatic; existing levels keep their values. New and copied levels
   start **Excluded from game build**, independently of active/deprecated status,
   and can be saved and locally tested while the author develops them.
4. After creation, show the level and the next task: **Add a flat starter
   chunk** or **Open Chunk Creator**. A starter uses the current supported
   dimensions, the level's ground reference, the Default group for Automatic
   selection (or the first referenced group for an explicit section-design copy), a
   deliberate Early tier, and a validated terrain material. The initial preset
   is a 600×270 chunk with the existing 16-unit tile size, with continuous
   solid ground from the level ground reference to the chunk bottom, no Prefabs
   or enemy markers, and the existing `grass_dirt` material when available.
   Resolve dimensions from current runtime/authoring contracts; if the required
   material or ground bounds are invalid, ask for a valid material/preset in
   context rather than choosing an arbitrary catalog entry. In Automatic mode a
   lone starter repeats through difficulty fallback until more content is added;
   a copied section design may still require other groups or distinct chunks.
5. Save the Level/theme pair before moving to the Chunk route. The action is
   labeled **Save and add starter chunk** when this is required. A typed handoff
   opens a prepared starter in Chunk Creator; its normal domain owns creation,
   validation, preview, and save. Show **Save and return to level** there.
6. Returning restores the level and refreshes chunk/background dependencies.
   The starter enters the authored dependency snapshot without generation.
   Standard Automatic creation is ready for Play; copied section designs list
   any remaining requirements before either scenario's admission can pass.

This is an explicit resumable sequence of domain-owned saves. Reserve the
starter's stable target once in the handoff intent; retry first checks the saved
sources and opens an already-created target instead of creating another. Reopen
of a saved level with no chunks offers **Continue: add starter**. After a saved
starter exists, open that content; a cancelled unsaved chunk remains an explicit
new creation on a later session. See the recovery contract below for saved-only
crash recovery. Cancellation never leaves half a
Level/theme pair. An empty background is valid authoring content and receives a
neutral preview plus **Add background layers**; it is not a fake missing asset.

Existing Duplicate becomes **Copy level settings…**, with a summary that it
copies metadata and the selected background reuse/copy choice, starts Automatic,
and copies no chunks. A separate explicit **Copy section design** option retains
the source groups and assembly rules, including distinctness, but lists the
content still needed. Its starter targets the first section's group; other
missing pools/capacities have Add chunk actions. Neither copy mode inherits build
inclusion. A valid incomplete design can be saved without dismantling its rules.
Full deep cloning of levels/assets is outside scope.

### Edit existing content and appearance

The Contents view provides visual selection, **Add group**, and **Edit chunk**.
Group creation asks for a readable name and allocates its canonical identifier
in the Level domain; show a humanized label with the stored identifier in
Advanced. Preserve the existing string-group schema. Renaming a stored group
would require explicit migration of chunk and section references, so no casual
rename action is added in this scope. Creating a replacement group, assigning
content, and removing an unused group remain available.

**Add chunk to this group** and **Assign chunk to group** carry the intended
group in a typed Chunk handoff. Save a newly created group before navigation;
the Chunk metadata/create form previews the intended assignment and commits it
through its normal domain path. The author can therefore create and populate
two groups without developer-prepared content.

Ordinary Chunk creation may retain its existing empty/deprecated starting state
and detailed tools. Carry the intended level/group into that form and make the
remaining steps visible: author geometry/placements, validate, set Active to
join runtime pools, then Save and return. An inactive chunk must not appear to
participate in Play. A chunk belongs to one group: reassignment removes it from
the previous group. Show affected sections and resulting capacity issues,
especially when moving its last usable chunk; permit the incomplete design to
be saved and repaired under the admission rules below.

Level Creator
does not copy geometry, placement, or marker editors into its inspector. Changes
to chunk group/tier/status route through the Chunk domain and its existing
metadata form. Ordinary cross-domain handoffs resolve Save all/Discard all/Cancel
for the departing session. A diagnostic repair of an unsaveable dependency uses
the bounded retained-origin path below.

Targets include stable level identity, optional chunk/group identity, and transient
return context such as selected section/filter. The shell loads and validates
the target before replacing its current session. Missing/moved targets explain
the change and preserve the source workspace. Returning reloads dependencies,
not a stale count-only cache.

Background editing opens the exact assigned theme. Show **Used by N levels**
and offer **Make a copy for this level** before editing a shared theme. Theme
layer editing stays in Parallax, where the same Save semantics must apply.

### Automatic selection and ordered sections

Automatic maps to an absent assembly. It does not require a synthetic Default
section. Group filters in Contents are organizational in this mode; they must
not imply exclusion from automatic runtime selection.

Enabling Ordered sections proposes a populated group when available, otherwise
an existing declared group with an Add chunk action. Start at one chunk with
repeats allowed. Authors can accept and save structurally valid length/distinct
rules before enough content exists; capacity feedback blocks Play, not designing
the sequence. Never invent a group reference or silently reduce a requested count.

Each section card answers: **which content, how much, and can it repeat?**
Use group label/thumbnails as the primary title; keep the existing stable
`segmentId` secondary. No new persistent section-display-name schema is needed.
Lengths are **At least / At most … chunks**. Distinctness reads **Use each chunk
at most once in this section** with resolved-pool capacity feedback.

Reordering supports drag handles, keyboard commands, and Move earlier/later.
One reorder is one semantic undo step. Removing a section is undoable. Removing
a group referenced by sections or chunks is blocked with navigable references.
The required `default` group remains available, labeled **Default**.

Switching an existing sequence to Automatic explicitly removes the assembly
through one undoable command. If sections exist, explain their removal first;
Cancel preserves them. Do not keep a hidden second serialized sequence. Undo
restores the prior sequence.

Difficulty controls show consecutive counts with computed chunk-index ranges
and **Hard: continues**. A coverage summary shows authored versus fallback
tiers. For example: **No Easy chunks; this stage uses Early chunks**. The
enemy-free opening is a separate control. No new difficulty presets or balance
changes are introduced under UI labels.

### One trustworthy Save

The UI exposes one Save, backed by three explicit internal layers: local edit
buffer, accepted session document, and persisted authoring sources.

- Valid completed edits enter the session through semantic domain commands.
  Text fields retain incomplete/invalid text locally; blur/Enter closes a valid
  edit transaction. Save also finalizes valid focused input. Avoid a command or
  revision per keystroke.
- Dirty state reacts to every visible input. Save validates and includes all
  visible edits; invalid input focuses the first error and writes nothing.
- Selection, filters, tab/section expansion, and viewport/seed changes are
  history-neutral presentation state. They never increment revisions or occupy
  content undo steps; an edit finalized during navigation remains one real edit.
- Undo/redo and reload reconcile buffers through an explicit document-change
  lifecycle, outside `build`. An unresolved invalid buffer cannot be silently
  overwritten by owner/section selection or history navigation.
- Ordinary level/chunk/section selection and tab changes within the same
  session finalize valid local input into accepted unsaved edits. They do not
  request a repository save or discard session changes. Retain mounted buffers
  where appropriate; if an invalid buffer would be replaced, offer Keep editing
  or Discard this edit and preserve selection on cancel. Create/Copy settings
  use the same local-input protection.
- Ordinary domain replacement, deliberate reload, workspace changes, and close
  resolve all departing local/session changes with Save all/Discard all/Cancel.
  Continue only after a successful save or explicit discard. Failures retain
  exact input and source selection. The bounded dependency-repair path below is
  the explicit exception; navigation within the same session never prompts for
  accepted changes.
- Source export remains in existing plugins/stores and retains drift checking,
  rollback, canonical reload, and cleanup-required outcomes. Recovery warnings
  remain visible; report committed source writes separately from refresh or
  cleanup failure rather than misreporting them as an uncommitted save failure.
- **Review changes** shows the exact pending source plan; technical diffs are
  optional detail. Routine Save does not require a second generic confirmation
  after the author already requested a reversible save.

Save covers the whole Level/theme session, including changes on levels other
than the selected one. Show an always-visible summary such as **2 levels and
1 background have changes**, with affected names available inline. Departure
dialogs list those names and say **Save all level changes** / **Discard all level
changes** / **Cancel**. The summary includes local buffers and accepted edits;
invalid buffers still block Save. **Discard this edit** only abandons the
specific invalid field buffer. Chunk and Parallax routes expose their actual
document scope using the same shared contract.

### Save admission and dependency repair

One authoritative diagnostic model identifies the operations each issue blocks.
Do not infer Save admission from a generic error count or hide runtime blockers.

| Condition | Save | Local Play / game-content Build |
| --- | --- | --- |
| Invalid field syntax, schema, identity, reference, numeric range, source asset contract, or unsafe/stale baseline | Block the affected source transaction; retain input and correction/recovery action | Block use of that invalid input |
| Declared group with no usable chunks, empty level pool, insufficient distinct capacity, or otherwise valid content failing whole-level reachability/seams | Persist the structurally valid design | Block affected scenario; block Build when level is included |
| Valid content with fallback tiers or empty supported background | Save | Admit if canonical runtime checks pass; show useful feedback |

This changes validation responsibilities, not source-integrity guarantees.
Coordinate semantic compound-command admission (`_rejectInvalidCompoundCandidate`),
plugin export, store/coordinator preflight, and installed-candidate verification
(`_requireInstalledCandidate`) in one milestone. Preserve parse/source corruption,
reference, baseline, transaction, and individual asset/geometry checks. Runtime
readiness remains canonical in the shared pipeline/Core; no widget suppresses
`insufficient_distinct_group_chunks` to force a write. Apply operation-aware
diagnostics to dependency documents so their repair actions can be opened.

For a dependency error that still prevents Save, **Repair in [editor]** may retain
one originating session in memory: accepted semantic edits, exact local buffers,
source baselines, selection, and return intent. Preflight the target before
suspending the origin. Only that dependency route is opened; no nested suspended
sessions or global multi-document framework is introduced. Closing or replacing
the workspace must also resolve the retained origin, never silently abandon it.

**Save repair and return** saves through the dependency's normal plugin, reloads
current origin sources/dependencies, and reapplies compatible originating intent
through domain commands. It must not restore a stale theme/dependency snapshot
over the repair. Conflicting edits use the recovery choices below; unresolvable
buffers stay visible. Cancellation returns to the retained work with its error
still present. Unreadable target data leaves the origin intact and offers Reload
or a retained known-good version when available; this is not a generic corrupted
file reconstruction tool.

### Undo and history boundaries

Ordinary value and section edits remain undoable after a successful Save. Use
plugin-owned semantic history reconciled against the new canonical baseline:
Undo creates a new pending content change and the next Save follows the current
revision policy. Never restore old source fingerprints, baseline lists, revision
numbers, or dependency caches from full-document history snapshots. Merely
retaining the existing session undo stack across reload is insufficient.

Creating an identity is undoable before its first save. That first save seals
the creation lifecycle entry for the persisted level/theme/chunk; subsequent
Undo cannot delete that identity or recycle its ordinal. Ordinary edits remain
undoable, including section removal and switching to Automatic. Show the history
boundary when no earlier eligible edit remains.

Selection and normal Save preserve document history. A successful ordinary
cross-domain handoff, deliberate reload/discard, workspace replacement, or reopen
starts fresh content history; show that boundary in the Undo state. A cancelled
handoff keeps history. Repair return reapplies retained intent as fresh pending
edits against reloaded sources; it does not resurrect old history or offer undo
of the dependency save from Level Creator. Play/Stop retain history unchanged.

### Recovery and reopening

| Situation | Required next action and retained state |
| --- | --- |
| External source drift | Name changed content, retain intended edits, then offer Reload and discard all or Review and reapply. Reapply nonoverlapping semantic edits against current sources; conflicting fields require an explicit saved/intended value choice through the plugin. Keep unresolved intent as a read-only recovery copy in the current session. Never blind-overwrite new baselines or offer endless Save retry. |
| Files committed; canonical refresh failed | Show **Saved; refresh failed** with affected content. Retry refresh only; keep the committed transaction outcome and disable repeat writes until reconciliation. Reapply only edits not already committed. |
| Commit or rollback needs cleanup | Preserve the transaction's exact outcome and recovery paths; do not claim success until the stored result proves which files committed. Resolve cleanup before another conflicting write. |
| Starter handoff interrupted | Retain the saved Level/theme pair and stable target intent in-session; retry checks current sources before creating. On reopen, infer the remaining step from saved content and offer Continue or Open existing chunk. |
| Normal close and reopen | Resolve all active/retained edits on close. Restore saved sources and persist only safe workspace-keyed level/tab/filter selection; revalidate missing IDs and show an empty/selection state when needed. Reopening starts fresh history. |
| Crash or forced termination | Recovery is saved-source-only. Local buffers, unsaved commands, retained repair origin, and session recovery copies are not crash-persistent. No autosave/draft journal is promised in this scope. |

The shared shell needs a semantic save outcome and reactive page-draft status.
Update all route adapters in one pass so Level, Chunk, and Parallax journeys
use consistent language and guards. Preserve page-specific gesture/modal locks;
do not add route-ID branching or a second persistence layer in the shell.

## 5. Preview and full Level Play

### One authored snapshot for preview and Play

Introduce a bounded read-only Level content projection and an immutable
preparation input containing accepted Level metadata, all relevant chunks,
Prefab/tile sources, terrain materials, background definitions, and referenced
workspace assets. The Level document owns Level/theme edits; dependency reads
do not make it the write authority for other domains.

Capture one coherent source generation. Include input identities/fingerprints
in preparation results, check source drift during capture, and discard stale
asynchronous results after editing, navigation, reload, or cancellation.
Referenced images/definitions must not change halfway through Play; capture
resolved assets or detect drift and require a new preparation.

Reuse the shared content pipeline for compilation/materialization and Core's
reachability analysis for group/tier/distinct/seam admission. Show structural
errors separately from content suggestions and runtime readiness. Zero usable
chunks blocks Play, while an empty but valid level can still be saved. One
sampled seed is an illustration, never proof of universal seam safety. The
current assembly analyzer's 256-chunk finite pacing prefix limit receives a
plain-language diagnostic if exceeded; do not silently relax it.

The sampled preview starts with a bounded first 12 chunks and a default seed
4401. **New variation** changes a local preview setting, never source content or
undo history. Show the actual chosen chunk order, resolved difficulty, section
boundaries, enemy-free opening, and a continuation indicator. Repeated flat content must visibly
remain repetitive. Reuse existing chunk/material/Prefab preview rendering and
Core selection; do not create a Flutter scheduler or a decorative approximation
of chunk geometry. Extend bounded sample length only when useful.

### Runtime construction and identity

Add a validated `LevelPlaytestScenario` through the tooling-only playtest
boundary. It owns a freshly materialized terrain catalog and the real level
chunk source, preserving authored progression, enemy suppression, assembly,
ground/camera values, and seed. It must not wrap the single-chunk lasso or use
`LevelRegistry.byId` for current authoring values.

Scenario admission checks every eligible chunk for matching authored level
identity, unique stable chunk key, valid active status, and the runtime stream
width (currently 600 world units). Enforce these across the entire pool before
constructing Core, alongside the canonical compiler and scheduler checks.
Wrong-level or mismatched-width data must not produce a partial runnable scenario.

New authored levels expose a genuine architectural dependency: `LevelDefinition`
and snapshots currently require generated `LevelId` values. The recommended
solution is an explicit typed distinction between registered game identity and
authored preview identity at the Core tooling boundary. Normal game/replay
construction continues to require a registered identity; preview construction
uses the actual authored string identity. Migrate affected snapshot/render
consumers coherently. Do not impersonate Field/Forest, add placeholder enum
entries, or convert backend/protocol identities to dynamic strings.

Prove this boundary in Phase 0 through both Play launchers with a never-generated
level. Treat it as a Core contract change requiring parity tests. A
fresh-process build was considered but is not the chosen default: it adds
build/restart/packaging overhead and undermines unsaved iteration.

Inject materialized background definitions and terrain-material catalogs, as
well as workspace image bytes, into the existing Flame render bridge.
`StagedTerrain` currently resolves materials through the generated
`TerrainMaterialRegistry`; merely capturing a material JSON file does not make
Play consume it. Add an explicit catalog dependency with the generated catalog
as the normal application default and the captured validated catalog for Play.
Reuse shared material conversion/validation and test new material identifiers
that have never been generated. Generated registries must not override the
preview's captured appearance. Keep gameplay behavior in Core.

Migrate existing `ChunkPlaytestPreparation` and `ChunkPlaytestScenario` in the
same delivery as Level Play. Both consume the authored identity and coherent
dependency/asset snapshot; Chunk preparation must no longer reject an ID absent
from generated `LevelId` or read current settings/pools from `LevelRegistry`.
Overlay the accepted selected-chunk edits on that authored snapshot, then retain
the canonical focused loop/lasso validation for Chunk Play. Retire its old
generated-catalog dependency path instead of keeping a special fallback for new
levels. The shared host accepts either scenario; it does not decide scheduling.
Incomplete assembly/reachability or an unsafe loop can still block focused Play;
show the repair action without requiring rules to be discarded. Focused Play is
not a bypass for canonical scheduler or seam admission.

Label the scopes **Test chunk — focused loop** and **Play level — seeded run**.
Chunk Play deliberately disables the level's enemy-free opening to test markers
and uses its focused loop; full Level Play preserves the actual seed, tier
progression, assembly, and `noEnemyChunks`. In a sampled occurrence distinguish
markers present in the source, suppression during the opening, and spawn-placement
failures. Compatible enemy placement and obstacle/perch requirements still come
from existing validation; never change runtime rules to make a preview look active.

### Play interactions

- **Play / F5** finalizes valid local input into the session and captures the
  scenario without saving files. Invalid input remains visible with an
  actionable reason; gestures and active dialogs retain their existing locks.
- Start at the real level beginning with the same seed as the visible sample.
  First delivery uses Eloise and the existing default loadout; expose these
  defaults in Play settings without adding loadout-authoring scope.
- Reuse the current Windows host controls: Enter starts, P pauses/resumes, F6
  restarts the same immutable scenario, F5/Escape stops. Use the existing game
  input mappings, keyboard focus behavior, aim bounds, and focus-loss pause.
- Preparation, loading, paused, game-over, and failed states have clear next
  actions. Play readiness explains failures beside the action and in the full
  issue list; normal editor unavailability is not a source-file error.
- Keep the editing subtree mounted while playing. Stop restores level, tab,
  section/chunk selection, inspector state, viewport, seed, history, and pending
  diff. Restart never recaptures changed files. Re-entering Play prepares current
  edits afresh.
- Continue to label the host **PLAYTEST — NO REWARDS/REPLAY**. No auth, tickets,
  player state, submissions, ghosts, leaderboard, or backend calls are involved.

### Required parity checks

Resolve these before claiming that the preview matches gameplay:

1. Generator chunk pools currently include parsed deprecated chunks while seam
   reachability filters active chunks. Make eligibility consistent in the
   authoritative generation/materialization path and its tests; the intended
   playable pools use active content while preserving stored deprecated identity.
2. Flame currently consumes background Parallax layers; foreground definitions
   are authored/generated but have no observed render consumer. Preview/Play
   must use the same supported layers. Mark unsupported foreground content with
   an actionable limitation; adding foreground runtime support is a separately
   scoped render change, not an invented preview feature.
3. Terrain, Prefab visuals, enemy placement, tier fallback, and seed selection
   must match the real runtime. Verify with multi-chunk fixtures; the current
   one-flat-chunk levels cannot establish this by themselves.
4. A never-generated level, material, and theme must work from both visible
   Play entry points without generation/restart. Compare captured identity,
   metadata, geometry, and appearance; assert only the declared test-scope
   differences in scheduling/enemy suppression.

## 6. Saving, building, and release readiness

Play must work directly from authoring content, independent of generation.
Provide an explicit **Build game content** action for preparing saved content
for application builds. It operates on the repository, not just the selected
level, and belongs to a small workspace service exposed through the shared shell.

### Unfinished levels and build inclusion

Add an explicit persisted `includeInBuild` boolean to the Level source schema.
Use an explicit v1→v2 migration that sets it to `true` on every current record;
normal parsers then accept the current schema only. New/copy commands set it to
`false`. Keep `active`/`deprecated` independent: deprecation currently hides a
registered level from selection while retaining runtime access, so it cannot
serve as an exclusion flag without changing that contract.

The library and level settings show **Included in game build** / **Excluded from
game build**. Excluding saves the same level identity, ordinal, groups, rules,
chunk keys, status, and theme links; it deletes no content. Excluded levels can
be reopened, edited, saved, and tested through authored Play when locally ready.
**Include in game build** updates that same record and exposes its readiness
blockers with Open/Add/Repair actions. Inclusion can be saved while incomplete;
Build must still pass admission. This is an explicit set-aside/resume workflow.

Implement this policy coherently in the authoritative pipeline/generator and
their runtime consumers, not by filtering source-file discovery:

- Parse and validate all source schemas, identities, references, asset contracts,
  and individual chunk geometry, including excluded content. Structural corruption
  still blocks Build and names its source.
- Apply whole-level pool capacity, scheduler reachability, and seam readiness
  to included levels. Emit runtime chunk pools/terrain for those levels only;
  shared assets used by included content remain available. Included deprecated
  levels remain addressable and must pass readiness too.
- Preserve every existing `LevelId` enum slot/ordinal and identity/display
  metadata. Generate compiled availability separately. Registry lookup for an
  excluded ID must return a typed unavailable failure before constructing a
  definition; it must never bind to absent pools or substitute another level.
- Select default runtime patterns from included active playable content. Require at
  least one included, active, playable level before replacing generated outputs.
  Only included active levels enter selectable output; remove the UI's fallback
  from an empty selectable list to all `LevelId.values`.
- Gate app selection/default restoration, asset loading, and run start on compiled
  availability, including existing hardcoded Field defaults. A stale local
  selection offers an available choice. Ticket/replay/ghost identity is never
  substituted. Validator content/configuration absence uses its existing failure
  path; it cannot become a fabricated simulation or a successful reward result.

The strict schema migration, generated availability, and affected consumers land
together in Phase 3 before new-level commands rely on exclusion. Reconcile
active/deprecated chunk eligibility in that same migration so capacity admission
and generated pools use one canonical predicate. Keep normal
registered replay identities and backend authorization/catalog contracts intact.
Local inclusion neither authorizes an online run nor removes a level from a live
server; compatible release artifacts remain the developer handoff below.

### Build execution and status

Use the existing root generator and `GeneratedArtifactPlan`; do not create
Level-owned output writers. Add a machine-readable report for source problems,
generated drift, output changes, and transaction results. Invoke the known Dart
executable with fixed argument arrays and the canonical repository directory,
using one guarded job. Handle tool absence, cancellation, source drift,
permission/file-lock failures, and rollback/cleanup results inside the UI.

Build saves/resolves pending authoring input first, validates, transactionally
generates the existing outputs, and verifies exact post-build drift. Lock
editor source writes, reload, and workspace replacement during the job; verify
external-source fingerprints again before commit. Cancellation is admitted
before output replacement. Once replacement starts, finish the transaction or
its rollback and show **Finishing safely**; never terminate the subprocess in
the middle of file replacement. The input set must remain coherent through the
job. List included/excluded levels in the Build summary. Another included level's
runtime-readiness failure can block this repository-wide operation; show its name
and **Open / Add content / Exclude from game build** as appropriate. Exclusion
returns to an ordinary source edit/save before retrying Build. Structural errors
anywhere still require repair. Saved does not imply Play or Build readiness.

Use independent status dimensions:

| Dimension | Example states |
| --- | --- |
| Authoring | Unsaved changes, Saving, Saved, Save failed, Saved; refresh failed |
| Local Play | Preparing, Ready to play, Needs a playable chunk, Fix 2 issues |
| Build inclusion | Included in game build, Excluded from game build |
| Generated content | Not checked, Build needed, Building, Built and verified, Build failed |

Recheck freshness after relevant dependency edits/external changes. An existing
generated file is not proof of freshness; a nonzero dry-run currently means
either ordinary drift or invalid input, which the structured report must
distinguish. Local build success does not reload enum constants in an already
running application; authored Level Play avoids that dependency.

Generated UI already includes New Level, but backend selection authorization
currently admits only Field/Forest, and replay validation uses compiled level
data. Therefore do not show **Published**, **Live**, or **Available online**
based on active status or local generation. Keep level availability settings
distinct from source build inclusion and explain that release builds determine
player availability.
Developer handoff must identify compatible app/validator builds and backend
catalog/board configuration; no deployment or account administration is added
to Level Creator.

Sources:
[generator](../../../../tool/generate_chunk_runtime_data.dart),
[artifact transaction](../../../../tool/generated_artifact_plan.dart),
[backend catalog](../../../../functions/src/ownership/loadout_authorization.ts),
[board provisioning](../../../../functions/src/boards/provisioning.ts),
[validator](../../../../services/replay_validator/lib/src/validator_worker.dart).

## 7. Implementation boundaries and reuse

| Responsibility | Owner / intended change |
| --- | --- |
| Layout, fields, selection, edit buffers | Split the Level coordinator into bounded route-local presentation/state siblings; use existing shared cards/catalog/layout primitives |
| Save/dirty/navigation semantics | Existing shared page contracts, shell, session, owner-draft and pending-resolution presentation; semantic results, not Level-specific shell branches |
| Save admission, history, and repair | Domain-owned operation diagnostics and semantic edit reconciliation; shell hosts one bounded retained origin and never restores old write baselines |
| Level and background lifecycle | Existing Level plugin/models/store and compound save coordinator; explicit background/section-copy policies, build-inclusion schema and defaults |
| First-chunk creation and metadata | Existing Chunk lifecycle/metadata policy; explicit starter preset usable with an empty level |
| Content browsing and visual previews | Immutable dependency projection; extract minimal reusable preview input from existing Chunk preview, keeping source writes in their domains |
| Source compilation and runtime materialization | `runner_content_pipeline`; explicit strings/typed products, no repository I/O or Flutter |
| Scheduling, terrain admission, preview runtime identity | `runner_core` tooling constructor/scenario and canonical scheduler; preserve production determinism and registered protocol identity |
| Actual Play rendering/input/lifecycle | Existing `lib/playtest/**`, Flame bridge, shared shell shortcut contract; generalize the host for the two real scenario types |
| Build/progress/freshness | Small editor workspace service around the root generator and artifact plan |
| Compiled level availability | Authoritative pipeline/root generator and registered runtime consumers; stable IDs, explicit unavailable admission, no authorization/catalog redesign |

Relevant reuse:
[UI system](../../../tdd/editor_ui_system.md),
[shared widgets](../../../../tools/editor/lib/src/app/pages/shared),
[Chunk preview](../../../../tools/editor/lib/src/app/pages/chunkCreator/v2/chunk_owner_preview.dart),
[session](../../../../tools/editor/lib/src/session/editor_session_controller.dart),
[host contract](../../../tdd/editor_chunk_playtest_host.md),
[Level/theme transaction](../../../tdd/level_visual_theme_authoring_pipeline.md).

Do not expand the already-large Level page with another scene implementation,
duplicate identifier allocation in widgets, or add a generic editor framework.
The workspace presentation keeps group/section schemas intact. The explicit
Level schema v2 inclusion migration and Play identity/availability contracts
are bounded changes in their owning layers, delivered with all affected consumers.

## 8. Delivery order and gates

| Phase | Deliverable | Acceptance gate |
| --- | --- | --- |
| 0. Characterization and runtime proof | Lifecycle/admission regressions, representative fixtures, wireframe review, both Play identity/materialization paths, exclusion/availability compatibility proof | Known losses reproduced; both authored scenarios work without generated identity; stable registered IDs survive excluded runtime content |
| 1. Editing reliability | Unified Save scope/dirty state, operation-aware admission, semantic undo after Save, bounded repair and concrete recovery | Incomplete valid designs save; dependency repair retains intent; multi-level Save/Discard and Save→Undo→Save use correct baselines/revisions |
| 2. Level workspace | Compact library, persistent preview/catalog, Contents/Flow/Appearance, friendly controls, full diagnostics and responsive layout | Current sparse levels are understandable; automatic and ordered flows both work; old long-form route is removed |
| 3. Complete creation and handoffs | Coherent inclusion schema/generator/consumer migration, name/copy/default policies, first-chunk preset, resumable Chunk/Parallax handoffs | Creator saves and resumes incomplete designs; excluded experiments do not break compiled selection or finished-content generation; ordinary content editing has no dead ends |
| 4. Both authored Play paths | Coherent snapshots, sampled Level selection, full Core scenario, migrated focused Chunk scenario, material/theme injection and shared host | Both launchers play never-generated/current authored content; scope differences are explicit; Stop/Restart preserve specified states |
| 5. Build workflow | Structured report, inclusion summary, source resolution, transaction/progress/freshness UI | Finished content builds while incomplete experiments stay excluded; source/build/server states remain distinct |
| 6. Acceptance and closure | Real creator tasks including recovery/history/resume, accessibility/performance, docs and migration cleanup | Complete create/edit/Play/save/reopen workflow passes with actual newly authored content; required regressions pass; plan is archived |

Phases 1 and 2 are useful independently validated releases, but do not satisfy
the full requested workflow by themselves. Phases 3 and 4 form one release gate:
do not expose exclusion/new-copy defaults to authors while existing Chunk Play
still depends on generated registries. Phase 3's migration must pass source/build
compatibility tests; Phase 4 completes authored Play before that release ships.
Phase 4 is mandatory, not an optional
future enhancement. Phase 0 resolves the highest-risk runtime boundary before
committing the complete UI to an unproven Play path. Presentation work and the
scenario/compiler work can then proceed independently against agreed inputs.

## 9. Verification and definition of done

Use the [checklist](ui-ux-redesign-checklist.md) as the implementation ledger.
Every milestone receives focused tests, documentation, and a coherent commit;
do not include the unrelated current worktree changes.

Automated coverage must include draft/selection/undo/reload failures; invalid
numeric text; atomic Level/theme copy/create/reuse; first chunk on an empty
level; exact handoff/return targets; automatic/section/tier/seed parity;
distinct-pool and seam errors; unsaved/never-generated Level Play; injected
backgrounds; cancellation/focus/Stop/Restart; source drift; and repository-wide
build failure/recovery/freshness. Include active/deprecated chunk fixtures and
multiple groups/tiers rather than relying on flat current content.

Audit regression coverage is mandatory: all Save admission gates agree on an
incomplete copied sequence; retained dependency repair returns over fresh sources;
multi-level Save/Discard reports its actual scope; Save→Undo→Save uses current
baselines and revisions; first-save creation fences preserve identity; both Play
launchers accept never-generated dependencies; and committed-refresh failure
retries no writes. Exercise same-session retry and reopen after starter saves.

Migration/generator fixtures must build an excluded incomplete distinct sequence
alongside finished content, reject that sequence when included, and still reject
malformed/duplicate/reference/geometry-invalid excluded sources. Check restored
identity/rules, excluded first-alphabetical and Field defaults, no selectable-level
fallback, and controlled unavailable app/ghost/validator handling. An all-excluded
build must fail before replacing outputs. Build/dry-run repeat deterministically.

Run editor analysis/tests for each touched editor milestone. Run content-pipeline,
Core, game/UI, playtest, generator, and snapshot/protocol/validator checks when
their contracts are touched. Use generator write/dry-run tests in disposable
workspace fixtures; do not repair unrelated current content as part of a UI
milestone.

Manual acceptance uses at least one game content creator who did not implement
the editor, on a provisioned workspace with existing assets:

- Create a named level/background/starter and test from Chunk and Level Creator
  before generation. Change terrain, place a Prefab and a compatible enemy, then
  compare focused Chunk Play with the actual Level opening and later occurrences.
- Create the second useful chunk with existing tools, author its geometry,
  activate it, and assign it to a group. Supplied assets are fine; supplied
  completed chunks cannot replace this exercise.
- Edit two level names/pacing values, verify the save-scope summary, exercise
  Save all/Discard all/Cancel, then Save→Undo→Save and the explicit handoff boundary.
- Create two groups and ordered sections using the new content; distinguish
  repetition from difficulty progression. Move a group's last chunk and follow
  the resulting repair action. Edit a repeated source and verify all occurrences.
- Copy ordinary settings, then explicitly copy a two-group distinct section
  design. Save its incomplete rules, add the needed chunks via diagnostics, return,
  and Play without discarding those rules. Exercise a retained dependency repair.
- Edit a shared background safely and understand which levels change.
- Put aside an incomplete experiment, build completed content, reopen/resume the
  experiment with the same identity/rules, finish it, include it, and build again.
- Recover from external drift and committed-save/refresh failure, interrupt and
  retry the starter without duplicates, then close/reopen saved content and Play.
- Distinguish Saved, Ready to play, Included in game build, and Built; confirm that
  no local state implies online release. Verify the stated saved-only crash limit.

Target: complete these tasks without code/JSON intervention, lost work during
supported operations, or an unexplained disabled action. Game-creation vocabulary
needs no beginner teaching exercise. Record confusion, wrong
turns, and time-to-first-Play; use observations to refine layout and labels.
Measure preview/preparation responsiveness on the Windows reference machine,
keep compilation off the UI isolate, and verify stop/cancel remains responsive
under a deliberately large content fixture.

The HTML concept remains an illustrative layout, not evidence that these state
contracts work. Its coverage notice links to this plan; implementation fixtures
and real creator acceptance establish completion.

Update implemented behavior in the editor UI TDD, Level/theme pipeline TDD,
playtest TDD (including the whole-level contract), Core identity/snapshot docs
where affected, editor README, editor AGENTS, and the add-new-level workflow as
each milestone lands. Update GDD only if implemented player behavior changes;
proposals remain in this plan until delivered. Archive this plan/checklist on
completion, retaining the wireframe as historical design context.
