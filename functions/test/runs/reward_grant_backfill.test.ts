import assert from "node:assert/strict";
import { after, beforeEach, test } from "node:test";

import { deleteApp, getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, type Firestore } from "firebase-admin/firestore";

import { loadOrCreateCanonicalState } from "../../src/ownership/canonical_store.js";
import { backfillLegacyRewardGrantStates } from "../../src/runs/reward_grant_backfill.js";

const firestoreEmulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
if (!firestoreEmulatorHost) {
  throw new Error(
    "FIRESTORE_EMULATOR_HOST is not set. Run via `firebase emulators:exec`.",
  );
}

const emulatorProjectIdBase =
  process.env.GCLOUD_PROJECT ?? "demo-rpg-runner-functions-tests";
const projectId = `${emulatorProjectIdBase}-reward-grant-backfill`;
const appName = `reward-grant-backfill-tests-${process.pid}-${Date.now()}`;
const app = initializeApp({ projectId }, appName);
const db = getFirestore(app);
const uid = "uid_reward_grant_backfill";
const nowMs = 1_700_000_000_000;

beforeEach(async () => {
  await Promise.all([
    clearCollection(db, "reward_grants"),
    clearCollection(db, "ownership_profiles"),
    clearCollection(db, "system_maintenance"),
  ]);
});

after(async () => {
  await Promise.all(getApps().map((value) => deleteApp(value)));
});

test("off mode performs no inventory or writes", async () => {
  await seedSettledGrant(db, "grant_off", 11);

  const result = await backfillLegacyRewardGrantStates({
    db,
    options: { mode: "off", nowMs },
  });

  assert.deepEqual(result, {
    mode: "off",
    nowMs,
    scannedCount: 0,
    alreadyAppliedCount: 0,
    repairedAppliedCount: 0,
    terminalizedRevocationCount: 0,
    invariantViolationCount: 0,
    nextCursor: null,
    completed: false,
  });
  assert.equal((await db.collection("ownership_profiles").get()).empty, true);
  assert.equal((await db.collection("system_maintenance").get()).empty, true);
});

test("inventory mode reports repair candidates without applying rewards", async () => {
  await seedSettledGrant(db, "grant_inventory", 13);

  const result = await backfillLegacyRewardGrantStates({
    db,
    options: { mode: "inventory", nowMs },
  });

  assert.equal(result.scannedCount, 1);
  assert.equal(result.repairedAppliedCount, 1);
  assert.equal(result.completed, true);
  assert.equal((await db.collection("ownership_profiles").get()).empty, true);
  const migrationState = await db
    .collection("system_maintenance")
    .doc("legacy_reward_grant_migration")
    .get();
  assert.equal(migrationState.get("mode"), "inventory");
  assert.equal(migrationState.get("completedAtMs"), nowMs);
});

test("apply mode credits a legacy reward exactly once", async () => {
  await seedSettledGrant(db, "grant_apply", 17);

  const first = await backfillLegacyRewardGrantStates({
    db,
    options: { mode: "apply", nowMs },
  });
  assert.equal(first.repairedAppliedCount, 1);

  const firstCanonical = await loadOrCreateCanonicalState({ db, uid });
  assert.equal(firstCanonical.progression.gold, 17);
  assert.deepEqual(firstCanonical.progression.appliedRewardGrantIds, [
    "grant_apply",
  ]);

  const retry = await backfillLegacyRewardGrantStates({
    db,
    options: { mode: "apply", nowMs: nowMs + 1 },
  });
  assert.equal(retry.scannedCount, 0);
  assert.equal(retry.repairedAppliedCount, 0);
  assert.equal(retry.completed, true);
  assert.equal(
    (await loadOrCreateCanonicalState({ db, uid })).progression.gold,
    17,
  );
});

async function seedSettledGrant(
  dbValue: Firestore,
  runSessionId: string,
  goldAmount: number,
): Promise<void> {
  await dbValue.collection("reward_grants").doc(runSessionId).set({
    uid,
    runSessionId,
    lifecycleState: "validated_settled",
    goldAmount,
    mode: "practice",
  });
}

async function clearCollection(dbValue: Firestore, name: string): Promise<void> {
  const docs = await dbValue.collection(name).listDocuments();
  await Promise.all(docs.map((docRef) => dbValue.recursiveDelete(docRef)));
}
