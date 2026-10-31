import assert from "node:assert/strict";
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";
import { runCompletionReceiptRef } from "../../src/runs/completion_receipt.js";
import { after, beforeEach, test } from "node:test";

import { deleteApp, getApps, initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore, type Firestore } from "firebase-admin/firestore";
import type { CloudTasksClient } from "@google-cloud/tasks";

import { loadOrCreateCanonicalState } from "../../src/ownership/canonical_store.js";
import { executeOwnershipCommand } from "../../src/ownership/command_executor.js";
import { readAchievementProgress } from "../../src/ownership/achievements.js";
import {
  ImmediateSettlementDispatchRequestError,
  dispatchImmediateSettlement,
} from "../../src/runs/immediate_settlement_dispatch.js";
import { backfillLegacyRewardGrantStates } from "../../src/runs/reward_grant_backfill.js";
import {
  enqueueAcceptedRunProjection,
  enqueueBoardProjectionReconciliation,
} from "../../src/runs/projection_dispatch.js";
import {
  parseProjectionReconciliationBatchSize,
  projectionReconciliationSchedule,
  reconcileLeaderboardBoardProjections,
} from "../../src/runs/projection_reconciliation.js";
import { settleAcceptedRunSession } from "../../src/runs/reward_settlement.js";
import { listInbox, loadInboxSummary } from "../../src/inbox/store.js";
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

// This suite asserts the final post-migration behavior, without the temporary
// read-time compatibility path used only during production inventory/apply.
process.env.LEGACY_READ_RECONCILIATION_ENABLED = "false";
process.env.REPLAY_VALIDATOR_URL = "https://validator.example";

