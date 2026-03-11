# Town Store Implementation Checklist

Date: March 11, 2026
Status: Not started
Source plan: `docs/building/store/town-store-rewarded-refresh-plan.md`

## Goal

Turn the Town store plan into a phased execution checklist with concrete tasks,
clear dependencies, and per-phase done criteria.

## Phase Order

Implementation order is locked:

1. Ownership model expansion
2. Store backend state, pricing, and commands
3. Town UI and gold refresh
4. Locked-content discovery from loadout screens
5. Rewarded refresh via AdMob

Do not start Phase 5 before Phases 1-4 are complete and stable.

## Phase 1: Ownership Model Expansion

Objective:

- support sellable non-spell abilities as first-class owned content

Tasks:

- [ ] Replace the narrow spell-only ownership model with a broader per-character
      ability ownership model.
- [ ] Define the new canonical ownership shape for:
      - projectile spells
      - spell-slot abilities
      - non-spell active abilities by slot
- [ ] Migrate starter-owned content into the new ownership model.
- [ ] Update normalization logic so invalid or missing owned-content state is
      repaired safely.
- [ ] Update serializer/deserializer code for the new ownership model.
- [ ] Update loadout validation/presenter read paths to use the new owned-skill
      shape.
- [ ] Add tests covering:
      - starter ownership seeding
      - migration fallback behavior
      - owned-vs-locked ability visibility

Done when:

- non-spell abilities can be represented as owned/unowned without temporary
  side systems
- existing starter baselines still load cleanly
- touched tests pass

## Phase 2: Store Backend State, Pricing, and Commands

Objective:

- add canonical store state and server-authoritative purchase/refresh behavior

Tasks:

- [ ] Extend progression canonical state with Town store data:
      - `generation`
      - `refreshDayKeyUtc`
      - `refreshesUsedToday`
      - `activeOffers`
- [ ] Define `StoreOffer` DTO fields:
      - `offerId`
      - `bucket`
      - `domain`
      - `slot`
      - `itemId`
      - `priceGold`
- [ ] Add backend `StorePricingCatalog`.
- [ ] Seed the pricing catalog with all current sellable items.
- [ ] Set `defaultPriceGold = 150` for all current entries.
- [ ] Implement per-bucket eligible-pool builders for:
      - sword
      - shield
      - accessory
      - spellbook
      - projectile spell
      - spell
      - ability
- [ ] Implement deterministic store generation by bucket.
- [ ] Implement same-bucket backfill after purchase.
- [ ] Implement sold-out bucket behavior.
- [ ] Add `purchaseStoreOffer` command.
- [ ] Add `refreshStore` command with `method = gold | rewardedAd`.
- [ ] Implement gold refresh cost validation (`50` gold).
- [ ] Implement UTC-day quota reset behavior.
- [ ] Add store-specific rejection reasons.
- [ ] Add backend tests covering:
      - store seeding
      - price resolution
      - purchase success
      - insufficient gold
      - same-bucket backfill
      - sold-out buckets
      - gold refresh success
      - refresh limit reached
      - no-change refresh rejection

Done when:

- the backend can fully serve and mutate canonical Town store state without UI
- purchase and gold refresh are both transactionally safe
- store offers persist resolved `priceGold`

## Phase 3: Town UI and Gold Refresh

Objective:

- ship a playable Town store without ads

Tasks:

- [ ] Replace the placeholder Town page with a real store screen.
- [ ] Build the Town surface from existing shared UI primitives where they fit:
      - `MenuScaffold`
      - `AppButton`
- [ ] Render the fixed 7-bucket layout:
      - Sword
      - Shield
      - Accessory
      - Spellbook
      - Projectile Spell
      - Spell
      - Ability
- [ ] Reuse existing select-character/store-adjacent visual primitives for
      offer rendering:
      - `GearIcon`
      - `AbilitySkillIcon`
      - `ProjectileIconFrame`
      - existing ability/gear text helpers
- [ ] Show current gold from canonical progression state.
- [ ] Show offer price from resolved `priceGold`.
- [ ] Render sold-out bucket states without collapsing the layout.
- [ ] Keep `town_page.dart` orchestration-focused; extract reusable store
      widgets if the page starts accumulating card/layout/state-detail logic.
- [ ] Keep Town-only helper widgets colocated with the Town page, but move any
      cross-flow reused widget into `lib/ui/components/`.
- [ ] Use `UiTokens` and existing component themes for spacing, typography, and
      shared colors.
