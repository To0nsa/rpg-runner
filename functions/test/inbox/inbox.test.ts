import assert from "node:assert/strict";
import { after, beforeEach, test } from "node:test";
import { deleteApp, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { loadOrCreateCanonicalState } from "../../src/ownership/canonical_store.js";
import { handleInboxRequest } from "../../src/inbox/callable_handlers.js";
import { inboxCollections } from "../../src/inbox/contracts.js";
import { sendOperatorMessage } from "../../src/inbox/operator.js";
import { issueSystemMessage, claimInboxReward, markInboxMessageRead, listInbox, loadInboxSummary } from "../../src/inbox/store.js";

if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error("Use the Firestore emulator.");
const app = initializeApp({ projectId: "demo-rpg-runner-inbox-tests" }, `inbox-${process.pid}`);
const db = getFirestore(app);
const uid = "inbox-player";
const nowMs = 1700000000000;

beforeEach(async () => {
  for (const name of [...Object.values(inboxCollections), "ownership_profiles", "player_profiles", "account_deletion_requests", "abuse_quota"]) {
    for (const doc of (await db.collection(name).get()).docs) await db.recursiveDelete(doc.ref);
  }
  await db.collection("player_profiles").doc(uid).set({ uid });
});
after(async () => { await deleteApp(app); });

async function deliver(sourceId = "test-gift", goldAmount = 25) {
  return issueSystemMessage({ db, uid, nowMs, delivery: { sourceId, goldAmount, title: "A gift", body: "Your gold is ready." } });
}

test("operator adapter delivers once, preserves claim flow and fences invalid recipients", async () => {
  const input = { uid, sourceId: "operator-retry", title: "Gift", body: "Thank you.", goldAmount: 40 };
  const projectId = "demo-rpg-runner-inbox-tests";
  const messageId = await sendOperatorMessage(projectId, input);
  assert.equal(await sendOperatorMessage(projectId, input), messageId);
  const inbox = await listInbox(db, uid);
  assert.equal(inbox.messages.length, 1);
  assert.equal(inbox.messages[0].sourceId, "operator:operator-retry");
  assert.equal((await loadOrCreateCanonicalState({ db, uid })).progression.gold, 0);
  const claimed = await claimInboxReward({ db, uid, messageId, commandId: "operator-claim", expectedRevision: 0 });
  assert.equal(claimed.result.canonicalState.progression.gold, 40);
  await sendOperatorMessage(projectId, input);
  assert.equal((await loadInboxSummary(db, uid)).unclaimedCount, 0);
  await assert.rejects(sendOperatorMessage(projectId, { ...input, goldAmount: 41 }), { code: "already-exists" });
  await assert.rejects(sendOperatorMessage(projectId, { ...input, uid: "missing-player" }), { code: "not-found" });
  await db.collection("account_deletion_requests").doc(uid).set({ uid, state: "requested" });
  await assert.rejects(sendOperatorMessage(projectId, { ...input, sourceId: "deleted" }), { code: "failed-precondition" });
});

test("delivery retries preserve contents and whole-inbox attention", async () => {
  const ids = await Promise.all([deliver(), deliver()]);
  assert.equal(ids[0], ids[1]);
  assert.deepEqual(await loadInboxSummary(db, uid), { revision: 1, unreadCount: 1, unclaimedCount: 1 });
  assert.equal((await loadOrCreateCanonicalState({ db, uid })).progression.gold, 0);
  await assert.rejects(deliver("test-gift", 50), { code: "already-exists" });
  const first = await markInboxMessageRead(db, uid, ids[0], nowMs + 1);
  const second = await markInboxMessageRead(db, uid, ids[0], nowMs + 2);
  assert.deepEqual(first, second);
  assert.equal(second.summary.unreadCount, 0);
  assert.equal(second.summary.unclaimedCount, 1);
});

test("concurrent claims and retries credit once even with different command ids", async () => {
  const messageId = await deliver();
  const base = { db, uid, messageId, expectedRevision: 0, nowMs };
  const claims = await Promise.all([
    claimInboxReward({ ...base, commandId: "claim-a" }),
    claimInboxReward({ ...base, commandId: "claim-b" }),
  ]);
  for (const claim of claims) assert.equal(claim.result.rejectedReason, null);
  const retried = await claimInboxReward({ ...base, commandId: "claim-a" });
  assert.equal(retried.result.replayedFromIdempotency, true);
  assert.equal(retried.result.canonicalState.progression.gold, 25);
  assert.equal(retried.result.canonicalState.revision, 1);
  assert.equal(retried.summary.unclaimedCount, 0);
  assert.equal(retried.summary.unreadCount, 1);
});

test("stale ownership revision and reused command identity do not grant gold", async () => {
  const messageId = await deliver();
  const stale = await claimInboxReward({ db, uid, messageId, commandId: "stale", expectedRevision: 5 });
  assert.equal(stale.result.rejectedReason, "staleRevision");
  assert.equal(stale.message.claimedAtMs, null);
  const mismatch = await claimInboxReward({ db, uid, messageId, commandId: "stale", expectedRevision: 0 });
  assert.equal(mismatch.result.rejectedReason, "idempotencyKeyReuseMismatch");
  const good = await claimInboxReward({ db, uid, messageId, commandId: "fresh", expectedRevision: 0 });
  assert.equal(good.result.canonicalState.progression.gold, 25);
});

test("gold overflow and unsupported rewards leave all claim state unchanged", async () => {
  const messageId = await deliver();
  const canonical = await loadOrCreateCanonicalState({ db, uid });
  await db.collection("ownership_profiles").doc(`${uid}__${canonical.profileId}`).update({ "progression.gold": Number.MAX_SAFE_INTEGER });
  await assert.rejects(claimInboxReward({ db, uid, messageId, commandId: "overflow", expectedRevision: 0 }));
  assert.equal((await listInbox(db, uid)).messages[0].claimedAtMs, null);
  assert.equal((await loadInboxSummary(db, uid)).unclaimedCount, 1);
  await db.collection(inboxCollections.messages).doc(messageId).update({ rewards: [{ kind: "item", amount: 1 }] });
  await assert.rejects(claimInboxReward({ db, uid, messageId, commandId: "unsupported", expectedRevision: 0 }), { code: "failed-precondition" });
});

test("pagination handles equal timestamps and summary includes older unclaimed gifts", async () => {
  const giftId = await deliver("old-gift");
  await markInboxMessageRead(db, uid, giftId);
  for (let index = 0; index < 21; index += 1) {
    const id = await issueSystemMessage({ db, uid, nowMs: nowMs + 1,
      delivery: { sourceId: `info-${index}`, title: "News", body: "Game information." } });
    await markInboxMessageRead(db, uid, id);
  }
  const first = await listInbox(db, uid);
  assert.equal(first.messages.length, 20);
  assert.equal(first.summary.unreadCount, 0);
  assert.equal(first.summary.unclaimedCount, 1);
  const second = await listInbox(db, uid, first.nextCursor!);
  assert.equal(second.messages.length, 2);
  assert.equal(second.nextCursor, null);
  assert.equal(new Set([...first.messages, ...second.messages].map((m) => m.id)).size, 22);
});

test("information-only mail cannot be claimed", async () => {
  const id = await deliver("info", 0);
  await assert.rejects(claimInboxReward({ db, uid, messageId: id, commandId: "info-claim", expectedRevision: 0 }), { code: "failed-precondition" });
  const read = await markInboxMessageRead(db, uid, id);
  assert.equal(read.summary.unreadCount + read.summary.unclaimedCount, 0);
});

test("callables reject unauthenticated callers, identity spoofing and client reward fields", async () => {
  await assert.rejects(handleInboxRequest({ data: { userId: uid } }, db, "list"), { code: "unauthenticated" });
  await assert.rejects(handleInboxRequest({ auth: { uid: "other" }, data: { userId: uid } }, db, "list"), { code: "permission-denied" });
  await assert.rejects(handleInboxRequest({ auth: { uid }, data: { userId: uid, goldAmount: 100 } }, db, "list"), { code: "invalid-argument" });
  const id = await deliver();
  await assert.rejects(markInboxMessageRead(db, "other", id), { code: "not-found" });
  await assert.rejects(claimInboxReward({ db, uid: "other", messageId: id, commandId: "steal", expectedRevision: 0 }), { code: "not-found" });
});

test("deletion fences reads, claims and delivery", async () => {
  const id = await deliver();
  await db.collection("account_deletion_requests").doc(uid).set({ uid, state: "requested" });
  await assert.rejects(listInbox(db, uid));
  await assert.rejects(markInboxMessageRead(db, uid, id));
  await assert.rejects(claimInboxReward({ db, uid, messageId: id, commandId: "deleted", expectedRevision: 0 }));
  await assert.rejects(deliver("late"));
});
