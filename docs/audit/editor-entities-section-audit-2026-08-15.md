# Editor Entities Section Audit — August 15, 2026

Date: August 15, 2026
Scope: the standalone editor's Entities route under `tools/editor`, including
page state, scene interaction, inspector behavior, domain models, parser,
validation, pending diffs, source export, file writes, and focused tests
Decision: all six findings were closed by the Phase 0 safety pass on August 16,
2026; the bounded collider editor now has scalar-preserving and transactional
source writes, typed failure signaling, asynchronous parsing, and one change
policy

## Evidence policy

This is a point-in-time review of the current working tree based on Git commit
`de1305fb43f1743a708856009080ba99a67f80ba` plus uncommitted editor-toolbar
integration. The working tree already contained unrelated user changes; this
audit did not alter implementation or authored-content files.

The user requested that tests be handled later. Accordingly, this audit is
based on static source review and test inventory only. It does not claim that
the current analyzer or test suite passed during this review.

## Executive conclusion

The Entities section has a good architectural core:

- `EntityDomainPlugin` is a thin adapter over separate parser, document, and
  export collaborators;
- immutable document snapshots support deterministic scene projection and
  session-level undo/redo;
- parser/load issues and editor validation are combined before export;
- pending diffs and real export use the same patch planner;
- source snippets and offsets are checked for drift rather than rewritten on a
  best-effort basis;
- scene drags use coalesced undo, while inspector drafts stay page-local until
  an authoring command is applied;
- the current shared toolbar integration delegates Apply to the page-owned
  confirmation flow.

The original audit found no Critical issue, two High issues, two Medium issues,
and two Low issues. Phase 0 closed them without broadening the route into an
advanced entity editor. The two High issues were in the source persistence
boundary:

1. player/projectile collider bindings can encompass unrelated source between
   the bound arguments, but export replaces the whole range with collider fields
   only;
2. direct writes do not use the repository's transaction primitive, do not make
   a final drift check immediately before replacement, and can miss rollback of
   a source write that partially mutates before throwing.

The current checked-in player and projectile catalogs keep the affected fields
adjacent, so the first issue is latent rather than evidence of existing source
corruption. The second issue is a failure/concurrency exposure, not evidence that
an ordinary successful write currently produces incorrect data.

## Method

The review covered:

- all files under `tools/editor/lib/src/entities/**`;
- all files under `tools/editor/lib/src/app/pages/entities/**`;
- shared session export orchestration and workspace write primitives;
- the authoritative runtime files and source layouts referenced by the parser;
- focused entity tests and the two entity cases in `widget_test.dart`;
- editor README/TDD coverage for the Entities workflow;
- searches for stale TODO/FIXME markers, duplicate numeric/change logic, and
  direct synchronous file access.

## Findings

### ENT-H01 — Multi-node collider bindings can erase unrelated source

Severity: High
Status: Closed — August 16, 2026

Implementation evidence: player, enemy, and projectile collider fields now
carry per-scalar bindings and unit conversions. Export replaces only changed
numeric expressions. Reordered/interleaved fixture regressions prove unrelated
arguments and comments survive unchanged.

`_bindingFromNodes` computes one replacement interval from the minimum start
offset to the maximum end offset of several AST nodes
(`entity_source_parser_support.dart:292-321`). Player loading uses that helper
for four named collider arguments
(`entity_source_parser_domain_loaders.dart:312-317`), and projectile loading
uses it for two (`entity_source_parser_domain_loaders.dart:452-457`).

The exporter then replaces that entire interval with a newly constructed block
that contains only the collider arguments
(`entity_export_patch_planner.dart:429-467`). As a result, this legal source:

```dart
colliderWidth: 20.0,
someUnrelatedOption: true,
colliderHeight: 46.0,
```

binds a range containing `someUnrelatedOption`, but the generated player
replacement omits it. Comments inside the range are lost for the same reason.
The exact-snippet drift check cannot prevent this because the planned range
still matches the file exactly; the unsafe deletion is part of the planned
replacement.

The reordered-argument regression test only rearranges an otherwise contiguous
set of collider arguments (`entity_test_support.dart:77-96` and
`entity_test_support.dart:205-212`). Its expected output explicitly
canonicalizes that contiguous block (`entity_parser_export_test.dart:383-455`),
so it does not cover interleaved arguments or comments.

Recommendation:

