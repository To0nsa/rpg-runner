import assert from "node:assert/strict";
import { after, beforeEach, test } from "node:test";

import { deleteApp, getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, type Firestore } from "firebase-admin/firestore";

import {
  accountDeletionStages,
  accountDeletionCompletionRetentionMs,
  type AccountDeletionAuth,
  type AccountDeletionDependencies,
  processAccountDeletion,
  processPendingAccountDeletions,
  type ReplayArtifactStore,
  requestAccountDeletion,
} from "../../src/account/delete.js";
import { assertAccountActive } from "../../src/account/deletion_guard.js";
import { parseAccountDeleteRequest } from "../../src/account/validators.js";
import { loadOrCreateCanonicalState } from "../../src/ownership/canonical_store.js";
import {
  loadOrCreatePlayerProfile,
  updatePlayerProfile,
} from "../../src/profile/store.js";

const firestoreEmulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
if (!firestoreEmulatorHost) {
  throw new Error(
    "FIRESTORE_EMULATOR_HOST is not set. Run via `firebase emulators:exec`.",
  );
}

const emulatorProjectIdBase =
  process.env.GCLOUD_PROJECT ?? "demo-rpg-runner-functions-tests";
const projectId = `${emulatorProjectIdBase}-account`;
const appName = `account-delete-tests-${process.pid}-${Date.now()}`;
const app = initializeApp({ projectId }, appName);
const db = getFirestore(app);

const requestNowMs = 1_000;
const afterUploadLeaseMs = requestNowMs + 15 * 60 * 1000 + 1;

beforeEach(async () => {
  await Promise.all(
    [
      "account_deletion_requests",
      "abuse_quota",
      "ownership_profiles",
      "player_profiles",
      "display_name_index",
      "ghost_runs",
      "leaderboard_ghost_runs",
      "weekly_ghost_runs",
      "leaderboard_boards",
      "run_sessions",
      "validated_runs",
      "reward_grants",
    ].map((collection) => clearCollection(db, collection)),
  );
});

after(async () => {
  await Promise.all(getApps().map((value) => deleteApp(value)));
});

test("parseAccountDeleteRequest validates required fields", () => {
  const parsed = parseAccountDeleteRequest({
    userId: "u1",
    sessionId: "s1",
  });
  assert.equal(parsed.userId, "u1");
  assert.equal(parsed.sessionId, "s1");
});

test("request creates tombstone before disabling auth and blocks lazy creation", async () => {
  const uid = "uid_tombstone";
  const auth = new InMemoryAccountDeletionAuth();
  const dependencies = deletionDependencies(auth);

  const result = await requestAccountDeletion({
    db,
    uid,
    nowMs: requestNowMs,
    dependencies,
  });

  assert.equal(result.status, "in_progress");
  assert.deepEqual(auth.calls, [`disable:${uid}`]);
  assert.equal(
    (
      await db.collection("account_deletion_requests").doc(uid).get()
    ).exists,
    true,
  );
  await assert.rejects(
    assertAccountActive(db, uid),
    isDeletionInProgressError,
  );
  await assert.rejects(
    loadOrCreatePlayerProfile({ db, uid }),
    isDeletionInProgressError,
  );
  await assert.rejects(
    updatePlayerProfile({
      db,
      uid,
      nowMs: requestNowMs + 1,
      displayName: "Should Not Exist",
    }),
    isDeletionInProgressError,
  );
  await assert.rejects(
    loadOrCreateCanonicalState({ db, uid }),
    isDeletionInProgressError,
  );
  assert.equal(
    (await db.collection("player_profiles").doc(uid).get()).exists,
    false,
  );
  assert.equal(
    (
      await db
        .collection("ownership_profiles")
        .where("uid", "==", uid)
        .get()
    ).empty,
    true,
  );
});

