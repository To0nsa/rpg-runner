import assert from "node:assert/strict";
import { after, beforeEach, test } from "node:test";

import { deleteApp, getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, type Firestore } from "firebase-admin/firestore";

import type { RunValidationTaskDispatcher } from "../../src/runs/submission_store.js";
import { repairStaleRunValidations } from "../../src/runs/validation_repair.js";

const firestoreEmulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
if (!firestoreEmulatorHost) {
  throw new Error(
    "FIRESTORE_EMULATOR_HOST is not set. Run via `firebase emulators:exec`.",
  );
}

const emulatorProjectIdBase =
  process.env.GCLOUD_PROJECT ?? "demo-rpg-runner-functions-tests";
const projectId = `${emulatorProjectIdBase}-validation-repair`;
const appName = `validation-repair-tests-${process.pid}-${Date.now()}`;
const app = initializeApp({ projectId }, appName);
const db = getFirestore(app);

beforeEach(async () => {
  await clearCollection(db, "run_sessions");
});

after(async () => {
  await Promise.all(getApps().map((value) => deleteApp(value)));
});

test("expired validation lease is fenced off and requeued once", async () => {
  const nowMs = 100_000;
  await db.collection("run_sessions").doc("run_expired").set({
    state: "validating",
    updatedAtMs: nowMs - 20_000,
    validationStartedAtMs: nowMs - 20_000,
    validationLeaseToken: "expired-token",
    validationLeaseExpiresAtMs: nowMs - 1,
    validationAttempt: 3,
  });
  const dispatcher = new FakeValidationDispatcher();

  const first = await repairStaleRunValidations({
    db,
    nowMs,
    dispatcher,
    options: {
      batchSize: 10,
      leaseDurationMs: 10_000,
      pendingStaleThresholdMs: 10_000,
      reenqueueCooldownMs: 5_000,
    },
  });

  assert.equal(first.reclaimedLeaseCount, 1);
  assert.equal(first.failureCount, 0);
  assert.deepEqual(dispatcher.requests, [
    {
      runSessionId: "run_expired",
      taskKey: "repair-1",
    },
  ]);
  const repaired = (
    await db.collection("run_sessions").doc("run_expired").get()
  ).data();
  assert.equal(repaired?.state, "pending_validation");
  assert.equal(repaired?.validationLeaseToken, undefined);
  assert.equal(repaired?.validationLeaseExpiresAtMs, undefined);
  assert.equal(repaired?.validationTaskGeneration, 1);
  assert.equal(repaired?.validationNextAttemptAtMs, nowMs + 5_000);

  const duplicate = await repairStaleRunValidations({
    db,
    nowMs,
    dispatcher,
    options: {
      batchSize: 10,
      leaseDurationMs: 10_000,
      pendingStaleThresholdMs: 10_000,
      reenqueueCooldownMs: 5_000,
    },
  });
  assert.equal(duplicate.reclaimedLeaseCount, 0);
  assert.equal(duplicate.requeuedPendingCount, 0);
  assert.equal(dispatcher.requests.length, 1);
});

test("legacy pending validation without retry timestamp is recovered", async () => {
  const nowMs = 200_000;
  await db.collection("run_sessions").doc("run_pending").set({
    state: "pending_validation",
    updatedAtMs: nowMs - 20_000,
    validationAttempt: 1,
  });
  const dispatcher = new FakeValidationDispatcher();

  const result = await repairStaleRunValidations({
    db,
    nowMs,
    dispatcher,
    options: {
      batchSize: 10,
      pendingStaleThresholdMs: 10_000,
      reenqueueCooldownMs: 5_000,
    },
  });

  assert.equal(result.requeuedPendingCount, 1);
  assert.deepEqual(dispatcher.requests, [
    {
      runSessionId: "run_pending",
      taskKey: "repair-1",
    },
  ]);
});

test("enqueue failure keeps pending validation immediately repairable", async () => {
  const nowMs = 300_000;
  await db.collection("run_sessions").doc("run_enqueue_failure").set({
    state: "pending_validation",
    updatedAtMs: nowMs - 20_000,
    validationNextAttemptAtMs: nowMs - 1,
    validationAttempt: 4,
  });
  const dispatcher = new FakeValidationDispatcher({ fail: true });

  const result = await repairStaleRunValidations({
    db,
    nowMs,
    dispatcher,
    options: {
      batchSize: 10,
      pendingStaleThresholdMs: 10_000,
      reenqueueCooldownMs: 5_000,
    },
  });

  assert.equal(result.failureCount, 1);
  const repaired = (
    await db.collection("run_sessions").doc("run_enqueue_failure").get()
  ).data();
  assert.equal(repaired?.state, "pending_validation");
  assert.equal(repaired?.validationTaskGeneration, 1);
  assert.equal(repaired?.validationNextAttemptAtMs, nowMs);
  assert.equal(repaired?.validationLastEnqueueFailureAtMs, nowMs);
});

class FakeValidationDispatcher implements RunValidationTaskDispatcher {
  constructor(options?: { fail?: boolean }) {
    this.fail = options?.fail ?? false;
  }

  readonly fail: boolean;
  readonly requests: Array<{ runSessionId: string; taskKey?: string }> = [];

  async enqueueRunValidationTask(args: {
    runSessionId: string;
    taskKey?: string;
  }): Promise<void> {
    this.requests.push(args);
    if (this.fail) {
      throw new Error("simulated task enqueue failure");
    }
  }
}

async function clearCollection(dbValue: Firestore, name: string): Promise<void> {
  const docs = await dbValue.collection(name).listDocuments();
  await Promise.all(docs.map((docRef) => dbValue.recursiveDelete(docRef)));
}