- [ ] If the store needs visuals specific to Town, add a dedicated store
      `ThemeExtension` instead of page-local styling knobs or raw colors.
- [ ] Implement purchase interaction:
      - select offer
      - confirm purchase
      - apply canonical response
- [ ] Implement `Refresh for 50 Gold`.
- [ ] Disable gold refresh when:
      - player has less than `50` gold
      - daily quota is exhausted
      - no bucket can change
- [ ] Show remaining daily refresh count.
- [ ] Add UI tests covering:
      - layout rendering
      - purchase success
      - insufficient-gold purchase
      - gold refresh success
      - sold-out rendering
      - refresh disabled states

Done when:

- the Town store is usable end-to-end with gold purchases and gold refresh
- all store state comes from canonical backend responses
- shared/select-character UI primitives are reused where they fit, without
  introducing a parallel store-only styling system

## Phase 4: Locked-Content Discovery From Loadout Screens

Objective:

- make locked store content discoverable from gear and skill setup flows

Tasks:

- [ ] Update `GearsTab` to show locked entries, not only unlocked entries.
- [ ] Update `SkillsTab` to show locked skills after ownership migration.
- [ ] Add a clear locked-state presentation for loadout candidates.
- [ ] Reuse or extract shared locked-state badges/tiles from select-character
      flows instead of duplicating near-identical widgets in Town/loadout pages.
- [ ] Add `Find in Town` CTA or equivalent navigation affordance.
- [ ] Route locked-item CTA to the Town page.
- [ ] Ensure loadout screens still distinguish:
      - owned but illegal for current loadout
      - locked and not owned
- [ ] Add widget/presenter tests for locked-content discovery behavior.

Done when:

- locked items are visible and understandable from setup screens
- the player can navigate from a locked loadout item to Town directly

## Phase 5: Rewarded Refresh Via AdMob

Objective:

- add rewarded refresh as the final monetization layer on top of the finished
  gold-refresh store

Tasks:

- [ ] Introduce a rewarded-refresh abstraction for Flutter integration.
- [ ] Add backend refresh-grant model and storage.
- [ ] Add grant issuance flow.
- [ ] Add grant verification flow.
- [ ] Add grant consumption flow inside `refreshStore`.
- [ ] Integrate AdMob rewarded ads in Flutter.
- [ ] Pass backend grant identifiers through the ad flow.
- [ ] Add server-side reward verification endpoint or equivalent verified path.
- [ ] Gate rewarded refresh UI behind the ad integration being enabled.
- [ ] Ensure rewarded refresh and gold refresh share the same daily quota.
- [ ] Add emulator/dev fake-grant support.
- [ ] Add tests covering:
      - verified rewarded refresh success
      - unverified grant rejection
      - expired grant rejection
      - reused grant rejection

Done when:

- rewarded refresh works without weakening the existing gold-refresh contract
- AdMob is the runtime ad provider
- the app does not rely on a Firebase-only ad-delivery path

## Cross-Cutting Tasks

These should be completed as part of the relevant phase, not deferred to the
end.

- [ ] Keep docs in sync if the contract changes.
- [ ] Keep rejection reasons typed across client and backend.
- [ ] Keep store logic server-authoritative; no client-only fallback logic.
- [ ] Keep tests aligned with canonical revision/idempotency semantics.
- [ ] Run targeted analysis/tests for touched files after each phase.

## Release Gates

Before shipping Town without ads:

- [ ] Phases 1-4 are complete.
- [ ] Gold purchase flow is stable.
- [ ] Gold refresh is stable.
- [ ] Locked-content discovery is in place.

Before shipping rewarded refresh:

- [ ] Phase 5 is complete.
- [ ] AdMob integration is stable in the target platform build.
- [ ] Reward verification is server-enforced.
- [ ] Compliance/privacy docs have been reviewed for ad integration.

## Verification Commands

Run the relevant subset as each phase lands:

- [ ] `dart analyze lib/ui/state lib/ui/pages lib/ui/components lib/ui/theme lib/core/meta`
- [ ] `flutter test test/ui/state`
- [ ] `flutter test test/ui/pages`
- [ ] `flutter test test/ui/components`
- [ ] `pnpm --dir functions test`

## Exit Criteria

The checklist is complete when:

- the Town store supports permanent purchases
- gold refresh works with the shared daily quota
- rewarded refresh works as the final phase
- locked loadout content routes players back to Town
- backend authority remains intact across pricing, ownership, and refresh flows
