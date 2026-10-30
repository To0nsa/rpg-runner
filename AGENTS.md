# AGENTS.md

Instructions for **Lothringen: The Long Run**.

## Start here

1. Inspect the task's implementation and `git status --short`. Preserve unrelated
   work, including staged edits; never reset or overwrite it to simplify a task.
2. Read every applicable `AGENTS.md` from the root to the files being changed,
   not only the closest one. Deeper rules refine their own subtree. When working
   from the root, explicitly open nested instructions before editing there.
3. Use the [agent routing index](.agent/README.md) to select instructions,
   workflows, and validation. Read only task-relevant references. Tests and
   authored assets also require the rules of the implementation they exercise.
4. Consult [current documentation](docs/README.md) and the matching TDD/GDD.
   Plans and archived evidence describe intent/history, not implemented behavior
   or authorization to start unrelated work.

Direct session instructions take precedence over repository guidance. Keep
explanation-only and review-only requests read-only. Proceed with authorized
implementation; clarify only when an unresolved assumption risks material churn.
For substantial work, inspect first, choose an approach consistent with current
patterns, and establish acceptance criteria. Use the
[coordination workflow](.agent/workflows/coordinate-work.md) for work spanning
milestones, sessions, or explicitly authorized collaborators.

## Ownership and boundaries

| Area | Authority |
| --- | --- |
| `packages/runner_core/` | Pure-Dart fixed-tick gameplay, ECS, commands, events, snapshots |
| `packages/runner_content_pipeline/` | Explicit authored source strings to typed Core runtime data; no repository I/O |
| `packages/run_protocol/` | Pure-Dart run/replay/board/leaderboard wire contracts |
| `packages/terrain_materials/` | Pure-Dart terrain render-material source contracts |
| `packages/tool_ui/` | Shared Flutter tool presentation |
| `packages/game_presentation/` | Core-backed icons and names |
| `tools/admin/` | Operator UI and isolated local service |
| `lib/game/` | Flame rendering and input/controller bridge |
| `lib/ui/` | App shell, menus, HUD, local state and backend adapters |
| `functions/src/` | Authenticated profile, ownership, run-session, board and account authority |
| `services/replay_validator/` | Deterministic replay validation, settlement handoff and projections |
| `tools/editor/` | Repository-backed source authoring; never gameplay authority |
| `tool/` | Repository generators, asset checks and local probes |
| `tools/release/` | Release preparation, evidence and authorized cutover |

Keep `ui -> game -> core`. UI may consume stable Core value types and public
definitions, but may not mutate Core internals. Core must not import Flutter,
Flame, the content pipeline, or backend/UI concerns. Keep filesystem traversal
outside shared content packages. Prefer existing semantic APIs and domain owners
over new parallel abstractions.

When a contract crosses layers, update every affected producer and consumer in
one change. Follow [cross-layer changes](.agent/workflows/change-cross-layer-contract.md)
for protocol, callable, persistence, settlement, and client changes. Keep
determinism, authentication, compatibility, revision, and idempotency checks intact.

## Development environment

The app, `tools/admin` and `packages/*` share the root Pub workspace and `pubspec.lock`. Run
`flutter pub get` and workspace dependency changes at the root; never create
member lockfiles. `tools/editor` and `services/replay_validator` are independent
apps with their own checked-in lockfiles. Resolve the editor with Flutter from
its directory and the worker with `dart pub get` from its directory.

Use the versions recorded in [README.md](README.md) and the lockfiles. Backend
commands use Corepack/pnpm from the root workspace. Edit `functions/src/**`,
never generated `functions/lib/**` or `functions/lib_test/**`.

Fetch current library/SDK/API/CLI documentation with Context7 when changing
library-specific usage or configuration: resolve the library ID first, then
query one concept at a time. Use official documentation if the tool is unavailable
and report the limitation when material. Repository logic, refactors and reviews
that do not depend on external API behavior do not need a documentation lookup.

## Validation

