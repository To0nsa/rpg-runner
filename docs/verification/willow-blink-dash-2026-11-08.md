# Willow Blink Dash — local verification, 2026-11-08

Implemented against `7f5025a8` plus the task diff, on Windows with Dart 3.13.1.
This is local source validation, not a deployment or phone playtest.

## Delivered behavior

- Separate `bounty_hunter.blink_dash` mobility ability, 4 base stamina and 3s
  cooldown. Horizontal blink on the ground or in the air, with vulnerable
  preparation/recovery and protection only during the invisible phase.
- All nine visible teleport poses are used, including the final pose on the
  second atlas row. Restoring the original transparent fifth frame gives ten
  runtime frames: four preparation, one blank relocation and five recovery.
- Lunge Slash uses the final five-frame blade strip (row 29), with matching
  active strike frames. Pistol, crossbow and shotgun share the mapping.
- Obstacle width is measured from **placed collision polygons**. The largest
  woodcamp tent is 92 units before its chunk scale of 1.5: **138 world units**.
  Other placed tent widths are 96 and 136.5. All 24 placed tent colliders fit.
  The open blink travels 110 units; obstacle approach is at most 32 units, with
  body radius plus 2 units of clearance beyond the far edge.
- A blocked/oversized/distant exit is rejected before costs. Execution rechecks
  clearance and encounter bounds, refunding a newly blocked destination once.
  Interruption/reuse cannot retain a delayed blink. Signed teleport distance is
  counted once toward furthest progress.
- Shared icon/description, backend offers, Admin fixture and local compatibility
  `2026.11.8.2` are aligned. Ranked seeds were regenerated with the owning offline
  helper. Replay/command schemas and terrain/navigation algorithms are unchanged.

See [gameplay](../gdd/combat/abilities/willow.md),
[technical contract](../tdd/willow.md#blink-dash) and
[completed checklist](../archive/2026-11-08/building/willow_blink_dash.md).

## Local checks

Commands run from the repository root unless another directory is listed.

| Check | Result |
| --- | --- |
| `dart test --reporter expanded` in `packages/runner_core` | 2,553 passed, including real woodcamp tent crossings at 30/60/120 Hz, both directions; no repositioning during traversal |
| `dart test test/ecs/world_motion_authority_test.dart --reporter expanded` in Core | 30 passed after adding six further confinement/refund/damage-phase/swap/reuse regressions |
| `flutter test test/core --reporter expanded` | 519 passed |
| `dart test test --reporter expanded` in `services/replay_validator` | 350 passed; all eight ranged variants round-trip Blink Dash and Lunge Slash through recorded inputs |
| `dart analyze` in worker | No issues |
| Targeted analysis of Core, shared presentation, changed renderer/description and render test | No issues |
| `flutter test --no-pub test/game/willow_blink_render_test.dart test/ui/icons/ability_skill_icon_test.dart test/ui/state/firebase_run_session_api_test.dart --reporter expanded` | 12 passed |
| Render test after loading the existing Inter font for the review sheet | 1 passed; blank frame has zero alpha in all three variants |
| `flutter test --no-pub test/admin_controller_test.dart test/local_service_test.dart --reporter expanded` in `tools/admin` | 4 passed using the local fixture service |
| Functions `build` and `build:test` | Passed |
| `node --test lib_test/test/ownership/bounty_hunter.test.js lib_test/test/runs/compatibility.test.js lib_test/test/runs/practice_routes.test.js` in `functions` | 11 passed |
| `node functions/tool/refresh_navigation_routes.mjs` | Local ranked routes regenerated for the new compatibility |
| Admin catalog `--write-fixture`, then `--check-fixture` | Passed; regenerated from compiled Functions |
| `dart run tool/generate_chunk_runtime_data.dart --dry-run` | 88 chunks, three levels/themes/materials validated; no drift |
| `dart run packages/runner_core/tool/update_navigation_revision.dart --check` | Existing fingerprint remains fresh |
| `dart run tool/sync_assets.dart --check` | Asset block is current |

Compiled `bin/server.dart` in the worker to `.tmp/willow_blink_validator.exe`,
then ran `benchmark --ticks=36000 --strict`. All gates passed: Forest 0.793s and
Field 0.605s for 36,000 ticks each, deterministic repeats and sustained progress.
This is the existing generated-terrain/no-combat benchmark, not a device or
container benchmark. [Raw result](assets/willow-blink-benchmark-2026-11-08.json).

The first crossing assertions incorrectly treated snapshot animation clocks as
frame indices; the corrected assertions resolve the existing quantized step.
A first presentation command also named a nonexistent Admin test; the corrected
presentation and actual Admin suites passed independently. Initial compiler/lint
and compatibility fixture issues were corrected before the passes above.

## Visual review and icon provenance

The [rendered review sheet](assets/willow-blink-frames-2026-11-08.png) was visually
inspected. Each family shows all ten blink frames and the five final-strip attack
frames, using the real animation loader and PlayerView. Gameplay tests independently
verify that relocation occurs at the blank frame and recovery completes.

[Final icon](../../assets/images/icons/skills-icons/willow/blink_dash.png) was
generated with the built-in imagegen tool, using Willow's existing Dash icon as
style reference, then exported through System.Drawing nearest-neighbor sampling
at 64x64 while preserving alpha. The bundled icon passes transparent-margin,
unique-path and loading tests. Full-resolution source remains at
`C:/Users/Toonsa/.codex/generated_images/01a1b7c5-63bc-7962-a261-ccb320b5d9d1/exec-d7b8c8a4-e91d-49e7-ad66-b93f558d37e9.png`.

Final icon SHA-256: `9dfe7a80256898f1e0c156c08692f7234825d383ed23598e20f7cf2eb82e6fd6`.

Exact generation prompt:

> Generate one isolated transparent pixel-art game ability icon for Willow's Blink Dash: a grounded dark-cloaked bounty hunter disappearing into charcoal speed wisps and reappearing beyond a small stone obstacle. Muted charcoal, worn brown leather, pale gray highlights and a tiny subdued teal blink accent. Crisp chunky readable pixel art, centered, no border, no text, no background, generous transparent margin. Composition readable as a 64 by 64 game menu icon. Match the restrained dark silhouette and pixel-art clarity of the reference dash icon. Output exactly 64x64 if possible.

No cloud writes, live gifts, run cancellation, release or phone installation were
performed. The compatible client/issuer/worker rollout and device playtesting
remain separate release acceptance work.
