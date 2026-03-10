import type {
  CanonicalDocument,
  JsonObject,
  OwnershipCanonicalState,
} from "./contracts.js";

export const knownCharacterIds = ["eloise", "eloiseWip"] as const;
export type KnownCharacterId = (typeof knownCharacterIds)[number];

export const knownAbilitySlots = [
  "primary",
  "secondary",
  "projectile",
  "mobility",
  "spell",
  "jump",
] as const;
export type KnownAbilitySlot = (typeof knownAbilitySlots)[number];

export const knownGearSlots = [
  "mainWeapon",
  "offhandWeapon",
  "spellBook",
  "accessory",
] as const;
export type KnownGearSlot = (typeof knownGearSlots)[number];

const starterLoadout: JsonObject = {
  mask: 7,
  mainWeaponId: "plainsteel",
  offhandWeaponId: "roadguard",
  spellBookId: "apprenticePrimer",
  projectileSlotSpellId: "acidBolt",
  accessoryId: "strengthBelt",
  abilityPrimaryId: "eloise.seeker_slash",
  abilitySecondaryId: "eloise.shield_block",
  abilityProjectileId: "eloise.snap_shot",
  abilitySpellId: "eloise.arcane_haste",
  abilityMobilityId: "eloise.dash",
  abilityJumpId: "eloise.jump",
};

export function starterSelection(): JsonObject {
  return structuredClone({
    schemaVersion: 1,
    levelId: "field",
    runType: "practice",
    characterId: "eloise",
    buildName: "Build 1",
    loadoutsByCharacter: {
      eloise: starterLoadout,
      eloiseWip: starterLoadout,
    },
  } satisfies JsonObject);
}

export function starterMeta(): JsonObject {
  return structuredClone({
    schemaVersion: 2,
    inventory: {
      weapons: ["plainsteel", "roadguard"],
      spellBooks: ["apprenticePrimer"],
      accessories: ["strengthBelt"],
    },
    equippedByCharacter: {
      eloise: {
        mainWeaponId: "plainsteel",
        offhandWeaponId: "roadguard",
        spellBookId: "apprenticePrimer",
        accessoryId: "strengthBelt",
      },
      eloiseWip: {
        mainWeaponId: "plainsteel",
        offhandWeaponId: "roadguard",
        spellBookId: "apprenticePrimer",
        accessoryId: "strengthBelt",
      },
    },
    spellListByCharacter: {
      eloise: {
        projectileSpells: ["acidBolt", "holyBolt"],
        spellAbilities: ["eloise.arcane_haste", "eloise.focus"],
      },
      eloiseWip: {
        projectileSpells: ["acidBolt", "holyBolt"],
        spellAbilities: ["eloise.arcane_haste", "eloise.focus"],
      },
    },
  } satisfies JsonObject);
}

export function starterCanonicalState(profileId: string): OwnershipCanonicalState {
  return {
    profileId,
    revision: 0,
    selection: starterSelection(),
    meta: starterMeta(),
  };
}

export function starterCanonicalDocument(
  uid: string,
  profileId: string,
): CanonicalDocument {
  const canonical = starterCanonicalState(profileId);
  return {
    uid,
    profileId: canonical.profileId,
    revision: canonical.revision,
    selection: canonical.selection,
    meta: canonical.meta,
  };
}

export function normalizeCanonicalState(
  candidate: Partial<OwnershipCanonicalState> | null | undefined,
  profileId: string,
): OwnershipCanonicalState {
  const fallback = starterCanonicalState(profileId);
  if (!candidate) {
    return fallback;
  }
  const selection = isJsonObject(candidate.selection)
    ? structuredClone(candidate.selection)
    : fallback.selection;
  const meta = isJsonObject(candidate.meta)
    ? structuredClone(candidate.meta)
    : fallback.meta;
  const revision =
    typeof candidate.revision === "number" && Number.isInteger(candidate.revision)
      ? candidate.revision
      : fallback.revision;
  const normalizedProfileId =
    typeof candidate.profileId === "string" && candidate.profileId.length > 0
      ? candidate.profileId
      : profileId;
  return {
    profileId: normalizedProfileId,
    revision,
    selection,
    meta,
  };
}

export function isJsonObject(value: unknown): value is JsonObject {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
