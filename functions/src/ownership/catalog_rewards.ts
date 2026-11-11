import { HttpsError } from "firebase-functions/v2/https";
import { characterContentAllowed, knownCharacterIds } from "./character_catalog.js";
import { storeOfferDefinitions, type StoreOfferDefinition } from "./store_pricing.js";

/** Account-wide gear or a skill assigned to an explicit character. */
export interface CatalogReward {
  kind: "gear" | "ability" | "projectileSpell";
  itemId: string;
  slot: string;
  characterId?: string;
}

/** The store, gifts and campaign share one allowlist; callers cannot invent items or slots. */
export function catalogDefinition(reward: CatalogReward): StoreOfferDefinition {
  const definition = storeOfferDefinitions.find((entry) => entry.domain === reward.kind &&
    entry.slot === reward.slot && entry.itemId === reward.itemId);
  if (!definition) throw new HttpsError("invalid-argument", "Unknown gift item or skill slot.");
  return definition;
}

/** Shared validation for authored campaign rewards and Admin gifts. */
export function parseCatalogReward(value: unknown): CatalogReward {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new HttpsError("invalid-argument", "Invalid catalog reward.");
  const row = value as Record<string, unknown>;
  if (!["gear", "ability", "projectileSpell"].includes(row.kind as string)) throw new HttpsError("invalid-argument", "Unsupported reward type.");
  const allowed = row.kind === "gear" ? ["kind", "itemId", "slot"] : ["kind", "itemId", "slot", "characterId"];
  if (Object.keys(row).some((key) => !allowed.includes(key))) throw new HttpsError("invalid-argument", "Unknown attachment field.");
  const reward: CatalogReward = { kind: row.kind as CatalogReward["kind"],
    itemId: identityText(row.itemId, "itemId", 100), slot: identityText(row.slot, "slot", 40) };
  if (reward.kind !== "gear") {
    reward.characterId = identityText(row.characterId, "characterId", 100);
    if (!(knownCharacterIds as readonly string[]).includes(reward.characterId)) throw new HttpsError("invalid-argument", "Unknown gift character.");
    if (!characterContentAllowed(reward.characterId, reward.kind, reward.slot, reward.itemId)) throw new HttpsError("invalid-argument", "Gift does not belong to this character.");
  }
  catalogDefinition(reward);
  return reward;
}

function identityText(raw: unknown, field: string, max: number): string {
  if (typeof raw !== "string" || raw.trim().length === 0 || raw.length > max) {
    throw new HttpsError("invalid-argument", `Invalid ${field}.`);
  }
  return raw.trim();
}
