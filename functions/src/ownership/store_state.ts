import type { JsonObject, OwnershipRejectedReason } from "./contracts.js";
import { sha256Hex } from "./hash.js";
import {
  type StoreBucket,
  type StoreDomain,
  type StoreOfferDefinition,
  type StoreRefreshMethod,
  type StoreSlot,
  isStoreBucket,
  isStoreDomain,
  isStoreRefreshMethod,
  isStoreSlot,
  resolveStorePriceGold,
  storeBuckets,
  storeDefinitionsForBucket,
  storeOfferId,
} from "./store_pricing.js";

export interface StoreOffer {
  offerId: string;
  bucket: StoreBucket;
  domain: StoreDomain;
  slot: StoreSlot;
  itemId: string;
  priceGold: number;
}

export interface StoreState {
  schemaVersion: number;
  generation: number;
  refreshDayKeyUtc: string;
  refreshesUsedToday: number;
  activeOffers: StoreOffer[];
}

export interface PurchaseStoreOfferResult {
  accepted: boolean;
  rejectedReason?: OwnershipRejectedReason;
}

export interface RefreshStoreResult {
  accepted: boolean;
  rejectedReason?: OwnershipRejectedReason;
}

const storeSchemaVersion = 1;
const storeRefreshLimitPerDay = 3;
const goldRefreshCost = 50;

const abilitySlots: readonly StoreSlot[] = [
  "primary",
  "secondary",
  "projectile",
  "mobility",
  "jump",
  "spell",
];

interface OwnershipSnapshot {
  selectedCharacterId: string;
  inventoryWeapons: Set<string>;
  inventorySpellBooks: Set<string>;
  inventoryAccessories: Set<string>;
  learnedProjectileSpells: Set<string>;
  learnedAbilityIdsBySlot: Map<StoreSlot, Set<string>>;
}

export function normalizeProgressionStore(args: {
  progression: JsonObject;
  meta: JsonObject;
  selection: JsonObject;
  userId: string;
  nowMs: number;
}): void {
  const progressionRecord = asRecord(args.progression);
  if (progressionRecord === null) {
    return;
  }
  const store = normalizeStoreState({
    storeRaw: progressionRecord.store,
    meta: args.meta,
    selection: args.selection,
    userId: args.userId,
    nowMs: args.nowMs,
  });
  progressionRecord.store = storeToJson(store);
}

export function purchaseStoreOffer(args: {
  progression: JsonObject;
  meta: JsonObject;
  selection: JsonObject;
  userId: string;
  offerId: string;
  nowMs: number;
}): PurchaseStoreOfferResult {
  const progression = asRecord(args.progression);
  const meta = asRecord(args.meta);
  const selection = asRecord(args.selection);
  if (progression === null || meta === null || selection === null) {
    return { accepted: false, rejectedReason: "invalidCommand" };
  }

  const store = normalizeStoreState({
    storeRaw: progression.store,
    meta: args.meta,
    selection: args.selection,
    userId: args.userId,
    nowMs: args.nowMs,
  });
  const offer = store.activeOffers.find((value) => value.offerId === args.offerId);
  if (!offer) {
    return { accepted: false, rejectedReason: "offerUnavailable" };
  }

  const ownershipBefore = buildOwnershipSnapshot(args.meta, args.selection);
  if (isDefinitionOwned(offer, ownershipBefore)) {
    return { accepted: false, rejectedReason: "alreadyOwned" };
  }

  const currentGold = integerValue(progression.gold) ?? 0;
  if (currentGold < offer.priceGold) {
    return { accepted: false, rejectedReason: "insufficientGold" };
  }

  progression.gold = currentGold - offer.priceGold;
  grantOwnership({
    meta,
    selectedCharacterId: ownershipBefore.selectedCharacterId,
    offer,
  });

  const ownershipAfter = buildOwnershipSnapshot(args.meta, args.selection);
  const nextOffers = store.activeOffers.filter(
    (value) => value.offerId !== offer.offerId,
  );
  const backfill = pickOfferForBucket({
    bucket: offer.bucket,
    userId: args.userId,
    generation: store.generation,
    ownership: ownershipAfter,
    seedSuffix: `purchase:${offer.offerId}`,
  });
  if (backfill) {
    nextOffers.push(backfill);
  }
  store.activeOffers = sortOffersByBucket(nextOffers);
  progression.store = storeToJson(store);
  return { accepted: true };
}

