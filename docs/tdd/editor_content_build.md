# Editor content Build boundary

`ContentBuildService` owns one repository content Build or freshness check for
the editor shell. Authoring Save and generated output freshness are independent:
saving accepted source does not publish runtime constants, and generated file
presence does not prove a successful current build. The service is implemented
under `tools/editor/lib/src/build/`; the shell-neutral `ContentBuildDialog` exposes
callbacks for Save/Build, source navigation and Level repair without performing
authoring mutations itself.

## Process and report contract

The service resolves an actual Dart SDK executable and starts the repository's
`tool/generate_chunk_runtime_data.dart` with a fixed argument list and canonical
working directory, without a command shell. Missing tooling or a generator that
resolves outside the selected workspace becomes a failed report. A second job
is rejected while one is running. The caller resolves pending Save decisions and
holds its authoring-write/navigation guard for the awaited operation.

`--machine-readable` reserves stdout for protocol-version-1 JSON lines. Each
progress record contains `type: progress`, a phase, and the expected output paths
once the output plan is available. One final `type: result`
record contains the operation, outcome, captured SHA-256 input fingerprint,
included/excluded Level metadata, diagnostics, expected output paths, exact
output changes and transaction outcome. Human diagnostics remain on stderr.
`--dry-run` selects an exact read-only freshness check. Existing CLI invocations
without the flag retain human-readable output.

Phases are capturing, validating, checking_outputs, staging, committing and
verifying. Outcomes are current, drift, built, invalid, cancelled, stale and
failed. A zero process exit without a valid report is a failure. A verified
result requires the appropriate current/built outcome, successful exit, a full
input digest and no issues or transaction recovery failures. Included Levels
with no active chunks provide `included_level_has_no_active_chunks` and their
owning `levelId` so the shell can offer Open, Add content and Exclude actions.
Excluded rows offer Restore to game build with the same identity and saved rules.
These repair callbacks create accepted authoring edits; Save and the next Build
still perform their normal admission checks before publishing runtime content.

## Captured source and freshness

`ContentBuildSnapshot` captures exact bytes and the sorted set of all Level
authoring JSON, canonical atlas PNGs and parallax PNGs. It includes excluded and
deprecated source; Build still strictly parses and validates every source.
Generator Dart code, content-pipeline/material/Core source dependencies and
their package manifests are fingerprinted too. Generated Core outputs are
excluded from the input digest so publication does not invalidate itself.
Fingerprint records include paths and byte hashes, so file additions, removals,
renames and same-length image changes invalidate the capture.

The root generator's Level/theme/material and chunk readers consume captured
bytes. Compilation cannot silently mix a later on-disk source into the captured
job. Inputs must resolve inside the canonical workspace, and links found within
the scanned input trees are rejected. Generated outputs retain their existing
fixed ownership paths and exact-byte comparison rules.

The generator compares the source snapshot again before staging, after all
staged output files have been flushed and immediately before the first target
replacement. It compares sources and exact expected outputs again after
publication. Drift before replacement produces a stale result without changing
targets; drift afterward preserves `outputsCommitted: true` and does not claim
the current workspace was built successfully.

The service watches relevant source and reported output paths and conservatively
invalidates the displayed success after disk edits. It retains source changes
observed while a job is running, including the final report/process-exit window;
the generator's own staged and generated output writes do not invalidate that
job. The shell also marks local authoring edits dirty. Clearing local dirty state cannot restore a previous
success without another exact check. Manual freshness checks remain authoritative
where recursive filesystem watching is unavailable; existing output presence is
never treated as proof. Workspace replacement clears the old report and watcher.
Restart/rebuild of a running app or editor is required to
load changed generated constants. Authored Play uses its captured authoring
scenario and assets directly.

## Cancellation and atomic replacement

The editor requests cancellation by writing `cancel` on the generator's stdin.
It never kills the process. Cancellation remains available during capture,
validation, output comparison and staging. `GeneratedArtifactPlan.writeAll`
invokes `beforeReplacement` after every sibling staged file is complete; this
gate verifies the source fingerprint and cancellation once more. A rejected gate
cleans up staged files and preserves all prior generated targets.

`onReplacementStarted` announces the committing phase before the first rename.
At this boundary the generator stops accepting cancellation. The UI disables
Cancel and Close, displays **Finishing safely**, and awaits either verified
installation or rollback. Normal replacement/verification failures restore
original targets and report rollback completion. Cleanup failure after successful
installation reports committed outputs and the remaining cleanup failures.
This is the existing in-process multi-file rollback transaction, not a promise
of crash recovery after an operating-system or power failure.

If a child exits without reporting its transaction after committing began, the
service reports an unknown transaction outcome and requires a fresh check. It
does not label that state cancelled or assume unchanged outputs. Failure reports
preserve any confirmed output-commit fact from the child; they do not weaken
source admission or turn unavailable validator content into replay rejection.

Build only publishes local generated content. Application and replay-validator
artifacts must use compatible generated content. Online ticket, board and live
catalog configuration remain a separate developer-owned workflow.

## Verification

- `test/tool/content_build_snapshot_test.dart` verifies frozen bytes, source-set
  and image drift, and generated-output exclusion from input identity.
- `test/tool/generated_artifact_plan_test.dart` verifies the final source gate,
  staging cleanup, exact output checks and multi-target rollback.
- `test/tool/generate_chunk_runtime_data_test.dart` exercises real machine reports,
  pre-replacement cancellation, included/excluded summaries, owner diagnostics
  and the existing strict source/generator contract.
- `tools/editor/test/build/content_build_service_test.dart` covers single-job
  execution, fixed arguments, cancellation boundaries, absent/malformed reports,
  unsaved/freshness state and narrow Build dialog actions.
