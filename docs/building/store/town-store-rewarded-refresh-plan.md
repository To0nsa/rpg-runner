# Town Store Rewarded Refresh Plan

Date: March 11, 2026
Status: In progress (Phases 1-4 complete, Phase 5 pending)

## Purpose

Define the full product and architecture plan for the Town store before any
runtime integration begins.

The Town store should let players buy permanent unlocks for loadout content
while keeping ownership, pricing, and refresh behavior server-authoritative.

## Delivery Assumption

- This is pre-launch work with no live users.
- No production data migration path is required for ownership/progression
  schema changes.
- During implementation, local/emulator state can be reset instead of carrying
  legacy compatibility logic.

## Locked Decisions

These decisions are locked for v1 unless explicitly revised:

- The store is server-authoritative.
- The store only sells permanent unlocks the player does not already own.
- Purchased items are unlocked only; they are not auto-equipped.
- The store has 7 fixed buckets and shows at most one active offer per bucket.
- The 7 buckets are:
  - sword
  - shield
  - accessory
  - spellBook
  - projectileSpell
  - spell
  - ability
- `spell` means a spell-slot ability.
- `ability` means a non-spell active ability.
- Manual refresh has two paths:
  - watch a rewarded ad
  - spend `50` gold
- Both refresh paths consume the same shared daily quota.
- The daily refresh cap is `3` successful refreshes per UTC day.
- Gold refresh ships first.
- Rewarded ads ship last.
- Rewarded ads use AdMob in Flutter; Firebase is supporting infrastructure, not
  the ad-delivery SDK itself.
- Pricing is backend-authoritative through a `StorePricingCatalog`.
- `defaultPriceGold = 150` for now, but each item still has its own catalog
  entry.
- Ownership model changes ship as direct schema replacement (no live-data
  migration track).

## Current Baseline

Already in place:

- Firebase-backed ownership canonical state with revision + idempotency
- permanent ownership mutations for:
  - gear unlocks
  - projectile spell learning
  - spell-slot ability learning
- gold accrual via `awardRunGold`
- placeholder Town route in UI

Current gaps:

- no store inventory state
- no gold spending command
- no store refresh command
- no rewarded-ad integration
- no daily refresh quota tracking
- non-spell skills are not yet modeled as individually owned unlocks

## Scope

In scope:

- Town store inventory generation
- gold spending for permanent unlocks
- gold-paid refresh
- rewarded refresh
- daily refresh quota
- ownership-model expansion needed to support sellable skills
- Town UI
- loadout-screen discovery hooks into Town
- backend and Flutter test coverage

Out of scope:

- real-money purchases
- consumables
- duplicate compensation systems
- bundles
- discounts
- rarity animations
- pity systems
- temporary boosts
- broader ad monetization outside rewarded refresh

## Terminology

Use these terms consistently in code and docs:

- `bucket`: one fixed store category slot in the Town layout
- `offer`: one concrete purchasable item shown in a bucket
- `sold out`: a bucket has no eligible unowned items left
- `generation`: a monotonic store reroll version used for deterministic offer
  generation
- `refresh`: rerolling the active store offers
- `refresh grant`: a server-tracked entitlement created for rewarded refresh
  flow

## Canonical Wire Literals

Use these exact wire values across backend, Flutter client, tests, and docs:

- `bucket`: `sword|shield|accessory|spellBook|projectileSpell|spell|ability`
- `domain`: `gear|projectileSpell|ability`
- `slot`:
  `mainWeapon|offhandWeapon|spellBook|accessory|primary|secondary|projectile|mobility|jump|spell`
- `refresh.method`: `gold|rewardedAd`

## Architecture Options

### Option 1: Persistent server-authored store snapshot

Summary:

- backend persists active offers and refresh counters
- purchases and refreshes mutate canonical state transactionally
- gold refresh and rewarded refresh both use the same authority boundary

Pros:

- strongest anti-cheat posture
- easiest to debug live player state
- aligns with existing ownership revision/idempotency model
- clean UI because the active store is explicit canonical state

Cons:

- more backend state than a purely derived store
- rewarded refresh still needs verification infrastructure later

### Option 2: Stateless derived store

Summary:

- backend derives offers from ownership state plus counters on every load

Pros:

- less persisted store state
- deterministic derivation is simple to test

Cons:

- purchase and refresh behavior become harder to reason about
- debugging live player store state is worse
- offer stability across mutations is less obvious

### Option 3: Client-authored store with backend purchase validation

Summary:

- client rolls offers locally and server only validates purchases

Pros:

- fastest to prototype

Cons:

- weakest authority boundary
- easiest refresh path to exploit
- likely throwaway

## Chosen Architecture

Use Option 1: persistent server-authored store snapshot.

Reasoning:

- ownership is already treated as server-authoritative in this repo
- gold is already canonical server-side
- refreshes touch monetization/economy and should not trust the client
- fixed bucket layout is easier to operate when active offers are explicitly
  persisted

## Product Rules

These are the gameplay and economy rules for v1:

1. The Town store never sells an already owned item.
2. Every purchase is permanent and one-time only.
3. A purchased item is unlocked but not auto-equipped.
4. Refresh is always manual; there is no free reroll.
5. Manual refresh can use either:
   - rewarded ad
   - `50` gold
6. Both refresh methods use the same daily quota.
7. A player may complete at most `3` refreshes per UTC day.
8. The server owns all timing, pricing, offer generation, and refresh
   validation.
9. If a bucket runs out of eligible items, it becomes sold out.
10. If the full store runs out of eligible items, the store is effectively sold
    out and refresh is disabled.

## Store Layout

The Town screen should always reserve space for these 7 buckets:

1. Sword
2. Shield
3. Accessory
4. Spellbook
5. Projectile Spell
6. Spell
7. Ability

Bucket meaning:

- `sword`: main-weapon offer
- `shield`: offhand shield offer
- `accessory`: accessory offer
- `spellBook`: spellbook offer
- `projectileSpell`: projectile-spell ownership offer
- `spell`: spell-slot ability offer
- `ability`: non-spell active ability offer

The `ability` bucket can pull from these actual ability-slot pools:

- primary
- secondary
- projectile
- mobility
- jump

Even though the UI groups those under one generic `Ability` bucket, the backend
must still persist the real underlying slot on the offer.

## Store Lifecycle

### Initial seeding

For a new profile:

- seed the store once on canonical creation or first store initialization
- generate at most one active offer per bucket
- any empty bucket starts as sold out

### Day boundary

Use server-computed UTC day keys:

- reset point: `00:00 UTC`
- example stored key: `refreshDayKeyUtc = "2026-03-11"`

Day rollover only resets daily refresh allowance.

Day rollover does not automatically reroll the store.

### Purchase behavior

On successful purchase:

- deduct gold
- grant ownership
- remove the purchased offer
- backfill only that same bucket if another eligible item exists
- otherwise mark that bucket sold out

### Refresh behavior

A refresh rerolls buckets independently.

Bucket-level rule:

- if a bucket has at least one alternate eligible item, reroll that bucket
- if a bucket has no alternate eligible item, keep its current offer
- if a bucket is already sold out, it stays sold out

Store-level rule:

- a refresh is only valid if at least one bucket can actually change

This avoids charging a refresh when the store cannot materially update.

## Ownership Model Change

Current ownership is too narrow for a full Town store because it covers:

- gear inventory
- projectile spells
- spell-slot abilities

It does not yet model non-spell active abilities as individually owned content.

### Direct replacement plan (no migration track)

Replace `SpellList` and `spellListByCharacter` with a broader per-character
ability ownership model.

Recommended shape:

```text
AbilityOwnershipState
  learnedProjectileSpellIds: Set<ProjectileId>
  learnedAbilityIdsBySlot:
    primary: Set<AbilityKey>
    secondary: Set<AbilityKey>
    projectile: Set<AbilityKey>
    mobility: Set<AbilityKey>
    jump: Set<AbilityKey>
    spell: Set<AbilityKey>
```

Implementation expectations:

- bump schema/versioned defaults once
- seed starter ownership directly in the new shape
- remove legacy `SpellList` runtime paths in one pass
- do not ship dual-read compatibility branches for old ownership payloads

Why this is needed:

- starter-owned skills remain seeded exactly once per slot
- the store can sell non-spell abilities cleanly
- `SkillsTab` can show owned vs locked consistently
- the app avoids inventing a second temporary ownership system just for Town

## Canonical Data Model

Keep store state inside progression to minimize top-level contract churn.

Recommended expansion:

```text
ProgressionState
  gold: int
  awardedRunIds: int[]
  store:
    schemaVersion: int
    generation: int
    refreshDayKeyUtc: string
    refreshesUsedToday: int
    activeOffers: StoreOffer[]
```

Recommended offer shape:

```text
StoreOffer
  offerId: string
  bucket: sword | shield | accessory | spellBook | projectileSpell | spell | ability
  domain: gear | projectileSpell | ability
  slot: mainWeapon | offhandWeapon | spellBook | accessory | primary | secondary | projectile | mobility | jump | spell
  itemId: string
  priceGold: int
```

Notes:

- `offerId` should be stable and domain-qualified
- example: `gear:mainWeapon:stormneedle`
- `bucket` defines where the offer renders in Town
- `slot` preserves the real underlying slot semantics
- `priceGold` is resolved from the pricing catalog at offer-generation time

## Pricing Model

### Authority

Pricing must be backend-authoritative.

The backend owns a `StorePricingCatalog`.

The client only reads resolved prices from active offers.

### Catalog shape

Recommended key shape:

- `domain + slot + itemId`

Example conceptual entries:

```text
gear + mainWeapon + plainsteel -> 150
gear + offhandWeapon + roadguard -> 150
gear + accessory + strengthBelt -> 150
gear + spellBook + apprenticePrimer -> 150
projectileSpell + projectile + acidBolt -> 150
ability + spell + eloise.arcane_haste -> 150
ability + primary + eloise.seeker_slash -> 150
```

### Default pricing policy for v1

For now:

- `defaultPriceGold = 150`
- every sellable entry resolves to `150`

Even with uniform pricing, keep entries in the catalog now so later tuning can
diverge per item without redesigning the system.

### Why offers persist resolved prices

When an offer is generated, its current `priceGold` is written into that offer.

This gives stable player-facing behavior:

- old generated offers keep their original price until purchased or refreshed
- future generations can use updated catalog prices

That avoids mid-offer price drift and keeps purchase validation simple.

## Offer Generation Rules

### Eligible pools

Build one eligible pool per bucket:

- `sword`
- `shield`
- `accessory`
- `spellBook`
- `projectileSpell`
- `spell`
- `ability`

An item is eligible only if it is:

- sellable in v1
- valid for the current player/profile
- mapped to that bucket
- not already owned
- not already the active offer for that bucket

Bucket mapping:

- `sword` -> main-weapon sellable roster
- `shield` -> offhand shield sellable roster
- `accessory` -> accessory roster
- `spellBook` -> spellbook roster
- `projectileSpell` -> projectile-spell ownership domain
- `spell` -> spell-slot ability domain
- `ability` -> non-spell active ability domain

### Selection strategy

Recommended behavior:

- generate one offer independently per bucket
- use a deterministic sampler seeded by `uid + generation + bucket`
- persist the resulting offers

Determinism is helpful for reproducible tests, but the persisted snapshot
remains the runtime source of truth.

## Commands

Add two new ownership commands:

- `purchaseStoreOffer`
- `refreshStore`

