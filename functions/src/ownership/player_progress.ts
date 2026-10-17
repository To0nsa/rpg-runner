import type { JsonObject } from "./contracts.js";
import { RewardGrantInvariantViolationError } from "./reward_grants.js";

/** One XP per 200 validated score points keeps 30,000-point runs at 150 XP. */
const xpScoreDivisor = 200;

/** Account-wide totals begin with runs carrying versioned validator evidence. */
export function initialPlayerProgress(): JsonObject {
  return {
    schemaVersion: 1,
    totalXp: 0,
    acceptedRuns: 0,
    runsByLevel: {},
    damageDealt100: 0,
    damageTaken100: 0,
  };
}

/** Applies one accepted run inside the pending-to-validated settlement transaction. */
export function applyPlayerProgress(args: {
  progression: JsonObject;
  validatedRun: Record<string, unknown>;
  session: Record<string, unknown>;
}): boolean {
  const raw = args.validatedRun.playerRunStats;
  if (raw === undefined || raw === null) return false;
  const evidence = record(raw, "Player run stats");
  if (args.validatedRun.accepted !== true || evidence.schemaVersion !== 1) {
    fail("Player run stats require an accepted result and supported version.");
  }
  const score = integer(args.validatedRun.score, "validated score");
  const dealt = integer(evidence.damageDealt100, "run damage dealt");
  const taken = integer(evidence.damageTaken100, "run damage taken");
  const levelId = nonEmptyString(args.session.levelId, "run level");
  const mode = args.session.mode;
  if (mode !== "practice" && mode !== "competitive" && mode !== "weekly") {
    fail("Unsupported run mode for player progression.");
  }
  const current = args.progression.playerProgress === undefined
    ? initialPlayerProgress()
    : record(args.progression.playerProgress, "player progression");
  if (current.schemaVersion !== 1) fail("Unsupported player progression version.");
  const runsByLevel = readRunsByLevel(current.runsByLevel);
  const levelRuns = runsByLevel[levelId] ?? { practice: 0, competitive: 0, weekly: 0 };
  runsByLevel[levelId] = {
    ...levelRuns,
    [mode]: add(levelRuns[mode], 1, `${levelId} ${mode} runs`),
  };
  args.progression.playerProgress = {
    schemaVersion: 1,
    totalXp: add(current.totalXp, Math.floor(score / xpScoreDivisor), "lifetime XP"),
    acceptedRuns: add(current.acceptedRuns, 1, "accepted runs"),
    runsByLevel,
    damageDealt100: add(current.damageDealt100, dealt, "lifetime damage dealt"),
    damageTaken100: add(current.damageTaken100, taken, "lifetime damage taken"),
  };
  return true;
}

function readRunsByLevel(raw: unknown): Record<string, { practice: number; competitive: number; weekly: number }> {
  if (raw === undefined) return {};
  const levels = record(raw, "runs by level");
  const result: Record<string, { practice: number; competitive: number; weekly: number }> = {};
  for (const [level, value] of Object.entries(levels)) {
    nonEmptyString(level, "run level");
    const counts = record(value, `${level} runs`);
    result[level] = {
      practice: integer(counts.practice, `${level} practice runs`),
      competitive: integer(counts.competitive, `${level} competitive runs`),
      weekly: integer(counts.weekly, `${level} weekly runs`),
    };
  }
  return result;
}

function nonEmptyString(raw: unknown, name: string): string {
  if (typeof raw !== "string" || raw.trim().length === 0) {
    fail(`${name} must be a non-empty string.`);
  }
  return (raw as string).trim();
}

function add(current: unknown, increment: number, name: string): number {
  const result = integer(current, name) + increment;
  return integer(result, name);
}

function integer(value: unknown, name: string): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) {
    fail(`${name} must be a non-negative safe integer.`);
  }
  return value as number;
}

function record(value: unknown, name: string): Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    fail(`${name} must be an object.`);
  }
  return value as Record<string, unknown>;
}

function fail(message: string): never {
  throw new RewardGrantInvariantViolationError(message);
}
