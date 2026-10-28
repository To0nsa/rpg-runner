import { createHash } from "node:crypto";
import { isDeepStrictEqual } from "node:util";
import { FieldPath, type DocumentData, type Firestore, type Transaction } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import { assertAccountActiveInTransaction } from "../account/deletion_guard.js";
import {
  canonicalMergeWriteData,
  canonicalWriteData,
  idempotencyWriteData,
  resolveCanonicalStateForTransaction,
} from "../ownership/canonical_store.js";
import type { OwnershipCommandResult } from "../ownership/contracts.js";
import { inboxCollections, type InboxCursor, type InboxSummary, type SystemMessage } from "./contracts.js";
import { boundedText, safeInteger } from "./validators.js";
import { inboxMessageExpiry } from "./retention_policy.js";
import { assertInboxGiftsEnabled, catalogDefinition, inboxRewardKey, parseInboxRewards } from "./gifts.js";
import { grantCatalogOwnership, normalizeProgressionStore } from "../ownership/store_state.js";
import type { InboxCatalogReward } from "./contracts.js";

const pageSize = 20;
export const emptyInboxSummary: InboxSummary = { revision: 0, unreadCount: 0, unclaimedCount: 0 };

/** Delivery identity survives text edits, policy changes and request retries. */
export function systemMessageId(uid: string, sourceId: string): string {
  return createHash("sha256").update(JSON.stringify([uid, sourceId])).digest("hex");
}

function contentHash(message: SystemMessage): string {
  return createHash("sha256").update(JSON.stringify([
    message.uid, message.sourceId, message.title, message.body, message.rewards,
  ])).digest("hex");
}

function readRemovalReceipt(raw: DocumentData, id: string, uid: string) {
  if (raw.uid !== uid) throw new HttpsError("not-found", "Message not found.");
  if (raw.schemaVersion !== 1 || raw.messageId !== id ||
      typeof raw.contentHash !== "string" || !/^[a-f0-9]{64}$/.test(raw.contentHash)) {
    throw new HttpsError("failed-precondition", "Invalid message removal receipt.");
  }
  safeInteger(raw.deletedAtMs, "deletedAtMs");
  return raw;
}

export function readInboxSummary(raw: DocumentData | undefined): InboxSummary {
  if (!raw) return { ...emptyInboxSummary };
  return {
    revision: safeInteger(raw.revision, "summary revision"),
    unreadCount: safeInteger(raw.unreadCount, "unread count"),
    unclaimedCount: safeInteger(raw.unclaimedCount, "unclaimed count"),
  };
}

function nextSummary(summary: InboxSummary, unread: number, unclaimed: number): InboxSummary {
  return {
    revision: safeInteger(summary.revision + 1, "summary revision"),
    unreadCount: safeInteger(summary.unreadCount + unread, "unread count"),
    unclaimedCount: safeInteger(summary.unclaimedCount + unclaimed, "unclaimed count"),
  };
}

export function decodeSystemMessage(raw: DocumentData | undefined, id: string, uid: string): SystemMessage {
  if (!raw || raw.uid !== uid) throw new HttpsError("not-found", "Message not found.");
  if (![1, 2].includes(raw.schemaVersion) || raw.id !== id) {
    throw new HttpsError("failed-precondition", "Unsupported message format.");
  }
  let rewards;
  try { rewards = parseInboxRewards(raw.rewards); }
  catch { throw new HttpsError("failed-precondition", "Unsupported reward format."); }
  if (raw.schemaVersion === 1 && (rewards.length > 1 || rewards.some((reward) => reward.kind !== "gold"))) {
    throw new HttpsError("failed-precondition", "Unsupported legacy reward format.");
  }
  return {
    schemaVersion: raw.schemaVersion,
    id,
    uid,
    sourceId: boundedText(raw.sourceId, "sourceId", 200),
    title: boundedText(raw.title, "title", 120),
    body: boundedText(raw.body, "body", 2000),
    rewards,
    createdAtMs: safeInteger(raw.createdAtMs, "createdAtMs"),
    readAtMs: raw.readAtMs === null ? null : safeInteger(raw.readAtMs, "readAtMs"),
    claimedAtMs: raw.claimedAtMs === null ? null : safeInteger(raw.claimedAtMs, "claimedAtMs"),
  };
}

export interface SystemMessageDelivery {
  sourceId: string;
  title: string;
  body: string;
  goldAmount?: number;
  attachments?: InboxCatalogReward[];
}