### `purchaseStoreOffer`

Purpose:

- atomically spend gold and grant ownership

Payload:

```text
offerId: string
```

Server transaction rules:

1. load canonical state
2. validate revision and idempotency
3. ensure `offerId` exists in active offers
4. ensure the underlying item is still unowned
5. ensure player has enough gold
6. deduct gold
7. grant ownership
8. remove purchased offer
9. backfill the same bucket if possible
10. persist canonical state and idempotency result

### `refreshStore`

Purpose:

- reroll active offers

Payload:

```text
method: rewardedAd | gold
refreshGrantId?: string
```

Server transaction rules:

1. load canonical state
2. validate revision and idempotency
3. reset daily counter if `refreshDayKeyUtc` is stale
4. ensure `refreshesUsedToday < 3`
5. branch by `method`
6. if `method == rewardedAd`:
7. verify `refreshGrantId` belongs to this user/profile and is marked verified
8. ensure the grant is unused and unexpired
9. if `method == gold`:
10. ensure player has at least `50` gold
11. deduct `50` gold
12. ensure at least one bucket can change
13. reroll buckets independently
14. increment `refreshesUsedToday`
15. if `method == rewardedAd`, mark the grant consumed
16. persist canonical state and idempotency result

Validator expectations:

- backend validators must parse and constrain new store command payloads
- command and rejection enums must remain typed across backend and Flutter

## Rejection Reasons

Extend the ownership rejection surface with store-specific reasons:

- `insufficientGold`
- `offerUnavailable`
- `alreadyOwned`
- `refreshLimitReached`
- `invalidRefreshMethod`
- `rewardNotVerified`
- `rewardAlreadyConsumed`
- `rewardExpired`
- `nothingToRefresh`

These should remain typed and backend-authored.

## Rewarded Refresh

Gold refresh is the primary first-shipped refresh path.

Rewarded refresh is a late-phase addition.

### Production flow

1. Client requests a refresh attempt.
2. Client creates or fetches a backend-issued `refreshGrantId`.
3. Client launches the rewarded ad with the grant id as custom data.
4. Ad provider server-side verification notifies backend on reward completion.
5. Backend marks the grant verified.
6. Client calls `refreshStore(method: rewardedAd, refreshGrantId)`.
7. Backend consumes the grant and rerolls the store.

### Gold refresh flow

1. Client requests `refreshStore(method: gold)`.
2. Backend checks quota and `gold >= 50`.
3. Backend deducts `50` gold and rerolls the store.

### Grant model

Recommended server-side record:

```text
store_refresh_grants/{grantId}
  uid: string
  profileId: string
  createdAtMs: int
  expiresAtMs: int
  verifiedAtMs: int?
  consumedAtMs: int?
  provider: string
```

Recommended rules:

- grant expires after 15 minutes
- one grant unlocks exactly one refresh
- refresh quota is checked at claim time, not ad-start time

### Provider choice

Use AdMob when rewarded refresh is implemented.

Firebase should be used around the ad flow where useful for:

- Analytics
- Remote Config / experiments
- backend verification and refresh-grant consumption

Do not plan around a Firebase-only ad-delivery SDK path.

### Dev and test mode

Add a `RewardedRefreshApi`-style abstraction so the app can run with:

- production AdMob flow
- emulator/dev fake grants
- widget-test deterministic completions

## UI Plan

### Town page

Replace the placeholder Town page with a real store surface containing:

- gold header
- fixed 7-bucket layout
- clear sold-out states
- refresh card showing:
  - remaining refreshes today
  - `Refresh for 50 Gold`
  - `Watch Ad` when ad phase is enabled

Recommended Town sections:

- Sword
- Shield
- Accessory
- Spellbook
- Projectile Spell
- Spell
- Ability

Recommended offer states:

- purchasable
- insufficient gold
- purchased this session
- sold out
- unavailable because canonical state changed

### Loadout discovery

