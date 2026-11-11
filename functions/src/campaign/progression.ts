import { HttpsError } from "firebase-functions/v2/https";
import type { JsonObject, OwnershipCanonicalState } from "../ownership/contracts.js";
import { RewardGrantInvariantViolationError } from "../ownership/reward_grants.js";
import { campaignCatalog } from "./generated_catalog.js";

export interface CampaignMission {
  readonly id: string;
  readonly available: boolean;
  readonly levelId: string;
  readonly firstClearXp: number;
  readonly rewardAbilityId: string | null;
}
export interface CampaignChapter {
  readonly id: string;
  readonly rewardCharacterId: string | null;
  readonly missions: readonly CampaignMission[];
}
export interface CampaignCatalog {
  readonly contentDigest: string;
  readonly rewardPolicyVersion: number;
  readonly chapters: readonly CampaignChapter[];
}

/** Missing campaign state represents a new chapter, including pre-release accounts. */
export function initialCampaignProgress(): JsonObject {
  return { schemaVersion: 1, missions: {} };
}

export function campaignCharacterUnlocked(progression: JsonObject, characterId: unknown): boolean {
  if (characterId !== "bountyHunter") return true;
  const chapter = campaignCatalog.chapters.find((entry) => entry.rewardCharacterId === characterId);
  return chapter !== undefined && chapter.missions.every((mission) => missionCleared(progression, mission.id));
}

export function missionCleared(progression: JsonObject, missionId: string): boolean {
  const state = object(progression.campaign);
  if (state?.schemaVersion !== 1) return false;
  const missions = object(state?.missions);
  return object(missions?.[missionId])?.cleared === true;
}

/** Called again in the issuance transaction so predecessor unlocks remain authoritative. */
export function authorizeCampaignMission(
  progression: JsonObject,
  missionId: string | undefined,
  levelId: string,
  catalog: CampaignCatalog = campaignCatalog,
): JsonObject {
  for (const chapter of catalog.chapters) {
    const index = chapter.missions.findIndex((mission) => mission.id === missionId);
    if (index < 0) continue;
    const mission = chapter.missions[index]!;
    if (!mission.available || mission.levelId !== levelId ||
        chapter.missions.slice(0, index).some((entry) => !missionCleared(progression, entry.id))) {
      throw new HttpsError("failed-precondition", "Campaign mission is not available.");
    }
    return { missionId: mission.id, contentDigest: catalog.contentDigest,
      rewardPolicyVersion: catalog.rewardPolicyVersion };
  }
  throw new HttpsError("invalid-argument", "Unknown campaign mission.");
}

/** First-clear grants and bests share the canonical wallet settlement transaction.
 * Stable mission IDs prevent a new content revision from granting first-clear XP twice.
 */
export function applyCampaignProgress(args: {
  canonical: OwnershipCanonicalState;
  validatedRun: Record<string, unknown>;
  session: Record<string, unknown>;
  nowMs: number;
  catalog?: CampaignCatalog;
}): { changed: boolean; xp: number } {
  if (args.session.mode !== "campaign") return { changed: false, xp: 0 };
  const catalog = args.catalog ?? campaignCatalog;
  const ticket = object(args.session.runTicket);
  const binding = object(ticket?.campaign);
  const evidence = object(args.validatedRun.campaign);
  if (args.validatedRun.accepted !== true || !binding || !evidence ||
      !object(args.validatedRun.playerRunStats) ||
      binding.missionId !== evidence.missionId || binding.contentDigest !== evidence.contentDigest ||
      binding.rewardPolicyVersion !== evidence.rewardPolicyVersion ||
      binding.contentDigest !== catalog.contentDigest || binding.rewardPolicyVersion !== catalog.rewardPolicyVersion) {
    fail("Campaign settlement requires matching verified content and reward policy.");
  }
  const mission = catalog.chapters.flatMap((chapter) => [...chapter.missions])
    .find((entry) => entry.id === binding.missionId);
  if (!mission || mission.levelId !== args.session.levelId) fail("Unknown campaign settlement mission.");
  const state = object(args.canonical.progression.campaign) ?? initialCampaignProgress();
  if (state.schemaVersion !== 1) fail("Unsupported campaign progress version.");
  const missions = object(state.missions) ?? {};
  const previous = object(missions[mission.id]) ?? {};
  const completed = args.validatedRun.endedReason === "missionCompleted";
  const firstClear = completed && previous.cleared !== true;
  const score = safeInteger(args.validatedRun.score);
  const tick = safeInteger(args.validatedRun.tick);
  const bests = object(previous.bests) ?? {};
  // Content and reward policy changes deliberately start a new comparable best.
  const bestKey = `${catalog.contentDigest}_v${catalog.rewardPolicyVersion}`;
  const best = object(bests[bestKey]);
  if (completed && (!best || score > safeInteger(best.score) ||
      (score === best.score && tick < safeInteger(best.tick)))) {
    bests[bestKey] = { score, tick, runSessionId: String(args.validatedRun.runSessionId) };
  }
  missions[mission.id] = { ...previous, cleared: completed || previous.cleared === true,
    attempts: safeInteger(safeInteger(previous.attempts ?? 0) + 1), bests,
    ...(firstClear ? { firstClearedAtMs: args.nowMs } : {}) };
  args.canonical.progression.campaign = { schemaVersion: 1, missions };
  if (firstClear && mission.rewardAbilityId) {
    const ownership = object(args.canonical.meta.abilityOwnershipByCharacter);
    const eloise = object(ownership?.eloise);
    const slots = object(eloise?.abilitiesBySlot);
    if (!slots || !Array.isArray(slots.jump)) fail("Missing canonical jump ownership.");
    if (!slots.jump.includes(mission.rewardAbilityId)) slots.jump.push(mission.rewardAbilityId);
  }
  return { changed: true, xp: firstClear ? mission.firstClearXp : 0 };
}

function object(value: unknown): JsonObject | undefined {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as JsonObject : undefined;
}
function safeInteger(value: unknown): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) fail("Invalid campaign counter.");
  return value as number;
}
function fail(message: string): never { throw new RewardGrantInvariantViolationError(message); }
