import { FieldPath, type Firestore } from "firebase-admin/firestore";

import {
  canonicalMergeWriteData,
  canonicalWriteData,
  resolveCanonicalStateForTransaction,
} from "../ownership/canonical_store.js";
import {
  reconcilePendingRewardGrantsForTransaction,
  RewardGrantInvariantViolationError,
} from "../ownership/reward_grants.js";
import { logSettlementMetric } from "./settlement_metrics.js";

const rewardGrantsCollection = "reward_grants";
const maintenanceCollection = "system_maintenance";
const migrationStateDocument = "legacy_reward_grant_migration";
const legacyLifecycleStates = [
  "validated_settled",
  "revocation_visible",
] as const;

export type LegacyRewardGrantMigrationMode = "off" | "inventory" | "apply";

export interface RewardGrantBackfillOptions {
  nowMs?: number;
  maxDocs?: number;
  mode?: LegacyRewardGrantMigrationMode;
}

/** A bounded page result used for migration logs and the operator runbook. */
export interface RewardGrantBackfillResult {
  mode: LegacyRewardGrantMigrationMode;
  nowMs: number;
  scannedCount: number;
  alreadyAppliedCount: number;
  repairedAppliedCount: number;
  terminalizedRevocationCount: number;
  invariantViolationCount: number;
  nextCursor: string | null;
  completed: boolean;
}

/**
 * Inventories or repairs legacy grants without making profile reads a payout path.
 *
 * It processes a cursor-bounded page in document-id order. `apply` uses the
 * same canonical idempotency helper as settlement; `inventory` never mutates
 * grants or canonical ownership (it does persist its paging cursor).
 */
export async function backfillLegacyRewardGrantStates(args: {
  db: Firestore;
  options?: RewardGrantBackfillOptions;
}): Promise<RewardGrantBackfillResult> {
  const mode = args.options?.mode ?? "inventory";
  const nowMs = args.options?.nowMs ?? Date.now();
  const maxDocs = clampBatchSize(args.options?.maxDocs);
  if (mode === "off") {
    return {
      mode,
      nowMs,
      scannedCount: 0,
      alreadyAppliedCount: 0,
      repairedAppliedCount: 0,
      terminalizedRevocationCount: 0,
      invariantViolationCount: 0,
      nextCursor: null,
      completed: false,
    };
  }

  const stateRef = args.db
    .collection(maintenanceCollection)
    .doc(migrationStateDocument);
  const stateSnapshot = await stateRef.get();
  const storedMode = stateSnapshot.get("mode");
  const completedAtMs = stateSnapshot.get("completedAtMs");
  if (storedMode === mode && typeof completedAtMs === "number") {
    return {
      mode,
      nowMs,
      scannedCount: 0,
      alreadyAppliedCount: 0,
      repairedAppliedCount: 0,
      terminalizedRevocationCount: 0,
      invariantViolationCount: 0,
      nextCursor: null,
      completed: true,
    };
  }

  const storedCursor = stateSnapshot.get("cursor");
  const cursor =
    typeof storedCursor === "string" && storedCursor.trim().length > 0
      ? storedCursor.trim()
      : null;
  let query = args.db
    .collection(rewardGrantsCollection)
    .where("lifecycleState", "in", legacyLifecycleStates)
    .orderBy(FieldPath.documentId())
    .limit(maxDocs);
  if (cursor !== null) {
    query = query.startAfter(cursor);
  }
  const page = await query.get();

  let alreadyAppliedCount = 0;
  let repairedAppliedCount = 0;
  let terminalizedRevocationCount = 0;
  let invariantViolationCount = 0;
  for (const rewardGrant of page.docs) {
    const outcome = await inspectOrRepairLegacyGrant({
      db: args.db,
      runSessionId: rewardGrant.id,
      mode,
      nowMs,
    });
    if (outcome === "already_applied") {
      alreadyAppliedCount += 1;
    } else if (outcome === "repaired_applied") {
      repairedAppliedCount += 1;
    } else if (outcome === "terminalized_revocation") {
      terminalizedRevocationCount += 1;
    } else if (outcome === "invariant_violation") {
      invariantViolationCount += 1;
    }
  }

  const pageIsFull = page.size === maxDocs;
  const nextCursor = pageIsFull ? page.docs.at(-1)?.id ?? null : null;
  const completed = !pageIsFull;
  await stateRef.set(
    {
      mode,
      cursor: nextCursor,
      updatedAtMs: nowMs,
      ...(completed ? { completedAtMs: nowMs } : { completedAtMs: null }),
      lastPage: {
        scannedCount: page.size,
        alreadyAppliedCount,
        repairedAppliedCount,
        terminalizedRevocationCount,
        invariantViolationCount,
      },
    },
    { merge: true },
  );

  const result: RewardGrantBackfillResult = {
    mode,
    nowMs,
    scannedCount: page.size,
    alreadyAppliedCount,
    repairedAppliedCount,
    terminalizedRevocationCount,
    invariantViolationCount,
    nextCursor,
    completed,
  };
  logSettlementMetric({
    event: "legacy_reward_grant_migration",
    deliverySource: "legacy_migration",
    outcome: mode,
    scannedCount: result.scannedCount,
    settledCount: result.repairedAppliedCount,
    invariantViolationCount: result.invariantViolationCount,
  });
  return result;
}

