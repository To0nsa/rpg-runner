# AGENTS.md - release tooling

Read the root AGENTS.md, docs/tdd/deployment_workflow.md and the current release
checklist before changing this workflow.

- release.ps1 is the canonical entry point; keep its default action offline Plan.
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
- Keep successful preparation bound to source/toolchain/artifact evidence.
  Production stage checkpoints must never outlive their matching artifacts.
- Release web builds must include web/production_defines.json and reject a
  missing or empty App Check site key. This domain-restricted key is public;
  credentials and debug tokens must never enter that file.
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
- Report live checks, mocked checks and unrun gates separately. Never relabel
  a prior release's owner-requested test omission as a passing current gate.
