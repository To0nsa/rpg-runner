import type { JsonObject, OwnershipRejectedReason } from "./contracts.js";
import { characterContentAllowed, knownCharacterIds } from "./character_catalog.js";
import {
  type StoreBucket, type StoreDomain, type StoreOfferDefinition,
  type StoreRefreshMethod, type StoreSlot, isStoreRefreshMethod,
  resolveStorePriceGold, storeBuckets, storeOfferDefinitions, storeOfferId,
} from "./store_pricing.js";

export interface StoreOffer {
  offerId: string;
  bucket: StoreBucket;
  domain: StoreDomain;
  slot: StoreSlot;
  itemId: string;
  priceGold: number;
}

/** Permanent server-priced entries, including owned items, for character browsing. */
export interface CatalogOffer extends StoreOffer {
  characterIds: string[];
}

export interface StoreState {
  schemaVersion: number;
  generation: number;
  refreshDayKeyUtc: string;
  refreshesUsedToday: number;
  /** One unowned entry per bucket for retained clients. Never paid-reroll stock. */
  activeOffers: StoreOffer[];
  catalogOffers: CatalogOffer[];
}

export interface PurchaseStoreOfferResult {
  accepted: boolean;
  rejectedReason?: OwnershipRejectedReason;
}
export type RefreshStoreResult = PurchaseStoreOfferResult;

const abilitySlots: readonly StoreSlot[] = [
  "primary", "secondary", "projectile", "mobility", "jump", "spell",
];
interface OwnershipSnapshot {
  selectedCharacterId: string;
  inventoryWeapons: Set<string>;
  inventorySpellBooks: Set<string>;
  inventoryAccessories: Set<string>;
  learnedProjectileSpells: Set<string>;
  learnedAbilityIdsBySlot: Map<StoreSlot, Set<string>>;
}

/** Rebuild from authoritative definitions; retained offers/prices never grant access. */
export function normalizeProgressionStore(args: {
  progression: JsonObject; meta: JsonObject; selection: JsonObject;
  userId: string; nowMs: number;
}): void {
  const snapshot = buildOwnershipSnapshot(args.meta, args.selection);
  const catalogOffers = [...storeOfferDefinitions]
    .sort((a, b) => storeBuckets.indexOf(a.bucket) - storeBuckets.indexOf(b.bucket) ||
      storeOfferId(a).localeCompare(storeOfferId(b)))
    .map((definition) => ({
      ...definition, offerId: storeOfferId(definition),
      priceGold: resolveStorePriceGold(definition),
      characterIds: knownCharacterIds.filter((id) =>
        characterContentAllowed(id, definition.domain, definition.slot, definition.itemId)),
    }));
  const activeOffers = new Map<StoreBucket, StoreOffer>();
  for (const offer of catalogOffers) {
    if (!activeOffers.has(offer.bucket) &&
        characterContentAllowed(snapshot.selectedCharacterId, offer.domain, offer.slot, offer.itemId) &&
        !isDefinitionOwned(offer, snapshot)) {
      const { characterIds: _characterIds, ...legacyOffer } = offer;
      activeOffers.set(offer.bucket, legacyOffer);
    }
  }
  args.progression.store = {
    schemaVersion: 2, generation: 0, refreshDayKeyUtc: "", refreshesUsedToday: 0,
    activeOffers: [...activeOffers.values()].map((offer) => ({ ...offer })),
    catalogOffers,
  };
}

/** Buys for an explicit character without changing selection; absent targets retain legacy semantics. */
export function purchaseStoreOffer(args: {
  progression: JsonObject; meta: JsonObject; selection: JsonObject;
  userId: string; offerId: string; characterId?: string; nowMs: number;
}): PurchaseStoreOfferResult {
  const offer = storeOfferDefinitions.find((value) => storeOfferId(value) === args.offerId);
  const ownership = buildOwnershipSnapshot(args.meta, args.selection, args.characterId);
  if (!offer || !characterContentAllowed(ownership.selectedCharacterId, offer.domain, offer.slot, offer.itemId)) {
    return { accepted: false, rejectedReason: "offerUnavailable" };
  }
  if (isDefinitionOwned(offer, ownership)) {
    return { accepted: false, rejectedReason: "alreadyOwned" };
  }
  const priceGold = resolveStorePriceGold(offer);
  const currentGold = integerValue(args.progression.gold) ?? 0;
  if (currentGold < priceGold) {
    return { accepted: false, rejectedReason: "insufficientGold" };
  }
  args.progression.gold = currentGold - priceGold;
  grantCatalogOwnership({ meta: args.meta, selectedCharacterId: ownership.selectedCharacterId, offer });
  normalizeProgressionStore(args);
  return { accepted: true };
}

/** Retained clients cannot spend gold refreshing the permanent catalogue. */
export function refreshStore(_args: {
  progression: JsonObject; meta: JsonObject; selection: JsonObject;
  userId: string; method: StoreRefreshMethod; nowMs: number;
}): RefreshStoreResult {
  return { accepted: false, rejectedReason: "nothingToRefresh" };
}

export function isStoreRefreshMethodValue(value: string): value is StoreRefreshMethod {
  return isStoreRefreshMethod(value);
}