test("bounded workflow erases large account, catches reinsertion, then deletes auth", async () => {
  const uid = "uid_delete_target";
  const otherUid = "uid_keep";
  const auth = new InMemoryAccountDeletionAuth();
  const artifacts = new InMemoryReplayArtifactStore();
  const dependencies = deletionDependencies(auth, artifacts);

  await seedLargeAccount({ db, uid, otherUid, artifacts });
  await requestAccountDeletion({
    db,
    uid,
    nowMs: requestNowMs,
    pageSize: 2,
    dependencies,
  });

  const quiet = await processUntilStage({
    db,
    uid,
    targetStage: "quiet_wait",
    nowMs: requestNowMs,
    pageSize: 2,
    dependencies,
  });
  assert.equal(quiet.status, "in_progress");
  assert.deepEqual(auth.calls, [`disable:${uid}`]);

  // Simulate late server work or an upload signed before the tombstone.
  await db.collection("reward_grants").doc("late_reward").set({
    uid,
    runSessionId: "late_reward",
  });
  await db.collection("validated_runs").doc("late_run").set({
    uid,
    runSessionId: "late_run",
  });
  artifacts.add(
    `replay-submissions/pending/${uid}/late_run/replay.bin.gz`,
  );
  artifacts.add("replay-submissions/validated/late_run.bin.gz");

  const readyToDeleteAuth = await processUntilStage({
    db,
    uid,
    targetStage: "delete_auth",
    nowMs: afterUploadLeaseMs,
    pageSize: 2,
    dependencies,
  });
  assert.equal(readyToDeleteAuth.status, "in_progress");
  const activeTombstone = (
    await db.collection("account_deletion_requests").doc(uid).get()
  ).data();
  assert.ok((activeTombstone?.pass as number) >= 3);
  assert.ok((activeTombstone?.deleted?.runSessionDocs as number) > 2);
  assert.ok(
    (activeTombstone?.deleted?.pendingReplayObjectDeletes as number) > 2,
  );
  await db.collection("account_deletion_requests").doc(uid).set(
    { unexpectedLegacyDiagnostic: "must not survive completion" },
    { merge: true },
  );

  const completed = await processAccountDeletion({
    db,
    uid,
    nowMs: afterUploadLeaseMs,
    pageSize: 2,
    dependencies,
  });
  assert.equal(completed.status, "deleted");
  assert.deepEqual(auth.calls, [`disable:${uid}`, `delete:${uid}`]);

  for (const collection of [
    "player_profiles",
    "display_name_index",
    "ownership_profiles",
    "abuse_quota",
    "run_sessions",
    "validated_runs",
    "reward_grants",
    "ghost_runs",
    "leaderboard_ghost_runs",
    "weekly_ghost_runs",
  ]) {
    const owned = await db
      .collection(collection)
      .where("uid", "==", uid)
      .get();
    assert.equal(owned.empty, true, collection);
  }
  assert.equal(
    (
      await db
        .collection("leaderboard_boards")
        .doc("board_1")
        .collection("player_bests")
        .doc(uid)
        .get()
    ).exists,
    false,
  );
  assert.equal(
    (
      await db
        .collection("leaderboard_boards")
        .doc("board_1")
        .collection("ghost_manifests")
        .doc("entry_target")
        .get()
    ).exists,
    false,
  );
  assert.equal(
    (
      await db
        .collection("leaderboard_boards")
        .doc("board_1")
        .collection("views")
        .doc("top10")
        .get()
    ).exists,
    false,
  );
  assert.equal(artifacts.hasPrefix(`replay-submissions/pending/${uid}/`), false);
  assert.equal(
    artifacts.hasObject("replay-submissions/validated/late_run.bin.gz"),
    false,
  );

  assert.equal(
    (await db.collection("player_profiles").doc(otherUid).get()).exists,
    true,
  );
  assert.equal(
    (await db.collection("abuse_quota").doc(otherUid).get()).exists,
    true,
  );
  assert.equal(
    (
      await db
        .collection("leaderboard_boards")
        .doc("board_1")
        .collection("player_bests")
        .doc(otherUid)
        .get()
    ).exists,
    true,
  );

  const tombstone = (
    await db.collection("account_deletion_requests").doc(uid).get()
  ).data();
  assert.deepEqual(tombstone, {
    state: "complete",
    requestedAtMs: requestNowMs,
    completedAtMs: afterUploadLeaseMs,
    expiresAtMs:
      afterUploadLeaseMs + accountDeletionCompletionRetentionMs,
  });
});

