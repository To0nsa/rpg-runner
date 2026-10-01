# Deployment workflow

## Scope and release authority

The canonical entry point is [release.ps1](../../tools/release/release.ps1).
It coordinates the configured Firebase project, web Hosting site and
Cloud Run replay worker. The root .firebaserc and firebase.json identify the
project/site; replay bucket and queue location come from the existing Functions
environment files. This workflow currently supports the configured environment,
not arbitrary project overrides or native app-store distribution.

Source currently agrees on gameplay 2026.09.10, rules-v2, score-v2 and ghost-v1.
Replay and command format remain 1. The latest checked-in production evidence
is [2026.09.9](../archive/2026-09-25/verification/game-compat-2026.09.9-production.md).
That historical evidence does not prove today's live state.
The [release checklist](../building/rescue_release_operations.md) retains the
outstanding linked Play Games smoke checks.

## Commands

Run from the repository root in Windows PowerShell 5.1 or PowerShell 7:

~~~powershell
.\tools\release\release.ps1 -Action Plan
.\tools\release\release.ps1 -Action Prepare
.\tools\release\release.ps1 -Action Inspect
.\tools\release\release.ps1 -Action BuildImage
.\tools\release\release.ps1 -Action ImageStatus
~~~

The optional root package aliases are corepack pnpm release -Action Plan and
corepack pnpm release:test. Direct PowerShell invocation is also available.

Plan reads source and prints the resolved tuple and evidence directory; it
requires Git but no cloud login. Prepare only changes local dependency/build
output. Inspect reads production and compiles the local Functions inventory
dependencies with the configured Functions environment files; it does not
change production. BuildImage uploads source and
starts a billable Cloud Build but does not deploy a service. ImageStatus records
the successful build's immutable digest, or reports that the build is running.

Only after the release is explicitly authorized and the immutable image is
ready, perform the cutover:

~~~powershell
.\tools\release\release.ps1 -Action PauseIssuance
.\tools\release\release.ps1 -Action Inspect
.\tools\release\release.ps1 -Action Deploy -CutoverReady
.\tools\release\release.ps1 -Action Inspect
.\tools\release\release.ps1 -Action ResumeIssuance -CutoverReady
~~~

CutoverReady records the operator's completed drain/cancellation review; it
does not grant authorization on the user's behalf. The script also obtains a
fresh read-only inventory and blocks on non-terminal or unknown run states,
pending reward settlement, or quarantined settlement. It does not cancel runs,
reset remote data, migrate historical replay authority, or create a canary
account. Continue the signed-in release checklist after restoring issuance.

## Preparation and reuse

Prepare first resolves root pnpm and Flutter workspace dependencies with frozen
lockfiles, then resolves the independent Dart validator lockfile. Generated
content must pass the repository generator's dry-run freshness check.

It runs three independent jobs after dependency resolution:

- Functions production dependency audit, build and emulator tests.
- Root Dart analysis, Flutter tests excluding device integration tests, and the
  release web build.
- Core, protocol and content-pipeline package analysis/tests, validator
  analysis/tests, and the compiled AOT protocol-rejection probe.

Device integration/performance tests and editor tests are separate task-specific
checks. Release image throughput is checked remotely, not by pretending that
local tests prove the container's one-CPU/512-MiB behavior.

Evidence and per-job logs live under
.tmp/releases/<project>/<source-sha256>/. A manifest records the tuple, toolchain,
prepared artifact hashes, Cloud Build ID, immutable image and deployment
checkpoints. Fingerprints include tracked and non-ignored untracked deployment
sources, authoring/assets, web inputs, test inputs, deployment scripts and
Functions environment files. Environment contents are hashed, not printed.
Compiled Functions output and web output are hashed separately.

A successful Prepare is reused only when source, toolchain and artifact bytes
still match. Use Prepare -Rebuild to intentionally repeat it. Failed jobs never
mark preparation successful, and source changes during preparation invalidate
the result. Job failures stop the remaining jobs; their logs identify the
failed slice. Run only one preparation per checkout because artifact directories
are shared.

BuildImage starts asynchronously, so agents can report progress and poll
ImageStatus without repeating a source upload. Repeated BuildImage calls reuse
the recorded build; use BuildImage -Rebuild to submit another. The checked-in
Cloud Build configuration benchmarks the exact final image with 36,000 ticks,
strict throughput checks, one CPU and 512 MiB before publishing it. CI additionally
runs image health/configuration smoke and vulnerability checks; a Cloud Build
benchmark is not equivalent to all CI gates.

## Cutover ordering

PauseIssuance temporarily sets the deployed runsessioncreate Cloud Run service's
RUN_SUPPORTED_GAME_COMPAT_VERSIONS to release-paused. This uses the existing
compatibility allowlist: normal client versions fail before a ticket is issued.
It is a temporary compatibility gate, not an authorization or abuse-control
replacement. Both queues continue processing while existing validation and
settlement drain. Do not publish another runSessionCreate revision during this
interval; Firebase deployment may overwrite the runtime gate.

