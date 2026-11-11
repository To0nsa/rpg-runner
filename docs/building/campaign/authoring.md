# Campaign authoring and editor proposal

Status: proposed. This document supports the single
[implementation checklist](implementation.md).

## Source organization

Propose a campaign source domain beneath `assets/authoring/campaign/`, with a
chapter catalogue and individual mission files. Final filenames/schema are an M0
decision. Keep ordinary chunks in their existing source domain and reusable
atlases/parallax in their canonical asset directories.

A mission source describes stable identity/revision/status/build inclusion,
localized text identities, source/theme references, ordered route occurrences,
player start, bounds, objectives/exit, gameplay rules, and versioned score/reward
policy references. Chapter sources own mission order/prerequisites and map anchor
metadata. Keep account progress and editor viewport/selection preferences out of
authored content. Mission inclusion must not imply runner catalogue inclusion.

The shared compiler accepts captured source strings and explicit dependencies.
Editor/repository tooling discovers and reads files. The generator emits immutable
Core data and the metadata needed by presentation and trusted backend catalogues;
do not create independently maintained mission/reward lists in Dart and TypeScript.
The trusted backend policy projection must be bound to the same content release.
Generated output never becomes an input to source authoring.

## Chunk reuse

Each ordered occurrence contains its own stable ID and an explicit source-owner/
chunk-key reference. Its position in the list determines placement at the supported
chunk width; no arbitrary rotation/scaling or freeform scene transform is needed
for the first delivery. Validate compatible dimensions, world references, terrain
materials, and actual neighbor joins. For Val Outpost, begin with Forest sources
that already fit its theme and require the least traversal repair.

The workspace distinguishes three actions:

| Action | Meaning |
| --- | --- |
| Insert or duplicate occurrence | Reuse the same source at another route position with a fresh instance ID |
| Edit shared source | Open Chunk Creator; changes affect every referencing mission and existing runner pool |
| Create variant | Copy through the existing chunk domain into a new identity, then point this occurrence at it |

Show source identity and where-used impact before editing shared content. A new
variant must not accidentally enter a runner's automatic pool; M0 must define
explicit content usage/admission for campaign-only variants while preserving
existing chunk ownership. Do not use broad deprecation as a hidden substitute for
usage rules. Source deletion/rekey checks include campaign references and offer
explicit repair rather than silently substituting another chunk.

Keep geometric edits in Chunk Creator. Mission sources place mission-owned start,
exit, and objective regions and can refer to a specific occurrence's source
encounter/marker. Avoid an unrestricted nested override system. If ordinary combat
placements differ, create a variant until a repeated, concrete need justifies a
typed override. Compiler admission must reject unsupported runner spawn policies
for mandatory mission targets rather than silently changing them.

## Mission workspace

Reuse editor layout, geometry preview, catalogs, inspector controls, navigation
transactions, and play host. Add a campaign/mission domain for source ownership;
do not put all mission commands in a new page widget or recreate chunk editing.

The workspace provides:

- Chapter/mission library with draft, included, and readiness states.
- Chunk library filtered by source owner, group, difficulty, and compatibility.
- Ordered route strip with insert, move, duplicate occurrence, and remove actions.
- Continuous assembled preview with seams, bounds, source names, and instance IDs.
- Context inspector for mission details, occurrence source, start, exit, objectives,
  scoring/reward policy, and chapter prerequisites.
- Geometry/placement overlays and diagnostics that select the offending source,
  occurrence, objective, or seam.
- Whole-mission Play from the authored player start, and optional focused source
  Play clearly identified as a different diagnostic scope.

Display text should follow the [localization contract](../../tdd/localization.md).
Settle whether authoring owns source text plus translation identities or validated
resource references using the current content/localization pipeline. No generated
localization file is a hand-edited authoring surface.

## Editing and persistence

Semantic commands own insert/reorder/relink, marker placement, objective edits,
and metadata changes. Undo/redo preserves stable identities and obeys existing
revision rules. Removing an occurrence with referenced objectives must identify
and resolve those dependencies; reordering must not bind them by their old index.

Use existing transactional Save, source/dependency drift guards, and history
reconciliation. Valid but incomplete design can be saved as a draft. Malformed
source blocks Save; missing runtime readiness blocks Play and included Build.
Switching to Chunk Creator and returning restores the mission/occurrence context,
refreshes dependent content, and invalidates stale previews/play captures. Editing
a source while a mission playtest runs cannot mutate that captured attempt.

Persist workspace selection/zoom separately from content. Save, Play, and Build
remain distinct outcomes: saving a mission does not publish runtime artifacts,
and successfully testing an unsaved draft does not prove generated freshness.

## Compiler and Build admission

Validate unique IDs, strict schema/numeric bounds, source provenance, reference
existence/status, occurrence uniqueness, and chapter prerequisite cycles. Check
an eligible initial mission, supported placement dimensions, start support,
bounds, exit support, objective target types, and terminal conditions that are
structurally satisfiable. Reject random route selection and recursive expansion.

For every adjacent pair, apply shared compiled terrain/seam rules at their exact
world placement. Start/end boundaries need their own checks; do not invent a
continuation chunk past a finite exit. Player navigation must permit the intended
return route. Static admission catches malformed geometry and references; actual
movement tests establish traversal, as specified in [Validation](validation.md).

Allow explicit references to source chunks whose owner is not selectable as a
runner level only through documented inclusion rules. Capture all referenced
dependencies in the build closure; do not require an unrelated endless level to
be exposed in menus to make a campaign mission available. Preserve ordinary
runner admission invariants and generated stable identity ordering.

Extend the existing atomic generation transaction to publish campaign Core data,
presentation metadata, trusted backend policy data where needed, and dependency
fingerprints consistently. Freshness checks include mission/chapter sources and
all transitive references. Navigation preparation covers finite routes and their
actual bidirectional working sets; existing forward-only route enumeration is
not evidence of campaign coverage. Missing optional prepared graphs retain the
existing deterministic fallback, subject to measured startup/runtime budgets.

## Authored play acceptance

Play captures immutable mission, source dependency, and asset bytes through the
shared compiler, including valid unpublished drafts. It uses production mission
camera, objective, entity-lifetime, and completion behavior with a local session.
It cannot issue account rewards. Stop restores the editor state using its existing
lifecycle and input cleanup.

Authors must be able to create the first mission, reorder reused chunks, repair
a bad return-path seam, create a campaign-only variant, place start/objective/exit,
play a return trip, save/reopen, and build without hand-editing JSON. Include
shared-source drift, invalid drafts, Undo after Save, and failed-save recovery
in that acceptance sequence.
