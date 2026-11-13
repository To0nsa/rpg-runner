# Campaign Journal verification — November 13, 2026

Source: the uncommitted working tree in `C:/dev/Lothringen/long-run`, including
the pre-existing campaign/editor work. An ignored task baseline was captured
before editing. No commits, deployments, cloud writes or account migrations
were performed for this feature.

## Delivered behavior

- Optional English/French `journal` title/body at campaign, chapter and mission
  scope, with strict validation and deterministic round-trip/build projection.
- Campaign opening, chapter introduction and mission completion forms use the
  existing guarded plugin commands, Save/reopen, Undo/Redo and source-drift checks.
  Mission local drafts also join Apply/Reset and navigation/Play resolution.
- A read-only preview after any selected mission (or opening only) includes
  authored drafts through that point. Both languages use the shared visibility
  and ordering policy.
- Library derives visible published updates from confirmed mission clears.
  Failed/pending attempts, replays and excluded drafts do not append entries.
  Restored progress, account reset, locale switching and compact enlarged text
  are covered by widget regressions.
- The opening follows the user’s post–Le feu de joie continuity: survivors in
  Théodonis, Éloïse called to Val, apparently different cultists, an unproven link.
  Later draft mission prose records only the stated assignment outcomes.

Source comparison against the starting catalog confirms unchanged campaign
map/title, stable mission IDs, geometry, objectives, inclusion and rewards.
Only Journal metadata, chapter description and catalog/mission revisions changed.
Draft mission Journal titles/bodies are omitted from generated game/server data.
The existing shared content digest changes with authored prose; ordinary release
compatibility gates still apply before any future deployment.

## Local verification

| Working directory | Command or check | Result |
| --- | --- | --- |
| Root | `flutter pub get --enforce-lockfile` | Passed; lockfile unchanged |
| `tools/editor` | `flutter pub get --enforce-lockfile` | Passed; lockfile unchanged |
| `packages/runner_content_pipeline` | `dart test test/campaign_journal_test.dart test/campaign_source_test.dart test/campaign_settings_source_test.dart` | 20 passed |
| `tools/editor` | `flutter test --no-pub test/campaign_journal_fields_test.dart test/campaign_settings_test.dart test/campaign_chapter_dialog_test.dart` | 11 passed |
| `tools/editor` | `flutter test --no-pub test/campaign_authoring_test.dart --name 'inline mission settings\|campaign workspace exposes editable'` | 2 passed |
| Root | `flutter test --no-pub test/ui/pages/meta/campaign_journal_test.dart test/ui/pages/meta/codex_library_test.dart --name 'Journal\|map dialog\|settled Open entries\|locations show\|location map markers'` | 9 passed |
| Root | `flutter test --no-pub test/tool/generate_chunk_runtime_data_test.dart --name 'campaign generates a trusted finite registry'` | 1 passed, including real trusted replay at 30/120 Hz and both metadata projections |
| Root | `dart run tool/generate_chunk_runtime_data.dart --dry-run` | Passed: 166 chunks, 3 levels, 3 themes and 3 terrain materials; no blocking issues |
| Root | `corepack pnpm --dir functions build` | Passed against the final generated catalog |
| Root | `dart run tool/localization.dart check` | Final check passed (en, fr), including generated freshness and no added exemptions |
| Root/editor | Targeted `dart analyze` over changed implementation/tests | Final passes: no issues found |
| `tools/editor` | `flutter build windows --release --no-pub` | Passed in 298.7 seconds; produced `build/windows/x64/runner/Release/runner_editor.exe` |
| Root | Scoped `git diff --check` and documentation link validation | Passed |

The 43 focused tests are local automated evidence. The full game/editor suites,
physical-device acceptance and live backend acceptance were not run. No native
interactive smoke test has been claimed.

Initial editor test failures came from scrolling/focus assumptions in forms that
grew a Journal section. The tests now scroll explicitly, and the normal map and
mission settings remain ahead of the Journal fields. Final reruns passed. A new
unnecessary PageStorage string was removed after the localization gate flagged it;
no source-text exemptions were added.

## Initial Val entry follow-up

The chapter introduction originally contained only the cultist-investigation
setup, omitting the Library’s initial location description. Restored that complete
English/French description before the setup: tents, Théo’s guards, Hanna, the
bugbear threat, message relay and traveler refuge. The campaign opening and all
mission outcomes remain unchanged. Catalog revision advances from 13 to 14.

A regression reproduced the missing passage against the original chapter body.
The editor regression checks the complete location text precedes every Val
mission update in both languages; the Library regression checks the generated
chapter retains it before and after a confirmed clear.

Follow-up checks on the corrected revision-14 source:

| Working directory | Command | Result |
| --- | --- | --- |
| `tools/editor` | `flutter test --no-pub test/campaign_journal_fields_test.dart` | 4 passed, including all four mission checkpoints in English and French |
| Root | `flutter test --no-pub test/ui/pages/meta/campaign_journal_test.dart` | 3 passed |
| Root | `dart run tool/generate_chunk_runtime_data.dart --dry-run` | Passed; regenerated catalogs are fresh |
| `tools/editor` | `dart analyze test/campaign_journal_fields_test.dart` | No issues found |
| Root | `dart analyze test/ui/pages/meta/campaign_journal_test.dart` | No issues found |

The generated campaign digest is
`c6424b7e3e49c468275f1990c0cac1efa4385743721ee132c4ce6f80d3a71f52`.

Native UI inspection was unavailable because the computer-use service could
not connect to its native pipe. The editor reads this content from repository
source; its already-built application code has not changed. Reload Campaign to
refresh an already-open document.

## Entry ordering follow-up

Catalog revision 15 orders the authored entries as **Val Outpost**, **After Le feu
de joie**, then mission outcomes. The spoiler-free location description is now
the campaign opening; the post-fire narrative and investigation setup are the
Val chapter introduction. Every existing English/French paragraph is retained.
No projection policy, mission, account progress or gameplay data changed.

The ordering regression failed against revision 14 because Val Outpost was below
the campaign opening. Editor and Library assertions now check the explicit
English/French titles and their visual order, as well as the intact location text.

Repeated the editor and Library commands listed above against revision 15: all
4 editor tests and 3 Library tests passed. Generated freshness passed. The shared
campaign digest is now
`5153719e01a6250abd265112a1610649d80afbe0bf8448e0dfb57616cf0aebff`.
This source-only change needs Campaign Reload in an open editor, with no native
application rebuild.
