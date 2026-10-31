# Reward pipeline rework, October 31, 2026

Implementation and local verification are complete at
`ef0d87b5deb995740ba6f078caeab5f96ffda5ea`. This work preserves the existing UX,
verified gold/XP authority, gameplay tuple and navigation inputs. No cloud
deployment, phone installation or new live latency measurement was performed.

The [workstream plan](../building/reward_verification_latency.md) retains the
separate dev rollout and live acceptance gates. The
[two-run phone capture](reward-latency-phone-2026-10-31.md) is the pre-change
baseline, not evidence of these changes' latency or cost.

## Source and behavior

The work started from clean `e85626c7`; implementation milestones are
`818ce588`, `85941805`, `1da90497` and `ef0d87b5`.

- Submission recovery preserves completed uploads, consults server state after
  ambiguous responses/restarts, serializes journal changes and retries interrupted
  finalization without uploading again. Final receipts remain until canonical
  account acknowledgement. Short transient retries retain quota-aware backoff.
- One additive `runSubmission` callable handles grant/finalize/status. Existing
  endpoints remain available. Upload permission is prepared during real run
  activity with bounded, owner-bound caching and expiry renewal; hub-only ticket
  prefetch does not prepare grants or send keepalive traffic.
- Settlement writes an owner-readable completion receipt in the same transaction
  as gold, XP and canonical account state. Foreground exact-document listeners
  deliver confirmed state, with revision/account fencing and polling fallback.
  Account deletion and retention include receipts. No provisional spendable
  reward or presentation change was introduced.
- Eventarc is the normal settlement path. Private HTTP dispatch remains an
  explicit rollback mode. Durable tasks continue pending validation, settlement
  and account deletion; hourly safety scans remain independent of queue health.
  Lost enqueue responses, duplicate delivery, stale leases and deletion fences
  retain their existing authority boundaries.
- Function registration stays synchronous while domain imports are deferred to
  handlers. Shared clients are reused. Worker deployment explicitly configures
  automatic scaling, zero service/revision minimums and request-based billing.
  No always-on compute or artificial warming was added; hourly maintenance still
  incurs usage, so this is not a claim of a zero total idle bill.

Implemented contracts are recorded in
[reward completion](../tdd/reward_settlement_operations.md),
[account deletion](../tdd/account_deletion_workflow.md),
[Functions](../tdd/firebase_cloud_functions_overview.md),
[worker delivery](../tdd/replay_validator_worker.md) and
[deployment](../tdd/deployment_workflow.md).

## Local and mocked validation

Raw logs and artifact inspection output are in ignored
`.tmp/pipeline-rework-20261031/`. Counts below overlap across milestones and
must not be summed into a unique-test total. Firebase checks used the local
Firestore emulator and demo project, not deployed services. Release checks
mock cloud commands and do not establish live IAM or queue state.

| Scope | Commands / working directory | Result and evidence |
| --- | --- | --- |
| Backend compilation and suite | Root: `corepack pnpm --dir functions build`, `build:test`, `test` | Full 311-test suite passed in `functions-full.log` before the final deletion enqueue-outage refinement. |
| Final deletion/queue changes | Root: Functions `firebase emulators:exec --config ../firebase.test.json --project demo-rpg-runner-functions-tests --only firestore` running `node --test lib_test/test/pending_work.test.js lib_test/test/account/account_delete_callable.test.js` | 23/24 passed, including the new queue-outage regression; one assertion expected the old health-result shape. After correcting that expectation, `node --test --test-name-pattern=reports lib_test/test/account/account_delete_callable.test.js` passed both selected tests. Logs: `final-deletion-recovery.log`, `deletion-health-final.log`. The unchanged passing cases were reused. |
| Final endpoint registration | `functions/`: `node --test lib_test/test/index_registration.test.js` | Both checks passed, covering synchronous discovery, deferred imports, min-zero/private metadata, event enqueue failures and task retry wiring; `final-registration.log`. |
| Settlement/receipt authority | Root: focused Functions emulator tests | 65 settlement/deletion/rules tests and 58 retention/projection/contract tests passed. The Dart decoder consumes the fixture produced by the real TypeScript settlement transaction. Logs: `completion-emulator.log`, `completion-retention-contract.log`. |
| Client integration | Root: `flutter test --no-pub` over the 12 affected client test files | 130 passed, including UI consumers, receipt decoding, account replacement, receipt/finalize overlap and offline resume; `completion-consumer-tests.log`. Affected app/run/test analysis passed in `completion-analysis.log`. |
| Final client recovery | Root: `flutter test --no-pub test/ui/state/run_submission_coordinator_test.dart test/ui/state/app_state_run_submission_test.dart` | All 44 passed after the last recovery changes; targeted analysis clean. Logs: `final-recovery-client.log`, `final-recovery-analysis.log`. |
| Replay worker | `services/replay_validator/`: `dart analyze`, `dart test test`, `dart compile exe bin/server.dart -o ../../.tmp/pipeline-rework-20261031/replay_validator_server.exe` | Analysis clean, all 304 tests passed, executable compiled. Logs: `worker-analysis.log`, `worker-full.log`, `worker-compile.log`. |
| Release tooling | Root: `tools/release/test_release.ps1`, `test_release_integration.ps1`, `test_release_cache.ps1`, under Windows PowerShell and PowerShell 7 | Helper 62, integration 121 and cache 56 checks passed under each shell. Includes actual worker-configuration script mocked to verify scaling/billing/delivery mode, private pending-work IAM and queue-pause separation. Logs: `release-{helper,integration,cache}-ps{5,7}.log`. |
| Guidance and documentation | Root: `node tools/agents/check.mjs`, `git diff --check`, changed-document relative-link check | Passed. Documentation-only follow-up does not change tested runtime inputs. |

