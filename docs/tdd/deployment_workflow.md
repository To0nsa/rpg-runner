# Deployment workflow

## Scope and release authority

The canonical entry point is [release.ps1](../../tools/release/release.ps1).
It selects `dev`, `staging` or `prod` from
[environments.json](../../tools/release/environments.json). The registry owns the
project, region, Firebase config, replay bucket, worker endpoint, queue names and
Android package. `.firebaserc` aliases must agree; its default stays dev.
`ProjectId`/`Region` can assert the selected identity but cannot redirect it.
Cloud mutations require explicit `-Environment`; offline Plan defaults to dev.
After initial Provision creates the build bucket, cloud-mutating release actions
acquire `_release/mutation-lock.json` in that project's `<project>_cloudbuild`
bucket. Conditional generation-zero creation admits one operator across machines
and checkouts. Finally deletes only the acquired generation. A held lock blocks
before release mutations; it never expires while an operator may still work.
After a crashed operator, inspect its recorded action/machine/process and actual
cloud job state before removing that exact abandoned generation. Never clear a
lock merely because another release is waiting. Initial Provision itself needs
operator coordination because the bucket may not yet exist.
PauseIssuance/Bootstrap also claim `_release/cutover.json` for the prepared source
digest. This record survives command boundaries and failures. Deploy and resume
require the same digest; successful resume clears only its verified generation.
Thus a second candidate cannot interleave between another operator's commands.
If a candidate must be abandoned, inspect jobs, serving revisions, issuance and
queues, record the recovery decision, then remove only that exact ownership
generation before claiming replacement source. The tool never steals ownership.
Staging/prod use their project-number-based Cloud Run worker URLs. Those URLs
can be configured before service creation; deployment must still verify the
actual service, image and traffic before issuance resumes.

Only dev has a Hosting site. Staging/prod configuration deliberately has no
Hosting target; their coordinated backend releases do not publish a website.
The local web build remains preparation evidence, not proof of an Android build.
Native artifact preparation and service deployment remain in progress in the
[Android beta workstream](../building/android_beta_release.md).

`SigningSetup -Environment staging|prod` creates a separate upload key in that
project's `android-upload-signing` Secret Manager secret. The initial Windows
operator retains a DPAPI recovery copy outside the repository, in the sibling
`lothringen-secrets/<environment>/` directory (`C:\dev\lothringen-secrets` on the
release workstation). `LOTHRINGEN_SECRETS_DIR` can select another external absolute
directory; paths inside the repository or release checkout are rejected.
Retries restore and verify the existing key rather than rotating it. Only the
build scope receives a temporary keystore/password environment; finally removes
the file and restores prior process variables. Temporary keystores also stay in
the protected external directory. Never copy local secrets into `.tmp`, Git or CI
artifacts. Google Play's distribution
certificate must be registered separately after Play App Signing enrollment.

After Prepare, `BuildAndroid -Environment <name> -AndroidVersionCode <integer>`
requires a clean frozen checkout and builds a dev APK or signed staging/prod AAB.
Initialize a fresh checkout's ignored Gradle wrapper with the pinned SDK's
`flutter build apk --config-only --flavor dev --release`, then verify a clean
tracked tree before BuildAndroid. This creates configuration only; the release
action subsequently builds the requested flavor and records Gradle's identity.
The Android component input hash includes native sources/configuration, shared
app/content inputs and signing/inspection recipes. Evidence records commit,
source/input hashes, tuple, Flutter/JDK/Gradle identity, version, artifact hash,
native manifest/resources, permissions, ABIs and navigation graph integrity.
Dart symbols and available R8 mapping stay beside the artifact. Staging/prod
symbol upload targets the packaged Firebase app and must succeed before build
evidence is recorded. Dev collection/upload stays disabled. Existing
successful version evidence cannot be overwritten. Allocate codes from live Play
history; tooling cannot infer a reserved draft version from the repository.

