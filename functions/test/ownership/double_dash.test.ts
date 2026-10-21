import assert from "node:assert/strict";
import { test } from "node:test";
import { applyOwnershipCommand } from "../../src/ownership/apply_command.js";
import { starterCanonicalState } from "../../src/ownership/defaults.js";
import type { OwnershipCommandEnvelope } from "../../src/ownership/contracts.js";
import { storeOfferDefinitions, resolveStorePriceGold, storeOfferId } from "../../src/ownership/store_pricing.js";
import { purchaseStoreOffer } from "../../src/ownership/store_state.js";

test("Double Dash must be purchased before it can be equipped", () => {
  const state = starterCanonicalState("default", "test");
  const equip: OwnershipCommandEnvelope = {
    type: "setAbilitySlot", userId: "test", sessionId: "session",
    expectedRevision: 0, commandId: "equip-double-dash",
    payload: { characterId: "eloise", slot: "mobility", abilityId: "eloise.double_dash" },
  };
  assert.equal(applyOwnershipCommand(state, equip).accepted, false);
  const definition = storeOfferDefinitions.find(d => d.itemId === "eloise.double_dash");
  assert.ok(definition);
  assert.equal(definition.slot, "mobility");
  const priceGold = resolveStorePriceGold(definition);
  state.progression.gold = priceGold;
  state.progression.store = {
    schemaVersion: 1, generation: 0, refreshDayKeyUtc: "2026-10-21",
    refreshesUsedToday: 0,
    activeOffers: [{ ...definition, offerId: storeOfferId(definition), priceGold }],
  };
  const result = purchaseStoreOffer({
    progression: state.progression, meta: state.meta, selection: state.selection,
    userId: "test", offerId: storeOfferId(definition), nowMs: Date.UTC(2026, 9, 21),
  });
  assert.equal(result.accepted, true);
  assert.equal(state.progression.gold, 0);
  assert.equal(applyOwnershipCommand(state, equip).accepted, true);
  assert.equal(applyOwnershipCommand(state, {
    ...equip, payload: { ...equip.payload, slot: "jump" },
  }).accepted, false);
});
