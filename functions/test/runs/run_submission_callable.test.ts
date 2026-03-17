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
import { createRunSession } from "../../src/runs/store.js";
import type { RunSubmissionDependencies } from "../../src/runs/submission_store.js";

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
  ]);
});

after(async () => {
  await Promise.all(getApps().map((value) => deleteApp(value)));
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
      generation: "rollout-off",
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
  private readonly metadataByPath = new Map<string, {
    contentLengthBytes: number;
    contentType?: string;
    generation?: string;
  }>();

  async issueUploadGrant(args: {
    objectPath: string;
    contentType: string;
    expiresAtMs: number;
  }): Promise<{ uploadUrl: string; uploadMethod: "PUT" }> {
    return {
      uploadUrl: `https://upload.invalid/${encodeURIComponent(args.objectPath)}?exp=${args.expiresAtMs}`,
      uploadMethod: "PUT",
    };
  }

  async loadMetadata(args: {
    objectPath: string;
  }): Promise<{ contentLengthBytes: number; contentType?: string; generation?: string }> {
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
    metadata: { contentLengthBytes: number; contentType?: string; generation?: string },
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