Inspection uses pinned, hash-checked bundletool 1.18.3 and Android SDK build-tools
36.0.0. It rejects mismatched Firebase/Play Games resources, debug/test builds,
target API below 36, missing/corrupt navigation, credential files, invalid
signatures and insufficient ELF64/ZIP page alignment. A derived universal APK
is inspection-only: distribute the original AAB, never the inspection APK.
These checks follow [APK Analyzer](https://developer.android.com/tools/apkanalyzer)
and [16 KB support](https://developer.android.com/guide/practices/page-sizes).
Play-delivered auth, attestation and device/runtime checks remain separate gates.

Release-preparation CI now requires a native dev build/inspection alongside the
existing browser/component checks; Android source changes trigger it. CI receives
no staging/prod upload secrets. The authorized operator builds signed candidates
through BuildAndroid using project-local Secret Manager. CI dev evidence is not
a publishable staging/prod artifact or a production deployment authorization.

`Provision -Environment <name> -BillingAccount <id> -BudgetAmount <amountEUR>`
creates or verifies foundations without deploying gameplay. It requires explicit
billing and a positive monthly alert budget, rejects conflicting existing billing,
budget, database or bucket identities, batches API enablement, and initializes
Firebase Auth without configuring OAuth credentials. It creates project-local
service accounts, build resources and initially paused replay queues, and applies
the existing retention helper. Retries preserve existing queue state. Budgets
notify billing IAM recipients; they do not cap spending. OAuth linkage, managed
recovery, monitoring and image-dependent bootstrap remain separate release steps.

`MonitoringSetup -Environment <name> -NotificationEmail <owner>` reapplies the
existing validator, reward-settlement, abuse-control and account-deletion bundles
under the environment lock. It requires a usable project-local email channel
and reads back all 31 enabled policies. Saved configuration evidence does not
prove email delivery or deployed service health. Explicit `UNVERIFIED` blocks;
Google's omitted/unspecified state means verification is not required and is
recorded honestly, without claiming verified delivery. No verification code is
copied between projects.

`RecoverySetup -Environment staging|prod` enables Firestore PITR and deletion
protection and creates/verifies a daily managed backup schedule with seven-day
retention. It never restores or changes player documents. Existing different
retention blocks rather than being shortened. PITR history accumulates after
enablement; a configured schedule is not evidence that its first backup exists.
The small beta recovery targets are at most one minute of database loss for a
retained PITR point and four hours for operator-led service restoration; daily
backups provide a fallback with up to 24 hours of database loss. These are targets,
not a measured full-service recovery guarantee.

Rehearse on named synthetic databases in dev. Before any real recovery, pause
issuance, preserve accepted-run/reward and deletion evidence after the chosen
snapshot, restore into a new database, reconcile grants against wallet revisions
and reapply later deletions before serving players. Auth accounts, replay objects,
queues and derived leaderboard/ghost views are outside a Firestore snapshot;
verify or rebuild them from authoritative evidence before reopening. Never replay
reward grants blindly or restore an account that has since requested deletion.
Managed backups/PITR can retain deleted records for up to seven days and must be
covered by privacy disclosures. See [managed PITR](https://firebase.google.com/docs/firestore/use-pitr)
and [backup schedules](https://docs.cloud.google.com/sdk/gcloud/reference/firestore/backups/schedules/create).

For a newly provisioned, unused project, `Bootstrap -Environment <name>
-CutoverReady` replaces the first `PauseIssuance`. It requires the same prepared
source and successful benchmarked immutable image. A live read-only inventory
must show no Auth users, Firestore collections, Functions or Cloud Run services.
The action records that inventory, deploys only the issuer with the explicit
`release-paused` gate, restores local environment bytes and verifies the healthy
serving revision. Continue with normal `Deploy` and `ResumeIssuance`; all drain,
artifact and readiness gates still apply. Bootstrap never imports or resets data.
If bootstrap creates the issuer before a later failure, inspect it and recover
with normal `PauseIssuance`/`Deploy`; do not erase resources to rerun bootstrap.

First-time coordinated `Deploy -CutoverReady -EnableInitialEventRetries`
acknowledges Firebase's prompt for new retry-enabled settlement/projection event
handlers. After the ordinary prepared-image, paused-issuer and drain gates, it
reads the live Functions inventory and deploys only missing
`runSettlementOnHandoff` / `runProjectionOnAccepted` with `--force`. Existing
handlers must be active in the selected project/region with retries already
enabled; drift blocks instead of being changed. The regular full deployment,
issuer and Firestore commands never inherit this flag. Normal defaults remain
strict, and a partial successful creation is skipped on retry. This adds no new
runtime retry policy: the two idempotent handlers already declare it in source.

Functions derive their runtime and private validator-invoker service accounts
from the SDK deployment project, rejecting contradictory project variables or a
foreign validator override. Release checks validate replay bucket, region,
queues, dispatch identity and endpoint before a mutation. A project-specific
Functions environment file is required; shared `.env` values alone cannot
configure a new environment. Secrets remain outside source and evidence.

The existing project's deployed release is gameplay `2026.10.21`, deployed October 25,
2026 UTC from frozen commit `a4f99b89`. Its ranked tuple is `2026.10.21` /
`rules-v2` / `score-v4` / `ghost-v1`; replay and command formats remain 1.
The [production evidence](../verification/game-compat-2026.10.21-production.md)
records complete coordinated preparation, the 93,910-graph immutable worker
and strict benchmark, both Android APKs, the guarded cutover and live artifact
checks. All 469 accepted validations and settled grants were preserved without
cancelling runs or resetting data. Both queues and normal issuance are restored,
all six expected boards are ready, and all 30 Functions are ACTIVE.

Controlled signed-in gameplay remains unverified. The
[release checklist](../building/rescue_release_operations.md) retains linked
Play Games smoke checks. Matching universal Android Dev and release APKs were
built and inspected; the owner will install them. No phone installation or
device gameplay check was performed in this release. The
[October 18 leaderboard patch](../verification/leaderboard-level-2026-10-18-production.md)
and [`2026.10.16` release](../verification/game-compat-2026.10.16-production.md)
remain historical evidence.

The earlier [October 3 ghost cache client release](../verification/ghost-cache-client-2026-10-03.md)
published `8d7d9bdc` to Hosting under gameplay `2026.10.3` and installed a rebuilt debug
APK on the connected phone. It required no issuance pause or run cancellation;
ghost launch, cache reuse, and rendering were subsequently verified on Android.

## Commands

Run from the repository root in Windows PowerShell 5.1 or PowerShell 7:

~~~powershell
.\tools\release\release.ps1 -Environment dev -Action Plan
.\tools\release\release.ps1 -Environment dev -Action Prepare
.\tools\release\release.ps1 -Environment dev -Action Inspect
.\tools\release\release.ps1 -Environment dev -Action BuildImage
.\tools\release\release.ps1 -Environment dev -Action ImageStatus
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
.\tools\release\release.ps1 -Environment dev -Action PauseIssuance
.\tools\release\release.ps1 -Environment dev -Action Inspect
.\tools\release\release.ps1 -Environment dev -Action Deploy -CutoverReady
.\tools\release\release.ps1 -Environment dev -Action Inspect
.\tools\release\release.ps1 -Environment dev -Action ResumeIssuance -CutoverReady
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
.\tools\release\release.ps1 -Environment dev -Action Checkout -Commit <release-commit>
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

Runtime security overrides are mirrored in root `pnpm-workspace.yaml` and
`functions/package.json`: Firebase uploads only `functions/` and resolves its
production dependencies with npm. Both pin body-parser 1.x to 1.20.9 and 2.x
to 2.4.0 for [GHSA-27r3-jxmh-p828](https://github.com/advisories/GHSA-27r3-jxmh-p828).
Validate override changes with both the workspace production audit and an
isolated production npm resolution/audit outside the pnpm workspace.

Web builds are optimized local Developer Practice hosts. `client-build` uses
`--no-web-resources-cdn` so CanvasKit is served with the artifact, requires no
Firebase/App Check defines, and runs `node tools/release/web_smoke.mjs build/web`
before publishing build evidence. The smoke test uses a fresh headless Chrome
profile and a loopback server, rejects backend requests and browser exceptions,
and checks the hub, Options, run readiness and start. Chrome (or
`CHROME_EXECUTABLE`) and Node 24 are required for this component. Its script is
included in component cache inputs.

Linux CI also runs the Chrome widget tests for browser adapter selection and
local runs; the artifact-bundle job requires that job. The pinned Flutter SDK's
Windows widget-browser harness misroutes CanvasKit and escapes test paths, so
Windows preparation uses the real-artifact smoke gate instead. Native account
and coordinated backend release gates are unchanged.

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
.\tools\release\release.ps1 -Environment dev -Action ImportCI -RunId <successful-run-id>
.\tools\release\release.ps1 -Environment dev -Action Prepare
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
For matching worker inputs, `BuildImage -ReuseImageFrom <environment>` reads the
source environment's cache record, verifies its current successful Cloud Build
result and strict benchmark, then submits a source-free pull/tag/benchmark job in
the destination project. The immutable image, including its complete navigation
pack, is copied without recompilation. ImageStatus requires the destination
digest to equal the source digest and retains that provenance in release/cache
evidence. Every project retains its own registry, runtime identities and data.
Worker fingerprints cover Core/protocol sources, generator/revision tools, route
plan, dependency locks and container recipes; equal game-version strings alone
are insufficient. Android flavors share the checkout's client graph directory
and validate existing exact-key graph bytes before packaging.

The destination Cloud Build account requires `roles/artifactregistry.reader` on
only the source `replay` repository. For this beta, staging's build account reads
dev's repository; production's build account reads staging's. This does not grant
cross-project Firestore, Auth, Storage or runtime access. Missing source evidence
or permissions fails closed. A prior failed/cancelled destination job needs
explicit `-Rebuild` after inspection; a still-running source is not reusable.

Rebuild deliberately submits another image or requested copy. The strict 36,000-tick benchmark of
the final container remains required for coordinated release; it is inexpensive
and is not removed by this optimization.
Cloud Build allows 7,200 seconds for image preparation and the strict benchmark.
The expanded navigation pack exceeded the previous 3,600-second window before
image publication, so this limit covers preparation without relaxing the
benchmark or any runtime resource gate.
The Dockerfile resolves its pinned distroless runtime base before the long
navigation compilation. This avoids fetching that public registry manifest
after an hour-long build, when the build's registry credential may have expired.

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
The callable returns structured `release-maintenance` details. Obsolete clients
receive `update-required` after cutover; newer date-version clients arriving
before their backend also receive maintenance. See [run startup](run_startup.md).
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
zero missing expected current boards in the inventory, the exact worker
digest with 100% traffic on its ready revision, and a byte-matching live
main.dart.js. It resumes the queues, deploys runSessionCreate, and removes only
the temporary supported-version override. It records artifacts deployed and
issuance resumed separately. Scheduler acceptance alone is not board completion.
The inventory uses the provisioner's configured levels and current UTC windows;
future boards are created on demand and are not a readiness prerequisite.

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
.\tools\release\test_release_environments.ps1
.\tools\release\test_provision_environment.ps1
.\tools\release\test_release_integration.ps1 -TestEnvironment staging
.\tools\release\test_release_integration.ps1 -TestEnvironment prod
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
Hosting-only deployment and backend retries while indexes build. Foundation
checks cover isolated provisioning, idempotent Auth setup, paused new queues,
preserved existing queues and conflicting billing/budgets. Run these
suites under Windows PowerShell 5.1 and PowerShell 7.
Mocks never establish live IAM, successful Firebase publication, actual container
throughput or signed-in gameplay acceptance.