- capture one expression binding for each writable named argument;
- replace only the scalar expression for width, height, and offsets, as the
  anchor-expression writer already does for narrowly proven ranges;
- retain overlap and exact-before-snippet rejection in the planner;
- add player and projectile regressions with interleaved unrelated arguments,
  comments, and reordered collider fields, asserting byte preservation outside
  the edited scalar expressions.

### ENT-H02 — Entity writes bypass the atomic transaction and final drift seam

Severity: High
Status: Closed — August 16, 2026

Implementation evidence: patched sources and persistent `.bak` outputs are one
`WorkspaceWriteTransaction` artifact set. `beforeReplace` checks complete
source baselines, installed output is byte-verified and reparsed before cleanup,
and injected first/middle/last install, verification, existing-backup, final
drift, and cleanup-state tests cover the transaction boundary.

The planner reads each current source, validates every captured snippet, and
stores full before/after content (`entity_export_patch_planner.dart:58-95`). The
writer later writes `.bak` files and source files directly with
`writeAsStringSync` (`entity_export_writer.dart:18-43`). It does not re-read the
source immediately before replacement.

This creates three integrity gaps:

- an external edit after planning can be overwritten, while the persistent
  `.bak` is populated from the stale `patch.originalContent` rather than the
  external edit;
- a process or machine interruption can leave a truncated file or a mixed
  multi-file state because replacements are not staged and renamed atomically;
- `writtenSources` is updated only after `writeAsStringSync` returns. If that
  call truncates or partially writes and then throws, the damaged source is not
  present in the rollback list (`entity_export_writer.dart:33-42`).

The repository already provides the stronger primitive needed here.
`WorkspaceWriteTransaction` stages and flushes complete outputs, moves targets
to recoverable sibling backups, installs and byte-verifies the entire set, and
documents `beforeReplace` as the final optimistic-concurrency seam
(`workspace_write_transaction.dart:61-68` and `workspace_write_transaction.dart:94-195`).

The current backup-failure test blocks creation of the first `.bak`, before any
source replacement starts (`entity_parser_export_test.dart:305-381`). The drift
test mutates source before export planning (`entity_parser_export_test.dart:540-591`).
Neither test exercises final pre-replace drift, a failure during source
replacement, or recovery after one of several sources has been installed.

Recommendation:

- express both persistent `.bak` outputs and patched sources as one
  `WorkspaceWriteTransaction` artifact set;
- in `beforeReplace`, verify every source still exactly equals the plan's
  `originalContent` before any target moves;
- verify installed source bytes or reparse the written sources before temporary
  transaction backups are discarded;
- preserve the existing user-visible `.bak` contract while relying on the
  transaction's separate recovery files for rollback;
- add injected failure tests for final drift, first/middle/last replacement,
  an existing persistent `.bak`, partial-write simulation, verification failure,
  and transaction cleanup reporting.

### ENT-M01 — Expected export failures bypass the controller error channel

Severity: Medium
Status: Closed — August 16, 2026

Implementation evidence: `ExportOutcome` separates no-change, failed, applied,
and applied-with-cleanup-required results. Converted failures carry an
actionable message into `EditorSessionController.exportError`; controller and
shared-toolbar widget tests verify immediate feedback.

Entity export catches validation, planning, and write failures and converts
them into `ExportResult(applied: false)` with an `entity_export_error.md`
artifact (`entity_export_pipeline.dart:53-76` and
`entity_export_writer.dart:104-113`). `EditorSessionController` sets
`exportError` only when a plugin throws (`editor_session_controller.dart:319-350`).

The Entities page checks `exportError` to show an immediate failure snackbar,
but when it receives the entity error artifact, `exportError` is null and the
page returns as soon as it sees `applied == false`
(`entities_editor_page.dart:261-277`). The bottom Apply Result panel eventually
shows `files written: no` and the selected artifact
(`entities_editor_status_panels.dart:92-143`), but the primary action gives no
immediate failure notification. The same `applied: false` value also represents
a successful no-op in the shared contract, so callers cannot classify the two
states without knowing artifact title conventions.

Recommendation:

- use one explicit failure contract across plugins: either throw a typed export
  exception for failed application or extend `ExportResult` with a typed
  outcome/error field;
- reserve a no-op outcome for the valid no-changes case;
- make the shell/page show consistent immediate feedback and keep the artifact
  only as detailed diagnostics;
- add a widget/controller test that exercises entity source drift through the
  shared Apply action and asserts visible failure feedback.