test("repeated requests converge on the same workflow", async () => {
  const uid = "uid_repeat";
  const auth = new InMemoryAccountDeletionAuth();
  const dependencies = deletionDependencies(auth);

  const first = await requestAccountDeletion({
    db,
    uid,
    nowMs: requestNowMs,
    dependencies,
  });
  const second = await requestAccountDeletion({
    db,
    uid,
    nowMs: requestNowMs + 1,
    dependencies,
  });

  assert.equal(first.requestId, uid);
  assert.equal(second.requestId, uid);
  assert.equal(
    (
      await db.collection("account_deletion_requests").get()
    ).size,
    1,
  );
  assert.equal(auth.calls.filter((call) => call === `disable:${uid}`).length, 1);
});

test("retryable stage failure resumes without losing coverage", async () => {
  const uid = "uid_retry";
  const auth = new InMemoryAccountDeletionAuth();
  const artifacts = new InMemoryReplayArtifactStore([
    `replay-submissions/pending/${uid}/run_1/replay.bin.gz`,
  ]);
  artifacts.failNextPrefixDelete = true;
  const dependencies = deletionDependencies(auth, artifacts);

  await requestAccountDeletion({
    db,
    uid,
    nowMs: requestNowMs,
    dependencies,
  });
  const retryable = await processUntilStatus({
    db,
    uid,
    targetStatus: "retryable",
    nowMs: requestNowMs,
    dependencies,
  });
  assert.equal(retryable.stage, "pending_replay_artifacts");

  const completed = await drainDeletion({
    db,
    uid,
    nowMs: afterUploadLeaseMs,
    dependencies,
  });
  assert.equal(completed.status, "deleted");
  assert.equal(
    artifacts.hasPrefix(`replay-submissions/pending/${uid}/`),
    false,
  );
  assert.deepEqual(auth.calls, [`disable:${uid}`, `delete:${uid}`]);
});

test("repair scan reports bounded backlog health without account identifiers", async () => {
  const nowMs = requestNowMs + 7 * 60 * 60 * 1000;
  const auth = new InMemoryAccountDeletionAuth();
  const dependencies = deletionDependencies(auth);
  await Promise.all([
    db.collection("account_deletion_requests").doc("uid_oldest").set({
      uid: "uid_oldest",
      state: "retryable",
      stage: "disable_auth",
      requestedAtMs: requestNowMs,
      updatedAtMs: requestNowMs,
      attemptCount: 400,
      deleted: {},
    }),
    db.collection("account_deletion_requests").doc("uid_newer").set({
      uid: "uid_newer",
      state: "requested",
      stage: "disable_auth",
      requestedAtMs: requestNowMs + 1,
      updatedAtMs: requestNowMs + 1,
      attemptCount: 2,
      deleted: {},
    }),
  ]);

  const result = await processPendingAccountDeletions({
    db,
    nowMs,
    maxRequests: 1,
    dependencies,
  });

  assert.deepEqual(result, {
    scannedCount: 1,
    processedCount: 1,
    retryableCount: 0,
    completedRecordDeletes: 0,
    retryableBacklogCount: 1,
    oldestActiveAgeMs: 7 * 60 * 60 * 1000,
    oldestActiveStage: "disable_auth",
    maxAttemptCount: 400,
    activePageSaturated: true,
  });
  assert.equal("uid" in result, false);
  assert.equal("requestId" in result, false);
});

