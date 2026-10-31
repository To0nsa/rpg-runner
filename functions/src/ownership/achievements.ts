import type { JsonObject } from "./contracts.js";
import { RewardGrantInvariantViolationError } from "./reward_grants.js";
import { readRunEnemyDefeats } from "./run_discoveries.js";
import {
  achievementDefinitions, achievementTierGold as tierGold,
  completedRunMinimumDistanceMeters, completedRunMinimumDurationSeconds,
  type AchievementMetric,
} from "./achievement_catalog.js";
const naturalEnds = new Set([
  "fellBehindCamera", "fellIntoGap", "playerDied", "bossEncounterFailed",
]);

export interface AchievementTier extends JsonObject {
  threshold: number;
  goldAmount: number;
  achievedAtMs: number | null;
  claimedAtMs: number | null;
}
export interface AchievementEntry extends JsonObject {
  id: string;
  value: number;
  tiers: AchievementTier[];
}
export interface AchievementProgress extends JsonObject {
  schemaVersion: 1;
  entries: AchievementEntry[];
}

/** Empty achievement history deliberately ignores existing account totals. */
export function initialAchievementProgress(): AchievementProgress {
  return {
    schemaVersion: 1,
    entries: achievementDefinitions.map((definition) => ({
      id: definition.id, value: 0,
      tiers: definition.thresholds.map((threshold, index) => ({
        threshold, goldAmount: tierGold[index], achievedAtMs: null, claimedAtMs: null,
      })),
    })),
  };
}

/** Fail closed on persisted corruption; never erase a durable claim receipt. */
export function readAchievementProgress(raw: unknown): AchievementProgress {
  if (raw === undefined) return initialAchievementProgress();
  const progress = object(raw);
  if (progress.schemaVersion !== 1 || !Array.isArray(progress.entries) ||
      progress.entries.length !== achievementDefinitions.length) fail();
  const entries = progress.entries.map((rawEntry, index) => {
    const entry = object(rawEntry);
    const definition = achievementDefinitions[index];
    if (entry.id !== definition.id || !Array.isArray(entry.tiers) ||
        entry.tiers.length !== 3) fail();
    const value = count(entry.value);
    let previousUnearned = false;
    const tiers = entry.tiers.map((rawTier, tierIndex) => {
      const tier = object(rawTier);
      const threshold = count(tier.threshold);
      const goldAmount = count(tier.goldAmount);
      const achievedAtMs = timestamp(tier.achievedAtMs);
      const claimedAtMs = timestamp(tier.claimedAtMs);
      // Version 1 fixes thresholds. Earned gold is snapshotted, not recomputed.
      if (threshold !== definition.thresholds[tierIndex] || goldAmount === 0 ||
          (claimedAtMs !== null && (achievedAtMs === null || claimedAtMs < achievedAtMs)) ||
          (achievedAtMs !== null && (previousUnearned || value < threshold))) fail();
      previousUnearned ||= achievedAtMs === null;
      return { threshold, goldAmount, achievedAtMs, claimedAtMs };
    });
    return { id: definition.id, value, tiers };
  });
  return { schemaVersion: 1, entries };
}

/** Applies verified metrics, gating only completed runs on participation/natural end.
 * Called only by terminal settlement; its transaction prevents run replays.
 */
export function applyRunAchievements(args: {
  progression: JsonObject;
  validatedRun: Record<string, unknown>;
  nowMs: number;
}): boolean {
  const run = args.validatedRun;
  // Retained legacy evidence earns its original rewards without invented metrics.
  if (run.playerRunStats === undefined || run.codex === undefined ||
      run.distanceMeters === undefined || run.durationSeconds === undefined ||
      run.endedReason === undefined) return false;
  if (run.accepted !== true) fail();
  const distance = count(run.distanceMeters);
  const seconds = count(run.durationSeconds);
  if (typeof run.endedReason !== "string" ||
      (!naturalEnds.has(run.endedReason) && run.endedReason !== "gaveUp")) fail();
  // Short runs and manual quits retain earned metrics without farming run counts.
  const completedRun = naturalEnds.has(run.endedReason) &&
    (distance >= completedRunMinimumDistanceMeters || seconds >= completedRunMinimumDurationSeconds);
  const kills = Object.values(readRunEnemyDefeats(run.codex))
    .reduce<number>((sum, value) => count(sum + count(value)), 0);
  const progress = readAchievementProgress(args.progression.achievements);
  const earnedAt = confirmationTime(args.nowMs);
  const metrics: Record<AchievementMetric, number> = {
    runs: completedRun ? 1 : 0, distanceMeters: distance, durationSeconds: seconds, enemyKills: kills,
  };
  for (const [index, entry] of progress.entries.entries()) {
    const definition = achievementDefinitions[index];
    const value = metrics[definition.metric];
    entry.value = count(definition.aggregation === "best"
      ? Math.max(entry.value, value) : entry.value + value);
    for (const [tierIndex, tier] of entry.tiers.entries()) {
      if (tier.achievedAtMs === null && entry.value >= tier.threshold) {
        tier.achievedAtMs = earnedAt;
        tier.goldAmount = tierGold[tierIndex];
      }
    }
  }
  args.progression.achievements = progress;
  return true;
}

/** Claims all earned tiers for one achievement, or all achievements when null.
 * Durable per-tier receipts also prevent repayment after command-ID expiry.
 */
export function claimAchievementGold(
  progression: JsonObject, achievementId: string | null, nowMs: number,
): boolean {
  const progress = readAchievementProgress(progression.achievements);
  if (achievementId !== null && !progress.entries.some((entry) => entry.id === achievementId)) {
    return false;
  }
  let gold = count(progression.gold);
  const claimedAt = confirmationTime(nowMs);
  for (const entry of progress.entries) {
    if (achievementId !== null && entry.id !== achievementId) continue;
    for (const tier of entry.tiers) {
      if (tier.achievedAtMs === null || tier.claimedAtMs !== null) continue;
      gold = count(gold + tier.goldAmount);
      tier.claimedAtMs = Math.max(claimedAt, tier.achievedAtMs);
    }
  }
  progression.gold = gold;
  progression.achievements = progress;
  return true;
}

function object(raw: unknown): Record<string, unknown> {
  if (raw === null || typeof raw !== "object" || Array.isArray(raw)) fail();
  return raw as Record<string, unknown>;
}
function count(raw: unknown): number {
  if (typeof raw !== "number" || !Number.isSafeInteger(raw) || raw < 0) fail();
  return raw as number;
}
function timestamp(raw: unknown): number | null {
  return raw === null ? null : confirmationTime(raw);
}
function confirmationTime(raw: unknown): number {
  const value = count(raw);
  if (value > 8640000000000000) fail();
  return value;
}
function fail(): never {
  throw new RewardGrantInvariantViolationError("Invalid achievement evidence or progress.");
}
