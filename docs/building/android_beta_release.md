# Android beta release with dev, staging and production

Status: paused at the owner's request on October 28, 2026 (Helsinki), after work without
browser access; started October 26, 2026. Resume only when the owner asks. This is the
active checklist for reusing the existing project for development, creating
isolated staging and production backends, and releasing an Android beta through
Google Play. Team expansion and internal release-candidate testing make staging
part of this workstream now, including before the first production beta.
Prefer the smallest implementation that provides reliable isolation and routine
releases. A second Firebase registration in the same project is not environment
isolation.

The agent will perform repository work, CLI operations and console configuration
through the user's connected Chrome session where no suitable CLI/API exists.
The October 26 execution request authorizes project/configuration/signing/CI
setup, use of the existing billing account, deployments, maintenance/pause/resume,
and internal/closed Play publication. Public rollout remains excluded. Complete
reviewable preparation and retain all non-waived acceptance gates.

## Execution checkpoint - October 28, 2026

October 28 continuation: the owner requested all remaining work that can proceed
without browser access, then requested a safe pause. The in-flight dev APK build
completed and the temporary account's real-clock cleanup was verified. No retry
drill or dev cutover was started after the pause request. Resume the corrected
frozen c8b candidate only on the owner's instruction.
Play-delivered staging acceptance still gates production deployment. Browser-only
configuration/publication and the dedicated reviewer-account handoff remain open.

Current candidate: `c8b353a6e332bad701b6c044d4d138cc17e64b85`. Prepare passed for
all three environments. Its staging version 1 AAB passed canonical verification
and symbol upload at 20:29 UTC, SHA-256
`f9db4dd6d2b15ca406b37c322450ad607c1a61d96019ed4d9ab1cf4a4b291699`.
Production version 1 AAB verification/symbol upload passed at 21:01 UTC, SHA-256
`d3a7997b24839e369c9a06a5ca06ad8bb7406223a86199aeea425c83a0d25b44`.
The corrected worker image and both registry copies passed their strict benchmark
and canonical ImageStatus with identical digests; dev AOT passed. Staging c8b
deployment passed at 21:25 UTC: `replay-validator-00002-27j` is Ready at 100%
traffic, and all three expected boards are active. Guarded ResumeIssuance passed
at 21:30 UTC, with queues running and the cutover record cleared. The first c8b
five-case drill stopped before dispatch because its fixture changed the legacy
runType without updating runMode. Local checks reproduce that rejection and
confirm the corrected sequence. Account/data/artifact deletion was verified at
21:57 UTC after the real quiet period. The fresh retry drill remains unstarted.
Dev version 1 APK verification passed at 21:56 UTC, SHA-256
`ce0aa0e2d08106cb13000de644939b8b3e8a15d4e768b93e2735663de077d376`.
All three native artifacts and all three immutable images are retained. Dev's
existing runtime remains unchanged; production runtime remains undeployed.
The CLI's existing cloud login cannot access the Play publishing API: both apps
return HTTP 403 for insufficient OAuth scope. No Android device is attached.

Previous bcb CLI progress: dev and production Prepare passed; staging preparation and
both destination images remain verified. All ten production validation components
were reused only after input/artifact checks; the fresh advisory audit passed.
Guarded recovery at 17:11 UTC transferred staging's cutover record to bcb after
fresh empty-project, paused-issuer/queues and no-active-build checks. Staging AOT
completed for all three ABIs. Canonical staging BuildAndroid passed at 17:33 UTC,
including signing/resources/assets, 16 KB checks and symbol upload. Version 1 AAB
SHA-256: `8e3c12cfa933e38060af554af79c317125bd367eb3774721af68fbfabd523914`.
After the first Eventarc propagation failure, the retry deployed all staging
Functions, rules and index definitions at 17:57 UTC. It stopped at the index
readiness gate: 10 CREATING / 2 READY on immediate readback. Its checkpoint was
reused after all 12 staging indexes became READY. Canonical Deploy passed at 18:34 UTC, with
worker `replay-validator-00001-rsg` Ready at 100% traffic on the verified image.
Guarded ResumeIssuance passed at 18:42 UTC; its source-bound cutover record was
cleared and mutation lock released. Production BuildAndroid passed at 18:23 UTC,
version 1 / `1.0.0`, AAB SHA-256
`0304e471ef42b931e57a661245d3b8b23cc279017028ea93dde75b8ff91eafab`,
including production signing/resources and symbol upload. Dev packaging and
staging CLI acceptance remain. No production service deployment has
occurred. No Android device is currently attached.

Staging acceptance found a blocker at 18:49 UTC: both synthetic replays were
accepted and settled, but leaderboard/ghost projection timed out. The worker
decoded an empty Firestore map as null, invalidating runs whose Codex kill map
was empty. The regression reproduces this locally; the decoder fix preserves
empty maps/arrays. All 301 worker tests, analysis and executable compilation
pass. Replacement candidate `c8b353a6e332bad701b6c044d4d138cc17e64b85` is frozen
in its canonical clean checkout and pushed to the candidate branch. Prepare has
passed for all three environments; the corrected staging worker image is verified.
Staging signed packaging passed for all three architectures. Complete the
remaining native artifacts, guarded deployment and live drill. The bcb artifacts retain their original
identity and are not an accepted release. Its temporary account/data cleanup
passed at 19:05 UTC after the real quiet period; only the intended tombstone remains.

Previous pause, October 27 at 22:10 UTC / 00:10 Helsinki: both active local commands were interrupted
and returned exit 1: the remaining preparation/image loop and staging sequential
AOT compilation. This was an owner-requested pause, not a passing build result.
Staging Prepare passed at 22:07:11 UTC, source digest
`71ed90cfad8e455f9820a63d539da4e34d3dda589cc3112802b31c321655cba0`;
its cached immutable image was verified and the mutation lock released. Production
Prepare is incomplete; final-candidate dev Prepare has not started. Staging AOT
has only ARM32 symbols, so native packaging is not ready. No new cutover recovery
or deployment was performed. Dev remains online; staging remains paused under
the preceding f44 cutover record; production has no game deployment.

The owner authorizes cleaning unused `.tmp` content to free space, then explicitly
requested this pause. Resume with a bounded inventory/cleanup, preserving active
candidate source, final artifacts/symbols, verified caches and release evidence.
Do not wipe `.tmp`: it contains the frozen candidate and the only local copies
of signed builds. About 4.75 GB was free at pause. The dedicated reviewer account
has not been created. Browser connection remains unavailable.

Temporary cleanup completed on October 28 at 18:45 Helsinki. Removed 38 unused
build/test/profile directories (6.22 GiB); C: had 6.58 GiB free afterward.
All 251 retained artifact/metadata hashes matched and all 12 release checkouts
remained clean, including the frozen bcb candidate. Source, signed builds,
symbols, navigation data, shared release caches and release evidence are retained.
Details: `.tmp/beta-checks/tmp-cleanup-{plan,result,verification}.json` and the
linked verification record. Preparation resumed after this cleanup checkpoint.

Previous bcb resume helpers/logs live in `.tmp/beta-checks/`: `prepare_android_serial_bcb.ps1`,
`recover_staging_bcb.ps1`, `candidate-bcb-*`. Guarded recovery is now complete;
the original record and fresh inspection are retained in the evidence. Current
c8b work is listed above and in Next action. Reuse evidence only for unchanged
inputs; do not deploy production before non-waived staging acceptance.

Preceding frozen candidate: `bcb59300e98c3563adc3ca32bddcd89c2813cedb`, pushed to
`release/android-beta-browser-check`. It adds the validated, explicit initial
event-retry acknowledgement and generated Crashlytics-cache ignore. Comparison
of its clean LF checkout against `f44ab755` passed all 32 checks: ten validation
components, Android build inputs and seven runtime/environment groups for each
project. Its staging/prod bundles completed, but the October 28 CLI drill found
the projection blocker above; its artifacts retain their original commit identity.
Production's first scheduled Firestore
backup is now verified READY, snapshot October 27 at 21:33:42 UTC, expiring
November 3 at the same time. Chrome's native pipe and browser inventory remain
unavailable after the latest owner-reported reconnect.

