import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { test } from "node:test";
import { coreCatalog, coreStarterLoadouts } from "../../src/ownership/core_catalog.generated.js";
import { characterContentAllowed, knownCharacterIds } from "../../src/ownership/character_catalog.js";
import { parseCatalogReward } from "../../src/ownership/catalog_rewards.js";
import { normalizeAuthorizedLoadout } from "../../src/ownership/loadout_authorization.js";
import { normalizeCanonicalState, starterMeta } from "../../src/ownership/defaults.js";
import { inboxGiftCatalog, inboxGiftCatalogHash } from "../../src/inbox/gifts.js";

test("generated eligibility rejects unknown identities, slots, domains and recipients", () => {
  for (const entry of coreCatalog) {
    for (const character of [...knownCharacterIds, "eloiseWip", "unknown"]) {
      const allowed = (entry.characterIds as readonly string[]).includes(character);
      assert.equal(characterContentAllowed(character, entry.domain, entry.slot, entry.itemId), allowed);
      assert.equal(characterContentAllowed(character, entry.domain, "wrong-slot", entry.itemId), false);
      assert.equal(characterContentAllowed(character, "wrong-domain", entry.slot, entry.itemId), false);
      assert.equal(characterContentAllowed(character, entry.domain, entry.slot, `${entry.itemId}.forged`), false);
      if (entry.domain !== "gear") {
        const reward = { kind: entry.domain, slot: entry.slot, itemId: entry.itemId, characterId: character };
        if (allowed) assert.deepEqual(parseCatalogReward(reward), reward);
        else assert.throws(() => parseCatalogReward(reward));
      }
    }
    if (entry.domain === "gear") {
      assert.doesNotThrow(() => parseCatalogReward({ kind: entry.domain, slot: entry.slot, itemId: entry.itemId }));
    }
  }
  for (const itemId of ["eloise.forged", "common.forged", "bounty_hunter.threefold_cut", "bounty_hunter.roll", "bounty_hunter.slide"]) {
    assert.equal(characterContentAllowed("eloise", "ability", "primary", itemId), false);
    assert.equal(characterContentAllowed("bountyHunter", "ability", "primary", itemId), false);
  }
});

test("gift catalogue and activation hash remain byte-compatible with the retained fixture", () => {
  const fixture = JSON.parse(readFileSync(resolve(process.cwd(), "../tools/admin/test/fixtures/catalog.json"), "utf8"));
  assert.deepEqual(inboxGiftCatalog, fixture.entries);
  assert.deepEqual(knownCharacterIds, fixture.characters);
  assert.equal(inboxGiftCatalogHash, fixture.catalogHash);
});

test("Core starters are authorized, cloned and preserve retained account ownership", () => {
  for (const id of knownCharacterIds) {
    assert.ok(normalizeAuthorizedLoadout({ characterId: id, loadout: coreStarterLoadouts[id], meta: starterMeta() }));
  }
  const first = starterMeta();
  first.inventory = {};
  assert.notDeepEqual(first, starterMeta());
  const retained = normalizeCanonicalState(null, "default", "catalog-test");
  const inventory = retained.meta.inventory as { weapons: string[] };
  inventory.weapons.push("retained-unknown-item");
  const after = normalizeCanonicalState(retained, "default", "catalog-test");
  assert.deepEqual(after.meta, retained.meta);
});
