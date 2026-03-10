import type {
  JsonObject,
  OwnershipCanonicalState,
  OwnershipCommandEnvelope,
  OwnershipRejectedReason,
} from "./contracts.js";
import {
  knownCharacterIds,
  normalizeCanonicalState,
  starterCanonicalState,
} from "./defaults.js";

export type ApplyCommandResult =
  | {
      accepted: true;
      canonicalState: OwnershipCanonicalState;
    }
  | {
      accepted: false;
      rejectedReason: OwnershipRejectedReason;
    };

export function applyOwnershipCommand(
  canonical: OwnershipCanonicalState,
  command: OwnershipCommandEnvelope,
): ApplyCommandResult {
  const state = normalizeCanonicalState(canonical, command.profileId);
  const payload = asRecord(command.payload);
  if (payload === null) {
    return rejected("invalidCommand");
  }

  switch (command.type) {
    case "setSelection":
      return applySetSelection(state, payload);
    case "resetOwnership":
      return accepted({
        ...starterCanonicalState(command.profileId),
        revision: state.revision,
      });
    case "setLoadout":
      return applySetLoadout(state, payload);
    case "equipGear":
      return applyEquipGear(state, payload);
    case "setAbilitySlot":
      return applySetAbilitySlot(state, payload);
    case "setProjectileSpell":
      return applySetProjectileSpell(state, payload);
    case "learnProjectileSpell":
      return applyLearnProjectileSpell(state, payload);
    case "learnSpellAbility":
      return applyLearnSpellAbility(state, payload);
    case "unlockGear":
      return applyUnlockGear(state, payload);
  }
}

function applySetSelection(
  canonical: OwnershipCanonicalState,
  payload: Record<string, unknown>,
): ApplyCommandResult {
  const selection = asJsonObject(payload.selection);
  if (selection === null) {
    return rejected("invalidCommand");
  }
  return accepted({
    ...canonical,
    selection,
  });
}

function applySetLoadout(
  canonical: OwnershipCanonicalState,
  payload: Record<string, unknown>,
): ApplyCommandResult {
  const characterId = nonEmptyString(payload.characterId);
  const loadout = asRecord(payload.loadout);
  if (characterId === null || loadout === null) {
    return rejected("invalidCommand");
  }
  if (!isKnownCharacterId(characterId)) {
    return rejected("invalidCommand");
  }
  const selection = ensureSelectionObject(canonical.selection);
  const loadouts = ensureMap(selection, "loadoutsByCharacter");
  loadouts[characterId] = structuredClone(loadout);
  return accepted({
    ...canonical,
    selection,
  });
}

function applyEquipGear(
  canonical: OwnershipCanonicalState,
  payload: Record<string, unknown>,
): ApplyCommandResult {
  const characterId = nonEmptyString(payload.characterId);
  const slot = nonEmptyString(payload.slot);
  const itemId = nonEmptyString(payload.itemId);
  const itemDomain = nonEmptyString(payload.itemDomain);
  if (characterId === null || slot === null || itemId === null || itemDomain === null) {
    return rejected("invalidCommand");
  }
  if (!isKnownCharacterId(characterId)) {
    return rejected("invalidCommand");
  }

  const expectedDomain = gearSlotToItemDomain(slot);
  if (expectedDomain === null || expectedDomain !== itemDomain) {
    return rejected("invalidCommand");
  }

  const gearField = gearSlotToField(slot);
  if (gearField === null) {
    return rejected("invalidCommand");
  }

  const meta = ensureMetaObject(canonical.meta);
  const equippedByCharacter = ensureMap(meta, "equippedByCharacter");
  const equipped = ensureMap(equippedByCharacter, characterId);
  equipped[gearField] = itemId;

  // Keep selection loadout gear in sync with equipped gear.
  const selection = ensureSelectionObject(canonical.selection);
  const loadouts = ensureMap(selection, "loadoutsByCharacter");
  const loadout = ensureMap(loadouts, characterId);
  loadout[gearField] = itemId;

  return accepted({
    ...canonical,
    selection,
    meta,
  });
}

function applySetAbilitySlot(
  canonical: OwnershipCanonicalState,
  payload: Record<string, unknown>,
): ApplyCommandResult {
  const characterId = nonEmptyString(payload.characterId);
  const slot = nonEmptyString(payload.slot);
  const abilityId = nonEmptyString(payload.abilityId);
  if (characterId === null || slot === null || abilityId === null) {
    return rejected("invalidCommand");
  }
  if (!isKnownCharacterId(characterId)) {
    return rejected("invalidCommand");
  }

  const abilityField = abilitySlotToField(slot);
  if (abilityField === null) {
    return rejected("invalidCommand");
  }

  const selection = ensureSelectionObject(canonical.selection);
  const loadouts = ensureMap(selection, "loadoutsByCharacter");
  const loadout = ensureMap(loadouts, characterId);
  loadout[abilityField] = abilityId;

  return accepted({
    ...canonical,
    selection,
  });
}

function applySetProjectileSpell(
  canonical: OwnershipCanonicalState,
  payload: Record<string, unknown>,
): ApplyCommandResult {
  const characterId = nonEmptyString(payload.characterId);
  const spellId = nonEmptyString(payload.spellId);
  if (characterId === null || spellId === null) {
    return rejected("invalidCommand");
  }
  if (!isKnownCharacterId(characterId)) {
    return rejected("invalidCommand");
  }
  const selection = ensureSelectionObject(canonical.selection);
  const loadouts = ensureMap(selection, "loadoutsByCharacter");
  const loadout = ensureMap(loadouts, characterId);
  loadout.projectileSlotSpellId = spellId;
  return accepted({
    ...canonical,
    selection,
  });
}