test("failure after every deletion stage replays from its durable checkpoint", async () => {
  for (const stage of accountDeletionStages) {
    const uid = `uid_fault_${stage}`;
    const auth = new InMemoryAccountDeletionAuth();
    const artifacts = new InMemoryReplayArtifactStore();
    const artifactExists = await seedDeletionStageArtifact({
      db,
      uid,
      stage,
      artifacts,
    });
    await db.collection("account_deletion_requests").doc(uid).set({
      uid,
      state: "requested",
      stage,
      pass: 1,
      finalPass: false,
      passDeletedCount: 0,
      boardCursor: null,
      requestedAtMs: requestNowMs,
      updatedAtMs: requestNowMs,
      attemptCount: 0,
      deleted: {},
    });

    let injectFailure = true;
    const dependencies: AccountDeletionDependencies = {
      auth,
      replayArtifactStore: artifacts,
      afterStage: async (completedStage) => {
        if (injectFailure && completedStage === stage) {
          injectFailure = false;
          throw new Error(`injected post-stage failure: ${stage}`);
        }
      },
    };

    const failed = await processAccountDeletion({
      db,
      uid,
      nowMs: afterUploadLeaseMs,
      pageSize: 2,
      dependencies,
    });
    assert.equal(failed.status, "retryable", stage);
    assert.equal(failed.stage, stage, stage);
    assert.equal(await artifactExists(), false, stage);

    const retryable = (
      await db.collection("account_deletion_requests").doc(uid).get()
    ).data();
    assert.equal(retryable?.state, "retryable", stage);
    assert.equal(retryable?.stage, stage, stage);
    assert.equal(
      retryable?.lastErrorMessage,
      `injected post-stage failure: ${stage}`,
      stage,
    );

    let resumed = failed;
    for (let attempt = 0; attempt < 5; attempt += 1) {
      resumed = await processAccountDeletion({
        db,
        uid,
        nowMs: afterUploadLeaseMs + attempt + 1,
        pageSize: 2,
        dependencies,
      });
      if (resumed.stage !== stage) {
        break;
      }
    }
    assert.notEqual(resumed.stage, stage, stage);
    const checkpoint = (
      await db.collection("account_deletion_requests").doc(uid).get()
    ).data();
    assert.equal(checkpoint?.lastErrorClass, undefined, stage);
    assert.equal(checkpoint?.lastErrorMessage, undefined, stage);
  }
});

test("concurrent workers serialize deletion pages without duplicating a stage", async () => {
  const uid = "uid_lease";
  const auth = new InMemoryAccountDeletionAuth();
  auth.disableDelayMs = 100;
  const dependencies = deletionDependencies(auth);
  await db.collection("account_deletion_requests").doc(uid).set({
    uid,
    state: "requested",
    stage: "disable_auth",
    pass: 1,
    finalPass: false,
    passDeletedCount: 0,
    requestedAtMs: requestNowMs,
    attemptCount: 0,
  });

  const results = await Promise.all([
    processAccountDeletion({
      db,
      uid,
      nowMs: requestNowMs + 1,
      dependencies,
    }),
    processAccountDeletion({
      db,
      uid,
      nowMs: requestNowMs + 1,
      dependencies,
    }),
  ]);
  assert.ok(results.filter((result) => result.processed).length >= 1);
  assert.deepEqual(auth.calls, [`disable:${uid}`]);
  let tombstone = (
    await db.collection("account_deletion_requests").doc(uid).get()
  ).data();
  if (tombstone?.stage !== "display_name_index") {
    await processAccountDeletion({
      db,
      uid,
      nowMs: requestNowMs + 2,
      dependencies,
    });
    tombstone = (
      await db.collection("account_deletion_requests").doc(uid).get()
    ).data();
  }
  assert.ok((tombstone?.attemptCount as number) >= 2);
  assert.equal(tombstone?.stage, "display_name_index");
});

test("already-missing auth user is terminally successful", async () => {
  const uid = "uid_missing_auth";
  const auth = new InMemoryAccountDeletionAuth();
  auth.userMissing = true;
  const dependencies = deletionDependencies(auth);

  await requestAccountDeletion({
    db,
    uid,
    nowMs: requestNowMs,
    dependencies,
  });
  const completed = await drainDeletion({
    db,
    uid,
    nowMs: afterUploadLeaseMs,
    dependencies,
  });
  assert.equal(completed.status, "deleted");
});

