# Éloïse WIP retirement — local verification

Source: `f267ba0a` plus the retirement change. Checks were local on November 11,
2026 (Dart 3.13.1, Node 24.22.1); Firestore used the demo-project emulator.
No deployment, account reset, gift activation or run cancellation was performed.

The runtime enum/registry, starter profiles and Admin catalog now contain only
Éloïse and Willow. Old saved selections restore Éloïse; earned skills merge once
without overwriting current builds/equipment or changing currency/progression.
Normal canonical saves remove obsolete character branches. Retained gifts and
delivery receipts keep their original identities/hashes and credit Éloïse;
new gifts and ownership commands for the removed identity are rejected.
See the [retirement contract](../tdd/character_builds.md#character-retirement).

## Checks

| Directory | Command / scope | Result |
| --- | --- | --- |
| Root | `corepack pnpm --dir functions build` and `build:test` | Passed |
| `functions` | `UPDATE_RUN_COMPLETION_FIXTURE=true`, then `corepack pnpm exec firebase emulators:exec --config ../firebase.test.json --project demo-rpg-runner-functions-tests --only firestore "node --test lib_test/test/ownership/*.test.js lib_test/test/inbox/*.test.js lib_test/test/runs/run_projection.test.js"` | 193 passed; producer regenerated the receipt fixture |
| Root | `dart analyze packages/runner_core`, `dart analyze packages/game_presentation`, `dart analyze lib` | No issues |
| `services/replay_validator` | `dart analyze`; `dart compile exe bin/server.dart -o ../../.tmp/eloise-removal-validator.exe` | Passed |
| Root | `dart run packages/runner_core/tool/update_navigation_revision.dart --check` | Passed; fingerprint unchanged |
| Root | `node tools/admin/service/catalog.mjs --write-fixture`, then `--check-fixture` | Generated catalog removes the retired recipient and updates its hash |
| Root | `node --test tools/admin/service/test/*.test.mjs` | 12 passed |
| `tools/admin` | `flutter test` | 7 passed, including backend catalog rendering and durable delivery retry |

Core ran `dart test` for `test/players/character_retirement_test.dart`,
`test/ecs/world_contact_capsule_store_test.dart`,
`test/terrain_game_core_harness_test.dart`,
`test/terrain_player_edge_landing_test.dart`,
`test/collision/terrain/terrain_player_signatures_test.dart` and `test/bosses`.
There were 1,194 passing cases plus one failed exploratory Willow case described
below. After removing that added case, the affected
`test/bosses/forest_boss_sequence_test.dart` rerun passed all four cases. No
production geometry, movement, boss tuning or signature goldens changed.

Root Flutter checks covered selection persistence, canonical loadouts, hybrid
sync, inbox decoding, the producer-generated run receipt, level setup, character
selection and meta normalization. The first run passed 79 cases and exposed
a character-name mapping error in five cases. Correcting that mapping and
rerunning `test/ui/state/firebase_inbox_api_test.dart` and
`test/ui/pages/select_character/character_selection_page_test.dart` passed all
nine cases, including old-gift serialization and distinct old/current gift keys.

Worker tests covered `test/boss_victory_blessing_replay_test.dart`,
`test/shoggoth_close_range_replay_test.dart` and `test/validator_worker_test.dart`.
The run passed 114 cases, skipped the existing optional `CAMPAIGN_REPLAY_FIXTURE`
case and failed one exploratory Willow case below. The final Éloïse-only
close-range file passed its three 30/60/90 Hz cases. The campaign fixture, device
acceptance and a release-image throughput benchmark were not run.

## Scope of the old combat scripts

Most duplicate-character tests now exercise Willow's actual catalog and capsule.
Two scripts originally authored for Éloïse and her identical WIP copy remain
Éloïse-specific. Extending them mechanically to Willow produced different
outcomes: the compressed Forest seed-7 boss sequence fell at tick 2,807 during
the Goddess encounter, and Shoggoth's 60 Hz point-blank script did not observe
the expected retaliatory impact. These exploratory cases were not retained as
claims of Willow acceptance. Their original Éloïse assertions remain intact;
no tolerance, movement or gameplay change was made to force them to pass.

Rollout still requires matching client/Functions/worker artifacts, draining old
retired-character tickets and renewed gift-catalog activation evidence.