### ENT-M02 — Filesystem checks and parsing run synchronously on the UI isolate

Severity: Medium
Status: Closed — August 16, 2026

Implementation evidence: entity source reads and analyzer parsing run through
a worker isolate. Referenced image existence is captured as an immutable set on
the loaded document/scene, build code no longer calls `File.existsSync`, and
the decoded-image loader avoids cached-image rebuild loops.

`EntityDomainPlugin.loadFromRepo` is asynchronous in signature but calls the
entire synchronous parser before its first suspension
(`entity_domain_plugin.dart:59-69`). The parser performs synchronous reads and
AST parsing across fixed sources and every player catalog
(`entity_source_parser.dart:64-108` and
`entity_source_parser_support.dart:10-63`). This can make Reload block the
desktop UI as the catalog grows or when a workspace is on slower storage.

There is also synchronous filesystem work in normal widget construction.
`_buildViewportPanel` resolves reference visuals during build
(`entity_scene_view.dart:8-29`), and `_resolveReferenceVisual` calls
`File.existsSync` for every animation view (`entity_scene_reference.dart:37-99`).
Scene drag updates rebuild frequently, so those existence checks repeat on the
interaction path even though the loaded document and asset paths are unchanged.

Recommendation:

- move source loading/parsing off the UI isolate, or at minimum make the load
  boundary genuinely asynchronous before performing blocking work;
- resolve asset availability once per loaded document/workspace snapshot and
  cache the immutable result;
- keep widget build and drag rebuilds limited to in-memory projection;
- add a focused benchmark or instrumentation test for reload and drag rebuilds
  with a representative entity/animation count.

### ENT-L01 — Entity update commands silently accept partial malformed payloads

Severity: Low
Status: Closed — August 16, 2026

Implementation evidence: the route now emits an immutable `EntityUpdate` and
the document boundary rejects malformed envelopes, unknown targets, non-finite
values, incomplete optional groups, and edits without writable bindings before
history changes.

The shared authoring command is an untyped string/map envelope
(`authoring_types.dart:5-39`). The entity document pipeline independently reads
each field and falls back to the current value whenever the payload value is
missing or has the wrong type (`entity_document_pipeline.dart:153-208`). A
payload with an invalid `halfX` and valid `halfY`, for example, silently applies
only `halfY`.

Current inspector and scene callers construct numeric payloads through one page
helper (`entities_editor_apply.dart:80-165`), so this is primarily a boundary
robustness and future-maintenance issue rather than a demonstrated current UI
failure. The silent fallback nevertheless hides programming errors and makes
the exact command contract implicit.

Recommendation:

- decode `update_entry` once into a typed entity update object;
- require the four collider fields together and reject malformed payloads as a
  no-op with a diagnostic or as a programmer error, according to the editor's
  shared command policy;
- validate optional values against the entry's writable bindings;
- test missing, wrong-type, non-finite, unknown-id, and mixed-validity payloads.

### ENT-L02 — Change tolerance and bounds-diff logic have three owners

Severity: Low
Status: Closed — August 16, 2026

Implementation evidence: `EntityNumericPolicy` and `EntityChangeSet` own field
equality and deltas for gestures, document no-op/dirty behavior, pending plans,
source edits, and installed-output verification. Epsilon-boundary regression
coverage exercises the shared policy.

The document pipeline owns `changeEpsilon`, entity-bounds comparison, nullable
comparison, and dirty detection (`entity_document_pipeline.dart:15-20` and
`entity_document_pipeline.dart:246-306`). The export planner repeats its own
bounds and nullable comparison helpers
(`entity_export_patch_planner.dart:412-427`). Scene interaction hard-codes the
same `0.000001` tolerance a third time for collider and anchor drag changes
(`entity_scene_interaction.dart:322-341`).

This duplication is small today, but these three decisions jointly determine
whether a gesture creates history, whether a document is dirty, and whether a
source edit is produced. If one tolerance or compared field changes alone, the
section can report a dirty entry with no source edits or create mismatched undo
and export behavior.

Recommendation:

- have the document layer produce a typed `EntityChangeSet`/field delta against
  baseline and let the export planner consume it;
- put shared entity numeric equality in one domain-owned policy used by scene
  command coalescing and document comparison;
- remove the duplicated private comparison helpers and test epsilon-boundary
  behavior through gesture, dirty-state, and export layers.

## Existing coverage

Static inventory found 29 focused entity tests:

