# Agent orchestration audit — October 26, 2026

Status: initial repository findings resolved in `8056f116`; additional checker
fixes and evidence are recorded in the [follow-up review](#follow-up-review).
This is a closed audit of
coding-agent guidance and coordination, not a gameplay-AI or production audit.
Current behavior is documented in the
[orchestration contract](../../../tdd/agent_orchestration.md) and
[routing index](../../../../.agent/README.md).

## Scope and method

Inspected all 13 original `AGENTS.md` files, all eight original `.agent/workflows`
documents, the three existing CI workflows, the installed pre-commit hook, package
and workspace manifests, documentation indexes and relevant source/test entry
points. Checked local guidance links, instruction ancestry/bytes, source paths,
test runners, source-generation ownership, release routing, and task lifecycle.
Confirmed level schema v3 against both generator and editor constants, and ECS
registration guidance against `EcsWorld`. Checked the traversal matrix and
generator/test targets without rerunning gameplay suites for documentation edits.

Initial baseline was `5567f8b8`. Existing protocol work was independently committed
as `d7e8397e` during this audit; it was not edited, staged or tested by this task.
Existing Android release-planning changes were also preserved. This audit's
implementation commit contains only agent guidance, its checker/tests, CI and
related documentation.

Codex discovery was checked against current official documentation and the
Context7 `/openai/codex` source. The documented default combined instruction
limit is 32 KiB; nested discovery follows the root-to-working-directory chain.
See [official discovery guidance](https://learn.chatgpt.com/docs/agent-configuration/agents-md).

## What already worked

- Layer ownership was substantially correct: pure Dart Core/protocol/content
  packages, Flame bridge, app state, Functions, replay worker and editor boundaries.
- Determinism, auth, revision/idempotency, generated-content ownership and release
  cutover constraints were documented in the owning layers.
- Core change workflows and the traversal workflow described real implementation
  paths, reusable fixtures and finite-route evidence limits.
- Release tooling had offline planning, evidence/cache discipline and mocked CI;
  documentation already distinguished current plans from archived evidence.
- Root validation policy explicitly called for proportional checks, although
  some descendant command lists communicated a different default.

These were retained. No application architecture reorganization was needed to
repair the agent control surface.

## Findings and resolution

| ID | Severity | Observed problem | Delivered resolution |
| --- | --- | --- | --- |
| A1 | High | UI and editor ancestor chains exceeded the documented default instruction limit, risking truncated rules. Root guidance duplicated maps and broad context. | Root reduced from 16,661 to 9,287 bytes; detailed editor domain rules moved to an explicit reference without losing their content. Enforced root/chain budgets. |
| A2 | Medium | No workflow index or complete instruction map; release instructions were outside the root's main list. | One checked routing index includes every instruction, workflow and agent reference, with task triggers and command working directories. |
| A3 | Medium | “Closest instructions” was ambiguous about ancestor rules and source rules for tests/assets outside source subtrees. Generators, tests, authoring, docs and CI lacked scoped entry guidance. | Root now requires all applicable ancestors and explicit source-owner routing. Added concise scoped instructions and mapped root infrastructure/integration drivers. |
| A4 | Medium | Blanket minimum/full-suite lists competed with proportional validation; package test commands could be interpreted as root Flutter-package invocations. | Clarified focused-first selection and package working directories; preserved mandatory AOT, traversal, compatibility and release gates. Included portable Core package tests. |
| A5 | Medium | Level workflow/editor instructions still named schema v2 although current source/code require v3. Deployment workflow selected one historical rescue-release checklist as “current.” | Updated schema guidance and required selecting the checklist matching the user's release from the current index. |
| A6 | Medium | No common checkpoint, resume, shared-write ownership or evidence handoff procedure. | Added a coordination workflow covering one workstream checklist, dependency order, bounded collaborator scope when authorized, integration review and accurate resumption. |
| A7 | Medium | Core-specific workflows existed, but no procedure traced client/Functions/worker contract changes end to end. | Added a cross-layer workflow covering codecs, constructors, persistence, auth, retries, leases, digest/version effects and consumer verification. |
| A8 | Medium | Nothing automatically detected guidance index drift, broken links, shadowed instructions or context-budget growth. Existing hook checked assets only. | Added a read-only Node/Git checker, 19 regression tests and Windows/Linux CI with broad triggers to catch referenced-file deletions. |
| A9 | Low | Context7 guidance arrived from session instructions but was not a durable repository convention. | Root now records resolve-first external API lookup and official-source fallback without demanding documentation lookups for ordinary business logic. |

No pre-existing broken inline Markdown links were found in the original
instruction/workflow set. The relevant problems were missing routing and stale
semantics, not a fabricated collection of broken links.

## Context measurements

Before values are raw on-disk ancestor-file sums from the initial checkout.
After values include the checker's two-byte separators. Checkout line endings
may change byte totals slightly; CI measures its own checkout.

| Chain | Before bytes | After bytes |
| --- | ---: | ---: |
| Root | 16,661 | 9,287 |
| Root → app → UI | 34,041 | 26,773 |
| Root → editor | 43,082 | 26,152 |
| Root → Core package → Core source | 29,965 | 22,966 |

The maximum is now 26,773 bytes against a 28,672-byte repository budget. The
editor reference is selected only for relevant domains. Adding more nested files
alone would not have solved cumulative chain size; reducing always-loaded
content was necessary.

## Validation evidence

Local Windows checkout, Node `v24.22.1`, implementation committed as `8056f116`:

| Check | Working directory | Result |
| --- | --- | --- |
| `node --test tools/agents/check.test.mjs` | Repository root | 19 passed; zero failed/skipped. Covers valid guidance, missing/deleted files/directories, new unindexed instructions/workflows, budgets, overrides, anchors, UTF-8/CRLF, outside-repo symlinks, ignored trees, linked Git worktrees and CLI exit behavior. |
| `node tools/agents/check.mjs` | Repository root | Pass; 32 guidance files and all 19 instruction chains checked. |
| Editor extraction comparison | Repository root | Existing domain section preserved, apart from terminal blank-line normalization. |
| CI YAML parse | Repository root | Parsed with local Python YAML parser; Windows/Linux matrix verified. This is syntax evidence, not a hosted CI run. |
| `git diff --cached --check` and staged scope review | Repository root | Pass before implementation commit; no unrelated files included. |
| Installed pre-commit asset-manifest check | Repository root | Pass: asset block up to date. |

Full Flutter, backend, worker and editor suites were not run: no application
behavior or release tooling executable changed. Existing release checks remain
required for future changes that affect those invariants.

## Limits and intentional omissions

- Hosted CI, Linux execution and future agent instruction loading were not observed
  locally. The workflow is committed; remote branch protection was not changed.
- The checker validates structure, references and size, not prose truth or command
  semantics. Code-path literals and unsupported Markdown forms need review; its
  documented supported syntax is intentionally small and dependency-free.
- No repository agent runtime, model pinning, role configuration, persistent agent
  queue or scheduler was found or added. Current workflows use the host session's
  capabilities. Adding a second execution framework without an actual consumer
  would increase maintenance rather than close a demonstrated gap.
- No agent delegation, global configuration changes, cloud mutations, deployments
  or external messaging were performed. Coordination guidance applies only when
  collaborators are authorized and available.
- Global/session instruction size and actual agent adherence are not proven by a
  repository byte check. Report host-specific loading failures when observed;
  do not treat the budget as a universal runtime guarantee.

No findings were deferred from the initial audit. The limits above are evidence
boundaries and operating choices, not passing claims about unrun work.

## Follow-up review

The user's requested verification started from `3eb58336`. The original 19 tests
still passed, but seven newly added regressions failed against that implementation.
The review repaired these concrete gaps:

| Finding | Correction |
| --- | --- |
| HTML-comment links could satisfy required navigation; stale commented links generated false failures. | Ignore HTML comments for links and headings. Commented headings cannot satisfy anchors. |
| Unused reference definitions counted as index entries, while undefined explicit references were not checked. | Resolve actual full/collapsed/shortcut reference use, reject undefined explicit references, and require a visible navigation link. Images also cannot substitute for navigation. |
| URL decoding happened before fragment splitting, so a valid `%23` in a filename became a fragment separator. | Split literal separators before decoding the path and fragment independently. |
| The link regex truncated parenthesized filenames and mishandled single-quoted titles. | Parse balanced/escaped destination parentheses and quoted titles; diagnose malformed destinations. |
| Empty quoted or non-string workflow descriptions passed the presence check. | Require a nonempty single-line string description; reject common non-string scalar, block and collection forms. |
| A symlink to an ignored file inside the repository bypassed the ignored-tree boundary. | Require the resolved target to belong to the repository's Git inventory as well as remain physically inside the repository. |
| The level workflow invoked `dart analyze` with three positional directories. | Use one invocation per directory, matching the [official Dart command syntax](https://github.com/dart-lang/site-www/blob/main/src/content/tools/dart-analyze.md) fetched through Context7 and the installed CLI's usage output. |

Regression coverage now includes 29 tests, all passing locally on Windows with
Node `v24.22.1`: zero failures or skips. The fixture repositories use a private
empty hooks directory so fixture commits cannot execute a user's global hooks.
Size-report ordering is ordinal rather than locale-dependent. The command
`node tools/agents/check.mjs` still passes for 32 guidance files; the largest
instruction chain remains 26,773 bytes. `git diff --check` passes. Maintained
guidance source paths were reviewed again, with package/domain-relative and
external brand references distinguished from missing files.

Current parser scope and limitations are updated in the
[orchestration contract](../../../tdd/agent_orchestration.md). The added tests
include both valid syntax and negative controls; the checker remains offline
and does not claim to implement all Markdown or YAML syntax.

The existing Ubuntu WSL environment was inspected for an independent Linux run.
Git was available, but Node was absent from its executable path. No runtime was
installed and no Linux pass is claimed. Hosted CI remains unrun locally. The
installed Dart usage text confirmed the analysis syntax, but its telemetry write
was denied by the sandbox; official documentation independently established the
same syntax. No application suites or production operations were needed for
these checker/documentation changes. Unrelated Android planning edits remain
outside this task.
