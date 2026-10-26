# Android beta execution evidence

Status: in progress, October 26, 2026. No new environment deployed yet.
The active checklist is [android_beta_release.md](../building/android_beta_release.md).

## Initial state

Source inspected: `f0aa66d8`, repository root `C:\dev\rpg_runner`.
Initial edits: the untracked release plan and its two documentation-index links.
No staged edits or unrelated source modifications.

Read-only live CLI checks used the existing authenticated operator credential
cache (outside Git). `gcloud auth list`, project list, billing account list and
the existing project's billing association succeeded. The open **Firebase
Payment** account is the existing project's billing account. Other projects and
the closed billing account are outside this workstream.

`gcloud run services list`, `tasks queues list`, `scheduler jobs list` and
`firestore databases list` against `rpg-runner-d7add` / `europe-west1` show:

- worker ready revision `replay-validator-00058-94k`;
- issuer ready revision `runsessioncreate-00071-wx8`;
- validation/projection queues both RUNNING, each capped at five concurrent
  dispatches and five dispatches/second;
- nine enabled scheduled maintenance jobs;
- default native Firestore database in `eur3`, pessimistic concurrency, PITR
  disabled and one-hour version retention. This is inventory, not recovery proof.

`gh auth status` verifies repository access. Browser inventory via the Chrome
control integration returned no connected browsers; setup instructions supplied
to the owner. The subsequent Windows Computer Use retry succeeded; see the
console and project foundation evidence below.

## Authorization and waiver

The October 26 execution request authorizes all necessary plan-scoped projects,
billing linkage, IAM, secrets, signing, CI, deployment, maintenance and beta
publication. It excludes general public distribution and unrelated deletion.
Only the owner's existing development game data may be discarded if necessary.

Traversal/navigation/content-quality failures are non-blocking for this initial
release, with exact failure evidence required. No gameplay failure waiver has
been consumed. Replay integrity/determinism, missing
assets, authentication, isolation, builds and deployments remain blocking.

## Environment-routing milestone

Implemented registry and explicit mutation selection, Firebase aliases and
separate configs, environment resource validation, project-specific configuration
requirement, project-derived Functions runtime/private-invoker identities, and
dev-only Hosting. Staging/prod IDs were initially proposed and later created below.
Release input hashing includes Android and environment definitions. Git file
enumeration disables pathname quoting so accented asset paths remain usable.

Validation from the repository root on the milestone subsequently committed as
`c1d11dbd07803e2545683221fac15f76a917b69a`:

- `corepack pnpm --dir functions build` and `build:test`: pass.
- `node --test functions/lib_test/test/deployment_identity.test.js`: 5 pass.
- `corepack pnpm --dir functions test`: 257 pass, zero failures/skips. The first
  sandboxed invocation could not read Firebase CLI configuration; the rerun with
  existing credential/emulator-cache access passed. Transient log:
  `.tmp/beta-checks/functions-tests.log` (credential diagnostics redacted).
- `test_release_environments.ps1`: 29 checks pass on PowerShell 5.1 and 7.
- `test_release.ps1`: 32 checks pass on PowerShell 5.1 and 7.
- `test_release_cache.ps1`: 48 mocked checks pass on PowerShell 5.1 and 7.
- `test_release_integration.ps1 -TestEnvironment <dev|staging|prod>`: all six
  runs pass on PowerShell 5.1 and 7 (87 dev checks and 82 each staging/prod).
  Logs: `.tmp/beta-checks/integration-<powershell|pwsh>-<environment>.log`.
  These exercise actual entry-point sequencing against mocked commands,
  including project selection and no staging/prod Hosting publication.
- `node tools/agents/check.mjs` and `git diff --check`: pass.

Live `release.ps1 -Action Inspect -Environment dev -CacheDirectory
.tmp/beta-inventory-cache` succeeded. Inventory observed at
`2026-10-26T20:36:13.893Z`, stored under
`.tmp/releases/rpg-runner-d7add/eec4b43c0a3591ee0c55667da341cc4b3d895e7f981345b37070b3f5ae9af35c/`.
It reports one player, 469 accepted runs, 469 settled grants, no pending or
quarantined settlement. Historical findings include 18 grants without sessions
and one ghost with invalid source lineage; no reset/repair was performed.

The main Windows checkout's CRLF bytes differ from the earlier LF release
baseline, so its default Plan rejected simulation input hashes. Git comparison
against `a4f99b89` shows no new simulation implementation/content changes, only
instruction files in that input area. This inspection uses an isolated scratch
cache; the actual release must use the canonical LF frozen checkout and verified
baseline. No gameplay-version bump or weakening of the simulation fence was made
to hide line-ending differences.

