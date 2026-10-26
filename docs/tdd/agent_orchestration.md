# Repository agent orchestration

## Scope and ownership

The repository orchestrates coding work through scoped instructions and
on-demand workflows. It has no custom agent runtime, agent roles tied to models,
background scheduler, repository-local MCP configuration, or automatic delegation.
The host session supplies those capabilities and controls permissions.

The instruction graph starts at [root instructions](../../AGENTS.md) and the
[routing index](../../.agent/README.md). Root guidance owns shared boundaries,
worktree hygiene, proportional validation and release authorization. Nested
`AGENTS.md` files own their subtree's constraints; explicitly routed source
instructions also apply to related tests, authored assets and root infrastructure.
Workflows own procedures, and TDD/GDD documents own implemented contracts.
Plans and verification records own task progress and evidence, respectively.

Do not duplicate all these sources into a second set of agent personas, skills
or generated instruction files. Extend an existing owner when the behavior fits.
Repository Markdown workflows are explicitly read references, not automatically
registered tools or executable skills.

## Discovery and context budget

Codex's documented discovery walks from the project root toward the working
directory, with a default combined instruction limit of 32 KiB. A session opened
at the root therefore still needs to read relevant descendant instructions when
editing their files. See [official instruction discovery documentation](https://learn.chatgpt.com/docs/agent-configuration/agents-md).

The local checker limits root guidance to 10 KiB and each repository instruction
chain to 28 KiB, including two-byte separators. This leaves margin below the
documented default; it does not measure global/session instructions or guarantee
the host loaded a particular file. Long domain details belong in linked,
task-selected references, such as [editor authoring](../../.agent/references/editor-authoring.md).

The routing index links every repository instruction file, workflow and agent
reference. Keep one instruction owner per directory: an `AGENTS.override.md`
beside `AGENTS.md` is rejected because it silently shadows the canonical rules.
No user-global configuration is changed or inspected by this mechanism.

## Work lifecycle

[Coordination](../../.agent/workflows/coordinate-work.md) establishes one outcome,
acceptance criteria and dependency order. Small tasks need no persistent plan.
Longer tasks reuse one current workstream checklist rather than creating parallel
state files. Checkpoints record actual file/commit state, decisions, validation
inputs/results, remaining work and authorization boundaries.

Use a single coordinator for integration. If the user/session explicitly enables
collaborators, assign bounded outcomes and disjoint write ownership; serialize
shared-file edits, generators, dependency resolution and emulator resources.
Review returned diffs and evidence before integrating. This convention neither
launches agents nor overrides the host's delegation restrictions.

On resume, reconcile the saved checkpoint with current user constraints and Git
state. Reuse checks only for unchanged inputs. Complete producer/consumer changes
together using the [cross-layer workflow](../../.agent/workflows/change-cross-layer-contract.md).
Record release prerequisites separately from local implementation completion;
cloud cutover requires the user's release authorization.

## Offline guidance check

Run from the root:

```text
node tools/agents/check.mjs
node --test tools/agents/check.test.mjs
```

The checker also runs by absolute script path from another directory; it derives
the repository root from its own location. It uses Node built-ins and Git,
without dependency installation, Flutter, network, credentials or cloud calls.
Git's tracked and nonignored untracked file inventory works in normal checkouts
and linked worktrees. Ignored build/dependency trees are excluded, including when
a symlink alias points into one. Resolved targets must remain inside the repository
and its Git inventory. Deleted tracked targets are still reported as failures
until references are repaired.

Checks cover:

- required root/index/contract and root-to-index navigation
- complete index entries for all `AGENTS.md`, `AGENTS.override.md`, workflows and
  other Markdown references under `.agent/`
- nonempty guidance, single-line string workflow descriptions and shadowing overrides
- local Markdown link existence, repository containment and Markdown heading anchors
- root and ancestor-chain UTF-8 byte budgets

Link checks apply to instruction files, `.agent/**/*.md`, and this contract.
Linked documents are read to resolve heading anchors, but their outbound links
are not recursively crawled. Supported syntax includes inline Markdown links
with angle-bracket destinations, balanced/escaped parentheses and optional quoted
titles, plus full, collapsed and defined shortcut reference links. Explicit
references without definitions and malformed inline destinations fail. Labels
resolve without case sensitivity; the first definition wins. Definitions are
checked, but unused definitions and images cannot satisfy navigation/index entries.
Literal fragment separators are split before URL decoding, preserving encoded
characters in filenames. Heading checks support ATX `#` headings and duplicate
heading suffixes. Fenced/inline code examples and HTML comments are excluded from
link discovery; commented headings cannot satisfy anchors. Use relative,
forward-slash links and ATX headings in maintained guidance. Labels and reference
definitions must be on one line. External links are not fetched. Inline backtick
paths, shell-command correctness, arbitrary HTML anchors, complex nested Markdown
labels and whole-repository prose semantics are outside this checker.

Workflow front matter requires a nonempty single-line description, plain or
quoted. Empty strings, null/boolean/numeric scalars and block/collection forms
are rejected; this intentionally does not implement a general YAML parser.

Failures produce deterministic file-specific diagnostics and exit status 1.
The checker does not execute referenced workflows or mutate files. Its fixtures
exercise missing/deleted references, indexing, size growth, encoding/line endings,
worktrees and command-line failures. Guidance edits need the check; checker edits
also need the regression suite.

## CI and evidence limits

[Agent guidance CI](../../.github/workflows/agent-guidance.yml) runs the checker
and fixture tests on Windows and Linux for pull requests and pushes to `master`.
It deliberately has no path filter: deleting a referenced source or document
must fail even if no guidance file changed. It uses read-only repository access,
bounded timeouts and no production actions. Branch-protection requirements are
remote settings and are not established by adding this workflow.

The existing pre-commit hook checks asset-manifest freshness. Application,
generator and release suites remain separate; a guidance pass proves structural
health only. Human/agent review must still compare claims and command examples
with current code, assess missing consumers and choose behavior tests. Local
checker success is not evidence that hosted CI or future agent sessions ran.
