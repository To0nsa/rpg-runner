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
