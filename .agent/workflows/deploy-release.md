# Deploy a release

Read [deployment_workflow.md](../../docs/tdd/deployment_workflow.md) and the
[current release checklist](../../docs/building/rescue_release_operations.md).
Use tools/release/release.ps1 as the entry point. Its default action is Plan.

1. Inspect source/worktree and run Plan. Resolve tuple or Functions environment
   drift before preparing. Use Checkout -Commit <authorized-commit> to create
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
   Preparation can be reused while the source and artifact hashes match.
5. Once production cutover is authorized, run PauseIssuance. Keep queues running
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