## Empty-target bootstrap and live foundation work

Added `release.ps1 -Action Bootstrap -Environment <name> -CutoverReady`.
It requires prepared artifacts and a successfully benchmarked immutable worker
image, verifies no Auth users/Firestore collections/Functions/Cloud Run services,
and creates only a verified paused issuer. Normal Deploy/ResumeIssuance gates
still apply. No destructive reset or cross-project import is implemented.

Local validation of the uncommitted bootstrap milestone, repository root:

- `test_release.ps1`: 38 checks pass on PowerShell 5.1 and 7.
- `test_release_cache.ps1`: 48 pass on both shells.
- `test_release_environments.ps1`: 29 pass on both shells.
- `test_release_integration.ps1 -TestEnvironment <dev|staging|prod>`: all six
  runs pass, 93 dev and 88 each staging/prod. An initial empty-array handling
  difference between PowerShell versions was corrected and both retested.
- `node functions/tool/bootstrap_inventory.mjs --project rpg-runner-d7add`:
  live read-only success at `2026-10-26T20:57:46.706Z`, both existence flags true.
  This verifies dev is rejected as an empty bootstrap target. Initial end-user
  credential quota-project error was resolved with the explicit matching header.
- `node tools/agents/check.mjs` and `git diff --check`: pass.

Live project operations completed October 26:

| Environment | Project / number | Observed result |
| --- | --- | --- |
| Dev | `rpg-runner-d7add` / `964001571974` | Display name updated to Lothringen Long Run - Dev; existing services/data retained |
| Staging | `lothringen-long-run-staging` / `943085064373` | Created, existing billing linked, Firebase enabled |
| Prod | `lothringen-long-run-prod` / `696550437718` | Created, existing billing linked, Firebase enabled |

Billing readback is enabled on both new projects. No project-ID suffix was
needed. API enablement requires batches of at most 20; the initial larger batch
was rejected before enablement and is being retried in smaller batches.

Windows Computer Use successfully inspected signed-in Chrome. Personal Play
developer account `8150014461378797161` has the Long Run draft app
`4975420968170292531`; its internal track is inactive and draft bundle library
is empty. No artifact/version code was uploaded or released. Console reports
zero opted-in closed testers and requires 12 testers for 14 continuous days for
public access. Internal testing is available; closed testing still needs app
setup. Signing certificates and Play Games configuration remain to be inspected.
The owner explicitly reconfirmed three environments after discussing overhead.

## Foundation provisioning and Android preparation

Bootstrap implementation is committed as `91dd4978`. Subsequent source includes
the independent sign-in/deletion fix `f5075eed`; no final candidate is frozen.

`release.ps1 -Action Provision -Environment <staging|prod> -BillingAccount
<existing-account> -BudgetAmount <25EUR|50EUR>` completed with live readback on
October 26. Staging completed at 21:32:05Z and prod at 21:35:57Z after Auth
initialization was added. Local logs are `.tmp/beta-checks/provision-*-auth.log`.
Neither environment has game Functions or a worker service yet.

- Native Firestore in `europe-west1`, deletion protection enabled.
- Project-specific replay and Cloud Build buckets, uniform access, public
  access prevention, seven-day soft deletion; existing retention helper applied.
- Project-local replay registry, run-control/validator/task-dispatch identities,
  scoped runtime roles and queue enqueuer grants. No new owner/editor grant.
- Both queues initially PAUSED at five concurrent dispatches/five per second;
  retries preserve existing queue state.
- EUR25/month staging and EUR50/month prod budgets, actual 50/90/100% and
  forecast 100% alerts. Default billing IAM recipients; these are not cost caps.
- Firebase/Identity Toolkit Auth initialized. The first existence-only check
  failed with `auth/configuration-not-found`; initialization resolved it.
- Live `node functions/tool/bootstrap_inventory.mjs --project <project>` passed:
  staging 21:35:13Z and prod 21:36:52Z, both `hasAuthUsers=false` and
  `hasFirestoreCollections=false`. These are inventories, not bootstrap runs.
- Environment `.env` files are ignored, explicit and isolated. Staging/prod
  select abuse and App Check enforcement; no auth/attestation bypass is enabled.

`test_provision_environment.ps1` passes 30 mocked checks on PowerShell 5.1 and
7, covering all environments, retries, Auth initialization, foreign billing/
budget rejection, API batch limit and identity isolation. An initial scalar
`.Count` test bug was corrected; logs `provision-test-<powershell|pwsh>.log`.
The full required release regression matrix also passes on both shells: 40
helper/syntax checks, 48 cache checks, 29 isolation checks, and 93 dev / 88
staging / 88 prod entry-point checks. Logs use the `foundations-` prefix.
Agent guidance and diff checks pass. CI now runs the same environment/provisioning
checks; its hosted execution has not yet been triggered for this milestone.

