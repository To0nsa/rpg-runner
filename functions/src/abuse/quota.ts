import { createHash } from "node:crypto";

import type { Firestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

import { assertAccountActiveInTransaction } from "../account/deletion_guard.js";

const abuseQuotaCollection = "abuse_quota";
const defaultRetentionPaddingMs = 24 * 60 * 60 * 1000;

export const abuseQuotaRoutes = [
  "ownership_command",
  "run_create",
  "upload_grant",
  "finalize_replay_bytes",
  "leaderboard_read",
  "ghost_url",
] as const;

export type AbuseQuotaRoute = (typeof abuseQuotaRoutes)[number];
export type AbuseControlMode = "monitor" | "enforce";

export interface AbuseQuotaWindowPolicy {
  name: "burst" | "sustained";
  durationMs: number;
  limit?: number;
}

export interface AbuseQuotaPolicy {
  route: AbuseQuotaRoute;
  mode: AbuseControlMode;
  windows: readonly AbuseQuotaWindowPolicy[];
}

interface QuotaCounter {
  windowStartedAtMs: number;
  count: number;
}

interface AbuseQuotaDocument {
  uid?: unknown;
  counters?: unknown;
  updatedAtMs?: unknown;
  expiresAtMs?: unknown;
}

export interface AbuseQuotaDecision {
  route: AbuseQuotaRoute;
  accepted: boolean;
  wouldReject: boolean;
  mode: AbuseControlMode;
  units: number;
  counters: Record<string, number>;
  limits: Record<string, number | null>;
  expiresAtMs: number;
}

export function resolveAbuseQuotaPolicy(
  route: AbuseQuotaRoute,
  env: NodeJS.ProcessEnv = process.env,
): AbuseQuotaPolicy {
  const prefix = `ABUSE_${route.toUpperCase()}`;
  return {
    route,
    mode: readAbuseControlMode(env.ABUSE_CONTROL_MODE),
    windows: [
      {
        name: "burst",
        durationMs:
          readPositiveInt(env[`${prefix}_BURST_WINDOW_MS`]) ?? 60 * 1000,
        limit: readPositiveInt(env[`${prefix}_BURST_LIMIT`]),
      },
      {
        name: "sustained",
        durationMs:
          readPositiveInt(env[`${prefix}_SUSTAINED_WINDOW_MS`]) ??
          24 * 60 * 60 * 1000,
        limit: readPositiveInt(env[`${prefix}_SUSTAINED_LIMIT`]),
      },
    ],
  };
}

export function readOptionalBoundedAbuseLimit(args: {
  envName: string;
  max: number;
  env?: NodeJS.ProcessEnv;
}): number | undefined {
  if (!Number.isSafeInteger(args.max) || args.max <= 0) {
    throw new Error("Abuse limit maximum must be a positive safe integer.");
  }
  const env = args.env ?? process.env;
  const raw = env[args.envName]?.trim();
  if (!raw) {
    return undefined;
  }
  if (!/^[1-9][0-9]*$/.test(raw)) {
    return handleInvalidOptionalLimit(args.envName, args.max, env);
  }
  const parsed = Number(raw);
  if (!Number.isSafeInteger(parsed) || parsed > args.max) {
    return handleInvalidOptionalLimit(args.envName, args.max, env);
  }
  return parsed;
}

export async function consumeUserQuota(args: {
  db: Firestore;
  uid: string;
  route: AbuseQuotaRoute;
  units?: number;
  nowMs?: number;
  policy?: AbuseQuotaPolicy;
}): Promise<AbuseQuotaDecision> {
  const nowMs = args.nowMs ?? Date.now();
  const units = args.units ?? 1;
  if (!Number.isSafeInteger(units) || units <= 0) {
    throw new Error("Quota units must be a positive safe integer.");
  }
  const policy = args.policy ?? resolveAbuseQuotaPolicy(args.route);
  validatePolicy(policy, args.route);

  const quotaRef = args.db.collection(abuseQuotaCollection).doc(args.uid);
  const decision = await args.db.runTransaction(async (tx) => {
    await assertAccountActiveInTransaction(tx, args.db, args.uid);
    const snapshot = await tx.get(quotaRef);
    const stored = snapshot.data() as AbuseQuotaDocument | undefined;
    const counters = decodeCounters(stored?.counters);
    const nextCounters = { ...counters };
    const counts: Record<string, number> = {};
    const limits: Record<string, number | null> = {};
    let wouldReject = false;

    for (const window of policy.windows) {
      const key = counterKey(policy.route, window.name);
      const current = currentCounter(
        counters[key],
        nowMs,
        window.durationMs,
      );
      const nextCount = current.count + units;
      nextCounters[key] = {
        windowStartedAtMs: current.windowStartedAtMs,
        count: nextCount,
      };
      counts[window.name] = nextCount;
      limits[window.name] = window.limit ?? null;
      if (window.limit !== undefined && nextCount > window.limit) {
        wouldReject = true;
      }
    }

    if (
      policy.mode === "enforce" &&
      policy.windows.some((window) => window.limit === undefined)
    ) {
      throw new HttpsError(
        "failed-precondition",
        `Quota enforcement for ${policy.route} is missing a configured limit.`,
      );
    }

    const maxWindowMs = Math.max(
      ...policy.windows.map((window) => window.durationMs),
    );
    const expiresAtMs = nowMs + maxWindowMs + defaultRetentionPaddingMs;
    tx.set(
      quotaRef,
      {
        uid: args.uid,
        counters: nextCounters,
        updatedAtMs: nowMs,
        expiresAtMs,
      },
      { merge: true },
    );

    return {
      route: policy.route,
      accepted: policy.mode !== "enforce" || !wouldReject,
      wouldReject,
      mode: policy.mode,
      units,
      counters: counts,
      limits,
      expiresAtMs,
    } satisfies AbuseQuotaDecision;
  });

  logQuotaDecision(args.uid, decision);
  if (!decision.accepted) {
    throw new HttpsError(
      "resource-exhausted",
      `Quota exceeded for ${decision.route}.`,
      {
        route: decision.route,
        retryable: true,
      },
    );
  }
  return decision;
}

export async function cleanupExpiredAbuseQuota(args: {
  db: Firestore;
  nowMs?: number;
  batchSize?: number;
}): Promise<{ scanned: number; deleted: number }> {
  const nowMs = args.nowMs ?? Date.now();
  const batchSize = args.batchSize ?? 200;
  if (!Number.isSafeInteger(batchSize) || batchSize <= 0 || batchSize > 500) {
    throw new Error("Abuse quota cleanup batchSize must be in 1..500.");
  }
  const snapshot = await args.db
    .collection(abuseQuotaCollection)
    .where("expiresAtMs", "<=", nowMs)
    .orderBy("expiresAtMs", "asc")
    .limit(batchSize)
    .get();
  if (snapshot.empty) {
    return { scanned: 0, deleted: 0 };
  }
  const batch = args.db.batch();
  for (const doc of snapshot.docs) {
    batch.delete(doc.ref);
  }
  await batch.commit();
  return {
    scanned: snapshot.size,
    deleted: snapshot.size,
  };
}

function currentCounter(
  stored: QuotaCounter | undefined,
  nowMs: number,
  durationMs: number,
): QuotaCounter {
  if (
    !stored ||
    nowMs < stored.windowStartedAtMs ||
    nowMs - stored.windowStartedAtMs >= durationMs
  ) {
    return {
      windowStartedAtMs: nowMs,
      count: 0,
    };
  }
  return stored;
}

function decodeCounters(value: unknown): Record<string, QuotaCounter> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  const out: Record<string, QuotaCounter> = {};
  for (const [key, candidate] of Object.entries(
    value as Record<string, unknown>,
  )) {
    if (!candidate || typeof candidate !== "object" || Array.isArray(candidate)) {
      continue;
    }
    const record = candidate as Record<string, unknown>;
    if (
      typeof record.windowStartedAtMs !== "number" ||
      !Number.isSafeInteger(record.windowStartedAtMs) ||
      typeof record.count !== "number" ||
      !Number.isSafeInteger(record.count) ||
      record.count < 0
    ) {
      continue;
    }
    out[key] = {
      windowStartedAtMs: record.windowStartedAtMs,
      count: record.count,
    };
  }
  return out;
}

