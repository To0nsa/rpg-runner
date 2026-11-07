import { isDeepStrictEqual } from "node:util";
import { buildAt, buildUnlockLevels, isBuildUnlocked, record, selectionSchemaVersion, validBuildName } from "./character_builds.js";
import type { JsonObject } from "./contracts.js";
import { knownCharacterIds } from "./defaults.js";
import { characterContentAllowed } from "./character_catalog.js";
import { storeOfferDefinitions, type StoreSlot } from "./store_pricing.js";

const knownLevelIds = ["forest", "field"] as const;
const knownRunModes = ["practice", "competitive", "weekly"] as const;
const allowedLoadoutMask = 0b111;

interface LoadoutField {
  field: string;
  domain: "gear" | "projectileSpell" | "ability";
  slot: StoreSlot;
}

const loadoutFields: readonly LoadoutField[] = [
  { field: "mainWeaponId", domain: "gear", slot: "mainWeapon" },
  { field: "offhandWeaponId", domain: "gear", slot: "offhandWeapon" },
  { field: "spellBookId", domain: "gear", slot: "spellBook" },
  {
    field: "projectileSlotSpellId",
    domain: "projectileSpell",
    slot: "projectile",
  },
  { field: "accessoryId", domain: "gear", slot: "accessory" },
  { field: "abilityPrimaryId", domain: "ability", slot: "primary" },
  { field: "abilitySecondaryId", domain: "ability", slot: "secondary" },
  { field: "abilityProjectileId", domain: "ability", slot: "projectile" },
  { field: "abilitySpellId", domain: "ability", slot: "spell" },
  { field: "abilityMobilityId", domain: "ability", slot: "mobility" },
  { field: "abilityJumpId", domain: "ability", slot: "jump" },
];

export function normalizeAuthorizedSelection(args: {
  selection: unknown;
  meta: JsonObject;
  progression: JsonObject;
  previousSelection?: JsonObject;
}): JsonObject | null {
  const selection = asRecord(args.selection);
  if (selection === null || selection.schemaVersion !== selectionSchemaVersion) return null;
  const levelId = nonEmptyString(selection.levelId);
  const runMode = nonEmptyString(selection.runMode) ?? nonEmptyString(selection.runType);
  const legacyRunType = nonEmptyString(selection.runType);
  const characterId = nonEmptyString(selection.characterId);
  if (levelId === null || !knownLevelIds.includes(levelId as (typeof knownLevelIds)[number]) ||
      runMode === null || !knownRunModes.includes(runMode as (typeof knownRunModes)[number]) ||
      (legacyRunType !== null && legacyRunType !== runMode) ||
      characterId === null || !isKnownCharacterId(characterId)) return null;
  const branches = asRecord(selection.buildsByCharacter);
  if (branches === null) return null;
  const normalizedBranches: JsonObject = {};
  for (const id of knownCharacterIds) {
    const branch = record(branches[id]);
    if (branch === null || !isBuildUnlocked(branch.selectedBuildIndex, args.progression) ||
        !Array.isArray(branch.builds) || branch.builds.length !== buildUnlockLevels.length) return null;
    const builds: JsonObject[] = [];
    for (let index = 0; index < buildUnlockLevels.length; index++) {
      const build = record(branch.builds[index]);
      const name = validBuildName(build?.name);
      const loadout = normalizeAuthorizedLoadout({ loadout: build?.loadout, meta: args.meta, characterId: id });
      if (name === null || loadout === null) return null;
      const normalized = { name, loadout };
      // Locked slots can be carried in a selection, but cannot be edited.
      if (args.previousSelection !== undefined && !isBuildUnlocked(index, args.progression) &&
          !isDeepStrictEqual(normalized, buildAt(args.previousSelection, id, index))) return null;
      builds.push(normalized);
    }
    normalizedBranches[id] = { selectedBuildIndex: branch.selectedBuildIndex, builds };
  }
  return { schemaVersion: selectionSchemaVersion, levelId, runMode, runType: runMode,
    characterId, buildsByCharacter: normalizedBranches };
}

