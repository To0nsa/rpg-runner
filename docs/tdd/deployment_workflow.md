# Deployment workflow

## Scope and release authority

The canonical entry point is [release.ps1](../../tools/release/release.ps1).
It coordinates the configured Firebase project, web Hosting site and
Cloud Run replay worker. The root .firebaserc and firebase.json identify the
project/site; replay bucket and queue location come from the existing Functions
environment files. This workflow currently supports the configured environment,
not arbitrary project overrides or native app-store distribution.

Source targets gameplay 2026.10.2, rules-v2, score-v3 and ghost-v1 for the
furthest-progress distance fix and shared 25-world-unit metre. This source change
has not been deployed. Replay and command format remain 1. The latest
checked-in production evidence is [2026.10.1 at commit 0cb94b94](../verification/game-compat-2026.10.1-production.md),
deployed October 2, 2026. That coordinated release includes projectile auto
aim, NPC section guards and the latest Forest content, with refreshed generated
terrain and chunk patterns. The [release checklist](../building/rescue_release_operations.md)
retains the outstanding linked Play Games smoke checks.

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

## Preparation, CI and reuse

Preparation now uses a persistent component cache in the common Git checkout's
.tmp/release-cache/. Detached release worktrees share it, so deleting a release
checkout does not delete validated web/Functions artifacts or successful check
records. CacheDirectory can select a separate local/CI cache. Existing schema-1
release manifests remain historical evidence and are not reusable preparation;
use a new frozen checkout instead of rewriting those records.

Create that checkout from the authorized commit with:

~~~powershell
.\tools\release\release.ps1 -Action Checkout -Commit <release-commit>
~~~

Checkout creates/reuses .tmp/release-checkouts/<commit> with LF source bytes,
checks that an existing checkout is clean and still at that commit, and copies
only the application's .env and configured-project .env file. Credentials stay
in the user's existing SDK configuration. Run subsequent actions from the
printed checkout. Its default cache stays in the main checkout. Run one
preparation per checkout/cache key; concurrent writers fail rather than combine
incomplete artifacts.

Prepare resolves frozen dependencies only for components whose checks/builds
need to run (plus the pinned Firebase CLI when absent). Client analysis targets
lib, test and test_driver. Client checks also resolve the validator's independent
lockfile because authored-trap tests compile real worker fixtures; cached
validator results do not supply that checkout-local package configuration.
Shared packages have their own analysis/tests, so
release preparation no longer resolves the independent editor merely to analyze
unrelated sources. Editor and device integration/performance checks remain
separate task-specific gates. Production npm advisories are checked on every
backend/coordinated preparation, including cache hits, because advisories can
change without source changes.

A coordinated preparation requires these components:

- Functions emulator tests and the production TypeScript build.
- Client analysis/tests excluding device integration, and the release web build.
- Core, protocol, content-pipeline and terrain-material analysis/tests.
- Validator analysis/tests and the compiled AOT protocol-rejection probe.
- Generated-content dry-run freshness.

Node, Flutter-workspace and independent Dart-service work run concurrently;
checks within a local SDK workspace run sequentially. CI splits client tests
into four file shards on separate runners and overlaps analysis, shared-package
checks and builds. It keeps all unit/widget tests. Flutter's JSON reports and
slow-tests-<shard>.json record elapsed test durations for future optimization;
they do not replace assertions. A local cache miss runs the client suite once;
reuse avoids repeating it on the release machine.

.github/workflows/release-preparation.yml is the shared CI recipe. It replaces
the old Functions-only workflow and takes over the validator unit/AOT checks.
replay-validator.yml retains final-container health/configuration smoke,
non-root execution, strict one-CPU/512-MiB throughput and vulnerability checks.
The preparation bundle does not claim those container gates. CI uses pinned
Flutter 3.47.1, Dart 3.13.1, Node 24.16.0 and the repository's pnpm version;
a reusable bundle requires matching SDK revisions/versions locally.

To reuse a successful CI bundle on the exact clean release commit:

~~~powershell
.\tools\release\release.ps1 -Action ImportCI -RunId <successful-run-id>
.\tools\release\release.ps1 -Action Prepare
~~~

ImportCI uses gh to verify the origin repository, exact commit, workflow path,
successful completed status and push/workflow_dispatch event. Fork/PR runs,
incomplete client-shard coverage, mismatched input/toolchain hashes and modified
artifact bytes are rejected. CI artifacts expire after 14 days; already imported
local cache entries persist. Application environment files and credentials are
excluded from CI bundles. Prepare still checks the local release tuple and
project environment, restores verified artifacts, and performs the fresh audit.
When CI is unavailable or SDKs differ, local Prepare runs the same recipes.

Each component key hashes its relevant source/dependencies/tests and validation
recipe, plus SDK identity. Test-only edits invalidate validation, not production
builds. UI edits reuse backend evidence; Core/protocol edits invalidate dependent
client/validator evidence. Failed checks never publish markers. Artifact copies
are hashed, reject links, and publish complete cache entries atomically. Rebuild
reruns relevant recipes; identical inputs/toolchains producing different build
bytes block reuse until investigated.

