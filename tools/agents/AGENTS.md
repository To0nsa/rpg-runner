# Agent guidance tooling

This directory validates repository guidance; it does not execute agents or
application checks. Keep it dependency-free using Node built-ins and Git so it
works offline before Flutter/cloud setup. Do not read user configuration,
credentials, ignored build trees or external companion repositories.

Preserve read-only checks, deterministic actionable diagnostics, nonzero failure
status and path handling on Windows/Linux and in Git worktrees. Document supported
Markdown/reference syntax and checker limits in the
[orchestration contract](../../docs/tdd/agent_orchestration.md).

Changes to checker behavior require isolated fixture regressions for both valid
guidance and failure cases. Run `node --test tools/agents/check.test.mjs` and
`node tools/agents/check.mjs` from the repository root. Do not add app test suites
or cloud calls to this checker.