export function normalizeAuthorizedLoadout(args: {
  loadout: unknown;
  meta: JsonObject;
  characterId: string;
}): JsonObject | null {
  if (!isKnownCharacterId(args.characterId)) {
    return null;
  }
  const loadout = asRecord(args.loadout);
  const mask = loadout?.mask;
  if (
    loadout === null ||
    typeof mask !== "number" ||
    !Number.isInteger(mask) ||
    mask < 0 ||
    (mask & ~allowedLoadoutMask) !== 0
  ) {
    return null;
  }

  const normalized: JsonObject = { mask };
  for (const definition of loadoutFields) {
    const itemId = nonEmptyString(loadout[definition.field]);
    if (
      itemId === null ||
      !characterContentAllowed(args.characterId, definition.domain, definition.slot, itemId) ||
      !isKnownContent({
        domain: definition.domain,
        slot: definition.slot,
        itemId,
      }) ||
      !isOwnedContent({
        meta: args.meta,
        characterId: args.characterId,
        domain: definition.domain,
        slot: definition.slot,
        itemId,
      })
    ) {
      return null;
    }
    normalized[definition.field] = itemId;
  }
  return normalized;
}

export function isAuthorizedGear(args: {
  meta: JsonObject;
  characterId: string;
  slot: "mainWeapon" | "offhandWeapon" | "spellBook" | "accessory";
  itemId: string;
}): boolean {
  return (
    characterContentAllowed(args.characterId, "gear", args.slot, args.itemId) &&
    isKnownContent({ domain: "gear", slot: args.slot, itemId: args.itemId }) &&
    isOwnedContent({
      meta: args.meta,
      characterId: args.characterId,
      domain: "gear",
      slot: args.slot,
      itemId: args.itemId,
    })
  );
}

export function isAuthorizedAbility(args: {
  meta: JsonObject;
  characterId: string;
  slot: StoreSlot;
  abilityId: string;
}): boolean {
  return (
    isKnownCharacterId(args.characterId) &&
    characterContentAllowed(args.characterId, "ability", args.slot, args.abilityId) &&
    isKnownContent({
      domain: "ability",
      slot: args.slot,
      itemId: args.abilityId,
    }) &&
    isOwnedContent({
      meta: args.meta,
      characterId: args.characterId,
      domain: "ability",
      slot: args.slot,
      itemId: args.abilityId,
    })
  );
}

export function isAuthorizedProjectileSpell(args: {
  meta: JsonObject;
  characterId: string;
  spellId: string;
}): boolean {
  return (
    isKnownCharacterId(args.characterId) &&
    characterContentAllowed(args.characterId, "projectileSpell", "projectile", args.spellId) &&
    isKnownContent({
      domain: "projectileSpell",
      slot: "projectile",
      itemId: args.spellId,
    }) &&
    isOwnedContent({
      meta: args.meta,
      characterId: args.characterId,
      domain: "projectileSpell",
      slot: "projectile",
      itemId: args.spellId,
    })
  );
}

function isKnownContent(args: {
  domain: "gear" | "projectileSpell" | "ability";
  slot: StoreSlot;
  itemId: string;
}): boolean {
  return storeOfferDefinitions.some(
    (definition) =>
      definition.domain === args.domain &&
      definition.slot === args.slot &&
      definition.itemId === args.itemId,
  );
}

function isOwnedContent(args: {
  meta: JsonObject;
  characterId: string;
  domain: "gear" | "projectileSpell" | "ability";
  slot: StoreSlot;
  itemId: string;
}): boolean {
  const meta = asRecord(args.meta);
  if (meta === null) {
    return false;
  }
  if (args.domain === "gear") {
    const inventory = asRecord(meta.inventory);
    if (inventory === null) {
      return false;
    }
    const inventoryField = gearInventoryField(args.slot);
    return (
      inventoryField !== null &&
      readStringList(inventory[inventoryField]).includes(args.itemId)
    );
  }

  const ownershipByCharacter = asRecord(meta.abilityOwnershipByCharacter);
  const ownership = ownershipByCharacter === null
    ? null
    : asRecord(ownershipByCharacter[args.characterId]);
  if (ownership === null) {
    return false;
  }
  if (args.domain === "projectileSpell") {
    return readStringList(ownership.projectileSpells).includes(args.itemId);
  }
  const abilitiesBySlot = asRecord(ownership.abilitiesBySlot);
  return (
    abilitiesBySlot !== null &&
    readStringList(abilitiesBySlot[args.slot]).includes(args.itemId)
  );
}

function gearInventoryField(slot: StoreSlot): string | null {
  switch (slot) {
    case "mainWeapon":
    case "offhandWeapon":
      return "weapons";
    case "spellBook":
      return "spellBooks";
    case "accessory":
      return "accessories";
    default:
      return null;
  }
}

function isKnownCharacterId(value: string): boolean {
  return knownCharacterIds.includes(
    value as (typeof knownCharacterIds)[number],
  );
}

function asRecord(value: unknown): Record<string, unknown> | null {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, unknown>;
}

function nonEmptyString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function readStringList(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.filter(
    (entry): entry is string =>
      typeof entry === "string" && entry.trim().length > 0,
  );
}
