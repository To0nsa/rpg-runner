# AGENTS.md - release tooling

Read the root AGENTS.md, docs/tdd/deployment_workflow.md and the current release
checklist before changing this workflow.

- release.ps1 is the canonical entry point; keep its default action offline Plan.
- Preserve the independent Flutter workspace and Dart validator lockfiles.
- Reuse configure_cloud.ps1 and retention/monitoring scripts rather than
  duplicating their deployment policy.
- Keep ticket issuance paused across Functions/worker/Hosting cutover. Never
  redeploy runSessionCreate in the backend phase; it belongs to ResumeIssuance.
- PauseIssuance may rebuild a missing issuer image only with the explicit
  release-paused environment gate. Restore local environment bytes in finally.
  Verify the healthy revision serving all traffic, not the desired template.
- Keep successful preparation bound to source/toolchain/artifact evidence.
  Production stage checkpoints must never outlive their matching artifacts.
- Keep cloud mutations sequential and explicit. Tests use mocked commands and
  isolated .tmp fixtures; never run a production cutover to test the scripts.
- Test helpers and the actual entry-point sequence with test_release.ps1 and
  test_release_integration.ps1 under Windows PowerShell and PowerShell 7.
- Report live checks, mocked checks and unrun gates separately. Never relabel
  a prior release's owner-requested test omission as a passing current gate.
