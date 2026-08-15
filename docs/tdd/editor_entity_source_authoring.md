# Editor Entity Source Authoring

Date: August 16, 2026
Status: Implemented current collider-editor contract

## Scope

The Entities route is a bounded editor for existing player, enemy, and
projectile collider values plus the already-supported anchor, render-scale,
and cast-origin fields. It is not a general entity creator and does not own
gameplay catalogs, identity creation, behavior scripting, or asset generation.

`EntityDomainPlugin` remains the authoring boundary. It loads an immutable
`EntityDocument`, derives an `EntityScene`, validates candidate edits, previews
the exact planned patches, and applies them through the repository transaction
primitive. Runtime Dart remains authoritative until the later data-first entity
authoring phases are implemented.

## Authoritative inputs

The parser reads the current supported shapes from:

- `packages/runner_core/lib/enemies/enemy_catalog.dart`;
- every Dart file under
  `packages/runner_core/lib/players/characters/`;
- `packages/runner_core/lib/projectiles/projectile_catalog.dart`;
- the projectile render catalog and enemy/projectile render registries;
- player render tuning and Core spatial-grid tuning.

The parser records ordinary unsupported or missing source shapes as validation
issues. A loaded document may remain inspectable, but any error-severity issue
blocks Apply.

Repository reads and Dart parsing run in a worker isolate. Referenced image
existence is resolved once during parsing into canonical
`assets/images/...` paths stored on the document and scene. Widget build and
scene-drag paths consult only that immutable set; they do not probe the
filesystem.

## Binding and edit contract

Every writable collider number owns an `EntityColliderScalarBinding` covering
only its expression. Player and projectile catalogs store full dimensions, so
their half-extent bindings convert editor units to source units with a factor
of two. Enemy collider source already stores half extents and uses a factor of
one. An absent offset binding means that offset is read-only and must remain
unchanged.

Anchor expressions may retain their proven expression shape by rewriting only
the scalar operand. Other supported values likewise use the narrowest captured
source expression. Planning rejects overlapping edits, an unexpected snippet,
or any source that differs from the loaded binding. Text outside the edited
scalar ranges—including comments, argument order, unrelated expressions, and
formatting—is byte-preserved.

The UI emits one typed `EntityUpdate`. Its four collider values are an atomic
group; optional values are accepted only when the selected entry has a writable
binding. Known commands with malformed payloads, non-finite numbers,
incomplete anchor pairs, missing targets, or attempts to change a read-only
field fail deterministically before document history changes.

`EntityNumericPolicy` owns equality for scene gestures, no-op command
suppression, dirty detection, pending planning, and export verification. The
current absolute tolerance is `0.000001`. `EntityChangeSet` is the single list
of editable-field differences consumed by pending and export code.

## Optimistic concurrency and transaction

Pending preview and Apply use the same export plan. Apply performs these steps:

1. validate the complete candidate document and build narrow source patches;
2. stage every patched source and every persistent `.bak` as one
   `WorkspaceWriteTransaction` artifact set;
3. in `beforeReplace`, immediately before any target moves, require every
   planned source to equal the plan's complete original bytes;
4. install and byte-verify the complete artifact set;
5. reparse the installed entity sources and verify the changed definitions
   while transaction rollback is still available;
6. remove transaction-owned recovery files only after verification succeeds.

Any drift or failure before verified commit rolls the whole artifact set back.
This includes restoring a persistent `.bak` that existed before Apply. A normal
successful Apply leaves one user-visible `<source>.bak` containing the exact
pre-Apply source. Files named `.authoring-<transaction>-*.bak` or `.tmp` are
transaction-owned recovery evidence, not the user-visible backup contract.

## Export outcomes and recovery

`ExportResult.outcome` distinguishes four states:

| Outcome | Repository state | UI behavior |
| --- | --- | --- |
| `noChanges` | No files written | No failure feedback |
| `validationFailed` | Candidate rejected before persistence | Immediate validation failure plus diagnostic artifact |
| `sourceDrift` | Loaded/planned source no longer matches disk | Immediate reload/review failure plus diagnostic artifact |
| `failed` | Planning/persistence failed and rollback completed | Immediate Apply failure plus diagnostic artifact |
| `rollbackIncomplete` | Apply failed and recovery did not restore every target | Immediate Apply failure plus exact recovery paths |
| `applied` | Outputs committed, verified, and cleaned | Reload canonical source and report success |
| `appliedWithCleanupRequired` | Outputs committed and verified; recovery cleanup incomplete | Reload canonical source and show recovery paths |

A cleanup failure after verified commit must never be reported as a failed or
rolled-back Apply. Conversely, validation, planning, drift, installation,
rollback, and verification states must remain distinguishable from a normal
no-op. The session controller exposes typed failure messages through
`exportError`, so the shared toolbar and Entities page do not infer failure
from artifact names.

## Interaction invariants

Inspector text remains page-local until **Apply Values** emits a typed command.
Route changes, reload, and app exit include that local draft in the shared
discard guard. Once inspector values enter session history, the page rebases
its draft baseline so Undo and Redo project the restored snapshot instead of
misclassifying stale text as a new draft. Scene handle drags apply coalesced
commands; pointer-up, primary-button loss, and pointer-cancel close one undo
unit. Hit tests use the same viewport geometry as the painter, and a pointer
sequence outside a handle does not create history.

## Verification evidence

Focused tests cover scalar preservation with reordered and interleaved source,
final drift, first/middle/last installation failures, verification rollback,
pre-existing persistent backups, cleanup-required reporting, typed command
rejection, numeric tolerance, cached asset availability, shared Apply failure
feedback, scene hit testing/pointer cancel/coalesced undo, and guarded local
draft reload behavior.
