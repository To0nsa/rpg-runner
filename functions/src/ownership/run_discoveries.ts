import type { JsonObject } from "./contracts.js";
import { RewardGrantInvariantViolationError } from "./reward_grants.js";

const idPattern = /^[a-zA-Z][a-zA-Z0-9_]{0,63}$/;

export function initialCodexProgress(): JsonObject {
  return { schemaVersion: 2, competitiveBestScores: {} };
}

export function initialEnemyDefeats(): JsonObject {
  return { schemaVersion: 1, byEnemy: {} };
}

/** Applies replay-derived discoveries within the terminal settlement transaction. */
export function applyRunDiscoveries(args: {
  progression: JsonObject;
  validatedRun: Record<string, unknown>;
  session: Record<string, unknown>;
}): boolean {
  // The evidence retains its original wire name for already-validated runs.
  const raw = args.validatedRun.codex;
  if (raw === undefined || raw === null) return false;
  const evidence = record(raw, "run discovery evidence");
  const ticket = record(args.session.runTicket, "run ticket");
  const levelId = evidence.levelId;
  if (
    evidence.schemaVersion !== 1 ||
    args.validatedRun.accepted !== true ||
    typeof levelId !== "string" ||
    !idPattern.test(levelId) ||
    levelId !== ticket.levelId ||
    levelId !== args.session.levelId
  ) fail("Run discovery evidence does not match the accepted run ticket.");

  const runDefeats = readRunEnemyDefeats(evidence);
  const codex = args.progression.codex === undefined
    ? initialCodexProgress()
    : record(args.progression.codex, "Codex progression");
  if (codex.schemaVersion !== 1 && codex.schemaVersion !== 2) {
    fail("Unsupported Codex progression version.");
  }
  const competitiveBestScores = counts(
    codex.competitiveBestScores, "Codex competitive scores",
  );
  const legacyDefeats = codex.schemaVersion === 1
    ? counts(codex.enemyKills, "legacy Codex kills") : {};

  const existingDefeats = args.progression.enemyDefeats;
  const defeats = existingDefeats === undefined
    ? initialEnemyDefeats()
    : record(existingDefeats, "enemy defeats");
  if (defeats.schemaVersion !== 1) fail("Unsupported enemy defeats version.");
  // A present shared map is authoritative; otherwise transfer old Codex kills.
  const byEnemy = existingDefeats === undefined
    ? counts(legacyDefeats, "legacy Codex kills")
    : counts(defeats.byEnemy, "lifetime enemy defeats");
  for (const [id, count] of Object.entries(runDefeats)) {
    byEnemy[id] = integer((byEnemy[id] ?? 0) + count, "lifetime enemy defeats");
  }
  if (args.session.mode === "competitive") {
    competitiveBestScores[levelId as string] = Math.max(
      competitiveBestScores[levelId as string] ?? 0,
      integer(args.validatedRun.score, "validated score"),
    );
  }

  args.progression.enemyDefeats = { schemaVersion: 1, byEnemy };
  args.progression.codex = { schemaVersion: 2, competitiveBestScores };
  return true;
}

/** Shared replay evidence for Library discoveries, lifetime stats and milestones. */
export function readRunEnemyDefeats(raw: unknown): Record<string, number> {
  const evidence = record(raw, "run discovery evidence");
  if (evidence.schemaVersion !== 1) fail("Unsupported run discovery evidence.");
  return counts(evidence.enemyKills, "run enemy defeats");
}

function record(value: unknown, name: string): Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    fail(`${name} must be an object.`);
  }
  return value as Record<string, unknown>;
}

function counts(value: unknown, name: string): Record<string, number> {
  const source = record(value, name);
  if (Object.keys(source).length > 64) fail(`${name} has too many identities.`);
  const result = Object.create(null) as Record<string, number>;
  for (const [id, count] of Object.entries(source)) {
    if (!idPattern.test(id)) fail(`${name} has an invalid identity.`);
    Object.defineProperty(result, id, {
      value: integer(count, name), enumerable: true, writable: true, configurable: true,
    });
  }
  return result;
}

function integer(value: unknown, name: string): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) {
    fail(`${name} must be a non-negative safe integer.`);
  }
  return value as number;
}

function fail(message: string): never {
  throw new RewardGrantInvariantViolationError(message);
}
