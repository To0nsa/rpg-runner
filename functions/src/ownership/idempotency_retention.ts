import {
  FieldPath,
  FieldValue,
  type Firestore,
  type Query,
} from "firebase-admin/firestore";

import {
  ownershipIdempotencyRetentionMs,
  ownershipIdempotencySchemaVersion,
} from "./canonical_store.js";
import {
  isOwnershipRejectedReason,
  type IdempotencyDocument,
  type OwnershipRejectedReason,
} from "./contracts.js";

const maintenanceStateCollection = "maintenance_state";
const compactionStateDoc = "ownership_idempotency_compaction_v2";

export interface OwnershipIdempotencyMaintenanceResult {
  expiredScanned: number;
  expiredDeleted: number;
  migrationScanned: number;
  migrationCompacted: number;
  migrationCompleted: boolean;
  migrationCursor: string | null;
}

export async function maintainOwnershipIdempotencyRetention(args: {
  db: Firestore;
  nowMs?: number;
  batchSize?: number;
}): Promise<OwnershipIdempotencyMaintenanceResult> {
  const nowMs = args.nowMs ?? Date.now();
  const batchSize = args.batchSize ?? 200;
  validateBatchSize(batchSize);
  const expired = await deleteExpiredIdempotency({
    db: args.db,
    nowMs,
    batchSize,
  });
  const migration = await compactLegacyIdempotency({
    db: args.db,
    nowMs,
    batchSize,
  });
  return {
    expiredScanned: expired.scanned,
    expiredDeleted: expired.deleted,
    migrationScanned: migration.scanned,
    migrationCompacted: migration.compacted,
    migrationCompleted: migration.completed,
    migrationCursor: migration.cursor,
  };
}

async function deleteExpiredIdempotency(args: {
  db: Firestore;
  nowMs: number;
  batchSize: number;
}): Promise<{ scanned: number; deleted: number }> {
  const snapshot = await args.db
    .collectionGroup("idempotency")
    .where("expiresAtMs", "<=", args.nowMs)
    .orderBy("expiresAtMs", "asc")
    .limit(args.batchSize)
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

async function compactLegacyIdempotency(args: {
  db: Firestore;
  nowMs: number;
  batchSize: number;
}): Promise<{
  scanned: number;
  compacted: number;
  completed: boolean;
  cursor: string | null;
}> {
  const stateRef = args.db
    .collection(maintenanceStateCollection)
    .doc(compactionStateDoc);
  const stateSnapshot = await stateRef.get();
  const state = stateSnapshot.data();
  if (state?.completed === true) {
    return {
      scanned: 0,
      compacted: 0,
      completed: true,
      cursor: null,
    };
  }

  const cursor =
    typeof state?.cursor === "string" && state.cursor.trim().length > 0
      ? state.cursor.trim()
      : null;
  let query: Query = args.db
    .collectionGroup("idempotency")
    .orderBy(FieldPath.documentId())
    .limit(args.batchSize);
  if (cursor) {
    query = query.startAfter(args.db.doc(cursor));
  }
  const snapshot = await query.get();
  const batch = args.db.batch();
  let compacted = 0;
  for (const doc of snapshot.docs) {
    const data = doc.data() as IdempotencyDocument;
    if (
      data.schemaVersion === ownershipIdempotencySchemaVersion &&
      data.result === undefined
    ) {
      continue;
    }
    const outcome = compactOutcome(data);
    batch.set(
      doc.ref,
      {
        schemaVersion: ownershipIdempotencySchemaVersion,
        outcome,
        result: FieldValue.delete(),
        createdAtMs: readNonNegativeInt(data.createdAtMs) ?? args.nowMs,
        expiresAtMs: args.nowMs + ownershipIdempotencyRetentionMs,
      },
      { merge: true },
    );
    compacted += 1;
  }

  const completed = snapshot.size < args.batchSize;
  const nextCursor =
    completed || snapshot.empty
      ? null
      : snapshot.docs[snapshot.docs.length - 1]!.ref.path;
  batch.set(
    stateRef,
    {
      cursor: nextCursor,
      completed,
      updatedAtMs: args.nowMs,
      ...(completed ? { completedAtMs: args.nowMs } : {}),
    },
    { merge: true },
  );
  await batch.commit();
  return {
    scanned: snapshot.size,
    compacted,
    completed,
    cursor: nextCursor,
  };
}

function compactOutcome(data: IdempotencyDocument): {
  resultingRevision: number;
  rejectedReason: OwnershipRejectedReason | null;
} {
  const result = data.result;
  const revision = readNonNegativeInt(result?.newRevision) ?? 0;
  const rejectedRaw = result?.rejectedReason;
  const rejectedReason =
    rejectedRaw === null ||
    (typeof rejectedRaw === "string" &&
      isOwnershipRejectedReason(rejectedRaw))
      ? rejectedRaw
      : "invalidCommand";
  return {
    resultingRevision: revision,
    rejectedReason,
  };
}

function readNonNegativeInt(value: unknown): number | null {
  if (
    typeof value !== "number" ||
    !Number.isSafeInteger(value) ||
    value < 0
  ) {
    return null;
  }
  return value;
}

function validateBatchSize(value: number): void {
  if (!Number.isSafeInteger(value) || value <= 0 || value > 200) {
    throw new Error("Ownership idempotency batchSize must be in 1..200.");
  }
}