| Area | Test file | Count | Covered behavior |
|---|---|---:|---|
| Parser/export | `entity_parser_export_test.dart` | 11 | direct writes/backups, top-level enemy bindings, animation metadata, missing metadata fallback, reference edits, validation blocking, initial backup failure, contiguous argument reordering, stable discovery, expression preservation, pre-plan drift |
| Session | `entity_session_test.dart` | 4 | edit/undo/redo/pending/export, collider diff, cast-origin diff, anchor/render-scale diff |
| Domain models | `entity_domain_models_test.dart` | 7 | immutable snapshots and runtime-shaped collider preview behavior |
| Document validation | `entity_document_pipeline_test.dart` | 2 | invalid actor capsule and legal projectile proportions |
| Inspector widgets | `entity_inspector_panel_test.dart` | 3 | actor/projectile explanations and invalid actor messaging |
| Route widgets | `widget_test.dart` | 2 | entity table load and caster cue semantics |

The suite is strongest around parser discovery, normal patch output, source
drift before planning, and collider interpretation. The highest-value missing
regressions are:

- interleaved non-collider arguments and comments inside a multi-node binding;
- final drift immediately before replacement;
- source-write failure after at least one file has changed;
- existing persistent `.bak` restoration and transaction recovery reporting;
- shared-toolbar Apply failure feedback;
- scene handle hit testing, drag math, coalesced undo, and pointer cancel;
- local inspector draft behavior across toolbar Undo, Redo, Reload, and route
  changes;
- malformed command payload handling and epsilon-boundary consistency.

No tests were executed as part of this audit.

## Phase 0 closure validation — August 16, 2026

The remediation pass added and passed focused entity model, document, parser,
export, transaction, session-controller, inspector, scene-interaction, and
typed-result tests. Shared-toolbar failure feedback and guarded local-draft
reload coverage also passed before unrelated concurrent work changed the
Chunk/terrain/Prefab slices.

The full editor suite was attempted and reached 432 passing tests, but the
current worktree could not complete the repository-wide gate because separate
active work introduced a syntax error in the Chunk v2 workspace, terrain tests
calling a missing reducer method, and missing Chunk/Prefab controls. Focused
analysis of the entity, entity-page, domain, and session directories remains
clean. The active implementation checklist retains the full-suite gate as open
until those unrelated worktree errors are resolved.

## Documentation assessment

`tools/editor/README.md:76-98` documents runtime collider meaning and preview
behavior. `docs/tdd/editor_ui_system.md:93-97` documents the high-level Entities
layout/ownership split. There is no focused TDD for the source parser, binding
model, drift invariant, persistent backup contract, write transaction, or
failure result contract.

When the High findings are implemented, add a focused editor-entity authoring
TDD that records:

- authoritative input source paths and supported AST shapes;
- scalar binding and preservation guarantees;
- optimistic-concurrency timing;
- persistent `.bak` versus transaction-recovery ownership;
- atomicity, verification, rollback, and cleanup semantics;
- typed export outcomes and user-facing failure behavior.

This audit is evidence and prioritization, not a substitute for that durable
implementation contract.

## Remediation order

1. Replace player/projectile multi-node range rewriting with scalar expression
   bindings and preservation regressions (`ENT-H01`).
2. Move entity backup/source application onto `WorkspaceWriteTransaction` with
   a final before-replace drift check and fault-injection coverage (`ENT-H02`).
3. Normalize export failure signaling and shared-toolbar feedback (`ENT-M01`).
4. Remove filesystem work from build and blocking parser work from the UI
   interaction path (`ENT-M02`).
5. Introduce typed entity update decoding and one domain-owned change-set/
   numeric-comparison policy (`ENT-L01`, `ENT-L02`).
6. Add the focused TDD, then run `dart analyze` and the full
   `tools/editor` Flutter test suite.

## Final decision

Phase 0 closes `ENT-H01`, `ENT-H02`, `ENT-M01`, `ENT-M02`, `ENT-L01`, and
`ENT-L02`. The current bounded collider editor is appropriate for its existing
source-backed scope: valid edits preserve unrelated source, multi-file Apply is
rollback-safe, failure states are explicit, and UI interaction no longer owns
repository parsing or repeated existence checks.

This closure does not approve the advanced entity catalog editor. Creation,
identity lifecycle, broader gameplay fields, and data-first generation remain
separate future phases in the entity authoring strategy.