Deploy verifies that gate and a freshly drained inventory, then:

1. Pauses validation and projection queue dispatch.
2. Deploys every exported Function except runSessionCreate, together with
   Firestore rules and indexes, using the repository-pinned Firebase CLI and an
   explicit project/config path. It requires all composite indexes to be READY
   before continuing.
3. Restores private invocation bindings for immediate settlement and both
   Eventarc targets; a public invoker binding blocks continuation.
4. Calls the existing configure_cloud.ps1 for the immutable worker, bucket IAM,
   resource/probe limits, queue routing and retention policies.
5. Requests leaderboard board maintenance and publishes the prepared web build.

The issuer is deliberately deployed in ResumeIssuance, after every replay
consumer is ready. Completed Functions, worker and Hosting checkpoints are saved
so a failed Deploy can be rerun with the same prepared source. Index creation
can remain asynchronous: leave issuance paused, inspect index state, and rerun
Deploy once READY. IAM checks and board-maintenance requests are repeated on
retry. Operations are sequential because accepted replay settlement and worker
compatibility depend on that order.

Deploy leaves normal issuance and both queues paused. ResumeIssuance requires
zero missing expected current/next boards in the inventory, the exact worker
digest with 100% traffic on its ready revision, and a byte-matching live
main.dart.js. It resumes the queues, deploys runSessionCreate, and removes only
the temporary supported-version override. It records artifacts deployed and
issuance resumed separately. Scheduler acceptance alone is not board completion.

If ResumeIssuance is interrupted after the issuer starts serving, inspect live
state before retrying: new sessions may now exist, and the fresh drain check will
intentionally block another compatibility cutover. Do not pause or cancel those
sessions just to make a retry pass.

## Environment, rollback and operations

Use a logged-in gcloud configuration whose directory is writable in the execution
environment, plus credentials accepted by the pinned Firebase CLI. Scripts pass
the project explicitly and do not change the operator's global CLI project or
account. They never print an access token. Keep credentials outside release
manifests; inspect configuration evidence before sharing it externally.

For restricted Windows agent processes, distinguish a missing SDK from an
inaccessible configuration. Check Get-Command gcloud and the process APPDATA,
LOCALAPPDATA and CLOUDSDK_CONFIG values before requesting another login. Restore
missing Windows paths for that invocation; point CLOUDSDK_CONFIG at the
operator's existing configuration rather than creating another credential store.
gcloud needs credential-cache access even for read-only cloud commands; use the
approved shell access path when the sandbox blocks that cache. Do not copy
credentials into the repository or reset the operator's account/project. See
[Google Cloud configuration guidance](https://docs.cloud.google.com/sdk/docs/configurations).

The October 1, 2026 audit initially failed against an inaccessible C:\gcloud
configuration. Restoring the process paths and allowing existing credential-cache
access resolved gcloud reads without another login; the live validator remained
replay-validator-00042-g9g with 100% traffic. Initial Flutter startup and local
Docker access were also limited by the execution environment; those findings
do not establish a production problem. No production resource was changed
during workflow implementation.

Retain the preceding immutable image, Functions source and Hosting version as a
coordinated rollback set. Use the [validator rollback procedure](../../services/replay_validator/README.md#projection-cost-rollout-and-rollback);
do not point old tickets at a newer Core or reset settlement/ghost lineage.
Native Android/iOS distribution remains a separate rebuilt-client release.

Monitoring deployment stays explicit through the existing scripts in
services/replay_validator/monitoring and functions/monitoring. Release preparation
does not apply alert policies or send notifications. Validator deployment retains
the existing artifact/source retention procedure in
[cloud_artifact_retention.md](cloud_artifact_retention.md).

The Firebase CLI supports scoped deployment through its
[only flag](https://firebase.google.com/docs/cli#deploy_specific_firebase_services).
Cloud Build supports
[asynchronous submission](https://docs.cloud.google.com/sdk/gcloud/reference/builds/submit#--async);
the script records the reported build result, rather than resolving a mutable
tag later.

## Verification

~~~powershell
.\tools\release\test_release.ps1
.\tools\release\test_release_integration.ps1
~~~

The helper suite covers source/version/environment drift, artifact tampering,
project/digest fencing, blocked drain states, native failure propagation and
stderr-safe JSON. The integration suite invokes the actual entry point against
an isolated fixture with mocked CLI commands, proving issuer exclusion,
settlement-before-worker ordering, checkpoints and readiness-before-resume.
Mocks never establish live IAM, successful Firebase publication, actual container
throughput or signed-in gameplay acceptance.