async function seedLargeAccount(args: {
  db: Firestore;
  uid: string;
  otherUid: string;
  artifacts: InMemoryReplayArtifactStore;
}): Promise<void> {
  await args.db.collection("player_profiles").doc(args.uid).set({
    uid: args.uid,
    displayName: "Delete Me",
    displayNameNormalized: "delete me",
  });
  await args.db.collection("display_name_index").doc("delete me").set({
    uid: args.uid,
  });
  await args.db.collection("player_profiles").doc(args.otherUid).set({
    uid: args.otherUid,
    displayName: "Keep Me",
    displayNameNormalized: "keep me",
  });
  await args.db.collection("abuse_quota").doc(args.uid).set({
    uid: args.uid,
    expiresAtMs: 999_999,
  });
  await args.db.collection("abuse_quota").doc(args.otherUid).set({
    uid: args.otherUid,
    expiresAtMs: 999_999,
  });

  for (let index = 0; index < 5; index += 1) {
    const suffix = String(index);
    const ownership = args.db
      .collection("ownership_profiles")
      .doc(`profile_${suffix}`);
    await ownership.set({ uid: args.uid, profileId: `profile_${suffix}` });
    for (let command = 0; command < 3; command += 1) {
      await ownership
        .collection("idempotency")
        .doc(`command_${command}`)
        .set({ payloadHash: `${index}-${command}` });
    }
    await args.db.collection("run_sessions").doc(`run_${suffix}`).set({
      uid: args.uid,
      runSessionId: `run_${suffix}`,
    });
    await args.db.collection("validated_runs").doc(`run_${suffix}`).set({
      uid: args.uid,
      runSessionId: `run_${suffix}`,
    });
    await args.db.collection("reward_grants").doc(`run_${suffix}`).set({
      uid: args.uid,
      runSessionId: `run_${suffix}`,
    });
    args.artifacts.add(
      `replay-submissions/pending/${args.uid}/run_${suffix}/replay.bin.gz`,
    );
    args.artifacts.add(
      `replay-submissions/validated/run_${suffix}.bin.gz`,
    );
  }

  await args.db.collection("ghost_runs").doc("ghost_1").set({
    uid: args.uid,
    runSessionId: "run_0",
  });
  await args.db.collection("leaderboard_ghost_runs").doc("ghost_2").set({
    userId: args.uid,
    replayStorageRef: "ghosts/board_1/entry_target/ghost.bin.gz",
  });
  await args.db.collection("weekly_ghost_runs").doc("ghost_3").set({
    ownerUid: args.uid,
  });
  await args.db.collection("leaderboard_boards").doc("board_1").set({
    boardId: "board_1",
  });
  await args.db
    .collection("leaderboard_boards")
    .doc("board_1")
    .collection("ghost_manifests")
    .doc("entry_target")
    .set({
      uid: args.uid,
      runSessionId: "run_0",
      replayStorageRef: "ghosts/board_1/entry_target/ghost.bin.gz",
    });
  await args.db
    .collection("leaderboard_boards")
    .doc("board_1")
    .collection("player_bests")
    .doc(args.uid)
    .set({ uid: args.uid });
  await args.db
    .collection("leaderboard_boards")
    .doc("board_1")
    .collection("player_bests")
    .doc(args.otherUid)
    .set({ uid: args.otherUid });
  await args.db
    .collection("leaderboard_boards")
    .doc("board_1")
    .collection("views")
    .doc("top10")
    .set({ entries: [{ uid: args.uid }] });
  args.artifacts.add("ghosts/board_1/entry_target/ghost.bin.gz");
}

type DeletionStage = (typeof accountDeletionStages)[number];

