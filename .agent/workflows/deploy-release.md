# Deploy a coordinated release

Read [deployment_workflow.md](../../docs/tdd/deployment_workflow.md) and the
[current release checklist](../../docs/building/rescue_release_operations.md).
Use tools/release/release.ps1 as the entry point. Its default action is Plan.

1. Inspect source/worktree and run Plan. Resolve tuple or Functions environment
   drift before preparing.
2. Run Prepare. Review the per-slice logs and successful manifest; use Rebuild
   only when a matching preparation must deliberately be repeated.
3. Run Inspect if cloud access is available. If an installed gcloud reports no
   account, check process Windows app-data paths and access to the existing
   credential cache before requesting another login. Use the approved shell
   access path; never copy credentials into the repo. Report unresolved failures
   without treating historical deployment evidence as live confirmation.
4. Once image upload/build is authorized, run BuildImage and poll ImageStatus.
   Preparation can be reused while the source and artifact hashes match.
5. Once production cutover is authorized, run PauseIssuance. Keep queues running
   while validation and settlement drain. Any cancellation/reset needs its own
   authorization and is not performed by this workflow.
6. Run Deploy -CutoverReady only after the drain review. Review saved
   checkpoints if an index or later deployment step fails; keep issuance paused.
7. Inspect board completion, then run ResumeIssuance -CutoverReady. Complete the
   linked Play Games smoke, replay acceptance, once-only settlement, leaderboard,
   retired-version rejection and generation-pinned ghost checks.
8. Record actual source, image/revision, Hosting artifact identity, live checks,
   exclusions and remaining work. Update the release checklist; archive it only
   when its outstanding verification is complete or explicitly superseded.

Backend-only package deployment commands do not perform this coordinated
cutover. Do not use them while a gameplay compatibility release is in progress.
