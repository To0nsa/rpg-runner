import { campaignCharacterUnlocked, initialCampaignProgress } from "../campaign/progression.js";
import { buildUnlockLevels, selectionSchemaVersion } from "./character_builds.js";
import { initialAchievementProgress, readAchievementProgress } from "./achievements.js";
import type {
  CanonicalDocument,
  JsonObject,
  OwnershipCanonicalState,
} from "./contracts.js";
import { normalizeProgressionStore } from "./store_state.js";
import { initialPlayerProgress } from "./player_progress.js";
import { initialCodexProgress, initialEnemyDefeats } from "./run_discoveries.js";
import { knownCharacterIds } from "./character_catalog.js";
import { coreAbilitySlots, coreGearSlots, coreStarterLoadouts, coreStarterMeta } from "./core_catalog.generated.js";

export { knownCharacterIds } from "./character_catalog.js";
export type KnownCharacterId = (typeof knownCharacterIds)[number];

export const knownAbilitySlots = coreAbilitySlots;
export type KnownAbilitySlot = (typeof knownAbilitySlots)[number];
export const knownGearSlots = coreGearSlots;
export type KnownGearSlot = (typeof knownGearSlots)[number];

export function starterSelection(): JsonObject {
  return {
    schemaVersion: selectionSchemaVersion,
    levelId: "field",
    runMode: "practice",
    runType: "practice",
    characterId: "eloise",
    buildsByCharacter: Object.fromEntries(knownCharacterIds.map((id) => [id, {
      selectedBuildIndex: 0,
      builds: buildUnlockLevels.map((_, index) => ({
        name: `Build ${index + 1}`,
        loadout: structuredClone(coreStarterLoadouts[id]),
      })),
    }])),
  };
}

export function starterMeta(): JsonObject {
  return structuredClone(coreStarterMeta);
}

export function starterProgression(args: {
  userId: string;
  meta: JsonObject;
  selection: JsonObject;
}): JsonObject {
  const progression = structuredClone({
    gold: 0,
    campaign: initialCampaignProgress(),
    awardedRunIds: [],
    codex: initialCodexProgress(),
    enemyDefeats: initialEnemyDefeats(),
    playerProgress: initialPlayerProgress(),
    achievements: initialAchievementProgress(),
  } satisfies JsonObject);
  normalizeProgressionStore({
    progression,
    meta: args.meta,
    selection: args.selection,
    userId: args.userId,
    nowMs: Date.now(),
  });
  return progression;
}

export function starterCanonicalState(
  profileId: string,
  userId: string,
): OwnershipCanonicalState {
  const selection = starterSelection();
  const meta = starterMeta();
  const progression = starterProgression({
    userId,
    meta,
    selection,
  });
  return {
    profileId,
    revision: 0,
    selection,
    meta,
    progression,
  };
}

export function starterCanonicalDocument(
  uid: string,
  profileId: string,
): CanonicalDocument {
  const canonical = starterCanonicalState(profileId, uid);
  return {
    uid,
    profileId: canonical.profileId,
    revision: canonical.revision,
    selection: canonical.selection,
    meta: canonical.meta,
    progression: canonical.progression,
  };
}

export function normalizeCanonicalState(
  candidate: Partial<OwnershipCanonicalState> | null | undefined,
  profileId: string,
  userId: string,
): OwnershipCanonicalState {
  const fallback = starterCanonicalState(profileId, userId);
  if (!candidate) {
    return fallback;
  }
  const selection = isJsonObject(candidate.selection)
    ? structuredClone(candidate.selection)
    : fallback.selection;
  const meta = isJsonObject(candidate.meta)
    ? structuredClone(candidate.meta)
    : fallback.meta;
  const progression = isJsonObject(candidate.progression)
    ? structuredClone(candidate.progression)
    : fallback.progression;
  retireEloiseWip(selection, meta);
  if (!(knownCharacterIds as readonly unknown[]).includes(selection.characterId) ||
      !campaignCharacterUnlocked(progression, selection.characterId)) selection.characterId = "eloise";
  progression.achievements = readAchievementProgress(progression.achievements);
  normalizeProgressionStore({
    progression,
    meta,
    selection,
    userId,
    nowMs: Date.now(),
  });
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
    progression,
  };
}

export function isJsonObject(value: unknown): value is JsonObject {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

/** Preserve earned skills without replacing Éloïse's current builds or equipment. */
function retireEloiseWip(selection: JsonObject, meta: JsonObject): void {
  const ownership = meta.abilityOwnershipByCharacter;
  if (isJsonObject(ownership)) {
    const retired = ownership.eloiseWip;
    if (isJsonObject(retired)) {
      const current = isJsonObject(ownership.eloise) ? ownership.eloise : {};
      const mergeIds = (a: unknown, b: unknown) => [...new Set([
        ...(Array.isArray(a) ? a.filter((id): id is string => typeof id === "string") : []),
        ...(Array.isArray(b) ? b.filter((id): id is string => typeof id === "string") : []),
      ])];
      current.projectileSpells = mergeIds(current.projectileSpells, retired.projectileSpells);
      const currentSlots = isJsonObject(current.abilitiesBySlot) ? current.abilitiesBySlot : {};
      const retiredSlots = isJsonObject(retired.abilitiesBySlot) ? retired.abilitiesBySlot : {};
      for (const slot of knownAbilitySlots) currentSlots[slot] = mergeIds(currentSlots[slot], retiredSlots[slot]);
      current.abilitiesBySlot = currentSlots;
      ownership.eloise = current;
    }
    delete ownership.eloiseWip;
  }
  for (const branches of [selection.buildsByCharacter, selection.loadoutsByCharacter, meta.equippedByCharacter]) {
    if (isJsonObject(branches)) delete branches.eloiseWip;
  }
}
