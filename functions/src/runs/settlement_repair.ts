import {
  FieldPath,
  FieldValue,
  type DocumentData,
  type Firestore,
  type Query,
  type QuerySnapshot,
} from "firebase-admin/firestore";

import {
  assertAccountActiveInTransaction,
  isAccountDeletionInProgressError,
} from "../account/deletion_guard.js";
import {
  settleAcceptedRunSession,
  type AcceptedRunSettlementOutcome,
} from "./reward_settlement.js";
import {
  logSettlementMetric,
  settlementErrorClass,
} from "./settlement_metrics.js";

const runSessionsCollection = "run_sessions";
const maintenanceCollection = "system_maintenance";
const maintenanceDocument = "settlement_repair";
const settlementPendingState = "settlement_pending";
const retryableDisposition = "retryable";
const quarantinedDisposition = "quarantined";

export interface SettlementRepairOptions {
  batchSize: number;
  staleThresholdMs: number;
  nowMs?: number;
}

export interface SettlementRepairResult {
  scannedCount: number;
  classifiedCount: number;
  settledCount: number;
  alreadySettledCount: number;
  quarantinedCount: number;
  failureCount: number;
  retryablePendingCount: number;
  totalQuarantinedCount: number;
  oldestRetryableAgeMs: number | null;
  nextCursor: string | null;
  noProgress: boolean;
}

type SettlementRunner = (args: {
  db: Firestore;
  runSessionId: string;
  nowMs: number;
  deliverySource: "repair";
}) => Promise<AcceptedRunSettlementOutcome>;

/**
 * Repairs one stable page of retryable settlement handoffs.
 *
 * Legacy pending sessions are classified through a separate cursor before the
 * retry query. Invariant violations are marked non-retryable in a transaction,
 * while infrastructure failures remain on the retryable lane.
 */