Per-release evidence remains in .tmp/releases/<project>/<source-sha256>/:
source/contract/scope, component keys, artifact hashes, timings/logs, image and
stage checkpoints. Source fences reject edits during preparation/upload and
before production actions. Main-worktree edits cannot join a frozen checkout.
Do not relabel old omitted checks as successful current evidence.

BuildImage starts asynchronously and caches successful exact-image benchmark
results by worker inputs, project and region outside the release checkout.
Reuse re-reads the original Cloud Build status and immutable image result.
Rebuild deliberately submits another image. The strict 36,000-tick benchmark of
the final container remains required for coordinated release; it is inexpensive
and is not removed by this optimization.

## Scoped deployment

Plan reports Auto scope. Scope Coordinated can widen it; an explicit Hosting or
Backend scope cannot narrow changes that require another scope. Without a
verified local production baseline, the first release is coordinated. It must
still use a new gameplay version for deterministic changes excluded from the
last published commit; absence of a baseline is not permission to reuse a tuple.

ResumeIssuance after a successful coordinated cutover records the baseline:
runtime input hashes and contract, immutable worker image, published web hash
and ACTIVE Functions identities. It verifies worker health/100% serving traffic
and live web bytes. Subsequent scoped releases update it only after verification.
Baseline hashes include project environment/configuration, and environment
contents are never printed or uploaded into CI artifacts.

- UI/assets-only changes select Hosting; only client checks/build are required.
- Backend-only profile/account/ownership changes select Backend; Functions
  tests/build and the fresh production audit are required.
- Core, shared protocol, worker, infrastructure or tuple changes select
  Coordinated. Backend run/board/leaderboard/ghost sources are conservatively
  shared inputs because they participate in replay/projection contracts.
- No runtime change selects None and deploys nothing.

A deterministic simulation change against a baseline requires a new matching
gameCompatVersion. All scopes validate the client/backend/worker/board tuple.
Before scoped mutations, the workflow rechecks baseline Functions identities,
worker health/digest/traffic, published web hash, healthy unpaused issuer and
RUNNING replay queues. External production drift blocks the fast path.

For a scoped release the commands are Plan, Prepare, Deploy. It does not build
or deploy a worker, pause queues or change issuance policy. Backend deploys
Functions/rules/indexes under the unchanged protocol and tuple, verifies READY
indexes, ACTIVE exports and private invocation permissions; the issuer is
redeployed normally. Hosting publishes only the prepared web artifact. Successful
backend/Hosting checkpoints support retry after a later readiness failure.

Coordinated releases retain the explicit BuildImage, PauseIssuance, drain,
Deploy -CutoverReady and ResumeIssuance -CutoverReady stages below. Scoped
Deploy still requires user deployment authorization; choosing a scope supplies
no consent. Linked Play Games smoke remains a live gate after either path.
## Cutover ordering

PauseIssuance temporarily sets the deployed runsessioncreate Cloud Run service's
RUN_SUPPORTED_GAME_COMPAT_VERSIONS to release-paused. This uses the existing
compatibility allowlist: normal client versions fail before a ticket is issued.
It is a temporary compatibility gate, not an authorization or abuse-control
replacement. The pause pins the serving revision's immutable image when that
image still exists in Artifact Registry. Firebase's managed image cleanup can
remove an older image while its imported Cloud Run revision keeps serving. If
the registry explicitly reports that image missing, PauseIssuance rebuilds the
prepared issuer through Firebase with release-paused explicitly included in the
project environment for that deployment. It restores the local environment
file byte-for-byte in finally, including after failure, and checks the source
fingerprint. Permission and other registry failures stop rather than trigger
a rebuild. This paused recovery does not open normal issuance.

Pause verification reads the revision serving 100% of traffic and requires a
healthy current service revision with the explicit gate. A desired template
left behind by a failed update cannot establish a pause. Both queues continue processing while existing validation and
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
Firebase deployment suppresses inherited DEBUG output for that invocation and
restores the caller's setting afterward. Do not print Firebase login JSON:
login:list --json includes cached token fields; select account identifiers only.

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
.\tools\release\test_release_cache.ps1
~~~

The helper suite covers source/version/environment drift, artifact tampering,
project/digest fencing, blocked drain states, native failure propagation and
stderr-safe JSON. The integration suite invokes the actual entry point against
an isolated fixture with mocked CLI commands, proving issuer exclusion,
settlement-before-worker ordering, checkpoints and readiness-before-resume.
They also reject failed paused templates and split issuer traffic, verify
immutable issuer pinning, and cover missing-image recovery and environment
restoration on both successful and failed rebuilds.
Cache/CI checks exercise the preparation recipes, component invalidation,
artifact restoration/tampering, current advisory audit, failed-marker rejection,
scope/version selection, exact-run provenance, complete client-shard assembly,
bundle import and slow-test timing. The entry-point fixtures also exercise
Hosting-only deployment and backend retries while indexes build. Run all three
suites under Windows PowerShell 5.1 and PowerShell 7.
Mocks never establish live IAM, successful Firebase publication, actual container
throughput or signed-in gameplay acceptance.