export function refreshStore(args: {
  progression: JsonObject;
  meta: JsonObject;
  selection: JsonObject;
  userId: string;
  method: StoreRefreshMethod;
  nowMs: number;
}): RefreshStoreResult {
  const progression = asRecord(args.progression);
  if (progression === null) {
    return { accepted: false, rejectedReason: "invalidCommand" };
  }

  const store = normalizeStoreState({
    storeRaw: progression.store,
    meta: args.meta,
    selection: args.selection,
    userId: args.userId,
    nowMs: args.nowMs,
  });
  const utcDayKey = utcDayKeyForMs(args.nowMs);
  if (store.refreshDayKeyUtc !== utcDayKey) {
    store.refreshDayKeyUtc = utcDayKey;
    store.refreshesUsedToday = 0;
  }
  if (store.refreshesUsedToday >= storeRefreshLimitPerDay) {
    return { accepted: false, rejectedReason: "refreshLimitReached" };
  }

  if (args.method === "rewardedAd") {
    return { accepted: false, rejectedReason: "rewardNotVerified" };
  }
  if (!isStoreRefreshMethod(args.method)) {
    return { accepted: false, rejectedReason: "invalidRefreshMethod" };
  }

  const currentGold = integerValue(progression.gold) ?? 0;
  if (currentGold < goldRefreshCost) {
    return { accepted: false, rejectedReason: "insufficientGold" };
  }

  const ownership = buildOwnershipSnapshot(args.meta, args.selection);
  const existingByBucket = new Map<StoreBucket, StoreOffer>();
  for (const offer of store.activeOffers) {
    existingByBucket.set(offer.bucket, offer);
  }
  const rerollGeneration = store.generation + 1;
  const nextOffers = new Map<StoreBucket, StoreOffer>();
  let changed = false;

  for (const bucket of storeBuckets) {
    const existing = existingByBucket.get(bucket);
    if (!existing) {
      // Sold-out buckets remain sold-out on refresh.
      continue;
    }

    const alternates = eligibleDefinitionsForBucket({
      bucket,
      ownership,
      excludedItemId: existing.itemId,
    });
    if (alternates.length === 0) {
      nextOffers.set(bucket, existing);
      continue;
    }
    const replacement = pickDeterministicDefinition(
      alternates,
      `${args.userId}:${rerollGeneration}:${bucket}:refresh`,
    );
    const nextOffer = offerFromDefinition(replacement);
    nextOffers.set(bucket, nextOffer);
    changed = changed || nextOffer.offerId !== existing.offerId;
  }

  if (!changed) {
    return { accepted: false, rejectedReason: "nothingToRefresh" };
  }

  progression.gold = currentGold - goldRefreshCost;
  store.generation = rerollGeneration;
  store.refreshDayKeyUtc = utcDayKey;
  store.refreshesUsedToday += 1;
  store.activeOffers = sortOffersByBucket(Array.from(nextOffers.values()));
  progression.store = storeToJson(store);
  return { accepted: true };
}

export function isStoreRefreshMethodValue(value: string): value is StoreRefreshMethod {
  return isStoreRefreshMethod(value);
}

export function goldRefreshCostValue(): number {
  return goldRefreshCost;
}

export function storeRefreshLimitPerDayValue(): number {
  return storeRefreshLimitPerDay;
}

function normalizeStoreState(args: {
  storeRaw: unknown;
  meta: JsonObject;
  selection: JsonObject;
  userId: string;
  nowMs: number;
}): StoreState {
  const fallbackDayKey = utcDayKeyForMs(args.nowMs);
  const snapshot = buildOwnershipSnapshot(args.meta, args.selection);
  const candidate = asRecord(args.storeRaw);
  const generation =
    candidate && integerValue(candidate.generation) !== null
      ? Math.max(0, integerValue(candidate.generation) ?? 0)
      : 0;
  const refreshesUsedTodayRaw =
    candidate && integerValue(candidate.refreshesUsedToday) !== null
      ? Math.max(0, integerValue(candidate.refreshesUsedToday) ?? 0)
      : 0;
  const refreshDayKeyRaw =
    candidate && typeof candidate.refreshDayKeyUtc === "string"
      ? candidate.refreshDayKeyUtc
      : fallbackDayKey;
  const refreshDayKeyUtc =
    refreshDayKeyRaw === fallbackDayKey ? refreshDayKeyRaw : fallbackDayKey;
  const refreshesUsedToday =
    refreshDayKeyRaw === fallbackDayKey ? refreshesUsedTodayRaw : 0;
  const activeOffers = parseStoreOffers(candidate?.activeOffers).filter(
    (offer) => !isDefinitionOwned(offer, snapshot),
  );

  const offersByBucket = new Map<StoreBucket, StoreOffer>();
  for (const offer of activeOffers) {
    offersByBucket.set(offer.bucket, offer);
  }
  for (const bucket of storeBuckets) {
    if (offersByBucket.has(bucket)) continue;
    const seeded = pickOfferForBucket({
      bucket,
      userId: args.userId,
      generation,
      ownership: snapshot,
      seedSuffix: "seed",
    });
    if (seeded) {
      offersByBucket.set(bucket, seeded);
    }
  }

  return {
    schemaVersion: storeSchemaVersion,
    generation,
    refreshDayKeyUtc,
    refreshesUsedToday,
    activeOffers: sortOffersByBucket(Array.from(offersByBucket.values())),
  };
}

function storeToJson(store: StoreState): JsonObject {
  return {
    schemaVersion: store.schemaVersion,
    generation: store.generation,
    refreshDayKeyUtc: store.refreshDayKeyUtc,
    refreshesUsedToday: store.refreshesUsedToday,
    activeOffers: store.activeOffers.map((offer) => ({
      offerId: offer.offerId,
      bucket: offer.bucket,
      domain: offer.domain,
      slot: offer.slot,
      itemId: offer.itemId,
      priceGold: offer.priceGold,
    })),
  };
}