The Flutter checks used the installed SDK's `flutter_tools.snapshot` directly
where the batch launcher stalled. The native APK build resolved root workspace
dependencies normally. Only Firestore and its two platform packages were added;
Flutter generated native plugin registration. Toolchain: Flutter 3.47.1,
Dart 3.13.1, Node 24.22.1, Java 21.0.10.7 and Gradle 9.3.1.

## Dev Android artifact and navigation reuse

Root command `flutter build apk --debug --flavor dev` passed
(`assembleDevDebug`: 817.0 seconds). This is a standalone local native integration
check, not a frozen release artifact or an installed build. No staging/prod
artifact was built.

- Path: `build/app/outputs/flutter-apk/app-dev-debug.apk`.
- SHA-256: `225c4f2d190cb6df693b77add863f677b21cc71b5163c65302bd17326aa68638`.
- Size: 287,615,342 bytes.
- Package: `com.example.rpg_runner.dev`; version `1.0.0-dev-debug`, code `1`;
  debuggable; packaged Firebase project `rpg-runner-d7add`.
- `apkanalyzer` checked the manifest and packaged project resource;
  `apksigner verify --print-certs` passed with the Android debug certificate
  SHA-256 `001f8fe8d465d47b2aa1264fd8a00ac2221875aeef17ce1bfad5d1bf6d91f061`.
- Build log: `dev-debug-build.log`; inspections: `dev-debug-artifact.json` and
  `dev-debug-AndroidManifest.xml` in the raw-evidence directory.

The accepted navigation pack was reused from verified dev APK 4 source
`8a094efb67a9f8e988940206c73b830765142248`. The diff for navigation inputs against
that source was empty. Every graph's hash and size was checked before reuse;
the final `dart run packages/runner_core/tool/prepare_navigation.dart --client`
pass reused 3,750 graphs and built zero. ZIP inspection then verified the exact
packaged graph set and all hashes/sizes: 3,750 graphs, 30,911,144 graph bytes,
manifest SHA-256
`6f65c41f501cc9618ecefd8ae3349d037656aacb567935ab81268f8639a812bd`.
The worker navigation pack was not rebuilt.

An earlier standalone attempt mistakenly used the root checkout's stale pack
and regenerated 3,650 graphs before it was stopped. It was not accepted as
reuse evidence. The verified pack above replaced it before the successful
producer/build checks. Logs retain both attempts: `client-navigation-reuse.log`
and `client-navigation-seeded.log`; provenance is in `client-navigation-seed.json`.

## Remaining acceptance

Dev deployment must use the repository's coordinated release workflow, a frozen
candidate, current source-bound preparation, private handler/queue IAM checks
and live baseline gates. The APK above does not replace those release gates.
Earlier approval to cancel five specific tickets does not authorize new
cancellations. No cloud or account mutations occurred during this work.

After an authorized dev rollout, repeat correlated cold/warm phone measurements
and verify offline/response-loss recovery, account switching and unchanged
gold/XP presentation. There is no measured post-change latency, cost reduction,
p95 result or target-phone performance claim yet. Existing route coverage and
authored-terrain findings remain open in the workstream plan.
