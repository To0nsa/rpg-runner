import assert from "node:assert/strict";
import { after, beforeEach, test } from "node:test";
import { deleteApp, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import type { TaskOptions } from "firebase-admin/functions";
import { enqueuePendingWork, parsePendingWork, processPendingWork,
  type PendingWork } from "../src/pending_work.js";
import { processPendingAccountDeletions, requestAccountDeletion } from "../src/account/delete.js";

if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error("Firestore emulator required.");
const app = initializeApp({ projectId: "demo-pending-work" }, `pending-${process.pid}`);
const db = getFirestore(app);
const nowMs = 1_700_000_000_000;
const calls: string[] = [];
const dependencies = {
  auth: { async disableAndRevoke() { calls.push("disable"); }, async deleteUser() { calls.push("delete"); } },
  replayArtifactStore: { async deletePageByPrefix() { return 0; }, async deleteObjectIfExists() { return false; } },
};
beforeEach(async () => {
  for (const collection of await db.listCollections()) await db.recursiveDelete(collection);
  calls.length = 0;
});
after(() => deleteApp(app));

test("enqueue names deduplicate events, separate recovery generations, and retain retries on outage", async () => {
  const requests: {data: PendingWork; options: TaskOptions}[] = [];
  const queue = { async enqueue(data: PendingWork, options: TaskOptions) { requests.push({ data, options }); } };
  const work: PendingWork = { kind: "run", runSessionId: "run_1" };
  await enqueuePendingWork({ work, generation: "initial", delaySeconds: 900, queue });
  await enqueuePendingWork({ work, generation: "initial", delaySeconds: 900, queue });
  await enqueuePendingWork({ work, generation: "repair-1", queue });
  assert.equal(requests[0].options.id, requests[1].options.id);
  assert.notEqual(requests[0].options.id, requests[2].options.id);
  assert.equal(requests[0].options.scheduleDelaySeconds, 900);
  const duplicate = { async enqueue() { throw { code: "functions/task-already-exists" }; } };
  await enqueuePendingWork({ work, generation: "initial", queue: duplicate });
  const outage = { async enqueue() { throw new Error("unavailable"); } };
  await assert.rejects(enqueuePendingWork({ work, generation: "initial", queue: outage }), /unavailable/);
  for (const invalid of [null, {}, { kind: "run", runSessionId: "a/b" }, { kind: "account", uid: "" }]) {
    assert.throws(() => parsePendingWork(invalid));
  }
});

test("lost validation delivery recovers exact evidence, fences duplicates, and finishes after settlement", async () => {
  const work: PendingWork = { kind: "run", runSessionId: "run_recover" };
  const ref = db.doc("run_sessions/run_recover");
  const evidence = { storageGeneration: "42", canonicalSha256: "a".repeat(64), objectPath: "pending/replay" };
  await ref.set({ uid: "owner", state: "uploaded", updatedAtMs: nowMs - 900001, uploadedReplay: evidence });
  const tasks: unknown[] = [];
  const validationDispatcher = { async enqueueRunValidationTask(data: unknown) { tasks.push(data); } };
  const args = { db, work, nowMs, validationDispatcher };
  assert.equal(await processPendingWork(args), "pending");
  assert.equal(await processPendingWork(args), "pending");
  assert.equal(tasks.length, 1);
  assert.deepEqual((await ref.get()).get("uploadedReplay"), evidence);
  await ref.update({ state: "validated" });
  assert.equal(await processPendingWork(args), "complete");
});

test("live leases are preserved; expired leases retry enqueue and deletion fences work", async () => {
  const ref = db.doc("run_sessions/run_lease");
  const work: PendingWork = { kind: "run", runSessionId: "run_lease" };
  await ref.set({ uid: "owner", state: "validating", validationLeaseToken: "token",
    validationLeaseExpiresAtMs: nowMs + 1 });
  let enqueues = 0;
  const validationDispatcher = { async enqueueRunValidationTask() { enqueues++; throw new Error("queue down"); } };
  assert.equal(await processPendingWork({ db, work, nowMs, validationDispatcher }), "pending");
  assert.equal(enqueues, 0);
  assert.equal((await ref.get()).get("validationLeaseToken"), "token");
  assert.equal(await processPendingWork({ db, work, nowMs: nowMs + 2, validationDispatcher }), "pending");
  assert.equal(enqueues, 1);
  assert.equal((await ref.get()).get("validationLeaseToken"), undefined);
  assert.equal((await ref.get()).get("validationNextAttemptAtMs"), nowMs + 2);
  await db.doc("account_deletion_requests/owner").set({ state: "requested" });
  assert.equal(await processPendingWork({ db, work, nowMs: nowMs + 3, validationDispatcher }), "complete");
  assert.equal(enqueues, 1);
});

test("missed settlement event is recovered once, including the atomic receipt", async () => {
  const runSessionId = "run_settle";
  const work: PendingWork = { kind: "run", runSessionId };
  await db.doc(`run_sessions/${runSessionId}`).set({ runSessionId, uid: "owner",
    mode: "practice", state: "settlement_pending", settlementPendingAtMs: nowMs - 1000,
    settlementRepairDisposition: "retryable" });
  await db.doc(`validated_runs/${runSessionId}`).set({ runSessionId, uid: "owner",
    mode: "practice", accepted: true, goldEarned: 23 });
  await db.doc(`reward_grants/${runSessionId}`).set({ runSessionId, uid: "owner",
    mode: "practice", lifecycleState: "settlement_pending", goldAmount: 23,
    createdAtMs: nowMs - 1000, updatedAtMs: nowMs - 1000 });
  assert.equal(await processPendingWork({ db, work, nowMs }), "complete");
  assert.equal(await processPendingWork({ db, work, nowMs }), "complete");
  const receipt = await db.doc(`run_completion_receipts/owner/runs/${runSessionId}`).get();
  assert.equal(receipt.get("canonicalState.progression.gold"), 23);
  assert.equal(receipt.get("canonicalState.revision"), 1);
});

test("invariant incidents stop retries and stay quarantined without wallet writes", async () => {
  const runSessionId = "run_poison";
  const work: PendingWork = { kind: "run", runSessionId };
  await db.doc(`run_sessions/${runSessionId}`).set({ uid: "owner", state: "settlement_pending",
    settlementRepairDisposition: "retryable" });
  assert.equal(await processPendingWork({ db, work, nowMs }), "quarantined");
  assert.equal(await processPendingWork({ db, work, nowMs }), "quarantined");
  assert.equal((await db.doc(`run_sessions/${runSessionId}`).get()).get("settlementRepairDisposition"), "quarantined");
  assert.equal((await db.doc("ownership_profiles/owner").get()).exists, false);
});

test("account tasks resume checkpoints through the upload quiet period and acknowledge completion", async () => {
  await requestAccountDeletion({ db, uid: "owner", nowMs, dependencies });
  const work: PendingWork = { kind: "account", uid: "owner" };
  assert.equal(await processPendingWork({ db, work, nowMs, deletionDependencies: dependencies }), "pending");
  assert.equal((await db.doc("account_deletion_requests/owner").get()).get("stage"), "quiet_wait");
  assert.equal(calls.includes("delete"), false);
  let result = "pending";
  for (let attempt = 0; attempt < 5 && result === "pending"; attempt++) {
    result = await processPendingWork({ db, work, nowMs: nowMs + 900001, deletionDependencies: dependencies });
  }
  assert.equal(result, "complete");
  assert.equal(await processPendingWork({ db, work, nowMs }), "complete");
  assert.equal(calls.filter((call) => call === "delete").length, 1);
});

test("hourly deletion safety scan restores missed task delivery; leased work stays pending", async () => {
  await requestAccountDeletion({ db, uid: "owner", nowMs, dependencies });
  await db.doc("account_deletion_requests/owner").update({ leaseToken: "other", leaseExpiresAtMs: nowMs + 10000 });
  const restored: string[] = [];
  await processPendingAccountDeletions({ db, nowMs, dependencies,
    onPending: async (uid) => { restored.push(uid); } });
  assert.deepEqual(restored, ["owner"]);
  assert.equal(await processPendingWork({ db, work: { kind: "account", uid: "owner" },
    nowMs, deletionDependencies: dependencies }), "pending");
  assert.equal(calls.includes("delete"), false);
});

test("deletion safety scan still advances erasure when the task queue is unavailable", async () => {
  await requestAccountDeletion({ db, uid: "owner", nowMs, dependencies });
  const result = await processPendingAccountDeletions({ db, nowMs, dependencies,
    onPending: async () => { throw new Error("queue down"); } });
  assert.equal(result.continuationFailureCount, 1);
  assert.ok(result.processedStepCount > 0);
  assert.equal((await db.doc("account_deletion_requests/owner").get()).get("stage"), "quiet_wait");
});