async function seedDeletionStageArtifact(args: {
  db: Firestore;
  uid: string;
  stage: DeletionStage;
  artifacts: InMemoryReplayArtifactStore;
}): Promise<() => Promise<boolean>> {
  const documentExists = (path: string) => async () =>
    (await args.db.doc(path).get()).exists;
  const collectionStages: Partial<
    Record<DeletionStage, { collection: string; uidField: string }>
  > = {
    display_name_index: {
      collection: "display_name_index",
      uidField: "uid",
    },
    ownership: { collection: "ownership_profiles", uidField: "uid" },
    abuse_quota: { collection: "abuse_quota", uidField: "uid" },
    reward_grants: { collection: "reward_grants", uidField: "uid" },
    ghost_runs_uid: { collection: "ghost_runs", uidField: "uid" },
    ghost_runs_user_id: {
      collection: "ghost_runs",
      uidField: "userId",
    },
    ghost_runs_owner_uid: {
      collection: "ghost_runs",
      uidField: "ownerUid",
    },
    leaderboard_ghost_runs_uid: {
      collection: "leaderboard_ghost_runs",
      uidField: "uid",
    },
    leaderboard_ghost_runs_user_id: {
      collection: "leaderboard_ghost_runs",
      uidField: "userId",
    },
    leaderboard_ghost_runs_owner_uid: {
      collection: "leaderboard_ghost_runs",
      uidField: "ownerUid",
    },
    weekly_ghost_runs_uid: {
      collection: "weekly_ghost_runs",
      uidField: "uid",
    },
    weekly_ghost_runs_user_id: {
      collection: "weekly_ghost_runs",
      uidField: "userId",
    },
    weekly_ghost_runs_owner_uid: {
      collection: "weekly_ghost_runs",
      uidField: "ownerUid",
    },
  };

  if (args.stage === "profile") {
    const path = `player_profiles/${args.uid}`;
    await args.db.doc(path).set({ uid: args.uid });
    return documentExists(path);
  }
  if (args.stage === "ownership_idempotency") {
    const parent = args.db.collection("ownership_profiles").doc(args.uid);
    await parent.set({ uid: args.uid });
    const child = parent.collection("idempotency").doc("fault");
    await child.set({ payloadHash: "fault" });
    return async () => (await child.get()).exists;
  }
  if (args.stage === "run_sessions" || args.stage === "validated_runs") {
    const collection =
      args.stage === "run_sessions" ? "run_sessions" : "validated_runs";
    const runId = `${args.uid}_run`;
    const path = `${collection}/${runId}`;
    const artifactPath = `replay-submissions/validated/${runId}.bin.gz`;
    await args.db.doc(path).set({ uid: args.uid, runSessionId: runId });
    args.artifacts.add(artifactPath);
    return async () =>
      (await args.db.doc(path).get()).exists ||
      args.artifacts.hasObject(artifactPath);
  }
  if (args.stage === "board_ghosts") {
    await clearCollection(args.db, "leaderboard_boards");
    const board = args.db.collection("leaderboard_boards").doc("fault_board");
    await board.set({ boardId: "fault_board" });
    const manifest = board.collection("ghost_manifests").doc("fault");
    await manifest.set({ uid: args.uid });
    return async () => (await manifest.get()).exists;
  }
  if (args.stage === "board_player_bests") {
    await clearCollection(args.db, "leaderboard_boards");
    const board = args.db.collection("leaderboard_boards").doc("fault_board");
    await board.set({ boardId: "fault_board" });
    const best = board.collection("player_bests").doc(args.uid);
    const view = board.collection("views").doc("top10");
    await best.set({ uid: args.uid });
    await view.set({ entries: [] });
    return async () => (await best.get()).exists || (await view.get()).exists;
  }
  if (args.stage === "pending_replay_artifacts") {
    const prefix = `replay-submissions/pending/${args.uid}/`;
    args.artifacts.add(`${prefix}fault/replay.bin.gz`);
    return async () => args.artifacts.hasPrefix(prefix);
  }
  const collectionStage = collectionStages[args.stage];
  if (collectionStage) {
    const path = `${collectionStage.collection}/${args.uid}_${args.stage}`;
    await args.db.doc(path).set({
      [collectionStage.uidField]: args.uid,
    });
    return documentExists(path);
  }
  return async () => false;
}