beforeEach(async () => {
  await Promise.all([
    clearCollection(db, "run_sessions"),
    clearCollection(db, "run_completion_receipts"),
    clearCollection(db, "reward_grants"),
    clearCollection(db, "validated_runs"),
    clearCollection(db, "ownership_profiles"),
    clearCollection(db, "account_deletion_requests"),
    clearCollection(db, "system_maintenance"),
    clearCollection(db, "leaderboard_boards"),
    clearCollection(db, "system_messages"),
    clearCollection(db, "inbox_rewards"),
    clearCollection(db, "inbox_summaries"),
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

  const result = await loadRunSessionSubmissionStatus({
    db,
    uid,
    runSessionId,
  });

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

  const result = await loadRunSessionSubmissionStatus({
    db,
    uid,
    runSessionId,
  });

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

  const result = await loadRunSessionSubmissionStatus({
    db,
    uid,
    runSessionId,
  });

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

  const result = await loadRunSessionSubmissionStatus({
    db,
    uid,
    runSessionId,
  });

  const reward = result.submissionStatus.reward as Record<string, unknown>;
  assert.equal(reward.status, "final");
  assert.equal(reward.provisionalGold, 75);
  assert.equal(reward.effectiveGoldDelta, 75);
  assert.equal(reward.spendableGoldDelta, 75);
});

test("settlement handoff credits gold once and exposes terminal validation together", async () => {
  const runSessionId = await seedRunSession(db, uid, "settlement_pending");
  await db
    .collection("run_sessions")
    .doc(runSessionId)
    .set({ mode: "practice" }, { merge: true });
  await db.collection("validated_runs").doc(runSessionId).set({
    runSessionId,
    uid,
    mode: "practice",
    accepted: true,
    goldEarned: 75,
  });
  await seedRewardGrant(db, runSessionId, {
    uid,
    mode: "practice",
    lifecycleState: "settlement_pending",
    goldAmount: 75,
  });

  const firstOutcome = await settleAcceptedRunSession({
    db,
    runSessionId,
    nowMs,
  });

  assert.equal(firstOutcome, "settled");
  const canonical = await loadOrCreateCanonicalState({ db, uid });
  assert.equal(canonical.progression.gold, 75);
  assert.deepEqual(canonical.progression.playerProgress, {
    schemaVersion: 1, totalXp: 0, acceptedRuns: 0,
    runsByLevel: {},
    damageDealt100: 0, damageTaken100: 0,
  });
  assert.equal(canonical.revision, 1);
  const receiptRef = runCompletionReceiptRef(db, uid, runSessionId);
  const receipt = (await receiptRef.get()).data()!;
  assert.deepEqual(receipt.canonicalState, canonical);
  assert.equal(receipt.submissionStatus.reward.spendableGoldDelta, 75);
  assert.equal(receipt.submissionStatus.state, "validated");
  assert.equal(receipt.submissionStatus.validatedRun, undefined);
  const fixture = JSON.parse(JSON.stringify(receipt).replaceAll(runSessionId, "run_completion_fixture"));
  // Normalize only the current-day store marker; all account fields remain in
  // the real transaction payload consumed by the Dart contract test.
  fixture.canonicalState.progression.store.refreshDayKeyUtc = "2023-11-14";
  const fixturePath = resolve(process.cwd(), "test/fixtures/run_completion_receipt_v1.json");
  if (process.env.UPDATE_RUN_COMPLETION_FIXTURE === "true") {
    mkdirSync(resolve(process.cwd(), "test/fixtures"), { recursive: true });
    writeFileSync(fixturePath, `${JSON.stringify(fixture, null, 2)}\n`);
  }
  assert.deepEqual(fixture, JSON.parse(readFileSync(fixturePath, "utf8")));
  const session = await db.collection("run_sessions").doc(runSessionId).get();
  const grant = await db.collection("reward_grants").doc(runSessionId).get();
  assert.equal(session.get("state"), "validated");
  assert.equal(grant.get("lifecycleState"), "validated_settled");
  assert.equal(grant.get("appliedAtMs"), nowMs);
  assert.equal(grant.get("updatedAtMs"), nowMs);
  assert.equal(grant.get("appliedRevision"), 1);

  const secondOutcome = await settleAcceptedRunSession({
    db,
    runSessionId,
    nowMs: nowMs + 1,
  });
  const canonicalAfterRetry = await loadOrCreateCanonicalState({ db, uid });
  assert.equal(secondOutcome, "already_settled");
  assert.deepEqual((await receiptRef.get()).data(), receipt);
  assert.equal(canonicalAfterRetry.progression.gold, 75);
  assert.equal(canonicalAfterRetry.revision, 1);
  const grantAfterCanonicalReads = await db
    .collection("reward_grants")
    .doc(runSessionId)
    .get();
  assert.equal(grantAfterCanonicalReads.get("appliedAtMs"), nowMs);
  assert.equal(grantAfterCanonicalReads.get("updatedAtMs"), nowMs);
});

test("Codex settlement is atomic and concurrent retries count a run once", async () => {
  const runSessionId = await seedCodexRun("competitive", "forest", 10000,
    { grojib: 10, bringerOfDeath: 5 });
  const outcomes = await Promise.all([
    settleAcceptedRunSession({ db, runSessionId, nowMs }),
    settleAcceptedRunSession({ db, runSessionId, nowMs }),
  ]);
  assert.deepEqual(outcomes.sort(), ["already_settled", "settled"]);
  const canonical = await loadOrCreateCanonicalState({ db, uid });
  assert.equal(canonical.revision, 1);
  assert.deepEqual(canonical.progression.codex, {
    schemaVersion: 2,
    competitiveBestScores: { forest: 10000 },
  });
  assert.deepEqual(canonical.progression.enemyDefeats, {
    schemaVersion: 1, byEnemy: { grojib: 10, bringerOfDeath: 5 },
  });
});

test("shared defeats accumulate across modes while Codex retains competitive best", async () => {
  for (const [mode, level, score, kills] of [
    ["practice", "forest", 99999, { grojib: 4 }],
    ["weekly", "forest", 99999, { grojib: 3 }],
    ["competitive", "forest", 10000, { grojib: 3 }],
    ["competitive", "forest", 2000, { bringerOfDeath: 1 }],
    ["competitive", "field", 9000, {}],
  ] as const) {
    const runSessionId = await seedCodexRun(mode, level, score, kills);
    assert.equal(await settleAcceptedRunSession({ db, runSessionId, nowMs }), "settled");
  }
  const canonical = await loadOrCreateCanonicalState({ db, uid });
  assert.deepEqual(canonical.progression.codex, {
    schemaVersion: 2,
    competitiveBestScores: { forest: 10000, field: 9000 },
  });
  assert.deepEqual(canonical.progression.enemyDefeats, {
    schemaVersion: 1, byEnemy: { grojib: 10, bringerOfDeath: 1 },
  });
});

test("player stats and score XP settle once across run modes", async () => {
  for (const [mode, level, score, dealt, taken] of [
    ["practice", "forest", 10000, 12345, 678],
    ["competitive", "forest", 10050, 500, 300],
    ["weekly", "field", 2500, 0, 100],
  ] as const) {
    const runSessionId = await seedCodexRun(mode, level, score, {});
    await db.collection("validated_runs").doc(runSessionId).update({
      playerRunStats: {
        schemaVersion: 1, damageDealt100: dealt, damageTaken100: taken,
      },
    });
    const outcomes = await Promise.all([
      settleAcceptedRunSession({ db, runSessionId, nowMs }),
      settleAcceptedRunSession({ db, runSessionId, nowMs }),
    ]);
    assert.deepEqual(outcomes.sort(), ["already_settled", "settled"]);
  }
  const canonical = await loadOrCreateCanonicalState({ db, uid });
  assert.deepEqual(canonical.progression.playerProgress, {
    schemaVersion: 1, totalXp: 112, acceptedRuns: 3,
    runsByLevel: {
      forest: { practice: 1, competitive: 1, weekly: 0 },
      field: { practice: 0, competitive: 0, weekly: 1 },
    },
    damageDealt100: 12845, damageTaken100: 1078,
  });
  assert.equal(canonical.revision, 3);
});

test("new level gifts are atomic, cover multiple crossings and never backfill old levels", async () => {
  const initial = await loadOrCreateCanonicalState({ db, uid });
  await db.collection("ownership_profiles").doc(`${uid}__${initial.profileId}`).update({
    "progression.playerProgress": { schemaVersion: 1, totalXp: 224,
      acceptedRuns: 1, runsByLevel: {}, damageDealt100: 0, damageTaken100: 0 },
  });
  assert.equal((await listInbox(db, uid)).messages.length, 0);
  const runSessionId = await seedCodexRun("practice", "forest", 100000, {});
  await db.collection("validated_runs").doc(runSessionId).update({
    playerRunStats: { schemaVersion: 1, damageDealt100: 0, damageTaken100: 0 },
  });
  assert.deepEqual((await Promise.all([
    settleAcceptedRunSession({ db, runSessionId, nowMs }),
    settleAcceptedRunSession({ db, runSessionId, nowMs }),
  ])).sort(), ["already_settled", "settled"]);
  const inbox = await listInbox(db, uid);
  assert.deepEqual(inbox.messages.map((m) => m.sourceId).sort(), ["level:4", "level:5"]);
  for (const message of inbox.messages) {
    assert.deepEqual(message.rewards, [{ kind: "gold", amount: 25 }]);
    assert.equal(message.claimedAtMs, null);
  }
  assert.equal((await loadInboxSummary(db, uid)).unclaimedCount, 2);
  const canonical = await loadOrCreateCanonicalState({ db, uid });
  assert.equal(canonical.progression.gold, (await db.collection("reward_grants").doc(runSessionId).get()).get("goldAmount"));
});

for (const summary of [
  { revision: 1, unreadCount: -1, unclaimedCount: 0 },
  { revision: Number.MAX_SAFE_INTEGER, unreadCount: 0, unclaimedCount: 0 },
]) {
  test(`invalid inbox counters ${JSON.stringify(summary)} quarantine settlement atomically`, async () => {
    await loadOrCreateCanonicalState({ db, uid });
    await db.collection("inbox_summaries").doc(uid).set({ uid, ...summary });
    const runSessionId = await seedCodexRun("practice", "forest", 20000, {});
    await db.collection("validated_runs").doc(runSessionId).update({
      playerRunStats: { schemaVersion: 1, damageDealt100: 0, damageTaken100: 0 },
    });
    assert.equal(await settleAcceptedRunSession({ db, runSessionId, nowMs }), "invariant_violation");
    assert.equal((await loadOrCreateCanonicalState({ db, uid })).revision, 0);
    assert.equal((await db.collection("system_messages").get()).size, 0);
    assert.equal((await db.collection("run_sessions").doc(runSessionId).get()).get("state"), "settlement_pending");
    assert.equal((await runCompletionReceiptRef(db, uid, runSessionId).get()).exists, false);
  });
}

test("invalid player stats abort settlement and preserve legacy account state", async () => {
  const initial = await loadOrCreateCanonicalState({ db, uid });
  await db.collection("ownership_profiles").doc(`${uid}__${initial.profileId}`).update({
    "progression.playerProgress": FieldValue.delete(),
  });
  const runSessionId = await seedCodexRun("practice", "forest", 10000, { grojib: 1 });
  await db.collection("validated_runs").doc(runSessionId).update({
    playerRunStats: { schemaVersion: 1, damageDealt100: -1, damageTaken100: 0 },
  });
  assert.equal(await settleAcceptedRunSession({ db, runSessionId, nowMs }), "invariant_violation");
  const afterFailure = await loadOrCreateCanonicalState({ db, uid });
  assert.equal(afterFailure.progression.playerProgress, undefined);
  assert.equal(afterFailure.progression.gold, 0);
  assert.deepEqual(afterFailure.progression.codex, {
    schemaVersion: 2, competitiveBestScores: {},
  });
  await db.collection("validated_runs").doc(runSessionId).update({
    playerRunStats: { schemaVersion: 1, damageDealt100: 150, damageTaken100: 25 },
  });
  assert.equal(await settleAcceptedRunSession({ db, runSessionId, nowMs }), "settled");
  const afterSuccess = await loadOrCreateCanonicalState({ db, uid });
  assert.deepEqual(afterSuccess.progression.playerProgress, {
    schemaVersion: 1, totalXp: 50, acceptedRuns: 1,
    runsByLevel: { forest: { practice: 1, competitive: 0, weekly: 0 } },
    damageDealt100: 150, damageTaken100: 25,
  });
  assert.deepEqual(afterSuccess.progression.enemyDefeats, {
    schemaVersion: 1, byEnemy: { grojib: 1 },
  });
});

test("invalid Codex evidence rolls back gold, progress, grant and session together", async () => {
  for (const patch of [
    { schemaVersion: 2 }, { levelId: "field" },
    { enemyKills: { grojib: -1 } }, { enemyKills: { grojib: 0.5 } },
  ]) {
    const runSessionId = await seedCodexRun("practice", "forest", 100, { grojib: 10 });
    await db.collection("validated_runs").doc(runSessionId).set({
      codex: { schemaVersion: 1, levelId: "forest", enemyKills: { grojib: 10 }, ...patch },
    }, { merge: true });
    assert.equal(await settleAcceptedRunSession({ db, runSessionId, nowMs }), "invariant_violation");
    const canonical = await loadOrCreateCanonicalState({ db, uid });
    assert.equal(canonical.progression.gold, 0);
    assert.equal(canonical.revision, 0);
    assert.equal((await db.collection("run_sessions").doc(runSessionId).get()).get("state"), "settlement_pending");
    assert.equal((await db.collection("reward_grants").doc(runSessionId).get()).get("lifecycleState"), "settlement_pending");
  }
});

test("legacy accounts receive Codex progress even with a zero-gold grant", async () => {
  const initial = await loadOrCreateCanonicalState({ db, uid });
  await db.collection("ownership_profiles").doc(`${uid}__${initial.profileId}`).update({
    "progression.codex": FieldValue.delete(),
  });
  const runSessionId = await seedCodexRun("competitive", "forest", 10000, {});
  await db.collection("validated_runs").doc(runSessionId).update({ goldEarned: 0 });
  await db.collection("reward_grants").doc(runSessionId).update({ goldAmount: 0 });
  assert.equal(await settleAcceptedRunSession({ db, runSessionId, nowMs }), "settled");
  const canonical = await loadOrCreateCanonicalState({ db, uid });
  assert.equal(canonical.progression.gold, 0);
  assert.equal(canonical.revision, initial.revision + 1);
  assert.deepEqual(canonical.progression.codex, {
    schemaVersion: 2, competitiveBestScores: { forest: 10000 },
  });
});

test("rejected and pending validation runs cannot credit Codex progress", async () => {
  for (const state of ["pending_validation", "rejected"]) {
    const runSessionId = await seedCodexRun("practice", "forest", 100, { grojib: 10 });
    await db.collection("run_sessions").doc(runSessionId).update({ state });
    assert.equal(await settleAcceptedRunSession({ db, runSessionId, nowMs }), "not_ready");
  }
  const canonical = await loadOrCreateCanonicalState({ db, uid });
  assert.deepEqual(canonical.progression.codex, {
    schemaVersion: 2, competitiveBestScores: {},
  });
  assert.deepEqual(canonical.progression.enemyDefeats, {
    schemaVersion: 1, byEnemy: {},
  });
});

test("legacy Codex kills transfer once to the shared defeat map", async () => {
  const initial = await loadOrCreateCanonicalState({ db, uid });
  const profileRef = db.collection("ownership_profiles").doc(`${uid}__${initial.profileId}`);
  await profileRef.update({
    "progression.codex": {
      schemaVersion: 1,
      enemyKills: { grojib: 8, derf: 2 },
      competitiveBestScores: { forest: 9000 },
    },
    "progression.enemyDefeats": FieldValue.delete(),
  });
  const runSessionId = await seedCodexRun("competitive", "forest", 10000,
    { grojib: 2 });
  await db.collection("validated_runs").doc(runSessionId).update({
    playerRunStats: { schemaVersion: 1, damageDealt100: 50, damageTaken100: 5 },
  });
  assert.equal(await settleAcceptedRunSession({ db, runSessionId, nowMs }), "settled");
  assert.equal(await settleAcceptedRunSession({ db, runSessionId, nowMs }), "already_settled");
  const canonical = await loadOrCreateCanonicalState({ db, uid });
  assert.deepEqual(canonical.progression.codex, {
    schemaVersion: 2, competitiveBestScores: { forest: 10000 },
  });
  assert.deepEqual(canonical.progression.enemyDefeats, {
    schemaVersion: 1, byEnemy: { grojib: 10, derf: 2 },
  });
  assert.deepEqual(canonical.progression.playerProgress, {
    schemaVersion: 1, totalXp: 50, acceptedRuns: 1,
    runsByLevel: { forest: { practice: 0, competitive: 1, weekly: 0 } },
    damageDealt100: 50, damageTaken100: 5,
  });
  assert.equal((await profileRef.get()).get("progression.codex.enemyKills"), undefined);
});

test("achievements settle once in every mode without historical credit", async () => {
  const initial = await loadOrCreateCanonicalState({ db, uid });
  await db.collection("ownership_profiles").doc(`${uid}__${initial.profileId}`).update({
    "progression.playerProgress.acceptedRuns": 999,
    "progression.enemyDefeats.byEnemy.grojib": 9999,
  });
  for (const mode of ["practice", "competitive", "weekly"] as const) {
    const runSessionId = await seedCodexRun(mode, "forest", 100, { grojib: 10 });
    await db.collection("validated_runs").doc(runSessionId).update({
      distanceMeters: 100, durationSeconds: 0, endedReason: "playerDied",
      playerRunStats: { schemaVersion: 1, damageDealt100: 1, damageTaken100: 1 },
    });
    const outcomes = await Promise.all([
      settleAcceptedRunSession({ db, runSessionId, nowMs }),
      settleAcceptedRunSession({ db, runSessionId, nowMs: nowMs + 1 }),
    ]);
    assert.deepEqual(outcomes.sort(), ["already_settled", "settled"]);
  }
  const canonical = await loadOrCreateCanonicalState({ db, uid });
  const progress = readAchievementProgress(canonical.progression.achievements);
  assert.deepEqual(progress.entries.map((entry) => entry.value), [3, 100, 300, 0, 30]);
  assert.equal(canonical.progression.gold, 3, "achievement rewards are not automatic");
  assert.ok(progress.entries[0].tiers[0].achievedAtMs! >= nowMs);
  assert.equal(progress.entries[0].tiers[0].claimedAtMs, null);
});

test("short runs and manual quits settle achievement metrics once in every mode", async () => {
  for (const mode of ["practice", "competitive", "weekly"] as const) {
    for (const [endedReason, distanceMeters, durationSeconds, kills] of [
      ["playerDied", 10, 5, 1], ["gaveUp", 10, 5, 1], ["gaveUp", 500, 300, 9],
    ] as const) {
      const runSessionId = await seedCodexRun(mode, "forest", 100, { grojib: kills });
      await db.collection("validated_runs").doc(runSessionId).update({
        distanceMeters, durationSeconds, endedReason,
        playerRunStats: { schemaVersion: 1, damageDealt100: 1, damageTaken100: 1 },
      });
      const outcomes = await Promise.all([
        settleAcceptedRunSession({ db, runSessionId, nowMs }),
        settleAcceptedRunSession({ db, runSessionId, nowMs: nowMs + 1 }),
      ]);
      assert.deepEqual(outcomes.sort(), ["already_settled", "settled"]);
    }
  }
  const canonical = await loadOrCreateCanonicalState({ db, uid });
  const progress = readAchievementProgress(canonical.progression.achievements);
  assert.deepEqual(progress.entries.map((entry) => entry.value), [0, 500, 1560, 930, 33]);
  assert.equal(progress.entries[0].tiers[0].achievedAtMs, null);
  assert.ok(progress.entries.slice(1).every((entry) => entry.tiers[0].achievedAtMs !== null));
  assert.equal(canonical.progression.gold, 9, "achievement rewards still require a claim");
});

test("achievement claims enforce revision, identity, deletion and durable payment receipts", async () => {
  const runSessionId = await seedCodexRun("practice", "forest", 100, { grojib: 30 });
  await db.collection("validated_runs").doc(runSessionId).update({
    distanceMeters: 1500, durationSeconds: 120, endedReason: "fellIntoGap",
    playerRunStats: { schemaVersion: 1, damageDealt100: 1, damageTaken100: 1 },
  });
  assert.equal(await settleAcceptedRunSession({ db, runSessionId, nowMs }), "settled");
  let canonical = await loadOrCreateCanonicalState({ db, uid });
  const command = {
    type: "claimAchievements" as const, userId: uid, sessionId: "session",
    commandId: "achievement_claim", expectedRevision: canonical.revision,
    payload: { achievementId: null },
  };
  const first = await executeOwnershipCommand({ db, uid, command, nowMs: nowMs + 100 });
  assert.equal(first.rejectedReason, null);
  assert.equal(first.canonicalState.progression.gold, 176);
  const repeated = await executeOwnershipCommand({ db, uid, command, nowMs: nowMs + 200 });
  assert.equal(repeated.replayedFromIdempotency, true);
  assert.equal(repeated.canonicalState.progression.gold, 176);
  const mismatch = await executeOwnershipCommand({ db, uid,
    command: { ...command, payload: { achievementId: "slayer" } }, nowMs });
  assert.equal(mismatch.rejectedReason, "idempotencyKeyReuseMismatch");
  const stale = await executeOwnershipCommand({ db, uid,
    command: { ...command, commandId: "stale_claim" }, nowMs });
  assert.equal(stale.rejectedReason, "staleRevision");
  canonical = await loadOrCreateCanonicalState({ db, uid });
  const concurrent = await Promise.all(["new_claim_1", "new_claim_2"].map((commandId) =>
    executeOwnershipCommand({ db, uid,
      command: { ...command, commandId, expectedRevision: canonical.revision }, nowMs: nowMs + 300 })));
  assert.equal(concurrent.filter((result) => result.rejectedReason === "staleRevision").length, 1);
  canonical = await loadOrCreateCanonicalState({ db, uid });
  assert.equal(canonical.progression.gold, 176, "fresh command IDs cannot repay claimed tiers");
  const tiers = readAchievementProgress(canonical.progression.achievements).entries[1].tiers;
  assert.equal(tiers[0].achievedAtMs, nowMs);
  assert.equal(tiers[0].claimedAtMs, nowMs + 100);
  const spoof = await executeOwnershipCommand({ db, uid,
    command: { ...command, userId: "other", commandId: "spoof", expectedRevision: canonical.revision } });
  assert.equal(spoof.rejectedReason, "forbidden");
  await db.collection("account_deletion_requests").doc(uid).set({ state: "requested" });
  await assert.rejects(executeOwnershipCommand({ db, uid,
    command: { ...command, commandId: "after_deletion", expectedRevision: canonical.revision } }));
});

test("invalid achievement evidence rolls back run gold and terminal settlement", async () => {
  const runSessionId = await seedCodexRun("practice", "forest", 100, { grojib: 1 });
  await db.collection("validated_runs").doc(runSessionId).update({
    distanceMeters: -1, durationSeconds: 10, endedReason: "playerDied",
    playerRunStats: { schemaVersion: 1, damageDealt100: 1, damageTaken100: 1 },
  });
  assert.equal(await settleAcceptedRunSession({ db, runSessionId, nowMs }), "invariant_violation");
  const canonical = await loadOrCreateCanonicalState({ db, uid });
  assert.equal(canonical.progression.gold, 0);
  assert.equal(readAchievementProgress(canonical.progression.achievements).entries[0].value, 0);
  assert.equal((await db.collection("run_sessions").doc(runSessionId).get()).get("state"), "settlement_pending");
});

async function seedCodexRun(
  mode: "practice" | "competitive" | "weekly", levelId: string,
  score: number, enemyKills: Record<string, number>,
): Promise<string> {
  const runSessionId = await seedRunSession(db, uid, "settlement_pending");
  const context = mode === "practice" ? { mode } : {
    mode, boardId: `codex_${mode}_${levelId}`,
    boardKey: { mode, levelId, windowId: mode === "weekly" ? "2023-W46" : "2023-11",
      rulesetVersion: "rules-v1", scoreVersion: "score-v4" },
  };
  await db.collection("run_sessions").doc(runSessionId).set({
    ...context, levelId, runTicket: { levelId },
  }, { merge: true });
  await db.collection("validated_runs").doc(runSessionId).set({
    ...context, runSessionId, uid, accepted: true, goldEarned: 1, score,
    codex: { schemaVersion: 1, levelId, enemyKills },
  });
  await seedRewardGrant(db, runSessionId, {
    ...context, uid, lifecycleState: "settlement_pending", goldAmount: 1,
  });
  return runSessionId;
}

test("settlement does not recreate canonical state after account deletion", async () => {
  const runSessionId = await seedRunSession(db, uid, "settlement_pending");
  await db
    .collection("run_sessions")
    .doc(runSessionId)
    .set({ mode: "practice" }, { merge: true });
  await db.collection("validated_runs").doc(runSessionId).set({
    runSessionId,
    uid,
    mode: "practice",
    accepted: true,
    goldEarned: 75,
  });
  await seedRewardGrant(db, runSessionId, {
    uid,
    mode: "practice",
    lifecycleState: "settlement_pending",
    goldAmount: 75,
  });
  await db.collection("account_deletion_requests").doc(uid).set({
    state: "requested",
    requestedAtMs: nowMs,
  });

  await assert.rejects(
    settleAcceptedRunSession({ db, runSessionId, nowMs }),
    (error: { code?: unknown }) => error.code === "failed-precondition",
  );

  assert.equal((await db.collection("ownership_profiles").get()).empty, true);
  assert.equal(
    (await db.collection("run_sessions").doc(runSessionId).get()).get("state"),
    "settlement_pending",
  );
});

test("immediate settlement dispatch accepts only a run-session id and uses canonical settlement", async () => {
  const runSessionId = await seedRunSession(db, uid, "settlement_pending");
  await db
    .collection("run_sessions")
    .doc(runSessionId)
    .set({ mode: "practice" }, { merge: true });
  await db.collection("validated_runs").doc(runSessionId).set({
    runSessionId,
    uid,
    mode: "practice",
    accepted: true,
    goldEarned: 25,
  });
  await seedRewardGrant(db, runSessionId, {
    uid,
    mode: "practice",
    lifecycleState: "settlement_pending",
    goldAmount: 25,
  });

  const result = await dispatchImmediateSettlement({
    db,
    data: { runSessionId },
  });

  assert.deepEqual(result, { runSessionId, outcome: "settled" });
  const canonical = await loadOrCreateCanonicalState({ db, uid });
  assert.equal(canonical.progression.gold, 25);
  assert.equal(canonical.revision, 1);
});

test("immediate settlement dispatch rejects malformed requests before settlement", async () => {
  await assert.rejects(
    () => dispatchImmediateSettlement({ db, data: { runSessionId: "   " } }),
    ImmediateSettlementDispatchRequestError,
  );
});

test("immediate, Eventarc, and repair races credit one canonical reward", async () => {
  const runSessionId = await seedRunSession(db, uid, "settlement_pending");
  await db
    .collection("run_sessions")
    .doc(runSessionId)
    .set({ mode: "practice", settlementPendingAtMs: nowMs }, { merge: true });
  await db.collection("validated_runs").doc(runSessionId).set({
    runSessionId,
    uid,
    mode: "practice",
    accepted: true,
    goldEarned: 31,
  });
  await seedRewardGrant(db, runSessionId, {
    uid,
    mode: "practice",
    lifecycleState: "settlement_pending",
    goldAmount: 31,
  });

  const outcomes = await Promise.all([
    dispatchImmediateSettlement({ db, data: { runSessionId } }).then(
      (result) => result.outcome,
    ),
    settleAcceptedRunSession({
      db,
      runSessionId,
      nowMs,
      deliverySource: "eventarc",
    }),
    settleAcceptedRunSession({
      db,
      runSessionId,
      nowMs,
      deliverySource: "repair",
    }),
  ]);

  assert.deepEqual(outcomes.sort(), [
    "already_settled",
    "already_settled",
    "settled",
  ]);
  const canonical = await loadOrCreateCanonicalState({ db, uid });
  assert.equal(canonical.progression.gold, 31);
  assert.equal(canonical.revision, 1);
  assert.deepEqual(canonical.progression.appliedRewardGrantIds, [runSessionId]);
});

test("malformed settlement handoff returns an invariant violation without paying", async () => {
  const runSessionId = await seedRunSession(db, uid, "settlement_pending");
  await db
    .collection("run_sessions")
    .doc(runSessionId)
    .set({ mode: "practice" }, { merge: true });
  await db.collection("validated_runs").doc(runSessionId).set({
    runSessionId,
    uid,
    mode: "practice",
    accepted: true,
    goldEarned: 10,
  });
  await seedRewardGrant(db, runSessionId, {
    uid,
    mode: "practice",
    lifecycleState: "settlement_pending",
    goldAmount: 11,
  });

  const outcome = await settleAcceptedRunSession({ db, runSessionId, nowMs });

  assert.equal(outcome, "invariant_violation");
  const canonical = await loadOrCreateCanonicalState({ db, uid });
  assert.equal(canonical.progression.gold, 0);
  assert.equal(canonical.revision, 0);
  assert.equal(
    (await db.collection("run_sessions").doc(runSessionId).get()).get("state"),
    "settlement_pending",
  );
});

test("settlement overflow is an invariant violation and cannot credit gold", async () => {
  const runSessionId = await seedRunSession(db, uid, "settlement_pending");
  await db
    .collection("run_sessions")
    .doc(runSessionId)
    .set({ mode: "practice" }, { merge: true });
  await db.collection("validated_runs").doc(runSessionId).set({
    runSessionId,
    uid,
    mode: "practice",
    accepted: true,
    goldEarned: 1,
  });
  await seedRewardGrant(db, runSessionId, {
    uid,
    mode: "practice",
    lifecycleState: "settlement_pending",
    goldAmount: 1,
  });
  const initialCanonical = await loadOrCreateCanonicalState({ db, uid });
  const canonicalSnapshot = await db
    .collection("ownership_profiles")
    .where("uid", "==", uid)
    .limit(1)
    .get();
  await canonicalSnapshot.docs[0]!.ref.set(
    {
      progression: {
        ...initialCanonical.progression,
        gold: Number.MAX_SAFE_INTEGER,
      },
    },
    { merge: true },
  );

  const outcome = await settleAcceptedRunSession({ db, runSessionId, nowMs });

  assert.equal(outcome, "invariant_violation");
  const canonical = await loadOrCreateCanonicalState({ db, uid });
  assert.equal(canonical.progression.gold, Number.MAX_SAFE_INTEGER);
  assert.equal(canonical.revision, 0);
  assert.equal(
    (await db.collection("run_sessions").doc(runSessionId).get()).get("state"),
    "settlement_pending",
  );
});

test("legacy migration inventories then repairs settled grants without profile reads", async () => {
  const runSessionId = "legacy_grant_1";
  await seedRewardGrant(db, runSessionId, {
    uid,
    lifecycleState: "validated_settled",
    goldAmount: 19,
    mode: "practice",
  });

  const beforeMigration = await loadOrCreateCanonicalState({ db, uid });
  assert.equal(beforeMigration.progression.gold, 0);

  const inventory = await backfillLegacyRewardGrantStates({
    db,
    options: { mode: "inventory", nowMs },
  });
  assert.equal(inventory.repairedAppliedCount, 1);
  assert.equal((await loadOrCreateCanonicalState({ db, uid })).progression.gold, 0);

  const applied = await backfillLegacyRewardGrantStates({
    db,
    options: { mode: "apply", nowMs: nowMs + 1 },
  });
  assert.equal(applied.repairedAppliedCount, 1);
  const canonical = await loadOrCreateCanonicalState({ db, uid });
  assert.equal(canonical.progression.gold, 19);
  assert.deepEqual(canonical.progression.appliedRewardGrantIds, [runSessionId]);
});

test("legacy migration records an overflow as an invariant without paying", async () => {
  const runSessionId = "legacy_overflow_1";
  await seedRewardGrant(db, runSessionId, {
    uid,
    lifecycleState: "validated_settled",
    goldAmount: 1,
    mode: "practice",
  });
  const initialCanonical = await loadOrCreateCanonicalState({ db, uid });
  const canonicalSnapshot = await db
    .collection("ownership_profiles")
    .where("uid", "==", uid)
    .limit(1)
    .get();
  await canonicalSnapshot.docs[0]!.ref.set(
    {
      progression: {
        ...initialCanonical.progression,
        gold: Number.MAX_SAFE_INTEGER,
      },
    },
    { merge: true },
  );

  const result = await backfillLegacyRewardGrantStates({
    db,
    options: { mode: "apply", nowMs },
  });

  assert.equal(result.invariantViolationCount, 1);
  const canonical = await loadOrCreateCanonicalState({ db, uid });
  assert.equal(canonical.progression.gold, Number.MAX_SAFE_INTEGER);
  assert.equal(canonical.revision, 0);
});

test("accepted board runs enqueue a separate idempotent projection task", async () => {
  const runSessionId = await seedRunSession(db, uid, "settlement_pending");
  await db.collection("run_sessions").doc(runSessionId).set(
    {
      mode: "competitive",
      boardId: "board_competitive_field",
    },
    { merge: true },
  );
  const tasks = new FakeCloudTasksClient();

  const outcome = await enqueueAcceptedRunProjection({
    db,
    runSessionId,
    tasksClient: tasks as unknown as CloudTasksClient,
    config: {
      projectId: "demo-project",
      location: "europe-west1",
      queueName: "replay-projection",
      projectionTaskUrl: "https://validator.example/tasks/project",
      taskDispatchServiceAccount:
        "sa-replay-task-dispatch@demo-project.iam.gserviceaccount.com",
    },
  });

  assert.equal(outcome, "enqueued");
  assert.equal(tasks.requests.length, 1);
  assert.equal(
    tasks.requests[0]?.task?.httpRequest?.url,
    "https://validator.example/tasks/project",
  );
  assert.deepEqual(
    JSON.parse(
      Buffer.from(
        tasks.requests[0]?.task?.httpRequest?.body ?? "",
        "base64",
      ).toString("utf8"),
    ),
    { runSessionId },
  );
});

test("board reconciliation task uses the independent projection endpoint", async () => {
  const tasks = new FakeCloudTasksClient();

  await enqueueBoardProjectionReconciliation({
    boardId: "board_competitive_field",
    taskKey: "cycle-1",
    tasksClient: tasks as unknown as CloudTasksClient,
    config: {
      projectId: "demo-project",
      location: "europe-west1",
      queueName: "replay-projection",
      projectionTaskUrl: "https://validator.example/tasks/project",
      taskDispatchServiceAccount:
        "sa-replay-task-dispatch@demo-project.iam.gserviceaccount.com",
    },
  });

  assert.equal(tasks.requests.length, 1);
  assert.deepEqual(
    JSON.parse(
      Buffer.from(
        tasks.requests[0]?.task?.httpRequest?.body ?? "",
        "base64",
      ).toString("utf8"),
    ),
    { boardId: "board_competitive_field" },
  );
});

test("duplicate board reconciliation task is accepted as idempotent", async () => {
  const duplicateError = Object.assign(new Error("task already exists"), {
    code: 6,
  });
  const tasks = new FakeCloudTasksClient(duplicateError);

  await enqueueBoardProjectionReconciliation({
    boardId: "board_competitive_field",
    taskKey: "cycle-1",
    tasksClient: tasks as unknown as CloudTasksClient,
    config: {
      projectId: "demo-project",
      location: "europe-west1",
      queueName: "replay-projection",
      projectionTaskUrl: "https://validator.example/tasks/project",
      taskDispatchServiceAccount:
        "sa-replay-task-dispatch@demo-project.iam.gserviceaccount.com",
    },
  });

  assert.equal(tasks.requests.length, 0);
});

test("a later reconciliation bucket uses a distinct deterministic task", async () => {
  const tasks = new FakeCloudTasksClient();
  const config = {
    projectId: "demo-project",
    location: "europe-west1",
    queueName: "replay-projection",
    projectionTaskUrl: "https://validator.example/tasks/project",
    taskDispatchServiceAccount:
      "sa-replay-task-dispatch@demo-project.iam.gserviceaccount.com",
  };

  await enqueueBoardProjectionReconciliation({
    boardId: "board_competitive_field",
    taskKey: "cycle-1",
    tasksClient: tasks as unknown as CloudTasksClient,
    config,
  });
  await enqueueBoardProjectionReconciliation({
    boardId: "board_competitive_field",
    taskKey: "cycle-2",
    tasksClient: tasks as unknown as CloudTasksClient,
    config,
  });

  assert.equal(tasks.requests.length, 2);
  assert.notEqual(tasks.requests[0]?.task?.name, tasks.requests[1]?.task?.name);
});

test("projection reconciliation release defaults are hourly and bounded", () => {
  assert.equal(projectionReconciliationSchedule, "every 60 minutes");
  assert.equal(parseProjectionReconciliationBatchSize(undefined), 4);
  assert.equal(parseProjectionReconciliationBatchSize(""), 4);
  assert.equal(parseProjectionReconciliationBatchSize("0"), 4);
  assert.equal(parseProjectionReconciliationBatchSize("-1"), 4);
  assert.equal(parseProjectionReconciliationBatchSize("1.5"), 4);
  assert.equal(parseProjectionReconciliationBatchSize("invalid"), 4);
  assert.equal(parseProjectionReconciliationBatchSize("8"), 8);
  assert.equal(parseProjectionReconciliationBatchSize("1000"), 64);
});

test("scheduled projection reconciliation walks boards through a persisted cursor", async () => {
  await Promise.all(
    ["board_a", "board_b", "board_c"].map((boardId) =>
      db.collection("leaderboard_boards").doc(boardId).set({ boardId }),
    ),
  );
  const enqueued: string[] = [];
  const dispatcher = {
    async enqueue(args: { boardId: string; taskKey: string }): Promise<void> {
      enqueued.push(`${args.boardId}:${args.taskKey}`);
    },
  };

  const first = await reconcileLeaderboardBoardProjections({
    db,
    nowMs,
    batchSize: 2,
    dispatcher,
  });
  const second = await reconcileLeaderboardBoardProjections({
    db,
    nowMs,
    batchSize: 2,
    dispatcher,
  });

  assert.equal(first.completedPage, false);
  assert.equal(first.nextCursor, "board_b");
  assert.equal(first.queriedCount, 3);
  assert.equal(first.selectedCount, 2);
  assert.equal(first.cursorCommitted, true);
  assert.equal(second.completedPage, true);
  assert.equal(second.nextCursor, null);
  assert.equal(second.queriedCount, 1);
  assert.equal(second.selectedCount, 1);
  assert.equal(second.cursorCommitted, true);
  assert.deepEqual(
    enqueued.map((entry) => entry.split(":")[0]),
    ["board_a", "board_b", "board_c"],
  );
});

test("exact-multiple final page wraps without an empty invocation", async () => {
  await Promise.all(
    ["board_a", "board_b", "board_c", "board_d"].map((boardId) =>
      db.collection("leaderboard_boards").doc(boardId).set({ boardId }),
    ),
  );
  const enqueued: string[] = [];
  const dispatcher = {
    async enqueue(args: { boardId: string; taskKey: string }): Promise<void> {
      enqueued.push(args.boardId);
    },
  };

  const first = await reconcileLeaderboardBoardProjections({
    db,
    nowMs,
    batchSize: 2,
    dispatcher,
  });
  const second = await reconcileLeaderboardBoardProjections({
    db,
    nowMs: nowMs + 60 * 60 * 1000,
    batchSize: 2,
    dispatcher,
  });
  const third = await reconcileLeaderboardBoardProjections({
    db,
    nowMs: nowMs + 2 * 60 * 60 * 1000,
    batchSize: 2,
    dispatcher,
  });

  assert.equal(first.queriedCount, 3);
  assert.equal(first.completedPage, false);
  assert.equal(second.queriedCount, 2);
  assert.equal(second.selectedCount, 2);
  assert.equal(second.completedPage, true);
  assert.equal(second.nextCursor, null);
  assert.deepEqual(enqueued, [
    "board_a",
    "board_b",
    "board_c",
    "board_d",
    "board_a",
    "board_b",
  ]);
  assert.equal(third.selectedCount, 2);
});

test("empty reconciliation commits a completed cycle without a task client", async () => {
  const result = await reconcileLeaderboardBoardProjections({
    db,
    nowMs,
    createTasksClient: () => {
      throw new Error("task client must not be created for an empty page");
    },
  });

  assert.equal(result.queriedCount, 0);
  assert.equal(result.selectedCount, 0);
  assert.equal(result.enqueuedCount, 0);
  assert.equal(result.completedPage, true);
  assert.equal(result.nextCursor, null);
  assert.equal(result.cursorCommitted, true);
  assert.equal(result.schedule, "every 60 minutes");
  assert.equal(result.effectiveBatchSize, 4);
  assert.equal(result.retainedBoardCount, 0);
  assert.equal(result.completedCycleDurationMs, 0);
  const state = await db
    .collection("system_maintenance")
    .doc("replay_projection_reconciliation")
    .get();
  assert.equal(state.exists, true);
  assert.equal(state.get("cursor"), null);
});

test("default reconciliation selects four boards and keeps lookahead queued", async () => {
  await Promise.all(
    ["board_a", "board_b", "board_c", "board_d", "board_e"].map((boardId) =>
      db.collection("leaderboard_boards").doc(boardId).set({ boardId }),
    ),
  );
  const enqueued: string[] = [];

  const result = await reconcileLeaderboardBoardProjections({
    db,
    nowMs,
    dispatcher: {
      async enqueue(args: { boardId: string }): Promise<void> {
        enqueued.push(args.boardId);
      },
    },
  });

  assert.equal(result.queriedCount, 5);
  assert.equal(result.selectedCount, 4);
  assert.equal(result.enqueuedCount, 4);
  assert.equal(result.nextCursor, "board_d");
  assert.equal(result.retainedBoardCount, 5);
  assert.deepEqual(enqueued, ["board_a", "board_b", "board_c", "board_d"]);
});

test("96 boards complete and wrap in exactly 24 hourly invocations", async () => {
  const boardIds = Array.from(
    { length: 96 },
    (_, index) => `board_${index.toString().padStart(3, "0")}`,
  );
  await Promise.all(
    boardIds.map((boardId) =>
      db.collection("leaderboard_boards").doc(boardId).set({ boardId }),
    ),
  );
  const enqueued: string[] = [];
  const dispatcher = {
    async enqueue(args: { boardId: string; taskKey: string }): Promise<void> {
      enqueued.push(args.boardId);
    },
  };

  let lastResult;
  for (let invocation = 0; invocation < 24; invocation += 1) {
    lastResult = await reconcileLeaderboardBoardProjections({
      db,
      nowMs: nowMs + invocation * 60 * 60 * 1000,
      batchSize: 4,
      dispatcher,
    });
    assert.equal(lastResult.selectedCount, 4);
    assert.equal(lastResult.cursorCommitted, true);
  }

  assert.equal(lastResult?.completedPage, true);
  assert.equal(lastResult?.nextCursor, null);
  assert.equal(lastResult?.completedCycleDurationMs, 23 * 60 * 60 * 1000);
  assert.equal(enqueued.length, 96);
  assert.equal(new Set(enqueued).size, 96);

  const nextCycle = await reconcileLeaderboardBoardProjections({
    db,
    nowMs: nowMs + 24 * 60 * 60 * 1000,
    batchSize: 4,
    dispatcher,
  });
  assert.equal(nextCycle.selectedCount, 4);
  assert.deepEqual(enqueued.slice(-4), boardIds.slice(0, 4));
});

test("54 boards complete one cycle in 14 hourly invocations", async () => {
  const boardIds = Array.from(
    { length: 54 },
    (_, index) => `board_${index.toString().padStart(3, "0")}`,
  );
  await Promise.all(
    boardIds.map((boardId) =>
      db.collection("leaderboard_boards").doc(boardId).set({ boardId }),
    ),
  );
  const enqueued: string[] = [];
  const dispatcher = {
    async enqueue(args: { boardId: string; taskKey: string }): Promise<void> {
      enqueued.push(args.boardId);
    },
  };

  let lastResult;
  for (let invocation = 0; invocation < 14; invocation += 1) {
    lastResult = await reconcileLeaderboardBoardProjections({
      db,
      nowMs: nowMs + invocation * 60 * 60 * 1000,
      batchSize: 4,
      dispatcher,
    });
  }

  assert.equal(enqueued.length, 54);
  assert.equal(new Set(enqueued).size, 54);
  assert.equal(lastResult?.selectedCount, 2);
  assert.equal(lastResult?.completedPage, true);
  assert.equal(lastResult?.nextCursor, null);
  assert.equal(lastResult?.completedCycleDurationMs, 13 * 60 * 60 * 1000);
});

test("board inserted before the cursor is selected after wrap", async () => {
  await Promise.all(
    ["board_b", "board_c", "board_d"].map((boardId) =>
      db.collection("leaderboard_boards").doc(boardId).set({ boardId }),
    ),
  );
  const enqueued: string[] = [];
  const dispatcher = {
    async enqueue(args: { boardId: string; taskKey: string }): Promise<void> {
      enqueued.push(args.boardId);
    },
  };

  await reconcileLeaderboardBoardProjections({
    db,
    nowMs,
    batchSize: 2,
    dispatcher,
  });
  await db
    .collection("leaderboard_boards")
    .doc("board_a")
    .set({ boardId: "board_a" });
  await reconcileLeaderboardBoardProjections({
    db,
    nowMs: nowMs + 60 * 60 * 1000,
    batchSize: 2,
    dispatcher,
  });
  await reconcileLeaderboardBoardProjections({
    db,
    nowMs: nowMs + 2 * 60 * 60 * 1000,
    batchSize: 2,
    dispatcher,
  });

  assert.deepEqual(enqueued, [
    "board_b",
    "board_c",
    "board_d",
    "board_a",
    "board_b",
  ]);
});

test("stale overlapping reconciliation cannot overwrite newer cursor state", async () => {
  await Promise.all(
    ["board_a", "board_b", "board_c"].map((boardId) =>
      db.collection("leaderboard_boards").doc(boardId).set({ boardId }),
    ),
  );
  const stateRef = db
    .collection("system_maintenance")
    .doc("replay_projection_reconciliation");
  await stateRef.set({ cursor: null, updatedAtMs: nowMs - 1 });
  let replacedState = false;
  const dispatcher = {
    async enqueue(): Promise<void> {
      if (!replacedState) {
        replacedState = true;
        await stateRef.set({ cursor: "board_c", updatedAtMs: nowMs });
      }
    },
  };

  const result = await reconcileLeaderboardBoardProjections({
    db,
    nowMs,
    batchSize: 2,
    dispatcher,
  });

  assert.equal(result.cursorCommitted, false);
  assert.equal(result.nextCursor, "board_b");
  assert.equal(result.completedCycleDurationMs, null);
  const persisted = await stateRef.get();
  assert.equal(persisted.get("cursor"), "board_c");
});

test("scheduled projection reconciliation reuses and closes one task client", async () => {
  await Promise.all(
    ["board_a", "board_b", "board_c"].map((boardId) =>
      db.collection("leaderboard_boards").doc(boardId).set({ boardId }),
    ),
  );
  const tasks = new FakeCloudTasksClient();
  let clientCreateCount = 0;

  const result = await reconcileLeaderboardBoardProjections({
    db,
    nowMs,
    batchSize: 3,
    createTasksClient: () => {
      clientCreateCount += 1;
      return tasks as unknown as CloudTasksClient;
    },
  });

  assert.equal(result.enqueuedCount, 3);
  assert.equal(clientCreateCount, 1);
  assert.equal(tasks.requests.length, 3);
  assert.equal(tasks.closeCount, 1);
});

test("projection reconciliation does not advance its cursor after enqueue failure", async () => {
  await db
    .collection("leaderboard_boards")
    .doc("board_failure")
    .set({ boardId: "board_failure" });
  const tasks = new FakeCloudTasksClient(new Error("queue unavailable"));

  await assert.rejects(
    () =>
      reconcileLeaderboardBoardProjections({
        db,
        nowMs,
        createTasksClient: () => tasks as unknown as CloudTasksClient,
      }),
    /queue unavailable/u,
  );
  assert.equal(tasks.closeCount, 1);

  const state = await db
    .collection("system_maintenance")
    .doc("replay_projection_reconciliation")
    .get();
  assert.equal(state.exists, false);
});

test("reward projection: revocation_visible grant → revoked reward with zero deltas", async () => {
  const runSessionId = await seedRunSession(db, uid, "rejected");
  await seedRewardGrant(db, runSessionId, {
    uid,
    lifecycleState: "revocation_visible",
    goldAmount: 20,
    settlementReason: "replay_invalid",
  });

  const result = await loadRunSessionSubmissionStatus({
    db,
    uid,
    runSessionId,
  });

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

  const result = await loadRunSessionSubmissionStatus({
    db,
    uid,
    runSessionId,
  });

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

  const result = await loadRunSessionSubmissionStatus({
    db,
    uid,
    runSessionId,
  });

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

  const result = await loadRunSessionSubmissionStatus({
    db,
    uid,
    runSessionId,
  });

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

  const result = await loadRunSessionSubmissionStatus({
    db,
    uid,
    runSessionId,
  });

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
  await dbValue
    .collection("run_sessions")
    .doc(runSessionId)
    .set({
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
  await dbValue
    .collection("reward_grants")
    .doc(runSessionId)
    .set({
      runSessionId,
      updatedAtMs: nowMs,
      createdAtMs: nowMs,
      ...fields,
    });
}

async function clearCollection(
  dbValue: Firestore,
  name: string,
): Promise<void> {
  const docs = await dbValue.collection(name).listDocuments();
  await Promise.all(docs.map((docRef) => dbValue.recursiveDelete(docRef)));
}

interface ProjectionTaskRequest {
  task?: {
    name?: string;
    httpRequest?: {
      url?: string;
      body?: string;
    };
  };
}

class FakeCloudTasksClient {
  readonly requests: ProjectionTaskRequest[] = [];
  closeCount = 0;

  constructor(private readonly createTaskError?: Error) {}

  queuePath(projectId: string, location: string, queueName: string): string {
    return `projects/${projectId}/locations/${location}/queues/${queueName}`;
  }

  taskPath(
    projectId: string,
    location: string,
    queueName: string,
    taskId: string,
  ): string {
    return `${this.queuePath(projectId, location, queueName)}/tasks/${taskId}`;
  }

  async createTask(request: ProjectionTaskRequest): Promise<void> {
    if (this.createTaskError) {
      throw this.createTaskError;
    }
    this.requests.push(request);
  }

  async close(): Promise<void> {
    this.closeCount += 1;
  }
}