Locked content should remain discoverable in loadout screens:

- `GearsTab` should remain owned-entry focused and expose Town through a `+`
  CTA in the first unoccupied slot
- `SkillsTab` should show locked skills in compact form (icon + name only)
- locked skill details should route players to Town instead of disappearing
- candidate models should separate ownership state from legality state

Recommended CTA:

- `Find in Town` (on locked skill details)

### Interaction rules

Purchase flow:

- first tap selects an offer
- second tap confirms purchase
- success updates UI from canonical response
- no auto-equip prompt in v1

Refresh flow:

- `Refresh for 50 Gold` disables when `gold < 50`
- both refresh CTAs show they consume one of the `3` daily refreshes
- refresh CTAs disable when no bucket can change

### UI composition rules

The Town/store UI should follow the existing UI house style, not introduce a
parallel page-local design system.

Required reuse pattern:

- reuse shared shell and CTA primitives where they already fit:
  - `MenuScaffold`
  - `AppButton`
- reuse select-character/store-adjacent visual primitives for offer content:
  - `GearIcon` for sword, shield, accessory, and spellbook buckets
  - `AbilitySkillIcon` for ability and spell offers
  - `ProjectileIconFrame` for projectile-spell offers
  - existing ability/gear text helpers for consistent naming and copy
- keep `town_page.dart` orchestration-focused; extract reusable store widgets
  for the gold header, bucket section, offer card, refresh card, and locked CTA
  if the page starts accumulating layout or state-detail noise
- keep page-local widgets near the Town page only while they are page-local;
  once a widget is reused across flows, move it to `lib/ui/components/`
- use `UiTokens` and existing component themes for spacing, typography, and
  shared color decisions
- if the store needs visuals that are specific to Town, add a dedicated store
  `ThemeExtension` instead of raw page-local colors/padding/text styles
- if Town and select-character need the same badge/tile treatment, extract a
  shared component instead of copying private page-local widgets

## Delivery Plan

### Phase 1: Ownership model expansion

- replace spell-list ownership with broad ability ownership in one pass
- update normalization and starter baseline
- update picker presenters to respect new ownership model

### Phase 2: Store state and commands

- extend progression schema with store state
- add backend `StorePricingCatalog`
- add store seeding and normalization
- add `purchaseStoreOffer`
- add `refreshStore`
- add store-specific rejection reasons
- update validators and typed client/backend enums

### Phase 3: Town UI and gold refresh

- implement Town page
- wire purchase flow
- wire gold refresh flow
- expose loadout-to-store navigation affordances

### Phase 4: Locked-content discovery polish

- add `GearsTab` first-empty-slot `+` CTA with confirmation routing to Town
- update `SkillsTab` locked rendering to icon + name only in list/grid views
- add locked-skill details-panel `Find in Town` affordance
- harden empty and sold-out states

### Phase 5: Rewarded refresh via AdMob

- add refresh-grant issuance and consumption flow
- integrate AdMob rewarded ads in Flutter
- wire provider verification endpoint
- keep emulator-safe fake grant flow

## Likely File Impact

Backend:

- `functions/src/ownership/contracts.ts`
- `functions/src/ownership/defaults.ts`
- `functions/src/ownership/validators.ts`
- `functions/src/ownership/apply_command.ts`
- `functions/src/ownership/command_executor.ts`
- `functions/src/ownership/store_pricing.ts`
- new store helper files under `functions/src/ownership/`
- rewarded-refresh helper files under `functions/src/ads/` or
  `functions/src/store/`
- `functions/test/ownership/ownership_callable.test.ts`

Flutter:

- `lib/ui/state/loadout_ownership_api.dart`
- `lib/ui/state/firebase_loadout_ownership_api.dart`
- `lib/ui/state/progression_state.dart`
- `packages/runner_core/lib/meta/*` ownership models after replacing `SpellList`
- `lib/ui/pages/meta/town_page.dart`
- new shared store widgets under `lib/ui/components/`
- Town-only helper widgets colocated with `lib/ui/pages/meta/town_page.dart`
- optional store-specific theme extension under `lib/ui/theme/`
- loadout picker pages and presenters

