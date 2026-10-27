# Agent routing

This is the index for repository-owned coding-agent guidance. `AGENTS.md` files
hold scoped rules; workflows are read on demand. These Markdown workflows are
not executable agents or automatically registered skills. Session tools own
agent execution and permissions; the repository does not configure a model,
launch agents, or provide a background scheduler.

Read the root instructions, each ancestor instruction file for a touched path,
and the smallest matching workflow. Paths in backticks in guidance are relative
to the repository root unless the text explicitly gives another base. Markdown
links are relative to their containing file.

## Instruction map

| Work area | Instructions |
| --- | --- |
| All work | [Root](../AGENTS.md) |
| App and embedding | [App](../lib/AGENTS.md) |
| Rendering, input and controller | [Game](../lib/game/AGENTS.md) |
| Menus, HUD, state and client adapters | [UI](../lib/ui/AGENTS.md) |
| Core package, tests and tools | [Core package](../packages/runner_core/AGENTS.md) |
| Simulation implementation | [Core source](../packages/runner_core/lib/AGENTS.md) |
| Run/replay/board contracts | [Protocol](../packages/run_protocol/AGENTS.md) |
| Shared source compilation | [Content pipeline](../packages/runner_content_pipeline/AGENTS.md) |
| Terrain render contracts | [Materials](../packages/terrain_materials/AGENTS.md) |
| Firebase backend; root Firestore rules/indexes | [Functions](../functions/AGENTS.md) |
| Replay validation and projection | [Worker](../services/replay_validator/AGENTS.md) |
| Content editor | [Editor](../tools/editor/AGENTS.md); [domain details](references/editor-authoring.md) |
| Release scripts and deployment configuration | [Release](../tools/release/AGENTS.md) |
| Android flavors, signing and artifact evidence | [Release](../tools/release/AGENTS.md); [Android identities](../docs/tdd/android_build_variants.md) |
| Root test suites; integration drivers | [Tests](../test/AGENTS.md) |
| Root generators and probes | [Tooling](../tool/AGENTS.md) |
| Authored source assets | [Authoring](../assets/authoring/AGENTS.md) |
| Documentation, plans and evidence | [Documentation](../docs/AGENTS.md) |
| CI workflows | [CI](../.github/AGENTS.md) |
| Agent guidance checker | [Agent tooling](../tools/agents/AGENTS.md) |

The test, Firestore and integration-driver routes above are explicit routing
rules even when the source owner's instructions are outside that path's ancestry.

## Workflow selection

| Trigger | Workflow |
| --- | --- |
| Multiple milestones, resuming work, or authorized collaboration | [Coordinate work](workflows/coordinate-work.md) |
| Wire payload, callable, persistence or settlement change | [Change a cross-layer contract](workflows/change-cross-layer-contract.md) |
| Add/reorder a simulation system | [Add Core system](workflows/add-core-system.md) |
| Add persistent ECS state | [Create ECS component](workflows/create-ecs-component.md) |
| Command/tick/order/determinism change | [Change simulation contract](workflows/change-core-simulation-contract.md) |
| Snapshot/event semantics | [Change output contract](workflows/change-core-output-contract.md) |
| Authored geometry, markers or themes | [Change authored content](workflows/change-core-authored-content.md) |
| Add a playable level | [Add level](workflows/add-new-level.md) |
| Geometry/assembly/enemy movement/navigation verification | [Test level traversal](workflows/test-level-traversal.md) |
| Prepare or execute an authorized release | [Deploy release](workflows/deploy-release.md) |

For ordinary UI, renderer, backend, editor, test or documentation edits, use the
owning instructions and relevant implementation docs; a separate workflow is
not required for every change. Compose workflows only at affected boundaries.

## Validation

Select actual test files for the changed behavior, replacing `<target>` below.
These are command templates, not a request to run every suite. Run native commands
sequentially when they share generated output or emulator resources; check exit
codes before treating later results as evidence.

| Scope | Working directory | Focused checks |
| --- | --- | --- |
| App, Game, UI, root integration tests | Repository root | `dart analyze <changed-path>`; `flutter test <target>` |
| Pure Dart package | Owning `packages/<package>` | `dart analyze`; `dart test <target>` |
| Functions | Repository root | `corepack pnpm --dir functions build`; `corepack pnpm --dir functions test` (compiled emulator suite) |
| Validator | `services/replay_validator` | `dart analyze`; `dart test <target>` |
| Editor | `tools/editor` | `dart analyze <changed-path>`; `flutter test <target>` |
| Generated content | Repository root | `dart run tool/generate_chunk_runtime_data.dart --dry-run`; relevant `test/tool` targets |
| Asset manifest | Repository root | `dart run tool/sync_assets.dart --check` |
| Agent guidance | Repository root | `node tools/agents/check.mjs`; `node --test tools/agents/check.test.mjs` when checker changes |
| Release tooling | Repository root | Required mocked tests in [release instructions](../tools/release/AGENTS.md) |

Resolve the root Pub workspace at the root, and independent editor/worker apps
in their own directories. Running pure-package tests from their owning directory
avoids accidentally invoking the Flutter root package's test configuration.
Package-specific invariant checks still apply (for example protocol AOT probes,
navigation freshness, traversal controls and replay benchmarks).

The installed pre-commit hook checks asset-manifest freshness only; it does not
establish test coverage. The agent-guidance CI job validates this index and its
instruction graph independently of Flutter and cloud credentials. See the
[orchestration contract](../docs/tdd/agent_orchestration.md) for checker scope.
