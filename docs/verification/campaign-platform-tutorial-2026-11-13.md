# Campaign platform tutorial verification — 2026-11-13

Local source: Reporting for Duty revision 41, content digest
`fc967204b2a45be3ff88297edf844ca46446fd2caaad2951f9ec9839a5a70a22`.
The task baseline was captured before edits to preserve the existing dirty
checkout. Authored JSON changes by exactly one platform lesson and one revision
increment. Generated Core changes only its digest; UI/Functions also gain the
lesson and revision. Terrain, physics, navigation and replay commands are unchanged.

## Behavior and checks

The lesson targets the first unique one-way platform in `mission_chunk_4`, prefab
`tiny_swords_ground_platform_04_64x32_platform`. Its visual bounds are world
X 1960–2024, Y 160–192; collision ends at X 2022. The 64-unit approach pauses on
safe ground at X 1896–1901. Fresh movement dismisses the explanation and continues
walking; Jump cannot dismiss it. No HUD elements are revealed by default.

All 48 targeted tests passed locally:

| Directory | Command | Result |
| --- | --- | --- |
| `packages/runner_content_pipeline` | `dart test test/campaign_platform_tutorial_test.dart test/campaign_decoration_tutorial_test.dart test/campaign_gap_tutorial_test.dart test/campaign_source_test.dart --reporter expanded` | 28: strict bilingual schema, multi-piece target bounds, move/scale/reorder, missing/duplicate/solid targets, disabled-reference validation and existing source regression |
| Root | `flutter test test/ui/tutorial/campaign_tutorial_controller_test.dart --no-pub --reporter expanded` | 4: continuous route through all three platforms, grounded explanation, upward passage/descending support, early bypass and existing dry-gap fall control |
| Root | `flutter test test/playtest/runner_chunk_playtest_host_test.dart --plain-name 'ordered tutorials' --no-pub --reporter expanded` | 4: arrows, floating joystick, fixed joystick and hidden-HUD keyboard, fresh input, pause, real platform landing and restart |
| `tools/editor` | `flutter test test/campaign_water_tutorial_dialog_test.dart test/campaign_authoring_test.dart --name 'platform\|gap\|water\|decoration\|swimming\|[Tt]utorial' --no-pub --reporter expanded` | 12: bilingual card, approach validation, manual spotlight, missing target, Cancel, actual tab target selection, Apply/Undo, Save/reopen and captured Play |

Logs are under `build/platform_{pipeline,controller,host,editor}_tests.log`.
The controller uses seed 42 and catalog Éloïse, starting at the authored spawn
with continuous actor state and ordinary input. Finite per-segment budgets cover
the first four chunks. The route walks beneath the first platform, jumps through
its underside, and lands on the three real raised surfaces at Y 160, 112 and 128.
Assertions check actual support-edge identity and height. Exit crosses the real
fourth-chunk boundary at X ≥2400 and lands grounded. An alternate 20-unit warning
and an earlier jump cover airborne bypass without a midair or late popup.

Focused root and editor analysis pass. Final edits after behavior checks only
added lint-required braces, formatting and a test helper rename; no behavior changed.
`dart run tool/generate_chunk_runtime_data.dart --dry-run` validates 166 chunks and
current outputs. `dart run tool/localization.dart check` passes for English/French.
`corepack pnpm --dir functions build` passes. Existing navigation evidence is reused
because geometry, navigation inputs and algorithms are unchanged.

Reviewed `build/test/platform_tutorial.png`: the grounded player stops before the
first platform; the ellipse includes its upper surface, the card is readable, and
the grey veil and previously introduced HUD fit the mobile preview. This is a
widget screenshot, not a native executable or physical device check.

Development failures were resolved without tuning gameplay: the first landing
assertion used an arbitrary horizontal bound that ignored normal inertia; it now
checks the actual compiled support edge and exact height. Visual width includes
two units of padding beyond collision, so the target test now asserts both bounds.
The current platform emits one sprite; a separate multi-piece fixture verifies
the shared target union. Duplicate/moved source fixtures respect canonical order.

## Windows artifact and limits

`flutter build windows --release --no-pub` from `tools/editor` succeeded in
175.8 seconds. A concurrent change to the shared `ui_hub_theme.dart` was preserved;
the build-source capture was refreshed and a final build succeeded in 114.9 seconds.
Source hashes stayed unchanged through that final build. Ready executable:
`tools/editor/build/windows/x64/runner/Release/runner_editor.exe`.
Its `data/app.so` is 17,023,880 bytes with SHA-256
`4c5422111d2895cd7fefe0c124eda4afc3bc42a598353d427279d87442733da3`.
The payload contains the platform lesson and trigger. Local provenance is recorded
in `build/platform_windows_artifact.json`; scoped whitespace and documentation
link checks pass. No native executable launch is claimed.

No backend deployment, live backend call, phone test or physical ruler calibration
is part of this change. Traversal covers one character/seed and no enemies; it is
not full-mission or performance acceptance. Platform targets intentionally require
a unique placed one-way prefab with an exposed top and non-decoration visuals.
The task remains uncommitted alongside its pre-existing uncommitted dependencies.
