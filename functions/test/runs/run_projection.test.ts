import assert from "node:assert/strict";
import { after, beforeEach, test } from "node:test";

import { deleteApp, getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, type Firestore } from "firebase-admin/firestore";

import { loadRunSessionSubmissionStatus } from "../../src/runs/submission_store.js";

const firestoreEmulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
if (!firestoreEmulatorHost) {
  throw new Error(
    "FIRESTORE_EMULATOR_HOST is not set. Run via `firebase emulators:exec`.",
  );
}

const emulatorProjectIdBase =
  process.env.GCLOUD_PROJECT ?? "demo-rpg-runner-functions-tests";
const projectId = `${emulatorProjectIdBase}-run-projection`;
const appName = `run-projection-tests-${process.pid}-${Date.now()}`;
const app = initializeApp({ projectId }, appName);
const db = getFirestore(app);

const uid = "uid_projection_owner";
const nowMs = 1700000000000;

beforeEach(async () => {
  await Promise.all([
    clearCollection(db, "run_sessions"),
    clearCollection(db, "reward_grants"),
    clearCollection(db, "validated_runs"),
  ]);
});

after(async () => {
  await Promise.all(getApps().map((value) => deleteApp(value)));
});

// ---------------------------------------------------------------------------
// No reward grant path
// ---------------------------------------------------------------------------

test("reward projection: no reward grant and no validated run → reward absent", async () => {
  const runSessionId = await seedRunSession(db, uid, "pending_validation");

  const result = await loadRunSessionSubmissionStatus({ db, uid, runSessionId });

  assert.equal(result.submissionStatus.reward, undefined);
});

// ---------------------------------------------------------------------------
// Reward grant lifecycle states
// ---------------------------------------------------------------------------

test("reward projection: provisional_created grant → provisional with zero deltas", async () => {
  const runSessionId = await seedRunSession(db, uid, "pending_validation");
  await seedRewardGrant(db, runSessionId, {
    uid,
    lifecycleState: "provisional_created",
    goldAmount: 30,
  });

  const result = await loadRunSessionSubmissionStatus({ db, uid, runSessionId });

  const reward = result.submissionStatus.reward as Record<string, unknown>;
  assert.equal(reward.status, "provisional");
  assert.equal(reward.provisionalGold, 30);
  assert.equal(reward.effectiveGoldDelta, 0);
  assert.equal(reward.spendableGoldDelta, 0);
  assert.equal(reward.grantId, runSessionId);
});

test("reward projection: provisional_visible grant → provisional with zero deltas", async () => {
  const runSessionId = await seedRunSession(db, uid, "pending_validation");
  await seedRewardGrant(db, runSessionId, {
    uid,
    lifecycleState: "provisional_visible",
    goldAmount: 18,
  });

  const result = await loadRunSessionSubmissionStatus({ db, uid, runSessionId });

  const reward = result.submissionStatus.reward as Record<string, unknown>;
  assert.equal(reward.status, "provisional");
  assert.equal(reward.provisionalGold, 18);
  assert.equal(reward.effectiveGoldDelta, 0);
  assert.equal(reward.spendableGoldDelta, 0);
});

test("reward projection: validated_settled grant → final reward with full deltas", async () => {
  const runSessionId = await seedRunSession(db, uid, "validated");
  await seedRewardGrant(db, runSessionId, {
    uid,
    lifecycleState: "validated_settled",
    goldAmount: 75,
  });

  const result = await loadRunSessionSubmissionStatus({ db, uid, runSessionId });

  const reward = result.submissionStatus.reward as Record<string, unknown>;
  assert.equal(reward.status, "final");
  assert.equal(reward.provisionalGold, 75);
  assert.equal(reward.effectiveGoldDelta, 75);
  assert.equal(reward.spendableGoldDelta, 75);
});