function counterKey(
  route: AbuseQuotaRoute,
  windowName: AbuseQuotaWindowPolicy["name"],
): string {
  return `${route}_${windowName}`;
}

function validatePolicy(
  policy: AbuseQuotaPolicy,
  expectedRoute: AbuseQuotaRoute,
): void {
  if (policy.route !== expectedRoute) {
    throw new Error("Quota policy route does not match requested route.");
  }
  if (policy.windows.length === 0) {
    throw new Error("Quota policy must contain at least one window.");
  }
  const names = new Set<string>();
  for (const window of policy.windows) {
    if (names.has(window.name)) {
      throw new Error(`Quota policy contains duplicate ${window.name} window.`);
    }
    names.add(window.name);
    if (!Number.isSafeInteger(window.durationMs) || window.durationMs <= 0) {
      throw new Error("Quota window duration must be a positive safe integer.");
    }
    if (
      window.limit !== undefined &&
      (!Number.isSafeInteger(window.limit) || window.limit <= 0)
    ) {
      throw new Error("Quota window limit must be a positive safe integer.");
    }
  }
}

export function readAbuseControlMode(
  raw: string | undefined = process.env.ABUSE_CONTROL_MODE,
): AbuseControlMode {
  return raw?.trim().toLowerCase() === "enforce" ? "enforce" : "monitor";
}

function readPositiveInt(raw: string | undefined): number | undefined {
  const value = raw?.trim();
  if (!value || !/^[1-9][0-9]*$/.test(value)) {
    return undefined;
  }
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed <= 0) {
    return undefined;
  }
  return parsed;
}

function handleInvalidOptionalLimit(
  envName: string,
  max: number,
  env: NodeJS.ProcessEnv,
): undefined {
  const mode = readAbuseControlMode(env.ABUSE_CONTROL_MODE);
  console.error("abuse_configuration_invalid", {
    envName,
    mode,
    expected: `integer in 1..${max}`,
  });
  if (mode === "enforce") {
    throw new HttpsError(
      "failed-precondition",
      `Abuse-control configuration ${envName} is invalid.`,
    );
  }
  return undefined;
}

function logQuotaDecision(uid: string, decision: AbuseQuotaDecision): void {
  console.log("callable_quota", {
    route: decision.route,
    mode: decision.mode,
    accepted: decision.accepted,
    wouldReject: decision.wouldReject,
    units: decision.units,
    counters: decision.counters,
    limits: decision.limits,
    uidHash: createHash("sha256").update(uid).digest("hex").slice(0, 16),
  });
}