Previous frozen candidate: `f44ab755bd173b352be5f5d9c63c293b911def64`, including completed
board retention/account erasure, Unicode release fingerprints, production Play
identities/App Check, current-board readiness, cold Android asset preparation and
verified cross-environment worker-image reuse. Its isolated LF checkout is
`.tmp/release-checkouts/f44ab755bd173b352be5f5d9c63c293b911def64`, with all three
environment files copied by Checkout. The continuation branch is pushed.
All ten application-validation component fingerprints and the worker image
fingerprint match preceding candidate `d83a690c`; only operational tooling and
documentation changed. The reuse tooling has its own passing focused/matrix
checks. Fresh Prepare passed for all three environments, reusing verified
component evidence and passing current dependency advisory checks. Dev/staging/
prod source digests are recorded in the verification evidence.
The preceding candidate `ad759adb`'s
[CI preparation](https://github.com/To0nsa/rpg-runner/actions/runs/40550912893)
completed with 14 passing jobs and a Chrome-startup failure in the compiled-web
smoke. A fresh-checkout Android packaging gap was subsequently found: cached
Prepare restores web output but not ignored navigation graphs. BuildAndroid now
prepares those required assets explicitly; its 15 artifact/regression checks pass
on both PowerShell versions. Corrected-candidate
[CI 40553794370](https://github.com/To0nsa/rpg-runner/actions/runs/40553794370)
passes the compiled-web smoke on retry but fails the mandatory Functions audit
on the newly updated qs advisory. The existing local/deployed qs pin is now
6.16.1, with zero findings in both production dependency audits, 266 Functions
tests and four inventory regressions passing. The patched candidate's
[CI 40555415832 passed all 16 jobs](https://github.com/To0nsa/rpg-runner/actions/runs/40555415832),
including Android packaging/inspection, all client shards and the final evidence
bundle. Exact-source ImportCI and Prepare for all three environments passed.
Dev validator Cloud Build `9a8b0932-3a0a-48b6-a275-f3256c232c2f` completed SUCCESS
at 19:47:52 UTC, including the strict 1-CPU/512-MB/36,000-tick benchmark. Image
digest: `sha256:fb6a16cbee611183462938e19deb9aeaf79c283eadff475e4ab029a4e2a3c331`.
The frozen candidate adopted this matching image through verified cache evidence.
Staging copy build `fe7f9df1-ab0f-43e7-aa24-02f1c7b13880` completed SUCCESS
at 19:57:05 UTC. Canonical ImageStatus verified its strict benchmark and exact
digest equality; no graphs were regenerated. Production copy
`84a144e6-3867-4a34-be88-5ba8282f8f75` also passed at 20:13:40 UTC; canonical
ImageStatus verified the same digest and strict benchmark in all three projects.
The advisory and benchmark gates remain strict.
At the owner's request to avoid duplicate navigation generation, staging build
`d3015999-a988-4416-8144-0a0a05af5021` and production build
`dbc42520-375f-483e-a547-bba48b4d0218` were cancelled around 19:00 UTC.
A narrow release-tooling change now copies a verified
environment-neutral image into each destination registry, with matching worker
inputs, live source evidence, exact destination digest and a strict benchmark.
Its mocked checks pass on both PowerShell versions and both live image copies
pass. Dev runtime cutover is complete; staging/prod runtime deployment is pending.
The validated tooling milestone is frozen in the candidate above.
The preceding LF checkout `.tmp/release-checkouts/d83a690cd4ad82a5427a522a0646027e75d0ad19`
retains its build evidence. Draft PR #2's head has not been advanced. Earlier
component evidence is reused only after exact fingerprint/toolchain/artifact
verification; no full CI run is claimed for the new tooling-only commit.
No Play bundle is uploaded. Public privacy/deletion pages are live and match the
prepared bytes. Dev is deployed with healthy worker `replay-validator-00059-ssr`
and issuer `runsessioncreate-00074-9w8`, both serving all traffic. Both queues are
RUNNING, the board scheduler is ENABLED, and canonical ResumeIssuance completed
at 20:47:37 UTC. Anonymous worker access returns 403; authorized readiness is 200.
The installed dev APK completed a short physical-device run on the new stack:
accepted/settled counts increased from four to five with zero rejection or
quarantine. Fresh-account sign-in, Play Integrity and the full acceptance matrix
remain open. The owner confirmed Nicolas Louis, based in
Finland, with resolved support correspondence retained for 90 days. Those details
are incorporated in the prepared policy. Chrome's native control pipe is now
unavailable after a reconnect/reset attempt; browser inventory is empty. CLI
work continues, but Console uploads need the connection restored. The owner's
CPH2465 Android phone is connected and trusted, but installed-app acceptance has
not run. The owner reconfirmed all three environments and chose to keep both new
Play Games configurations tester-only. A dedicated review account is still to be
created by the owner; never submit owner credentials for reviewer access.

Preceding-candidate dev BuildAndroid version 1 passed at 19:17 UTC. Its initial missing
ignored Gradle wrapper was resolved with the pinned SDK's configuration-only
build, leaving the frozen tracked tree clean. The next attempt generated all
3,750 client navigation graphs, then failed AOT compilation for android-arm64
with an out-of-memory error (exit -1073740791). ARM32/x64 outputs and symbols
existed after that failed attempt; the project mutation lock was released.
The owner needs the other apps open. A sequential Flutter assemble
retry (`--resource-pool-size=1`) succeeded with all three architectures/symbols;
canonical packaging/inspection then succeeded. Its navigation preparation
validated and reused all 3,750 graphs, building zero. Details are in the linked
evidence. The new frozen candidate's dev APK completed canonical verification at
20:09:10 UTC, version 1 / 1.0.0-dev, SHA-256
`428b02e8b713741f4625022e7d11d5e34635fe3bcc8847cd1528c1ce11300ea3`.
Staging's signed AAB also passed at 21:01:26 UTC, version 1 / 1.0.0-staging,
SHA-256 `156dbcb2157681b5464c42424f167dcf461f3bc8882c12e4a45fbf610cdf655a`,
with project-specific resources, 3750 reused graphs, three ABIs, 16 KB checks and
successful staging symbol upload. Staging's paused issuer is now healthy, but the
first full deployment stopped at Firebase's acknowledgement for new retry-enabled
event handlers. A focused release-tool fix is validated and must be frozen before
retrying; production's AAB remains to be packaged. No earlier APK is relabeled as
a new-commit build.
The new candidate's sequential AOT step also passed all three architectures.
Its first packaging attempt failed on disk space after reusing all 3750 graphs.
Redundant generated Android caches were cleared, preserving source and recorded
artifacts; 6.3 GB was available before the successful canonical dev retry.
The dev APK is installed on the connected phone with its expected version.
Staging and production sequential AOT preparation passed; production's signed
packaging and inspection remain pending. Dev PauseIssuance recovered its removed old issuer
image by deploying only the explicitly paused issuer. Its first attempt hit
Firebase's 10-second local discovery timeout before changing the serving service;
the retry passed using the documented 60-second discovery allowance. Its
source-bound cutover record was retained through recovery and cleared only after
verified ResumeIssuance. The deliberately paused legacy board scheduler also
needed an explicit resume after verifying the new worker, before RunJob could
succeed. The workflow now documents that recovery ordering.
Failure details and retained logs are in the verification evidence.

The owner explicitly requested inclusion of the completed board lifecycle/account-
deletion work tracked in `docs/building/board_lifecycle_cleanup.md`. Runtime work
is now committed as `5b1f9092`, with 266 Functions and 298 worker tests passing,
worker analysis and executable compilation. Include it in the frozen candidate;
the older passing CI does not cover it. Its dev cleanup restored the projection
queue and left the legacy board-maintenance scheduler PAUSED. The October 27
cutover preserved that pause through Functions rollout and resumed it only after
verifying the matching worker; the scheduler is now ENABLED.

- Starting source: `f0aa66d8`; the only initial worktree edits are this plan and
  its links in `docs/README.md` and `docs/building/README.md`. Preserve them as
  part of this workstream. No staged or unrelated source changes were present.
- CLI access verified for the existing Lothringen operator and GitHub account.
  Windows Computer Use reached the signed-in Chrome window and Play Console.
  It subsequently stopped because the OAuth tab URL could not be verified;
  browser resumption is pending. Play Console inventory is recorded below.
- Live inventory corrects the planning baseline: the existing project's worker
  is `replay-validator-00058-94k`, with both replay queues RUNNING. The latest
  documented deployment is gameplay `2026.10.21` on October 25. Historical
  records remain attached to `rpg-runner-d7add`.
- User explicitly waives level pathfinding, enemy traversal, navigation quality
  and related content-test failures for this release only. Record exact failures;
  keep build/assets/auth/isolation/replay-integrity/deployment gates strict.
  No failure has yet been waived or relabeled as passing.
- Environment registry, explicit mutation selection, project resource checks,
  project-derived Functions identities and dev-only Hosting are implemented.
  The Functions build and all 257 emulator tests pass. Isolation helper tests
  pass on PowerShell 5.1/7; the six-case mocked routing matrix also passes
  (87 dev checks, 82 staging and 82 prod on each PowerShell version).
- Fresh inventory at `2026-10-26T20:36:13.893Z` found one player, 469 accepted
  validations and 469 settled grants, zero pending/quarantined settlement.
  Preserve the recorded historical orphan/ghost findings; they are not new
  environment state or permission for an unrelated cleanup.
- Routing milestone committed as `c1d11dbd07803e2545683221fac15f76a917b69a`.
  Empty-target bootstrap is implemented and validated on PowerShell 5.1 and 7.
- Created `lothringen-long-run-staging` (943085064373) and
  `lothringen-long-run-prod` (696550437718), linked both to the existing Firebase
  Payment billing account, and renamed the existing project's display name to
  `Lothringen Long Run - Dev`. Firebase and Auth are initialized on both new
  projects, with isolated Firestore, replay/build buckets, registry, service
  accounts and paused task queues. Monthly alert budgets are EUR25 staging and
  EUR50 prod; these are notifications, not spending caps. No new game backend
  or Android artifact is deployed.
- Play account is Personal. Existing Long Run app ID 4975420968170292531 has an
  inactive internal track, empty draft and no bundles in its library. Internal
  testing is available. Public access requires 12 testers for 14 continuous days;
  Console currently reports zero opted-in testers. Closed-track setup is pending.
- Owner reconsidered the overhead and explicitly reconfirmed all three
  environments for independent candidate testing during execution.
- Store audience confirmed by owner: Finland, ages 16+, public support and
  account-deletion contact `lothringen.rpg@gmail.com`; initial internal tester is
  the existing owner account. This audience choice does not replace IARC ratings.
- Provisioning is repeatable through `release.ps1 -Action Provision`; 30 mocked
  checks pass on PowerShell 5.1 and 7. Live existence-only Auth/Firestore checks
  confirm both new environments are empty. Worker URLs use the documented
  project-number format; actual service readback awaits deployment.
- Android flavor/resource generation passes for dev debug/release and staging/
  prod release. Nineteen focused environment/startup tests and targeted analysis
  pass. Signing, Play Games linkage and device acceptance remain pending.
- Play rejects `com.example.rpg_runner.staging` as already in use. It confirms
  `com.lothringen.longrun.staging` is available; created its separate Long Run
  Staging listing, app ID `4975698862921375548`. Update the new Firebase/native
  registration before uploading. Preserve the existing working dev identity.
- The previously staged auth/account-deletion work is now commit `f5075eed`.
  Preserve it as intended source and revalidate integration before freezing.
- Foundation milestone committed as `2e272c40`. Staging now uses the genuine
  Firebase registration for `com.lothringen.longrun.staging`; its separate Play
  Games project is linked to `lothringen-long-run-staging`. OAuth consent and
  credentials remain pending after browser control lost URL verification.
- Separate staging/prod upload keys are backed up in each project's Secret
  Manager. Readback and repeated setup preserve the same certificates. Google
  Play distribution signing remains pending; upload keys are not that identity.
- Signing milestone committed as `f3d1c471`. Android artifact inspection is
  implemented and passes on a real dev APK (API 36, all 3,750 navigation graphs,
  expected Firebase/Play IDs, three ABIs and 16 KB alignment). This is an
  uncommitted-source probe, not the frozen release candidate. The initial native
  build failed because `--no-pub` retained a test-only plugin registrant;
  enabling Flutter's normal release regeneration resolved it.
- Managed PITR and daily seven-day backup schedules are configured/read back in
  staging/prod. First scheduled backup completion is not yet verified. An isolated
  synthetic dev database restore completed in 11m09s and passed duplicate-reward
  and deletion-barrier checks. Both rehearsal databases were cleaned up and live
  inventory shows only the untouched default dev database. Full-service recovery
  and the first scheduled backup remain separate, unverified checks.
- Crashlytics dependency/handlers pass 21 focused startup/diagnostic tests and
  targeted analysis. Native AAB integration hit Gradle native-memory exhaustion;
  retry with bounded memory/workers passed, as did full AAB inspection. No live diagnostic event or
  readable release report is verified yet.
- Structured maintenance/update responses and the client release gate pass 25
  focused tests, 35 startup/recovery tests and all 259 Functions emulator tests.
  These are local checks, not Play/device acceptance or a deployed change.
- Operation locks and source-bound maintenance ownership pass 13 focused checks
  and 97/92/92 dev/staging/prod entry-point checks on PowerShell 5.1/7. Monitoring
  setup completed with 31 enabled policies in each new project, read back at
  23:43:42Z staging and 23:51:56Z prod on October 26. Incident delivery remains
  unverified. The new channels omit
  verification status, which the documented API treats as usable; an unnecessary
  verification request was withdrawn. Approval review
  rejected cross-project verification copying; it was not executed. The owner
  was also asked for the legal operator name/country needed for public privacy
  information. OAuth/Chrome resumption remains pending.
- Android/runtime milestone committed as `aac4d7f6`. Required final tooling
  matrix passes (50 syntax, 50 cache, 29 isolation, 11 artifact, nine recovery,
  13 lock checks on both shells); eight focused monitoring checks also pass.
- Artifact/operations milestone committed as `d9909a3e`. Updated the moved
  repository remote to `To0nsa/rpg-runner`, published the current intended source
  on `release/android-beta-environments`, and opened
  [draft PR #2](https://github.com/To0nsa/rpg-runner/pull/2). Automatic approval
  review rejected publishing the 42-commit history directly to default `master`;
  no default-branch push or merge occurred. The separate review branch succeeded.
- The first hosted release-preparation run passes all component checks, including
  all four client shards and the built web smoke test. Guidance and release-tooling
  workflows pass. The final validator-image job is still running. Android failed
  because plugin sources in the default C: Pub cache could not be made relative
  to the D: checkout by Kotlin's incremental compiler. CI now places the Pub
  cache on the checkout drive; hosted verification is pending.
  The browser widget job failed its local-run startup case; its recipe omitted
  required generated navigation assets. The recipe now prepares those assets
  and prints expanded diagnostics; hosted verification is pending. Cache input
  coverage includes these generators, with 53 mocked checks passing on both
  PowerShell versions. No traversal failure or other check is waived.
- CI recipe correction committed as `a492f1ef`. The browser retry still fails
  its startup case after asset preparation; expanded output alone still omits
  the framework exception. Adding test-attached exception/loading diagnostics
  before another retry. The built-web runtime smoke already passes.
- Native Android CI now passes on `a492f1ef`, including the actual APK inspection.
  The first validator-image job exhausted its 30-minute CI limit while offline
  graph generation was still progressing (76,790 graphs at 1,757 seconds).
  Aligning its allowance with Cloud Build's existing two-hour limit and limiting
  overlapping runs per ref; compilation, smoke, strict benchmark and image
  vulnerability checks remain mandatory.
- Browser diagnostics identify a readiness failure at `parallaxMounted` with no
  reported asset error. Moving route startup into real asynchronous execution
  did not resolve it: run `40426008765` still fails that case. All component jobs
  pass, including built-web smoke. Asset/task diagnostics are being added to
  identify the actual pending work; the simulated-clock cause remains unproven.
  This remains a blocking check, with no gameplay waiver.
- External deletion-page source is prepared at `web/account-deletion.html` with
  the confirmed support email, environment-specific request scope, in-app steps
  and actual retention limits. It is not yet published. Live log-bucket readback
  confirms 30-day operational and 400-day required audit retention in both new
  projects. Public privacy identity and support-correspondence policy remain
  dependent on operator input; no placeholder privacy policy is published.
- Replaced the Flutter launcher placeholder with the game icon in all five
  Android densities and prepared its 512 px Play export. The editable SVG and
  generation details are in [release assets](../release-assets/android/README.md).
  Dimensions, opacity and small-size rendering pass inspection; no store asset
  has been uploaded. `adb devices -l` currently lists no attached device.
- Validator image CI `40426008703` completed successfully at 00:51 UTC on
  October 27: full navigation preparation, configured/unconfigured runtime
  smoke, strict 1-CPU/512-MiB benchmark and Critical/High vulnerability scan pass.
  This is CI validation, not a deployed image or a frozen candidate.
- The isolated browser diagnostic (`40428392923`) found 23 requested images
  pending and no completed load task in the widget harness. Readiness, live ticks
  and Practice game-over are now covered by the mandatory compiled-app smoke
  test; browser widgets retain bootstrap, Options and local descriptor checks.
  The expanded smoke passes against the existing local web artifact; fresh-source
  CI verification remains pending. No failing gameplay check was waived.
- Fresh-source run `40429577996` on `f9015c3d` completed with all 16 jobs passing,
  including all five browser cases, the compiled-web start/game-over smoke,
  all component suites, native APK inspection and final evidence-bundle assembly.
  No traversal failures were waived. This is preparation evidence, not final
  Android/Play authentication or deployed acceptance.
- Added Options > Settings privacy/support links and failure fallback. Targeted
  analysis and four focused widget cases pass; one pre-existing launch-flag-only
  case is skipped in the default invocation. These small UI changes postdate the
  full CI run and require final-candidate CI/build validation. The shared policy
  URL is prepared but not published until the legal operator details are supplied.
- Prepared `web/privacy-policy.html` with the confirmed operator name and public
  contact. Both public pages now distinguish Firebase Authentication's provider
  deletion window (up to 180 days) from game recovery copies (up to seven days).
  Balanced HTML, local cross-links and 390-pixel layout checks pass; desktop and
  phone renders were inspected. Country/support-mail retention and publication
  remain pending. No public placeholder or policy has been deployed.
- October 27 resumption: Chrome is reachable but reports Gmail as its selected
  tab. Automatic approval review rejected reading that page because unrelated
  email is outside this release task. No email content was read; the owner has
  been asked to select the already-loaded staging OAuth tab. The old monitoring
  verification-email request is withdrawn: channel usability was established
  from API readback; actual alert delivery remains untested. At 05:45 UTC,
  staging/prod scheduled-backup inventories were still empty.
- Owner subsequently confirmed Finland and 90 days after resolution for support
  correspondence. Policy text is updated; the mailbox policy is an operator
  responsibility, not an automated app feature. Native Chrome inspection now
  reaches the selected staging OAuth page and configuration is in progress.
- Next: complete OAuth/Play and publish the prepared privacy information, then finalize
  source, run canonical Prepare/BuildAndroid, deploy dev/staging and complete
  acceptance before the already-authorized production cutover. Reuse completed
  foundations, signing, monitoring, recovery setup and unchanged check evidence.
- October 27 resumed after the owner's temporary handoff. Local signing backups,
  certificates and the staging OAuth backup now live in the operator/SYSTEM-only
  `C:\dev\lothringen-secrets` sibling directory, following Pikkuretki's layout.
  DPAPI readback and unchanged signing-file hashes were verified; the plaintext
  OAuth download was removed. Temporary build keys also stay outside checkouts.
  Both PowerShell versions pass 12 signing, 50 release, 97 integration and 53
  cache checks. No secrets were committed or keys rotated.
- Staging OAuth identity is configured as External/Testing with the owner as its
  sole test user. Web client
  `943085064373-cgchd3tftpkgv4f30q01k3aqblqa5vls.apps.googleusercontent.com`
  is backed up in that project's `play-games-oauth-client` Secret Manager secret.
  Firebase's Play Games provider was enabled and read back with that exact client
  at 15:30 UTC. The initial REST call failed for missing quota-project attribution;
  adding the documented project header resolved it. This is configuration evidence,
  not device sign-in acceptance. The owner explicitly approved `games`, `games_lite`
  and `drive.appdata` for staging/prod; all three are saved in staging's
  non-sensitive scope list. Production configuration remains pending.
- Chrome's reload readback then stopped because the helper could not confidently
  determine the current URL. No further browser input was sent in that turn;
  saved scopes still need a fresh-page readback before being treated as verified.
- Subsequent owner-authorized resumption verified the saved staging scopes on a
  fresh page. The matching web client is now saved as staging's draft Play Games
  server credential (`CgkItaGAorkbEAIQAA`). Refreshed the genuine Firebase Android
  config and explicit native server-client resource; all four environment tests
  pass. Android/distribution credentials and Play publication remain pending.
- Staging Play Integrity is now linked to its own Firebase project only
  (`943085064373`), read back in Console with the default 10,000/day API limit.
  This setup is not an attestation-verdict acceptance result. Native OAuth wiring
  is committed as `65ee1d27` and backed up on the continuation branch.
- First scheduled staging Firestore backup is now READY:
  `1ec4a342-a204-4237-8c45-c52e9fed4f25`, snapshot October 27 at 09:33:55 UTC,
  expiry November 3 at the same time. Production's inventory is still empty at
  this readback; its first completed backup is not claimed.
- Staging Play App Signing is enrolled with Google's three-certificate signing
  set (classic, hybrid classical and hybrid PQC). The downloaded public archive
  and extracted certificates are retained outside the repo under
  `C:\dev\lothringen-secrets\staging`. All six SHA-1/SHA-256 fingerprints were
  registered and read back in the correct Firebase Android app at 15:57 UTC.
  Three matching Android OAuth clients are created and verified. Their Play Games
  links are saved as drafts: classic `CgkItaGAorkbEAIQAQ`, hybrid
  `CgkItaGAorkbEAIQAg`, PQC `CgkItaGAorkbEAIQAw`. The classic credential remains
  the default for new installs. Refreshed genuine native configuration includes
  all three Android clients plus the existing server client; all four focused
  environment tests pass. Saved Play Games description, Action category, icon
  and feature graphic; Console reports ready to publish. Automatic approval
  review blocked the final Play Games service publication because it extends
  beyond the tester list and locks some settings. Specific owner approval is
  pending; nothing was published. Play-delivered sign-in and attestation remain
  unverified. Production configuration can proceed independently.
- Durable evidence: [Android beta execution](../verification/android-beta-2026-10-26.md).
- Production's old listing is still an empty March draft without a package or
  uploaded bundle. The current creation flow confirmed `com.lothringen.longrun`
  available and reserved it in new Long Run listing `4975092661531994619`
  (English UK, Game, Free). The old draft remains intact. New production Firebase
  app `1:696550437718:android:c27d2030dcee3fd2d9dcf7` matches that package; its
  genuine configuration and explicit flavor/registry/client identity are updated.
  Production Play Games is linked only to project `696550437718`. OAuth is now
  External/Testing with only the owner and the three approved game scopes.
  Production web client `696550437718-6n2bu175hk96rn77o8cob7ht6pcr2h4s.apps.googleusercontent.com`
  is backed up in external DPAPI and project-local Secret Manager. Firebase's
  enabled provider was verified at 16:56 UTC; the same client is saved as draft
  Play Games server credential `CgkI1uaQ7aIUEAIQAA`. Genuine Firebase configuration
  and native resources agree. Four environment tests, 29 isolation checks on
  each PowerShell version and Gradle's production Google Services task pass.
  Play Integrity is linked only to the production project (10,000/day quota).
  Distribution certificate/OAuth setup continues; no production artifact,
  deployment or installed-app acceptance is claimed.
- Production distribution setup is now configured for all three Google Play
  certificates. Matching Android OAuth clients and draft Play Games credentials
  are verified; classic `CgkI1uaQ7aIUEAIQAQ` remains the new-install default,
  alongside hybrid `CgkI1uaQ7aIUEAIQAg` and PQC `CgkI1uaQ7aIUEAIQAw`.
  The refreshed genuine Firebase config passes all four environment tests.
  Explicit App Check registration/readback completed at 17:10 UTC for both
  environments; Firebase Console independently shows the intended packages as
  Registered with Play Integrity. Production Play Games metadata/tester setup
  and publication remain open. No phone is attached; device acceptance was
  requested while independent work continues.
- Integration found the release inventory still required future board windows
  after `5b1f9092` changed provisioning to current windows only. The inventory
  and resume gate now use the provisioner's configured levels and current
  windows. Four inventory regressions pass; release helpers (51), integration
  (102 dev / 97 staging / 97 prod) and cache checks (56) pass on both PowerShell
  versions. Missing current boards still block without resuming queues. These
  are local/mocked checks; final-candidate CI and live cutover remain required.

## Outcome and environment decisions

The owner confirmed on October 25 that they are the game's only current user.
Their existing account and gameplay data may be reused for development or
discarded as needed for this setup. Preserving or migrating that data is not a
requirement. Reusing it in place avoids unnecessary work; no reset is required
just to change the project's role. This exception does not extend to future
beta-player data or authorize unrelated credential/resource deletion.

Use three complete environments from one codebase and deployment workflow:

| Environment | Firebase / Google Cloud project ID | Display name | Initial data |
| --- | --- | --- | --- |
| Development | Existing `rpg-runner-d7add` | `Lothringen Long Run - Dev` | Reuse the owner's existing account; add synthetic fixtures as needed |
| Staging | `lothringen-long-run-staging` | `Lothringen Long Run - Staging` | Synthetic fixtures and internal tester accounts |
| Production | `lothringen-long-run-prod` | `Lothringen Long Run - Prod` | Start fresh; no account, progression or replay import |

Both staging/production project IDs were created unchanged on October 26.
Their backend services and application configuration are still being provisioned.
Project display names can change; project IDs are permanent. Keep the existing
development ID to avoid resource recreation. These infrastructure labels use
the game's Lothringen identity; they do not rename the public game title.
Development changes frequently. Staging holds a selected, frozen candidate for
internal acceptance while development continues. Production serves external
closed-beta players and the eventual public release; beta is a distribution
stage, not another backend environment.

| Build / distribution | Android package | Backend | Purpose |
| --- | --- | --- | --- |
| Development debug | `com.example.rpg_runner.dev` | Existing project, now development | Everyday work and device debugging |
| Development release/profile | Same development package | Development project | Local release-mode debugging; a dev Play listing is optional |
| Staging release, separate app's Play internal track | `com.lothringen.longrun.staging` | New staging project | Team acceptance, real Play authentication/attestation and release rehearsals |
| Production release, Play internal track | `com.lothringen.longrun` | New production project | Final production-artifact smoke checks before promotion |
| Production release, closed beta and later public release | Same production package | Production project | Player testing and eventual public release |

These package names are the current baseline, pending the explicit identity
decision in Phase 1. Play tracks distribute versions of a package; they do not
select or isolate Firebase environments. Staging needs a separate Android package
and Play app listing. The production app's internal track still uses production
services and does not replace staging. Reuse an existing dev listing if useful;
creating a third Play listing is not required for normal development.

Use explicit Android `dev`, `staging` and `prod` product flavors, independently of
debug, profile and release build modes. Give dev/staging clear launcher labels
and separate package storage. This replaces the current debug-only package
suffix arrangement. Development release/profile must remain in development;
production debug must not become an accidental route to live data. Existing
web/Apple/Windows configuration targets the old project and therefore remains
development configuration until explicitly configured for production. Keep local
development on dev; account for this boundary without expanding Android delivery
into an Apple/Windows release or automatically publishing a production website.

Each backend owns its Auth users, Firestore, Functions, Storage, Cloud Run worker,
queues, scheduler jobs, boards, service accounts, IAM and operational evidence.
The owner's existing data stays in the existing project unless cleanup is needed;
future production-player data must not be copied into dev or staging. Signing in
with the same Google account in another environment creates independent state.
There is no account or progression migration workstream.

Alternatives considered: keeping one project leaves data and deployments shared;
keeping the old project as production would require more development-identity
relocation and retain its prototype project ID. Reusing it for dev and creating
staging/production fresh fits the owner's preference. Two environments were
initially considered; the owner's planned team expansion and independent
internal acceptance now justify staging. Local emulators complement the shared
dev project for isolated developer work; per-developer cloud projects are not
required by this plan.

## Scope and release policy

- Support one active gameplay compatibility version per environment. Staging
  can run the next version while production remains on its accepted version.
  Require an app update for incompatible releases and accept planned maintenance
  during cutover. Compatible
  UI fixes do not automatically require retiring older clients.
- Implement an update-required screen with a Google Play link before beta.
  Reuse server compatibility enforcement. Play's immediate in-app update flow is
  optional polish; it still requires user acceptance. Do not add multi-version
  validators or a custom update service for this beta.
- Stop new issuance and finish outstanding work before incompatible backend
  cutover. Do not interrupt a run to update. Current tickets last 24 hours, so
  maintenance duration depends on real drain/expiry evidence. Do not require a
  replacement build until it is available to the affected Play cohort. New
  clients arriving before cutover need a maintenance response too.
- Bootstrap staging/production without importing old sessions or requiring a
  drain of another project. Once production players exist, preserve their
  tickets, rewards and progression through the normal release workflow.
- Extend existing deployment scripts and CI, reuse backend alerts, use managed
  backups and standard client crash reporting. Keep one bounded beta-capacity
  check; defer a general load-testing platform and infrastructure rewrite.
- Prefer additive stored-data changes with defaults and stable identifiers.
  Mandatory app updates do not migrate saved player data. Add a focused data
  migration only when an actual schema change needs one.
- Promote a frozen commit through dev -> staging acceptance -> production.
  Hold staging stable during acceptance; fixes create a new candidate with
  affected checks repeated. Use the same application code, dependency locks,
  gameplay/content and build recipe without long-lived environment code forks.
- Match staging's auth, App Check, rules, indexes, queues and service topology to
  production. Document environment-specific identity, secret and scaling values.
  Smaller staging capacity can control cost, but record that limit when using
  its results as production load evidence. Separate telemetry and budgets.
- Staging and production AABs differ in package/configuration/signing identity.
  Build prod from the exact accepted source; verify its packaged configuration
  and run production smoke checks. Reuse backend artifact bytes only when inputs
  are genuinely environment-independent. Promote the same prod AAB across its
  own Play tracks, not a staging AAB into the production listing.

## Verified repository baseline and open facts

Read-only repository inspection on October 25 established:

- `.firebaserc` and `firebase.json` target `rpg-runner-d7add`.
- Both Android JSON configurations use that project. Debug selects the `.dev`
  registration; profile/release select the release registration.
- `android/app/build.gradle.kts` signs release with the workstation debug key.
  `pubspec.yaml` currently declares `1.0.0+1`; actual uploaded version codes are
  unknown until Play Console is inspected.
- `tools/release/release.ps1` rejects a project different from the configured
  default/Hosting site. Passing another `ProjectId` is not supported isolation.
- `functions/src/index.ts` hard-codes existing-project run-control and validator
  service-account addresses. Worker configuration already accepts project parameters,
  but the whole deployment chain still needs inspection.
- The latest documented deployment to the existing project is October 18,
  gameplay `2026.10.17`. Source/configuration includes later work. Neither HEAD
  nor local configuration proves what is serving. Preserve historical release
  records under their original project identity; they are not evidence for the
  new production project. Earlier documents call the existing project live/prod.
- [Android build identities](../tdd/android_build_variants.md) records successful
  dev authentication against the shared backend, but also an existing release
  Play Integrity rejection. Opening the hub is not proof of valid attestation.
- The initial planning pass recorded no connected browsers or tabs. Firebase,
  Cloud and Play Console state has not been verified during this plan revision.

Account type, verification status, existing Play listings/uploads, app-signing
enrollment, active credentials, project permissions, billing and existing service
health must be discovered rather than assumed.

## Execution and evidence rules

Prefer supported CLI/API operations for repeatability. Use the user's Chrome
session for Firebase/Google Cloud/Play Console tasks missing suitable CLI support.
Record the selected project/package before each mutation and verify the resulting
state afterward. Do not rely on the browser's previously selected project.

The agent owns implementation, tests, builds, resource configuration, draft store
materials and status tracking. The user supplies business decisions, authentic
policy facts, tester identities and access where missing, and performs required
credential, payment or identity-verification handoffs. Browser confirmation rules
apply at the actual consequential action; ordinary inspections and authorized
reversible preparation do not need repeated permission requests.

Before spending on cloud builds/provisioning, linking billing, changing sensitive
access, modifying live services or submitting/publishing a release, establish
the specific authorization required by the repository and browser policies.
Accepting binding terms or deleting unrecoverable data has its own action-time
requirements. The owner's sole-account data exception above permits necessary
dev cleanup; do not turn it into a blanket reset or carry it over to future
production users. Preserve auth and settlement invariants. Do not send tester
invitations/messages without explicit authorization.

Keep keys, keystore passwords, tokens, OAuth secrets and login exports out of Git,
logs and screenshots shared as evidence. Store only resource identifiers, public
certificate fingerprints, redacted configuration summaries and artifact hashes.
Use existing credential stores and protected secret storage; avoid downloaded
service-account keys when existing user/workload credentials suffice.

Maintain this checklist as the single progress record. For each phase, record
commit, environment, checks, evidence location and remaining limits. Save durable
redacted verification under `docs/verification/`; local operational output belongs
under `.tmp/`. Distinguish repository inspection, mocked checks and live results.

## Phase 1 - inventory and decisions

Execution: agent via read-only CLI and connected Chrome; user for missing decisions.

- [x] Restore/verify Chrome browser-control access to the intended signed-in
  profile, then inspect Firebase, Google Cloud and Play Console without changes.
- [x] Inventory existing resources, serving versions, active sessions, pending rewards,
  boards, buckets, queues, scheduler, IAM, billing, alerts and retention policies.
  Record what can be reused as dev and a redacted configuration baseline; do not
  build an account-data migration or duplicate the existing dev infrastructure.
- [ ] Inspect developer account type/date, verification and distribution access;
  existing app listings, package names, version codes and signing state;
  Play Games configuration, testers and linked Cloud/OAuth projects.
- [x] Decide the permanent production Android package/listing before upload.
  The new Cloud project name does not choose the Android package. Inspect Play
  constraints and prefer the simplest supported identity setup. Existing owner
  installations may be replaced without preserving gameplay data; update native,
  Firebase and Play Games configuration consistently if the package changes.
  Reserve a distinct staging package derived from that decision and identify the
  separate staging Play listing/internal tester access.
- [x] Verify availability of `lothringen-long-run-staging` and
  `lothringen-long-run-prod`; select database/bucket locations, billing account,
  operational contact, internal team and beta audience/countries, and test-data
  and production retention policies. Record all three environment identities.
  Consult brand references before changing public names or authoring store copy.
- [x] Inventory existing Play Games and OAuth credentials. Prefer leaving the
  working dev identity in the old project and configuring staging/prod separately.
  Package/certificate pairs can conflict across projects; resolve listing and
  credential constraints before creating duplicates or relinking a game. No
  custom cross-project authentication bridge is in scope.
- [x] Record team access: developers can work in dev; designated maintainers
  deploy candidates to staging; production deployment/signing stays restricted.
  Document how candidates are selected and accepted without requiring another
  deployment system or giving internal testers production cloud permissions.

Current team: the existing owner/operator `lothringen.rpg@gmail.com` is the sole
release maintainer and acceptance owner. No additional human deployment or
signing access has been granted. Runtime service accounts are project-local;
internal Play testers receive no Cloud IAM access. Add future developers to dev
only, designated release maintainers to staging, and production/signing access
separately after an explicit owner decision. Candidate acceptance records belong
in this checklist/evidence and precede the authorized production cutover.

Exit: environment/resource matrix and identity decisions recorded; existing state
known; outstanding user inputs named. Do not block independent local work on
optional store-copy choices.

## Phase 2 - make deployments environment-aware

Execution: agent, repository and CLI. Prepare locally before cloud changes.

- [x] Read the closest AGENTS files, then add one explicit validated environment
  definition for project, region, Firebase configuration/Hosting target, bucket,
  worker, queues, identities and required secrets. Map dev to the existing project
  and staging/prod to their new projects. Keep one deployment workflow and shared
  provisioning recipe; environment definitions supply resource differences.
- [x] Extend the existing release entry point and provisioning helpers to select
  an environment. Preserve offline default `Plan`; require explicit environment
  selection for mutations and reject contradictory project/resource identities.
- [x] Remove hard-coded project service-account addresses from Functions source.
  Derive/validate identity against the selected deployment project. Audit task
  dispatch, settlement URLs, token audiences, scheduled work and monitoring for
  cross-project defaults; make missing environment values fail clearly.
- [x] Separate manifests, baselines, checkpoints, config files and cache keys by
  environment/project. Share source-only evidence/artifacts only when inputs
  genuinely match. Historical old-project production evidence belongs to that
  project; it cannot establish a baseline for the new production project.
- [x] Add a first-deployment bootstrap path for empty staging/production, without
  requiring resources or paused/drained sessions in another project. Retain
  readiness checks and coordinated cutover rules for established environments.
  Bootstrap must verify the target is empty rather than trust an environment name.
- [x] Reuse provisioning helpers with safe retries and configuration readback;
  document console-only steps. Keep dev/staging runtime and deployment automation
  unable to mutate other environments, with separate production deployment access.
  The owner's existing operator identity can administer all projects. Serialize
  mutations per environment so two teammates cannot cut over it concurrently.
  Do not replace the existing tooling with a new infrastructure framework.
- [x] Add meaningful mocked tests for all three environments: an operation must
  not target another project's buckets, service accounts, queues, Hosting or
  release checkpoints. Mismatched configuration blocks before mutation; preserve
  scoped-release protections and environment-specific cache/evidence validation.
- [x] Update deployment TDD/workflow/AGENTS documentation alongside delivered
  changes. Validate release helpers under PowerShell 5.1 and 7 and run focused
  Functions checks for affected configuration behavior.

Exit: plans for all three environments resolve correctly; isolation and existing
cutover tests pass. No direct package-deploy workaround becomes a parallel path.

## Phase 3 - reuse development and provision staging/production

Execution: agent via CLI; Chrome for billing/console-only setup; user where required.

- [x] Label the existing project as development and reuse its account, data and
  services. Keep credentials needed for dev sign-in. Only clean up obsolete
  owner fixtures when necessary; no data preservation or import task is required.
- [x] Create the new staging and production Firebase/Cloud projects with their
  chosen IDs/display names, associate approved billing and enable required APIs.
  Configure separate budgets/alerts and conservative scaling; budget alerts are
  notifications, not a guaranteed spending cap.
- [ ] Apply the same provisioning recipe for Firestore/Storage, Auth configuration,
  indexes/rules, Artifact Registry/build resources, least-privilege service
  accounts, both task queues and scheduler jobs. Image-dependent worker deployment
  goes through canonical bootstrap: staging first, production after acceptance.
- [x] Create separate environment configuration/secrets. Keep worker invocation,
  bucket access, token audiences and settlement dispatch inside each project;
  do not grant dev/staging identities access to production resources.
- [ ] Apply existing retention/cleanup and monitoring policies to each selected
  environment. Verify indexes, private invokers and routing; worker health,
  supported compatibility tuple and required boards must pass after bootstrap.
- [ ] Update dev through the environment-aware workflow and bootstrap staging
  from a frozen candidate. Seed representative synthetic fixtures without copying
  the owner's dev account or production data. Record image/deployment identities.
  Prepare production configuration for Phase 8 bootstrap from the accepted
  candidate; production starts fresh, with explicit smoke-test accounts as needed.

Exit: dev/staging backend stacks operate independently and production foundations
are ready for candidate deployment; configuration readback proves isolation.

## Phase 4 - isolate Android configuration and Play Games identity

Execution: agent, repository/CLI plus Firebase and Play Console in Chrome.

- [ ] Implement `dev`/`staging`/`prod` flavors with clear package/label identities
  across build modes. Install all three side by side.
  Download genuine environment-specific Google Services files; select the
  intended Firebase app, Storage bucket, Functions region and native resources
  consistently. The dev installation stays on its current backend. Use a clean
  production installation for the owner when the former release package changes
  backend; do not build local-state migration code just to preserve owner data.
  Verify Auth, outbox, replay spool and ghost cache state cannot cross environments.
- [x] Retain the working dev registration/certificates in the existing Firebase
  project. Register staging/production packages and proper signing certificates
  in their own projects; resolve OAuth conflicts through the Phase 1 identity plan.
- [x] Establish staging/production Play Games and Firebase Auth linkage using the
  supported topology chosen in Phase 1. Prefer retaining the existing dev game
  configuration and configuring each new environment separately where Console
  permits it. Staging must test the real authentication path without a bypass.
  Document each game's linked Cloud project and server OAuth client. Do not
  assume the old server client authenticates against the new Firebase project.
- [ ] Configure flavor-specific game-services ID/server client resources. Verify
  the full chain: package + installed signing certificate -> Play Games -> server
  authorization code -> intended Firebase Auth project -> protected callable.
  The update-required link must open that flavor's Play listing, not switch a
  staging tester into the production app.
- [ ] Configure development debug App Check tokens only in development; require
  real Play Integrity for staging/prod Play-delivered release builds. Match
  production enforcement in staging before acceptance. Confirm diagnostics
  without logging credentials.
- [ ] Verify packaged IDs/resources and targeted startup/auth tests; install dev,
  staging and prod side by side. Prove the same Google account has independent
  state in each and non-production actions cannot change production progression.
- [x] Update Android identities/authentication TDD and build instructions. Mark
  non-Android configurations that still target the old project as development;
  verify local defaults cannot silently reach prod. Generated files stay generated.

Exit: dev retains working sign-in to the existing project; staging and production
builds have distinct registrations and authenticate to their respective projects
with fresh, independent progression.

## Phase 5 - production signing and reproducible Android artifacts

Execution: agent for configuration/builds; user for protected credential handling.

- [ ] Configure protected upload signing and Play App Signing for the live app.
  Remove debug-key fallback from release builds; missing signing inputs must
  fail clearly. Back up the upload key securely with a documented recovery owner.
- [ ] Configure staging release signing and its own Play app/internal track for
  team acceptance. Resolve listing/Play Games eligibility before relying on this
  path. Dev keeps local release-mode testing; its own Play listing is optional
  because required store-delivered integration coverage now belongs to staging.
- [x] Register the appropriate installed-app signing certificates with each
  environment's Firebase, Play Games and App Check setup. Distinguish Google's
  distribution signing certificate from the local upload certificate.
- [ ] Add a repeatable Android preparation/build path tied to frozen source,
  environment, compatibility tuple, toolchain, navigation assets and version
  code. Extend existing CI/release components to include Android sources, native
  configuration and toolchain inputs; current client-build evidence is web-only.
  Keep signing credentials protected and promote the same verified production
  AAB across Play tracks. Staging/prod bundles have different identities; record
  the accepted commit and environment-specific build inputs for both.
- [ ] Check current Play SDK requirements and inspect the actual bundle's target
  API, supported ABIs, native-library/page alignment, manifest, permissions,
  package, signing, size and asset inclusion. Upgrade/fix dependencies as needed.
- [ ] Allocate increasing version codes from actual Play history; generate signed
  AABs plus hashes and symbols needed to diagnose release crashes. No dev flags,
  debug tokens or secret material may enter the live bundle.

Exit: reproducible signed staging/prod AABs and a working dev build, with verified
identities; production no longer depends on the workstation debug signing key.

## Phase 6 - release candidate and pre-beta readiness

Execution: agent via automated checks and staging deployment; internal team via
Play-delivered device QA and candidate acceptance.

- [x] Run relevant client/Core/protocol/Functions/worker checks and generated
  content freshness. Follow the traversal workflow for included level/navigation
  changes; record levels, seeds, enemies, horizons and exclusions.
- [x] Prepare navigation graphs and run the strict benchmark on the final worker
  image. Reuse valid preparation evidence and retain required coverage; do not
  repeat this work for unrelated UI changes.
  Corrected c8b image/benchmark passed; canonical ImageStatus verified digest
  `sha256:9c81113febe223d1e399d12bdaa8253131e71a1df901611852d47b00b42edd80`.
- [x] Freeze the candidate commit and deploy its complete stack to staging.
  Hold it stable for the test session while dev work continues. Record who
  accepts the candidate; a fix selects a new commit and repeats affected checks.
  The prior bcb CLI drill found a projection blocker. Its c8b replacement stack
  passed deployment on October 28 at 21:25 UTC; acceptance is still pending.
- [ ] Install the staging release through its separate Play internal track. Verify
  real Play Integrity and Play Games sign-in, including a fresh tester account.
- [ ] Exercise issuance, replay upload/acceptance, exactly-once rewards, wallet
  catch-up, leaderboard and ghost retrieval, account deletion and pending-run
  recovery after disconnect, app restart and background/foreground transitions.
- [ ] Verify wrong-environment identities/tokens fail, unauthorized access remains
  blocked, and dev/staging tests leave production accounts/resources unchanged.
- [x] Implement and test the single-version release policy before the first beta
  client ships. Distinguish maintenance from an obsolete client; present an
  update-required screen with a Play Store button and reuse backend enforcement.
  Gate incompatible online operations/new runs, preserve outstanding submission
  recovery and keep account-deletion/support access available. A canceled or
  failed update must not bypass compatibility checks. Immediate in-app updating
  is optional, not a release prerequisite.
- [ ] Rehearse one incompatible update in staging: old/new clients, pause/drain,
  delayed store availability, restart and pending rewards. Do not assume a
  staged Play rollout can coexist with a single incompatible backend version.
  Record the maintenance window and the higher-version-code hotfix procedure;
  installed Android apps cannot be rolled back by restoring backend artifacts.
- [ ] Verify standard client error reporting and readable release stack traces,
  plus existing backend alerts for auth, validation and settlement. Record the
  owner, alert destination, actionable thresholds and conditions that stop rollout.
- [x] Configure managed production database recovery with explicit acceptable
  data-loss/recovery-time targets and retention. Run a small synthetic-data
  restore rehearsal in dev and document reward/deletion consistency checks.
  Keep recovery-copy disclosures accurate; no custom backup system is needed.
- [ ] Declare the initial beta audience cap and run a bounded representative
  concurrent replay/settlement check in staging. Observe queue age, completion
  latency, memory and cost against stated limits. The isolated simulation
  benchmark alone is not cloud capacity evidence; record scaling differences
  from production and expand testing with audience.
  Initial distribution cap is one invited owner account per app, matching the
  confirmed current player/tester population. Additional testers require the
  staging capacity result and an explicit tester list; no wider rollout or
  invitations are inferred. This cap does not satisfy any Google-required
  closed-testing qualification period or tester count.
- [ ] Check loading, controls, device performance/memory, crashes and ANRs on
  representative Android devices. Fix beta blockers; prior release waivers are
  historical evidence and do not automatically carry into beta acceptance.
- [ ] Record the accepted candidate and unresolved defects/limits. Commit
  independently validated milestones without including unrelated worktree edits.

Exit: an internally accepted frozen candidate with observed staging Play end-to-end
success, tested update/maintenance and recovery behavior, working diagnostics,
and an explicit disposition for every remaining beta blocker.

## Phase 7 - store listing, privacy and account readiness

Execution: agent prepares/configures; user validates factual business declarations.

- [ ] Inspect all mandatory tasks shown for the actual developer account and
  app. Complete identity/contact/device verification through user handoff where
  needed. Establish closed/open testing eligibility from the account's live state.
- [ ] Prepare truthful listing text, game icon, screenshots and required artwork
  from implemented gameplay. Consult Lothringen naming/brand references before
  creating public materials; do not advertise unimplemented systems.
- [ ] Use the existing [compliance checklist](../EU-compliance/checklist.md) to
  inventory actual SDK/data processing, retention and deletion behavior. Publish
  accessible privacy information and a working external account-deletion request
  route, with access inside the app as required. Verify the existing deletion
  implementation rather than declaring it complete from its presence in code.
- [ ] Complete Data safety, content rating, target audience, ads/monetization and
  app-access declarations from verified behavior. Provide a working reviewer
  access path compatible with mandatory Play Games authentication; do not add
  an auth bypass or invent review credentials.
- [ ] Configure release certificates, App Check/Play Integrity and Play Games
  tester/publication state for intended testers. Play app publication and Play
  Games publication are separate checks.

Exit: required console tasks complete, policy URLs work, disclosures match the
candidate, and reviewers/testers can access the game.

### Prepared English (UK) listing copy

Drafted from implemented features and the companion repository's Identity,
CrossMediaExpressionRules and Naming&Terminology references. Not submitted.
Keep existing titles `Long Run` and `Long Run Staging`. These drafts fit Google's
[30/80/4,000-character listing limits](https://support.google.com/googleplay/android-developer/answer/9859152?hl=en-GB).
The [game icon and title graphic](../release-assets/android/README.md) are
prepared. Actual Android screenshots and IARC answers remain pending.

Production short description:

> Build your loadout and fight to survive a dark-fantasy action runner.

Production full description:

> In Lothringen: The Long Run, survival depends on the choices you make before
> a run and the timing of every move within it.
>
> Choose your equipment and abilities, then fight through scrolling Field and
> Forest routes. Jump past hazards, manage your resources, and combine melee,
> ranged, spell and mobility abilities as enemies close in.
>
> Experiment in Practice, take on fixed-route Competitive and Weekly challenges,
> and compare your scores on leaderboards. Race recorded ghosts, earn in-game
> rewards, and adapt your build for the next attempt. Discover enemies and places
> in the Library as your account progresses.
>
> This Android beta requires an internet connection and a Google Play Games
> account. It is played in landscape, with configurable touch movement controls.
> Beta updates may include maintenance periods and required app updates.
>
> Send feedback or request help at lothringen.rpg@gmail.com.

Staging short description:

> Internal testing for Long Run. Separate test accounts and progression.

Staging full description: prepend this paragraph to the production description:

> Long Run Staging is the separate internal testing app for selected release
> candidates. Your staging account and progress are independent of Long Run.
> Access is limited to invited testers.

Initial beta release-note draft, only after the accepted build is available:

> Initial Android beta: build a loadout, explore Field and Forest, and test
> Practice, Competitive and Weekly runs. Report issues to
> lothringen.rpg@gmail.com with your app version and steps to reproduce them.

### Prepared data inventory for store/privacy completion

This inventory follows the existing compliance checklist and inspected source;
it is not a submitted Data safety form or a published privacy policy.

| Processing | Data and purpose | Implemented boundary |
| --- | --- | --- |
| Sign-in/account management | Play Games identity, Firebase UID and authentication tokens | Separate Auth project per app; native bridge requests server-side access without extra email/phone scopes |
| Profile and progression | Chosen display name, loadout, items, wallet, inbox and progression | Authoritative project-local Functions/Firestore; display names and competitive results can be visible to other players |
| Runs and competition | Tick-stamped commands, run identity, seed, replay hashes, validation results, rewards and ghost replays | Project-local replay storage/validator; leaderboard and ghost features expose selected competitive results/replays |
| Security | App attestation, quota/deletion state and operational request metadata | Enforced staging/prod App Check and backend authorization; restricted logs and deletion barriers |
| Diagnostics | Crash/error types, stack traces and SDK device/installation/session metadata | Crashlytics enabled only for staging/prod Android release; custom field is environment, with no custom account identifier or exception-message payload |
| Local preferences | Controls, local Practice selections and retry/spool state | Package-private device storage; Practice never issues or submits online runs |
| Support and rights requests | Sender email and request contents supplied by the player | Operator Nicolas Louis, Finland; confirmed support mailbox; delete correspondence 90 days after resolution |

SDK processing must also be included. Firebase documents authentication IP/user
agent processing, Play Integrity attestation, Crashlytics installation identifiers
and its transitive Installations/Sessions dependencies. Disabling Google Analytics
does not remove those diagnostics. Context7 did not return the relevant disclosure
page, so use the official [Firebase SDK disclosure](https://firebase.google.com/docs/android/play-data-disclosure)
and [Play Games SDK disclosure](https://developer.android.com/games/pgs/data-collection)
when completing the actual form against the frozen Android dependency graph.

No Analytics, advertising or purchase package is configured in `pubspec.lock`;
the inspected dev APK has no location, contacts, camera, microphone or advertising
ID permission. Do not translate that into a claim of no SDK data collection.
The final staging/prod manifests remain artifact checks. Account deletion and
separate recovery/log/Crashlytics retention are described in the prepared
deletion page and [deletion contract](../tdd/account_deletion_workflow.md).
The prepared privacy page maps account/gameplay processing to the requested
service, security/reliability to legitimate interests, and rights handling to
legal obligations. Controller name/country and 90-day resolved-support retention
are confirmed. Public policy publication and final Console declarations remain
open release tasks. The in-app privacy link is implemented; its destination must
be published and checked before release.

## Phase 8 - live internal release and closed beta

Execution: agent via canonical release CLI, Chrome and physical-device checks.

- [ ] Prepare live artifacts from the exact staging-accepted commit, dependency
  locks and gameplay/content. Revalidate environment inputs and the new
  production project's state. Reuse valid source evidence,
  not dev/staging cloud checkpoints. If the target is no longer empty after smoke
  testing, use normal cutover/drain gates rather than the empty-project bootstrap.
  Any code/content fix returns to staging; environment-specific bundle checks and
  production smoke still run because the staging AAB is a different application.
- [ ] Record the concrete production deployment and recovery set, then use the
  owner's October 26 initial-release authorization after the non-waived acceptance
  checks pass. Use canonical bootstrap or coordinated cutover as appropriate,
  preserving readiness, issuer, queue and compatibility fences. The old owner's
  disposable dev data is not permission to reset new production accounts.
  Keep production in maintenance until backend and Play availability match.
  Android delivery does not independently require or authorize a web publication;
  the old web deployment remains part of dev.
- [ ] Upload the signed live AAB as a draft, resolve Play validation findings,
  then publish to the main app's internal track once that action is authorized.
- [ ] Install from Play on a fresh tester account. Confirm live-project identity,
  valid attestation, sign-in and a complete accepted/rewarded run, leaderboard and
  ghost flow. The owner may use the same Google account with fresh production
  state. Replace the owner's former debug-signed release installation if needed;
  preserving its local state or progression is not required. Verify ordinary
  Play-signed updates preserve newly created production state.
- [ ] Prepare the closed-beta tester list, countries, feedback route, release
  notes and known limitations. Promote the same verified artifact where possible;
  rebuilds need new identity/checks. Obtain authorization for the actual rollout.
- [ ] Verify the tester opt-in and Play installation/update flow. Record the
  released version code, artifact hash, backend tuple, cohort and release time.

Exit: invited beta players can install through Play and complete real runs
against a stable live backend. Dev/staging deployments cannot affect their
environment.

## Phase 9 - beta operations and subsequent releases

Execution: agent maintains workflow and evidence; user supplies feedback/rollout decisions.

- [ ] Use the diagnostics and alert thresholds verified before beta to monitor
  crashes/ANRs, auth/App Check failures, replay latency/backlogs, settlement,
  leaderboard/ghost health and cost. Keep the cohort within measured capacity.
- [ ] Document one repeatable sequence: implement/test in dev -> freeze candidate
  -> deploy to staging and complete internal acceptance -> prepare prod from that
  commit and complete Play review -> authorized maintenance/drain when incompatible
  -> production backend and matching Play release -> verified availability and
  smoke checks -> reopen. A production internal track shares the same backend
  as closed beta; do not test an incompatible backend on active beta players.
  Recheck compatibility for deterministic changes, including levels; compatible
  UI-only releases can follow the scoped path without retiring old clients.
- [ ] Keep one supported gameplay version per environment and enforce updates
  only after the replacement is available to every affected cohort there. Reuse
  the tested recovery procedure; revisit overlapping versions within an environment
  only if maintenance becomes unacceptable.
- [ ] If the developer account requires the closed-test qualification period,
  track real tester participation before applying for production/open access.
  Never claim elapsed time or participation that has not occurred.
- [ ] Update implemented TDD/GDD/AGENTS/setup docs with each delivered milestone.
  Archive this plan only after completion or explicit supersession, preserving
  unresolved findings and incoming links.

Exit: beta is supportable with isolated dev/staging, auditable candidate promotion
and a tested response to client/backend compatibility and operational failures.

## Reference requirements checked October 25, 2026

Recheck these against official documentation and the actual Console before each
submission; the account's eligibility and warnings are not known from this plan.

- [Firebase environments](https://firebase.google.com/docs/projects/dev-workflows/overview-environments)
  recommends a separate project for each environment.
- [Cloud project names and IDs](https://docs.cloud.google.com/resource-manager/docs/creating-managing-projects)
  distinguishes editable display names from globally unique, permanent project IDs.
- [Multiple-project configuration](https://firebase.google.com/docs/projects/multiprojects)
  describes selecting native configuration by build target.
- [Play signing](https://developer.android.com/studio/publish/app-signing) explains
  the upload/distribution key distinction.
- [Play Games setup](https://developer.android.com/games/pgs/console/setup) and
  [Cloud project settings](https://developer.android.com/games/pgs/console/cloud-platform)
  govern the credential/project topology; separate Firebase projects alone do
  not migrate Play Games credentials.
- [App Check / Play Integrity](https://firebase.google.com/docs/app-check/android/play-integrity-provider)
  requires the intended project linkage and signing-certificate registration.
- [Play testing tracks](https://support.google.com/googleplay/android-developer/answer/9845334)
  distinguish internal, closed and open distribution.
- [Immediate in-app updates](https://developer.android.com/guide/playcore/in-app-updates/kotlin-java#immediate)
  require user acceptance and can be canceled. Backend compatibility enforcement
  supplies the mandatory-update boundary; a Play Store link is the initial UI.
- [Firestore backup and restore](https://firebase.google.com/docs/firestore/backups)
  provides managed recovery; verify application consistency with synthetic data.
- [New personal-account testing](https://support.google.com/googleplay/android-developer/answer/14151465)
  currently requires qualifying accounts to have at least 12 closed testers
  continuously opted in for 14 days before applying for production access;
  production approval also unlocks open testing for these accounts.
- [Target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878)
  currently specify Android 16 / API 36 for new mobile apps and updates from
  August 31, 2026. Inspect actual build output rather than assuming Flutter's
  default satisfies it.
- [16 KB page sizes](https://developer.android.com/guide/practices/page-sizes)
  describes native-library compatibility and changing enforcement dates. Verify
  Flutter/plugin binaries and Play bundle checks; an SDK version is not proof.
- [Account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111)
  cover in-app and external deletion request routes for apps creating accounts.

Repository execution references: [deployment workflow](../tdd/deployment_workflow.md),
[release checklist](rescue_release_operations.md),
[prepared navigation](../tdd/prepared_navigation.md),
[Android identities](../tdd/android_build_variants.md),
[authentication](../tdd/authentication_flow_and_authorization.md),
[abuse controls](../tdd/callable_abuse_controls.md) and
[level traversal workflow](../../.agent/workflows/test-level-traversal.md).

Next action after the owner resumes: run the corrected five-submission staging
drill through `.tmp/beta-checks/staging_c8b_smoke_retry.ps1` and preserve its
separate evidence. Verify projections, pinned ghost downloads, duplicate rewards,
bounded metrics and real-clock account cleanup. Then inspect dev's live state and
perform its guarded cutover, preserving owner data. Reuse the frozen c8b artifacts
and keep unrelated subsequent main-branch changes out of this release. Continue Play
upload/publication and physical-device acceptance matrix when browser/device
access is available. Deploy production only after non-waived staging acceptance.
No Play bundle has been uploaded/released. Do not repeat completed setup or treat
local validation as live acceptance.
