# Equipment and Training town services

Requested November 10, 2026: implement the permanent catalogue proposal, deploy
the backend to dev, and build a matching dev Android APK.

## Scope and acceptance

- Two town entrances, Equipment and Training, with shared navigation/presentation.
- Browse either playable character without changing run selection or saved builds.
- Permanent server-priced catalogues; 150 gold per unlock, no paid refreshes.
- Equipment includes ranged sources and shared accessories; Training contains
  ability-slot techniques. Owned entries remain inspectable; shared ownership
  cannot be purchased twice. Gear compares against the browsed character's build.
- Preserve confirmed-funds checks, compatibility, auth, revisions and idempotency.
- Keep English/French localization, compact/large-text layouts and accessible controls.
- Preserve retained profiles and legacy purchase requests. No gameplay or data reset.

The starting worktree contains the completed, uncommitted localization work and
other documentation/inbox/Admin changes. Preserve them. Initial status, diff and
task-relevant source copies are in ignored `.tmp/town-services/` for comparison.
They are not authorization for unrelated implementation. The release must freeze
the actual source and record all included work without altering unrelated staging.

## Milestones

- [x] Implement catalogue and explicit purchase target across backend/client.
- [x] Add services, character/category browsing, ownership and comparisons.
- [x] Verify backend boundaries and client/widget/localization behavior.
- [x] Update implemented GDD/TDD and review task-only diff.
- [ ] Freeze source; Plan/Prepare the dev release with reusable evidence.
- [ ] Deploy authorized dev backend scope and verify live state.
- [ ] Build/inspect matching dev Android APK and record artifact identity.

Owners: `functions/src/ownership`, `lib/ui/state`, `lib/ui/pages/town`, app routes,
app localization, focused Functions/Flutter tests and documentation. No Core or
replay contract change is planned. Release scope is decided by the canonical
release tool against the actual verified dev baseline, not assumed from history.

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
index remain untouched. Prepare must validate the combined frozen source before
any deployment. Native-device acceptance and full French editorial acceptance
remain outside the local test evidence.