export async function repairPendingSettlements(args: {
  db: Firestore;
  options: SettlementRepairOptions;
  settle?: SettlementRunner;
}): Promise<SettlementRepairResult> {
  const batchSize = clampBatchSize(args.options.batchSize);
  const nowMs = args.options.nowMs ?? Date.now();
  const settle = args.settle ?? settleAcceptedRunSession;
  const sessions = args.db.collection(runSessionsCollection);
  const maintenanceRef = args.db
    .collection(maintenanceCollection)
    .doc(maintenanceDocument);
  const maintenanceSnapshot = await maintenanceRef.get();
  const maintenance = maintenanceSnapshot.data() as
    | Record<string, unknown>
    | undefined;

  const classifiedCount = await classifyPendingPage({
    db: args.db,
    sessions,
    maintenanceRef,
    cursor: readCursor(maintenance?.classificationCursor),
    batchSize,
    nowMs,
  });

  const requestedCursor = readCursor(maintenance?.repairCursor);
  let repairPage = await loadRetryablePage({
    sessions,
    cursor: requestedCursor,
    batchSize,
  });
  let effectiveCursor = requestedCursor;
  if (repairPage.empty && requestedCursor !== null) {
    effectiveCursor = null;
    repairPage = await loadRetryablePage({
      sessions,
      cursor: null,
      batchSize,
    });
  }

  let settledCount = 0;
  let alreadySettledCount = 0;
  let quarantinedCount = 0;
  let failureCount = 0;
  for (const session of repairPage.docs) {
    const pendingAgeMs = durationSinceMs(
      session.get("settlementPendingAtMs"),
      nowMs,
    );
    const attemptRecorded = await updateSettlementRepairSession({
      db: args.db,
      runSessionId: session.id,
      data: {
        settlementRepairAttempts: FieldValue.increment(1),
        settlementRepairLastAttemptAtMs: nowMs,
        settlementRepairLastOutcome: "attempting",
      },
    });
    if (!attemptRecorded) {
      continue;
    }
    try {
      const outcome = await settle({
        db: args.db,
        runSessionId: session.id,
        nowMs,
        deliverySource: "repair",
      });
      if (outcome === "settled") {
        settledCount += 1;
      } else if (outcome === "already_settled") {
        alreadySettledCount += 1;
      } else if (outcome === "invariant_violation") {
        const quarantined = await quarantineSettlementIncident({
          db: args.db,
          runSessionId: session.id,
          nowMs,
        });
        if (quarantined) {
          quarantinedCount += 1;
        }
      } else {
        await updateSettlementRepairSession({
          db: args.db,
          runSessionId: session.id,
          data: { settlementRepairLastOutcome: outcome },
        });
      }
      if (
        pendingAgeMs !== null &&
        pendingAgeMs >= args.options.staleThresholdMs
      ) {
        logSettlementMetric({
          event: "stale_settlement_repair",
          runSessionId: session.id,
          deliverySource: "repair",
          outcome,
          pendingAgeMs,
        });
      }
    } catch (error) {
      if (isAccountDeletionInProgressError(error)) {
        continue;
      }
      failureCount += 1;
      await updateSettlementRepairSession({
        db: args.db,
        runSessionId: session.id,
        data: {
          settlementRepairLastOutcome: "infrastructure_failure",
          settlementRepairLastErrorClass: settlementErrorClass(error),
        },
      });
      logSettlementMetric({
        event: "settlement_repair_failure",
        runSessionId: session.id,
        deliverySource: "repair",
        errorClass: settlementErrorClass(error),
      });
    }
  }

  const nextCursor =
    repairPage.size === batchSize
      ? repairPage.docs.at(-1)?.id ?? effectiveCursor
      : null;
  await maintenanceRef.set(
    {
      repairCursor: nextCursor,
      repairPageUpdatedAtMs: nowMs,
      repairPage: {
        scannedCount: repairPage.size,
        settledCount,
        alreadySettledCount,
        quarantinedCount,
        failureCount,
      },
    },
    { merge: true },
  );

  const retryableQuery = sessions
    .where("state", "==", settlementPendingState)
    .where("settlementRepairDisposition", "==", retryableDisposition);
  const quarantinedQuery = sessions
    .where("state", "==", settlementPendingState)
    .where("settlementRepairDisposition", "==", quarantinedDisposition);
  const [retryableCountSnapshot, quarantineCountSnapshot, oldestSnapshot] =
    await Promise.all([
      retryableQuery.count().get(),
      quarantinedQuery.count().get(),
      retryableQuery.orderBy("settlementPendingAtMs").limit(1).get(),
    ]);
  const retryablePendingCount = retryableCountSnapshot.data().count;
  const totalQuarantinedCount = quarantineCountSnapshot.data().count;
  const oldestRetryableAgeMs = oldestSnapshot.empty
    ? null
    : durationSinceMs(
        oldestSnapshot.docs[0]?.get("settlementPendingAtMs"),
        nowMs,
      );
  const noProgress =
    retryablePendingCount > 0 &&
    repairPage.empty &&
    classifiedCount === 0;
  logSettlementMetric({
    event: "settlement_repair_scan",
    deliverySource: "repair",
    scannedCount: repairPage.size,
    settledCount,
    invariantViolationCount: quarantinedCount,
    classifiedCount,
    quarantinedCount,
    failureCount,
    retryablePendingCount,
    oldestRetryableAgeMs: oldestRetryableAgeMs ?? undefined,
    pageCursor: nextCursor ?? undefined,
    noProgress,
  });
  return {
    scannedCount: repairPage.size,
    classifiedCount,
    settledCount,
    alreadySettledCount,
    quarantinedCount,
    failureCount,
    retryablePendingCount,
    totalQuarantinedCount,
    oldestRetryableAgeMs,
    nextCursor,
    noProgress,
  };
}

async function updateSettlementRepairSession(args: {
  db: Firestore;
  runSessionId: string;
  data: Record<string, unknown>;
}): Promise<boolean> {
  const sessionRef = args.db
    .collection(runSessionsCollection)
    .doc(args.runSessionId);
  return args.db.runTransaction(async (tx) => {
    const session = await tx.get(sessionRef);
    if (!session.exists || session.get("state") !== settlementPendingState) {
      return false;
    }
    const uid = readCursor(session.get("uid"));
    if (uid === null) {
      return false;
    }
    try {
      await assertAccountActiveInTransaction(tx, args.db, uid);
    } catch (error) {
      if (isAccountDeletionInProgressError(error)) {
        return false;
      }
      throw error;
    }
    tx.set(sessionRef, args.data, { merge: true });
    return true;
  });
}

