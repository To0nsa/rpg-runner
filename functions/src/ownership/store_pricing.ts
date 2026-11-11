import { coreCatalog, coreGearSlots, coreAbilitySlots } from "./core_catalog.generated.js";

export const defaultPriceGold = 150;

export const storeBuckets = [
  "sword",
  "shield",
  "accessory",
  "spellBook",
  "projectileSpell",
  "spell",
  "ability",
] as const;
export type StoreBucket = (typeof storeBuckets)[number];

export const storeDomains = ["gear", "projectileSpell", "ability"] as const;
export type StoreDomain = (typeof storeDomains)[number];

export const storeSlots = [...coreGearSlots, ...coreAbilitySlots] as const;
export type StoreSlot = (typeof storeSlots)[number];

export const storeRefreshMethods = ["gold", "rewardedAd"] as const;
export type StoreRefreshMethod = (typeof storeRefreshMethods)[number];

export interface StoreOfferDefinition {
  bucket: StoreBucket;
  domain: StoreDomain;
  slot: StoreSlot;
  itemId: string;
}

// Buckets and prices are backend economy policy; membership comes only from Core.
const gearBuckets = {
  mainWeapon: "sword", offhandWeapon: "shield", spellBook: "spellBook", accessory: "accessory",
} as const;
export const storeOfferDefinitions: readonly StoreOfferDefinition[] = coreCatalog.map(
  ({ domain, slot, itemId }): StoreOfferDefinition => ({
    bucket: domain === "gear" ? gearBuckets[slot] :
      domain === "projectileSpell" ? "projectileSpell" : slot === "spell" ? "spell" : "ability",
    domain, slot, itemId,
  }),
);

const storeDefinitionsByBucket = new Map<StoreBucket, StoreOfferDefinition[]>();
for (const bucket of storeBuckets) {
  storeDefinitionsByBucket.set(bucket, []);
}
for (const definition of storeOfferDefinitions) {
  storeDefinitionsByBucket.get(definition.bucket)?.push(definition);
}

const storePriceByKey = new Map<string, number>();
for (const definition of storeOfferDefinitions) {
  storePriceByKey.set(storePricingKey(definition), defaultPriceGold);
}

export function isStoreBucket(value: string): value is StoreBucket {
  return (storeBuckets as readonly string[]).includes(value);
}

export function isStoreDomain(value: string): value is StoreDomain {
  return (storeDomains as readonly string[]).includes(value);
}

export function isStoreSlot(value: string): value is StoreSlot {
  return (storeSlots as readonly string[]).includes(value);
}

export function isStoreRefreshMethod(value: string): value is StoreRefreshMethod {
  return (storeRefreshMethods as readonly string[]).includes(value);
}

export function storePricingKey(definition: StoreOfferDefinition): string {
  return `${definition.domain}:${definition.slot}:${definition.itemId}`;
}

export function storeOfferId(definition: StoreOfferDefinition): string {
  return `${definition.domain}:${definition.slot}:${definition.itemId}`;
}

export function resolveStorePriceGold(definition: StoreOfferDefinition): number {
  return storePriceByKey.get(storePricingKey(definition)) ?? defaultPriceGold;
}

export function storeDefinitionsForBucket(
  bucket: StoreBucket,
): readonly StoreOfferDefinition[] {
  return storeDefinitionsByBucket.get(bucket) ?? [];
}
