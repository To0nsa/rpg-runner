import assert from "node:assert/strict";
import { after, beforeEach, test } from "node:test";

import { deleteApp, getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, type Firestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

import { loadOrCreateCanonicalState } from "../../src/ownership/canonical_store.js";
import {
  handleRunSessionCreateUploadGrant,
  handleRunSessionFinalizeUpload,
  handleRunSessionLoadStatus,
} from "../../src/runs/callable_handlers.js";
import { runReplaySubmissionCleanup } from "../../src/runs/cleanup.js";
import { defaultValidationRepairStaleThresholdMs } from "../../src/runs/session_state.js";
import { createRunSession } from "../../src/runs/store.js";
import {
  createRunSessionUploadGrant,
  type RunSubmissionDependencies,
} from "../../src/runs/submission_store.js";

const firestoreEmulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
if (!firestoreEmulatorHost) {
  throw new Error(
    "FIRESTORE_EMULATOR_HOST is not set. Run via `firebase emulators:exec`.",
  );
}

const emulatorProjectIdBase =
  process.env.GCLOUD_PROJECT ?? "demo-rpg-runner-functions-tests";
const projectId = `${emulatorProjectIdBase}-run-submissions`;
const appName = `run-submission-tests-${process.pid}-${Date.now()}`;
const app = initializeApp({ projectId }, appName);
const db = getFirestore(app);

const uid = "uid_run_submission_owner";

beforeEach(async () => {
  await Promise.all([
    clearCollection(db, "ownership_profiles"),
    clearCollection(db, "run_sessions"),
    clearCollection(db, "validated_runs"),
    clearCollection(db, "reward_grants"),
    clearCollection(db, "abuse_quota"),
    clearCollection(db, "account_deletion_requests"),
  ]);
});

after(async () => {
  await Promise.all(getApps().map((value) => deleteApp(value)));
});

test("active upload grant enforcement is atomic when configured", async () => {
  const deps = new FakeRunSubmissionDependencies();
  const firstRunSessionId = await createPracticeRunSession(db, uid);
  const secondRunSessionId = await createPracticeRunSession(db, uid);
  const previousMode = process.env.ABUSE_CONTROL_MODE;
  const previousLimit = process.env.ABUSE_RUN_ACTIVE_UPLOAD_GRANTS_LIMIT;
  process.env.ABUSE_CONTROL_MODE = "enforce";
  process.env.ABUSE_RUN_ACTIVE_UPLOAD_GRANTS_LIMIT = "1";
  try {
    await createRunSessionUploadGrant({
      db,
      uid,
      runSessionId: firstRunSessionId,
      dependencies: deps,
    });
    await assert.rejects(
      () =>
        createRunSessionUploadGrant({
          db,
          uid,
          runSessionId: secondRunSessionId,
          dependencies: deps,
        }),
      (error: { code?: string }) => error.code === "resource-exhausted",
    );
    assert.equal(deps.objectStore.issuedObjectPaths.length, 1);
  } finally {
    restoreEnv("ABUSE_CONTROL_MODE", previousMode);
    restoreEnv("ABUSE_RUN_ACTIVE_UPLOAD_GRANTS_LIMIT", previousLimit);
  }
});

test("upload grant + finalize moves run session to pending_validation and enqueues exactly once", async () => {
  const deps = new FakeRunSubmissionDependencies();
  const runSessionId = await createPracticeRunSession(db, uid);

  const grantResponse = await handleRunSessionCreateUploadGrant(
    callableRequest(
      {
        userId: uid,
        sessionId: "session_1",
        runSessionId,
      },
      uid,
    ),
    db,
    deps,
  );
  const uploadGrant = grantResponse.uploadGrant;
  const objectPath = String(uploadGrant.objectPath);
  deps.objectStore.setObjectMetadata(objectPath, {
    contentLengthBytes: 2048,
    contentType: "application/octet-stream",
    generation: "1",
  });

  const finalizeResponse = await handleRunSessionFinalizeUpload(
    callableRequest(
      {
        userId: uid,
        sessionId: "session_1",
        runSessionId,
        canonicalSha256:
          "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        contentLengthBytes: 2048,
        contentType: "application/octet-stream",
        objectPath,
      },
      uid,
    ),
    db,
    deps,
  );

  assert.equal(finalizeResponse.submissionStatus.state, "pending_validation");
  assert.equal(deps.taskDispatcher.enqueuedRunSessionIds.length, 1);
  assert.equal(deps.taskDispatcher.enqueuedRunSessionIds[0], runSessionId);

  const persisted = await db.collection("run_sessions").doc(runSessionId).get();
  assert.equal(persisted.get("state"), "pending_validation");
  assert.equal(persisted.get("uploadedReplay.objectPath"), objectPath);
  assert.equal(
    persisted.get("uploadedReplay.canonicalSha256"),
    "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  );
  assert.equal(persisted.get("uploadedReplay.storageGeneration"), "1");
  const validationLastEnqueuedAtMs = persisted.get(
    "validationLastEnqueuedAtMs",
  ) as number;
  assert.equal(persisted.get("validationTaskGeneration"), 0);
  assert.equal(
    persisted.get("validationNextAttemptAtMs"),
    validationLastEnqueuedAtMs + defaultValidationRepairStaleThresholdMs,
  );

  const rewardGrant = await db.collection("reward_grants").doc(runSessionId).get();
  assert.equal(rewardGrant.exists, true);
  assert.equal(rewardGrant.get("runSessionId"), runSessionId);
  assert.equal(rewardGrant.get("uid"), uid);
  assert.equal(rewardGrant.get("mode"), "practice");
  assert.equal(rewardGrant.get("boardId"), undefined);
  assert.equal(rewardGrant.get("boardKey"), undefined);
  assert.equal(rewardGrant.get("lifecycleState"), "provisional_created");
  assert.equal(rewardGrant.get("goldAmount"), 0);
});

test("finalize is idempotent for same replay metadata", async () => {
  const deps = new FakeRunSubmissionDependencies();
  const runSessionId = await createPracticeRunSession(db, uid);
  const objectPath = `replay-submissions/pending/${uid}/${runSessionId}/replay.bin.gz`;

  await handleRunSessionCreateUploadGrant(
    callableRequest(
      {
        userId: uid,
        sessionId: "session_1",
        runSessionId,
      },
      uid,
    ),
    db,
    deps,
  );
  deps.objectStore.setObjectMetadata(objectPath, {
    contentLengthBytes: 4096,
    contentType: "application/octet-stream",
    generation: "2",
  });

  const payload = {
    userId: uid,
    sessionId: "session_1",
    runSessionId,
    canonicalSha256:
      "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
    contentLengthBytes: 4096,
    contentType: "application/octet-stream",
    objectPath,
  };
  const first = await handleRunSessionFinalizeUpload(callableRequest(payload, uid), db, deps);
  const second = await handleRunSessionFinalizeUpload(callableRequest(payload, uid), db, deps);

  assert.equal(first.submissionStatus.state, "pending_validation");
  assert.equal(second.submissionStatus.state, "pending_validation");
  assert.equal(deps.taskDispatcher.enqueuedRunSessionIds.length, 1);
});

test("finalize rejects an overwritten object generation", async () => {
  const deps = new FakeRunSubmissionDependencies();
  const runSessionId = await createPracticeRunSession(db, uid);
  const objectPath = `replay-submissions/pending/${uid}/${runSessionId}/replay.bin.gz`;
  await handleRunSessionCreateUploadGrant(
    callableRequest(
      {
        userId: uid,
        sessionId: "session_1",
        runSessionId,
      },
      uid,
    ),
    db,
    deps,
  );
  deps.objectStore.setObjectMetadata(objectPath, {
    contentLengthBytes: 4096,
    contentType: "application/octet-stream",
    generation: "10",
  });
  const payload = {
    userId: uid,
    sessionId: "session_1",
    runSessionId,
    canonicalSha256:
      "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
    contentLengthBytes: 4096,
    contentType: "application/octet-stream",
    objectPath,
  };
  await handleRunSessionFinalizeUpload(callableRequest(payload, uid), db, deps);

  deps.objectStore.setObjectMetadata(objectPath, {
    contentLengthBytes: 4096,
    contentType: "application/octet-stream",
    generation: "11",
  });

  await assert.rejects(
    () =>
      handleRunSessionFinalizeUpload(
        callableRequest(payload, uid),
        db,
        deps,
      ),
    (error: { code?: string }) => error.code === "already-exists",
  );
});

test("finalize skips provisional reward grant creation when rollout flag is disabled", async () => {
  const previous = process.env.RUN_REWARD_PROVISIONAL_CREATE_ENABLED;
  process.env.RUN_REWARD_PROVISIONAL_CREATE_ENABLED = "false";
  try {
    const deps = new FakeRunSubmissionDependencies();
    const runSessionId = await createPracticeRunSession(db, uid);
    const objectPath = `replay-submissions/pending/${uid}/${runSessionId}/replay.bin.gz`;

    await handleRunSessionCreateUploadGrant(
      callableRequest(
        {
          userId: uid,
          sessionId: "session_1",
          runSessionId,
        },
        uid,
      ),
      db,
      deps,
    );
    deps.objectStore.setObjectMetadata(objectPath, {
      contentLengthBytes: 2048,
      contentType: "application/octet-stream",
      generation: "5",
    });

    const response = await handleRunSessionFinalizeUpload(
      callableRequest(
        {
          userId: uid,
          sessionId: "session_1",
          runSessionId,
          canonicalSha256:
            "abababababababababababababababababababababababababababababababab",
          contentLengthBytes: 2048,
          contentType: "application/octet-stream",
          objectPath,
          provisionalSummary: { goldEarned: 25 },
        },
        uid,
      ),
      db,
      deps,
    );

    assert.equal(response.submissionStatus.state, "pending_validation");
    const rewardGrant = await db.collection("reward_grants").doc(runSessionId).get();
    assert.equal(rewardGrant.exists, false);
  } finally {
    if (previous == null) {
      delete process.env.RUN_REWARD_PROVISIONAL_CREATE_ENABLED;
    } else {
      process.env.RUN_REWARD_PROVISIONAL_CREATE_ENABLED = previous;
    }
  }
});

test("finalize rejects conflicting metadata re-finalize", async () => {
  const deps = new FakeRunSubmissionDependencies();
  const runSessionId = await createPracticeRunSession(db, uid);
  const objectPath = `replay-submissions/pending/${uid}/${runSessionId}/replay.bin.gz`;

  await handleRunSessionCreateUploadGrant(
    callableRequest(
      {
        userId: uid,
        sessionId: "session_1",
        runSessionId,
      },
      uid,
    ),
    db,
    deps,
  );
  deps.objectStore.setObjectMetadata(objectPath, {
    contentLengthBytes: 3000,
    contentType: "application/octet-stream",
    generation: "3",
  });

  await handleRunSessionFinalizeUpload(
    callableRequest(
      {
        userId: uid,
        sessionId: "session_1",
        runSessionId,
        canonicalSha256:
          "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
        contentLengthBytes: 3000,
        contentType: "application/octet-stream",
        objectPath,
      },
      uid,
    ),
    db,
    deps,
  );

  await assert.rejects(
    () =>
      handleRunSessionFinalizeUpload(
        callableRequest(
          {
            userId: uid,
            sessionId: "session_1",
            runSessionId,
            canonicalSha256:
              "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
            contentLengthBytes: 3000,
            contentType: "application/octet-stream",
            objectPath,
          },
          uid,
        ),
        db,
        deps,
      ),
    (error: { code?: string }) => error.code === "already-exists",
  );
});

test("finalize enqueue failure leaves session uploaded for safe retry", async () => {
  const deps = new FakeRunSubmissionDependencies();
  deps.taskDispatcher.shouldFailEnqueue = true;
  const runSessionId = await createPracticeRunSession(db, uid);
  const objectPath = `replay-submissions/pending/${uid}/${runSessionId}/replay.bin.gz`;

  await handleRunSessionCreateUploadGrant(
    callableRequest(
      {
        userId: uid,
        sessionId: "session_1",
        runSessionId,
      },
      uid,
    ),
    db,
    deps,
  );
  deps.objectStore.setObjectMetadata(objectPath, {
    contentLengthBytes: 1800,
    contentType: "application/octet-stream",
    generation: "4",
  });

  await assert.rejects(
    () =>
      handleRunSessionFinalizeUpload(
        callableRequest(
          {
            userId: uid,
            sessionId: "session_1",
            runSessionId,
            canonicalSha256:
              "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
            contentLengthBytes: 1800,
            contentType: "application/octet-stream",
            objectPath,
          },
          uid,
        ),
        db,
        deps,
      ),
    (error: { code?: string }) => error.code === "unavailable",
  );

  const uploaded = await handleRunSessionLoadStatus(
    callableRequest(
      {
        userId: uid,
        sessionId: "session_1",
        runSessionId,
      },
      uid,
    ),
    db,
  );
  assert.equal(uploaded.submissionStatus.state, "uploaded");

  deps.taskDispatcher.shouldFailEnqueue = false;
  const retried = await handleRunSessionFinalizeUpload(
    callableRequest(
      {
        userId: uid,
        sessionId: "session_1",
        runSessionId,
        canonicalSha256:
          "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
        contentLengthBytes: 1800,
        contentType: "application/octet-stream",
        objectPath,
      },
      uid,
    ),
    db,
    deps,
  );
  assert.equal(retried.submissionStatus.state, "pending_validation");
});

test("upload-grant expiry commits terminal state before returning an error", async () => {
  const deps = new FakeRunSubmissionDependencies();
  const runSessionId = await createPracticeRunSession(db, uid);
  const expiryMs = 1_700_000_000_000;
  await db.collection("run_sessions").doc(runSessionId).set(
    { expiresAtMs: expiryMs - 1 },
    { merge: true },
  );

  await assert.rejects(
    () =>
      handleRunSessionCreateUploadGrant(
        callableRequest(
          {
            userId: uid,
            sessionId: "session_1",
            runSessionId,
          },
          uid,
        ),
        db,
        deps,
        () => expiryMs,
      ),
    (error: { code?: string }) => error.code === "failed-precondition",
  );

  const expired = await db.collection("run_sessions").doc(runSessionId).get();
  assert.equal(expired.get("state"), "expired");
  assert.equal(expired.get("updatedAtMs"), expiryMs);
  assert.equal(expired.get("terminalAtMs"), expiryMs);
  assert.equal(expired.get("expiredAtMs"), expiryMs);
  assert.equal(
    expired.get("message"),
    "Run session expired before upload grant issuance.",
  );

  await assert.rejects(
    () =>
      handleRunSessionCreateUploadGrant(
        callableRequest(
          {
            userId: uid,
            sessionId: "session_1",
            runSessionId,
          },
          uid,
        ),
        db,
        deps,
        () => expiryMs + 1,
      ),
    (error: { code?: string }) => error.code === "failed-precondition",
  );
  const repeated = await db.collection("run_sessions").doc(runSessionId).get();
  assert.equal(repeated.get("expiredAtMs"), expiryMs);
});

test("finalize expiry commits and revokes a provisional grant atomically", async () => {
  const deps = new FakeRunSubmissionDependencies();
  const runSessionId = await createPracticeRunSession(db, uid);
  const expiryMs = 1_700_000_000_000;
  const objectPath =
    `replay-submissions/pending/${uid}/${runSessionId}/replay.bin.gz`;
  await db.collection("run_sessions").doc(runSessionId).set(
    {
      state: "uploaded",
      expiresAtMs: expiryMs - 1,
    },
    { merge: true },
  );
  await db.collection("reward_grants").doc(runSessionId).set({
    runSessionId,
    uid,
    mode: "practice",
    lifecycleState: "provisional_created",
    goldAmount: 31,
    createdAtMs: expiryMs - 10,
    updatedAtMs: expiryMs - 10,
  });
  deps.objectStore.setObjectMetadata(objectPath, {
    contentLengthBytes: 1800,
    contentType: "application/octet-stream",
    generation: "7",
  });

  await assert.rejects(
    () =>
      handleRunSessionFinalizeUpload(
        callableRequest(
          {
            userId: uid,
            sessionId: "session_1",
            runSessionId,
            canonicalSha256:
              "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
            contentLengthBytes: 1800,
            contentType: "application/octet-stream",
            objectPath,
          },
          uid,
        ),
        db,
        deps,
        () => expiryMs,
      ),
    (error: { code?: string }) => error.code === "failed-precondition",
  );

  const [session, rewardGrant] = await Promise.all([
    db.collection("run_sessions").doc(runSessionId).get(),
    db.collection("reward_grants").doc(runSessionId).get(),
  ]);
  assert.equal(session.get("state"), "expired");
  assert.equal(session.get("expiredAtMs"), expiryMs);
  assert.equal(rewardGrant.get("lifecycleState"), "revoked_final");
  assert.equal(rewardGrant.get("settlementReason"), "run_session_expired");
  assert.equal(rewardGrant.get("revokedAtMs"), expiryMs);
  assert.equal(deps.taskDispatcher.enqueuedRunSessionIds.length, 0);
});

test("enqueue failure followed by cleanup expires and revokes the grant", async () => {
  const deps = new FakeRunSubmissionDependencies();
  deps.taskDispatcher.shouldFailEnqueue = true;
  const runSessionId = await createPracticeRunSession(db, uid);
  const objectPath =
    `replay-submissions/pending/${uid}/${runSessionId}/replay.bin.gz`;
  await handleRunSessionCreateUploadGrant(
    callableRequest(
      {
        userId: uid,
        sessionId: "session_1",
        runSessionId,
      },
      uid,
    ),
    db,
    deps,
  );
  deps.objectStore.setObjectMetadata(objectPath, {
    contentLengthBytes: 1800,
    contentType: "application/octet-stream",
    generation: "8",
  });
  await assert.rejects(
    () =>
      handleRunSessionFinalizeUpload(
        callableRequest(
          {
            userId: uid,
            sessionId: "session_1",
            runSessionId,
            canonicalSha256:
              "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
            contentLengthBytes: 1800,
            contentType: "application/octet-stream",
            objectPath,
            provisionalSummary: { goldEarned: 37 },
          },
          uid,
        ),
        db,
        deps,
      ),
    (error: { code?: string }) => error.code === "unavailable",
  );
  const uploaded = await db.collection("run_sessions").doc(runSessionId).get();
  const expiresAtMs = uploaded.get("expiresAtMs") as number;
  assert.equal(uploaded.get("state"), "uploaded");
  assert.equal(
    (await db.collection("reward_grants").doc(runSessionId).get()).get(
      "lifecycleState",
    ),
    "provisional_created",
  );

  const firstCleanup = await runReplaySubmissionCleanup({
    db,
    nowMs: expiresAtMs,
    dependencies: {},
  });
  assert.equal(firstCleanup.expiredSessionCount, 1);
  const revokedAtMs = (
    await db.collection("reward_grants").doc(runSessionId).get()
  ).get("revokedAtMs");
  const repeatedCleanup = await runReplaySubmissionCleanup({
    db,
    nowMs: expiresAtMs + 1,
    dependencies: {},
  });
  assert.equal(repeatedCleanup.expiredSessionCount, 0);
  assert.equal(
    (
      await db.collection("reward_grants").doc(runSessionId).get()
    ).get("revokedAtMs"),
    revokedAtMs,
  );

  const status = await handleRunSessionLoadStatus(
    callableRequest(
      {
        userId: uid,
        sessionId: "session_1",
        runSessionId,
      },
      uid,
    ),
    db,
  );
  assert.equal(status.submissionStatus.state, "expired");
  const reward = status.submissionStatus.reward as
    | Record<string, unknown>
    | undefined;
  assert.equal(reward?.status, "revoked");
  assert.equal(reward?.provisionalGold, 37);
});

test("terminal sessions never project an incompatible provisional reward", async () => {
  const runSessionId = await createPracticeRunSession(db, uid);
  await db.collection("run_sessions").doc(runSessionId).set(
    {
      state: "expired",
      updatedAtMs: 1_700_000_000_000,
      terminalAtMs: 1_700_000_000_000,
    },
    { merge: true },
  );
  await db.collection("reward_grants").doc(runSessionId).set({
    runSessionId,
    uid,
    mode: "practice",
    lifecycleState: "provisional_created",
    goldAmount: 41,
    updatedAtMs: 1_699_999_999_000,
  });

  const status = await handleRunSessionLoadStatus(
    callableRequest(
      {
        userId: uid,
        sessionId: "session_1",
        runSessionId,
      },
      uid,
    ),
    db,
  );

  assert.equal(status.submissionStatus.state, "expired");
  assert.equal(status.submissionStatus.reward, undefined);
});

test("finalize racing cleanup converges on one expired terminal state", async () => {
  const deps = new FakeRunSubmissionDependencies();
  const runSessionId = await createPracticeRunSession(db, uid);
  const expiryMs = 1_700_000_000_000;
  const objectPath =
    `replay-submissions/pending/${uid}/${runSessionId}/replay.bin.gz`;
  await db.collection("run_sessions").doc(runSessionId).set(
    {
      state: "uploaded",
      expiresAtMs: expiryMs,
    },
    { merge: true },
  );
  await db.collection("reward_grants").doc(runSessionId).set({
    runSessionId,
    uid,
    mode: "practice",
    lifecycleState: "provisional_created",
    goldAmount: 43,
    createdAtMs: expiryMs - 10,
    updatedAtMs: expiryMs - 10,
  });
  deps.objectStore.setObjectMetadata(objectPath, {
    contentLengthBytes: 1800,
    contentType: "application/octet-stream",
    generation: "9",
  });

  const [finalizeResult, cleanupResult] = await Promise.allSettled([
    handleRunSessionFinalizeUpload(
      callableRequest(
        {
          userId: uid,
          sessionId: "session_1",
          runSessionId,
          canonicalSha256:
            "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
          contentLengthBytes: 1800,
          contentType: "application/octet-stream",
          objectPath,
        },
        uid,
      ),
      db,
      deps,
      () => expiryMs,
    ),
    runReplaySubmissionCleanup({
      db,
      nowMs: expiryMs,
      dependencies: {},
    }),
  ]);

  assert.equal(finalizeResult.status, "rejected");
  assert.equal(cleanupResult.status, "fulfilled");
  const [session, rewardGrant] = await Promise.all([
    db.collection("run_sessions").doc(runSessionId).get(),
    db.collection("reward_grants").doc(runSessionId).get(),
  ]);
  assert.equal(session.get("state"), "expired");
  assert.equal(rewardGrant.get("lifecycleState"), "revoked_final");
  assert.equal(deps.taskDispatcher.enqueuedRunSessionIds.length, 0);
});

test("load status returns validatedRun payload for terminal validated session", async () => {
  const runSessionId = await createPracticeRunSession(db, uid);
  await db.collection("run_sessions").doc(runSessionId).set(
    {
      state: "validated",
      updatedAtMs: 1700000000001,
    },
    { merge: true },
  );
  await db.collection("validated_runs").doc(runSessionId).set({
    runSessionId,
    uid,
    mode: "practice",
    accepted: true,
    score: 1234,
    distanceMeters: 111,
    durationSeconds: 22,
    tick: 330,
    endedReason: "playerDied",
    goldEarned: 17,
    stats: { collectibles: 2 },
    replayDigest:
      "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    replayStorageRef: "replay-submissions/validated/run.bin.gz",
    createdAtMs: 1700000000000,
  });

  const statusResponse = await handleRunSessionLoadStatus(
    callableRequest(
      {
        userId: uid,
        sessionId: "session_1",
        runSessionId,
      },
      uid,
    ),
    db,
  );

  assert.equal(statusResponse.submissionStatus.state, "validated");
  const validatedRun = statusResponse.submissionStatus.validatedRun as
    | Record<string, unknown>
    | undefined;
  assert.ok(validatedRun);
  assert.equal(validatedRun?.runSessionId, runSessionId);
  assert.equal(validatedRun?.goldEarned, 17);
});

async function createPracticeRunSession(
  dbValue: Firestore,
  ownerUid: string,
): Promise<string> {
  await loadOrCreateCanonicalState({ db: dbValue, uid: ownerUid });
  const result = await createRunSession({
    db: dbValue,
    uid: ownerUid,
    mode: "practice",
    levelId: "field",
    gameCompatVersion: "build-2026-03-12",
  });
  return String(result.runTicket.runSessionId);
}

function callableRequest(
  data: Record<string, unknown>,
  authUid?: string,
): { auth?: { uid?: string } | null; data: unknown } {
  if (!authUid) {
    return { data };
  }
  return {
    data,
    auth: { uid: authUid },
  };
}

class FakeRunSubmissionDependencies implements RunSubmissionDependencies {
  readonly objectStore = new FakeReplaySubmissionObjectStore();
  readonly taskDispatcher = new FakeRunValidationTaskDispatcher();
}

class FakeReplaySubmissionObjectStore {
  readonly issuedObjectPaths: string[] = [];
  private readonly metadataByPath = new Map<string, {
    contentLengthBytes: number;
    contentType?: string;
    generation: string;
  }>();

  async issueUploadGrant(args: {
    objectPath: string;
    contentType: string;
    expiresAtMs: number;
  }): Promise<{ uploadUrl: string; uploadMethod: "PUT" }> {
    this.issuedObjectPaths.push(args.objectPath);
    return {
      uploadUrl: `https://upload.invalid/${encodeURIComponent(args.objectPath)}?exp=${args.expiresAtMs}`,
      uploadMethod: "PUT",
    };
  }

  async loadMetadata(args: {
    objectPath: string;
  }): Promise<{ contentLengthBytes: number; contentType?: string; generation: string }> {
    const found = this.metadataByPath.get(args.objectPath);
    if (!found) {
      throw new HttpsError(
        "failed-precondition",
        "Uploaded replay blob not found at canonical object path.",
      );
    }
    return found;
  }

  setObjectMetadata(
    objectPath: string,
    metadata: { contentLengthBytes: number; contentType?: string; generation: string },
  ): void {
    this.metadataByPath.set(objectPath, metadata);
  }
}

class FakeRunValidationTaskDispatcher {
  readonly enqueuedRunSessionIds: string[] = [];
  shouldFailEnqueue = false;

  async enqueueRunValidationTask(args: { runSessionId: string }): Promise<void> {
    this.enqueuedRunSessionIds.push(args.runSessionId);
    if (this.shouldFailEnqueue) {
      throw new Error("simulated enqueue failure");
    }
  }
}

async function clearCollection(dbValue: Firestore, name: string): Promise<void> {
  const docs = await dbValue.collection(name).listDocuments();
  await Promise.all(docs.map((docRef) => dbValue.recursiveDelete(docRef)));
}

function restoreEnv(name: string, value: string | undefined): void {
  if (value === undefined) {
    delete process.env[name];
    return;
  }
  process.env[name] = value;
}