async function inspectOrRepairLegacyGrant(args: {
  db: Firestore;
  runSessionId: string;
  mode: Exclude<LegacyRewardGrantMigrationMode, "off">;
  nowMs: number;
}): Promise<
  | "already_applied"
  | "repaired_applied"
  | "terminalized_revocation"
  | "invariant_violation"
> {
  try {
    return await args.db.runTransaction(async (tx) => {
      const rewardGrantRef = args.db
        .collection(rewardGrantsCollection)
        .doc(args.runSessionId);
      const rewardGrantSnapshot = await tx.get(rewardGrantRef);
      if (!rewardGrantSnapshot.exists) {
        return "invariant_violation";
      }
      const rewardGrant = rewardGrantSnapshot.data() as Record<string, unknown>;
      const lifecycleState = rewardGrant.lifecycleState;
      if (
        lifecycleState !== "validated_settled" &&
        lifecycleState !== "revocation_visible"
      ) {
        return "invariant_violation";
      }
      const uid = optionalNonEmptyString(rewardGrant.uid);
      const boundRunSessionId = optionalNonEmptyString(rewardGrant.runSessionId);
      if (uid === null || boundRunSessionId !== args.runSessionId) {
        return "invariant_violation";
      }

      const resolvedCanonical = await resolveCanonicalStateForTransaction({
        db: args.db,
        tx,
        uid,
      });
      const appliedGrantIds = resolvedCanonical.canonical.progression
        .appliedRewardGrantIds;
      const alreadyApplied =
        Array.isArray(appliedGrantIds) &&
        appliedGrantIds.includes(args.runSessionId);
      if (args.mode === "inventory") {
        if (lifecycleState === "revocation_visible") {
          return "terminalized_revocation";
        }
        return alreadyApplied ? "already_applied" : "repaired_applied";
      }

      const reconciled = await reconcilePendingRewardGrantsForTransaction({
        db: args.db,
        tx,
        uid,
        canonicalState: resolvedCanonical.canonical,
        nowMs: args.nowMs,
        settlementGrantId: args.runSessionId,
      });
      if (resolvedCanonical.exists && reconciled.canonicalChanged) {
        tx.set(
          resolvedCanonical.canonicalRef,
          canonicalMergeWriteData(uid, reconciled.canonicalState),
          { merge: true },
        );
      } else if (!resolvedCanonical.exists) {
        tx.set(
          resolvedCanonical.canonicalRef,
          canonicalWriteData(uid, reconciled.canonicalState),
        );
      }
      if (reconciled.revokedGrantCount > 0) {
        return "terminalized_revocation";
      }
      if (reconciled.appliedGrantCount > 0 && !alreadyApplied) {
        return "repaired_applied";
      }
      return "already_applied";
    });
  } catch (error) {
    if (error instanceof RewardGrantInvariantViolationError) {
      return "invariant_violation";
    }
    throw error;
  }
}

function clampBatchSize(value: number | undefined): number {
  if (!Number.isSafeInteger(value) || value === undefined) {
    return 64;
  }
  return Math.max(1, Math.min(value, 200));
}

function optionalNonEmptyString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}
