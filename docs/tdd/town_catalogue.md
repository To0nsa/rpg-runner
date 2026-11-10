# Town purchase catalogue

Equipment and Training share the existing authenticated ownership command path.
They are presentation categories: gear and projectile sources are Equipment;
ability-slot techniques are Training. Core gameplay and replay identities do not
change. See the [gameplay contract](../gdd/town_services.md).

## Server authority and retained clients

`normalizeProgressionStore` derives store schema 2 from `storeOfferDefinitions`,
canonical pricing and `characterContentAllowed`. `catalogOffers` includes owned
entries and their playable `characterIds`; it is identical across profiles.
Retained persisted offers, prices, refresh counters and generations are not
authority. No reset or entitlement migration is required.

The legacy fields remain decodable. `activeOffers` projects one unowned entry
per bucket for the currently selected character; after purchase it projects the
next available entry. Generation and refresh counters remain zero. Old
`refreshStore` requests return `nothingToRefresh`, without spending or advancing
revision. There is no refresh UI in the new client.

`purchaseStoreOffer.payload.characterId` is optional for wire compatibility.
Absent means the canonical selected character; present must be a known character
ID. New clients always send a recipient, pinned before the request and retained
across a stale-revision reload. A purchase never changes selected character,
selected build, equipment or saved build names.

The server resolves `offerId` against its current definitions, checks character
compatibility and existing ownership, then charges the server price from confirmed
gold and grants through `grantCatalogOwnership`. Saved/client prices cannot reduce
the charge. Gear ownership is account-wide with character compatibility; ranged
sources and techniques remain per character. Shared accessories cannot be bought
twice by targeting a second character. Auth, UID, deletion guards, revision,
payload-hash idempotency and transaction boundaries remain unchanged. The target
is part of the hashed payload, so reusing a command ID for another target fails.

Deploy the compatible backend before distributing the new client. A schema-1
snapshot does not support independent character browsing: the new UI displays
catalogue-unavailable guidance rather than fabricating prices or enabling purchases.
Older clients retain their restricted legacy view and safe purchase semantics.
No run/replay compatibility tuple change is required by this ownership change.

## Client presentation

`TownStorePage` accepts an initial `TownService` from its route. Service, browsed
character, category, unowned filter and expanded entry are route-local state.
Entry defaults to the active playable character. Browsing does not submit a
selection command. `TownOfferCard` renders names, art and authoritative Core
descriptions; gear comparisons use the browsed character's selected saved build.
Ranged sources show candidate and equipped source details. Willow details select
Supplies by character identity.

Owned entries remain inspectable and have no purchase action. Shared accessories
are labelled explicitly. Controls wrap for narrow/large-text layouts and the list
builds entries lazily. Every new message belongs to the app English/French ARBs.
Town building labels and their dot markers open the same route; Back returns to
the map. The legacy `/meta/town/store` route opens Equipment.

Displayed gold may include journaled rewards, but spending remains confirmed-only.
The existing dismissible reward-verification dialog blocks premature purchase;
confirmation never automatically resubmits it. A purchase in flight disables
purchase and character/service switching. Errors leave browsing available.

## Verification

Functions tests cover both 42-item equipment rosters, explicit-character grants,
unchanged builds, shared duplicates, forged saved prices, invalid recipients,
legacy refresh rejection and transactional idempotency. The generated
`functions/test/fixtures/town_catalogue.json` is checked against the actual backend
producer and decoded by the Dart consumer test. Regenerate it after a Functions
build with `node functions/test/fixtures/generate_town_catalogue.mjs`.
Widget tests cover both entrances, character/category browsing, details,
confirmed funds and French compact/large-text layouts. Device/economy acceptance
and live release evidence are separate from those local tests.
