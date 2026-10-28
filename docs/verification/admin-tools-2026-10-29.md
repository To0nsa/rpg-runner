# Admin tools and gift delivery verification — 2026-10-29

## Scope and source

Locally implemented Flutter Windows Admin, shared tool UI/game presentation,
schema-2 item/skill gifts and game inbox support. Tested worktree is based on
`4366f2a6` (the user’s release documentation commits on top of `d562b4eb`) plus
the task changes captured with this record. No deployment, real-player grant,
credential replacement or environment-gate activation occurred.

The [architecture](../tdd/admin_tools.md), [inbox contract](../tdd/system_inbox.md)
and [operator guide](../../tools/admin/README.md) define behavior and rollout.
The native app is repository-backed; the compiled Windows executable still needs
its checkout, Node service and canonical artwork. No portable installer was built.

## Completed local evidence

| Working directory | Command / scope | Result |
| --- | --- | --- |
| Root | `corepack pnpm --dir functions build` and `build:test` | Passed |
| `functions` | `corepack pnpm test` | 282 passed against local demo-project Firestore emulator |
| Root | `node --test tools/admin/service/test/*.test.mjs` | 11 passed, including offline-mode fallthrough prevention |
| Root | `node tools/admin/service/catalog.mjs --check-fixture` | Generated 63-entry backend catalog fixture fresh |
| `tools/admin` | `flutter test --no-pub` | 6 passed; real child service in fixture mode, draft restart/retry, save/receipt rejection, stale catalogs, complete catalog rendering and wide/narrow UI |
| `tools/admin` | `flutter build windows --no-pub` | Release executable built at `build/windows/x64/runner/Release/lothringen_admin.exe` |
| `packages/tool_ui` | `flutter test --no-pub` | 11 shared panel/layout/focus/state tests passed |
| Root | `flutter test --no-pub` with inbox API/AppState/page, icon-coordinate, gear-label, loadout and radial-control targets | 57 passed |
| Root | Final inbox API/AppState/page targets after strict character validation | 25 passed |
| `tools/editor` | Shell shortcuts, entity inspector/save admission, route/plugin switching and terrain-material targets | 30 passed |
| Root | `node tools/admin/service/test/browser_smoke.mjs` | Passed offline; environment selection, escaping, production review, lost response/reload/retry, export/import, native-gift draft refusal, storage failure, mobile layout; no external browser requests |
| Root | `dart analyze` on Admin/shared packages, game UI and changed inbox tests | No issues found |
| `tools/editor` | `dart analyze lib test` | No issues found after Prefab import correction |
| Root | `dart run tool/sync_assets.dart --check` | Asset block current |
| Root | `node tools/agents/check.mjs`, changed Markdown link checks, `git diff --check` | Passed; final archive/link check repeated before commit |

Screenshot inspection used `build/admin-proof/admin-wide.png` (ignored output).
The capture verifies decoded game artwork and actual shared tool layout, using
fixture player/project values. Widget screenshots and Windows compilation are
not a native end-user smoke test against a live project. The code uses the
existing dedicated credential path; auth isolation tests preserve shared ADC.

## Editor regression classification

The first broad run exposed an over-broad Prefab layout import rename, which was
corrected. The corrected focused run passed 105 cases and retained two Chunk
failures; two other errors were nonexistent test paths in the command, corrected
by the 30-case screen check above. Shared primitive tests now live in `tool_ui`.

An isolated worktree at unmodified `4366f2a6` reproduced these four failures:

- `ancient_god_entity_source_test.dart`: Shoggoth scale expected 1.5, actual 1.0.
- `chunk_v2_actor_terrain_projection_test.dart`: actor projection expected false,
  actual true.
- `chunk_authoring_workspace_test.dart`: direct marker expectation 3 vs 2.
- Same file, owner lifecycle: missed rename tap followed by `No element`.

Baseline command: `flutter test --no-pub test/ancient_god_entity_source_test.dart
 test/chunk_v2_actor_terrain_projection_test.dart test/chunk_authoring_workspace_test.dart`
from the baseline editor directory: 33 passed, 4 failed. The baseline's offline
Pub resolution independently required the same existing Firebase/URL-launcher
lockfile updates as the main editor, in addition to this task's new path packages.

Final complete editor command: `flutter test --no-pub` from `tools/editor`:
**880 passed, 2 skipped, 10 failed**. No compilation failures remain. All ten
failures reproduce in the isolated baseline; none are introduced by this task.
The full editor suite is therefore not green, and these existing findings remain
open outside this workstream.

The remaining six baseline failures were reproduced with:

- `flutter test --no-pub test/entity_session_test.dart test/chunk_playtest_editor_integration_test.dart`:
  6 passed, 5 failed. One entity-session expectation and four Play tests fail;
  the latter include the existing Voidborn Goddess sprite frame-28 mismatch and
  cascading lifecycle assertions/timeouts.
- `flutter test --no-pub test/polygon_authoring_legacy_codec_test.dart`:
  3 passed, 1 failed. The codec correctly rejects current source, but the test
  expects `collisionShapes` while the first unsupported field is `bossArena`.

Logs are local ignored files under `build/admin-proof/`: `editor-final.log`,
`editor-baseline.log`, `editor-baseline-integration.log`, `editor-baseline-codec.log`,
`editor-focused.log` and `editor-additional.log`. The temporary baseline worktree
is removed after verification. Its dependency changes and generated output were
never copied into the main worktree.

Final static analysis and all task-specific checks pass. The complete editor
result is retained honestly rather than suppressing or changing unrelated tests.

## Release boundary

Gold-only messaging remains schema 1. New item/skill issuance requires the
explicit compatible-environment gate; missing configuration fails closed.
Existing gift claims and identical delivery retries continue with issuance
turned off. Authorized backend/client rollout, required-update acceptance,
project-specific gate publication and live player smoke are still outstanding
release work, not local implementation evidence. No shared machine ADC was changed.

Context7 was unavailable. Library-specific choices were checked against official
[Flutter package/assets guidance](https://docs.flutter.dev/packages-and-plugins/developing-packages),
[Dart file locking](https://api.dart.dev/dart-io/RandomAccessFile/lock.html),
[process lifecycle](https://api.dart.dev/dart-io/Process/start.html) and
[image stream listeners](https://api.flutter.dev/flutter/painting/ImageStreamListener-class.html).
