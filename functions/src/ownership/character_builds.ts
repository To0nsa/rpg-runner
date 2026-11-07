import type { JsonObject } from "./contracts.js";
import { knownCharacterIds } from "./character_catalog.js";
import { playerLevelFromTotalXp } from "./player_progress.js";

export const selectionSchemaVersion = 2;
export const buildUnlockLevels = [1, 5, 12] as const;
export const buildNameMaxLength = 28;
const nameSegmenter = new Intl.Segmenter(undefined, { granularity: "grapheme" });

export function validBuildName(raw: unknown): string | null {
  if (typeof raw !== "string") return null;
  const name = raw.trim();
  return name.length > 0 && [...nameSegmenter.segment(name)].length <= buildNameMaxLength
    ? name : null;
}

export function isBuildIndex(value: unknown): value is number {
  return typeof value === "number" && Number.isInteger(value) &&
    value >= 0 && value < buildUnlockLevels.length;
}

export function confirmedPlayerLevel(progression: JsonObject): number {
  const progress = record(progression.playerProgress);
  const xp = progress?.totalXp;
  return playerLevelFromTotalXp(typeof xp === "number" && Number.isSafeInteger(xp) && xp >= 0 ? xp : 0);
}

export function isBuildUnlocked(index: unknown, progression: JsonObject): index is number {
  return isBuildIndex(index) && confirmedPlayerLevel(progression) >= buildUnlockLevels[index];
}

export function characterBuilds(selection: JsonObject, characterId: string): JsonObject | null {
  if (selection.schemaVersion !== selectionSchemaVersion) return null;
  return record(record(selection.buildsByCharacter)?.[characterId]);
}

export function buildAt(selection: JsonObject, characterId: string, index: unknown): JsonObject | null {
  if (!isBuildIndex(index)) return null;
  const builds = characterBuilds(selection, characterId)?.builds;
  return Array.isArray(builds) && builds.length === buildUnlockLevels.length
    ? record(builds[index]) : null;
}

export function selectedLoadout(selection: JsonObject, characterId: string,
  progression: JsonObject): JsonObject | null {
  const index = characterBuilds(selection, characterId)?.selectedBuildIndex;
  return isBuildUnlocked(index, progression)
    ? record(buildAt(selection, characterId, index)?.loadout) : null;
}

/** Equipped meta is a projection of each character's selected build. */
export function syncEquippedBuilds(selection: JsonObject, meta: JsonObject): JsonObject {
  const next = structuredClone(meta);
  const equipped: JsonObject = {};
  for (const id of knownCharacterIds) {
    const index = characterBuilds(selection, id)?.selectedBuildIndex;
    const loadout = record(buildAt(selection, id, index)?.loadout);
    if (loadout === null) continue;
    equipped[id] = {
      mainWeaponId: loadout.mainWeaponId,
      offhandWeaponId: loadout.offhandWeaponId,
      spellBookId: loadout.spellBookId,
      accessoryId: loadout.accessoryId,
    };
  }
  next.equippedByCharacter = equipped;
  return next;
}

export function record(value: unknown): JsonObject | null {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as JsonObject : null;
}
