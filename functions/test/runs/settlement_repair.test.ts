import assert from "node:assert/strict";
import { after, beforeEach, test } from "node:test";

import { deleteApp, getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, type Firestore } from "firebase-admin/firestore";

import { loadOrCreateCanonicalState } from "../../src/ownership/canonical_store.js";
import { repairPendingSettlements } from "../../src/runs/settlement_repair.js";

const firestoreEmulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
if (!firestoreEmulatorHost) {
  throw new Error(
    "FIRESTORE_EMULATOR_HOST is not set. Run via `firebase emulators:exec`.",
  );
}

const emulatorProjectIdBase =
  process.env.GCLOUD_PROJECT ?? "demo-rpg-runner-functions-tests";
const projectId = `${emulatorProjectIdBase}-settlement-repair`;
const appName = `settlement-repair-tests-${process.pid}-${Date.now()}`;
const app = initializeApp({ projectId }, appName);
const db = getFirestore(app);
const uid = "uid_settlement_repair";
const nowMs = 1_700_000_000_000;

beforeEach(async () => {
  await Promise.all([
    clearCollection(db, "run_sessions"),
    clearCollection(db, "validated_runs"),
    clearCollection(db, "reward_grants"),
    clearCollection(db, "ownership_profiles"),
    clearCollection(db, "system_maintenance"),
  ]);
});

after(async () => {
  await Promise.all(getApps().map((value) => deleteApp(value)));
});

test("poisoned first page is quarantined and cannot starve a valid later page", async () => {
  await seedPendingSession(db, {
    runSessionId: "a_poisoned",
    goldAmount: 0,
    includeSettlementDocuments: false,
    includeRepairDisposition: true,
  });
  await seedPendingSession(db, {
    runSessionId: "b_valid",
    goldAmount: 23,
    includeSettlementDocuments: true,
    includeRepairDisposition: true,
  });

  const firstPage = await repairPendingSettlements({
    db,
    options: { batchSize: 1, staleThresholdMs: 1, nowMs },
  });
  assert.equal(firstPage.scannedCount, 1);
  assert.equal(firstPage.quarantinedCount, 1);
  assert.equal(firstPage.settledCount, 0);

  const secondPage = await repairPendingSettlements({
    db,
    options: { batchSize: 1, staleThresholdMs: 1, nowMs: nowMs + 1 },
  });
  assert.equal(secondPage.scannedCount, 1);
  assert.equal(secondPage.settledCount, 1);
  assert.equal(secondPage.retryablePendingCount, 0);
  assert.equal(secondPage.totalQuarantinedCount, 1);

  const poison = await db.collection("run_sessions").doc("a_poisoned").get();
  assert.equal(poison.get("state"), "settlement_pending");
  assert.equal(poison.get("settlementRepairDisposition"), "quarantined");
  assert.equal(
    poison.get("settlementRepairIncidentReason"),
    "persisted_data_invariant",
  );
  const canonical = await loadOrCreateCanonicalState({ db, uid });
  assert.equal(canonical.progression.gold, 23);
  assert.deepEqual(canonical.progression.appliedRewardGrantIds, ["b_valid"]);

  const retry = await repairPendingSettlements({
    db,
    options: { batchSize: 1, staleThresholdMs: 1, nowMs: nowMs + 2 },
  });
  assert.equal(retry.scannedCount, 0);
  assert.equal(
    (await loadOrCreateCanonicalState({ db, uid })).progression.gold,
    23,
  );
});

test("legacy unclassified pending sessions enter the retryable lane", async () => {
  await seedPendingSession(db, {
    runSessionId: "legacy_valid",
    goldAmount: 19,
    includeSettlementDocuments: true,
    includeRepairDisposition: false,
  });

  const result = await repairPendingSettlements({
    db,
    options: { batchSize: 4, staleThresholdMs: 1, nowMs },
  });

  assert.equal(result.classifiedCount, 1);
  assert.equal(result.settledCount, 1);
  assert.equal(result.retryablePendingCount, 0);
  assert.equal(
    (await loadOrCreateCanonicalState({ db, uid })).progression.gold,
    19,
  );
});

test("infrastructure failures remain retryable and resume after the cursor wraps", async () => {
  await seedPendingSession(db, {
    runSessionId: "retryable_failure",
    goldAmount: 29,
    includeSettlementDocuments: true,
    includeRepairDisposition: true,
  });

  const failed = await repairPendingSettlements({
    db,
    options: { batchSize: 1, staleThresholdMs: 1, nowMs },
    settle: async () => {
      throw new Error("transient Firestore outage");
    },
  });
  assert.equal(failed.failureCount, 1);
  assert.equal(failed.retryablePendingCount, 1);
  const pending = await db
    .collection("run_sessions")
    .doc("retryable_failure")
    .get();
  assert.equal(pending.get("settlementRepairDisposition"), "retryable");
  assert.equal(pending.get("settlementRepairAttempts"), 1);

  const recovered = await repairPendingSettlements({
    db,
    options: { batchSize: 1, staleThresholdMs: 1, nowMs: nowMs + 1 },
  });
  assert.equal(recovered.settledCount, 1);
  assert.equal(recovered.failureCount, 0);
  assert.equal(
    (await loadOrCreateCanonicalState({ db, uid })).progression.gold,
    29,
  );
});

async function seedPendingSession(
  dbValue: Firestore,
  args: {
    runSessionId: string;
    goldAmount: number;
    includeSettlementDocuments: boolean;
    includeRepairDisposition: boolean;
  },
): Promise<void> {
  await dbValue.collection("run_sessions").doc(args.runSessionId).set({
    runSessionId: args.runSessionId,
    uid,
    mode: "practice",
    state: "settlement_pending",
    settlementPendingAtMs: nowMs - 1_000,
    updatedAtMs: nowMs - 1_000,
    expiresAtMs: nowMs + 3_600_000,
    ...(args.includeRepairDisposition
      ? {
          settlementRepairDisposition: "retryable",
          settlementRepairClassifiedAtMs: nowMs - 1_000,
          settlementRepairAttempts: 0,
        }
      : {}),
  });
  if (!args.includeSettlementDocuments) {
    return;
  }
  await dbValue.collection("validated_runs").doc(args.runSessionId).set({
    runSessionId: args.runSessionId,
    uid,
    mode: "practice",
    accepted: true,
    goldEarned: args.goldAmount,
  });
  await dbValue.collection("reward_grants").doc(args.runSessionId).set({
    runSessionId: args.runSessionId,
    uid,
    mode: "practice",
    lifecycleState: "settlement_pending",
    goldAmount: args.goldAmount,
    createdAtMs: nowMs - 1_000,
    updatedAtMs: nowMs - 1_000,
  });
}

async function clearCollection(dbValue: Firestore, name: string): Promise<void> {
  const docs = await dbValue.collection(name).listDocuments();
  await Promise.all(docs.map((docRef) => dbValue.recursiveDelete(docRef)));
}