Android worktree validation from the repository root:

- `flutter test test/firebase_environment_test.dart
  test/ui/bootstrap/app_services_test.dart test/ui/bootstrap/ui_app_startup_test.dart`:
  19 passed; `.tmp/beta-checks/android-environments.log`.
- Targeted Dart analysis: no issues; `android-environments-analysis.log`.
- Gradle `:app:processDevDebugGoogleServices :app:processDevReleaseGoogleServices
  :app:processStagingReleaseGoogleServices :app:processProdReleaseGoogleServices`:
  BUILD SUCCESSFUL; `android-flavor-resources.log`. This verifies configuration
  selection, not signed APKs or online authentication.

Play Console rejected `com.example.rpg_runner.staging` as already in use and
reported `com.lothringen.longrun.staging` available. The initial new Firebase
registration used the rejected package and must be superseded before build.
Created the separate Long Run Staging draft listing, app ID
`4975698862921375548`, with package `com.lothringen.longrun.staging`, English
(United Kingdom), Game, Free. No bundle uploaded or release published.
Owner supplied Finland, ages 16+, `lothringen.rpg@gmail.com` support/deletion
contact. Age audience does not establish the IARC rating.

## Remaining acceptance

Android identities, Play distribution signing, freeze/build/deployment hashes,
real Play auth/attestation, device acceptance, recovery rehearsal, capacity and
store review/publication are pending. Do not infer completion from authorization.

## Upload signing and release gate checkpoint (October 27 local time)

Foundation source is committed as `2e272c40`. Staging's corrected Firebase app is
`1:943085064373:android:51c288ba51386d01572efc`, package
`com.lothringen.longrun.staging`. Its genuine Google Services configuration is
downloaded and its upload SHA-1/SHA-256 registered. The earlier unused registration
was preserved. Staging Play Games is linked to project `943085064373`; consent,
OAuth clients and Firebase provider linkage are still pending. Computer Use
stopped when a newly opened Google OAuth tab's URL could not be verified; no
subsequent browser input was sent.

`release.ps1 -Action SigningSetup -Environment <staging|prod>` created separate
4096-bit RSA upload keys, backed them up in project-local Secret Manager secret
`android-upload-signing`, verified downloaded bytes, and retained Windows DPAPI
recovery copies under ignored `.tmp/release-signing/<environment>/`. Plaintext
passwords/payloads are absent from Git and logs. Owner recovery is through the
project Secret Manager or the original Windows profile's DPAPI copy. Repeating
setup restored the same certificate without rotation. These are upload keys;
Google Play's installed-app certificates still require enrollment/readback.

| Environment | Upload certificate SHA-256 |
| --- | --- |
| Staging | `AB46F14DC351DCCAFFA431F129BC95F2926C42AAC0DDD9BE5BF96F2BF84596C9` |
| Prod | `6934F381B5CAB46CED0084CB4DD7E6691EE84A4BE98987FF09CE2882B36B67A4` |

Live logs: `.tmp/beta-checks/signing-setup-*.log` and `signing-retry-*.log`.
`test_android_signing.ps1` passes eight mocked checks on PowerShell 5.1/7:
environment mismatch and byte tampering rejected; build failures preserve their
error, restore process environment and remove temporary key material; dev does
not request a cloud key. These tests use fake bytes, not live secrets.

The uncommitted release policy work now distinguishes an obsolete client
(`failed-precondition`, `update-required`) from paused issuance or an early future
client (`unavailable`, `release-maintenance`). Update opens only that flavor's
listing, keeps the server gate enforced, and leaves support/exit available.
Existing run submission/recovery is retained. Repository-root local evidence:

- `flutter test test/ui/run/run_release_gate_test.dart
  test/ui/run/run_start_preparation_test.dart
  test/ui/pages/hub/run_start_bootstrap_page_test.dart
  test/ui/state/firebase_run_session_api_test.dart test/firebase_environment_test.dart`:
  25 pass; `release-gate-client.log`.
- `flutter test test/ui/runner_game_widget_startup_test.dart
  test/ui/state/app_state_run_submission_test.dart
  test/ui/state/run_submission_coordinator_test.dart`: 35 pass;
  `release-gate-recovery.log`.
- `corepack pnpm --dir functions build` and `build:test`, compatibility tests:
  pass; full `corepack pnpm --dir functions test`: 259 pass;
  `release-gate-functions-emulator.log`.
- Targeted Dart analysis passes after fixing an initial style finding. A first
  test fixture omitted the required Firebase exception message; corrected before
  the successful rerun. No gameplay/traversal failure has been waived yet.
