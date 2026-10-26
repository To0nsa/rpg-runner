# Continuous integration

Keep jobs bounded, reproducible and least-privileged. Use checked-in toolchain
versions and frozen lockfiles; respect independent editor/worker resolutions.
CI must never deploy or mutate production merely to validate a pull request.

Changes to release jobs or evidence must follow
[release tooling instructions](../tools/release/AGENTS.md). Preserve exact-source
artifact keys, complete shard coverage and live-versus-mocked distinctions.

Agent guidance checks use Node built-ins and Git only. Keep their trigger broad
enough to catch a source/document deletion that breaks an existing guidance link,
even when no instruction file changed. Run checker regressions on Windows and
Linux. Workflow syntax checks do not establish that hosted jobs have run.
