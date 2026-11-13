# Equipment and Training town services

Requested November 10, 2026: implement the permanent catalogue proposal, deploy
the backend to dev, and build a matching dev Android APK.

## Scope and acceptance

- Two town entrances, Equipment and Training, with shared navigation/presentation.
- Browse either unlocked character without changing run selection or saved builds.
- Permanent server-priced catalogues; 150 gold per unlock, no paid refreshes.
- Equipment includes ranged sources and shared accessories; Training contains
  ability-slot techniques. Training's owned entries remain inspectable; Equipment
  hides owned entries entirely. Shared ownership
  cannot be purchased twice. Equipment shows only the selected item's own stats.
- Preserve confirmed-funds checks, compatibility, auth, revisions and idempotency.
- Keep English/French localization, compact/large-text layouts and accessible controls.
- Preserve retained profiles and legacy purchase requests. No gameplay or data reset.

The starting worktree contains the completed, uncommitted localization work and
other documentation/inbox/Admin changes. Preserve them. Initial status, diff and
task-relevant source copies are in ignored `.tmp/town-services/` for comparison.
They are not authorization for unrelated implementation. The release must freeze
the actual source and record all included work without altering unrelated staging.

## Compact Equipment follow-up — November 13, 2026

- [x] Replace Equipment cards with category rail, details pane, compact item
  grid and one purchase action; remove the service switch/introduction.
- [x] Reuse picker presentation and preserve the builder's browsing context.
- [x] Apply the compact-layout revisions: selected-item stats only, owned entries
  hidden entirely, no Show owned control, and a centered purchase action.
- [x] Remove the shared-accessory sentence; reuse the themed segmented character
  control and lock Willow's catalogue until her existing Campaign unlock.
- [x] Verify purchases, owned inspection, ranged sources, compact/French layouts
  and builder navigation; inspect real Flutter renders and the task diff.

This follow-up changes client presentation only. The existing worktree contains
unrelated Campaign/runtime/editor work and localization changes; preserve them.
No new backend deployment or Android build is authorized by this UI request.

Local checks for the uncommitted UI follow-up, run from the game root:

- `flutter test test/ui/pages/meta/town_page_test.dart --no-pub
  --dart-define=CAPTURE_TOWN_SERVICES=true --reporter expanded`: 17 passed.
- `flutter test test/ui/pages/select_character/loadout_setup_page_phase4_test.dart
  test/ui/pages/select_character/gear_stats_presenter_test.dart
  test/ui/pages/meta/codex_library_test.dart --no-pub --reporter expanded`:
  51 passed, including the builder shortcut and Town back stacks.
- Targeted `dart analyze` covered changed UI, routes and tests; final incremental
  checks of the workspace/page/tests and page/details widgets report no issues.
- `dart run tool/localization.dart check`: passed for English/French. After the
  last layout-only changes, `dart run tool/localization.dart audit` also passed.
- Inspected actual Flutter captures at 844×390 (English), 640×360 (Willow ranged
  equipment), and 320×640/640×360 (French, 180% text). Captures and check logs are
  in ignored `.tmp/design-proposals/`. `git diff --check` passes for task files.

These are local widget/render checks. The existing device end-to-end acceptance
and economy review below remain outstanding.

An intermediate compactness revision removed Equipment comparisons and the
ownership-filter control, always includes owned entries, and centers Buy in the
details pane. Its updated Town suite passes 17/17; targeted page/workspace/details
and test analysis reports no issues. Fresh English/ranged/French captures were
inspected in the same ignored preview directory. Revision-specific logs use the
`equipment-simplified-*` prefix. The broader 51-test result above predates this
revision; the shared builder picker was not changed by it.

The latest Equipment revision hides owned entries entirely. A purchase removes
its tile and selects the first remaining item, or clears details and Buy when
the category is empty. It also removes the Equipment-only owned markers/status
presentation. Training ownership browsing and the builder picker retain their
existing behavior. Focused revision logs use `equipment-unowned-only-*`:
18 Town widget tests pass, targeted analysis reports no issues, and the fresh
English capture was inspected. The checks include removal after
purchase, selection of the next item, an empty category and shared ownership.

The character-selector refinement removes the accessory sentence and its EN/FR
resources. Town now uses the shared gold segmented control and label typography;
Willow stays disabled until `AppState.isCharacterUnlocked` permits her. Direct
entry, live availability changes and retained purchase callbacks also respect
that availability. The existing developer-mode override is retained. Revision
logs use `equipment-selector-*` in the same ignored preview directory:

