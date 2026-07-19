import assert from "node:assert/strict";
import { after, beforeEach, test } from "node:test";

import { deleteApp, getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, type Firestore } from "firebase-admin/firestore";
import type { CloudTasksClient } from "@google-cloud/tasks";

import { loadOrCreateCanonicalState } from "../../src/ownership/canonical_store.js";
import {
  ImmediateSettlementDispatchRequestError,
  dispatchImmediateSettlement,
} from "../../src/runs/immediate_settlement_dispatch.js";
import { backfillLegacyRewardGrantStates } from "../../src/runs/reward_grant_backfill.js";
import {
  enqueueAcceptedRunProjection,
  enqueueBoardProjectionReconciliation,
} from "../../src/runs/projection_dispatch.js";
import { reconcileLeaderboardBoardProjections } from "../../src/runs/projection_reconciliation.js";
import { settleAcceptedRunSession } from "../../src/runs/reward_settlement.js";
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

beforeEach(async () => {
  await Promise.all([
    clearCollection(db, "run_sessions"),
    clearCollection(db, "reward_grants"),
    clearCollection(db, "validated_runs"),
    clearCollection(db, "ownership_profiles"),
    clearCollection(db, "system_maintenance"),
    clearCollection(db, "leaderboard_boards"),
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
  assert.equal(canonical.revision, 1);
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
  assert.equal(canonicalAfterRetry.progression.gold, 75);
  assert.equal(canonicalAfterRetry.revision, 1);
  const grantAfterCanonicalReads = await db
    .collection("reward_grants")
    .doc(runSessionId)
    .get();
  assert.equal(grantAfterCanonicalReads.get("appliedAtMs"), nowMs);
  assert.equal(grantAfterCanonicalReads.get("updatedAtMs"), nowMs);
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
  assert.equal(second.completedPage, true);
  assert.equal(second.nextCursor, null);
  assert.deepEqual(
    enqueued.map((entry) => entry.split(":")[0]),
    ["board_a", "board_b", "board_c"],
  );
});

test("projection reconciliation does not advance its cursor after enqueue failure", async () => {
  await db
    .collection("leaderboard_boards")
    .doc("board_failure")
    .set({ boardId: "board_failure" });

  await assert.rejects(
    () =>
      reconcileLeaderboardBoardProjections({
        db,
        nowMs,
        dispatcher: {
          async enqueue(): Promise<void> {
            throw new Error("queue unavailable");
          },
        },
      }),
    /queue unavailable/u,
  );

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
    httpRequest?: {
      url?: string;
      body?: string;
    };
  };
}

class FakeCloudTasksClient {
  readonly requests: ProjectionTaskRequest[] = [];

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
    this.requests.push(request);
  }
}