function applyLearnProjectileSpell(
  canonical: OwnershipCanonicalState,
  payload: Record<string, unknown>,
): ApplyCommandResult {
  const characterId = nonEmptyString(payload.characterId);
  const spellId = nonEmptyString(payload.spellId);
  if (characterId === null || spellId === null) {
    return rejected("invalidCommand");
  }
  if (!isKnownCharacterId(characterId)) {
    return rejected("invalidCommand");
  }
  const meta = ensureMetaObject(canonical.meta);
  const spellLists = ensureMap(meta, "spellListByCharacter");
  const spellList = ensureMap(spellLists, characterId);
  const projectileSpells = ensureStringList(spellList, "projectileSpells");
  addUnique(projectileSpells, spellId);
  return accepted({
    ...canonical,
    meta,
  });
}

function applyLearnSpellAbility(
  canonical: OwnershipCanonicalState,
  payload: Record<string, unknown>,
): ApplyCommandResult {
  const characterId = nonEmptyString(payload.characterId);
  const abilityId = nonEmptyString(payload.abilityId);
  if (characterId === null || abilityId === null) {
    return rejected("invalidCommand");
  }
  if (!isKnownCharacterId(characterId)) {
    return rejected("invalidCommand");
  }
  const meta = ensureMetaObject(canonical.meta);
  const spellLists = ensureMap(meta, "spellListByCharacter");
  const spellList = ensureMap(spellLists, characterId);
  const spellAbilities = ensureStringList(spellList, "spellAbilities");
  addUnique(spellAbilities, abilityId);
  return accepted({
    ...canonical,
    meta,
  });
}

function applyUnlockGear(
  canonical: OwnershipCanonicalState,
  payload: Record<string, unknown>,
): ApplyCommandResult {
  const slot = nonEmptyString(payload.slot);
  const itemId = nonEmptyString(payload.itemId);
  const itemDomain = nonEmptyString(payload.itemDomain);
  if (slot === null || itemId === null || itemDomain === null) {
    return rejected("invalidCommand");
  }

  const expectedDomain = gearSlotToItemDomain(slot);
  if (expectedDomain === null || expectedDomain !== itemDomain) {
    return rejected("invalidCommand");
  }

  const inventoryField = gearSlotToInventoryField(slot);
  if (inventoryField === null) {
    return rejected("invalidCommand");
  }

  const meta = ensureMetaObject(canonical.meta);
  const inventory = ensureMap(meta, "inventory");
  const list = ensureStringList(inventory, inventoryField);
  addUnique(list, itemId);

  return accepted({
    ...canonical,
    meta,
  });
}

function accepted(canonicalState: OwnershipCanonicalState): ApplyCommandResult {
  return { accepted: true, canonicalState };
}

function rejected(reason: OwnershipRejectedReason): ApplyCommandResult {
  return { accepted: false, rejectedReason: reason };
}

function asRecord(value: unknown): Record<string, unknown> | null {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, unknown>;
}

function asJsonObject(value: unknown): JsonObject | null {
  const record = asRecord(value);
  if (record === null) {
    return null;
  }
  return structuredClone(record) as JsonObject;
}

function nonEmptyString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function ensureSelectionObject(selection: JsonObject): JsonObject {
  return structuredClone(selection);
}

function ensureMetaObject(meta: JsonObject): JsonObject {
  return structuredClone(meta);
}

function ensureMap(
  parent: Record<string, unknown>,
  key: string,
): Record<string, unknown> {
  const candidate = asRecord(parent[key]);
  if (candidate !== null) {
    return candidate;
  }
  const created: Record<string, unknown> = {};
  parent[key] = created;
  return created;
}

function ensureStringList(parent: Record<string, unknown>, key: string): string[] {
  const raw = parent[key];
  if (Array.isArray(raw)) {
    const out: string[] = [];
    for (const value of raw) {
      if (typeof value === "string" && value.length > 0) {
        out.push(value);
      }
    }
    parent[key] = out;
    return out;
  }
  const created: string[] = [];
  parent[key] = created;
  return created;
}

function addUnique(list: string[], value: string): void {
  if (!list.includes(value)) {
    list.push(value);
  }
}

function isKnownCharacterId(value: string): boolean {
  return knownCharacterIds.includes(value as (typeof knownCharacterIds)[number]);
}

function abilitySlotToField(slot: string): string | null {
  switch (slot) {
    case "primary":
      return "abilityPrimaryId";
    case "secondary":
      return "abilitySecondaryId";
    case "projectile":
      return "abilityProjectileId";
    case "spell":
      return "abilitySpellId";
    case "mobility":
      return "abilityMobilityId";
    case "jump":
      return "abilityJumpId";
    default:
      return null;
  }
}

function gearSlotToField(slot: string): string | null {
  switch (slot) {
    case "mainWeapon":
      return "mainWeaponId";
    case "offhandWeapon":
      return "offhandWeaponId";
    case "spellBook":
      return "spellBookId";
    case "accessory":
      return "accessoryId";
    default:
      return null;
  }
}

function gearSlotToInventoryField(slot: string): string | null {
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

function gearSlotToItemDomain(slot: string): string | null {
  switch (slot) {
    case "mainWeapon":
    case "offhandWeapon":
      return "weapon";
    case "spellBook":
      return "spellBook";
    case "accessory":
      return "accessory";
    default:
      return null;
  }
}