async function drainDeletion(args: {
  db: Firestore;
  uid: string;
  nowMs: number;
  pageSize?: number;
  dependencies: AccountDeletionDependencies;
}) {
  for (let attempt = 0; attempt < 500; attempt += 1) {
    const result = await processAccountDeletion(args);
    if (result.status === "deleted") {
      return result;
    }
  }
  throw new Error(`Deletion ${args.uid} did not complete.`);
}

async function processUntilStage(args: {
  db: Firestore;
  uid: string;
  targetStage: string;
  nowMs: number;
  pageSize?: number;
  dependencies: AccountDeletionDependencies;
}) {
  for (let attempt = 0; attempt < 500; attempt += 1) {
    const result = await processAccountDeletion(args);
    if (result.stage === args.targetStage) {
      return result;
    }
  }
  throw new Error(`Deletion ${args.uid} did not reach ${args.targetStage}.`);
}

async function processUntilStatus(args: {
  db: Firestore;
  uid: string;
  targetStatus: string;
  nowMs: number;
  pageSize?: number;
  dependencies: AccountDeletionDependencies;
}) {
  for (let attempt = 0; attempt < 500; attempt += 1) {
    const result = await processAccountDeletion(args);
    if (result.status === args.targetStatus) {
      return result;
    }
  }
  throw new Error(`Deletion ${args.uid} did not reach ${args.targetStatus}.`);
}

function deletionDependencies(
  auth: InMemoryAccountDeletionAuth,
  replayArtifactStore = new InMemoryReplayArtifactStore(),
): AccountDeletionDependencies {
  return { auth, replayArtifactStore };
}

function isDeletionInProgressError(error: { code?: string }): boolean {
  return error.code === "failed-precondition";
}

async function clearCollection(
  dbValue: Firestore,
  name: string,
): Promise<void> {
  const docs = await dbValue.collection(name).listDocuments();
  await Promise.all(
    docs.map((docRef) => dbValue.recursiveDelete(docRef)),
  );
}

class InMemoryAccountDeletionAuth implements AccountDeletionAuth {
  readonly calls: string[] = [];
  userMissing = false;
  disableDelayMs = 0;

  async disableAndRevoke(uid: string): Promise<void> {
    if (this.disableDelayMs > 0) {
      await new Promise((resolve) =>
        setTimeout(resolve, this.disableDelayMs),
      );
    }
    if (!this.userMissing) {
      this.calls.push(`disable:${uid}`);
    }
  }

  async deleteUser(uid: string): Promise<void> {
    if (!this.userMissing) {
      this.calls.push(`delete:${uid}`);
    }
  }
}

class InMemoryReplayArtifactStore implements ReplayArtifactStore {
  constructor(initialObjects: readonly string[] = []) {
    for (const objectPath of initialObjects) {
      this.objects.add(objectPath);
    }
  }

  private readonly objects = new Set<string>();
  failNextPrefixDelete = false;

  add(objectPath: string): void {
    this.objects.add(objectPath);
  }

  hasObject(objectPath: string): boolean {
    return this.objects.has(objectPath);
  }

  hasPrefix(prefix: string): boolean {
    return [...this.objects].some((objectPath) =>
      objectPath.startsWith(prefix),
    );
  }

  async deletePageByPrefix(args: {
    prefix: string;
    maxResults: number;
  }): Promise<number> {
    if (this.failNextPrefixDelete) {
      this.failNextPrefixDelete = false;
      throw new Error("injected storage failure");
    }
    const toDelete = [...this.objects]
      .filter((objectPath) => objectPath.startsWith(args.prefix))
      .slice(0, args.maxResults);
    for (const objectPath of toDelete) {
      this.objects.delete(objectPath);
    }
    return toDelete.length;
  }

  async deleteObjectIfExists(args: {
    objectPath: string;
  }): Promise<boolean> {
    return this.objects.delete(args.objectPath);
  }
}