## Test Matrix

Minimum backend tests:

1. initial canonical load seeds at most one unowned offer per bucket
2. purchase deducts gold once and grants ownership once
3. purchase replay is idempotent
4. purchase rejects when gold is insufficient
5. purchase rejects when offer is no longer active
6. purchase never resurfaces an already owned item
7. purchase backfills only within the purchased bucket
8. sold-out buckets remain empty and do not cross-fill
9. generated offers resolve `priceGold` from the pricing catalog
10. existing offers keep their resolved price if catalog prices later change
11. gold refresh deducts exactly `50` gold
12. gold refresh replay is idempotent
13. rewarded refresh succeeds only with a verified unused grant
14. refresh rejects on the fourth successful claim in the same UTC day
15. day rollover resets quota server-side
16. refresh rejects when no bucket can change

Minimum Flutter tests:

1. Town page renders the fixed 7-bucket layout and gold
2. successful purchase updates UI from canonical response
3. insufficient-gold purchase shows disabled or rejected state correctly
4. gold refresh deducts `50` gold and updates the store
5. rewarded refresh updates the store once implemented
6. exhausted daily quota disables all refresh CTAs
7. sold-out bucket states render without collapsing layout
8. `GearsTab` `+` CTA routes to Town after confirmation
9. locked skills render compactly (icon + name only) in list/grid views
10. locked skill details-panel `Find in Town` CTA routes to Town
11. locked and illegal states render as distinct UI states in loadout pickers

## Acceptance Criteria

- The store never shows an owned item as purchasable.
- The store shows at most one active offer in each fixed bucket.
- A purchased item can never be bought twice.
- Purchasing an item deducts gold and grants ownership in one transaction.
- Manual refresh never exceeds `3` successful claims per UTC day.
- Gold refresh costs exactly `50` gold.
- Rewarded refresh requires a verified backend-tracked grant.
- Sold-out buckets render cleanly and never cross-fill from other categories.
- Locked discovery from loadout screens matches UX intent:
  `GearsTab` via `+` CTA, and `SkillsTab` via locked details CTA to Town.
- Town reuses the existing shared/select-character UI primitives where they
  already fit, and any store-specific styling is isolated behind the existing
  token/theme system.
- No live-data migration path is required for launch.

## Risks

### Ownership replacement still touches many surfaces

Mitigation:

- complete the ownership replacement first
- remove `SpellList` in one pass to avoid split models
- keep serializer/default updates in the same change

### Rewarded ads are not yet integrated

Mitigation:

- ship gold refresh first
- design rewarded refresh behind an abstraction
- add AdMob last

### Ads reopen privacy/compliance work

Mitigation:

- update compliance docs and privacy-policy scope when ad SDK/provider is added
- prefer server-side verification over trusting client callbacks

## Recommended Implementation Order

1. Lock the ownership replacement for sellable skills.
2. Implement store state, pricing catalog, and purchase command.
3. Ship gold refresh first.
4. Build and stabilize Town UI on top of the finalized backend contract.
5. Update loadout surfaces to expose locked content and Town routing.
6. Add rewarded refresh with AdMob as the final phase.

## Summary

Recommended v1 shape:

- persistent server-authored Town store
- 7 fixed buckets
- one-time permanent unlocks only
- backend `StorePricingCatalog`
- `defaultPriceGold = 150`
- manual refresh via either:
  - `50` gold
  - rewarded ad
- shared `3` per UTC day refresh quota
- no auto-equip on purchase
- no automatic daily reroll
- same-bucket backfill on purchase
- gold refresh first, AdMob rewarded refresh last
- pre-launch direct ownership schema replacement (no live-data migration track)
