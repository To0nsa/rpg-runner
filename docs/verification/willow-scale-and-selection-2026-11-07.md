# Willow scale and character selection — November 7, 2026

Source: `f70d0c7f` plus the scale and chooser changes committed with this report.
Checks ran locally on Windows with Flutter 3.47.1 / Dart 3.13.1. Existing unrelated
edits to `.gitignore`, `AGENTS.md` and `README.md` are outside this work.

## Result

Willow's native artwork now uses scale 1.35, with the `(34,47)` pivot and world
collider bottom at 22.95. The canvas support line at y=64 lands on that bottom.
Éloïse retains scale 0.75. Live players, ghosts and menu previews consume each
character definition's scale. Combat capsules and cast origin follow Willow's
larger body. The Entities editor retains guarded source bindings for defaults
and explicit scale constants.

The chooser fits two cards without scrolling. Card taps persist selection in
place; `Change build` selects and opens that character's remembered loadout.
Subtitles, descriptions, introductory copy and the current-character sentence
are removed. Unselected art uses the level cards' shared 60% dark scrim while
names and build buttons remain readable.

## Checks

Commands below use `flutter test --no-pub --no-version-check --reporter expanded`
unless a different runner is stated. Paths are relative to the listed directory.

| Directory | Command / targets | Result |
| --- | --- | --- |
| `packages/runner_core` | `dart test test/combat/bounty_hunter_test.dart --reporter expanded` | 71 passed, including real melee hits at 30/60/120 Hz |
| `services/replay_validator` | `dart test test/bounty_hunter_replay_test.dart --reporter expanded` | 3 passed: recorded movement, melee, shots and bombs for each gun |
| Root | `test/game/player_scale_render_test.dart`, `test/ui/player_idle_preview_scale_test.dart`, `test/ui/pages/select_character/character_selection_page_test.dart`, `test/ui/pages/select_character/loadout_setup_page_phase4_test.dart`, `test/game/runner_flame_game_ghost_layer_test.dart` | Initial run: 22 passed, 2 fixture assertions corrected as explained below |
| Root | `test/game/player_scale_render_test.dart test/ui/pages/select_character/loadout_setup_page_phase4_test.dart --name 'idle reference height\|selected character scale'` | 3 passed after those corrections; captures reviewed |
| Root | `test/game/shoggoth_attack_height_render_test.dart` | 1 passed with the definition-owned player scale |
| `tools/editor` | `test/entity_parser_export_test.dart test/entity_session_test.dart test/willow_projectile_source_test.dart` | 27 passed after fixture corrections |
| Root | `test/ui/pages/select_character/character_selection_page_test.dart test/ui/pages/select_level/level_setup_page_test.dart` | 7 passed for the new chooser and existing level selection |
| Root | `test/ui/pages/select_character/character_selection_page_test.dart` | Final overlay/capture adjustment: 4 passed at 1200×720, 800×450, 800×360 and 568×320 |
| Root | `dart analyze` on changed renderer, UI, player, combat and capture-test paths | No issues |
| `tools/editor` | `dart analyze` on changed parser and three editor tests | No issues |
| Root | `dart run tool/generate_chunk_runtime_data.dart --dry-run` | No blocking issues: 88 chunks, 3 levels, 3 parallax themes and 3 terrain materials |
| `packages/runner_core` | `dart run tool/update_navigation_revision.dart --check` | Current: `bd2274e0b71f13d538e131be959817d040eb11182da317b2db98903ed26a1e98` |

The first raster comparison counted weapons above Willow's head and mixed
different idle bob phases. The final test compares the reference body pose
within one world unit and checks every idle frame's feet within one raster pixel
at 4× zoom, for all three guns. Menu tests compare both characters at 88 and
120 widget units. The Training Field scale assertion uses a 1e-6 tolerance for
Flame's Float32 vector storage.

Combat fixtures use the real player catalog and a target inside all three
scaled melee sweeps. The editor fixture now supplies render metadata; an old
enemy-path expectation was corrected to the existing `catalog/unoco_enemy.dart`
owner and normalized for Windows. These corrections do not loosen source-drift
or export safety checks.

## Screenshots and phone

Local captures are kept under ignored `.tmp/`:

- `willow_scale_grounded.png`: Éloïse and Willow's three weapons at the same
  world zoom, with the common floor drawn explicitly.
- `willow_scale_training_eloise.png` and `willow_scale_training_bountyHunter.png`:
  actual Training Field renderer at the same 1200×540 viewport. Some HUD text
  retains test-font rendering; character and terrain pixels use real assets.
- `willow_selection_<width>x<height>.png`: final compact chooser at all four
  sizes, with application fonts and background loaded before capture.
- `willow_scale_phone_selection.png`: the scale fix on the connected CPH2465,
  before the subsequent compact chooser change.
- `willow_scale_phone_run.png`: passive capture of Willow during a phone run;
  this airborne frame is not evidence of grounded foot placement.

The user's terminal launched
`flutter run -d 8ce90820 --flavor dev --debug --dart-define=DEVELOPER_PRACTICE=true`
from the repository root. ADB confirmed dev package update at 20:48:56 local
time. The installed scale-fix APK SHA-256 was
`031B270055C928DE0D3BAD2FE73C37B47F7D70CB7FE1CDB6B7C9A42E5A9545D0`.
That APK predates the compact chooser. Its source changes are ready for hot
restart in the still-running user terminal; no second build or restart was
forced while the user played. There was no backend deployment or remote reset.
