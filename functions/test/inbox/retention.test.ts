import assert from "node:assert/strict";
import { after, beforeEach, test } from "node:test";
import { deleteApp, initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { handleInboxRequest } from "../../src/inbox/callable_handlers.js";
import { inboxCollections } from "../../src/inbox/contracts.js";
import { maintainInboxRetention } from "../../src/inbox/retention.js";
import { inboxRetentionMs } from "../../src/inbox/retention_policy.js";
import { claimInboxReward, deleteInboxMessage, issueSystemMessage, listInbox, loadInboxSummary, markInboxMessageRead } from "../../src/inbox/store.js";
import { loadOrCreateCanonicalState } from "../../src/ownership/canonical_store.js";

if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error("Use the Firestore emulator.");
const app = initializeApp({ projectId: "demo-rpg-runner-inbox-retention" }, `retention-${process.pid}`);
const db = getFirestore(app);
const uid = "retention-player";
const nowMs = 1700000000000;
beforeEach(async () => {
  for (const name of [...Object.values(inboxCollections), "ownership_profiles", "player_profiles", "account_deletion_requests", "abuse_quota", "maintenance_state"]) {
    for (const doc of (await db.collection(name).get()).docs) await db.recursiveDelete(doc.ref);
  }
  await db.collection("player_profiles").doc(uid).set({ uid });
});
after(async () => { await deleteApp(app); });
const deliver = (sourceId: string, goldAmount = 0) => issueSystemMessage({ db, uid, nowMs,
  delivery: { sourceId, goldAmount, title: "A message", body: "Private message content" } });
const remove = (messageId: string) => deleteInboxMessage({ db, uid, messageId, nowMs: nowMs + 20 });
const messageRef = (id: string) => db.collection(inboxCollections.messages).doc(id);

test("manual deletion protects gold; claimed deletion retains compact replay evidence", async () => {
  const id = await deliver("gift", 25);
  await assert.rejects(remove(id), { code: "failed-precondition" });
  assert.equal((await loadInboxSummary(db, uid)).unclaimedCount, 1);
  await claimInboxReward({ db, uid, messageId: id, commandId: "claim", expectedRevision: 0, nowMs: nowMs + 1 });
  const [first, retry] = await Promise.all([remove(id), remove(id)]);
  assert.deepEqual(first, retry);
  assert.deepEqual(first.summary, { revision: 3, unreadCount: 0, unclaimedCount: 0 });
  assert.equal((await messageRef(id).get()).exists, false);
  assert.equal((await db.collection(inboxCollections.rewards).doc(id).get()).exists, false);
  const receipt = (await db.collection(inboxCollections.receipts).doc(id).get()).data()!;
  assert.equal(receipt.goldAmount, 25);
  assert.equal(receipt.claimedAtMs, nowMs + 1);
  assert.equal(receipt.appliedRevision, 1);
  assert.equal(receipt.title, undefined);
  assert.equal(receipt.body, undefined);
  assert.equal(JSON.stringify(receipt).includes("Private message content"), false);
  assert.equal(await deliver("gift", 25), id);
  await assert.rejects(deliver("gift", 26), { code: "already-exists" });
  await assert.rejects(claimInboxReward({ db, uid, messageId: id, commandId: "claim-again", expectedRevision: 1 }), { code: "not-found" });
  assert.equal((await loadOrCreateCanonicalState({ db, uid })).progression.gold, 25);
  assert.equal((await listInbox(db, uid)).messages.length, 0);
  assert.equal((await loadInboxSummary(db, uid)).revision, 3);
});

test("unread information deletes once; ownership and callable boundaries remain enforced", async () => {
  const id = await deliver("info");
  const data = { userId: uid, messageId: id };
  await assert.rejects(handleInboxRequest({ data }, db, "delete"), { code: "unauthenticated" });
  await assert.rejects(handleInboxRequest({ auth: { uid: "other" }, data }, db, "delete"), { code: "permission-denied" });
  await assert.rejects(handleInboxRequest({ auth: { uid }, data: { ...data, force: true } }, db, "delete"), { code: "invalid-argument" });
  await assert.rejects(deleteInboxMessage({ db, uid: "other", messageId: id }), { code: "not-found" });
  const response = await handleInboxRequest({ auth: { uid }, data }, db, "delete");
  assert.equal((response as { deleted: boolean }).deleted, true);
  assert.deepEqual(await remove(id), { messageId: id, deleted: true, summary: { revision: 2, unreadCount: 0, unclaimedCount: 0 } });
  await assert.rejects(deleteInboxMessage({ db, uid: "other", messageId: id }), { code: "not-found" });
  await assert.rejects(remove("unknown"), { code: "not-found" });
  await deliver("info");
  assert.equal((await listInbox(db, uid)).messages.length, 0);
  await assert.rejects(issueSystemMessage({ db, uid, delivery: { sourceId: "info", title: "Edited", body: "Private message content" } }), { code: "already-exists" });
});

test("expiry starts at first read or successful claim, with exact 30-day boundaries", async () => {
  const info = await deliver("read-info");
  const gift = await deliver("claimed-gift", 25);
  const unread = await deliver("unread-info");
  const pending = await deliver("pending-gift", 25);
  const start = nowMs + 100;
  await markInboxMessageRead(db, uid, info, start);
  await markInboxMessageRead(db, uid, info, start + 1000);
  await markInboxMessageRead(db, uid, pending, start);
  await claimInboxReward({ db, uid, messageId: gift, commandId: "claim", expectedRevision: 0, nowMs: start });
  await claimInboxReward({ db, uid, messageId: gift, commandId: "repeat", expectedRevision: 1, nowMs: start + 1000 });
  assert.equal((await messageRef(info).get()).data()!.expiresAtMs, start + inboxRetentionMs);
  assert.equal((await messageRef(gift).get()).data()!.expiresAtMs, start + inboxRetentionMs);
  assert.equal((await maintainInboxRetention({ db, nowMs: start + inboxRetentionMs - 1 })).deleted, 0);
  assert.equal((await maintainInboxRetention({ db, nowMs: start + inboxRetentionMs })).deleted, 2);
  assert.deepEqual(new Set((await listInbox(db, uid)).messages.map((m) => m.id)), new Set([unread, pending]));
  const summary = await loadInboxSummary(db, uid);
  assert.equal(summary.unreadCount, 1);
  assert.equal(summary.unclaimedCount, 1);
  assert.equal((await maintainInboxRetention({ db, nowMs: start + 10 * inboxRetentionMs })).deleted, 0);
});

test("legacy timestamps are repaired and forged expiry cannot remove an unclaimed gift", async () => {
  const info = await deliver("legacy-info");
  const gift = await deliver("legacy-gift", 25);
  await markInboxMessageRead(db, uid, info, nowMs);
  await messageRef(info).update({ expiresAtMs: FieldValue.delete() });
  await messageRef(gift).update({ expiresAtMs: nowMs - 1 });
  const result = await maintainInboxRetention({ db, nowMs: nowMs + inboxRetentionMs });
  assert.equal(result.deleted, 1);
  assert.equal(result.repaired, 2);
  assert.equal((await messageRef(gift).get()).data()!.expiresAtMs, null);
  assert.equal((await loadInboxSummary(db, uid)).unclaimedCount, 1);
  await deliver("legacy-info");
  assert.equal((await messageRef(info).get()).exists, false);
});

test("an overflowing expiry aborts the read without changing message or counters", async () => {
  const id = await deliver("clock-overflow");
  await assert.rejects(markInboxMessageRead(db, uid, id, Number.MAX_SAFE_INTEGER), /Invalid inbox expiry time/);
  assert.equal((await messageRef(id).get()).data()!.readAtMs, null);
  assert.equal((await messageRef(id).get()).data()!.expiresAtMs, null);
  assert.deepEqual(await loadInboxSummary(db, uid), { revision: 1, unreadCount: 1, unclaimedCount: 0 });
  await markInboxMessageRead(db, uid, id, nowMs);
  assert.equal((await messageRef(id).get()).data()!.expiresAtMs, nowMs + inboxRetentionMs);
});

test("bounded sweep reaches later legacy messages across overlaps and deleted cursors", async () => {
  const ids = [];
  for (let i = 0; i < 7; i++) {
    const id = await deliver(`legacy-${i}`);
    ids.push(id);
    await markInboxMessageRead(db, uid, id, nowMs);
    await messageRef(id).update({ expiresAtMs: FieldValue.delete() });
  }
  const args = { db, nowMs: nowMs + inboxRetentionMs, batchSize: 2 };
  const overlap = await Promise.all([maintainInboxRetention(args), maintainInboxRetention(args)]);
  for (const result of overlap) assert.ok(result.repairScanned <= 2 && result.expiredScanned <= 2);
  for (let i = 0; i < 5; i++) await maintainInboxRetention(args);
  assert.equal((await listInbox(db, uid)).messages.length, 0);
  assert.equal((await db.collection(inboxCollections.receipts).get()).size, ids.length);
  assert.equal((await loadInboxSummary(db, uid)).revision, 21);
  const checkpoint = (await db.doc("maintenance_state/inbox_retention_v1").get()).data()!;
  assert.equal(checkpoint.cursor, null);
  await assert.rejects(maintainInboxRetention({ db, batchSize: 0 }));
});

test("cleanup and manual deletion serialize; account erasure fences receipt creation", async () => {
  const id = await deliver("race");
  await markInboxMessageRead(db, uid, id, nowMs);
  await Promise.all([remove(id), maintainInboxRetention({ db, nowMs: nowMs + inboxRetentionMs })]);
  assert.equal((await loadInboxSummary(db, uid)).revision, 3);
  assert.equal((await db.collection(inboxCollections.receipts).get()).size, 1);
  const protectedId = await deliver("erasing");
  await markInboxMessageRead(db, uid, protectedId, nowMs);
  await db.collection("account_deletion_requests").doc(uid).set({ uid });
  await assert.rejects(remove(protectedId), { code: "failed-precondition" });
  const cleanup = await maintainInboxRetention({ db, nowMs: nowMs + inboxRetentionMs });
  assert.ok(cleanup.accountDeletionSkipped > 0);
  assert.equal((await db.collection(inboxCollections.receipts).doc(protectedId).get()).exists, false);
});

test("concurrent claim and delete cannot lose or double the gold", async () => {
  const id = await deliver("claim-delete", 25);
  const results = await Promise.allSettled([
    claimInboxReward({ db, uid, messageId: id, commandId: "claim", expectedRevision: 0, nowMs }), remove(id),
  ]);
  assert.equal(results[0].status, "fulfilled");
  if (results[1].status === "rejected") assert.equal(results[1].reason.code, "failed-precondition");
  await remove(id);
  await deliver("claim-delete", 25);
  assert.equal((await loadOrCreateCanonicalState({ db, uid })).progression.gold, 25);
  assert.deepEqual(await loadInboxSummary(db, uid), { revision: 3, unreadCount: 0, unclaimedCount: 0 });
});
