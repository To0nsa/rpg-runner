# Campaign combat introduction — local verification

Reporting for Duty revision **47** adds **Projectiles and sword** after Dash,
bound to the existing guaranteed Grojib marker in `mission_chunk_10`, salt **1**.
The enemy page leads to a Projectile press; its real launch locks further shots.
Movement, Jump and Dash remain available. The enemy's real stationary melee
opportunity opens the Sword page. A fresh Sword press performs the normal strike;
its real execution unlocks Projectile. A dimmed button and bilingual practice hint
explain the temporary lock. No artificial cooldown or enemy tuning is introduced.

## Source and review

- Source comparison against the task-start snapshot proves revision **46 → 47**
  and exactly one appended tutorial. All other missions, markers, objectives,
  route and geometry match. Generated campaign terrain is byte-identical.
- Campaign digest:
  `ec5c0b40d24d3b5d1cd209e84dfe7499deab115ab0424816f055ccc870a93be6`.
  Authored catalog SHA-256:
  `0f06d78f1aa7d3202ece18b28733e71d8ce9a66ca685b6185f1ec9dad7e43e2a`.
- The generator also synchronizes the previously authored Grojib into the Core
  catalog. UI and Functions metadata carry the same revision and content digest.
- Core owns marker identity, current blade/body overlap and projectile reach with
  terrain sightline. Optional execution callbacks add feedback only; gameplay
  commands, ordering, costs, damage, cooldowns, AI and settlement are unchanged.
- Presentation owns guidance and cross-device input admission. Actual attack
  execution is observed before the completed-tick snapshot is published to the
  tutorial. Missing/dead targets release both controls; alternate attack pairs
  preserve their build and skip the starting Éloïse-specific instructions.
- Editor authoring reuses the shared three-page form, language tabs, spotlight
  geometry, terrain-resolved actor preview and normal revision-guarded Save,
  Undo/Redo and frozen Play paths. There is one combat creation action.
- Earlier tutorial work and unrelated edits remain untouched. The task baseline
  and review are in ignored `build/combat_tutorial_baseline/` and
  `build/combat_review.diff`. This change depends on the uncommitted tutorial
  framework, so it remains uncommitted with that work.

## Focused checks

All checks are local. `flutter` below is the installed SDK's
`dart.exe flutter_tools.snapshot` entry point; `dart` is the same SDK's Dart.
Counts describe each command, with overlapping tests intentionally not summed.

| Working directory | Command / selection | Result |
| --- | --- | --- |
| `packages/runner_content_pipeline` | `dart test test/campaign_combat_tutorial_test.dart test/campaign_mobility_tutorial_test.dart test/campaign_tutorial_test.dart test/campaign_source_test.dart --reporter expanded` | 25 passing: strict schema, mandatory reveals, marker validation, authored ordering and existing source contracts |
| `packages/runner_core` | `dart test test/campaign/combat_opportunity_test.dart test/campaign/campaign_enemy_runtime_test.dart --reporter expanded` | 16 passing: read-only geometry, sightline/lifetime controls, actual enemy activation/return and deterministic commands at 30/60/90 Hz |
| Root | `flutter test --no-pub test/ui/controls/runner_controls_overlay_radial_test.dart test/game/input/runner_semantic_action_dispatcher_test.dart test/ui/tutorial/campaign_combat_tutorial_test.dart --concurrency=1 --reporter expanded` | 52 passing before the additional visibility regression: action modes, control admission, cancellation and four combat policy fixtures |
| Root | `flutter test --no-pub test/playtest/runner_chunk_playtest_host_test.dart test/ui/tutorial/campaign_combat_tutorial_test.dart test/ui/tutorial/movement_tutorial_overlay_test.dart --name 'combat after dash\|real delivery\|dead target\|unready projectile\|French' --concurrency=1 --reporter expanded` | 19 passing: four real host variants, four policy fixtures and eleven French card cases, including compact display and enlarged text |
| Root | `flutter test --no-pub test/playtest/runner_chunk_playtest_host_test.dart test/ui/tutorial/campaign_combat_tutorial_test.dart --name 'combat after dash\|real delivery\|dead target\|unready projectile\|enemy body' --concurrency=1 --reporter expanded` | 9 passing: all four viewport-aware real encounters plus five policy fixtures; see `build/combat_visibility_test.log` |
| `tools/editor` | `flutter test --no-pub test/campaign_tutorial_dialog_test.dart test/campaign_authoring_test.dart --name 'combat authors\|tutorial edits\|three-step\|blessing\|dash authors' --concurrency=1 --reporter expanded` | 6 passing: shared forms and Save/Undo/Redo/frozen Play |
| `tools/editor` | Same two files with `--name 'combat authors\|tutorial edits'` | 2 passing after adding the actor preview wrapper |

