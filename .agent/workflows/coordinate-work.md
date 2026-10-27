---
description: Coordinate substantial work, preserve evidence, and resume safely across sessions
---

# Coordinate work

Use this for multiple milestones, resumed work, or collaboration already
authorized by the user/session. Ordinary small edits need no new plan artifact.
Start with the [routing index](../README.md) and current implementation.

## Establish scope

- Record the requested outcome, acceptance criteria, affected owners, existing
  worktree changes and material constraints. Separate verified facts from assumptions.
- Reuse the matching active plan in [the planning index](../../docs/building/README.md).
  If sustained work needs one, create one focused checklist there and link evidence
  to it. Do not create competing task ledgers or revive archived work implicitly.
- Order milestones by dependencies: settle shared contracts before dependent
  implementations; keep producer/consumer migrations together when intermediate
  states would be invalid. Identify focused checks and docs for each milestone.

## Execute and integrate

- Keep one coordinator responsible for scope, shared contracts, integration and
  final evidence. A single agent is sufficient when tasks share files or decisions.
- If collaborators are explicitly authorized and available, give each a bounded
  outcome, owned paths, dependencies, applicable instructions, acceptance criteria,
  and expected return format. Authorization and tool limits still apply; this
  workflow does not itself enable delegation or background agents.
- Use disjoint write ownership. Shared checkout changes are immediately visible;
  collaborators must not reset, stage or commit one another's work. Serialize
  shared-file edits, generated outputs, dependency resolution and emulator use.
  Use separate worktrees only when isolation serves the task and account for
  their dependency/build state. A worktree does not isolate cloud services.
- Require handoffs to state changed files, decisions, checks/results and unresolved
  risks. Review actual diffs and integrate dependent checks; a collaborator's
  completion message alone is not proof of correctness.
- Diagnose failed checks before retrying. Keep regressions as tests and preserve
  failure details. Do not loop unchanged commands, mask failures, or lower gates.

## Checkpoint and resume

For a meaningful checkpoint, update the existing plan/evidence with:

- completed scope and next concrete action
- relevant commit or uncommitted file state, including unrelated edits to preserve
- changed contracts and decisions that affect the next step
- exact validation command, working directory, result and source tested
- blockers, remaining checks and any authorization boundary

Do not copy whole logs or secrets into plans. Keep transient output in ignored
scratch locations. Commit only coherent validated milestones and inspect staged
changes first. If unrelated staged edits prevent a clean task-only commit, leave
the milestone uncommitted and report it rather than altering someone else's index.

On resume, reread the latest user constraints, active plan and applicable
instructions; inspect the current worktree. Reconcile the checkpoint with actual
files before acting. Reuse validation only where inputs are unchanged; do not
claim old, mocked or partial evidence as a new full pass.

## Finish

Review the task diff for correctness, scope, duplicate implementations, missing
consumers, source/generated consistency and documentation. Report delivered
behavior, validation and limitations. Archive completed plans/audits and repair
links as described in [documentation instructions](../../docs/AGENTS.md).
Leave remaining work explicit; do not mark blocked or unrun gates complete.
