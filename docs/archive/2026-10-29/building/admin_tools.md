# Shared Flutter tools and Admin gifts

Authorized: build a separate Flutter Admin app with the editor's shared UI/UX,
reuse game item/skill presentation, rename extracted components by ownership,
extend inbox delivery/claiming to existing items and skills, and update docs and
agent orchestration. No deployment or real-player grant is authorized.

Base: `d562b4eb`. Preserve unrelated edits in
`docs/building/android_beta_release.md` and
`docs/verification/android-beta-2026-10-26.md`.

## Acceptance and approach

- Extract neutral tool theme/tokens/cards/catalog/layout into `packages/tool_ui`;
  migrate editor consumers without changing authoring/session authority.
- Extract item/skill icon presentation into `packages/game_presentation`;
  the game and Admin use the same mappings and renderers. Core remains pure Dart.
- `tools/admin` owns the Flutter desktop app and local privileged service. Preserve
  dedicated operator login, explicit environments, immutable previews, durable
  drafts/delivery identity and retry safety. Reuse existing sending transactions.
- Gifts use existing allowlisted ownership definitions with explicit character
  targets for abilities/spells. Claim atomically; already-owned unlocks complete
  without compensation. Unclaimed attachments cannot expire or be deleted.
- Preserve legacy gold deliveries and retry hashes. Extended gifts need an
  explicit environment capability gate after backend/client rollout.
- Prove real extraction with editor/game consumers; prove delivery-to-claim with
  emulator integration and the Admin UI with fixture/widget/screenshot checks.

## Milestones

- [x] Shared UI and game presentation extraction, consumer migrations, checks.
- [x] Typed gifts, shared ownership grant primitive, compatibility/retention tests.
- [x] Flutter Admin service/client, catalog picker, durable preview/send flow.
- [x] Game inbox gift presentation and claim-state integration.
- [x] TDD/GDD/README and agent routing/instructions; final integrated checks/review.

Context7 is unavailable. Official Flutter packages/assets/desktop and Dart
workspace/process documentation are the fallback for library-specific changes.

## Completion — 2026-10-29

All implementation milestones are complete. Shared primitives and their tests
moved to their package owners; game/editor imports migrated. Admin is a root
workspace Windows app with the retained isolated credential path, durable
preview/send recovery, shared catalog artwork and typed existing unlocks.
TDD/GDD, guides, scoped instructions and the shared-tools orchestration workflow
are updated. No deployment or live grant was performed.

[Verification](../../../verification/admin-tools-2026-10-29.md) records the exact
commands, tested source and limitations: 282 backend tests, 11 service tests,
6 Admin tests, 11 shared UI tests, 57 focused game tests (plus a final 25-test inbox
check), native Windows build and browser compatibility pass. Final full editor
suite: 880 pass, 2 skip, 10 fail; all ten failures reproduce at baseline `4366f2a6`
and remain explicit outside this task. No new test regression remains.

The user's release-doc work advanced HEAD from `d562b4eb` to `4366f2a6` during
implementation; it was preserved. No shared ADC, environment capability gate or
live project was changed. Compatible backend/client rollout, required-update
acceptance and explicit gate publication are separate authorized release work.