/** Prepare all reads before settlement writes; invoke the returned writer in that transaction. */
export async function prepareSystemMessages(args: {
  db: Firestore;
  tx: Transaction;
  uid: string;
  deliveries: SystemMessageDelivery[];
  nowMs: number;
}): Promise<() => void> {
  if (args.deliveries.length === 0) return () => {};
  if (args.deliveries.length > 29) throw new Error("Too many messages in one transaction.");
  const messages = args.deliveries.map((delivery): SystemMessage => {
    const sourceId = boundedText(delivery.sourceId, "sourceId", 200);
    const amount = safeInteger(delivery.goldAmount ?? 0, "goldAmount");
    const attachments = parseInboxRewards(delivery.attachments ?? []);
    if (attachments.some((reward) => reward.kind === "gold")) throw new HttpsError("invalid-argument", "Use goldAmount for gold.");
    attachments.sort((a, b) => inboxRewardKey(a) < inboxRewardKey(b) ? -1 : inboxRewardKey(a) > inboxRewardKey(b) ? 1 : 0);
    const rewards = parseInboxRewards([...(amount > 0 ? [{ kind: "gold", amount }] : []), ...attachments]);
    return {
      schemaVersion: attachments.length > 0 ? 2 : 1,
      id: systemMessageId(args.uid, sourceId),
      uid: args.uid,
      sourceId,
      title: boundedText(delivery.title, "title", 120),
      body: boundedText(delivery.body, "body", 2000),
      createdAtMs: safeInteger(args.nowMs, "nowMs"),
      readAtMs: null,
      claimedAtMs: null,
      rewards,
    };
  });
  if (new Set(messages.map((message) => message.id)).size !== messages.length) {
    throw new HttpsError("invalid-argument", "Repeated source identity.");
  }
  const summaryRef = args.db.collection(inboxCollections.summaries).doc(args.uid);
  const summary = readInboxSummary((await args.tx.get(summaryRef)).data());
  const refs = messages.map((message) => args.db.collection(inboxCollections.messages).doc(message.id));
  const existing = await args.tx.getAll(...refs,
    ...messages.map((message) => args.db.collection(inboxCollections.receipts).doc(message.id)));
  const pending = messages.filter((message, index) => {
    const removed = existing[index + messages.length].data();
    if (removed) {
      const receipt = readRemovalReceipt(removed, message.id, args.uid);
      if (receipt.contentHash !== contentHash(message)) {
        throw new HttpsError("already-exists", "Delivery identity was reused with different content.");
      }
      return false;
    }
    if (!existing[index].exists) return true;
    const previous = decodeSystemMessage(existing[index].data(), message.id, args.uid);
    if (previous.sourceId !== message.sourceId || previous.title !== message.title ||
        previous.body !== message.body || !isDeepStrictEqual(previous.rewards, message.rewards)) {
      throw new HttpsError("already-exists", "Delivery identity was reused with different content.");
    }
    return false;
  });
  if (pending.some((message) => message.schemaVersion === 2)) await assertInboxGiftsEnabled(args.tx, args.db);
  const updatedSummary = pending.length === 0 ? null : nextSummary(
    summary,
    pending.length,
    pending.filter((message) => message.rewards.length > 0).length,
  );
  return () => {
    if (updatedSummary === null) return;
    for (const message of pending) {
      args.tx.create(args.db.collection(inboxCollections.messages).doc(message.id), { ...message, expiresAtMs: null });
      if (message.rewards.length > 0) {
        args.tx.create(args.db.collection(inboxCollections.rewards).doc(message.id), {
          uid: args.uid, messageId: message.id, rewards: message.rewards, claimedAtMs: null,
        });
      }
    }
    args.tx.set(summaryRef, { uid: args.uid, ...updatedSummary });
  };
}

/** Privileged server/operator entry point; deliberately not a player callable. */
export async function issueSystemMessage(args: {
  db: Firestore; uid: string; delivery: SystemMessageDelivery; nowMs?: number;
}): Promise<string> {
  const nowMs = args.nowMs ?? Date.now();
  await args.db.runTransaction(async (tx) => {
    await assertAccountActiveInTransaction(tx, args.db, args.uid);
    // Targeted operator deliveries must not invent an account for a mistyped UID.
    const profile = await tx.get(args.db.collection("player_profiles").doc(args.uid));
    if (!profile.exists) throw new HttpsError("not-found", "Player account not found.");
    const write = await prepareSystemMessages({ ...args, tx, deliveries: [args.delivery], nowMs });
    write();
  });
  return systemMessageId(args.uid, args.delivery.sourceId.trim());
}