function buildOwnershipSnapshot(meta: JsonObject, selection: JsonObject, characterId?: string): OwnershipSnapshot {
  const metaRecord = asRecord(meta) ?? {};
  const selectionRecord = asRecord(selection) ?? {};
  const selectedCharacterId = characterId ?? readSelectedCharacterId(selectionRecord);

  const inventory = asRecord(metaRecord.inventory) ?? {};
  const inventoryWeapons = new Set(readStringList(inventory.weapons));
  const inventorySpellBooks = new Set(readStringList(inventory.spellBooks));
  const inventoryAccessories = new Set(readStringList(inventory.accessories));

  const ownershipByCharacter = asRecord(metaRecord.abilityOwnershipByCharacter) ?? {};
  const selectedOwnership = asRecord(ownershipByCharacter[selectedCharacterId]) ?? {};
  const learnedProjectileSpells = new Set(
    readStringList(selectedOwnership.projectileSpells),
  );
  const abilitiesBySlot = asRecord(selectedOwnership.abilitiesBySlot) ?? {};
  const learnedAbilityIdsBySlot = new Map<StoreSlot, Set<string>>();
  for (const slot of abilitySlots) {
    learnedAbilityIdsBySlot.set(slot, new Set(readStringList(abilitiesBySlot[slot])));
  }

  return {
    selectedCharacterId,
    inventoryWeapons,
    inventorySpellBooks,
    inventoryAccessories,
    learnedProjectileSpells,
    learnedAbilityIdsBySlot,
  };
}

function readSelectedCharacterId(selection: Record<string, unknown>): string {
  const raw = selection.characterId;
  if (typeof raw !== "string" || raw.trim().length === 0) {
    return "eloise";
  }
  return raw.trim();
}

function isDefinitionOwned(
  definition: Pick<StoreOfferDefinition, "domain" | "slot" | "itemId">,
  snapshot: OwnershipSnapshot,
): boolean {
  switch (definition.domain) {
    case "gear":
      switch (definition.slot) {
        case "mainWeapon":
        case "offhandWeapon":
          return snapshot.inventoryWeapons.has(definition.itemId);
        case "spellBook":
          return snapshot.inventorySpellBooks.has(definition.itemId);
        case "accessory":
          return snapshot.inventoryAccessories.has(definition.itemId);
        default:
          return false;
      }
    case "projectileSpell":
      return snapshot.learnedProjectileSpells.has(definition.itemId);
    case "ability":
      return (
        snapshot.learnedAbilityIdsBySlot.get(definition.slot)?.has(definition.itemId) ??
        false
      );
  }
}

/** Applies a validated catalog unlock to canonical meta; duplicate unlocks are harmless. */
export function grantCatalogOwnership(args: {
  meta: Record<string, unknown>;
  selectedCharacterId: string;
  offer: StoreOfferDefinition;
}): void {
  switch (args.offer.domain) {
    case "gear":
      grantGearOwnership(args.meta, args.offer);
      return;
    case "projectileSpell":
      grantProjectileSpellOwnership(args.meta, args.selectedCharacterId, args.offer.itemId);
      return;
    case "ability":
      grantAbilityOwnership(
        args.meta,
        args.selectedCharacterId,
        args.offer.slot,
        args.offer.itemId,
      );
      return;
  }
}

function grantGearOwnership(meta: Record<string, unknown>, offer: StoreOfferDefinition): void {
  const inventory = ensureMap(meta, "inventory");
  switch (offer.slot) {
    case "mainWeapon":
    case "offhandWeapon":
      addUnique(ensureStringList(inventory, "weapons"), offer.itemId);
      return;
    case "spellBook":
      addUnique(ensureStringList(inventory, "spellBooks"), offer.itemId);
      return;
    case "accessory":
      addUnique(ensureStringList(inventory, "accessories"), offer.itemId);
      return;
    default:
      return;
  }
}

function grantProjectileSpellOwnership(
  meta: Record<string, unknown>,
  characterId: string,
  projectileSpellId: string,
): void {
  const abilityOwnershipByCharacter = ensureMap(meta, "abilityOwnershipByCharacter");
  const ownership = ensureMap(abilityOwnershipByCharacter, characterId);
  const projectileSpells = ensureStringList(ownership, "projectileSpells");
  addUnique(projectileSpells, projectileSpellId);
}

function grantAbilityOwnership(
  meta: Record<string, unknown>,
  characterId: string,
  slot: StoreSlot,
  abilityId: string,
): void {
  const abilityOwnershipByCharacter = ensureMap(meta, "abilityOwnershipByCharacter");
  const ownership = ensureMap(abilityOwnershipByCharacter, characterId);
  const abilitiesBySlot = ensureMap(ownership, "abilitiesBySlot");
  const abilityIds = ensureStringList(abilitiesBySlot, slot);
  addUnique(abilityIds, abilityId);
}

function asRecord(value: unknown): Record<string, unknown> | null {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, unknown>;
}

function integerValue(value: unknown): number | null {
  if (typeof value !== "number" || !Number.isInteger(value)) {
    return null;
  }
  return value;
}

function readStringList(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  const out: string[] = [];
  for (const item of value) {
    if (typeof item === "string" && item.trim().length > 0) {
      out.push(item.trim());
    }
  }
  return out;
}

function ensureMap(parent: Record<string, unknown>, key: string): Record<string, unknown> {
  const existing = asRecord(parent[key]);
  if (existing !== null) {
    return existing;
  }
  const created: Record<string, unknown> = {};
  parent[key] = created;
  return created;
}

function ensureStringList(parent: Record<string, unknown>, key: string): string[] {
  const raw = parent[key];
  if (Array.isArray(raw)) {
    const out = readStringList(raw);
    parent[key] = out;
    return out;
  }
  const created: string[] = [];
  parent[key] = created;
  return created;
}

function addUnique(values: string[], value: string): void {
  if (!values.includes(value)) {
    values.push(value);
  }
}
