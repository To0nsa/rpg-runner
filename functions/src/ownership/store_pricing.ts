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

export const storeSlots = [
  "mainWeapon",
  "offhandWeapon",
  "spellBook",
  "accessory",
  "primary",
  "secondary",
  "projectile",
  "mobility",
  "jump",
  "spell",
] as const;
export type StoreSlot = (typeof storeSlots)[number];

export const storeRefreshMethods = ["gold", "rewardedAd"] as const;
export type StoreRefreshMethod = (typeof storeRefreshMethods)[number];

export interface StoreOfferDefinition {
  bucket: StoreBucket;
  domain: StoreDomain;
  slot: StoreSlot;
  itemId: string;
}

export const storeOfferDefinitions: readonly StoreOfferDefinition[] = [
  // Swords.
  { bucket: "sword", domain: "gear", slot: "mainWeapon", itemId: "plainsteel" },
  { bucket: "sword", domain: "gear", slot: "mainWeapon", itemId: "waspfang" },
  { bucket: "sword", domain: "gear", slot: "mainWeapon", itemId: "cinderedge" },
  { bucket: "sword", domain: "gear", slot: "mainWeapon", itemId: "basiliskKiss" },
  { bucket: "sword", domain: "gear", slot: "mainWeapon", itemId: "frostbrand" },
  { bucket: "sword", domain: "gear", slot: "mainWeapon", itemId: "stormneedle" },
  { bucket: "sword", domain: "gear", slot: "mainWeapon", itemId: "nullblade" },
  { bucket: "sword", domain: "gear", slot: "mainWeapon", itemId: "sunlitVow" },
  // Shields.
  { bucket: "shield", domain: "gear", slot: "offhandWeapon", itemId: "roadguard" },
  { bucket: "shield", domain: "gear", slot: "offhandWeapon", itemId: "thornbark" },
  { bucket: "shield", domain: "gear", slot: "offhandWeapon", itemId: "cinderWard" },
  { bucket: "shield", domain: "gear", slot: "offhandWeapon", itemId: "tideguardShell" },
  { bucket: "shield", domain: "gear", slot: "offhandWeapon", itemId: "frostlockBuckler" },
  { bucket: "shield", domain: "gear", slot: "offhandWeapon", itemId: "ironBastion" },
  { bucket: "shield", domain: "gear", slot: "offhandWeapon", itemId: "stormAegis" },
  { bucket: "shield", domain: "gear", slot: "offhandWeapon", itemId: "nullPrism" },
  { bucket: "shield", domain: "gear", slot: "offhandWeapon", itemId: "warbannerGuard" },
  { bucket: "shield", domain: "gear", slot: "offhandWeapon", itemId: "oathwallRelic" },
  // Accessories.
  { bucket: "accessory", domain: "gear", slot: "accessory", itemId: "speedBoots" },
  { bucket: "accessory", domain: "gear", slot: "accessory", itemId: "goldenRing" },
  { bucket: "accessory", domain: "gear", slot: "accessory", itemId: "teethNecklace" },
  { bucket: "accessory", domain: "gear", slot: "accessory", itemId: "diamondRing" },
  { bucket: "accessory", domain: "gear", slot: "accessory", itemId: "ironBoots" },
  { bucket: "accessory", domain: "gear", slot: "accessory", itemId: "oathBeads" },
  { bucket: "accessory", domain: "gear", slot: "accessory", itemId: "resilienceCape" },
  { bucket: "accessory", domain: "gear", slot: "accessory", itemId: "strengthBelt" },
  // Spellbooks.
  { bucket: "spellBook", domain: "gear", slot: "spellBook", itemId: "apprenticePrimer" },
  { bucket: "spellBook", domain: "gear", slot: "spellBook", itemId: "bastionCodex" },
  { bucket: "spellBook", domain: "gear", slot: "spellBook", itemId: "emberGrimoire" },
  { bucket: "spellBook", domain: "gear", slot: "spellBook", itemId: "tideAlmanac" },
  { bucket: "spellBook", domain: "gear", slot: "spellBook", itemId: "hexboundLexicon" },
  { bucket: "spellBook", domain: "gear", slot: "spellBook", itemId: "galeFolio" },
  { bucket: "spellBook", domain: "gear", slot: "spellBook", itemId: "nullTestament" },
  { bucket: "spellBook", domain: "gear", slot: "spellBook", itemId: "crownOfFocus" },
  // Projectile spells.
  { bucket: "projectileSpell", domain: "projectileSpell", slot: "projectile", itemId: "iceBolt" },
  { bucket: "projectileSpell", domain: "projectileSpell", slot: "projectile", itemId: "fireBolt" },
  { bucket: "projectileSpell", domain: "projectileSpell", slot: "projectile", itemId: "acidBolt" },
  { bucket: "projectileSpell", domain: "projectileSpell", slot: "projectile", itemId: "darkBolt" },
  { bucket: "projectileSpell", domain: "projectileSpell", slot: "projectile", itemId: "earthBolt" },
  { bucket: "projectileSpell", domain: "projectileSpell", slot: "projectile", itemId: "holyBolt" },
  { bucket: "projectileSpell", domain: "projectileSpell", slot: "projectile", itemId: "waterBolt" },
  { bucket: "projectileSpell", domain: "projectileSpell", slot: "projectile", itemId: "thunderBolt" },
  // Spell-slot abilities.
  { bucket: "spell", domain: "ability", slot: "spell", itemId: "eloise.arcane_haste" },
  { bucket: "spell", domain: "ability", slot: "spell", itemId: "eloise.focus" },
  { bucket: "spell", domain: "ability", slot: "spell", itemId: "eloise.arcane_ward" },
  { bucket: "spell", domain: "ability", slot: "spell", itemId: "eloise.cleanse" },
  { bucket: "spell", domain: "ability", slot: "spell", itemId: "eloise.vital_surge" },
  { bucket: "spell", domain: "ability", slot: "spell", itemId: "eloise.mana_infusion" },
  { bucket: "spell", domain: "ability", slot: "spell", itemId: "eloise.second_wind" },
  // Non-spell abilities.
  { bucket: "ability", domain: "ability", slot: "primary", itemId: "eloise.bloodletter_slash" },
  { bucket: "ability", domain: "ability", slot: "primary", itemId: "eloise.bloodletter_cleave" },
  { bucket: "ability", domain: "ability", slot: "primary", itemId: "eloise.seeker_slash" },
  { bucket: "ability", domain: "ability", slot: "secondary", itemId: "eloise.aegis_riposte" },
  { bucket: "ability", domain: "ability", slot: "secondary", itemId: "eloise.shield_block" },
  { bucket: "ability", domain: "ability", slot: "projectile", itemId: "eloise.snap_shot" },
  { bucket: "ability", domain: "ability", slot: "projectile", itemId: "eloise.quick_shot" },
  { bucket: "ability", domain: "ability", slot: "projectile", itemId: "eloise.skewer_shot" },
  { bucket: "ability", domain: "ability", slot: "projectile", itemId: "eloise.overcharge_shot" },
  { bucket: "ability", domain: "ability", slot: "mobility", itemId: "eloise.dash" },
  { bucket: "ability", domain: "ability", slot: "mobility", itemId: "eloise.roll" },
  { bucket: "ability", domain: "ability", slot: "jump", itemId: "eloise.jump" },
  { bucket: "ability", domain: "ability", slot: "jump", itemId: "eloise.double_jump" },
];

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
