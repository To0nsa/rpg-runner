import {
  FieldValue,
  type DocumentReference,
  type Firestore,
} from "firebase-admin/firestore";

import {
  createCloudTasksRunValidationTaskDispatcher,
  type RunValidationTaskDispatcher,
} from "./submission_store.js";
import {
  defaultValidationLeaseDurationMs,
  defaultValidationRepairReenqueueCooldownMs,
  defaultValidationRepairStaleThresholdMs,
} from "./session_state.js";

const runSessionsCollection = "run_sessions";
const defaultValidationRepairBatchSize = 64;

export interface ValidationRepairResult {
  nowMs: number;
  scannedCount: number;
  reclaimedLeaseCount: number;
  requeuedPendingCount: number;
  skippedCount: number;
  failureCount: number;
}

interface ValidationRepairOptions {
  batchSize?: number;
  leaseDurationMs?: number;
  pendingStaleThresholdMs?: number;
  reenqueueCooldownMs?: number;
}

interface ValidationRepairCandidate {
  ref: DocumentReference;
  runSessionId: string;
}

interface PreparedValidationRepair {
  runSessionId: string;
  generation: number;
  reclaimedLease: boolean;
}

/**
 * Recovers expired leases and pending sessions whose original task may be gone.
 *
 * Firestore state is advanced before enqueue. A failed enqueue makes the
 * session immediately repair-eligible again, while the generation-specific
 * Cloud Tasks name keeps duplicate scheduler delivery idempotent.
 */
export async function repairStaleRunValidations(args: {
  db: Firestore;
  nowMs?: number;
  dispatcher?: RunValidationTaskDispatcher;
  options?: ValidationRepairOptions;
}): Promise<ValidationRepairResult> {
  const nowMs = args.nowMs ?? Date.now();
  const batchSize = positiveInt(
    args.options?.batchSize,
    defaultValidationRepairBatchSize,
  );
  const leaseDurationMs = positiveInt(
    args.options?.leaseDurationMs,
    defaultValidationLeaseDurationMs,
  );
  const pendingStaleThresholdMs = positiveInt(
    args.options?.pendingStaleThresholdMs,
    defaultValidationRepairStaleThresholdMs,
  );
  const reenqueueCooldownMs = positiveInt(
    args.options?.reenqueueCooldownMs,
    defaultValidationRepairReenqueueCooldownMs,
  );
  const dispatcher =
    args.dispatcher ?? createCloudTasksRunValidationTaskDispatcher();
  const candidates = await loadRepairCandidates({
    db: args.db,
    nowMs,
    batchSize,
    leaseDurationMs,
    pendingStaleThresholdMs,
  });

  let reclaimedLeaseCount = 0;
  let requeuedPendingCount = 0;
  let skippedCount = 0;
  let failureCount = 0;
  for (const candidate of candidates) {
    const prepared = await prepareRepairCandidate({
      db: args.db,
      candidate,
      nowMs,
      leaseDurationMs,
      pendingStaleThresholdMs,
      reenqueueCooldownMs,
    });
    if (!prepared) {
      skippedCount += 1;
      continue;
    }

    try {
      await dispatcher.enqueueRunValidationTask({
        runSessionId: prepared.runSessionId,
        taskKey: `repair-${prepared.generation}`,
      });
      if (prepared.reclaimedLease) {
        reclaimedLeaseCount += 1;
      } else {
        requeuedPendingCount += 1;
      }
    } catch {
      failureCount += 1;
      await makeRepairImmediatelyEligible({
        db: args.db,
        prepared,
        nowMs,
      });
    }
  }

  return {
    nowMs,
    scannedCount: candidates.length,
    reclaimedLeaseCount,
    requeuedPendingCount,
    skippedCount,
    failureCount,
  };
}

async function loadRepairCandidates(args: {
  db: Firestore;
  nowMs: number;
  batchSize: number;
  leaseDurationMs: number;
  pendingStaleThresholdMs: number;
}): Promise<ValidationRepairCandidate[]> {
  const sessions = args.db.collection(runSessionsCollection);
  const [expiredLease, legacyLease, duePending, legacyPending] =
    await Promise.all([
      sessions
        .where("state", "==", "validating")
        .where("validationLeaseExpiresAtMs", "<=", args.nowMs)
        .limit(args.batchSize)
        .get(),
      sessions
        .where("state", "==", "validating")
        .where(
          "validationStartedAtMs",
          "<=",
          args.nowMs - args.leaseDurationMs,
        )
        .limit(args.batchSize)
        .get(),
      sessions
        .where("state", "==", "pending_validation")
        .where("validationNextAttemptAtMs", "<=", args.nowMs)
        .limit(args.batchSize)
        .get(),
      sessions
        .where("state", "==", "pending_validation")
        .where(
          "updatedAtMs",
          "<=",
          args.nowMs - args.pendingStaleThresholdMs,
        )
        .limit(args.batchSize)
        .get(),
    ]);
  const candidates = new Map<string, ValidationRepairCandidate>();
  for (const snapshot of [
    expiredLease,
    legacyLease,
    duePending,
    legacyPending,
  ]) {
    for (const doc of snapshot.docs) {
      candidates.set(doc.id, {
        ref: doc.ref,
        runSessionId: doc.id,
      });
      if (candidates.size >= args.batchSize) {
        return [...candidates.values()];
      }
    }
  }
  return [...candidates.values()];
}

