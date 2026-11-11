import { createHash } from "node:crypto";
import type { Firestore, Transaction } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import { knownCharacterIds } from "../ownership/character_catalog.js";
import { parseCatalogReward } from "../ownership/catalog_rewards.js";
export { catalogDefinition } from "../ownership/catalog_rewards.js";
import { storeOfferDefinitions } from "../ownership/store_pricing.js";
import type { InboxReward } from "./contracts.js";
import { safeInteger } from "./validators.js";

/** Stable identity for a single unlock; gear is account-wide, skills are character-bound. */
export function inboxRewardKey(reward: InboxReward): string {
  return reward.kind === "gold" ? "gold" : JSON.stringify([reward.kind, reward.slot, reward.itemId, reward.characterId ?? null]);
}

/** Validates the persisted/wire reward union, preserving legacy gold representation. */
export function parseInboxRewards(raw: unknown): InboxReward[] {
  if (!Array.isArray(raw) || raw.length > 9) throw new HttpsError("invalid-argument", "Use at most nine attachments.");
  const rewards = raw.map((value): InboxReward => {
    if (!value || typeof value !== "object" || Array.isArray(value)) throw new HttpsError("invalid-argument", "Invalid attachment.");
    const row = value as Record<string, unknown>;
    if (row.kind === "gold") {
      if (Object.keys(row).some((key) => !["kind", "amount"].includes(key))) throw new HttpsError("invalid-argument", "Unknown gold field.");
      const amount = safeInteger(row.amount, "gold reward");
      if (amount === 0) throw new HttpsError("invalid-argument", "Empty gold attachment.");
      return { kind: "gold", amount };
    }
    return parseCatalogReward(row);
  });
  if (rewards.filter((r) => r.kind !== "gold").length > 8) throw new HttpsError("invalid-argument", "Use at most eight item/skill gifts.");
  if (new Set(rewards.map(inboxRewardKey)).size !== rewards.length) throw new HttpsError("invalid-argument", "Duplicate attachment.");
  return rewards;
}

export const inboxGiftCatalog = storeOfferDefinitions.map(({ domain, slot, itemId }) => ({ kind: domain, slot, itemId }));
export const inboxGiftCatalogHash = createHash("sha256").update(JSON.stringify([2, inboxGiftCatalog, knownCharacterIds])).digest("hex");
export const inboxGiftConfigurationPath = "inbox_configuration/gifts";

/** Missing/mismatched rollout evidence fails closed until the environment is upgraded. */
export function giftsEnabled(raw: Record<string, unknown> | undefined): boolean {
  return raw?.schemaVersion === 1 && raw.enabled === true && raw.catalogHash === inboxGiftCatalogHash;
}

/** Recheck inside issuance so disabling a catalog also invalidates already-open previews. */
export async function assertInboxGiftsEnabled(tx: Transaction, db: Firestore): Promise<void> {
  if (!giftsEnabled((await tx.get(db.doc(inboxGiftConfigurationPath))).data())) {
    throw new HttpsError("failed-precondition", "Item and skill gifts are not enabled for this environment's deployed app and backend.");
  }
}
