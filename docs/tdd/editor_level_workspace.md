# Level Creator workspace and authoring sessions

Status: Implemented; creator acceptance is tracked in the [delivery checklist](../building/editor/levelCreator/ui-ux-redesign-checklist.md).

## Ownership and workspace

`LevelCreatorPage` coordinates a searchable Level library, persistent preview,
Contents/Flow/Appearance views, and contextual inspector. Presentation siblings
receive typed callbacks; the Level domain owns commands, identities, validation,
pending diffs, and persistence. `LevelContentProjection` loads immutable Chunk
and Prefab sources and visual bounds without switching the active plugin.
Its geometry renderer is shared with Chunk previews and resolves authored
material/image assets. Play/sample preparation captures their complete source
dependencies separately through the shared compiler. Session `sourceGeneration`
invalidates dependent projections after source loading, Save refresh, and intent
reconciliation, including a return from a mounted dependency repair.

Shared three-panel layout retains its subtrees across responsive tabs and
resizing. Level-local view preferences store stable selection, tab, and filter
under a workspace-specific local application-data directory. They never enter
authored JSON. A missing saved Level ID requires an explicit current selection;
the editor does not silently select unrelated content. A typed handoff context
also retains the seed and selected source Chunk/section.

Automatic Flow is absent assembly. Ordered sections retain stable IDs and
reference Level-local groups. Each section can choose an exact Early, Easy,
Normal, or Hard difficulty; omitted difficulty means Automatic progression.
Explicit sections select only active chunks matching both group and difficulty,
without tier fallback. Global consecutive difficulty windows and their Hard
continuation apply to Automatic selection and Automatic sections.
Authors add, duplicate, remove and reorder sections in Flow. Duplication allocates
a new section ID and preserves the selected group, difficulty, count range and
distinctness. Equal minimum/maximum counts specify an exact length; Flow shows
one-based chunk positions when the preceding lengths are exact. These positions
are schedule indexes, not elapsed player travel. New sections use one unique
chunk, inherit the selected section's difficulty or a matching active chunk's
tier, and use Easy when the group has no loaded content.
Distinct selection resets per section occurrence, including repeat-all and
continue-last cycles. Repetition keeps each explicit difficulty. Pool readiness
counts unique active identities at the exact group/tier intersection and blocks
Play and included Build when insufficient; incomplete sections remain saveable.
Sample run and New variation prepare the real Core scenario's first 12 selections,
resolved tiers, section occurrences, and enemy-opening flags.
Each sampled occurrence names its reusable source; selecting it opens source
settings, whose edit action affects every occurrence of that source.
Captured input or seed changes hide stale results behind Update sample. Camera and ground references
remain read-only. Diagnostics use stable element and field metadata to reveal
the section/settings destination, including the responsive Settings panel.

Each Level may optionally author `firstChunkKey`. Contents exposes the action on
active Chunk cards, marks the current choice, and permits clearing it from Level
settings. The selected identity must belong to the Level and to the exact pool
resolved for schedule index zero, including the first ordered section's group,
explicit difficulty, and fallback rules. Invalid, missing, cross-Level, or
deprecated identities block Save/Play/Build rather than silently falling back.
Core pins the accepted Chunk only at index zero; subsequent selection retains
the normal deterministic schedule. A distinct first section excludes the
pinned identity from its remaining positions.

New and Copy collect a display name and allocate stable IDs in the domain;
Advanced permits explicit overrides. The default background choice makes an
independent layer copy, with sharing and empty-background choices explicit.
Background thumbnails reuse the Parallax painter even before a Level has chunks.
Copy settings defaults to Automatic; copying section/group design is optional
and never duplicates the source Chunk files.

## Save, admission, and history

Page-local text has an explicit bound identity and listener lifetime. Valid
input is finalized through semantic domain commands on completion or Save;
invalid/unfinished numeric input remains visible. Selection is presentation,
not content history. `EditorPageSaveHandler` returns an explicit outcome so shell
navigation cannot mistake a rejected Save or failed post-write refresh for a
successful departure. The shell names the whole domain's affected records and
offers Save all, Discard all, or Cancel before replacing that domain.

Validation is operation-aware. Structural/source errors block Save. Runtime
pool, capacity, and seam readiness errors block Play and included Build content;
they permit structurally valid incomplete design to be saved before repairing
its dependencies. All compound, plugin, coordinator, and store gates use the
same admission policy. Exclusion never excuses malformed authored data.

Level/Parallax history restoration applies content against the current saved
baseline and dependencies. Ordinary values, sections, and layers remain undoable
after Save without restoring stale revision tokens. The first persisted Save
seals creation history at that new identity. Deliberate reload and domain
replacement establish fresh history; local text retains normal text Undo.

## Handoff, repair, and failure recovery

Level-to-Chunk/Parallax navigation resolves departing changes, then preflights
the exact saved target before atomically changing the session. Chunk geometry,
group assignment, and starter allocation stay in the Chunk domain. A retained
starter intent reserves its stable target across failed attempts; reopening an
already-saved target does not recreate or overwrite it. Starter creation is an
accepted command with an Undo step before first Save. Save and return reloads
the originating Level and restores its typed view context.
These handoffs, the route selector, and Back/Forward share the shell's
[navigation transaction](editor_navigation.md). The return banner uses the
earlier matching Level visit when available, preserving Forward navigation.

An unsaveable Level/Parallax origin can retain one mounted document and raw
buffers while a separate session repairs a dependency. Nested suspension is
disallowed. Returning after a dependency write loads fresh sources and merges
only compatible authored intent by stable identity. Current dependency content
is retained; overlapping edits require explicit saved/intended choices. Every
merge attempt rereads sources, and rejection/cancellation keeps the recovery
copy. Creation identity collisions cannot overwrite an existing identity.

Source drift is a typed export failure with review/reapply or deliberate reload.
Post-commit refresh failure records that the write succeeded and offers refresh
only. Transaction failure preserves committed/rolled-back/cleanup-required
outcomes; retry uses the captured write manifest and verifies target, temporary,
and backup bytes before any recovery mutation. External changes stop recovery
instead of being deleted or overwritten. Unsaved drafts are session-local;
reopening restores saved sources, not crash-persisted draft bytes.

## Runtime and Build

Both Play entry points finalize valid visible buffers and capture immutable
authored source plus image bytes. Shared lifecycle code guards generation races,
keeps the editor mounted, and restores its state after Stop. Whole-Level Play
uses normal scheduling/pacing; focused Chunk Play loops its selected source with
authored markers. See [authored Play contracts](editor_chunk_playtest_host.md).

New/copied levels default excluded. Stable identity metadata remains generated
for excluded levels, while normal runtime availability is explicitly gated;
authored Play does not require compiled availability. See [Level/theme source
contracts](level_visual_theme_authoring_pipeline.md).

The shell owns repository-wide Build and Check freshness. Save resolution
precedes source-write locking. Build status is independent of authoring saved
state and Play readiness. Structured failures navigate to their source domain
or Level; exclusion from a report creates a normal pending Level edit. See
[Build process and transaction contracts](editor_content_build.md).