function parseStoreOffers(raw: unknown): StoreOffer[] {
  if (!Array.isArray(raw)) {
    return [];
  }
  const offersByBucket = new Map<StoreBucket, StoreOffer>();
  for (const value of raw) {
    const candidate = asRecord(value);
    if (!candidate) continue;
    const bucketRaw = candidate.bucket;
    const domainRaw = candidate.domain;
    const slotRaw = candidate.slot;
    const itemIdRaw = candidate.itemId;
    const offerIdRaw = candidate.offerId;
    const priceRaw = integerValue(candidate.priceGold);
    if (
      typeof bucketRaw !== "string" ||
      !isStoreBucket(bucketRaw) ||
      typeof domainRaw !== "string" ||
      !isStoreDomain(domainRaw) ||
      typeof slotRaw !== "string" ||
      !isStoreSlot(slotRaw) ||
      typeof itemIdRaw !== "string" ||
      itemIdRaw.trim().length === 0 ||
      priceRaw === null ||
      priceRaw <= 0
    ) {
      continue;
    }
    const definition: StoreOfferDefinition = {
      bucket: bucketRaw,
      domain: domainRaw,
      slot: slotRaw,
      itemId: itemIdRaw,
    };
    const offer: StoreOffer = {
      offerId: typeof offerIdRaw === "string" ? offerIdRaw : storeOfferId(definition),
      bucket: definition.bucket,
      domain: definition.domain,
      slot: definition.slot,
      itemId: definition.itemId,
      priceGold: priceRaw,
    };
    offersByBucket.set(offer.bucket, offer);
  }
  return sortOffersByBucket(Array.from(offersByBucket.values()));
}

function buildOwnershipSnapshot(meta: JsonObject, selection: JsonObject): OwnershipSnapshot {
  const metaRecord = asRecord(meta) ?? {};
  const selectionRecord = asRecord(selection) ?? {};
  const selectedCharacterId = readSelectedCharacterId(selectionRecord);

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

function pickOfferForBucket(args: {
  bucket: StoreBucket;
  userId: string;
  generation: number;
  ownership: OwnershipSnapshot;
  seedSuffix: string;
}): StoreOffer | null {
  const candidates = eligibleDefinitionsForBucket({
    bucket: args.bucket,
    ownership: args.ownership,
  });
  if (candidates.length === 0) {
    return null;
  }
  const definition = pickDeterministicDefinition(
    candidates,
    `${args.userId}:${args.generation}:${args.bucket}:${args.seedSuffix}`,
  );
  return offerFromDefinition(definition);
}

function eligibleDefinitionsForBucket(args: {
  bucket: StoreBucket;
  ownership: OwnershipSnapshot;
  excludedItemId?: string;
}): StoreOfferDefinition[] {
  return storeDefinitionsForBucket(args.bucket).filter((definition) => {
    if (args.excludedItemId && definition.itemId === args.excludedItemId) {
      return false;
    }
    return !isDefinitionOwned(definition, args.ownership);
  });
}

function pickDeterministicDefinition(
  candidates: readonly StoreOfferDefinition[],
  seed: string,
): StoreOfferDefinition {
  const ordered = [...candidates].sort((a, b) =>
    storeOfferId(a).localeCompare(storeOfferId(b)),
  );
  const hash = sha256Hex(seed);
  const head = hash.slice(0, 8);
  const index = Number.parseInt(head, 16) % ordered.length;
  return ordered[index]!;
}

function offerFromDefinition(definition: StoreOfferDefinition): StoreOffer {
  return {
    offerId: storeOfferId(definition),
    bucket: definition.bucket,
    domain: definition.domain,
    slot: definition.slot,
    itemId: definition.itemId,
    priceGold: resolveStorePriceGold(definition),
  };
}

function grantOwnership(args: {
  meta: Record<string, unknown>;
  selectedCharacterId: string;
  offer: StoreOffer;
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

function grantGearOwnership(meta: Record<string, unknown>, offer: StoreOffer): void {
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

function sortOffersByBucket(offers: StoreOffer[]): StoreOffer[] {
  const order = new Map<StoreBucket, number>();
  for (let i = 0; i < storeBuckets.length; i += 1) {
    order.set(storeBuckets[i]!, i);
  }
  return [...offers].sort((a, b) => {
    const left = order.get(a.bucket) ?? Number.MAX_SAFE_INTEGER;
    const right = order.get(b.bucket) ?? Number.MAX_SAFE_INTEGER;
    if (left !== right) {
      return left - right;
    }
    return a.offerId.localeCompare(b.offerId);
  });
}

function utcDayKeyForMs(nowMs: number): string {
  const now = new Date(nowMs);
  const year = now.getUTCFullYear().toString().padStart(4, "0");
  const month = (now.getUTCMonth() + 1).toString().padStart(2, "0");
  const day = now.getUTCDate().toString().padStart(2, "0");
  return `${year}-${month}-${day}`;
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