test("reward projection: revocation_visible grant → revoked reward with zero deltas", async () => {
  const runSessionId = await seedRunSession(db, uid, "rejected");
  await seedRewardGrant(db, runSessionId, {
    uid,
    lifecycleState: "revocation_visible",
    goldAmount: 20,
    settlementReason: "replay_invalid",
  });

  const result = await loadRunSessionSubmissionStatus({ db, uid, runSessionId });

  const reward = result.submissionStatus.reward as Record<string, unknown>;
  assert.equal(reward.status, "revoked");
  assert.equal(reward.provisionalGold, 20);
  assert.equal(reward.effectiveGoldDelta, 0);
  assert.equal(reward.spendableGoldDelta, 0);
  assert.equal(reward.message, "replay_invalid");
});

test("reward projection: revoked_final grant → revoked reward with zero deltas", async () => {
  const runSessionId = await seedRunSession(db, uid, "rejected");
  await seedRewardGrant(db, runSessionId, {
    uid,
    lifecycleState: "revoked_final",
    goldAmount: 10,
    revokedFinalBy: "ownership_reconcile",
  });

  const result = await loadRunSessionSubmissionStatus({ db, uid, runSessionId });

  const reward = result.submissionStatus.reward as Record<string, unknown>;
  assert.equal(reward.status, "revoked");
  assert.equal(reward.provisionalGold, 10);
  assert.equal(reward.effectiveGoldDelta, 0);
  assert.equal(reward.spendableGoldDelta, 0);
});

test("reward projection: malformed goldAmount treated as zero", async () => {
  const runSessionId = await seedRunSession(db, uid, "pending_validation");
  await seedRewardGrant(db, runSessionId, {
    uid,
    lifecycleState: "provisional_created",
    goldAmount: "not-a-number",
  });

  const result = await loadRunSessionSubmissionStatus({ db, uid, runSessionId });

  const reward = result.submissionStatus.reward as Record<string, unknown>;
  assert.equal(reward.status, "provisional");
  assert.equal(reward.provisionalGold, 0);
  assert.equal(reward.effectiveGoldDelta, 0);
  assert.equal(reward.spendableGoldDelta, 0);
});

test("reward projection: negative goldAmount clamped to zero", async () => {
  const runSessionId = await seedRunSession(db, uid, "validated");
  await seedRewardGrant(db, runSessionId, {
    uid,
    lifecycleState: "validated_settled",
    goldAmount: -99,
  });

  const result = await loadRunSessionSubmissionStatus({ db, uid, runSessionId });

  const reward = result.submissionStatus.reward as Record<string, unknown>;
  assert.equal(reward.status, "final");
  assert.equal(reward.provisionalGold, 0);
  assert.equal(reward.effectiveGoldDelta, 0);
  assert.equal(reward.spendableGoldDelta, 0);
});

test("reward projection: unknown grant state → reward absent (defensive)", async () => {
  const runSessionId = await seedRunSession(db, uid, "pending_validation");
  await seedRewardGrant(db, runSessionId, {
    uid,
    lifecycleState: "unknown_future_state",
    goldAmount: 5,
  });

  const result = await loadRunSessionSubmissionStatus({ db, uid, runSessionId });

  assert.equal(result.submissionStatus.reward, undefined);
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function seedRunSession(
  dbValue: Firestore,
  ownerUid: string,
  state: string,
): Promise<string> {
  const runSessionId = `proj_test_${Date.now()}_${Math.random().toString(36).slice(2)}`;
  await dbValue.collection("run_sessions").doc(runSessionId).set({
    runSessionId,
    uid: ownerUid,
    state,
    expiresAtMs: nowMs + 3_600_000,
    updatedAtMs: nowMs,
  });
  return runSessionId;
}

async function seedRewardGrant(
  dbValue: Firestore,
  runSessionId: string,
  fields: Record<string, unknown>,
): Promise<void> {
  await dbValue.collection("reward_grants").doc(runSessionId).set({
    runSessionId,
    updatedAtMs: nowMs,
    createdAtMs: nowMs,
    ...fields,
  });
}

async function clearCollection(dbValue: Firestore, name: string): Promise<void> {
  const docs = await dbValue.collection(name).listDocuments();
  await Promise.all(docs.map((docRef) => dbValue.recursiveDelete(docRef)));
}
