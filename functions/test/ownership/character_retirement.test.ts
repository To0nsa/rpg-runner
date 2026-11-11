import assert from "node:assert/strict";
import { test } from "node:test";
import { normalizeCanonicalState, starterCanonicalState } from "../../src/ownership/defaults.js";
import { knownCharacterIds, characterContentAllowed } from "../../src/ownership/character_catalog.js";
import { parseCatalogReward } from "../../src/ownership/catalog_rewards.js";
import { applyOwnershipCommand } from "../../src/ownership/apply_command.js";
import type { JsonObject } from "../../src/ownership/contracts.js";

test("retired character is absent from new profiles and rejected for commands and rewards", () => {
  assert.deepEqual(knownCharacterIds, ["eloise", "bountyHunter"]);
  assert.ok(!JSON.stringify(starterCanonicalState("main", "player")).includes("eloiseWip"));
  assert.equal(characterContentAllowed("eloiseWip", "ability", "spell", "eloise.focus"), false);
  assert.throws(() => parseCatalogReward({ kind: "ability", slot: "spell", itemId: "eloise.focus", characterId: "eloiseWip" }));
  for (const characterId of ["eloise", "eloiseWip"]) {
    const result = applyOwnershipCommand(starterCanonicalState("main", "player"), {
      userId: "player", sessionId: "session", commandId: "retired", expectedRevision: 0,
      type: "setAbilitySlot", payload: { characterId, buildIndex: 0, slot: "spell", abilityId: "eloise.focus" },
    });
    assert.equal(result.accepted, characterId === "eloise");
  }
});

test("old profiles fall back safely and merge earned skills once without overwriting active builds", () => {
  const old = starterCanonicalState("main", "player");
  old.selection.characterId = "eloiseWip";
  (old.selection.buildsByCharacter as JsonObject).eloiseWip = { builds: [] };
  (old.meta.equippedByCharacter as JsonObject).eloiseWip = { mainWeaponId: "waspfang" };
  (old.meta.abilityOwnershipByCharacter as JsonObject).eloiseWip = {
    projectileSpells: ["fireBolt", "acidBolt"],
    abilitiesBySlot: { spell: ["eloise.arcane_ward", "eloise.focus"] },
  };
  old.progression.gold = 321;
  old.revision = 17;
  const before = structuredClone(old);
  const normalized = normalizeCanonicalState(old, "main", "player");
  assert.equal(normalized.selection.characterId, "eloise");
  assert.equal(normalized.progression.gold, 321);
  assert.equal(normalized.revision, 17);
  assert.deepEqual((normalized.selection.buildsByCharacter as JsonObject).eloise, (old.selection.buildsByCharacter as JsonObject).eloise);
  assert.deepEqual((normalized.meta.equippedByCharacter as JsonObject).eloise, (old.meta.equippedByCharacter as JsonObject).eloise);
  const ownership = (normalized.meta.abilityOwnershipByCharacter as JsonObject).eloise as JsonObject;
  assert.deepEqual(ownership.projectileSpells, ["acidBolt", "holyBolt", "fireBolt"]);
  assert.deepEqual((ownership.abilitiesBySlot as JsonObject).spell, ["eloise.arcane_haste", "eloise.focus", "eloise.arcane_ward"]);
  assert.ok(!JSON.stringify(normalized).includes("eloiseWip"));
  assert.deepEqual(normalizeCanonicalState(normalized, "main", "player"), normalized);
  assert.deepEqual(old, before);
});
