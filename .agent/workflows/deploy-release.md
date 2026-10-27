---
description: Prepare evidence and execute a user-authorized scoped or coordinated release
---

# Deploy a release

Read [deployment_workflow.md](../../docs/tdd/deployment_workflow.md),
[release instructions](../../tools/release/AGENTS.md), and the checklist matching
the requested release in [current plans](../../docs/building/README.md).
Verify its source, environment, scope and outstanding gates against the user's
request; an older release plan is not a default target or authorization.
Use `tools/release/release.ps1` as the entry point. Its default action is Plan.
Select `-Environment dev|staging|prod` explicitly throughout a release. The
registry and Firebase aliases must agree. Only dev has Hosting; a prepared web
artifact never proves Android packaging or Play acceptance. Project-scoped
baselines/checkpoints cannot establish readiness in a different environment.
For authorized foundation setup, use Provision with explicit environment,
billing account and monthly budget. Verify its live readback; it does not deploy
the game or establish Android/Play readiness. Existing queues retain their state.
Configure SigningSetup, RecoverySetup and MonitoringSetup in the selected project
before candidate cutover. Mutation locks and the source-bound maintenance record
must remain intact; inspect abandoned work before any manual lock recovery.
Use BuildAndroid after Prepare with an explicit environment and version code.
In a fresh checkout, first run `flutter build apk --config-only --flavor dev
--release` and verify `git status --short` is empty. This initializes Flutter's
ignored Gradle wrapper before BuildAndroid records its version; it does not
produce an APK or change the candidate. Do not copy wrappers from another app.
Check actual Play history before choosing codes and preserve the same accepted
production AAB when promoting tracks. Native signing/resources/assets and
Play-delivered authentication/attestation are separate acceptance gates.

1. Inspect source/worktree and run Plan. Resolve tuple or Functions environment
   drift before preparing. Use Checkout -Environment <environment> -Commit <authorized-commit> to create
   the isolated LF checkout and copy only application environment files. Run
   every stage there; exclude later edits. Plan reports Auto scope. No verified
   baseline means coordinated cutover; previously excluded deterministic changes
   still require a new gameplay version.
2. When available, ImportCI -RunId <successful-run> from the exact clean commit,
   then run Prepare to restore verified artifacts and check current advisories.
   Otherwise Prepare runs the same checks locally. Review component logs and
   the successful manifest; use Rebuild
   only when a matching preparation must deliberately be repeated.
3. Run Inspect if cloud access is available. If an installed gcloud reports no
   account, check process Windows app-data paths and access to the existing
   credential cache before requesting another login. Use the approved shell
   access path; never copy credentials into the repo. Report unresolved failures
   without treating historical deployment evidence as live confirmation.
4. For Hosting/Backend/None scope, use Deploy once authorized. Fresh live
   baseline checks must pass; review verified results and finish the linked
   Play Games smoke. Do not run pause/image/resume stages for those scopes.
   For Coordinated scope, once image upload/build is authorized, run BuildImage
   and poll ImageStatus.
   For identical worker inputs across environments, finish one image first, then
   use `BuildImage -Environment staging -ReuseImageFrom dev` and later
   `BuildImage -Environment prod -ReuseImageFrom staging`. Each copy runs the
   strict benchmark and must retain the source digest in its own registry.
   The destination build account needs reader access only to the source image
   repository. Runtime service identities and player data stay project-local.
   Preparation can be reused while the source and artifact hashes match.
5. Once production cutover is authorized, run PauseIssuance. A newly provisioned
   target uses Bootstrap -CutoverReady first: it verifies no Auth users, Firestore
   collections, Functions or Cloud Run services and creates only the paused
   issuer. A partially bootstrapped target recovers through normal pause/deploy,
   never by deleting resources to make the empty check pass. Keep queues running
   while validation and settlement drain. Any cancellation/reset needs its own
   authorization and is not performed by this workflow. The action pins the live
   issuer image or, when it was deleted by managed cleanup, rebuilds the prepared
   issuer with the pause gate explicitly set. Verify the healthy serving revision,
   not just a desired template from a failed update.
6. Run Deploy -CutoverReady only after the drain review. Review saved
   checkpoints if an index or later deployment step fails; keep issuance paused.
7. Inspect board completion, then run ResumeIssuance -CutoverReady. Complete the
   linked Play Games smoke, replay acceptance, once-only settlement, leaderboard,
   retired-version rejection and generation-pinned ghost checks.
8. Record actual source, image/revision, Hosting artifact identity, live checks,
   exclusions and remaining work. Update the release checklist; archive it only
   when its outstanding verification is complete or explicitly superseded.
   Pending deterministic gameplay excluded from this deployment needs its own
   compatibility version before the next cutover.

Use release.ps1 for both scoped and coordinated releases. Direct backend package
deployment commands do not perform these scope/baseline checks or coordinated
cutover. Do not use them while a compatibility release is in progress.
