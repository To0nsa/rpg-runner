import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { test } from "node:test";
import { starterCanonicalState } from "../../src/ownership/defaults.js";
import { normalizeProgressionStore, purchaseStoreOffer, refreshStore } from "../../src/ownership/store_state.js";
import { parseExecuteCommandRequest } from "../../src/ownership/validators.js";
import type { JsonObject } from "../../src/ownership/contracts.js";

function seeded() {
  const state = starterCanonicalState("default", "catalogue-test");
  state.progression.gold = 1000;
  return { ...state, userId: "catalogue-test", nowMs: 0 };
}

test("permanent catalogue covers both equipment rosters and retains owned entries", () => {
  const state = seeded();
  normalizeProgressionStore(state);
  const store = state.progression.store as JsonObject;
  const offers = store.catalogOffers as JsonObject[];
  assert.equal(store.schemaVersion, 2);
  assert.equal(new Set(offers.map(o => o.offerId)).size, offers.length);
  for (const character of ["eloise", "bountyHunter"]) {
    assert.equal(offers.filter(o => (o.characterIds as string[]).includes(character) && o.domain !== "ability").length, 42);
  }
  assert.equal(offers.find(o => o.itemId === "plainsteel")?.priceGold, 150);
  assert.deepEqual(offers.find(o => o.itemId === "strengthBelt")?.characterIds, ["eloise", "bountyHunter"]);
  assert.deepEqual(store, JSON.parse(readFileSync(resolve(__dirname, "../../../test/fixtures/town_catalogue.json"), "utf8")));
});

test("purchase can target Willow while preserving active character and all builds", () => {
  const state = seeded();
  const selection = structuredClone(state.selection);
  const result = purchaseStoreOffer({ ...state, characterId: "bountyHunter", offerId: "ability:mobility:bounty_hunter.blink_dash" });
  assert.equal(result.accepted, true);
  assert.equal(state.progression.gold, 850);
  assert.deepEqual(state.selection, selection);
  const ownership = state.meta.abilityOwnershipByCharacter as JsonObject;
  const willow = ownership.bountyHunter as JsonObject;
  assert.ok(((willow.abilitiesBySlot as JsonObject).mobility as string[]).includes("bounty_hunter.blink_dash"));
  const offers = (state.progression.store as JsonObject).catalogOffers as JsonObject[];
  assert.ok(offers.some(o => o.offerId === "ability:mobility:bounty_hunter.blink_dash"));
});

test("shared accessory cannot be charged twice across characters", () => {
  const state = seeded();
  const offerId = "gear:accessory:speedBoots";
  assert.equal(purchaseStoreOffer({ ...state, offerId, characterId: "eloise" }).accepted, true);
  assert.equal(purchaseStoreOffer({ ...state, offerId, characterId: "bountyHunter" }).rejectedReason, "alreadyOwned");
  assert.equal(state.progression.gold, 850);
});

test("retained forged offers and prices cannot authorize or discount a purchase", () => {
  const state = seeded();
  state.progression.store = { schemaVersion: 1, activeOffers: [
    { offerId: "gear:mainWeapon:waspfang", priceGold: 1 },
    { offerId: "gear:mainWeapon:forged", priceGold: 1 },
  ] };
  assert.equal(purchaseStoreOffer({ ...state, offerId: "gear:mainWeapon:forged" }).rejectedReason, "offerUnavailable");
  assert.equal(purchaseStoreOffer({ ...state, offerId: "gear:mainWeapon:waspfang", characterId: "bountyHunter" }).rejectedReason, "offerUnavailable");
  assert.equal(purchaseStoreOffer({ ...state, offerId: "gear:mainWeapon:waspfang" }).accepted, true);
  assert.equal(state.progression.gold, 850);
});

test("old refresh commands never spend gold or mutate the catalogue", () => {
  const state = seeded();
  const before = structuredClone(state);
  for (const method of ["gold", "rewardedAd"] as const) {
    assert.equal(refreshStore({ ...state, method }).rejectedReason, "nothingToRefresh");
  }
  assert.deepEqual(state, before);
});

test("purchase recipient validation rejects malformed and unknown targets", () => {
  const command = { type: "purchaseStoreOffer", userId: "u", sessionId: "s", expectedRevision: 0,
    commandId: "purchase_target", payload: { offerId: "gear:mainWeapon:waspfang" } };
  for (const characterId of [null, 7, "", "unknown", []]) {
    assert.throws(() => parseExecuteCommandRequest({ command: { ...command, payload: { ...command.payload, characterId } } }));
  }
  assert.doesNotThrow(() => parseExecuteCommandRequest({ command }));
});