export async function loadInboxSummary(db: Firestore, uid: string): Promise<InboxSummary> {
  return db.runTransaction(async (tx) => {
    await assertAccountActiveInTransaction(tx, db, uid);
    return readInboxSummary((await tx.get(db.collection(inboxCollections.summaries).doc(uid))).data());
  });
}

/** A stable timestamp/id cursor includes ties and never exposes another player's mail. */
export async function listInbox(db: Firestore, uid: string, cursor?: InboxCursor) {
  return db.runTransaction(async (tx) => {
    await assertAccountActiveInTransaction(tx, db, uid);
    const summary = readInboxSummary((await tx.get(db.collection(inboxCollections.summaries).doc(uid))).data());
    let query = db.collection(inboxCollections.messages).where("uid", "==", uid)
      .orderBy("createdAtMs", "desc").orderBy(FieldPath.documentId(), "desc");
    if (cursor) query = query.startAfter(cursor.createdAtMs, cursor.messageId);
    const docs = (await tx.get(query.limit(pageSize + 1))).docs;
    const messages = docs.slice(0, pageSize).map((doc) => decodeSystemMessage(doc.data(), doc.id, uid));
    const last = messages.at(-1);
    return {
      messages,
      summary,
      nextCursor: docs.length > pageSize && last
        ? { createdAtMs: last.createdAtMs, messageId: last.id } : null,
    };
  });
}

export async function markInboxMessageRead(db: Firestore, uid: string, messageId: string, nowMs = Date.now()) {
  return db.runTransaction(async (tx) => {
    await assertAccountActiveInTransaction(tx, db, uid);
    const ref = db.collection(inboxCollections.messages).doc(messageId);
    const message = decodeSystemMessage((await tx.get(ref)).data(), messageId, uid);
    const summaryRef = db.collection(inboxCollections.summaries).doc(uid);
    let summary = readInboxSummary((await tx.get(summaryRef)).data());
    if (message.readAtMs === null) {
      message.readAtMs = nowMs;
      summary = nextSummary(summary, -1, 0);
      tx.update(ref, { readAtMs: nowMs, expiresAtMs: inboxMessageExpiry(message) });
      tx.set(summaryRef, { uid, ...summary });
    }
    return { message, summary };
  });
}

/** Credits a persisted attachment once and preserves ownership revision/idempotency rules. */
export async function claimInboxReward(args: {
  db: Firestore;
  uid: string;
  messageId: string;
  commandId: string;
  expectedRevision: number;
  nowMs?: number;
}) {
  const nowMs = args.nowMs ?? Date.now();
  const payloadHash = createHash("sha256").update(JSON.stringify([
    "claimInboxReward", args.uid, args.messageId, args.expectedRevision,
  ])).digest("hex");
  return args.db.runTransaction(async (tx) => {
    await assertAccountActiveInTransaction(tx, args.db, args.uid);
    const resolved = await resolveCanonicalStateForTransaction({ ...args, tx });
    const canonical = resolved.canonical;
    const idempotencyRef = resolved.canonicalRef.collection("idempotency").doc(args.commandId);
    const previous = (await tx.get(idempotencyRef)).data();
    const messageRef = args.db.collection(inboxCollections.messages).doc(args.messageId);
    const message = decodeSystemMessage((await tx.get(messageRef)).data(), args.messageId, args.uid);
    const rewardRef = args.db.collection(inboxCollections.rewards).doc(args.messageId);
    const reward = (await tx.get(rewardRef)).data();
    const summaryRef = args.db.collection(inboxCollections.summaries).doc(args.uid);
    let summary = readInboxSummary((await tx.get(summaryRef)).data());
    let rejectedReason: OwnershipCommandResult["rejectedReason"] = null;
    if (previous && previous.payloadHash !== payloadHash) rejectedReason = "idempotencyKeyReuseMismatch";
    else if (previous) rejectedReason = previous.outcome?.rejectedReason ?? null;
    else if (!reward || reward.uid !== args.uid || message.rewards.length === 0 ||
        !isDeepStrictEqual(reward.rewards, message.rewards) || reward.claimedAtMs !== message.claimedAtMs) {
      throw new HttpsError("failed-precondition", "Reward record does not match this message.");
    } else if (message.claimedAtMs === null) {
      if (canonical.revision !== args.expectedRevision) rejectedReason = "staleRevision";
      else {
        for (const attachment of message.rewards) {
          if (attachment.kind === "gold") {
            const gold = safeInteger(canonical.progression.gold, "gold balance");
            canonical.progression.gold = safeInteger(gold + attachment.amount, "gold balance");
          } else {
            grantCatalogOwnership({ meta: canonical.meta,
              selectedCharacterId: attachment.characterId ?? "",
              offer: catalogDefinition(attachment) });
          }
        }
        // Refresh offers against the new ownership without charging or changing the loadout.
        normalizeProgressionStore({ progression: canonical.progression, meta: canonical.meta,
          selection: canonical.selection, userId: args.uid, nowMs });
        canonical.revision = safeInteger(canonical.revision + 1, "ownership revision");
        message.claimedAtMs = nowMs;
        summary = nextSummary(summary, 0, -1);
        tx.update(messageRef, { claimedAtMs: nowMs, expiresAtMs: inboxMessageExpiry(message) });
        tx.update(rewardRef, { claimedAtMs: nowMs, appliedRevision: canonical.revision });
        tx.set(summaryRef, { uid: args.uid, ...summary });
        tx.set(resolved.canonicalRef, resolved.exists
          ? canonicalMergeWriteData(args.uid, canonical) : canonicalWriteData(args.uid, canonical), { merge: true });
      }
    }
    const result: OwnershipCommandResult = {
      canonicalState: canonical,
      newRevision: canonical.revision,
      replayedFromIdempotency: previous !== undefined,
      rejectedReason,
    };
    if (!previous) tx.set(idempotencyRef, idempotencyWriteData({ payloadHash, result, nowMs }));
    return { message, summary, result };
  });
}