async function prepareRepairCandidate(args: {
  db: Firestore;
  candidate: ValidationRepairCandidate;
  nowMs: number;
  leaseDurationMs: number;
  pendingStaleThresholdMs: number;
  reenqueueCooldownMs: number;
}): Promise<PreparedValidationRepair | undefined> {
  return args.db.runTransaction(async (tx) => {
    const snapshot = await tx.get(args.candidate.ref);
    if (!snapshot.exists) {
      return undefined;
    }
    const data = snapshot.data() as Record<string, unknown>;
    const state = stringValue(data.state);
    const leaseExpiresAtMs =
      intValue(data.validationLeaseExpiresAtMs) ??
      addIfPresent(
        intValue(data.validationStartedAtMs),
        args.leaseDurationMs,
      );
    const pendingEligibleAtMs =
      intValue(data.validationNextAttemptAtMs) ??
      addIfPresent(
        intValue(data.updatedAtMs),
        args.pendingStaleThresholdMs,
      );
    const reclaimingLease =
      state === "validating" &&
      leaseExpiresAtMs !== undefined &&
      leaseExpiresAtMs <= args.nowMs;
    const requeueingPending =
      state === "pending_validation" &&
      pendingEligibleAtMs !== undefined &&
      pendingEligibleAtMs <= args.nowMs;
    if (!reclaimingLease && !requeueingPending) {
      return undefined;
    }

    const generation = Math.max(
      0,
      intValue(data.validationTaskGeneration) ?? 0,
    ) + 1;
    tx.set(
      args.candidate.ref,
      {
        ...(reclaimingLease
          ? {
              state: "pending_validation",
              validationLeaseToken: FieldValue.delete(),
              validationLeaseExpiresAtMs: FieldValue.delete(),
              validationLeaseReclaimedAtMs: args.nowMs,
            }
          : {}),
        updatedAtMs: args.nowMs,
        validationTaskGeneration: generation,
        validationLastEnqueuedAtMs: args.nowMs,
        validationNextAttemptAtMs:
          args.nowMs + args.reenqueueCooldownMs,
        message: reclaimingLease
          ? "Expired validation lease recovered; validation retry queued."
          : "Validation retry recovered by scheduled repair.",
      },
      { merge: true },
    );
    return {
      runSessionId: args.candidate.runSessionId,
      generation,
      reclaimedLease: reclaimingLease,
    };
  });
}

async function makeRepairImmediatelyEligible(args: {
  db: Firestore;
  prepared: PreparedValidationRepair;
  nowMs: number;
}): Promise<void> {
  const ref = args.db
    .collection(runSessionsCollection)
    .doc(args.prepared.runSessionId);
  await args.db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    if (!snapshot.exists) {
      return;
    }
    const data = snapshot.data() as Record<string, unknown>;
    if (
      data.state !== "pending_validation" ||
      intValue(data.validationTaskGeneration) !== args.prepared.generation
    ) {
      return;
    }
    tx.set(
      ref,
      {
        updatedAtMs: args.nowMs,
        validationNextAttemptAtMs: args.nowMs,
        validationLastEnqueueFailureAtMs: args.nowMs,
        message: "Validation repair enqueue failed; retry remains pending.",
      },
      { merge: true },
    );
  });
}

function positiveInt(value: number | undefined, fallback: number): number {
  return Number.isSafeInteger(value) && (value ?? 0) > 0
    ? (value as number)
    : fallback;
}

function intValue(value: unknown): number | undefined {
  return typeof value === "number" && Number.isSafeInteger(value)
    ? value
    : undefined;
}

function stringValue(value: unknown): string | undefined {
  return typeof value === "string" ? value : undefined;
}

function addIfPresent(
  value: number | undefined,
  increment: number,
): number | undefined {
  return value === undefined ? undefined : value + increment;
}