Scoped root/editor analysis, generator freshness, English/French localization and
Functions compilation pass. Commands: `dart analyze <task paths>`, `dart run
tool/generate_chunk_runtime_data.dart --dry-run`, `dart run tool/localization.dart
check`, and `corepack pnpm --dir functions build`. The Functions build required
normal elevated filesystem access to replace existing local output. No deployment
or backend mutation occurred. Logs are retained as `build/combat_*.log`.

## Real encounter and review refinements

The host tests use seed **42**, catalog Éloïse at 60 Hz and the authored Reporting
for Duty route. They start from the mission spawn, complete every preceding
lesson, cross the eighth/ninth downhill boundary after Dash and continue into the
tenth-chunk Grojib encounter with continuous actor state and finite walk budgets.
There is no teleportation, skipped chunk, modified terrain or relaxed tolerance.

Arrows, floating joystick, fixed joystick and HUD-free keyboard all exercise real
attacks. A pre-held K cannot dismiss the Projectile page. A fresh attack spends
mana. Repeated touch/keyboard attempts cannot launch another shot during practice.
Sword remains hidden until its lesson, then a fresh press spends stamina and
produces a real landed-hit event. Player health remains full through that strike.
After recovery another Projectile spends mana, proving the lock was released.
Restart resets the lessons, hidden controls and mission progress.

Two findings were corrected and retained as regressions:

- Showing Sword at the outer reach edge while the enemy was moving could make
  homing predict past the enemy's imminent AI stop. Waiting for the actual stop
  lets the first strike land without changing AI or attack timing.
- Checking the camera canvas alone admitted a clipped enemy in a cover-scaled
  device preview. The mounted shared gameplay surface now lends a resolver for
  the actual visible world rectangle. The full body and authored opening must fit.
  The resolver is rebound on attempt replacement and detached on unmount; the
  host regression asserts the spotlight against the device's visible world bounds.

Reviewed widget-rendered images in `build/test/`: `combat_enemy_tutorial.png`,
`combat_projectile_tutorial.png` and `combat_sword_tutorial.png`. Cards are legible;
the enemy is inside the device crop and attack spotlights follow the real controls.
Policy fixtures cover interrupted execution, resource/readiness gates, early death,
unsupported abilities and listener cleanup; they are distinct from traversal proof.

## Windows artifact and limits

`flutter build windows --release --no-pub` from `tools/editor` succeeded in
**105.1 seconds** after the final viewport correction. All **2433** captured source
hashes and the final inventory match. Earlier builds were superseded during visual
review; the final artifact is the one verified here. The editor was closed for
replacement and was not launched for native visual acceptance.

Executable: `tools/editor/build/windows/x64/runner/Release/runner_editor.exe`.
Payload `data/app.so`: **17,187,720 bytes**, SHA-256
`d08ffc6ced9937eafd37d211ad5b37a0ca47305e482347fb1a7106a860ba7b8f`.
Source/artifact manifests: `build/combat_windows_sources.json` and
`build/combat_windows_artifact.json`.

Native visual acceptance, a phone/ruler calibration check, full-mission completion,
performance benchmarking and backend deployment are not claimed. The tutorial
currently teaches the starting Snap Shot/Seeker Slash pair; other builds are safely
released rather than given incompatible gesture instructions.
