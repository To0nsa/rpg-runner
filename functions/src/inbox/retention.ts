import { FieldPath, type Firestore } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { assertAccountActiveInTransaction, isAccountDeletionInProgressError } from "../account/deletion_guard.js";
import { inboxCollections } from "./contracts.js";
import { inboxMessageExpiry } from "./retention_policy.js";
import { decodeSystemMessage, deleteInboxMessage } from "./store.js";
import { safeInteger } from "./validators.js";

/** Bounded expiry cleanup plus a rotating compatibility sweep for pre-policy messages.
 * Every removal rechecks current claim/read state. Cursor CAS prevents an overlapping
 * invocation from replacing newer progress; skipped failures are reported and revisited.
 */
export async function maintainInboxRetention(args: { db: Firestore; nowMs?: number; batchSize?: number }) {
  const { db } = args;
  const nowMs = safeInteger(args.nowMs ?? Date.now(), "nowMs");
  // At most 200 due documents and 200 compatibility documents per hourly invocation.
  const batchSize = args.batchSize ?? 200;
  if (!Number.isSafeInteger(batchSize) || batchSize < 1 || batchSize > 200) throw new Error("Inbox batchSize must be in 1..200.");
  const result = { expiredScanned: 0, deleted: 0, repairScanned: 0, repaired: 0,
    accountDeletionSkipped: 0, failed: 0, expiredBacklog: false, sweepHasMore: false, checkpointAdvanced: false };
  const handleFailure = (error: unknown, messageId: string) => {
    if (isAccountDeletionInProgressError(error)) result.accountDeletionSkipped += 1;
    else {
      result.failed += 1;
      logger.error("inboxRetentionDocumentFailed", { messageId, error });
    }
  };
  const due = await db.collection(inboxCollections.messages)
    .where("expiresAtMs", ">=", 0).where("expiresAtMs", "<=", nowMs)
    .orderBy("expiresAtMs").limit(batchSize + 1).get();
  result.expiredBacklog = due.size > batchSize;
  for (const doc of due.docs.slice(0, batchSize)) {
    result.expiredScanned += 1;
    try {
      const deletion = await deleteInboxMessage({ db, uid: doc.data().uid, messageId: doc.id, nowMs, onlyExpired: true });
      if (deletion.deleted) result.deleted += 1;
    } catch (error) { handleFailure(error, doc.id); }
  }

  const stateRef = db.collection("maintenance_state").doc("inbox_retention_v1");
  const stateDoc = await stateRef.get();
  const state = stateDoc.data();
  const revision = safeInteger(state?.revision ?? 0, "retention revision");
  let query = db.collection(inboxCollections.messages).orderBy(FieldPath.documentId());
  if (typeof state?.cursor === "string") query = query.startAfter(state.cursor);
  const page = await query.limit(batchSize + 1).get();
  const docs = page.docs.slice(0, batchSize);
  result.sweepHasMore = page.size > batchSize;
  for (const doc of docs) {
    result.repairScanned += 1;
    try {
      const uid: string = doc.data().uid;
      const repair = await db.runTransaction(async (tx) => {
        await assertAccountActiveInTransaction(tx, db, uid);
        const current = await tx.get(doc.ref);
        if (!current.exists) return { repaired: false, expired: false };
        const message = decodeSystemMessage(current.data(), doc.id, uid);
        const expiresAtMs = inboxMessageExpiry(message);
        const repaired = current.data()!.expiresAtMs !== expiresAtMs;
        if (repaired) tx.update(doc.ref, { expiresAtMs });
        return { repaired, expired: expiresAtMs !== null && expiresAtMs <= nowMs };
      });
      if (repair.repaired) result.repaired += 1;
      if (repair.expired) {
        const deletion = await deleteInboxMessage({ db, uid, messageId: doc.id, nowMs, onlyExpired: true });
        if (deletion.deleted) result.deleted += 1;
      }
    } catch (error) { handleFailure(error, doc.id); }
  }
  result.checkpointAdvanced = await db.runTransaction(async (tx) => {
    const current = await tx.get(stateRef);
    if ((current.data()?.revision ?? 0) !== revision) return false;
    tx.set(stateRef, { revision: revision + 1,
      cursor: result.sweepHasMore ? docs.at(-1)!.id : null, updatedAtMs: nowMs });
    return true;
  });
  return result;
}