- `flutter test test/ui/pages/meta/town_page_test.dart
  test/ui/pages/options/options_page_test.dart
  test/ui/pages/leaderboards/leaderboards_page_test.dart --no-pub
  --dart-define=CAPTURE_TOWN_SERVICES=true --reporter expanded`: 25 passed
  (22 Town tests and 3 shared-control consumer tests).
- Targeted analysis of the shared control, Town page/workspace/details and Town
  tests reports no issues. `dart run tool/localization.dart check` passes for
  English/French, including generated-resource freshness.
- Fresh Flutter captures confirm readable game typography, the disabled Willow
  state and French 180% text without overflow at 320×640 and 640×360.

## Compact Training Hall follow-up — November 13, 2026

- [x] Share Equipment's responsive category rail, details panel, item grid and
  centered price action through `TownStoreWorkspace`.
- [x] Keep All categories and learned techniques visible; show learned technique
  checks and inspectable details with no duplicate purchase action.
- [x] Localize the price-bearing Learn action and its accessible gold label in
  English/French. Preserve character/build selection and purchase verification.
- [x] Verify selection, ownership refresh, in-flight controls and compact/French
  enlarged-text layouts; inspect Flutter captures and the task diff.

Local verification of the uncommitted Training Hall changes, from the game root:

- `flutter test test/ui/pages/meta/town_page_test.dart --no-pub
  --dart-define=CAPTURE_TOWN_SERVICES=true --reporter expanded`: 26 passed,
  covering both services, learned inspection, category filtering, server prices, pinned
  recipients, locked controls and ownership refresh without equipping.
- `dart analyze lib/ui/pages/town`: no issues.
- `dart run tool/localization.dart generate` and
  `dart run tool/localization.dart check`: passed for English/French, including
  the generated price-bearing Learn action and accessible currency label.
- Inspected Flutter captures of the full Training catalogue at 844×390,
  learned inspection at 800×600, and French 180% text at 320×640 and 640×360.
  Captures are under ignored `.tmp/design-proposals/equipment-implementation/`;
  task-only starting copies are in `.tmp/training-hall-redesign-baseline/`.
  The task diff has no whitespace errors.

These checks use local widgets and a scripted ownership API. Native-device,
live-backend and economy acceptance remain separate.

The requested filter refinement removes Not yet unlocked and its route-local
state. Learned techniques always remain visible and selected after purchase.
The refined Town suite passes all 26 tests, Town analysis reports no issues,
and the fresh Training capture confirms the filter is absent.

## Milestones

- [x] Implement catalogue and explicit purchase target across backend/client.
- [x] Add services, character/category browsing, ownership and comparisons.
- [x] Verify backend boundaries and client/widget/localization behavior.
- [x] Update implemented GDD/TDD and review task-only diff.
- [x] Freeze source; Plan/Prepare the dev release with reusable evidence.
- [x] Deploy authorized dev backend scope and verify live state.
- [x] Build/inspect matching dev Android APK and record artifact identity.

Owners: `functions/src/ownership`, `lib/ui/state`, `lib/ui/pages/town`, app routes,
app localization, focused Functions/Flutter tests and documentation. Town services
do not change Core simulation or replay wire schemas. Release scope was decided
by the canonical release tool against the verified dev baseline.

Optional future rotating discounts are outside this initial catalogue release.
The current price is a baseline; economy/playtesting is not implied by unit tests.

## Local evidence and release candidate

Functions build and 112 ownership tests passed against the Firestore emulator.
The focused catalogue/state tests (17) and map/Library tests (14) pass, including
explicit recipient retries, shared ownership, protected provisional funds and
French enlarged text. Localization checks pass for English/French. Rendered
catalogue previews and command logs are in `.tmp/town-services/`.

Offline release Plan selects Coordinated scope against the verified dev baseline.
The existing localization tool changes affect tracked simulation inputs, so the
candidate uses `2026.11.10` consistently across app, Functions and validator.
Current/next ranked route windows are regenerated. The release snapshot includes
the existing completed localization/inbox/Admin work; the user's branch and
index remain untouched. Prepare validated the combined frozen source before
deployment. Native-device acceptance and full French editorial acceptance
remain outside the local test evidence.

Implementation, full preparation, dev deployment and Android version code 7 are
complete. Dev issuance is restored. See the
[verification record](../verification/town-services-2026-11-10.md) for the frozen
source, check counts, APK identity and live readback. This checklist remains
current because the linked Play Games/device end-to-end acceptance described
in that record is still outstanding; artifact and emulator checks do not replace it.