Choose the smallest checks that prove the affected behavior. The
[routing index](.agent/README.md#validation) records working directories and
commands. Command lists in nested instructions are menus unless a specific
invariant or release gate makes a check mandatory.

- Explanation-only work needs no tests unless necessary to answer the question.
- Documentation-only work needs diff/link checks, not app analyzers or suites.
- Small code changes need targeted analysis and relevant behavior tests.
- Exact reverts need diff verification; test only for conflicts or uncertainty.
- Cross-layer changes need checks on each affected side of the contract.
- Run full suites for broad impact, explicit requests, or required release gates.
  Explain unusually expensive checks before starting them.
- Reuse verified artifacts (including navigation) and test evidence when inputs,
  toolchain/config, environment/signing and hashes match. New commits alone do
  not invalidate reuse. Explain rebuilds; record command, directory, result and
  source; distinguish live, mocked, failed and unrun checks.

For geometry, assembly, enemy movement or navigation, follow
[level traversal](.agent/workflows/test-level-traversal.md). Verify generated
freshness first; declare levels, seeds, enemies and finite route horizons. Require
crossing the actual route boundary with continuous actor state and real catalog
capabilities. Preserve failing-seed regressions and clear/blocked controls;
never teleport, skip chunks, or silently widen tolerances to obtain a pass.
Diagnose composition, planning and movement separately. Pursuit checks do not
replace spawn, combat, player, camera, performance or full-run coverage.

## Documentation and change hygiene

Follow [the documentation policy](docs/rules/code-documentation-policy.md).
Comments should explain intent, constraints, rationale or non-obvious behavior.
Keep side effects out of widget builds and avoid deprecated Flutter APIs.

- Update TDDs for architecture, contracts, ownership, lifecycle, ordering,
  persistence and security invariants. Update GDDs for mechanics, tuning and
  player-facing behavior. Update both when both change.
- Keep proposed work in `docs/building/`; maintain one checklist per workstream.
  Archive completed/superseded audits and plans under `docs/archive/<date>/`,
  preserve their folder structure, and repair incoming links. Unresolved findings
  remain explicit even when the document is archived.
- Update relevant instructions when boundaries change, README for setup or
  capabilities, and embedding API docs in `lib/runner.dart`,
  `lib/ui/runner_game_widget.dart`, and `lib/ui/runner_game_route.dart` when affected.
- Keep generated files generated. Inspect source and generated diffs together.
- Make small, coherent commits after independently validated milestones. Stage
  only the task's changes, review the staged diff, and preserve unrelated staged
  work. Do not commit failures, incomplete migrations or transient output.
- Before finishing, review the full task diff for correctness, unnecessary
  abstractions, stale references and missing consumers. Report limitations honestly.

## Release boundary

Use [the release workflow](.agent/workflows/deploy-release.md) and
[deployment contract](docs/tdd/deployment_workflow.md).
Android defaults to dev in every build mode. Staging/prod require explicit
release flavors, separate signing and Play-delivered acceptance. Freeze one
candidate for staging and production; keep artifact identity and unavailable
device/review checks explicit. Preserve per-environment mutation locks and the
source-bound maintenance record across interrupted cutovers.
`tools/release/release.ps1` is the entry point; default `Plan` is offline.
Read [release instructions](tools/release/AGENTS.md) before changing tooling.
Select `-Environment dev|staging|prod` for releases; cloud mutations require it.
Keep project baselines, checkpoints, runtime identities and Android configuration
isolated. Only dev has a Hosting target in the current registry.

Prepare source/artifacts before cutover. BuildImage uploads source and starts
Cloud Build; PauseIssuance, Deploy and ResumeIssuance mutate production and
require the user's release authorization. Reuse existing authorization within
its scope. A plan/checklist alone never authorizes deployment, data resets or
run cancellation. Keep `runSessionCreate` excluded from coordinated backend
cutover so issuance stays paused. Scoped releases need a verified baseline and
fresh live checks; shared gameplay/protocol/infrastructure changes retain
coordinated cutover. Historical and mocked evidence cannot establish live state.

## World, brand and assets

For lore, naming, tone, visuals or setting-driven game design, consult the
companion repository `C:\dev\Lothringen\`:

- `Brand/Identity.md` and `Brand/CrossMediaExpressionRules.md`: world pillars and
  runner expression through resource pressure, risk/reward and build adaptation
- `Brand/VisualIdentity.md` and `Brand/VisuelTokens.md`: art, color and typography
- `Brand/Naming&Terminology.md` and `Brand/WorldSnapshot/`: naming and canon

These are creative references, not runtime dependencies or proof of implemented
mechanics. If unavailable, state the limitation and use local references without
inventing canon. `lib/ui/theme/ui_world_palette.dart` implements selected tokens.

Keep reusable level atlases at
`assets/images/level/atlases/<collection>/<sheet>.png`, grouped by visual
collection, and parallax at `assets/images/parallax/<theme>/<sheet>.png`.
Use lowercase snake_case; ordered parallax sheets use `layer_NN.png`. Prefab
and terrain material authoring reuse the canonical atlases.
