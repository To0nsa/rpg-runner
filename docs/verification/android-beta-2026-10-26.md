# Android beta execution evidence

Status: in progress, October 29, 2026. Frozen c8b is deployed to dev and staging;
bounded dev-device smoke passed. Play-delivered staging acceptance and production
deployment remain open. Staging version 1 is published to the owner-only internal
track and installed through Play; owner sign-in, enforced real Play Integrity,
run/reward, leaderboard/ghost and post-settlement restart checks pass. Dated
sections below retain their historical scope.
The active checklist is [android_beta_release.md](../building/android_beta_release.md).

## External secret storage and staging OAuth (October 27)

On the owner's instruction, local credentials moved to
`C:\dev\lothringen-secrets/<environment>`, matching Pikkuretki's sibling-folder
pattern. The directory allows only the operator and SYSTEM. Both upload-signing
DPAPI backups and DER certificates retain their original SHA-256 file hashes.
The staging OAuth JSON was DPAPI-encrypted there, decrypted in memory and compared
before removing its exact plaintext download. No keys were rotated. Historical
`.tmp/release-signing` references below describe the previous location.

SigningSetup and BuildAndroid now use the external directory, including temporary
build keystores; absolute `LOTHRINGEN_SECRETS_DIR` overrides are rejected inside the
common repository/current checkout. A trailing newline in DPAPI files is trimmed
before decryption. Repository-root checks on these changes atop `1d1297da`:
`test_android_signing.ps1` (12), `test_release.ps1` (50),
`test_release_integration.ps1` (97), and `test_release_cache.ps1` (53) all pass under
Windows PowerShell and PowerShell 7. Logs: `.tmp/beta-checks/external-secrets-*`.
These are mocked/local tests, not release deployment evidence. Agent guidance
validation also passes (32 files, maximum chain 27,369/28,672 bytes).

Staging Google Auth Platform is External/Testing with the owner as the sole test
user. Its web client is
`943085064373-cgchd3tftpkgv4f30q01k3aqblqa5vls.apps.googleusercontent.com`.
Project-local Secret Manager backup `play-games-oauth-client` was read back and
compared in memory. Firebase REST provider `playgames.google.com` was enabled and
read back with that client at `2026-10-27T15:30:20Z`. A prior 403 reported a missing
quota project; the documented `X-Goog-User-Project` header resolved it without
additional IAM grants. The explicitly approved `games`, `games_lite` and
`drive.appdata` scopes were saved in staging's non-sensitive scope list. Play
credential linkage and device sign-in still require their own verification.
The confirmed Finland/90-day support-retention text also passes the separate
headless 390-pixel layout probe for both public pages. No candidate is frozen
and no waiver was used.

After the next authorized resumption, Chrome read back all three saved scopes
from the loaded staging page. Play Games saved draft server credential
`CgkItaGAorkbEAIQAA` using the same web client. The genuine Android config was
downloaded with `firebase apps:sdkconfig ANDROID
1:943085064373:android:51c288ba51386d01572efc --project lothringen-long-run-staging`
and checked for the expected project, app, package and type-3 client before
replacing the staging source file. Its native server-client resource now agrees.
`flutter test test/firebase_environment_test.dart` passes all four cases on these
changes atop `6a511535`; log `.tmp/beta-checks/staging-oauth-native-config-test.log`.
The first sandboxed invocation produced no output and was stopped; the successful
invocation used installed-SDK access. This does not prove Play/device sign-in.

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

## Native artifact and managed recovery checkpoint

Signing milestone is `f3d1c471`. The native build/inspection and recovery helpers
are still uncommitted. Required mocked matrix passes on PowerShell 5.1/7: 46
syntax/helper checks, 48 cache checks, 29 environment checks, 11 artifact checks,
nine managed recovery checks and 93/88/88 dev/staging/prod entry-point checks.
Logs use `.tmp/beta-checks/android-pipeline-*`. Hosted CI is not yet run.

The first `flutter build apk --flavor dev --release --no-pub` failed after 606s
because GeneratedPluginRegistrant referenced excluded `integration_test` Java.
The installed Flutter 3.47.1 source confirms `--no-pub` skips release-mode plugin
regeneration. Retrying `flutter build apk --flavor dev --release` succeeded after
754s. The native release recipe now permits regeneration and rejects source/lock
drift after the build. Flutter's already-ignored machine-specific plugin metadata
is removed from the index; the local generated file is retained.

`Test-AndroidArtifact` inspected this uncommitted-source APK (before Crashlytics
was added), not a final frozen build:

- Package `com.example.rpg_runner.dev`, version `1.0.0-dev` / code 1, API 36,
  min API 24, non-debuggable release mode.
- Firebase app `1:964001571974:android:1a4b98db937af313d81d07` and existing dev
  Play Games server client match compiled resources.
- All 3,750 navigation graphs match the prepared manifest's byte lengths/hashes;
  manifest SHA-256 `24529810f7d414c9e0e1047e28c24fb443ad02048634a8e0cc98ee5bd84359f8`.
- ARM32/ARM64/x86_64 present, nine native libraries, ELF64 and APK ZIP alignment
  pass 16 KB checks. Signature verified. APK size 188,445,473 bytes, SHA-256
  `83dac2d4efeb26a3fdf56d985d57f66ce0d315949e261a192cddad4069db9bb2`.
- Initial inspection falsely treated case-distinct optimized resource names as
  duplicates; ZIP comparison now respects case. Full inspection passes in
  `.tmp/beta-checks/android-dev-inspection/inspection.json`.

`release.ps1 -Action RecoverySetup -Environment <staging|prod>` completed live:
staging `2026-10-26T22:26:02.7798762Z`, prod `22:26:55.0468881Z`. Both report PITR
enabled, deletion protection and daily backups retained 604800 seconds. Schedule
IDs: staging `81659924-f26a-43fe-b285-9704c055a957`; prod
`55808bbe-c641-43f6-bdcc-851524241e63`. Logs `recovery-setup-*.log`. This proves
configuration only; history is accumulating and no scheduled backup completion
has yet been checked.

Created isolated dev database `beta-recovery-20261027-source` in europe-west1,
with PITR enabled, for a synthetic reward/deletion restore. Creation operation
completed. Initial ADC access was denied; the CLI-token adapter then needed the
Firestore transport's matching Google Auth version. No existing player data or
Auth records were modified. Seed succeeded at `2026-10-26T22:41:23.024Z` using
the real compiled settlement and deletion guard. Managed PITR clone of the
`22:42:00Z` snapshot to `beta-recovery-20261027-restored` ran from
`22:43:03.869808Z` to `22:54:13.001927Z` (11m09s, SUCCESSFUL). At `22:59:07.820Z`,
the restored wallet retained 75 gold/revision 1 and one applied grant; another
settlement returned `already_settled` without changing state. The restored
deletion tombstone rejected account access and no deleted-user ownership existed.
Logs: `recovery-rehearsal-seed-final.log`, `recovery-rehearsal-clone-status.log`,
`recovery-rehearsal-verify.log` under `.tmp/beta-checks/`.

Both synthetic databases were deleted after verification. Live database-list
readback in `recovery-rehearsal-final-databases.json` shows only `(default)` in
eur3; that database was untouched. Deletion operations and their retained PITR
metadata are recorded in `recovery-delete-*.log`. This rehearsal proves database
restore, duplicate-settlement safety and the deletion barrier for the fixtures;
it does not restore Auth, Storage objects, queues or measure full-service RTO.

The subsequent dev AAB probe with Crashlytics failed after 1058s: the Gradle
daemon could not allocate native memory. Its former limits allowed an 8 GB heap
and 4 GB metaspace on a 16 GB workstation. The build now uses 4 GB heap, 1 GB
metaspace and two workers. Retry succeeded after 939s. The task's orphaned,
idle Kotlin compiler daemon was identified by its crashed Gradle parent and
stopped to release memory; unrelated processes were preserved. After successful
completion the task's idle Gradle daemon was also stopped.

`Test-AndroidArtifact` then passed on the dev AAB with Crashlytics included:
bundletool validation, complete upload-key signature, 16 KB bundle/ELF/derived
APK alignment, all navigation assets and actual Firebase/Play resources. The
174,472,156-byte AAB SHA-256 is
`4aa75501015de4be475506394fafc8cdd45664ac46a3e6da58a5225caeb37e1f`;
package/code/API/certificate match the earlier dev probe. Evidence is
`android-dev-bundle-retry.log` and
`android-dev-bundle-inspection/inspection.json`. This is still unfrozen source,
not a candidate or Play publication. The first direct inspection invocation
omitted `release_cache.ps1`; loading that required helper resolved the invocation
error without changing the artifact.

Environment locking passes 13 focused checks and 97/92/92 entry-point checks on
PowerShell 5.1 and 7 (`cutover-*` logs). Concurrent actions cannot acquire another
operator's lock; the source-bound maintenance record prevents interleaving
candidates across commands and survives failure until verified resume. Initial
staging monitoring exercised live acquisition/finally cleanup. Agent guidance
and diff checks pass; native CI has not yet run remotely.

