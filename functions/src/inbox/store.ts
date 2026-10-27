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

const pageSize = 20;
export const emptyInboxSummary: InboxSummary = { revision: 0, unreadCount: 0, unclaimedCount: 0 };

/** Delivery identity survives text edits, policy changes and request retries. */
export function systemMessageId(uid: string, sourceId: string): string {
  return createHash("sha256").update(JSON.stringify([uid, sourceId])).digest("hex");
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
  if (raw.schemaVersion !== 1 || raw.id !== id || !Array.isArray(raw.rewards) || raw.rewards.length > 1) {
    throw new HttpsError("failed-precondition", "Unsupported message format.");
  }
  const rewards = raw.rewards.map((reward: unknown) => {
    if (reward === null || typeof reward !== "object" || !("kind" in reward) || reward.kind !== "gold" || !("amount" in reward)) {
      throw new HttpsError("failed-precondition", "Unsupported reward type.");
    }
    const amount = safeInteger(reward.amount, "gold reward");
    if (amount === 0) throw new HttpsError("failed-precondition", "Invalid gold reward.");
    return { kind: "gold" as const, amount };
  });
  return {
    schemaVersion: 1,
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
    return {
      schemaVersion: 1,
      id: systemMessageId(args.uid, sourceId),
      uid: args.uid,
      sourceId,
      title: boundedText(delivery.title, "title", 120),
      body: boundedText(delivery.body, "body", 2000),
      createdAtMs: safeInteger(args.nowMs, "nowMs"),
      readAtMs: null,
      claimedAtMs: null,
      rewards: amount > 0 ? [{ kind: "gold", amount }] : [],
    };
  });
  if (new Set(messages.map((message) => message.id)).size !== messages.length) {
    throw new HttpsError("invalid-argument", "Repeated source identity.");
  }
  const summaryRef = args.db.collection(inboxCollections.summaries).doc(args.uid);
  const summary = readInboxSummary((await args.tx.get(summaryRef)).data());
  const refs = messages.map((message) => args.db.collection(inboxCollections.messages).doc(message.id));
  const existing = await args.tx.getAll(...refs);
  const pending = messages.filter((message, index) => {
    if (!existing[index].exists) return true;
    const previous = decodeSystemMessage(existing[index].data(), message.id, args.uid);
    if (previous.sourceId !== message.sourceId || previous.title !== message.title ||
        previous.body !== message.body || !isDeepStrictEqual(previous.rewards, message.rewards)) {
      throw new HttpsError("already-exists", "Delivery identity was reused with different content.");
    }
    return false;
  });
  const updatedSummary = pending.length === 0 ? null : nextSummary(
    summary,
    pending.length,
    pending.filter((message) => message.rewards.length > 0).length,
  );
  return () => {
    if (updatedSummary === null) return;
    for (const message of pending) {
      args.tx.create(args.db.collection(inboxCollections.messages).doc(message.id), message);
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
      tx.update(ref, { readAtMs: nowMs });
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
        const gold = safeInteger(canonical.progression.gold, "gold balance");
        canonical.progression.gold = safeInteger(gold + message.rewards[0].amount, "gold balance");
        canonical.revision = safeInteger(canonical.revision + 1, "ownership revision");
        message.claimedAtMs = nowMs;
        summary = nextSummary(summary, 0, -1);
        tx.update(messageRef, { claimedAtMs: nowMs });
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
