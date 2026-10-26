# Documentation

Use [the index](README.md), [active plans](building/README.md) and
[active audits](audit/README.md) to locate current work. Follow
[the documentation policy](rules/code-documentation-policy.md).

- TDDs describe implemented technical contracts; GDDs describe implemented game
  behavior and tuning. Check code before asserting either.
- Keep proposed/in-progress work in one `building/` checklist per workstream.
  Audits record findings and link accepted work; `verification/` records evidence.
- Evidence states tested source, command/working directory, result, limitations
  and whether checks were local, mocked or live. No fabricated passes or deployments.
- Archive completed, closed or explicitly superseded audits/plans under
  `archive/<date>/` using the original folder structure. Update incoming links and
  indexes; unresolved findings remain explicit. Archived work is not a task queue.
- Use relative Markdown links for repository references. Keep external world
  canon references clearly identified; never imply unavailable material was read.

For documentation-only edits, inspect the diff and validate affected links.
Do not run application analyzers or test suites. Agent instruction/workflow edits
also run `node tools/agents/check.mjs` from the root.
