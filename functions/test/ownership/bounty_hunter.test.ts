import assert from "node:assert/strict";
import { test } from "node:test";
import { applyOwnershipCommand } from "../../src/ownership/apply_command.js";
import { starterCanonicalState } from "../../src/ownership/defaults.js";
import { hunterAbilitiesBySlot, hunterStarterLoadout, characterContentAllowed } from "../../src/ownership/character_catalog.js";
import { normalizeAuthorizedLoadout, normalizeAuthorizedSelection } from "../../src/ownership/loadout_authorization.js";
import { parseInboxRewards } from "../../src/inbox/gifts.js";
import { normalizeProgressionStore, purchaseStoreOffer } from "../../src/ownership/store_state.js";
import { storeOfferDefinitions, resolveStorePriceGold, storeOfferId } from "../../src/ownership/store_pricing.js";
import type { JsonObject, OwnershipCommandEnvelope } from "../../src/ownership/contracts.js";

test("fresh profiles include Willow and selection requires her complete branch", () => {
  const state = starterCanonicalState("default", "test");
  const loadouts = state.selection.loadoutsByCharacter as JsonObject;
  assert.deepEqual(loadouts.bountyHunter, hunterStarterLoadout);
  assert.ok(normalizeAuthorizedSelection(state));
  assert.ok(normalizeAuthorizedLoadout({ loadout: hunterStarterLoadout, meta: state.meta, characterId: "bountyHunter" }));
  delete loadouts.bountyHunter;
  assert.equal(normalizeAuthorizedSelection(state), null);
});

test("hunter has 25 purchasable abilities in the correct slots at existing prices", () => {
  const entries = storeOfferDefinitions.filter(d => d.itemId.startsWith("bounty_hunter."));
  assert.equal(entries.length, 25);
  for (const [slot, names] of Object.entries(hunterAbilitiesBySlot)) {
    for (const name of names) {
      const entry = entries.find(d => d.slot === slot && d.itemId === `bounty_hunter.${name}`);
      assert.ok(entry);
      assert.equal(resolveStorePriceGold(entry), 150);
    }
  }
});

test("character ownership and equipment families are both enforced", () => {
  const state = starterCanonicalState("default", "test");
  for (const characterId of ["eloise", "bountyHunter"]) {
    const wrongGun = characterId === "eloise" ? "hunterPistol" : "acidBolt";
    const base: OwnershipCommandEnvelope = { type: "setProjectileSpell", userId: "test", sessionId: "s", expectedRevision: 0, commandId: "test",
      payload: { characterId, spellId: wrongGun } };
    assert.equal(applyOwnershipCommand(state, base).accepted, false);
    assert.equal(applyOwnershipCommand(state, { ...base, type: "learnProjectileSpell" }).accepted, false);
    assert.equal(applyOwnershipCommand(state, { ...base, type: "equipGear", payload: {
      characterId, slot: "mainWeapon", itemDomain: "weapon", itemId: characterId === "eloise" ? "hunterBlade" : "plainsteel",
    } }).accepted, false);
  }
  assert.throws(() => parseInboxRewards([{ kind: "ability", slot: "primary", itemId: "bounty_hunter.twin_cut", characterId: "eloise" }]));
  assert.equal(parseInboxRewards([{ kind: "ability", slot: "primary", itemId: "bounty_hunter.twin_cut", characterId: "bountyHunter" }]).length, 1);
});

test("hunter store purchase unlocks only that character and preserves its price", () => {
  const state = starterCanonicalState("default", "test");
  state.selection.characterId = "bountyHunter";
  const definition = storeOfferDefinitions.find(d => d.itemId === "bounty_hunter.twin_cut")!;
  const priceGold = resolveStorePriceGold(definition);
  state.progression.gold = priceGold;
  state.progression.store = { schemaVersion: 1, generation: 0, refreshDayKeyUtc: "2026-11-07", refreshesUsedToday: 0,
    activeOffers: [{ ...definition, offerId: storeOfferId(definition), priceGold }] };
  assert.equal(purchaseStoreOffer({ progression: state.progression, meta: state.meta, selection: state.selection, userId: "test", offerId: storeOfferId(definition), nowMs: Date.UTC(2026, 10, 7) }).accepted, true);
  assert.equal(state.progression.gold, 0);
  assert.ok(normalizeAuthorizedLoadout({ loadout: { ...hunterStarterLoadout, abilityPrimaryId: "bounty_hunter.twin_cut" }, meta: state.meta, characterId: "bountyHunter" }));
  for (const characterId of ["eloise", "bountyHunter", "eloise"]) {
    state.selection.characterId = characterId;
    normalizeProgressionStore({ progression: state.progression, meta: state.meta, selection: state.selection, userId: "test", nowMs: Date.UTC(2026, 10, 7) });
    const offers = (state.progression.store as JsonObject).activeOffers as JsonObject[];
    assert.ok(offers.every(d => characterContentAllowed(characterId, d.domain as string, d.slot as string, d.itemId as string)));
  }
});
