# AGENTS.md - release tooling

Read the root AGENTS.md, [deployment contract](../../docs/tdd/deployment_workflow.md)
and the checklist matching the user's release in
[current plans](../../docs/building/README.md) before changing this workflow.
Do not assume a previously used release checklist is the current target.

- release.ps1 is the canonical entry point; keep its default action offline Plan.
- Select dev/staging/prod through environments.json. Cloud mutations require
  explicit -Environment. Reject conflicting project, bucket, queue, endpoint and
  service-account values before mutation; never inherit dev configuration for a
  missing project file. Only dev currently publishes Hosting.
- Preserve the independent Flutter workspace and Dart validator lockfiles.
- Reuse configure_cloud.ps1 and retention/monitoring scripts rather than
  duplicating their deployment policy.
- Keep ticket issuance paused across coordinated Functions/worker/Hosting
  cutover. Exclude runSessionCreate from that backend phase; it belongs to
  ResumeIssuance. Verified Backend scope may redeploy it under the unchanged
  tuple without pausing issuance.
- PauseIssuance may rebuild a missing issuer image only with the explicit
  release-paused environment gate. Restore local environment bytes in finally.
  Verify the healthy revision serving all traffic, not the desired template.
- Bootstrap requires a fresh empty-project inventory and the same prepared
  source/benchmarked image. Create only a paused issuer, then use normal cutover.
  Never clear an established environment to satisfy bootstrap emptiness.
- Keep successful preparation bound to source/toolchain/artifact evidence.
  Production stage checkpoints must never outlive their matching artifacts.
- Web builds are optimized local Practice hosts with no Firebase configuration.
  Bundle CanvasKit with --no-web-resources-cdn and require web_smoke.mjs against
  the built artifact before caching client-build evidence. Chrome and Node are
  required. Linux CI also runs browser widget tests; its success gates the bundle.
  Keep native account/App Check restrictions and backend authorization intact.
- Keep component input dependencies and CI recipes aligned. A cache hit must
  verify artifact bytes; partial client shards and failed/fork/PR CI runs are
  not complete release evidence. Never cache the current npm advisory audit.
- Scoped deployment requires a verified baseline and fresh unchanged live
  consumers. Shared gameplay/protocol/infrastructure changes use coordinated
  cutover. Keep the exact final-image benchmark and readiness/drain gates.
- Keep cloud mutations sequential and explicit. Tests use mocked commands and
  isolated .tmp fixtures; never run a production cutover to test the scripts.
- Test helpers and the actual entry-point sequence with test_release.ps1 and
  test_release_integration.ps1, plus cache/CI checks in test_release_cache.ps1,
  under Windows PowerShell and PowerShell 7.
- Also run test_release_environments.ps1 and integration cases with
  -TestEnvironment staging and prod for environment-routing changes.
- Report live checks, mocked checks and unrun gates separately. Never relabel
  a prior release's owner-requested test omission as a passing current gate.