async function classifyPendingPage(args: {
  db: Firestore;
  sessions: FirebaseFirestore.CollectionReference;
  maintenanceRef: FirebaseFirestore.DocumentReference;
  cursor: string | null;
  batchSize: number;
  nowMs: number;
}): Promise<number> {
  let query = args.sessions
    .where("state", "==", settlementPendingState)
    .orderBy(FieldPath.documentId())
    .limit(args.batchSize);
  if (args.cursor !== null) {
    query = query.startAfter(args.cursor);
  }
  const page = await query.get();
  let classifiedCount = 0;
  for (const session of page.docs) {
    if (session.get("settlementRepairDisposition") !== undefined) {
      continue;
    }
    const classified = await updateSettlementRepairSession({
      db: args.db,
      runSessionId: session.id,
      data: {
        settlementRepairDisposition: retryableDisposition,
        settlementRepairClassifiedAtMs: args.nowMs,
        settlementRepairAttempts: 0,
      },
    });
    if (classified) {
      classifiedCount += 1;
    }
  }
  const nextCursor =
    page.size === args.batchSize
      ? page.docs.at(-1)?.id ?? args.cursor
      : null;
  await args.maintenanceRef.set(
    {
      classificationCursor: nextCursor,
      classificationPageUpdatedAtMs: args.nowMs,
      classificationPage: {
        scannedCount: page.size,
        classifiedCount,
      },
    },
    { merge: true },
  );
  return classifiedCount;
}

async function loadRetryablePage(args: {
  sessions: FirebaseFirestore.CollectionReference;
  cursor: string | null;
  batchSize: number;
}): Promise<QuerySnapshot<DocumentData>> {
  let query: Query<DocumentData> = args.sessions
    .where("state", "==", settlementPendingState)
    .where("settlementRepairDisposition", "==", retryableDisposition)
    .orderBy(FieldPath.documentId())
    .limit(args.batchSize);
  if (args.cursor !== null) {
    query = query.startAfter(args.cursor);
  }
  return query.get();
}

async function quarantineSettlementIncident(args: {
  db: Firestore;
  runSessionId: string;
  nowMs: number;
}): Promise<boolean> {
  const sessionRef = args.db
    .collection(runSessionsCollection)
    .doc(args.runSessionId);
  return args.db.runTransaction(async (tx) => {
    const session = await tx.get(sessionRef);
    if (
      !session.exists ||
      session.get("state") !== settlementPendingState ||
      session.get("settlementRepairDisposition") !== retryableDisposition
    ) {
      return false;
    }
    const uid = readCursor(session.get("uid"));
    if (uid === null) {
      return false;
    }
    try {
      await assertAccountActiveInTransaction(tx, args.db, uid);
    } catch (error) {
      if (isAccountDeletionInProgressError(error)) {
        return false;
      }
      throw error;
    }
    tx.set(
      sessionRef,
      {
        settlementRepairDisposition: quarantinedDisposition,
        settlementRepairQuarantinedAtMs: args.nowMs,
        settlementRepairLastAttemptAtMs: args.nowMs,
        settlementRepairLastOutcome: "invariant_violation",
        settlementRepairIncidentReason: "persisted_data_invariant",
      },
      { merge: true },
    );
    return true;
  });
}

function readCursor(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length === 0 ? null : trimmed;
}

function clampBatchSize(value: number): number {
  if (!Number.isSafeInteger(value)) {
    return 64;
  }
  return Math.max(1, Math.min(value, 200));
}

function durationSinceMs(value: unknown, nowMs: number): number | null {
  if (!Number.isSafeInteger(value)) {
    return null;
  }
  return Math.max(0, nowMs - Number(value));
}