Monitoring is incomplete. Both projects have 15 enabled validator/settlement
policies at `2026-10-26T23:32Z` and enabled project-local owner email channels:
staging `5051742138447933000`, prod `16298104619394512183`. Their verification
status is omitted, not `UNVERIFIED`. The new wrapper initially misclassified
that response and stopped before abuse/deletion setup. Google's
[NotificationChannel contract](https://docs.cloud.google.com/monitoring/api/ref_v3/rest/v3/projects.notificationChannels)
treats omitted/unspecified status as usable without verification; the wrapper
now preserves that state honestly and still rejects explicit `UNVERIFIED`.
Eight focused monitoring tests pass on PowerShell 5.1/7, including the omitted
field, foreign channels and disabled/duplicate policies. Final reconciliation
completed with 31 enabled policies per project: staging at
`2026-10-26T23:43:42.3232672Z`, prod at `2026-10-26T23:51:56.1608590Z`.
Both project-local mutation locks were released successfully. Evidence is
`.tmp/releases/<project>/monitoring/monitoring.json` and
`.tmp/beta-checks/monitoring-final-<environment>.log`. Fixed empty-API handling
and selected-project dashboard queries in the
existing helpers. Automatic
approval review rejected copying dev's verified email status across projects;
that operation was not executed and its temporary script was removed. The
initial request for project-specific email verification was withdrawn after
checking the API contract. No verification code was requested/copied, no channel
verification state was changed, and no verified alert delivery is claimed.
First backup inventory reports zero backups in both
new projects (`backups-*.json`).

Artifact/operations milestone is
`d9909a3e4d7d6cbb56dd5b149166ca25728a7b45`. The moved repository's canonical
remote is `https://github.com/To0nsa/rpg-runner.git`. Its `master` was 42 commits
behind the current intended local source and not ahead. Automatic approval
review rejected the direct default-branch push as broad publication of that
history; it did not execute. The safe alternative published
`release/android-beta-environments` and opened
[draft PR #2](https://github.com/To0nsa/rpg-runner/pull/2), without merging.

Hosted validation of PR merge source
`e79860977206b7c42b29e833b12af340736dc1d2` (head `d9909a3e`) has passed all
release-preparation components, including all four client-test shards and the
real built-web smoke test. Separate guidance and PowerShell tooling workflows
passed. The final validator-image job is still running at this checkpoint.
These PR results are validation, not importable final release
evidence or proof of deployment.

The Linux browser job in
[release-preparation run 40421473512](https://github.com/To0nsa/rpg-runner/actions/runs/40421473512)
passed four tests and failed
`web boots, opens options and plays a recorder-free local run`. Its default
reporter omitted the underlying widget exception. The recipe lacked the ignored
client navigation assets required to load a run; added preparation before the
browser tests and expanded output for diagnosis on retry. The canonical Linux
preparation recipe now does the same, and its cache key includes the navigation
generator/route inputs. `test_release_cache.ps1` passes 53 mocked checks on
PowerShell 5.1 and 7 (`browser-recipe-cache-ps*.log`). Hosted verification of the
change is pending; the failure is not waived or reported as fixed yet. A local
Windows browser-test attempt produced no diagnostic output and was interrupted;
the pinned SDK's previously recorded Windows harness limitation still applies.

The Android job failed after 7m14s of Gradle compilation in
`:battery_plus:compileReleaseKotlin` and `:firebase_core:compileReleaseKotlin`.
The complete artifact log identifies `IllegalArgumentException: this and base
files have different roots`: the default Pub cache is on C:, checkout on D:.
CI now uses the action's documented
[`pub-cache-path` input](https://github.com/subosito/flutter-action/tree/v2#caching)
to keep plugin sources on the checkout drive. Compiler checks and incremental
compilation remain enabled. Full log:
`.tmp/beta-checks/ci-40421473512-android/build.log`; retry is pending.

Recipe changes committed as `a492f1efdd3dc87b4553eeba54b3e67349a458d9`.
Both PowerShell versions also pass 50 release checks and 97 mocked entry-point
checks (`browser-recipe-release-ps*.log`, `browser-recipe-entry-ps*.log`).
The browser job in retry run `40423207090` still fails the same startup case
after successful navigation preparation. Expanded reporting still lacks the
underlying framework exception, so the test now forwards full exception details
through `printOnFailure` while preserving the original failure reporter, and
attaches loading state/error/stack if readiness is not reached. Targeted
`dart analyze test/ui/bootstrap/web_practice_startup_test.dart` passes. This
diagnostic change does not remove assertions, extend the wait or waive the gate.

External account-deletion page source is prepared at
`web/account-deletion.html`; it is not published or registered in Play Console.
It uses the owner's confirmed support/deletion email, describes the existing
double-confirmation in-app flow, keeps requests scoped to the chosen environment,
and discloses primary deletion versus recovery/log/diagnostic retention. The
public privacy policy still needs the legal operator identity/country and the
support-correspondence policy. No privacy placeholder is deployed.

Read-only `gcloud logging buckets list --location=global --project=<project>
--format=json(name,retentionDays,locked,lifecycleState)` confirms `_Default`
retention 30 days and locked `_Required` retention 400 days in both new projects;
all buckets are ACTIVE. Evidence: `.tmp/beta-checks/log-retention-*.json`.
No retention was changed by that inspection.

Native Android job `121922433760` in retry run `40423207090` passed on PR merge
source `18cafbccdeef6effda310ffb33176aa41e23fa20` (head `a492f1ef`). The actual
dev release APK build and complete native artifact inspection succeeded after
moving the Pub cache onto the checkout drive. It is CI validation, with the
runner's dev key, not the owner's final installable candidate.

The retained inspection is
`.tmp/beta-checks/ci-40423207090-android/android-ci.json`: package
`com.example.rpg_runner.dev`, code 1, min/target SDK 24/36, correct dev
Firebase/Play resources, 3,750 navigation graphs, three ABIs and 16-KB alignment.
APK SHA-256 `9b235f96f7a0a3be35d8f1caa5e5376ddf99ea494ff9a0cfdae574f119a682ed`,
188,861,430 bytes; runner certificate
`011d2d7c54cd24d41a29738e18f64aca176f8d55949f29f98af071d938e8bc6b`.
Its LF-checkout navigation manifest hash is
`6f65c41f501cc9618ecefd8ae3349d037656aacb567935ab81268f8639a812bd`.
The retained artifact contains inspection/build evidence, not an APK intended
for tester installation. The runner certificate does not replace the registered
owner dev certificate.

The first Replay Validator job `121916696570` in run `40421473569` was cancelled
at its 30-minute job limit. It was still generating required offline graphs,
reporting 76,790 graphs/7,750 windows at 1,757.361 seconds before cancellation.
No compiler error or traversal test failure was reported. CI now has the same
bounded 120-minute allowance as `cloudbuild.yaml` and one active workflow per
ref. The complete image, runtime smoke, strict one-CPU/512-MiB benchmark and
Critical/High vulnerability gate are retained; none is waived.

The superseded validator run `40423207049`, still using the insufficient old
limit, was explicitly cancelled after the replacement was submitted; its actual
final status is `completed/cancelled`. Corrected workflow source is commit
`3aad1cc8365dcedbffb70a2c0e2e5ded9619c600`.

Browser diagnostics in run `40425121438`, job `121928835561`, now expose the
failure: readiness remained at `RunLoadPhase.parallaxMounted`, with null
error/stack and the loading screen still visible. The exact assertion was
`Expected: exactly one matching candidate` / zero `ReadyOverlay` widgets.
The test originally mounted the route on the fake test clock,
then only yielded real asynchronous time afterward. It now mounts the route and
pumps its bounded loading loop inside `tester.runAsync`; this follows the
[Flutter asynchronous test guidance](https://api.flutter.dev/flutter/flutter_test/WidgetTester/runAsync.html).
The limit remains 1,200 iterations with 16-ms simulated frames and 10-ms real
yields. Asset loads, readiness, real simulation ticks and game-over assertions
are preserved. Hosted run `40426008765` still fails at `parallaxMounted` without
a reported error. The clock hypothesis is therefore unconfirmed; this change
does not establish a fix. All component jobs pass, including the independently
built web smoke test. The browser widget gate remains failed, not waived.

The five Android launcher exports now derive from
`docs/release-assets/android/long_run_icon.svg`, with a separate 512 px Play icon.
The brand references were read from `C:/dev/Lothringen/Brand/`. Rendering used
resvg-js 2.6.2 installed only under ignored `.tmp/icon-renderer`; app dependencies
are unchanged. XML parsing, PNG dimensions/alpha and 512/48 px visual inspection
pass. The Play image is 6,389 bytes with fully opaque alpha. No upload occurred.
At 00:39 UTC, `adb devices -l` returned an empty device list.

The corresponding feature graphic is a 1,024 × 500 RGB PNG (34,349 bytes),
rendered from its SVG with the existing Cinzel font. Dimensions, full opacity
before RGB encoding, and visual layout pass inspection. It is title artwork,
not a gameplay screenshot. Play upload and actual Android screenshots remain
pending.

### Validator CI and browser gate continuation

[Validator run 40426008703](https://github.com/To0nsa/rpg-runner/actions/runs/40426008703)
on PR merge `31db307e37f44dcfd3e611dc1df48f408e311188` (branch source
`7d1d1268`) completed successfully at 00:51:52 UTC October 27.
The final image passed configured/unconfigured HTTP smoke checks and the strict
36,000-tick benchmark at one CPU and 512 MiB. Seed 4401 produced deterministic
outcomes in both levels: Forest 0.723795 seconds, Field 0.574230 seconds, with all
eight gates true. The fixture excludes combat/objectives; this is not full-game
device performance evidence. Trivy 0.74.0, using its freshly fetched database,
found zero Critical/High OS vulnerabilities; it found no language-specific files
to scan. Application dependency audits remain separate required checks.
CI image manifest `sha256:1a22d003cc6f518351db0a70d0d4dc65c8427fb08f9d429b2990749bc262032e`
was built on the runner only; it is not a deployed project image.

Isolated diagnostic source `6d000021` was pushed to
`release/android-beta-browser-check` and dispatched as release-preparation run
`40428392923`, preserving the long validator job. Its browser case again failed
at `parallaxMounted`: zero completed load tasks and all 23 requested images still
pending (player, parallax and terrain/prefab atlases). No missing-file exception
was reported. This records the observed harness failure, not a proven SDK cause.

The asset-backed gameplay assertions are moved to mandatory `web_smoke.mjs`,
which now checks exit confirmation and the Practice-only game-over screen as
well as actual readiness, live timer, local-only Options, no exceptions and no
backend requests. Browser widget tests retain bootstrap and descriptor checks.
No readiness/asset assertion or gameplay failure is waived. Targeted Dart
analysis and Node syntax checks pass. Expanded smoke against the existing
October 25 local web artifact passes (`browser-runtime-gameover.log`); this is
an exploratory harness check, not fresh-source release evidence. CI rebuild and
the revised browser suite must pass before this gate is considered resolved.
The Windows widget-harness retry remained at test loading and was interrupted;
it produced no passing or failing test result.

The release syntax/helper, cache/provenance and actual-entry-point mocked checks
were rerun after the smoke-script change: 50, 53 and 97 pass respectively on both
PowerShell 5.1 and 7. Logs: `.tmp/beta-checks/browser-host-*.log`. No cloud mutation
or SDK build is performed by those mocked checks. Fresh-source CI is dispatched
on `f9015c3d` as run `40429577996`; the source is not frozen for release.

That [fresh-source run](https://github.com/To0nsa/rpg-runner/actions/runs/40429577996)
completed with all 16 jobs successful. All five browser tests pass; the actual
release web build also passes readiness, live simulation, exit confirmation and
Practice game-over with no exceptions/backend requests. Build/smoke log retained
under `.tmp/beta-checks/ci-40429577996-client-build/`. This resolves the browser
release gate through explicit coverage relocation, without waiving a failure.

The native dev APK inspection from the same source passes, now including the
game launcher icon: 188,861,342 bytes, SHA-256
`4e8606f34f186ae9bf8c9d89ffde7718ac6e48ff7b543dedc95a12f73736011c`, input digest
`5fcd808b30b203aa645354e99bc355c2baaff65946e4f137cfcbd04c951487ed`.
It retains the correct dev IDs, API 36, 3,750 navigation graphs, three ABIs and
16-KB alignment. Its ephemeral CI certificate is not the owner's installed-app
identity, and CI uploads inspection evidence rather than a deliverable APK.
Readback: `.tmp/beta-checks/ci-40429577996-android/`.

Subsequent Options privacy/support links use the shared dev Hosting policy path
and confirmed support email, preserve navigation when an external handler fails,
and remain visible alongside local Practice settings. Targeted analysis passes;
`flutter test test/ui/pages/options/options_page_test.dart
test/ui/bootstrap/developer_mode_ui_test.dart` reports four passes and one
pre-existing `DEVELOPER_PRACTICE` launch-flag-only skip. Logs:
`privacy-links-analysis.log`, `privacy-links-tests.log` under `.tmp/beta-checks/`.
The full CI run above predates these UI edits; final-candidate checks still apply.
The privacy destination is not published and live link acceptance is pending.

At 01:21 UTC the canonical `ImportCI -RunId 40429577996 -Environment dev`
completed successfully from
`.tmp/release-checkouts/f9015c3d7dd028ac61bfcacc74f3e0f0ae50884d`.
All ten components were verified and imported to shared `.tmp/release-cache`.
This is an LF validation snapshot, not the final release candidate. Its worktree
and the original checkout remain separate; subsequent UI changes are not claimed
as covered by that CI run. Log: `.tmp/beta-checks/ci-import-40429577996.log`.

System Node is 24.22.1 while CI is pinned to 24.16.0. For exact provenance,
downloaded the official Node 24.16.0 Windows x64 ZIP and verified SHA-256
`edaca9bd58ec8e92037dac4e877d52f6b8f430b81c18b57e264b4e2fb111cd56`
against `https://nodejs.org/dist/v24.16.0/SHASUMS256.txt`. The isolated SDK lives
under `.tmp/toolchains/node-v24.16.0-win-x64`; prepend it to the release process's
PATH and restore PATH in `finally`. The system installation was not changed.
Its bundled Corepack selected the pinned pnpm 11.22.0 and CI import passed the
existing strict toolchain checks. Do not weaken those checks to reuse evidence.

Resume from implementation commit `c8323e39` and the active checklist. All CI jobs
submitted during this continuation have finished (the superseded diagnostic run
is cancelled; the final preparation and validator runs succeeded). No cloud job
or release mutation is pending. The account browser stopped on URL verification;
resume it only after the user loads the staging OAuth page. Needed factual input:
legal operator name/country and support-mail retention. A physical Android device
is needed for the unrun Play sign-in, Integrity, side-by-side, lifecycle and
performance checks. No traversal waiver has been used. No final release commit,
install link or production acceptance is claimed.

### Privacy source and browser resumption (October 27, 05:45 UTC)

Owner supplied `Nicolas Louis` as the operator. Country and support-mail retention
were asked separately and remain pending; the store market does not establish
operator residence. Prepared `web/privacy-policy.html` with the confirmed name,
contact, actual data purposes, lawful-basis map, recipients/transfers, retention,
rights and deletion access. It contains no scripts, tracking resources or forms.
Support correspondence currently uses a purpose-based retention description;
the owner's fixed period must be incorporated before publication.

Rechecked official [Firebase privacy information](https://firebase.google.com/support/privacy)
and the [EDPB rights guide](https://www.edpb.europa.eu/sme/be-compliant/respect-individuals-rights_en).
Corrected the deletion page to distinguish Firebase Authentication's up-to-180-day
provider removal window from the game's seven-day recovery copies. These pages
remain unpublished; source or a screenshot does not prove a working public URL.

Validation from the root checkout based on `ad71432b`, with only these policy/docs
edits: Python HTMLParser confirmed balanced markup, one H1 per page, no active
embedded content, and existing relative link targets. Inspected a desktop render
and both phone renders from isolated headless Chrome profiles without user
accounts. `.tmp/beta-checks/privacy-layout.mjs` used actual 390-pixel mobile
emulation and confirmed `scrollWidth == innerWidth == 390` for both pages.
Screenshots are `privacy-desktop.png`, `privacy-policy-mobile.png` and
`account-deletion-mobile.png` under `.tmp/beta-checks/`. An initial CLI
`--window-size=390,844` screenshot was clipped by Chrome's minimum desktop window
size; the explicit emulation resolved the probe limitation, with no CSS fix
needed. External legal links were read; email delivery was not tested.

Native browser inventory succeeded, but Chrome reported Gmail as the selected
tab despite the earlier OAuth-page reply. Automatic approval review blocked
native accessibility capture and the browser-state fallback to prevent reading
unrelated private email. Neither request returned email content. Asked the owner
to reselect the staging OAuth tab; no credential or console changes were made.
The report of no verification emails does not reopen channel verification:
omitted/UNSPECIFIED status is usable as recorded above. Delivery remains untested.

Fresh `gcloud firestore backups list --project=<staging|prod> --format=json
--quiet` at 05:45 UTC returned `[]` for both projects (exit 0). First completed
scheduled backups remain unverified. Existing recovery configuration/rehearsal
evidence is unchanged. No candidate, deployment, Play upload or waiver is claimed.

Android/runtime implementation milestone committed as
`aac4d7f662dcd8268494993e3d990cd794646c61`. The commit includes the genuine flavor
configs, project/App Check guards, maintenance/update UI, Crashlytics handlers,
dependencies and Android memory fix. The native probes used these runtime bytes
before the commit; artifact source is still not the final release candidate.

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

## Staging Play signing and Android credentials (October 27)

Play Console's signing page for app `4975698862921375548` reports Google-managed
App Signing in use with zero installed users. Its downloaded `certificates.zip`
contains three signing certificates, matching Google's current quantum-ready
enrollment. No signing key was changed. The archive and extracted public DER files
are retained in `C:\dev\lothringen-secrets\staging`, outside every checkout.
The upload key remains a separate identity.

| Certificate | SHA-1 | SHA-256 |
| --- | --- | --- |
| Classic | `7B1DC37D7E16EA26B374ED635F23276CCA4FA63E` | `6272EA6A975B3A59283153010BE2AD3F53E958897E34FD034A797D8ACBBD842F` |
| Hybrid classical | `FBDF0AD7A141F198B4471666B9BF7D25A2454E33` | `8ADCA0CB69362D4453F5B1F43BC3B5B74CD22CA1254E05472C68CEEDA4B54D90` |
| Hybrid PQC | `187EDE06AA5FDBE1E47E83C1E81543E603E102DC` | `45BB21C4FB4CBF7D81BBCA9B9ABD6B2664AB7CAE44A562CD182F1DD78F9046FC` |

Registered and verified all six hashes through Firebase Management's SHA API for
app `1:943085064373:android:51c288ba51386d01572efc` at
`2026-10-27T15:57:40.801Z`, preserving the upload-certificate registrations.
Play Integrity's linked Cloud project was read back as `943085064373` only,
with a 10,000/day API quota. This does not establish an accepted device verdict.

Created and read back these Android OAuth clients in that staging project; all
use package `com.lothringen.longrun.staging`. Each is saved as a separate draft
Play Games credential with player-facing name `Long Run Staging`.

| Certificate | OAuth client ID | Play Games credential |
| --- | --- | --- |
| Classic | `943085064373-1oepm623hb1hjdts2pg8h6qiiug8nvrv.apps.googleusercontent.com` | `CgkItaGAorkbEAIQAQ` |
| Hybrid classical | `943085064373-fsq59kpq3mi3bu2h5mo9muritttb100k.apps.googleusercontent.com` | `CgkItaGAorkbEAIQAg` |
| Hybrid PQC | `943085064373-dsfa2d8fjhjeuhngkripiqrkv9cqi520.apps.googleusercontent.com` | `CgkItaGAorkbEAIQAw` |

The classic credential remains the default for new installs. Saved games and
additional Recall storage remain off. The Console's optional Firebase link is
for Analytics and is not required for the configured Firebase Auth provider;
it remains unused. Existing server credential `CgkItaGAorkbEAIQAA` binds the
separate web client recorded above. Google's publication review now reports the
credentials ready. Saved the prepared description, Action category, 512-pixel
icon and 1024-by-500 feature graphic; both uploaded previews were inspected.
Console then reported ready to publish. Automatic approval review rejected the
final Play Games service publication because the service becomes available
beyond the tester list and some settings become irreversible. The owner has
been asked for that specific approval; it is pending. No publication was made.

Downloaded genuine native config with `firebase apps:sdkconfig ANDROID
1:943085064373:android:51c288ba51386d01572efc --project
lothringen-long-run-staging --out .tmp/beta-checks/staging-sdkconfig-play-signing.json`.
Verified project/app/package and all three certificate-client mappings before
updating `android/app/src/staging/google-services.json`. Root command
`flutter test test/firebase_environment_test.dart` passes all four tests on
`5b1f9092` plus this config change; log
`.tmp/beta-checks/staging-play-signing-config-test.log`.
This is configuration evidence, not the frozen candidate or installed-app
acceptance. No Play bundle or backend deployment has occurred in this step.

## Production branded identity and server OAuth (October 27)

The current Play creation flow reserved `com.lothringen.longrun` in new Long Run
listing `4975092661531994619` (English UK, Game, Free). The previous empty March
draft `4975420968170292531` remains untouched; no package or bundle was attached
to it. The production flavor, release registry and client identity now select
the branded package. Firebase app `1:696550437718:android:c27d2030dcee3fd2d9dcf7`
is genuinely registered in `lothringen-long-run-prod`; the earlier provisional
registration remains intact. Its existing upload certificate was registered and
read back at `2026-10-27T16:44:33.0378265Z`.

Production OAuth is External/Testing, with only the owner as a test user. Saved
and read back the approved `games`, `games_lite` and `drive.appdata` scopes.
Created web client
`696550437718-6n2bu175hk96rn77o8cob7ht6pcr2h4s.apps.googleusercontent.com` without
web origins or redirect URIs, as required for the Play Games server credential.
Its secret is verified in `C:\dev\lothringen-secrets\prod\oauth-client.dpapi` and
production Secret Manager `play-games-oauth-client`. The temporary plaintext
download was removed only after encrypted readback matched. No secret appears
in source or evidence. Firebase's enabled `playgames.google.com` provider was
read back with this client at `2026-10-27T16:56:08.5943861Z`.

The same client is saved as draft Play Games server credential
`CgkI1uaQ7aIUEAIQAA`, named Long Run. Play Integrity readback lists only project
`696550437718`, with the default 10,000/day quota. Downloaded genuine Firebase SDK
configuration includes the server client and matches the production app/package.
The explicit native resource uses that same client.

Validation on `dcc0d891` plus this identity change, from the repository root:

- `flutter test test/firebase_environment_test.dart`: four pass;
  `.tmp/beta-checks/prod-identity-tests.log`. A sandboxed wrapper stalled before
  starting Dart; stopped that invocation and reran with access to the SDK cache.
- `test_release_environments.ps1` on Windows PowerShell 5.1 and PowerShell 7:
  29 checks pass each, no cloud commands; `prod-identity-environments-ps51.log`
  and `prod-identity-environments-ps7.log` in `.tmp/beta-checks`.
- From `android`, `gradlew.bat :app:processProdReleaseGoogleServices --console=plain`:
  succeeds in 49 seconds. Generated `project_id`, `google_app_id` and
  `default_web_client_id` match production. Log: `prod-google-services-gradle.log`.

These checks do not establish a frozen candidate, APK/AAB acceptance, device
sign-in, attestation, service deployment or Play publication. Production Android
distribution credentials and both environments' App Check registration remain
open. The staging Play Games publication approval is still pending.

## Production distribution credentials and beta App Check (October 27)

Downloaded the production listing's public signing archive and retained it as
`C:\dev\lothringen-secrets\prod\play-certificates-20261027.zip`, alongside the
three extracted public DER certificates. The current signing page's SHA-256
matches the classic certificate below. No signing key was changed.

| Certificate | SHA-1 | SHA-256 |
| --- | --- | --- |
| Classic | `9562EBFC414E79B77D728C607FD7D81BE50C90E1` | `3065A34ECE1F52D82E639F4A9C2279CB059B066D56CB44B83CE800FE3362101F` |
| Hybrid classical | `B19F3C1189540F4CD8AAFCEBCCEA633E1860A190` | `7BC33DF610B1A88CBCF33BB78F4C5BDBD611DC071906DF3ACEDE776BDA3BBC26` |
| Hybrid PQC | `0517642013243D8D564073408BC4D40099FB595A` | `1D104D96BCA39F8C07CF79D4D756B099C2551109B943C49A882CF464F66F0804` |

All six hashes are registered in production app
`1:696550437718:android:c27d2030dcee3fd2d9dcf7`, read back at
`2026-10-27T17:03:21.6775100Z`. Each Android OAuth client uses only
`com.lothringen.longrun` and its corresponding SHA-1:

| Certificate | OAuth client ID | Draft Play Games credential |
| --- | --- | --- |
| Classic | `696550437718-tjm4uk58s63e8t5hdgk6036bbciuaq97.apps.googleusercontent.com` | `CgkI1uaQ7aIUEAIQAQ` |
| Hybrid classical | `696550437718-mhlhcochb7kamr4v25jpem7psee5v40o.apps.googleusercontent.com` | `CgkI1uaQ7aIUEAIQAg` |
| Hybrid PQC | `696550437718-uj86l62iod8rrnnmijmm65g8ti0rk8av.apps.googleusercontent.com` | `CgkI1uaQ7aIUEAIQAw` |

All three Play Games links are saved as Long Run. The classic remains the default
for new installs; the other two default-selection boxes remain unchecked.
Refreshed genuine SDK configuration includes all three mappings and the existing
server client. Root `flutter test test/firebase_environment_test.dart` passes
four tests on `0e07756f` plus this configuration change; log
`.tmp/beta-checks/prod-play-signing-config-test.log`.

Explicitly registered the selected staging and production apps through
[App Check's documented Play Integrity update API](https://firebase.google.com/docs/reference/appcheck/rest/v1/projects.apps.playIntegrityConfig/patch).
Set one-hour tokens and `allowUnrecognizedVersion=false`, preserving other
settings. Readback timestamps are `2026-10-27T17:10:05.6401612Z` staging and
`2026-10-27T17:10:13.6473892Z` production. Firebase Console independently reports
both intended packages as Registered with Play Integrity. The unused provisional
registrations remain unchanged. The API omits the false boolean in its response;
the documented default requires Play recognition. Existing device/account
settings were preserved, not weakened. These registration checks do not prove
device attestation or Play-delivered sign-in. Logs are
`.tmp/beta-checks/staging-appcheck-registration.json` and
`.tmp/beta-checks/prod-appcheck-registration.json`.

`adb devices -l` still reports no attached device. Production Play Games metadata,
tester readback, publication, Play artifacts, deployed acceptance and device
checks remain open. No gameplay waiver has been used.

## Current-board release readiness integration (October 27)

Source: `a577bed8` plus the current-board inventory/resume/cache correction.
The completed board lifecycle implementation provisions current windows only;
the release inventory previously required future windows as well. It now derives
current expected IDs from the same provisioning configuration. A missing current
board still rejects resume before either queue resumes. Future-only fixtures
cannot satisfy readiness. The inventory regression runs after the Functions
build, and both inventory source/test changes invalidate cached build evidence.

Commands ran from `C:\dev\rpg_runner`, with logs under `.tmp/beta-checks`:

| Command | Result | Log prefix |
| --- | --- | --- |
| Pinned Node 24.16.0 `--test functions/tool/production_inventory.test.mjs` | 4 pass | `current-board-inventory-tests` |
| `tools/release/test_release.ps1` | 51 pass on PowerShell 5.1 and 7 | `current-board-release-ps51`, `current-board-release-ps7` |
| `tools/release/test_release_integration.ps1` | 102 dev checks pass on both | `current-board-integration-ps51`, `current-board-integration-ps7` |
| Same with `-TestEnvironment staging` | 97 pass on both | `current-board-staging-ps51`, `current-board-staging-ps7` |
| Same with `-TestEnvironment prod` | 97 pass on both | `current-board-prod-ps51`, `current-board-prod-ps7` |
| `tools/release/test_release_cache.ps1` | 56 pass on both | `current-board-cache-ps51`, `current-board-cache-ps7` |

All logs use `.log`. `git diff --check` passes. These tests mock cloud commands;
the inventory subprocess replaces network access and uses no real credentials.
No deployment or gameplay waiver occurred. The installed Firebase CLI's scheduler
update uses explicit configuration field masks, preserving the existing dev
scheduler pause; read its actual state again during cutover and resume only after
the matching worker is healthy.

## Frozen candidate and console continuation (October 27)

Candidate `ad759adbe96444d379d8b4e038732e8074897696` is frozen in the canonical
LF checkout under `.tmp/release-checkouts`. `Checkout` copied the selected dev,
staging and production application environment files separately. Each offline
`Plan` resolves Coordinated with the unchanged `2026.10.21/rules-v2/score-v4/ghost-v1`
tuple. Logs: `.tmp/beta-checks/candidate-plan-{dev,staging,prod}.log`.

Pushed the existing continuation branch and dispatched exact-source
[release preparation run 40550912893](https://github.com/To0nsa/rpg-runner/actions/runs/40550912893).
The first web-build job compiled successfully, but its subsequent smoke failed
before browser connection: `Timed out: Chrome debugging port`. This is not a
gameplay waiver or a passing build gate. Other jobs are still running; inspect
and retry the isolated browser startup failure before accepting CI evidence.
Logs: `candidate-ci-client-build-job.log` and
`candidate-ci-client-build/client-build-0/client-build.log` under `.tmp/beta-checks`.

Saved and read back production Play Games metadata: Long Run, prepared 897-character
description, Action category, game icon and feature graphic. Both image previews
were inspected. Next-generation IDs remain On; Recall storage without a profile
and Saved games remain Off. This saved draft is not service publication.

Production internal track `4700923082088337056` currently has no releases.
Read back existing Toonsa list membership as the sole owner email, then selected
and saved that list for this track. Console confirms Select testers complete.
Its future install URL is `https://play.google.com/apps/internaltest/4700923082088337056`;
the Console marks it unavailable until publication. No artifact is uploaded yet.
Production's scheduled-backup listing is still empty at this checkpoint;
`prod-backups-20261027-candidate.json` records that readback. Device checks remain
pending, with `adb devices -l` reporting no device.

Both Play Games Testers tabs independently show the owner email as the sole
tester with access to saved drafts. Production service metadata is ready; service
publication approval remains pending separately from internal app publication.
Live `bootstrap_inventory.mjs --project <project>` from the candidate reports no
Auth users or Firestore collections in staging at `2026-10-27T17:39:42.902Z` and
production at `2026-10-27T17:39:47.598Z`. These preliminary readbacks do not replace
Bootstrap's fresh checks. Candidate `Inspect -Environment dev` completed at
17:34:59 UTC: three current boards, none missing, zero sessions/profiles following
the owner's completed erasure, and the board-maintenance scheduler still PAUSED.
Logs: `candidate-bootstrap-inventory-{staging,prod}.json` and
`candidate-inspect-dev.log` under `.tmp/beta-checks`.

The first candidate CI finished with 14 passing jobs, including the Android
build/inspection and all client shards. Only the compiled-web Chrome startup
failed; the dependent bundle did not run. It is not accepted preparation evidence.
During fresh-checkout preparation, inspection found a separate required packaging
gap: cached Prepare restores `build/web`, while ignored `assets/navigation`
files are absent. `BuildAndroid` now resolves the frozen workspace and runs the
existing client navigation producer before signing/packaging. Preparation failure
blocks both. No traversal behavior or tolerance changed.

On `ad759adb` plus this packaging correction, both
`powershell.exe -NoProfile -File tools/release/test_android_artifacts.ps1` and
`pwsh -NoProfile -File tools/release/test_android_artifacts.ps1` pass 15 checks,
including cold-checkout success ordering and failure-before-signing behavior.
Logs: `cold-android-ps51.log`, `cold-android-ps7.log` under `.tmp/beta-checks`.
Release helpers (51), dev integration (102) and cache/provenance checks (56) also
pass on both PowerShell versions; logs `cold-{release,integration,cache}-ps51.log`
and `cold-{release,integration,cache}-ps7.log`. `git diff --check` passes.
This supersedes the prior candidate freeze; the corrected commit needs exact-source
CI and actual environment-specific builds.

Staging internal track `4701264247659999845` now has the same verified owner-only
Toonsa list selected and saved. Its existing Untitled release draft contains no
bundle; Add from library explicitly reports No app bundles. Allocate initial
version code 1. Future install URL
`https://play.google.com/apps/internaltest/4701264247659999845` remains disabled
until the release is published. No bundle or public rollout occurred.

## Current dependency audit correction (October 27)

Candidate `a4bda7e653655916736e9f8c4cc8a2fadc0c402d` includes the validated cold
Android preparation fix. Its [CI run 40553794370](https://github.com/To0nsa/rpg-runner/actions/runs/40553794370)
passes the compiled-web smoke, resolving the preceding runner-startup failure.
Both Functions jobs stop at the mandatory fresh advisory audit:
[GHSA-6pq8-jhm2-2vcw](https://github.com/advisories/GHSA-6pq8-jhm2-2vcw), updated
October 27, covers pinned qs 6.16.0 and identifies 6.16.1 as patched. The failure
is retained in `final-ci-functions-{build,checks}-job.log`; it is not waived.

Advanced only the existing qs override to 6.16.1 in `pnpm-workspace.yaml` and
the separately uploaded `functions/package.json`, then regenerated the existing
pnpm lockfile. The diff changes only qs's pin, integrity and dependency edges.
Validation on `a4bda7e6` plus that correction, from the repository root with
pinned Node 24.16.0:

- `corepack pnpm install --frozen-lockfile`: pass.
- `corepack pnpm --dir functions audit --prod --json`: zero vulnerabilities.
- `corepack pnpm --dir functions build`: pass.
- `corepack pnpm --dir functions test`: 266 pass, zero failures/skips.
- `node --test functions/tool/production_inventory.test.mjs`: four pass.
- Copied only Functions' package manifest to a new system-temporary directory
  outside the pnpm workspace. `npm install --package-lock-only --omit=dev
  --ignore-scripts`, `npm audit --omit=dev --json` and
  `npm ls qs --package-lock-only --omit=dev --json` pass. Audit reports zero;
  every production qs edge resolves to 6.16.1. No second workspace lockfile was added.
- `git diff --check`: pass.

Logs use `.tmp/beta-checks/qs-patch-*`. No runtime gameplay code changed; final
candidate CI/build/deployment evidence must be bound to the patched commit.

Both Play apps' no-ads declarations are saved and independently read back as
Change saved, pending review submission. Production age-audience configuration
is gated by Sign-in details. The Console and Google's
[review-access requirements](https://support.google.com/googleplay/android-developer/answer/15748846?hl=en)
require reusable access to authenticated gameplay, including third-party account
details where needed. A dedicated review account was requested from the owner;
no owner credentials or invented credentials were submitted, and that declaration
remains incomplete. This does not prevent independent build/backend work.

## Patched candidate validation and production declarations (October 27)

Frozen source: `d83a690cd4ad82a5427a522a0646027e75d0ad19`.
[Release preparation 40555415832](https://github.com/To0nsa/rpg-runner/actions/runs/40555415832)
completed successfully with all 16 jobs passing, including the fresh advisory
audit, four client shards, compiled-web smoke, native Android inspection and
complete evidence bundle. No traversal failure was waived. ImportCI runs from
the exact LF checkout; log `.tmp/beta-checks/candidate-d83-import-ci.log`.

Production Play declarations for Government apps (No), Financial features (none)
and Health apps (none) are saved. The production IARC questionnaire is also saved,
with pixel-art fantasy violence against humans and non-humans, unrealistic
reactions, frequent distant combat, limited blood, dark overtones and recurring
scary imagery. Actual player hit/death, Unoco death and Voidborn Goddess sprite
assets were inspected alongside the active enemy catalog. No sexual, gambling,
controlled-substance, crude-humor or authored offensive-language content was
declared. The native-interaction answer excludes ordinary competition/ghosts:
there is no chat or user photo/audio exchange, consistent with Google's
[interaction guidance](https://support.google.com/googleplay/android-developer/answer/7021383?hl=en).
No location sharing, real-world propaganda, terrorism advocacy or crime
instruction exists in this fantasy game.

Calculated ratings include PEGI 7 (mild violence, fear), ESRB Everyone 10+
(fantasy violence, mild blood), and USK 12 (fantasy violence, dark atmosphere).
Console confirms Questionnaire saved; review submission is still pending and
the certificate ID is not yet populated. These content ratings do not change
the owner's separately selected 16+ audience. Privacy, reviewer access, Data
safety, actual Android screenshots, audience and country configuration remain
open; no Play release was published by these declaration saves.

Production's existing closed Alpha track `4700012046966711629` now targets only
Finland (Console readback: Targeted 1). Selected the existing Toonsa email list,
previously verified as the sole owner account, and saved
`lothringen.rpg@gmail.com` as its feedback contact. Console reports two of four
track-setup tasks complete. The track remains inactive with no release; no
testers were added or invited, and no qualification period has begun.

Exact-candidate ImportCI completed successfully. Canonical development Prepare
is running from the LF checkout, using that evidence and fresh advisory checks;
log `.tmp/beta-checks/candidate-d83-prepare-dev.log`. It subsequently passed with
all ten components reused and the fresh dependency audit clean. Dev source digest
is `1151277edf58a9f7926a5a709e1b0e8c9deaa3773489f5b811cb2e472feb665d`.
Canonical BuildImage acquired/released its project lock and started Cloud Build
`9a8b0932-3a0a-48b6-a275-f3256c232c2f` at 18:22:11 UTC. Readback is WORKING with
the configured 7200-second limit; this is not an image pass or deployment.
Log: `.tmp/beta-checks/candidate-d83-image-dev.log`.

Production Store settings now read Game / Action with public support email
`lothringen.rpg@gmail.com`, both saved. Optional phone/website fields are blank.
Staging Prepare is running from the same frozen checkout, with log
`.tmp/beta-checks/candidate-d83-prepare-staging.log`.

Staging Prepare passed for digest
`ac307d586ae098d863632d634ec6f816406f7021365bb9e107eb4972572ea87a`.
Its canonical BuildImage started `d3015999-a988-4416-8144-0a0a05af5021` at
18:24:53 UTC; readback is WORKING. Production Prepare also passed, for digest
`df30dbc8463d839572f2c09693b4bc3acfe767d90d5685e7955b79425d11fbec`.
Logs are `.tmp/beta-checks/candidate-d83-{image-staging,prepare-prod}.log`.
Production BuildImage is underway; deployment remains gated on staging acceptance.

Production's en-GB default store listing now has the prepared short/full copy,
512px icon and 1024x500 feature graphic uploaded and visually verified. Console
confirms Draft saved. Required phone screenshots are absent; the listing is not
submitted or published. No generated or web screenshots were substituted.

Production Cloud Build is `dbc42520-375f-483e-a547-bba48b4d0218`, started at
18:28:11 UTC. All three image builds remain WORKING at the next readback.

The first dev BuildAndroid attempt failed before packaging/signing because the
fresh checkout lacked ignored `android/gradlew.bat`; the release action records
Gradle's version before Flutter's normal build creates that wrapper. No artifact
was recorded and its mutation lock was released. The pinned Flutter 3.47.1 source
confirms `build apk --config-only` injects missing wrapper files before returning
without assembly. Ran `flutter build apk --config-only --flavor dev --release
--build-number=1` in the exact frozen checkout: success, wrapper/JAR generated,
`git status --short` empty. Canonical BuildAndroid dev/version 1 is retrying;
log `.tmp/beta-checks/candidate-d83-android-dev-retry.log`. Documented this cold
checkout initialization in the release workflow and Android/deployment contracts.
The candidate commit and source digests are unchanged; no tests were bypassed.

Owner explicitly chose to keep Play Games tester-only. Do not publish either
Play Games configuration. The owner will create a separate review account;
review-access details remain incomplete. The offered Android phone is now
connected and authorized in `adb devices -l` (model CPH2465). This is device
availability only, not installed-app acceptance.

The owner reconsidered staging once more and explicitly reconfirmed
dev + staging + prod. No environment removal or resource deletion occurred.
Staging's Store settings are now Game / Action with the confirmed public support
email; both changes show saved in Console. Remaining declarations/listing and
release publication are still pending.

Dev BuildAndroid retry exited 1 after 7m36s of Gradle work: Dart AOT
`android_aot_release_android-arm64` failed with `Out of memory` and snapshotter
exit `-1073740791`. This is a blocking build failure, not a traversal waiver.
The retry log and candidate's `android/dev/1/build.log` retain the failure.
All 3,750 client graphs were generated successfully. ARM32 and x64 `app.so`
outputs and corresponding Dart symbols exist, but ARM64 and the final APK do not.
Canonical finally released mutation lock generation `1793126133507156`.
Readback found approximately 1 GB free physical RAM and 3.8 GB free committed
memory on this 16 GB workstation. Asked the owner to close unused heavy apps;
no unrelated processes were terminated. Retry must preserve all three ABIs.

## Shared graph/image reuse and memory recovery (October 27)

The owner needs their other applications open. Used Flutter 3.47.1's supported
`assemble --resource-pool-size=1` with the same Gradle-emitted inputs, output paths,
defines and all three AOT targets. Confirmed the option in the pinned SDK's
assemble command and BuildSystemConfig; no SDK or candidate source was changed.
Ignored helper `.tmp/beta-checks/prepare_android_serial.ps1` records this exact
candidate invocation. It passed, produced the missing ARM64 output, retained
ARM32/x64 and all three symbol files, and verified the tracked tree clean.
Log `.tmp/beta-checks/candidate-d83-serial-dev.log`. Canonical dev BuildAndroid
version 1 was retried; log `candidate-d83-android-dev-after-serial.log` in the
same directory. Its graph preparation reports built=0, reused=3750 in 29.665s.
Packaging/inspection remains in progress; compilation alone is not acceptance.

The owner requested reuse of identical navigation graphs across environments.
Inspection confirmed Android flavors share the client directory, whereas three
isolated Docker builds each regenerate the complete worker navigation pack.
The worker image contains no project configuration or secrets; deployment supplies
those separately. Implemented BuildImage -ReuseImageFrom with a shared worker
fingerprint, live source-build/strict-benchmark verification, immutable pull/tag,
destination strict benchmark, exact digest equality and saved copy provenance.
No runtime/gameplay or generator behavior changed. The destination still owns its
registry image and all runtime/service/data identities.

Cancelled the redundant staging `d3015999-a988-4416-8144-0a0a05af5021` and prod
`dbc42520-375f-483e-a547-bba48b4d0218` jobs around 19:00 UTC; their cancellation is
recorded as superseded work, never as passing image evidence. Dev build
`9a8b0932-3a0a-48b6-a275-f3256c232c2f` continues (52,300 graphs at the next readback).
Granted repository-level `roles/artifactregistry.reader` on dev's `replay` repo
to staging's actual build account `943085064373-compute@developer.gserviceaccount.com`,
and on staging's `replay` repo to production's build account
`696550437718-compute@developer.gserviceaccount.com`. Both IAM updates succeeded;
no player-data or runtime cross-project roles were granted.

Local image-reuse validation on PowerShell 5.1 and 7: 16 focused image-evidence
checks, 53 release checks, and the full integration matrix (106 dev, 101 staging,
101 prod) pass; cache tests also pass. Logs use `.tmp/beta-checks/image-reuse-*`.
The first new integration test lacked its own helper imports; corrected the test
harness and reran successfully. These tests mock cloud commands and do not prove
the pending image copies/deployments. Existing CI evidence still covers unchanged
application/worker component inputs; the tooling milestone needs its own commit.

Chrome control later lost its native pipe. One reconnect/reset attempt failed,
and browser control inventory returns no connected browser. Console work is
pending restoration; CLI work remains available. The phone reports Android API 35.
Production PITR and delete protection are enabled with 604800s retention; its
scheduled-backup list is still empty (do not call this a completed backup).

Image reuse was committed as `f44ab755bd173b352be5f5d9c63c293b911def64` and pushed
to `release/android-beta-browser-check`. It is the new frozen candidate.
Checkout created the matching LF directory and copied all three environment
configuration files. Both sets of 29 isolation checks also pass, with
`git diff --check` and the agent-guidance check passing. Compared all ten release
component fingerprints and the worker fingerprint between d83a690c and f44ab755:
all match. No application, Core, Functions or worker runtime source changed.
Worker fingerprint is
`e0555a9542aee0128c854e251f4e3e158554d40bfb1740bb16d6cefcbc473b0b`.
Locked pnpm and Flutter setup passed in the new checkout, the Gradle wrapper was
initialized through Flutter, and the existing navigation directory was copied
for validation/reuse. Tracked source remained clean. Prepare is running for all
three environments; logs `.tmp/beta-checks/candidate-f44-prepare-<env>.log`.

The preceding d83a690c dev APK completed canonical inspection at 19:17 UTC:
184126366 bytes, SHA-256
`b0807f4804fe669abe68dc3f8328dc04d632873b7e65ae604b4991525e27fdc4`.
Package `com.example.rpg_runner.dev`, version `1.0.0-dev`/1, min SDK 24,
target SDK 36; all three required ABIs, 9 native libraries, 16 KB ELF/ZIP checks
and all 3750 navigation graphs passed. Navigation manifest SHA-256 is
`6f65c41f501cc9618ecefd8ae3349d037656aacb567935ab81268f8639a812bd`;
APK signing certificate SHA-256 is
`001f8fe8d465d47b2aa1264fd8a00ac2221875aeef17ce1bfad5d1bf6d91f061`.
No advertising-ID permission appears. Canonical evidence is in that checkout's
`android/dev/1/android.json`; its lock was released. This is a genuine installable
earlier-candidate APK, not evidence that f44ab755 Android builds are complete.

Both redundant Cloud Builds read back CANCELLED. The retained dev build reached
69460 graphs and remains WORKING. Its unchanged worker inputs permit reuse after
successful image publication/benchmark; no pending job has been marked passing.

Fresh Prepare passed for f44ab755 in all three environments at 19:28:10 UTC
(dev), 19:30:49 (staging) and 19:36:27 (prod), reusing the ten matching component
records and passing current dependency audits. New source digests:

| Environment | Source digest |
| --- | --- |
| Dev | `863755afe6412f9819a90a501148b7a38a7593310f72fa069ae659920b328228` |
| Staging | `5467c26ac1dde5608a06f80031e29dfaed25e7726f2a61924a7d24dcbb4934cc` |
| Prod | `399ba7b2c981e8eeb3e4304f05d32e6d71f0895b68e6367f29af869526f722d2` |

The new dev sequential AOT invocation has produced all three native outputs;
canonical Android packaging/inspection remains pending. The retained remote
worker build has reached 84,170 graphs and remains in progress.

Retained dev Cloud Build `9a8b0932-3a0a-48b6-a275-f3256c232c2f` completed SUCCESS
at 19:47:52 UTC. Its immutable image digest is
`sha256:fb6a16cbee611183462938e19deb9aeaf79c283eadff475e4ab029a4e2a3c331`.
Canonical ImageStatus in the original checkout saved its successful build
evidence and worker-input cache record. The frozen candidate is adopting that
matching image before copying it to staging. No image is deployed yet.

The f44ab755 dev sequential AOT preparation passed with all three architectures.
Its canonical navigation check reused all 3750 graphs (built=0). Android Gradle
packaging then failed `:app:copyFlutterAssetsDevRelease` with Windows disk full
(`java.io.IOException: Espace insuffisant sur le disque`), after 6m13s. This is
a blocking build failure, not a waiver. Preserved the full failed build log as
`.tmp/beta-checks/candidate-f44-android-dev-disk-full.log`; mutation lock
generation `1793129935501164` was released. Reclaimed redundant Android generated
outputs from the preceding d83a690c checkout, retaining its web artifact, APK and
release evidence. Main-checkout Android intermediate caches are also being
cleared; source, APK/AAB outputs and all recorded evidence are retained.

Cleanup completed with approximately 6.3 GB free. The old generated Gradle
problems report was locked and left in place. Canonical dev BuildAndroid version
1 is retrying, with `.tmp/beta-checks/candidate-f44-android-dev-retry.log`.
The frozen candidate's BuildImage dev action verified/adopted the retained image
and released its lock. Staging BuildImage -ReuseImageFrom dev submitted
`fe7f9df1-ab0f-43e7-aa24-02f1c7b13880`, then released its project lock. This job
copies immutable bytes and benchmarks them; it does not upload source or
regenerate graphs. Completion/digest verification is still pending.

Staging copy `fe7f9df1-ab0f-43e7-aa24-02f1c7b13880` completed SUCCESS at
19:57:05 UTC. Canonical ImageStatus verified the strict benchmark and identical
digest `sha256:fb6a16cbee611183462938e19deb9aeaf79c283eadff475e4ab029a4e2a3c331`,
and recorded provenance/cache evidence. Log:
`.tmp/beta-checks/candidate-f44-image-staging-complete.log`. This is live proof of
image reuse across isolated registries; runtime deployment remains pending.

Frozen f44ab755 dev BuildAndroid version 1 passed at 20:09:10 UTC after disk
recovery. Artifact SHA-256:
`428b02e8b713741f4625022e7d11d5e34635fe3bcc8847cd1528c1ce11300ea3`,
184126366 bytes. Package/version `com.example.rpg_runner.dev` / `1.0.0-dev` / 1;
min SDK 24, target SDK 36, three ABIs, nine native libraries and 16 KB alignment
pass. All 3750 navigation graphs are present with the same verified manifest
hash. Native resources target rpg-runner-d7add and its registered dev Firebase
app/Play Games OAuth client. No advertising-ID permission. Evidence is
`.tmp/release-checkouts/f44ab755bd173b352be5f5d9c63c293b911def64/.tmp/releases/rpg-runner-d7add/863755afe6412f9819a90a501148b7a38a7593310f72fa069ae659920b328228/android/dev/1/android.json`;
the installable APK is alongside it. Log:
`.tmp/beta-checks/candidate-f44-android-dev-retry.log`. Lock generation
`1793131022306097` was released. Staging sequential AOT preparation and production
image-copy submission have started; neither is recorded complete yet.

The verified dev APK installed successfully on the connected CPH2465 with
`adb install -r`; package readback confirms versionCode 1, versionName 1.0.0-dev,
min SDK 24 and target SDK 36. This preserves the existing dev installation's data;
the app has not yet been launched for the new backend acceptance session.
Staging sequential AOT preparation subsequently completed; its AAB is not yet
packaged/inspected. Production sequential AOT preparation is running.

Production image copy `84a144e6-3867-4a34-be88-5ba8282f8f75` ran from
20:12:19 to 20:13:40 UTC and completed SUCCESS. Canonical ImageStatus verified
its strict benchmark and the same immutable digest as dev/staging, recording
copy provenance. Log: `.tmp/beta-checks/candidate-f44-image-prod-complete.log`.
All three projects now have the same verified worker image in their isolated
registries; no production runtime has been deployed.

Canonical dev PauseIssuance is in progress. Its existing issuer image had been
removed by managed registry cleanup, so the built-in recovery path is rebuilding
only runSessionCreate with RUN_SUPPORTED_GAME_COMPAT_VERSIONS=release-paused.
The source-bound cutover record is claimed; do not replace it or clear the held
mutation lock while this action runs. Log:
`.tmp/beta-checks/candidate-f44-pause-dev.log`. Successful pause/readiness and the
fresh drain inventory remain required before coordinated deployment.

The first issuer recovery failed during Firebase's local discovery with
`User code failed to load. Cannot determine backend specification. Timeout after
10000`. Preserved the log as
`.tmp/beta-checks/candidate-f44-pause-dev-discovery-timeout.log`. Cloud readback
still showed the original ACTIVE issuer/revision `runsessioncreate-00071-wx8`,
with its October 25 update time; issuance was not paused by that attempt.
The mutation lock was released and local environment bytes restored. The
source-bound cutover record remains owned by this same candidate. Retrying
canonical PauseIssuance with the operator-only `FUNCTIONS_DISCOVERY_TIMEOUT=60`,
documented in [Firebase initialization guidance](https://firebase.google.com/docs/functions/tips#avoid_deployment_timeouts_during_initialization).
This only extends local CLI source discovery; no runtime gate is relaxed.
Retry log: `.tmp/beta-checks/candidate-f44-pause-dev-retry.log`.

The retry passed discovery and created regional issuer build
`fb198fdc-394e-44e6-8b20-c79f61a108ef`, which completed SUCCESS at 20:24:30 UTC.
Canonical PauseIssuance verified the healthy paused serving revision
`runsessioncreate-00072-suz` and released mutation lock generation
`1793132429804344`. The board-maintenance scheduler read back PAUSED. Dev Deploy
-CutoverReady is now running, using the same 60-second CLI discovery allowance
and retaining the source-bound cutover ownership. It performs a fresh drain check
before pausing queues/deploying consumers. Log:
`.tmp/beta-checks/candidate-f44-deploy-dev.log`. Issuance must remain paused until
worker, boards and live artifact checks pass; then explicitly resume the legacy
board scheduler and run canonical ResumeIssuance. Production Android sequential
AOT preparation has also completed with all three symbols; its AAB is still pending.

Dev's fresh drain inventory at 20:26:45 UTC found four already accepted runs,
four settled grants, no active sessions, no stale/quarantined settlements and all
three expected current boards. These precede the new worker deployment and are
not claimed as new-candidate replay acceptance. No cancellation/reset was needed.
Functions deployment completed at 20:31:11 UTC. Worker revision
`replay-validator-00059-ssr` became Ready at 20:34:15 UTC, serving 100% of traffic;
its recorded worker checkpoint is 20:35:26 UTC.

Deploy then stopped at the legacy paused board scheduler: Google rejected RunJob
with `FAILED_PRECONDITION: Job.state must be ENABLED for RunJob`. Preserved
`.tmp/beta-checks/candidate-f44-dev-boards-paused.log`. Functions and worker
checkpoints remain valid; Hosting is not yet deployed. Issuance and both queues
remain paused. Fresh readback verified the worker's exact expected immutable
digest, Ready status and 100% traffic, then explicitly resumed the legacy
board-maintenance scheduler. Readback is ENABLED. Canonical Deploy is retrying
from saved checkpoints, log `.tmp/beta-checks/candidate-f44-deploy-dev-retry.log`.
The source-bound cutover record remains owned by f44ab755; no gate was bypassed.

Windows Computer Use's lightweight connection check still returns native-pipe
unavailable (OS error 2). No app input was attempted. Production's backup list
also remains empty at the later readback; first backup completion is still open.

Dev Deploy retry completed at 20:40:27 UTC, reusing the validated Functions and
worker checkpoints and publishing Hosting. The resumed board scheduler's last
attempt was 20:40:19 UTC with ENABLED state and an empty (successful) status.
Live worker smoke at 20:42:15 UTC returned 403 without authentication and 200
`ready` for the existing authorized operator. The identity token stayed only in
process memory; saved evidence contains no token:
`.tmp/beta-checks/candidate-f44-dev-worker-smoke.json`.

Both public policy pages returned HTTP 200 and exactly matched frozen build
bytes. Privacy SHA-256 is
`6734a9a63e201f6fbeed7cda85c232a51039851437a91fadf8699fbd1629859c`;
account deletion SHA-256 is
`594770ae8008a711f18546e7d9df1b9e40ea0f13f8a63a0646b3c5ba7086aa40`.
Evidence: `.tmp/beta-checks/candidate-f44-live-policy-verification.json`.
Live URLs: https://rpg-runner-d7add.web.app/privacy-policy.html and
https://rpg-runner-d7add.web.app/account-deletion.html.

Canonical ResumeIssuance passed all fresh drain/current-board/live-artifact gates
and restored dev issuance at 20:47:37 UTC. It deployed the normal issuer, removed
the temporary runtime gate, recorded the baseline and cleared this candidate's
cutover ownership. The serving issuer is `runsessioncreate-00074-9w8`.
Log `.tmp/beta-checks/candidate-f44-resume-dev.log`; mutation lock generation
`1793133844796787` was released. Play Games/replay/device acceptance remains
separate and unrun for the new stack. The phone is asleep; an unlock request is
pending while independent work continues.

Freed memory by stopping only release-owned Gradle daemon 26308 after verifying
its identity and IDLE state; no user application was closed. Staging canonical
BuildAndroid version 1 is now running. Its prior sequential AOT outputs and shared
client navigation pack are reused; signing/inspection/symbol upload remain gates.

Dev negative service smoke passed at 21:00:46 UTC: authenticated malformed
validation/projection task bodies both return 400 `invalid_request`, while
unauthenticated playerProfileLoad and runSessionCreate calls both return 401
`UNAUTHENTICATED`. No gameplay fixtures were created. Evidence:
`.tmp/beta-checks/candidate-f44-dev-worker-protocol-smoke.json`. This verifies
deployed rejection paths, not Play Games or Play Integrity device acceptance.

Staging BuildAndroid version 1 passed at 21:01:26 UTC. Signed AAB SHA-256:
`156dbcb2157681b5464c42424f167dcf461f3bc8882c12e4a45fbf610cdf655a`,
174459159 bytes. Package/version `com.lothringen.longrun.staging` /
`1.0.0-staging` / 1; min SDK 24, target SDK 36. The registered upload certificate
SHA-256 is `ab46f14dc351dccaffa431f129bc95f2926c42aac0ddd9be5bf96f2bf84596c9`.
The bundle has the expected staging Firebase/Play resources, all 3750 graph
bytes, three ABIs, nine native libraries, 16 KB alignment and no advertising-ID
permission. Client graph preparation reports built=0/reused=3750 in 36.277s.
Firebase CLI successfully uploaded all symbols to staging app
`1:943085064373:android:51c288ba51386d01572efc`; R8 mapping is retained. Evidence is
in the frozen checkout's staging source-digest directory under
`android/staging/1/android.json`, alongside `app-staging-release.aab`. The derived
inspection APK is not a distribution artifact. No Play upload has occurred.
Mutation lock generation `1793134181741069` was released.

Staging's first Bootstrap stopped before any cloud mutation because symbol upload
had generated untracked `functions/.crashlytics/dump_syms.exe` and `dump_syms.obj`.
The strict source fence correctly rejected the altered checkout. Preserved that
failure in `.tmp/beta-checks/candidate-f44-bootstrap-staging.log` and moved only
these two generated SDK files, after inventory/hash verification, into
`.tmp/beta-checks/crashlytics-generated-staging-f44`. The frozen tree is clean and
canonical Plan again reports the original prepared staging source digest
`5467c26ac1dde5608a06f80031e29dfaed25e7726f2a61924a7d24dcbb4934cc`.
No candidate source or preparation record was changed. Future checkouts ignore
this exact SDK cache directory; guidance documents recovery for older candidates.
`git diff --check`, `git check-ignore functions/.crashlytics/dump_syms.exe` and
`node tools/agents/check.mjs` passed (32 guidance files).

Staging Bootstrap -CutoverReady is retrying with FUNCTIONS_DISCOVERY_TIMEOUT=60.
It must pass the fresh empty-project inventory and create only the paused issuer.
Log: `.tmp/beta-checks/candidate-f44-bootstrap-staging-retry.log`. Production native
AOT is prepared, but its final BuildAndroid action remains pending.

The staging bootstrap retry verified an empty target at 21:19:41 UTC and created
issuer build `0c59986b-f738-4185-aadb-e88e0d9aac01` (SUCCESS at 21:23:38 UTC).
Revision `runsessioncreate-00001-cad` became Ready at 21:23:49 UTC with 100% traffic.
Firebase then returned a failure because its newly created `gcf-artifacts`
repository lacked a cleanup policy. The issuer creation succeeded; bootstrap as
a whole did not. Its lock was released and local environment bytes restored,
while source-bound cutover ownership remains. Do not repeat Bootstrap or erase
resources to satisfy its empty-project check.

Applied the documented Firebase `functions:artifacts:setpolicy --project
lothringen-long-run-staging --location europe-west1 --days 7 --force
--non-interactive` under the project mutation lock. Readback confirms the
`firebase-functions-cleanup` policy with `olderThan=604800s`, then the lock was
released. This covers Functions build images only, not player data or the separate
replay-image retention policy. Log:
`.tmp/beta-checks/candidate-f44-staging-functions-cleanup-policy.log`.
Canonical PauseIssuance is recovering the partially created target using the
same candidate/cutover record; log
`.tmp/beta-checks/candidate-f44-pause-staging-recovery.log`.

To make room for production packaging, verified the retained final dev APK hash
and removed only six disposable `build/app/intermediates/*/devRelease` directories
within the frozen checkout. The exact scoped paths are recorded in
`.tmp/beta-checks/candidate-f44-dev-intermediate-cleanup.txt`. Final artifacts,
symbols, evidence, source and shared graph/AOT caches remain intact; 2.76 GB was
available afterward. The frozen source tree remains clean. Phone readback still
shows Asleep/NotificationShade; device acceptance has not been attempted.

Canonical staging PauseIssuance recovery passed at 21:26:27 UTC. Healthy paused
issuer `runsessioncreate-00002-lrp` serves 100% traffic. The subsequent coordinated
Deploy passed its drain fence but stopped before creating the remaining Functions:
Firebase requires `--force` to acknowledge the already-authored retry policies on
`runSettlementOnHandoff` and `runProjectionOnAccepted`. The lock was released;
issuance and both queues remain paused, with the original cutover record intact.
Logs: `.tmp/beta-checks/candidate-f44-deploy-staging.log` and the frozen staging
evidence directory's `firebase.log`. No direct deployment workaround was used.

The release entry point now offers `-EnableInitialEventRetries` only for
coordinated `Deploy -CutoverReady`. Fresh live inventory selects only missing
instances of those two handlers for a separate explicitly acknowledged creation.
Existing mismatched, unfinished or non-retrying handlers block. Full deployment,
issuer and Firestore operations never receive `--force`; ordinary defaults and
pause/drain/benchmark checks remain strict. No runtime policy was changed.

Validation from the main checkout on both Windows PowerShell 5.1 and PowerShell 7:
61 release checks (plus 16 image checks), 56 cache/provenance checks, 29 environment
checks, and mocked entry-point checks for dev (101), staging (96), prod (96) pass.
Integration cases include explicit acknowledgement, missing-handler-only scope,
strict defaults, invalid action/authorization and active-run blocking. Logs use
`.tmp/beta-checks/initial-retries-`; guidance (32 files) and diff checks also pass.
These are mocked tool checks, not proof of the pending live staging deployment.
Freeze the correction and compare LF application fingerprints before cache reuse;
a preliminary comparison against the main CRLF working tree did not match and
was not used as evidence of equivalence.

After the owner unlocked the CPH2465, adb confirmed the dev app was foreground
and a screenshot showed its retained signed-in profile. The agent started Val
Outpost Competitive, tapped the start overlay, allowed the stationary player to
fall behind after three seconds, and tapped Collect Score. Read-only inventory
at 21:33:20 UTC had four validated/accepted/settled runs; at 21:37:04 UTC it had
five, zero rejected runs and zero quarantined settlements. One unrelated issued
session existed both before and after; it was left intact. Evidence:
`.tmp/beta-checks/candidate-f44-dev-{before,after}-device.json` and
`dev-phone-{current,after-play,run,started,result,collect}.png`. This is a basic
physical dev replay/settlement smoke on the new worker, not fresh-account sign-in,
exactly-once retry stress, full gameplay QA or staging Play Integrity acceptance.
The owner later navigated to Android's Long Run Dev app-info screen; no settings
were changed and no further phone input was sent.

The owner reported restoring the computer connection twice. New native-helper
checks, including a fresh Node session, still returned native-pipe unavailable
(OS error 2); browser inventories remained empty. No Windows input was sent.
Official OpenAI setup/troubleshooting guidance was provided; Console work remains
blocked by the unavailable connection, independently of the working phone/CLI.

### Final candidate recovery, October 27 late UTC

Committed and pushed `bcb59300e98c3563adc3ca32bddcd89c2813cedb` to the existing
continuation branch `release/android-beta-browser-check`. Canonical Checkout
created its clean LF tree and copied each environment configuration. All 32
comparisons against the preceding f44 LF checkout pass: the ten validation
components, Android build inputs, and seven runtime/environment groups per
project. Evidence: `.tmp/beta-checks/candidate-bcb-input-equivalence.json`.
The pinned Flutter configuration-only command initialized the ignored Android
wrapper successfully. Copied the verified 3,750-graph navigation pack; canonical
BuildAndroid must still validate every graph and produce its own final evidence.

The disk had only about 95 MB free after checkout. Verified the retained f44 dev
APK and staging AAB hashes, then removed only that checkout's disposable
`build/app/intermediates`, `build/app/generated`, `build/app/tmp` and
`.dart_tool/flutter_build` trees. Absolute-path and reparse checks preceded
deletion; source, final artifacts, symbols, web output and evidence remain.
Exact paths: `.tmp/beta-checks/candidate-bcb-prior-intermediate-cleanup.txt`.
Gradle reported PID 37348 IDLE; its log bound the last completed build to f44.
Stopped only that verified release daemon to free memory. User apps were left open.

Fresh staging inventory at 21:52:06 UTC shows only the ACTIVE paused issuer
`runsessioncreate-00002-lrp`, Ready with 100% traffic, both replay queues PAUSED,
no active Cloud Build jobs, no Auth users and no Firestore collections. Evidence:
`.tmp/beta-checks/candidate-bcb-staging-recovery-inspection.json`. This establishes
the inspected recovery state, not completion of the pending full deployment.

Production's first scheduled Firestore backup is READY: backup
`2fe07603-1334-4f5b-ad70-65b233e6e41f`, snapshot `2026-10-27T21:33:42.186313Z`,
expiry `2026-11-03T21:33:42.186313Z`. Readback at 21:58:22 UTC is retained in
`.tmp/beta-checks/candidate-bcb-prod-backups.json`; this proves scheduled backup
completion, not a full-service restore rehearsal.

At 22:10 UTC / October 28 00:10 Helsinki the owner requested a pause. Interrupted
both running local commands; exec sessions 45277 (remaining Prepare/BuildImage
loop) and 76015 (sequential staging AOT) exited 1. Preserve the partial output as
interrupted, not passing evidence. Staging Prepare had passed at 22:07:11 UTC for
source digest `71ed90cfad8e455f9820a63d539da4e34d3dda589cc3112802b31c321655cba0`.
Its matching image was verified by canonical BuildImage, with mutation lock
generation `1793138896848317` released. Production preparation for source digest
`bdb733be391ad2120e4d2891eb4730df51bc638a710cbffd61a0932acde66d20` is incomplete;
dev preparation in this final checkout has not started. Staging sequential AOT
has only `app.android-arm.symbols` (3,904,292 bytes), not a complete native build.

No new deployment or cutover-record replacement occurred. The manual recovery
helper `.tmp/beta-checks/recover_staging_bcb.ps1` is syntax-checked, unexecuted and
requires a fresh guarded inspection; staging ownership still belongs to f44.
The source-independent old f44 Android output copies were also removed only
after verifying the retained APK/AAB, with file inventory in
`.tmp/beta-checks/candidate-bcb-prior-output-cleanup.json`. Final artifacts,
symbols and evidence remain. Free disk at pause: 4,748,124,160 bytes.
The owner authorizes further cleanup of unused `.tmp` content on resumption;
no wholesale cleanup was performed. The owner confirms the reviewer account is
not created. Chrome/native connection remains unavailable; no Play upload or
production runtime deployment is claimed.

### Temporary cleanup on resumption, October 28

On the owner's cleanup request, inspected `.tmp` from `C:\dev\rpg_runner` and
removed 38 disposable directories containing 47,286 files / 6,676,644,964 bytes
(6.22 GiB). These were Android intermediates and Flutter/test output from older
checkouts plus unused benchmark/preview browser profiles. Source checkouts,
signed APK/AABs, symbols, navigation data, release caches, credentials and
release evidence were excluded. The protected OAuth directory was inaccessible
to inventory and left untouched. No user application or service was stopped.

`& .tmp/beta-checks/tmp-cleanup.ps1` reviewed the exact targets; the same command
with `-Apply` removed all 38 with zero failures. Every target's resolved absolute
path stayed under `.tmp`; ancestry and recursive checks rejected reparse points
and protected artifact names. A fresh process check found no selected path in
running command lines. The broader inventory counted 23.09 GiB of readable files;
it skipped reparse points and recorded the OAuth access limitation.

At 16:45:02 UTC, post-cleanup verification matched all 251 retained artifact and
metadata SHA-256 hashes, confirmed every selected directory absent, and verified
unchanged clean status for all 12 release checkouts. Frozen source remains
`bcb59300e98c3563adc3ca32bddcd89c2813cedb`. C: free space was 7,060,054,016 bytes
(6.58 GiB); Windows reported memory pressure during inventory, so this is the
measured post-cleanup space rather than a projection from the initial inventory.
`git diff --check` passes. No application tests, preparation or cloud mutations
were run for this cleanup.

Exact paths/results and preservation evidence remain in `.tmp/beta-checks/`:
`tmp-cleanup-plan.json`, `tmp-cleanup-result.json`,
`tmp-cleanup-process-check.json`, `tmp-cleanup-preservation-before.json` and
`tmp-cleanup-verification.json`. The existing pause/recovery gates remain open.

### CLI continuation, October 28

The owner requested all remaining release work that does not require browser
access. Frozen source remains `bcb59300e98c3563adc3ca32bddcd89c2813cedb`.
The three canonical Plans retain the expected environment identities and tuple;
dev resolves `None`, while staging and production remain `Coordinated`. Plan
logs: `.tmp/beta-checks/candidate-bcb-plan-resumed-{dev,staging,prod}.json`.

From the frozen checkout, `release.ps1 -Environment prod -Action Prepare`
with the shared `.tmp/release-cache` passed at `2026-10-28T17:05:59.5490264Z`.
All ten validation components were reused after fingerprint/artifact checks;
the mandatory fresh dependency audit reports no known vulnerabilities.
Production source digest remains
`bdb733be391ad2120e4d2891eb4730df51bc638a710cbffd61a0932acde66d20`.
Dev Prepare also passed with scope `None`, source digest
`368b1024cab59895ef8d4f24bc090144e34a35ddeb16cc7691c09ebe67a42696`;
this does not claim a new full test run or a dev backend deployment.

Canonical production BuildImage reused its existing successful copy build
`84a144e6-3867-4a34-be88-5ba8282f8f75`; staging ImageStatus reverified
`fe7f9df1-ab0f-43e7-aa24-02f1c7b13880`. Both retain immutable digest
`sha256:fb6a16cbee611183462938e19deb9aeaf79c283eadff475e4ab029a4e2a3c331`
and successful strict benchmark evidence. No new image build was submitted.
The production mutation lock was released. Logs use
`candidate-bcb-{prepare-dev,prepare-prod,image-prod,image-staging}-resumed.log`
under `.tmp/beta-checks`.

Fresh staging readback still showed healthy paused issuer
`runsessioncreate-00002-lrp` with 100% traffic and both queues PAUSED.
Production's scheduled backup remains READY. `adb devices -l` reports no device;
the previous checkpoint's attached-phone state is no longer current. Browser
work and Play-delivered/device acceptance remain open; production service
deployment is still gated on staging acceptance.

Guarded staging recovery completed with `.tmp/beta-checks/recover_staging_bcb.ps1`
from the frozen checkout. The lock-protected inspection at
`2026-10-28T17:11:22.2623353Z` verified the same healthy paused issuer, both paused
queues, no active builds, exactly one ACTIVE function, no Auth users and no
Firestore collections. The old f44 record was conditionally replaced with bcb
source digest `71ed90cfad8e455f9820a63d539da4e34d3dda589cc3112802b31c321655cba0`,
cutover generation `1793207498100417`. Mutation lock `1793207435287224` was released.
The before/after records and command log are
`candidate-bcb-staging-recovery-{before,after}.json` and
`candidate-bcb-staging-recovery-resumed.log`. Issuance remained paused.

Sequential staging AOT completed with `prepare_android_serial_bcb.ps1
-Environment staging`: ARM32, ARM64 and x64 symbol files are 3,904,292, 4,470,368
and 4,469,408 bytes respectively. This is compilation evidence only; canonical
BuildAndroid retains responsibility for signed packaging, inspection and uploads.
The build reused all 3,750 navigation graphs, building zero. Its native bundle
was generated at 17:29:52 UTC; final inspection/upload is still in progress.

A bounded staging CLI drill is prepared in ignored evidence storage as
`staging_bcb_smoke.{ps1,mjs}`; Node and PowerShell syntax checks passed, but no
synthetic account or replay has been created yet. It requires canonical deployed/
resumed state, uses a project mutation lock, one disabled temporary Auth account,
two 1,800-tick Field replays, real queue/worker processing and the frozen domain
transactions. Duplicate validation/settlement, projection and generation-pinned
ghost reads are checked; cleanup uses the real account-deletion stages and clock.
This does not exercise Play authentication, signed client upload grants, device
recovery or the full capacity/acceptance matrix. Context7 was unavailable; the
SDK/REST usage was checked against official
[Admin credentials](https://firebase.google.com/docs/reference/admin/node/firebase-admin.app.credential),
[Auth users](https://firebase.google.com/docs/auth/admin/manage-users),
[Cloud Tasks](https://docs.cloud.google.com/tasks/docs/reference/rest/v2/projects.locations.queues.tasks/create)
and [Storage insert](https://docs.cloud.google.com/storage/docs/json_api/v1/objects/insert)
documentation. No library or frozen source files were changed for this drill.

Canonical staging `BuildAndroid -AndroidVersionCode 1` completed successfully at
`2026-10-28T17:33:01.3528421Z`. Artifact SHA-256:
`8e3c12cfa933e38060af554af79c317125bd367eb3774721af68fbfabd523914`,
174,459,166 bytes, package `com.lothringen.longrun.staging`, version `1.0.0-staging`,
min SDK 24 / target SDK 36. The configured upload certificate, all environment
resources, 3,750 graphs, three ABIs, nine native libraries and 16 KB alignment
passed. Crashlytics symbols uploaded successfully; mapping and all three Dart
symbol files are retained with `android.json` under the frozen checkout's
`.tmp/releases/lothringen-long-run-staging/71ed90cfad8e455f9820a63d539da4e34d3dda589cc3112802b31c321655cba0/android/staging/1/`.
Mutation lock `1793207648215178` was released. This is a newly built bcb artifact,
not a relabeled f44 artifact, and has not been uploaded to Google Play.

After verifying the release Gradle daemon's last build belonged to bcb and its
last state was idle, stopped only PID 34196 to release memory. The bounded
`cleanup_completed_android.ps1 -Environment staging -Apply` then removed
1,814,609,031 bytes of completed Android intermediates and Flutter compiler cache.
All 11 retained files' hashes matched before/after; source stayed clean. Free
space became 3,952,156,672 bytes at 17:37:21 UTC. Its separate plan/result records
are `candidate-bcb-staging-completed-intermediate-cleanup-{plan,result}.json`.

The first canonical staging `Deploy -CutoverReady -EnableInitialEventRetries`
attempt reached the two missing event handlers, then failed during trigger
creation with Eventarc service-agent permission propagation. No handler remained
in live Functions inventory; the paused issuer remained ACTIVE. Readback confirms
`service-943085064373@gcp-sa-eventarc.iam.gserviceaccount.com` already has
`roles/eventarc.serviceAgent`, so no IAM role change was made. Google's
[Eventarc troubleshooting guidance](https://docs.cloud.google.com/eventarc/docs/troubleshooting)
documents this initial propagation delay. The source-bound cutover record remains;
mutation lock `1793209021754844` was released. Failure log and inspection:
`candidate-bcb-staging-eventarc-first-attempt.log`,
`candidate-bcb-staging-eventarc-{iam,functions}.json`. Canonical retry is running
with `FUNCTIONS_DISCOVERY_TIMEOUT=60`; it is not yet passing deployment evidence.

The prepared replay drill now generates gzip payloads through the frozen Dart
`RunTicket` / `ReplayBlobV1.withComputedDigest` codec, preserving positive frame
ticks and replay-v1 double spelling. A local-only 1,800-frame round-trip passed,
digest `31fc3798c4817d06c127b1bac44533f6d4ad8c598f33e08ad57db3e78fd49613`,
4,837 compressed bytes. The local codec fixture was never sent to staging.

Production and dev sequential AOT both completed for all three architectures.
Production symbols are 3,904,292 / 4,470,368 / 4,469,408 bytes; dev symbols are
3,904,016 / 4,470,048 / 4,469,080 bytes. Logs:
`candidate-bcb-serial-{prod,dev}-resumed.log`. Signed packaging remains pending.

The Eventarc retry successfully created both handlers at 17:52 UTC; canonical
Deploy then continued with the remaining Functions, rules and indexes. No
additional IAM role grant or source edit was needed. Completion of the whole
stack is still pending. The CLI drill's first read-only SDK initialization failed
because the Admin Firestore factory rejects a custom token credential. Using the
installed Cloud Firestore client with an in-memory `GoogleAuth`/`OAuth2Client`
resolved it; SDK type/source and the official
[OAuth client reference](https://docs.cloud.google.com/nodejs/docs/reference/google-auth-library/latest/google-auth-library/oauth2client)
were checked. Read-only retry confirms Auth and Firestore access, zero users and
no collections at observation. No account or replay was created. Logs:
`candidate-bcb-staging-sdk-check{,-retry}.log`.

The canonical retry deployed every remaining staging Function and Firestore
rules/index definitions successfully. `functionsDeployedAt` is
`2026-10-28T17:57:38.1406004Z`. It then stopped as designed at
`Confirm-ReleaseBackend` because indexes were still building; worker deployment
and issuance resume have not run. Fresh readback shows 10 CREATING / 2 READY
indexes in `candidate-bcb-staging-index-readiness.json`. The Functions checkpoint
is retained, the issuer is still paused, and mutation lock `1793209470816128` was
released. Rerunning canonical Deploy after readiness will reuse the completed
Functions stage. Production `BuildAndroid -AndroidVersionCode 1` started during
the index wait; it prepares the signed artifact only, not production services.

Staging's next index readback shows all 12 READY in
`candidate-bcb-staging-index-readiness-latest.json`. No second Functions rollout
is needed for unchanged source; canonical Deploy still must verify the backend,
deploy the worker and run board maintenance before resume.

Canonical dev Inspect completed with live inventory at `2026-10-28T18:02:04.188Z`:
worker `replay-validator-00059-ssr` is latest-created/latest-ready at 100% traffic;
both queues are RUNNING and all nine scheduled jobs are ENABLED. All three
expected current boards are present. There are five accepted/validated runs and
five settled grants, no quarantined or stale pending settlements, no invalid
leaderboard/ghost source references, and three current issued sessions. No user
data was changed. Evidence: `candidate-bcb-inspect-dev-resumed.log` and the frozen
dev release directory's `inventory.json`, `worker.json`, `queues.json`,
`scheduler.json`, `functions.json`.

Production packaging regenerated native compilation after switching flavors,
then completed the Gradle bundle at 18:18:17 UTC. Canonical inspection/upload is
still running, so this is not yet release-artifact acceptance. For the remaining
dev package, run sequential AOT immediately before BuildAndroid; prior flavor
preparation does not guarantee Flutter's shared build state stays reusable.
Verified idle release-owned Gradle PID 18324 was stopped after its completed bcb
build to release memory. No application source or user application was changed.

Production canonical BuildAndroid completed at `2026-10-28T18:23:38.8711728Z`.
The version-1 AAB is 174,459,293 bytes, SHA-256
`0304e471ef42b931e57a661245d3b8b23cc279017028ea93dde75b8ff91eafab`.
Package `com.lothringen.longrun`, version `1.0.0`, SDK 24/36, production Firebase/
Play Games resources and upload certificate
`6934f381b5cab46ced0084cb4dd7e6691ee84a4be98987ff09ce2882b36b67a4` passed.
Archive checks verified 3,750 navigation graphs, all three ABIs, nine native
libraries and 16 KB alignment. Symbols uploaded successfully; mapping, symbols,
manifest and inspection APK/APKS are retained alongside `android.json` in
`.tmp/releases/lothringen-long-run-prod/bdb733be391ad2120e4d2891eb4730df51bc638a710cbffd61a0932acde66d20/android/prod/1/`.
Mutation lock `1793210427863506` was released. No Play upload or production service
deployment occurred. Canonical staging Deploy is now continuing with the saved
Functions checkpoint and READY indexes; log:
`candidate-bcb-deploy-staging-index-ready.log`.

Completed production-intermediate cleanup at 18:26:16 UTC removed 2,109,003,387
bytes / 14,193 files; all 11 production artifact/metadata hashes still match.
Free disk became 2,855,473,152 bytes. Evidence:
`candidate-bcb-prod-completed-intermediate-cleanup-{plan,result}.json`.
The final sequential dev AOT preparation passed afterward, recorded in
`candidate-bcb-serial-dev-final.log`; no further flavor switch should precede
its canonical APK packaging.

Canonical staging Deploy completed at `2026-10-28T18:34:06.1272005Z`, with worker
checkpoint `2026-10-28T18:33:40.1758786Z`. New revision
`replay-validator-00001-rsg` is Ready, latest-created/latest-ready and serves 100%
traffic. Live readback confirms the exact benchmarked `sha256:fb6a16c...a3c331`
image, 1 CPU / 512 MiB, concurrency 1, maximum 10 instances and project-local
`sa-replay-validator` identity. Both queues retain PAUSED state, configured at
five dispatches/second and five concurrent dispatches. Board maintenance was
invoked by the canonical command. The mutation lock `1793212055244721` was
released; source-bound cutover ownership persists until verified resume.
Readback: `candidate-bcb-staging-worker-verified.json`; command log:
`candidate-bcb-deploy-staging-index-ready.log`. Guarded ResumeIssuance is now
running, but issuance restoration is not yet claimed.

Canonical staging `ResumeIssuance -CutoverReady` completed successfully;
`issuanceResumedAt` is `2026-10-28T18:42:51.3373207Z`. The command verified the
live artifacts/current boards, resumed both queues, deployed the issuer,
removed its temporary compatibility gate and saved the verified baseline.
It cleared the source-bound cutover record and released mutation lock
`1793212609231588`. Log: `candidate-bcb-resume-staging.log`. The frozen candidate
checkout remains clean. Play-linked authentication and device acceptance remain
unrun; the prepared CLI inspection/drill follows this backend checkpoint.

Live CLI HTTP inspection passed at `2026-10-28T18:44:49.637Z`: authenticated
worker readiness 200, anonymous worker 403, unauthenticated ticket callable 401;
zero Auth users before fixtures. The bounded drill then used one disabled
synthetic account and dispatched both 1,800-frame replays at 18:47:20 UTC.
Practice seed 14 ended at tick 728, score 475, one gold; competitive Field seed
871327128 ended at tick 1047, score 685, two gold. Both were accepted and settled
in about 2.7 / 4.4 seconds from finalize. They did not simulate all 1,800 ticks:
both ended naturally in gaps. The practice immediate settlement request timed
out at four seconds while durable settlement succeeded; evidence retains this
fallback rather than treating it as a lost reward.

The drill **failed** its 120-second leaderboard/ghost gate. Worker logs show
`projection_unchanged` after 37 ms; no ghost was published. Duplicate delivery,
wallet invariance and ghost-download assertions were not reached. Cleanup
entered `quiet_wait` at `2026-10-28T18:49:57.370Z` using the real deletion clock;
mutation lock `1793213205589008` was released. Logs/state:
`candidate-bcb-staging-smoke{,-run.log,-worker-log.json,-metrics.json}`.
Both queues were RUNNING and empty when metrics were collected at 18:55 UTC.
This failed drill is not capacity or release acceptance.

Investigation reproduced a Firestore decoder bug: `mapValue: {}` and
`arrayValue: {}` became null when REST omitted nested members. The valid empty
`codex.enemyKills` map then made both projection stores discard the accepted
`ValidatedRun`. Context7 remains unavailable; the official
[Firestore Value reference](https://docs.cloud.google.com/firestore/docs/reference/rest/v1/Value)
and installed SDK types were checked. The source fix retains empty collection
types without changing validation, gameplay, compatibility or protocol fields.
Added regressions cover empty/nested values and both real projection readers
using an HTTP fixture with empty kill evidence. Before-fix regression fails;
after-fix three tests pass. From `services/replay_validator`, `dart analyze`,
`dart test test --reporter=expanded` (301 tests), and `dart compile exe
bin/server.dart -o ../../.tmp/beta-checks/empty-firestore-values-validator.exe`
all passed. Logs: `empty-firestore-values-{regression-before,regression-after,
analyze,worker-tests,compile}.log`. These are local/mocked checks; a replacement
frozen candidate and live staging retest are still required.

The validated fix is committed as `c8b353a6e332bad701b6c044d4d138cc17e64b85`.
Canonical Checkout created its clean LF worktree and copied each environment's
configuration through the matching explicit dev/staging/prod action. The bcb
checkout remains clean and unchanged. Its abandoned native intermediates were
removed separately (294,536,061 bytes), verifying all 11 retained production
artifact hashes; evidence is `candidate-bcb-superseded-intermediate-cleanup-*.json`.
Canonical c8b staging Prepare is rerunning the four changed validation components
and reusing six checked unchanged components; current output is not yet a pass.

The bcb synthetic account's real deletion quiet period elapsed, and the cleanup
command completed at `2026-10-28T19:05:11.899Z`. It verified Auth absence, canonical
profile/run/grant/validated-result absence, no board best/view/ghost entry and
absence of all recorded pending/validated/ghost artifacts. The compact completed
deletion tombstone retains its normal 30-day expiry. Mutation lock
`1793214272491703` was released. Evidence:
`candidate-bcb-staging-smoke-cleanup.log` and updated drill JSON. No owner's dev
account or production data was used or deleted.

Canonical c8b staging Prepare passed at `2026-10-28T19:24:17.0142373Z`, source
digest `9c12c7d2105803296844a8b53b118af89524f89f769150b484e59f8a8bc3f604`.
Fresh checks: 269 Functions tests, production build/inventory checks, 1,348 client
tests with one existing platform skip (the web-only fresh-install launch test),
301 worker tests and the AOT protocol probe. Client/lib/test/test_driver and worker
analysis passed; advisory audit found no vulnerabilities. Six unchanged components
were verified/reused, including the web artifact. The candidate also includes
already-committed message-console work from the main branch; its Functions input
changes were revalidated, not mislabeled unchanged. New component durations:
Functions checks 330 s, Functions build 38 s, client checks 1,067 s, worker checks
141 s. Log: `candidate-c8b-prepare-staging.log` and candidate release evidence.

Dev/prod Prepare subsequently passed using the verified ten-component cache and
fresh advisory audits. Their respective source digests are
`3c1b12893ebba736a70ab1f8931451de1ba81df65a2dde51a6fa5039873be529` and
`0f6e94f5572b161b0b3b5b652da51983bcdb725a992af4d706cd19020e7cc918`.
The candidate branch now points to c8b. Navigation reuse compared unchanged
Android/runtime inputs and verified all 3,753 files / 31,441,085 bytes against
bcb, including 3,750 graphs; manifest SHA-256
`6f65c41f501cc9618ecefd8ae3349d037656aacb567935ab81268f8639a812bd`.
Canonical BuildAndroid still checks freshness and packaged bytes. Staging AOT
completed for all three ABIs (3,904,292 / 4,470,368 / 4,469,408 symbol bytes).
Evidence: `candidate-c8b-navigation-reuse.json`, `candidate-c8b-serial-staging.log`.

Canonical staging BuildImage started Cloud Build
`32238450-f739-4eb3-8c4b-c4cefc9fc06c` at 19:27:38 UTC, tag
`release-9c12c7d21058-20261028192728`; mutation lock `1793215648752984` was released.
It is still WORKING, so no corrected image/deployment acceptance is claimed yet.
No c8b cloud runtime cutover or signed Android packaging has happened yet.

Additional bounded disk cleanup retained unique artifact bytes: six duplicate
APK/AAB/mapping files removed at 19:38 UTC (873,428,802 bytes), with every retained
counterpart hash verified. Three old web output trees were byte-identical to c8b's
verified cached web artifact (4,488 files each, tree digest
`e256d366cc7a0a08dad2f8ac64673edaf1d918d756e33a41327d8862c49a4875`);
removing them at 19:49 UTC recovered 541,269,378 bytes. Old checkout source and
signed Android artifacts remain; those old web paths require cache restoration
before any future use. Six imported CI artifact copies were verified against
their canonical component caches and removed at 19:56 UTC (494,936,256 bytes).
Import bundle/component metadata and validation logs remain, and retained caches
passed verification again afterward. Evidence: `release-output-deduplication-*`,
`old-web-deduplication-*`, `import-artifact-deduplication-*`. Free C: space was
4,114,898,944 bytes after these operations.

Staging c8b BuildAndroid version 1 has now started. The earlier BuildImage
submission command completed and released its lock before this independent
operator action; its asynchronous Cloud Build continues from the uploaded
immutable source snapshot. No operator release commands overlap. Image creation
is regenerating the full server navigation plan (38 routes), so its completion
and strict final-image benchmark remain pending. The staging AOT outputs have
not been invalidated by a flavor switch. Log: `candidate-c8b-android-staging.log`.

The first c8b BuildAndroid attempt stopped in preflight because the clean checkout
had no ignored `android/gradlew.bat`; lock `1793217419532801` was released. At
`2026-10-28T20:01:18.4069997Z`, the three missing generated wrapper files were
materialized from the pinned Flutter 3.47.1 SDK's own wrapper cache, following
its installed `GradleUtils.injectGradleWrapperIfNeeded` implementation. Each
copied hash matched, existing Gradle distribution properties were preserved,
and the candidate remained clean. Evidence:
`candidate-c8b-gradle-wrapper-bootstrap.json`. This is environment preparation,
not a source or dependency change. For future cold checkouts, the documented
`flutter build apk --config-only --flavor dev --release` initializes the same
ignored wrapper before canonical BuildAndroid. The staging retry acquired lock
`1793217731486308` and reached Gradle packaging. Its still-pending result is in
`candidate-c8b-android-staging-retry.log`; the initial failure remains preserved.

A read-only Play Developer API capability check at `2026-10-28T20:10:19.3626168Z`
returned HTTP 403 / `ACCESS_TOKEN_SCOPE_INSUFFICIENT` for both app packages using
the existing CLI login. No Play edit, upload or publication occurred. The
[device-tier configuration list endpoint](https://developers.google.com/android-publisher/api-ref/rest/v3/applications.deviceTierConfigs/list)
requires the Android Publisher OAuth scope; current cloud credentials cannot
replace a Play-authorized browser/API login. Evidence: `play-api-cli-access.json`.
This establishes a concrete access blocker for browser-free Play publication,
not a conclusion about the developer account's underlying app permissions.

Before the corrected runtime is deployed, the c8b live drill is prepared for a
bounded five-submission burst on one disabled synthetic account: Practice Field
and Forest, both current Competitive boards, and the current Weekly board. All
ranked projections must expose their exact run and generation-pinned ghost;
duplicate validation/settlement must leave wallet and canonical revision unchanged.
Predetermined limits are 60 seconds for observed validation plus settlement,
120 seconds for projection, sampled memory below 85% of the worker limit, and
300 CPU-seconds / 150 GiB-seconds of worker allocation in the observed window.
Resource allocation is a bounded cost proxy, not a billing total. Each payload
has 1,800 input frames; natural early termination is recorded and does not prove
full-run duration/capacity. Queue snapshots, actual terminal ticks, metrics and
the real account-deletion quiet period remain required evidence. This is a
prepared check, not a pass or Play/device acceptance.

Canonical c8b staging BuildAndroid passed at `2026-10-28T20:29:57.7921679Z`.
Version 1 / `1.0.0-staging`, package `com.lothringen.longrun.staging`, SDK 24/36,
AAB SHA-256 `f9db4dd6d2b15ca406b37c322450ad607c1a61d96019ed4d9ab1cf4a4b291699`,
174,459,163 bytes. Actual native resources/signing, 3,750 navigation graphs,
all three ABIs / nine native libraries and 16 KB ELF alignment passed;
Crashlytics symbols uploaded. Mutation lock `1793217731486308` was released.
Its completed native intermediates were removed at 20:33 UTC, recovering
1,814,609,139 bytes while all 11 retained artifact hashes matched. Evidence:
`candidate-c8b-staging-completed-intermediate-cleanup-{plan,result}.json`.

Memory pressure was relieved only after packaging completed: the verified idle
staging Gradle daemon 14212 was stopped. An earlier attempt to stop old Kotlin
daemon 20584 was aborted because its CPU changed. Once no Gradle clients/daemons
remained, its old release parent 34196 was confirmed absent and that orphan
compiler was stopped, releasing 2,150,285,312 committed bytes. Evidence:
`candidate-c8b-staging-gradle-idle.json` and
`candidate-bcb-orphan-kotlin-cleanup.json`. User applications stayed open.
Production sequential AOT is now running; production runtime remains undeployed.

Production sequential AOT subsequently passed for all three ABIs with the expected
symbol sizes. Canonical production BuildAndroid version 1 is now running, without
a flavor switch after priming. Logs: `candidate-c8b-serial-prod.log` and
`candidate-c8b-android-prod.log`. No production runtime cutover is authorized by
this artifact-preparation result.

Fresh source-registry policy and `gcloud builds get-default-service-account
--project=rpg-runner-d7add` verified dev build identity
`964001571974-compute@developer.gserviceaccount.com`. Under staging mutation lock
`1793220086390171`, granted only `roles/artifactregistry.reader` on staging's
`europe-west1/replay` repository so dev can reuse the corrected environment-neutral
image. The existing production build-account reader remains. Readback policy
etag is `BwZe7JbXiQM=`; the mutation lock was released before production packaging.
Evidence: `candidate-c8b-staging-registry-iam-{fresh-before,after}.json`.
No dev access to production resources or project-wide role was granted.

Completed-build cleanup and terminating only verified release-owned daemons
restored sufficient space. An optional read-only historical web-cache deduplication
scan was stopped; its mutation mode was never run. No hard links were created
and all canonical component-cache paths remain unchanged.

Corrected staging Cloud Build `32238450-f739-4eb3-8c4b-c4cefc9fc06c` completed
SUCCESS at `2026-10-28T20:54:01.913108Z`. Immutable image digest:
`sha256:9c81113febe223d1e399d12bdaa8253131e71a1df901611852d47b00b42edd80`.
The final-image `benchmark-release-image` step ran with `--cpus=1 --memory=512m`,
`--ticks=36000 --strict` and passed all eight gates. Seed 4401, generated-terrain
fixture without combat objectives: Forest 1.873056 s / 320.33x realtime;
Field 1.661960 s / 361.02x realtime. Both completed 36,000 command frames with
deterministic outcomes and sustained forward progress. The full server navigation
build ended at 9,500 windows / 93,910 graphs. This benchmark remains distinct
from cloud replay/settlement capacity and device acceptance. Evidence:
`candidate-c8b-staging-cloud-build-completed.json` and
`candidate-c8b-staging-image-benchmark.json`. Canonical ImageStatus is binding
this result to the candidate before any runtime cutover.

Production c8b BuildAndroid passed at `2026-10-28T21:01:26.1688121Z`:
version 1 / `1.0.0`, 174,459,406 bytes, SHA-256
`d3a7997b24839e369c9a06a5ca06ad8bb7406223a86199aeea425c83a0d25b44`.
Production resources, upload certificate, navigation assets, all native ABIs,
16 KB alignment and symbol upload passed. Lock `1793220283197707` was released.
After the completed bundle was copied by the canonical action and Gradle was
verified idle, only its release-owned Gradle 35564 and Kotlin 35264 processes
were stopped while independent final inspection continued; evidence:
`candidate-c8b-prod-gradle-idle.json`. The prior bcb bundle remains distinct.

Canonical staging ImageStatus accepted the successful build and exact digest,
persisting its source-bound release/cache evidence in
`candidate-c8b-image-status-staging.log`. Production intermediate cleanup removed
1,814,472,939 bytes at `2026-10-28T21:04:41.5138112Z`; all 11 retained hashes match
and the checkout remains clean. Free disk was 3,752,558,592 bytes. Dev sequential
AOT is running, and canonical production BuildImage is copying the verified
staging image with `-ReuseImageFrom staging`; both remain pending actions.

Both destination image-copy builds passed their own strict benchmark and canonical
ImageStatus verified exact digest equality: production build
`4200f874-bbef-49df-b099-ce6aeca286a3` finished at
`2026-10-28T21:09:15.720155Z`; dev build
`933b4257-cfd1-4052-bb21-15615f062a85` finished at
`2026-10-28T21:10:18.876093Z`. Copy submission locks `1793221674418495` and
`1793221741823762` were released. All three projects retain image digest
`sha256:9c81113febe223d1e399d12bdaa8253131e71a1df901611852d47b00b42edd80`.
Evidence: `candidate-c8b-verified-images.json`, copy/status logs and per-environment
`cloud-build.json`. Dev sequential AOT passed with symbol sizes 3,904,016 /
4,470,048 / 4,469,080 bytes. No flavor switch will precede its remaining canonical
APK packaging. The canonical c8b staging PauseIssuance action is now running;
runtime deployment/resume and the live drill are still pending.

Canonical staging PauseIssuance passed at `2026-10-28T21:16:09.9326353Z` and
released mutation lock `1793222111995324`. The new c8b source-bound cutover record
remains. Guarded Deploy is now running under lock `1793222223415327`; the fresh
drain gate passed and the coordinated backend phase excludes `runSessionCreate`.
Logs: `candidate-c8b-pauseissuance-staging.log`, `candidate-c8b-deploy-staging.log`.

Four completed c8b bundle/mapping output copies were removed at
`2026-10-28T21:18:55.3564206Z`, recovering 401,340,881 bytes after exact comparison
with retained canonical artifacts. No canonical artifact was removed; both AAB
hashes match their inspection records. Evidence:
`candidate-c8b-output-deduplication-{plan,result}.json`.

The corrected staging Deploy passed: Functions checkpoint
`2026-10-28T21:21:43.6360894Z`, worker checkpoint
`2026-10-28T21:25:31.0594148Z`, full deployment
`2026-10-28T21:25:42.2532295Z`. Mutation lock `1793222223415327` was released.
The saved inventory has all three expected compatible current boards active,
with zero missing/malformed/key/window mismatches. Guarded ResumeIssuance is
running and will recheck live readiness/boards before reopening issuance.
Fresh dev readback still shows worker `replay-validator-00059-ssr` at 100% traffic
and the latest Functions update on October 27, matching the preceding deployment;
no later dev deployment was found. Evidence:
`candidate-c8b-dev-before-cutover-{worker,functions}.json`.

Canonical staging ResumeIssuance passed at `2026-10-28T21:30:44.7660337Z`;
mutation lock `1793222822179117` was released and the source-bound cutover record
cleared. Both queues are running. Authorized readiness returned 200, anonymous
worker access 403, and the unauthenticated callable 401 at 21:33 UTC. The staging
project had no Auth users before the new fixture. Evidence:
`candidate-c8b-resumeissuance-staging.log`,
`candidate-c8b-staging-worker-verified.json`, and
`candidate-c8b-staging-http-inspection.json`.

The first expanded c8b drill started at `2026-10-28T21:35:45.762Z`, issued two
Field tickets and uploaded their payloads, then stopped before any dispatch.
Its Forest selection changed legacy `runType` but retained the prior `runMode`;
the canonical ownership validator correctly rejected the mismatched pair.
This fixture error is not a replay/projection result. Its original state/logs
remain `candidate-c8b-staging-smoke.json` and `candidate-c8b-staging-smoke-run.log`.
Normal account deletion entered `quiet_wait` at `2026-10-28T21:36:23.054Z`;
lock `1793223340373032` was released. No clock override or owner data reset was used.

The retry helper sets both fields and uses separate state/payload paths. A local
check against the frozen compiled ownership implementation reproduced the old
failure and accepted all six mode/level combinations, including both possible
Weekly levels, at `2026-10-28T21:41:25.760Z`. This check made no cloud writes.
Evidence: `candidate-c8b-smoke-selection-check.json`; retry entrypoint:
`staging_c8b_smoke_retry.ps1`. The original failed fixture remains available for
cleanup. Dev canonical BuildAndroid version 1 started during the real quiet wait,
without switching flavors after its successful AOT priming.

The owner then requested a safe pause. No fresh retry drill or dev runtime cutover
was started. The already-running dev BuildAndroid completed successfully at
`2026-10-28T21:56:20.1960089Z`: version 1 / `1.0.0-dev`, package
`com.example.rpg_runner.dev`, 184,126,366 bytes, APK SHA-256
`ce0aa0e2d08106cb13000de644939b8b3e8a15d4e768b93e2735663de077d376`.
Native resources/signing, 3,750 navigation graphs, three ABIs and 16 KB checks
passed. Dev symbols are retained locally; upload is intentionally only required
for staging/prod. Lock `1793223744781505` was released. All three artifact hashes
were checked together in `candidate-c8b-android-artifacts.json`.

After Gradle finished and the APK was copied, only the verified idle release-owned
Gradle 36968 and Kotlin 38188 processes were stopped at 21:56 UTC; final artifact
inspection continued independently. Evidence: `candidate-c8b-dev-gradle-idle.json`.
Dev build intermediates remain available; no further optional cleanup was started
after the pause request.

The normal synthetic-account deletion completed after the actual quiet period.
The cleanup action verified Auth, ownership, run/reward/validation records,
leaderboard/ghost references and recorded replay objects absent at
`2026-10-28T21:57:11.667Z`; only the intended compact 30-day tombstone remains.
Evidence: `candidate-c8b-staging-smoke.json` and
`candidate-c8b-staging-smoke-cleanup.log`. This closes fixture cleanup, not live
replay/projection acceptance: dispatch never began in this attempt.

Resume from the corrected, locally checked `staging_c8b_smoke_retry.ps1` with its
fresh state path. Keep the failed attempt intact. The frozen c8b checkout remains
the release authority; unrelated ongoing changes in the main worktree are excluded.
Dev's c8b runtime cutover, live staging replay/ghost/capacity checks, Play-delivered
acceptance and production runtime deployment remain pending. Production still
requires non-waived staging acceptance; no Play upload/publication occurred.

Cleanup lock `1793224608441765` was released. Both in-flight commands exited 0.
The safe pause is recorded in `candidate-c8b-pause-checkpoint.json`; frozen
source is clean, the retry state does not exist, and no release action remains running.

## October 29 CLI continuation

The owner resumed the saved checkpoint, retaining the no-browser scope. Main is
clean at `3f4955b9` with newer Admin changes; the clean frozen release checkout
remains `c8b353a6e332bad701b6c044d4d138cc17e64b85`. Canonical staging Inspect passed
at `2026-10-29T16:02:28.032Z`: worker `replay-validator-00002-27j` is Ready at 100%
traffic on the verified `sha256:9c81113febe223d1e399d12bdaa8253131e71a1df901611852d47b00b42edd80`
image, both queues are RUNNING, all three expected current boards are active,
zero runs/profiles/projections remain, and the two prior deletion requests are
compact completed tombstones. Evidence: `candidate-c8b-staging-resume-inspect-20261029.log`
and the canonical release inventory/worker/queues/scheduler readbacks.

The retry helper's read-only HTTP/Auth check passed at
`2026-10-29T16:05:01.610Z`: zero Auth users, authorized readiness 200, anonymous
worker 403 and unauthenticated callable 401. Evidence:
`candidate-c8b-staging-http-inspection-20261029.json`. The corrected five-replay
drill was then started with its separate retry state/log paths.

Free disk had fallen below 1 GB. Completed dev build intermediates were removed
at `2026-10-29T16:03:33.5768879Z`, recovering 1,290,265,765 bytes; all nine retained
artifact/evidence hashes matched and frozen source stayed clean. Only the reviewed
candidate's `build/app/intermediates` and `.dart_tool/flutter_build` were removed.
Free disk after cleanup was 2,245,718,016 bytes. Evidence:
`candidate-c8b-dev-completed-intermediate-cleanup-{plan,result}.json`.

Context7 is now available, but two scoped Cloud Monitoring queries returned no
matching documentation. Google's official
[metric reference](https://docs.cloud.google.com/monitoring/api/metrics_gcp_p_z#run)
and [distribution schema](https://docs.cloud.google.com/monitoring/api/ref_v3/rest/v3/TypedValue#Distribution)
confirm minute sampling, up to 120 seconds visibility delay, allocation units and
bucket upper-bound semantics. Before dispatch, the ignored metrics helper was
updated to retain raw responses, accept the three documented histogram layouts,
and require a full sampling-plus-visibility delay after its fixed observation
window. Original resource and latency limits are unchanged. These are short-drill
resource measurements, not billing totals or full-run capacity acceptance.

The corrected live drill passed at `2026-10-29T16:08:34.827Z`. It submitted five
payloads concurrently through the actual task queue; snapshots observed up to
five concurrent dispatches and both queues drained. All runs were accepted and
settled within the predeclared 60-second observed limit:

| Case | Seed | Actual terminal tick | End reason | Gold | Observed settlement |
| --- | --- | ---: | --- | ---: | ---: |
| Practice Field | 15 | 1,800 | gaveUp | 3 | 4.042 s |
| Competitive Field | 871327128 | 1,047 | fellIntoGap | 2 | 4.116 s |
| Practice Forest | 7 | 494 | fellIntoGap | 0 | 4.056 s |
| Competitive Forest | 1884823297 | 903 | fellBehindCamera | 2 | 4.106 s |
| Weekly Field | 1933856514 | 211 | fellIntoGap | 0 | 12.015 s |

Each input stream contained 1,800 frames; four runs naturally ended earlier.
All five have an empty Codex enemy-kill map, directly exercising the original
Firestore projection regression. All three ranked boards produced the exact
run's best/top10 entry and an active exposed ghost before the declared deadline.
Downloaded Storage generations `1793290085140759`, `1793290085159526` and
`1793290086809339` passed the actual Dart codec's recomputed digest/run-ID checks.
Duplicate private-worker delivery and settlement returned already-settled outcomes;
wallet gold stayed exactly 7, each grant appeared once, and revision stayed 9.
Evidence: `candidate-c8b-staging-smoke-retry.json`, its run log and
`candidate-c8b-staging-drill-summary.json`. This is real backend/domain/queue
coverage; Play sign-in, attestation, client upload grants, lifecycle recovery,
full combat and full-run capacity are not established by these short fixtures.

Cleanup entered real `quiet_wait` at `2026-10-29T16:09:10.004Z`; mutation lock
`1793290035934565` was released. Final post-quiet-period verification is recorded below.

Cloud metrics passed after the documented visibility delay. Fixed observation
window `16:06:00Z` to `16:10:34.827Z`, read at `16:14:37.155Z`: 11 memory samples
with a 20% histogram upper bound versus the 85% limit; 69.82485960933984 CPU-seconds
versus 300; 12.35 GiB-seconds versus 150; 13 worker requests and zero 5xx. Both
queues were RUNNING and empty. All six metric responses were complete and referred
only to `replay-validator-00002-27j`. Evidence:
`candidate-c8b-staging-smoke-retry-metrics{-raw,}.json` and
`candidate-c8b-staging-metrics-response-check.json`. The window includes duplicate
validation and nearby requests. Allocation is a bounded resource-cost proxy,
not the complete bill or sustained load/capacity proof.

Fresh dev Inspect passed at `2026-10-29T16:09:31.482Z`. Its unchanged serving
worker is `replay-validator-00059-ssr`; the newest Function deployment remains
October 27. Ten sessions comprise five validated, one expired and four issued;
all five accepted grants are settled and no quarantined/stale settlement exists.
The four issued tickets are still valid, expiring between
`2026-10-29T17:49:25.396Z` and `2026-10-29T19:18:28.347Z`
(19:49–21:18 Helsinki). Canonical drain rules therefore block c8b dev cutover.
No PauseIssuance, cancellation or data reset was performed; dev remains online.
Evidence: `candidate-c8b-dev-resume-inspect-20261029.log` and its canonical inventory.

Read-only operational checks also confirm all 31 expected alert policies enabled
with a usable project-local email channel in each of staging/prod; actual incident
delivery remains untested. Production Cloud Run inventory is empty. Both managed
production backups are READY; the newer snapshot is October 28 at
`21:41:12.845107Z`, expiring November 4, alongside the preceding October 27 backup.
Backup presence does not replace the already-recorded synthetic restore rehearsal.
Evidence: `candidate-c8b-monitoring-readback-20261029.json`,
`candidate-c8b-prod-services-20261029.json`, `candidate-c8b-prod-backups-20261029.json`.

Play's read-only API still returns 403 / `ACCESS_TOKEN_SCOPE_INSUFFICIENT` for both
packages at `16:12:16.9178553Z`; no Play changes occurred. ADB inventory at
`16:12:19.5751286Z` still has no attached device. Evidence:
`play-api-cli-access-20261029.json`, `candidate-c8b-adb-availability-20261029.json`.

Staging scaling readback confirms concurrency 1, maximum 10 instances and startup
CPU boost enabled on revision `replay-validator-00002-27j`, with the earlier
fresh resource readback confirming 1 CPU / 512 MiB. Both queues permit five
concurrent dispatches at five dispatches/second. Production's canonical requested
worker settings are the same, but no production runtime exists to establish live
scaling or capacity equivalence. Evidence:
`candidate-c8b-staging-resource-limits-20261029.json`.

Post-quiet-period cleanup passed at `2026-10-29T16:24:57.669Z`. Auth, ownership,
run/reward/validation records, board best/top10/ghost references and recorded
Storage payloads were verified absent; only the intended compact 30-day tombstone
remains. Cleanup lock `1793291093547837` was released and the command exited 0.
Evidence: `candidate-c8b-staging-smoke-retry-cleanup.log` and the updated retry
state/summary. No test fixture remains live. Dev's final readback at
`2026-10-29T16:23:04.171Z` still has the same four valid issued tickets and no
quarantined settlement; its cutover remains blocked and issuance stays online.

Final canonical staging Inspect at `2026-10-29T16:26:27.689Z` confirms zero run sessions,
ownership profiles, player bests, ghost manifests and active deletions; three
compact completed tombstones and all three current boards remain. Both queues
are RUNNING and the same corrected worker revision is Ready. Evidence:
`candidate-c8b-staging-final-inspect-20261029.log` and
`candidate-c8b-cli-checkpoint-20261029.json`. The frozen checkout is clean.
Only the two release documents changed in the main worktree; no new app/runtime
implementation or production deployment was performed in this continuation.

## October 29 owner-authorized dev cancellation and c8b cutover

After the earlier blocked checkpoint, the owner explicitly authorized cancelling
the outstanding dev runs. Source remains clean frozen commit
`c8b353a6e332bad701b6c044d4d138cc17e64b85`, with dev source digest
`3c1b12893ebba736a70ab1f8931451de1ba81df65a2dde51a6fa5039873be529`.
No account reset or production deployment was included.

From the main repository, `pwsh -NoProfile -File
.tmp/beta-checks/cutover_c8b.ps1 -Environment dev -Action PauseIssuance`
invoked canonical `tools/release/release.ps1` from the frozen checkout and exited 0.
The old issuer image had been removed by managed cleanup, so the supported
recovery rebuilt only the prepared issuer with `release-paused` explicitly set.
Healthy serving revision `runsessioncreate-00075-naw` was verified at 100% traffic;
pause completed at `2026-10-29T16:57:07Z`. The source-bound cutover record remained
and mutation lock `1793292760217554` was released. Both queues were left running
while validation and settlement drained.

The ignored helper `.tmp/beta-checks/cancel_dev_c8b.ps1` ran `-Action inspect`,
`apply`, then `verify` from the main repository; each exited 0. Review required
exactly four issued sessions on `2026.10.21`, no upload/validation lease or finalized
payload, no corresponding reward/validated record, and verified absence of each
replay object in dev's configured bucket. Apply reacquired the dev mutation lock,
verified the frozen source, cutover owner and healthy paused serving revision,
and reread the same records inside a Firestore read-write transaction. Document
update-time preconditions and the exact reviewed set guarded its atomic commit.

Commit succeeded at `2026-10-29T16:58:26.721119Z`: exactly four sessions became
`cancelled`, with terminal/update timestamps and an owner-authorization message;
the retry timestamp was cleared. No documents or replay objects were deleted.
Mutation lock `1793293088245689` was released. At `16:58:53.497Z`, readback verified
all ten sessions terminal, the six other sessions unchanged, all five settled
reward grants and five validated records unchanged, and the existing ownership
and player profiles unchanged. Only the five declared session fields changed.
Reviewed set SHA-256:
`5b6706cea186c67e6416ffc7ed73eaa3d99a8c45a73a508c2e81f53ea213b153`.
Evidence under `.tmp/beta-checks/`: `candidate-c8b-pauseissuance-dev.log`,
`candidate-c8b-dev-cancellation-{plan,result,verified}.json` and the corresponding
`inspect`, `apply`, `verify` logs. The operational helper passed Node syntax
validation; no runtime implementation changed.

The first canonical dev Deploy passed source/image/pause/drain checks and paused
both queues, then failed during local Firebase function discovery at 17:00 UTC
with `TypeError: fetch failed`, before uploading the backend. No backend/worker/
Hosting checkpoint was recorded. The release lock `1793293168623230` was released and
the source-bound maintenance record retained. Both PowerShell HTTP and the pinned
Node 24 fetch subsequently read the same complete local manifest successfully
(HTTP 200, 12,104 bytes). The failed CLI had left its discovery server orphaned;
after verifying its exact frozen-checkout identity and absent parent, only that
process was stopped, allowing the failed command to exit 1. The unchanged
canonical Deploy was then retried. Evidence: `candidate-c8b-deploy-dev.log`,
`candidate-c8b-dev-discovery-recovery.json`, and the separate timestamped retry log.

The retry `cutover_c8b.ps1 -Environment dev -Action Deploy` exited 0. Backend
Functions/rules/indexes completed at `17:09:40.1357524Z`, worker configuration at
`17:12:24.9369773Z`, and Hosting/full Deploy at `17:13:19.7151682Z` on October 29.
All 4,487 prepared Hosting files were published. Mutation lock
`1793293525745176` was released; issuance and both queues remained paused.
The immutable image remains
`sha256:9c81113febe223d1e399d12bdaa8253131e71a1df901611852d47b00b42edd80`.

Canonical dev Inspect before resume exited 0. Its `17:14:18.855Z` inventory
confirms four cancelled, one expired and five validated sessions; five settled
grants and the existing 1,134-gold balance; three active current boards and zero
missing boards. Worker `replay-validator-00060-lcd` is Ready and serves 100% of
traffic with the exact prepared digest. Evidence:
`candidate-c8b-deploy-dev-retry-20261029T170440Z.log`,
`candidate-c8b-dev-before-resume-inspect-20261029.log`,
`candidate-c8b-dev-before-resume-inventory-20261029.json`, and canonical
`release.json`/`worker.json`.

Guarded `cutover_c8b.ps1 -Environment dev -Action ResumeIssuance` exited 0 and
recorded restored issuance at `2026-10-29T17:18:42.6365743Z`.
The canonical action rechecked the exact Ready
worker/traffic, current boards and drained inventory, and downloaded live Hosting
JavaScript to verify it matched the prepared artifact. Both queues resumed, the
issuer was deployed, the temporary compatibility override was removed and the
source-bound cutover record cleared. Baseline verification completed at
`17:18:55.7780169Z`; mutation lock `1793294111836032` was released. Live/prepared
Hosting SHA-256:
`7c08d5b9078fd8bd6336ed2ab6dd3ff7ac9552ce2f037820df49756819765423`.

Final canonical Inspect and `.tmp/beta-checks/verify_dev_c8b_http.ps1` exited 0.
The `17:20:00.021Z` inventory still has four cancelled, one expired and five
validated sessions; all five rewards are settled, with no stale/quarantined
settlement or invalid ownership. The 1,134-gold wallet, existing valid player best
and ghost remain. Both queues are RUNNING and all three current boards active.
At `17:20:15.0571691Z`, authorized worker readiness returned 200, anonymous worker
access 403 and unauthenticated session creation 401. Both `_release/cutover.json`
and `_release/mutation-lock.json` returned 404. Separate live issuer readback at
`17:20:45.7875873Z` verified `runsessioncreate-00077-kj5` healthy at 100% traffic
with no temporary pause override.

Final evidence under `.tmp/beta-checks/`:
`candidate-c8b-resumeissuance-dev.log`,
`candidate-c8b-dev-post-cutover-inspect-20261029.log`,
`candidate-c8b-dev-post-cutover-inventory-20261029.json`,
`candidate-c8b-dev-http-final-20261029.{log,json}`,
`candidate-c8b-dev-issuer-final-20261029.json`, and
`candidate-c8b-cli-checkpoint-after-dev-20261029.json`.
The frozen checkout remains clean. No browser, Play upload or production runtime
deployment was used. Play-delivered authentication/attestation, device acceptance
and reviewer-account handoff remain open and continue to gate production.

## October 29 connected-phone dev smoke

Live checks ran from `C:\dev\rpg_runner` against `rpg-runner-d7add` on the owner's
OnePlus CPH2465, Android 15/API 35, ARM64, with a 2400x1080 landscape display.
Source remained frozen at `c8b353a6e332bad701b6c044d4d138cc17e64b85`; no runtime
code or release artifacts changed. The dev package is `com.example.rpg_runner.dev`,
version 1 / `1.0.0-dev`, targeting API 36.

`adb devices -l` confirmed an authorized USB device. `pm path`, installed-package
metadata and `apksigner verify --print-certs` verified the existing package and
matching signer before `adb -s <device> install -r --no-incremental <dev-apk>`
returned Success at `17:44:56.2637295Z`. Account/data and first-install time were
preserved. Readback of the installed APK's SHA-256 matched the canonical artifact:
`ce0aa0e2d08106cb13000de644939b8b3e8a15d4e768b93e2735663de077d376`.
The temporary old APK copy was removed after hash verification (184,126,366 bytes);
canonical artifacts and the legacy package were retained. Staging/prod are absent.

`adb shell am start -W -n com.example.rpg_runner.dev/com.example.rpg_runner.MainActivity`
opened the existing signed-in hub with 1,134 gold. The owner was asked to play a
short Competitive run and try movement/jump/attack, then replied "finished".
Read-only `.tmp/beta-checks/observe_dev_phone_c8b.mjs` queried Firestore sessions,
validated records, grants, ownership and projections; screenshots independently
confirmed the visible wallet and leaderboard. Both observed Forest runs used
compatibility `2026.10.21`, `rules-v2`, `score-v4`, `ghost-v1`:

| Check | Owner's run | Brief ghost-launch run |
| --- | --- | --- |
| Run ID | `run_9a519e8c7ca4f7dff8e84610e5b3143da65291e1` | `run_9258536689af1e269b7a0df90614136f774b94c9` |
| Score / distance / end reason | 480 / 65 m / `gaveUp` | 15 / 0 m / `fellBehindCamera` |
| Validation and grant | accepted / `validated_settled` | accepted / `validated_settled` |
| Gold / applied grant count | 2 / exactly 1 | 0 / exactly 1 |
| Validated replay generation | `1793296123560494` | `1793296354442528` |

The owner's run settled at `17:48:43.940Z`; the wallet increased to 1,136 and
progression to 21/124 XP. `KEYCODE_HOME` followed by activity launch, then an
explicit `am force-stop` and cold relaunch, retained the account and balance.
Server readback after relaunch confirmed the first grant still applied once.
These transitions were tested after settlement, not during a pending upload.

Competitive Forest leaderboard loaded the existing 9,750-point, 888 m best
(`run_ade711be3a6aefb24569d0ad1e86d56c1ee6f3d3`). VS Ghost launched successfully;
a screenshot shows the translucent ghost moving separately from the player.
The three-second idle check run ended naturally, was collected and settled for
zero gold. Both new scores correctly left the higher best and exposed ghost
unchanged, including pinned ghost generation `1793126913215742`. Playback may
have used the existing cache; this does not prove a fresh network download.

Cold launch/relaunch reported 1,090/1,159 ms. Scoped PID-filtered AndroidRuntime/
Flutter error captures contained no error lines; exit-info since installation
showed only the requested force-stop. PSS snapshots were 236,301 KB at startup,
277,731 KB after the owner's run, 524,972 KB during ghost playback and 313,095 KB
at the final hub. These are bounded observations, not sustained memory/frame-time
acceptance. The owner supplied no separate qualitative controls/performance report.

The final device summary was recorded at `2026-10-29T17:55:47.6805088Z`. The app
was left at the hub with 1,136 gold and both grant IDs applied once. One issued
ticket, `run_5a31d07a5750f9494d706387f15ca0b6d229bcb2`, remained untouched;
no device-session cancellations or data resets were performed. Evidence lives in
`.tmp/beta-checks/device-c8b-20261029/`: `summary.json`, `install.json`, timestamped
observations, sanitized error captures and screenshots including
`ghost-playback.png` and `final-hub.png`.

This exercised the existing dev sign-in and configured debug App Check provider.
Fresh Play Games sign-in, Play-delivered staging/prod identities and integrity,
offline/pending-submission recovery, incompatible-update rehearsal and sustained
multi-device QA remain open. No browser, Play upload or production deployment
was used. Production remains gated on non-waived staging acceptance.

## October 29 staging Play internal publication

After explicit approval to close/reopen only the dedicated `rpg-runner` Chrome
session, the profile lock was released and Playwright connected successfully.
The existing Play Console sign-in remained usable. Native browser inventory still
did not expose Chrome; this recovery used the configured Playwright integration.
The main worktree was clean at `05cb638c`; the frozen c8b checkout remained clean.

From `C:\dev\rpg_runner`, `Get-FileHash -Algorithm SHA256` reverified the canonical
staging AAB as `f9db4dd6d2b15ca406b37c322450ad607c1a61d96019ed4d9ab1cf4a4b291699`
before upload to staging app `4975698862921375548` under developer
`8150014461378797161`. The existing draft had no artifact attached. The existing
Toonsa tester list was inspected and contained exactly the owner account; its
membership and selection were unchanged.

Play processed version code 1 / `1.0.0-staging`, minimum API 24, target API 36,
three ABIs, with ReTrace mapping and native debug symbols attached. Review showed
Ready to release, no blocking findings and an estimated 121 MB fresh download.
Published the named release `1.0.0-staging (1) - c8b353a6` to internal track
`4701264247659999845`. Confirmation completed at `2026-10-29T18:28:09.562Z`;
readback showed Active and Available to internal testers, released at 20:28
Helsinki, Not reviewed, with the temporary package-based unreviewed display name.
No production release or wider distribution was performed.

The owner account accepted its existing invitation at `18:29:04.075Z`; readback
confirmed tester status. Opt-in URL:
`https://play.google.com/apps/internaltest/4701264247659999845`.
The Play listing was reachable and offered installation on the known OnePlus
CPH2465. The web installation flow stopped at Google's identity-verification
prompt before installation was verified. The phone was asleep/locked; the owner
was asked to unlock it for installation directly through its Play Store.

The read-only staging observer at `18:27:10.547Z` found zero profiles/run sessions
before device testing. `gcloud run services describe runsessioncreate
--project=lothringen-long-run-staging --region=europe-west1` read back Ready
revision `runsessioncreate-00007-rwp` and `APP_CHECK_ROLLOUT_MODE=enforce`.
These are setup/baseline observations, not evidence of a successful device verdict.

Local evidence: `.tmp/beta-checks/play-staging-c8b-20261029.json`, browser snapshots
under `build/playwright-mcp/`, and the separate
`.tmp/beta-checks/device-staging-c8b-20261029/` directory. No source/artifact changes
or account resets were made. Play-installed sign-in, attestation and run acceptance
remain pending and continue to gate production.

## October 29 staging Play installation and first authentication

After the owner unlocked the connected OnePlus CPH2465 (Android 15/API 35),
`adb shell am start -W -a android.intent.action.VIEW` opened the staging listing
in `com.android.vending`. Install and Play were selected in the phone's Play
Store. Installation completed at `2026-10-29T18:44:48Z`. No APK was sideloaded.
The app remains separate from the existing dev installation and its data.

From `C:\dev\rpg_runner`, `adb shell pm list packages -i` and scoped
`dumpsys package` report installer/initiator `com.android.vending`, version code
1 and version name `1.0.0-staging`. This device's generated APK reports minimum
API 32 and target API 36; the uploaded bundle's Play metadata reports minimum
API 24. `pm path` identified the installed base APK, which was pulled only for
verification. Android build-tools 36.0.0 `apksigner verify --print-certs` passed
with the registered Play distribution SHA-256
`6272ea6a975b3a59283153010be2ad3f53e958897e34fd034a797d8acbbd842f`, distinct
from the upload key. It reported two unknown additional v3 attributes; signature
verification returned exit 0. The frozen source and uploaded AAB are unchanged.

First-launch logs confirm a non-empty Play Games server-auth-code response.
The app reached first-profile naming and then the hub using the owner's existing
Google account. The new staging profile started at level 1, 0/100 XP and zero
gold; its display name is Toonsa. This is a fresh staging profile, not a separate
fresh Google tester account.

Client `app_check_startup` reports release/Android, provider `play_integrity`,
token acquisition `available`, failure `none`, Firebase app
`1:943085064373:android:51c288ba51386d01572efc`. Scoped `gcloud logging read`
observations since installation confirm `authenticated`, `verified` and
`rolloutMode=enforce` for profile/loadout/inbox calls and `runSessionCreate`.
Ten allowlisted observations were saved at the first checkpoint; no token or
raw authentication payload was retained. Initial current-process diagnostics
contained zero fatal/unhandled exceptions and PSS 203,157 KB. This bounded
snapshot does not establish sustained performance or diagnostics acceptance.

Evidence: `.tmp/beta-checks/device-staging-c8b-20261029/` contains `install.json`,
`installed-package.txt`, `first-launch-diagnostics.json`,
`app-check-observations.json`, timestamped server observations and phone
screenshots. Competitive is selected, awaiting the owner's short run. Production
remains gated on the remaining non-waived staging acceptance checks.

## October 29 staging Play run, ghost and restart smoke

Continued from clean main `37da62e6` after the owner reported the phone run
finished. Tested source remains frozen c8b, staging Play version 1. All commands
ran from `C:\dev\rpg_runner`; phone interaction used scoped ADB commands, and
the existing read-only observer queried only staging. No source or artifact
changed, and no additional browser access was needed.

| Observation | Owner Competitive run | Brief ghost-playback check |
| --- | --- | --- |
| Run ID | `run_fe47ed1a3a9eb43c70af62963aa63a7d29e38d31` | `run_77dc8b6580e3bcd96c16108b94c8be0a0b54a1b5` |
| Level / mode | Forest (Val Outpost) / Competitive | Forest / Competitive |
| Score / distance / end reason | 9,235 / 822 m / `fellBehindCamera` | 15 / 0 m / `fellBehindCamera` |
| Validation / grant | accepted / `validated_settled` | accepted / `validated_settled` |
| Gold / applied grant count | 40 / exactly 1 | 0 / exactly 1 |
| Validated replay generation | `1793300393052847` | `1793300592105743` |

The owner run's canonical replay SHA-256 is
`31ca9e37a203b9b3d01d321e958063b7642edbe969ff75b4b621cff3fdc2c790`.
It updated at `18:59:53.337Z`; readback confirms the new staging wallet increased
from zero to 40 gold. The app shows level 1, 46/100 XP. The Competitive leaderboard
displays rank 1 of 1, score 9,235, 822 m and duration 02:14. The player best,
top-ten projection and exposed active ghost all reference this run, with promoted
ghost generation `1793300398302962`.

VS Ghost fetched its manifest and launched successfully. `ghost-visible.png`
shows the outlined ghost overlapping at the start; `ghost-end.png` shows it
separately airborne to the right of the idle player. This was the first ghost
launch in a fresh staging installation, for a run created after installation.
Together with the frozen cache's download-before-write path, this supports a fresh
download; no independent HTTP trace or private app-cache inspection was captured.
The three-second idle test ended naturally and settled for zero gold, leaving the
owner's best and ghost unchanged. App Check logs confirm verified, authenticated
requests under `enforce` for upload grant, finalize, status, leaderboard and ghost
manifest calls.

After both runs settled, `KEYCODE_HOME` followed by activity launch restored the
leaderboard. Returning to the hub, `am force-stop` followed by `am start -W`
relaunched the staging app and preserved the same account, 40 gold and 46 XP.
Android reported cold activity launch 1,465 ms; this is not time to the fully
initialized hub. Final observer readback at `19:05:18.103Z` retained revision 4
and exactly one application of each grant. Restart startup again acquired a Play
Integrity token successfully; fresh server observations remained verified.

Current-process log snapshots before/after restart contain zero fatal/unhandled
exceptions. Package-scoped exit-info contains only the requested force-stop, no
crash/ANR entry. PSS was 237,036 KB after the owner run, 285,321 KB before restart
and 226,338 KB afterward. These samples and one 2:14 run do not establish sustained
or representative multi-device performance. In the subsequent qualitative
follow-up, the owner confirmed movement, jump and attack were responsive with
no noticeable stuttering in the Play-installed staging run. This is owner-reported
evidence for that run, not instrumented frame-time or multi-device acceptance.

Two issued, unsubmitted tickets remain untouched: initial Practice ticket
`run_cc0e4cdb262189f7849c4ca26812cdaad024ee7e` and post-restart Competitive ticket
`run_fa60486b9e935ffc360f04ffb6160a4f2b7c7830`. No cancellation, account deletion,
data reset or phone connectivity change occurred. These lifecycle checks ran
after settlement and do not cover offline or pending-submission recovery.

Evidence remains in `.tmp/beta-checks/device-staging-c8b-20261029/`: updated
`summary.json`, timestamped observations, `app-check-after-run.json`,
`app-check-ghost.json`, `app-check-after-restart.json`, scoped diagnostic snapshots,
`cold-relaunch.txt`, `exit-info.txt` and screenshots. The phone is at the staging
hub. Production remains undeployed pending the other non-waived acceptance gates,
including separate fresh tester/reviewer accounts, offline/pending recovery,
incompatible-update rehearsal, diagnostics and broader device QA.

## October 29 unused Play draft removal

At the owner's request, removed the unused Long Run draft app
`4975420968170292531` from developer account `8150014461378797161`. Before
deletion, the home-page row identified it as Draft, last updated March 10, with
no package shown; its View link matched the recorded empty legacy listing.
The separate staging and production rows had their expected packages and IDs.
The draft-specific Delete action opened the non-restorable deletion confirmation;
confirmation completed at approximately 20:14 UTC (22:14 Helsinki).

Fresh console readback shows exactly two apps: staging
`4975698862921375548` / `com.lothringen.longrun.staging`, still Internal testing,
and production `4975092661531994619` / `com.lothringen.longrun`, still Draft.
No dev Play app was created. No Firebase project, backend, device installation,
tester membership or retained release was changed by this cleanup. Historical
sections above describe the old draft before its removal.
