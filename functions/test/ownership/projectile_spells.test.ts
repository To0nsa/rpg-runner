import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { test } from "node:test";
import { applyOwnershipCommand } from "../../src/ownership/apply_command.js";
import { starterCanonicalState } from "../../src/ownership/defaults.js";
import type { OwnershipCommandEnvelope, OwnershipCommandType } from "../../src/ownership/contracts.js";
import { playerEquippableProjectileIds } from "../../src/ownership/projectile_spells.js";
import { storeOfferDefinitions } from "../../src/ownership/store_pricing.js";

function command(type: OwnershipCommandType, spellId: string): OwnershipCommandEnvelope {
  return { type, userId: "test", sessionId: "session", expectedRevision: 0,
    commandId: `test-${type}-${spellId}`,
    payload: { characterId: "eloise", spellId,
      offerId: `projectileSpell:projectile:${spellId}` } };
}

test("Functions player spell allowlist matches Core and store candidates", () => {
  const source = readFileSync(resolve(process.cwd(), "../packages/runner_core/lib/projectiles/projectile_id.dart"), "utf8");
  const list = source.match(/const playerEquippableProjectileIds\s*=\s*<ProjectileId>\[([\s\S]*?)\]/)?.[1];
  assert.ok(list);
  const coreIds = [...list.matchAll(/ProjectileId\.(\w+)/g)].map((m) => m[1]);
  assert.deepEqual(coreIds, [...playerEquippableProjectileIds]);
  assert.deepEqual(storeOfferDefinitions.filter((d) => d.domain === "projectileSpell").map((d) => d.itemId), coreIds);
});

test("unknown and trap-only IDs cannot be learned, equipped or purchased", () => {
  for (const id of ["unknown", "poisonDart", "forgedSpell"]) {
    for (const type of ["learnProjectileSpell", "setProjectileSpell", "purchaseStoreOffer"] as const) {
      const state = starterCanonicalState("default", "test");
      state.progression.gold = 10000;
      const result = applyOwnershipCommand(state, command(type, id));
      assert.equal(result.accepted, false, `${type}: ${id}`);
    }
  }
});

test("Thunder Bolt remains learnable and equippable", () => {
  const learned = applyOwnershipCommand(starterCanonicalState("default", "test"), command("learnProjectileSpell", "thunderBolt"));
  assert.equal(learned.accepted, true);
  if (!learned.accepted) return;
  const equipped = applyOwnershipCommand(learned.canonicalState, command("setProjectileSpell", "thunderBolt"));
  assert.equal(equipped.accepted, true);
});
