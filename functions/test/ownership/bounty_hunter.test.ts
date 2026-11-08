import { buildAt } from "../../src/ownership/character_builds.js";
import assert from "node:assert/strict";
import { test } from "node:test";
import { applyOwnershipCommand } from "../../src/ownership/apply_command.js";
import { starterCanonicalState } from "../../src/ownership/defaults.js";
import { hunterAbilitiesBySlot, hunterStarterLoadout, characterContentAllowed, hunterBlades, hunterBombKits, hunterFieldKits, hunterProjectiles, hunterStarterProjectiles } from "../../src/ownership/character_catalog.js";
import { normalizeAuthorizedLoadout, normalizeAuthorizedSelection } from "../../src/ownership/loadout_authorization.js";
import { parseInboxRewards } from "../../src/inbox/gifts.js";
import { normalizeProgressionStore, purchaseStoreOffer } from "../../src/ownership/store_state.js";
import { storeOfferDefinitions, resolveStorePriceGold, storeOfferId } from "../../src/ownership/store_pricing.js";
import type { JsonObject, OwnershipCommandEnvelope } from "../../src/ownership/contracts.js";

test("fresh profiles include Willow and selection requires her complete branch", () => {
  const state = starterCanonicalState("default", "test");
  const loadouts = state.selection.buildsByCharacter as JsonObject;
  assert.deepEqual(buildAt(state.selection, "bountyHunter", 0)?.loadout, hunterStarterLoadout);
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
      payload: { buildIndex: 0, characterId, spellId: wrongGun } };
    assert.equal(applyOwnershipCommand(state, base).accepted, false);
    assert.equal(applyOwnershipCommand(state, { ...base, type: "learnProjectileSpell" }).accepted, false);
    assert.equal(applyOwnershipCommand(state, { ...base, type: "equipGear", payload: { buildIndex: 0,
      characterId, slot: "mainWeapon", itemDomain: "weapon", itemId: characterId === "eloise" ? "hunterBlade" : "plainsteel",
    } }).accepted, false);
  }
  assert.throws(() => parseInboxRewards([{ kind: "ability", slot: "primary", itemId: "bounty_hunter.twin_cut", characterId: "eloise" }]));
  assert.equal(parseInboxRewards([{ kind: "ability", slot: "primary", itemId: "bounty_hunter.twin_cut", characterId: "bountyHunter" }]).length, 1);
});

test("removed Threefold Cut is unavailable even with retained ownership", () => {
  const id = "bounty_hunter.threefold_cut";
  const state = starterCanonicalState("default", "test");
  const ownership = (state.meta.abilityOwnershipByCharacter as JsonObject).bountyHunter as JsonObject;
  (ownership.abilitiesBySlot as JsonObject).primary = ["bounty_hunter.quick_cut", id];
  assert.equal(storeOfferDefinitions.some(d => d.itemId === id), false);
  assert.equal(normalizeAuthorizedLoadout({
    loadout: { ...hunterStarterLoadout, abilityPrimaryId: id },
    meta: state.meta, characterId: "bountyHunter",
  }), null);
  assert.equal(applyOwnershipCommand(state, {
    type: "setAbilitySlot", userId: "test", sessionId: "s", expectedRevision: 0,
    commandId: "removed-threefold", payload: {
      characterId: "bountyHunter", buildIndex: 0, slot: "primary", abilityId: id,
    },
  }).accepted, false);
  assert.throws(() => parseInboxRewards([
    { kind: "ability", slot: "primary", itemId: id, characterId: "bountyHunter" },
  ]));
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


test("42 items per character; new Willow items are purchasable, grantable and family-restricted", () => {
  for (const character of ["eloise", "bountyHunter"]) {
    const items = storeOfferDefinitions.filter(d => d.domain !== "ability" && characterContentAllowed(character, d.domain, d.slot, d.itemId));
    assert.equal(items.length, 42);
    for (const [slot, count] of Object.entries({ mainWeapon: 8, offhandWeapon: 10, spellBook: 8, accessory: 8, projectile: 8 })) {
      assert.equal(items.filter(d => d.slot === slot).length, count);
    }
  }
  const state = starterCanonicalState("default", "test");
  const ownership = (state.meta.abilityOwnershipByCharacter as JsonObject).bountyHunter as JsonObject;
  assert.deepEqual(ownership.projectileSpells, [...hunterStarterProjectiles]);
  const families = [
    ["mainWeapon", hunterBlades], ["offhandWeapon", hunterBombKits],
    ["spellBook", hunterFieldKits], ["projectile", hunterProjectiles],
  ] as const;
  for (const [slot, ids] of families) {
    for (const itemId of ids) {
      const definition = storeOfferDefinitions.find(d => d.itemId === itemId)!;
      assert.ok(definition);
      assert.equal(resolveStorePriceGold(definition), 150);
      assert.equal(characterContentAllowed("bountyHunter", definition.domain, slot, itemId), true);
      assert.equal(characterContentAllowed("eloise", definition.domain, slot, itemId), false);
      if (slot === "projectile") {
        assert.equal(parseInboxRewards([{ kind: "projectileSpell", slot: "projectile", itemId, characterId: "bountyHunter" }]).length, 1);
        assert.throws(() => parseInboxRewards([{ kind: "projectileSpell", slot: "projectile", itemId, characterId: "eloise" }]));
      } else {
        assert.equal(parseInboxRewards([{ kind: "gear", slot, itemId }]).length, 1);
      }
    }
  }
});

test("new Willow gear is rejected before purchase and authorized after purchase", () => {
  for (const [slot, field, itemId] of [
    ["mainWeapon", "mainWeaponId", "hunterNotchknife"],
    ["offhandWeapon", "offhandWeaponId", "hunterPitchRig"],
    ["spellBook", "spellBookId", "hunterLongtrailPack"],
    ["projectile", "projectileSlotSpellId", "hunterBrushgun"],
  ]) {
    const state = starterCanonicalState("default", "test");
    state.selection.characterId = "bountyHunter";
    const loadout = { ...hunterStarterLoadout, [field]: itemId };
    assert.equal(normalizeAuthorizedLoadout({ loadout, meta: state.meta, characterId: "bountyHunter" }), null);
    const definition = storeOfferDefinitions.find(d => d.slot === slot && d.itemId === itemId)!;
    state.progression.gold = 150;
    state.progression.store = { schemaVersion: 1, generation: 0, refreshDayKeyUtc: "2026-11-08", refreshesUsedToday: 0,
      activeOffers: [{ ...definition, offerId: storeOfferId(definition), priceGold: 150 }] };
    const purchase = purchaseStoreOffer({ progression: state.progression, meta: state.meta, selection: state.selection,
      userId: "test", offerId: storeOfferId(definition), nowMs: Date.UTC(2026, 10, 8) });
    assert.equal(purchase.accepted, true);
    assert.equal(state.progression.gold, 0);
    assert.ok(normalizeAuthorizedLoadout({ loadout, meta: state.meta, characterId: "bountyHunter" }));
    assert.equal(normalizeAuthorizedLoadout({ loadout, meta: state.meta, characterId: "eloise" }), null);
  }
});
