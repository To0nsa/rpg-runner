import type { JsonObject } from "./contracts.js";
import { RewardGrantInvariantViolationError } from "./reward_grants.js";

const idPattern = /^[a-zA-Z][a-zA-Z0-9_]{0,63}$/;

/** Empty legacy profiles acquire Codex state on their first tracked settlement. */
export function initialCodexProgress(): JsonObject {
  return { schemaVersion: 1, enemyKills: {}, competitiveBestScores: {} };
}

/** Applies validator evidence inside the pending -> validated transaction only.
 * The session terminal state, written atomically with this state, fences retries.
 * Client summaries and legacy ordinal kill arrays are never progression inputs.
 */
export function applyCodexProgress(args: {
  progression: JsonObject;
  validatedRun: Record<string, unknown>;
  session: Record<string, unknown>;
}): boolean {
  const raw = args.validatedRun.codex;
  if (raw === undefined || raw === null) return false;
  const evidence = record(raw, "Codex evidence");
  const ticket = record(args.session.runTicket, "run ticket");
  const levelId = evidence.levelId;
  if (
    evidence.schemaVersion !== 1 ||
    args.validatedRun.accepted !== true ||
    typeof levelId !== "string" ||
    !idPattern.test(levelId) ||
    levelId !== ticket.levelId ||
    levelId !== args.session.levelId
  ) fail("Codex evidence does not match the accepted run ticket.");

  const kills = counts(evidence.enemyKills, "Codex evidence kills");
  const current = args.progression.codex === undefined
    ? initialCodexProgress()
    : record(args.progression.codex, "Codex progression");
  if (current.schemaVersion !== 1) fail("Unsupported Codex progression version.");
  const enemyKills = counts(current.enemyKills, "Codex lifetime kills");
  const competitiveBestScores = counts(
    current.competitiveBestScores, "Codex competitive scores",
  );
  for (const [id, count] of Object.entries(kills)) {
    enemyKills[id] = integer((enemyKills[id] ?? 0) + count, "Codex lifetime kills");
  }
  if (args.session.mode === "competitive") {
    competitiveBestScores[levelId as string] = Math.max(
      competitiveBestScores[levelId as string] ?? 0,
      integer(args.validatedRun.score, "validated score"),
    );
  }
  args.progression.codex = { schemaVersion: 1, enemyKills, competitiveBestScores };
  return true;
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