/** Removes visible content atomically with its counters and permanent retry receipt.
 * Unclaimed gifts cannot be removed. onlyExpired rechecks eligibility inside the
 * transaction for scheduled cleanup; manual retries return the existing receipt.
 */
export async function deleteInboxMessage(args: {
  db: Firestore; uid: string; messageId: string; nowMs?: number; onlyExpired?: boolean;
}) {
  const nowMs = safeInteger(args.nowMs ?? Date.now(), "nowMs");
  return args.db.runTransaction(async (tx) => {
    await assertAccountActiveInTransaction(tx, args.db, args.uid);
    const messageRef = args.db.collection(inboxCollections.messages).doc(args.messageId);
    const receiptRef = args.db.collection(inboxCollections.receipts).doc(args.messageId);
    const summaryRef = args.db.collection(inboxCollections.summaries).doc(args.uid);
    const rewardRef = args.db.collection(inboxCollections.rewards).doc(args.messageId);
    const [messageDoc, receiptDoc, summaryDoc, rewardDoc] = await tx.getAll(messageRef, receiptRef, summaryRef, rewardRef);
    let summary = readInboxSummary(summaryDoc.data());
    const result = (deleted: boolean) => ({ messageId: args.messageId, deleted, summary });
    if (!messageDoc.exists) {
      if (receiptDoc.exists) {
        readRemovalReceipt(receiptDoc.data()!, args.messageId, args.uid);
        return result(!args.onlyExpired);
      }
      if (args.onlyExpired) return result(false);
      throw new HttpsError("not-found", "Message not found.");
    }
    const message = decodeSystemMessage(messageDoc.data(), args.messageId, args.uid);
    const expiresAtMs = inboxMessageExpiry(message);
    if (args.onlyExpired && (expiresAtMs === null || expiresAtMs > nowMs)) return result(false);
    if (message.rewards.length > 0 && message.claimedAtMs === null) {
      throw new HttpsError("failed-precondition", "Claim your gifts before deleting this message.");
    }
    if (receiptDoc.exists) throw new HttpsError("failed-precondition", "Message already has a removal receipt.");
    const reward = rewardDoc.data();
    if (message.rewards.length > 0 && (!reward || reward.uid !== args.uid || reward.messageId !== message.id ||
        !isDeepStrictEqual(reward.rewards, message.rewards) || reward.claimedAtMs !== message.claimedAtMs)) {
      throw new HttpsError("failed-precondition", "Reward record does not match this message.");
    }
    summary = nextSummary(summary, message.readAtMs === null ? -1 : 0, 0);
    tx.create(receiptRef, {
      schemaVersion: 1, uid: args.uid, messageId: message.id,
      sourceId: message.sourceId, contentHash: contentHash(message),
      createdAtMs: message.createdAtMs, deletedAtMs: nowMs,
      claimedAtMs: message.claimedAtMs,
      goldAmount: message.rewards.find((reward) => reward.kind === "gold")?.amount ?? 0,
      ...(message.schemaVersion === 2 ? { rewards: message.rewards } : {}),
      appliedRevision: reward ? safeInteger(reward.appliedRevision, "appliedRevision") : null,
    });
    tx.delete(messageRef);
    if (rewardDoc.exists) tx.delete(rewardRef);
    tx.set(summaryRef, { uid: args.uid, ...summary });
    return result(true);
  });
}
