import assert from "node:assert/strict";
import { after, beforeEach, test } from "node:test";

import { deleteApp, getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, type Firestore } from "firebase-admin/firestore";

import {
  type GhostExposureLookup,
  runReplaySubmissionCleanup,
  type PendingReplayObjectListPage,
  type PendingReplayObjectStore,
} from "../../src/runs/cleanup.js";

const firestoreEmulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
if (!firestoreEmulatorHost) {
  throw new Error(
    "FIRESTORE_EMULATOR_HOST is not set. Run via `firebase emulators:exec`.",
  );
}

const emulatorProjectIdBase =
  process.env.GCLOUD_PROJECT ?? "demo-rpg-runner-functions-tests";
const projectId = `${emulatorProjectIdBase}-run-cleanup`;
const appName = `run-cleanup-tests-${process.pid}-${Date.now()}`;
const app = initializeApp({ projectId }, appName);
const db = getFirestore(app);

beforeEach(async () => {
  await Promise.all([
    clearCollection(db, "run_sessions"),
    clearCollection(db, "leaderboard_boards"),
    clearCollection(db, "maintenance"),
    clearCollection(db, "validated_runs"),
    clearCollection(db, "reward_grants"),
  ]);
});

after(async () => {
  await Promise.all(getApps().map((value) => deleteApp(value)));
});

test("run cleanup expires issued/uploading/uploaded sessions past expiry", async () => {
  const nowMs = Date.UTC(2026, 2, 13, 12, 0, 0, 0);
  await seedRunSession("issued_old", "issued", nowMs - 1);
  await seedRunSession("uploading_old", "uploading", nowMs - 1);
  await seedRunSession("uploaded_old", "uploaded", nowMs - 1);
  await seedRunSession("pending_old", "pending_validation", nowMs - 1);
  await seedRunSession("validated_old", "validated", nowMs - 1);
  await seedRunSession("issued_fresh", "issued", nowMs + 60_000);

  const result = await runReplaySubmissionCleanup({
    db,
    nowMs,
    dependencies: {},
  });

  assert.equal(result.expiredSessionCount, 3);
  assert.equal(result.pendingUploadCleanupSkipped, true);

  assert.equal(await stateFor("issued_old"), "expired");
  assert.equal(await stateFor("uploading_old"), "expired");
  assert.equal(await stateFor("uploaded_old"), "expired");
  assert.equal(await stateFor("pending_old"), "pending_validation");
  assert.equal(await stateFor("validated_old"), "validated");
  assert.equal(await stateFor("issued_fresh"), "issued");
});

test("run cleanup deletes stale pending replay uploads older than cutoff", async () => {
  const nowMs = 10_000;
  const objectStore = new FakePendingReplayObjectStore([
    {
      objectPath: "replay-submissions/pending/u1/run_old_a/replay.bin.gz",
      updatedAtMs: 7_000,
    },
    {
      objectPath: "replay-submissions/pending/u1/run_fresh/replay.bin.gz",
      updatedAtMs: 9_500,
    },
    {
      objectPath: "replay-submissions/pending/u2/run_old_b/replay.bin.gz",
      updatedAtMs: 1_000,
    },
  ]);

  const result = await runReplaySubmissionCleanup({
    db,
    nowMs,
    dependencies: {
      pendingReplayObjectStore: objectStore,
      stalePendingUploadCutoffMs: 1_000,
      maxExpiredSessionUpdatesPerRun: 10,
      maxPendingUploadDeletesPerRun: 10,
    },
  });

  assert.equal(result.stalePendingUploadDeletedCount, 2);
  assert.equal(result.stalePendingUploadScannedCount, 3);
  assert.equal(result.pendingUploadCleanupSkipped, false);
  assert.deepEqual(objectStore.deletedObjectPaths, [
    "replay-submissions/pending/u1/run_old_a/replay.bin.gz",
    "replay-submissions/pending/u2/run_old_b/replay.bin.gz",
  ]);
});

test("run cleanup preserves validating replay evidence until a sealed artifact exists", async () => {
  const nowMs = 10_000;
  const validatingPath =
    "replay-submissions/pending/u1/run_validating/replay.bin.gz";
  const archivedPath =
    "replay-submissions/pending/u1/run_archived/replay.bin.gz";
  await seedRunSession("run_validating", "pending_validation", nowMs + 10_000);
  await db.collection("run_sessions").doc("run_validating").set({
    uploadedReplay: {
      objectPath: validatingPath,
      storageGeneration: "123",
    },
  }, { merge: true });
  await seedRunSession("run_archived", "settlement_pending", nowMs + 10_000);
  await db.collection("run_sessions").doc("run_archived").set({
    uploadedReplay: {
      objectPath: archivedPath,
      storageGeneration: "456",
    },
    validatedReplay: {
      objectPath: "replay-submissions/validated/run_archived.bin.gz",
      storageGeneration: "789",
      sourceObjectPath: archivedPath,
      sourceStorageGeneration: "456",
    },
  }, { merge: true });
  const objectStore = new FakePendingReplayObjectStore([
    { objectPath: validatingPath, updatedAtMs: 1_000 },
    { objectPath: archivedPath, updatedAtMs: 1_000 },
  ]);

  const result = await runReplaySubmissionCleanup({
    db,
    nowMs,
    dependencies: {
      pendingReplayObjectStore: objectStore,
      stalePendingUploadCutoffMs: 1_000,
      maxExpiredSessionUpdatesPerRun: 10,
      maxPendingUploadDeletesPerRun: 10,
    },
  });

  assert.equal(result.stalePendingUploadDeletedCount, 1);
  assert.deepEqual(objectStore.deletedObjectPaths, [archivedPath]);
});

test("run cleanup deletes stale validated artifacts only for non-top10 runs", async () => {
  const nowMs = 1_000_000;
  const objectStore = new FakePendingReplayObjectStore([
    {
      objectPath: "replay-submissions/validated/run_top.bin.gz",
      updatedAtMs: 100_000,
    },
    {
      objectPath: "replay-submissions/validated/run_non_top.bin.gz",
      updatedAtMs: 100_000,
    },
    {
      objectPath: "replay-submissions/validated/run_fresh.bin.gz",
      updatedAtMs: 999_500,
    },
  ]);
  const ghostLookup = new FakeGhostExposureLookup(
    new Set<string>(["run_top"]),
  );

  const result = await runReplaySubmissionCleanup({
    db,
    nowMs,
    dependencies: {
      validatedReplayObjectStore: objectStore,
      ghostExposureLookup: ghostLookup,
      staleValidatedArtifactCutoffMs: 1_000,
      maxExpiredSessionUpdatesPerRun: 10,
      maxPendingUploadDeletesPerRun: 10,
      maxValidatedArtifactDeletesPerRun: 10,
    },
  });

  assert.equal(result.staleValidatedArtifactDeletedCount, 1);
  assert.equal(result.staleValidatedArtifactScannedCount, 3);
  assert.equal(result.validatedArtifactCleanupSkipped, false);
  assert.deepEqual(objectStore.deletedObjectPaths, [
    "replay-submissions/validated/run_non_top.bin.gz",
  ]);
  assert.deepEqual(ghostLookup.lookedUpRunSessionIds, [
    "run_top",
    "run_non_top",
  ]);
});

test("run cleanup deletes only old, unreferenced canonical ghost artifacts", async () => {
  const nowMs = 1_000_000;
  const activePath = "ghosts/board_active/entry_active/ghost.bin.gz";
  const demotedPath = "ghosts/board_demoted/entry_demoted/ghost.bin.gz";
  const orphanPath = "ghosts/board_orphan/entry_orphan/ghost.bin.gz";
  await db
    .collection("leaderboard_boards")
    .doc("board_active")
    .collection("ghost_manifests")
    .doc("entry_active")
    .set({ replayStorageRef: activePath, status: "active", exposed: true });
  await db
    .collection("leaderboard_boards")
    .doc("board_demoted")
    .collection("ghost_manifests")
    .doc("entry_demoted")
    .set({ replayStorageRef: demotedPath, status: "demoted", exposed: false });
  const objectStore = new FakePendingReplayObjectStore([
    { objectPath: activePath, updatedAtMs: 100_000 },
    { objectPath: demotedPath, updatedAtMs: 100_000 },
    { objectPath: orphanPath, updatedAtMs: 100_000 },
    {
      objectPath: "ghosts/board_orphan/entry_orphan/not-a-ghost.bin.gz",
      updatedAtMs: 100_000,
    },
    {
      objectPath: "ghosts/board_fresh/entry_fresh/ghost.bin.gz",
      updatedAtMs: nowMs - 500,
    },
  ]);

  const result = await runReplaySubmissionCleanup({
    db,
    nowMs,
    dependencies: {
      ghostArtifactObjectStore: objectStore,
      staleGhostArtifactCutoffMs: 1_000,
      maxGhostArtifactDeletesPerRun: 10,
    },
  });

  assert.equal(result.staleGhostArtifactDeletedCount, 1);
  assert.equal(result.staleGhostArtifactScannedCount, 5);
  assert.equal(result.ghostArtifactCleanupSkipped, false);
  assert.deepEqual(objectStore.deletedObjectPaths, [orphanPath]);
});

test("run cleanup resumes the ghost artifact scan from its persisted cursor", async () => {
  const nowMs = 1_000_000;
  const referencedPath = "ghosts/board_first/entry_first/ghost.bin.gz";
  const laterOrphanPath = "ghosts/board_later/entry_later/ghost.bin.gz";
  await db
    .collection("leaderboard_boards")
    .doc("board_first")
    .collection("ghost_manifests")
    .doc("entry_first")
    .set({ replayStorageRef: referencedPath, status: "active", exposed: true });
  const objectStore = new FakePendingReplayObjectStore([
    { objectPath: referencedPath, updatedAtMs: 100_000 },
    {
      objectPath: "ghosts/board_first/entry_first/not-a-ghost.bin.gz",
      updatedAtMs: 100_000,
    },
    { objectPath: laterOrphanPath, updatedAtMs: 100_000 },
  ]);
  const dependencies = {
    ghostArtifactObjectStore: objectStore,
    staleGhostArtifactCutoffMs: 1_000,
    maxGhostArtifactDeletesPerRun: 2,
    maxGhostArtifactScansPerRun: 2,
  };

  const firstRun = await runReplaySubmissionCleanup({
    db,
    nowMs,
    dependencies,
  });
  assert.equal(firstRun.staleGhostArtifactDeletedCount, 0);
  assert.equal(firstRun.staleGhostArtifactScannedCount, 2);

  const secondRun = await runReplaySubmissionCleanup({
    db,
    nowMs: nowMs + 1,
    dependencies,
  });
  assert.equal(secondRun.staleGhostArtifactDeletedCount, 1);
  assert.equal(secondRun.staleGhostArtifactScannedCount, 1);
  assert.deepEqual(objectStore.deletedObjectPaths, [laterOrphanPath]);
});

test("run cleanup does not advance past a page when delete capacity is lower", async () => {
  const nowMs = 1_000_000;
  const firstPath = "ghosts/board_a/entry_a/ghost.bin.gz";
  const secondPath = "ghosts/board_b/entry_b/ghost.bin.gz";
  const thirdPath = "ghosts/board_c/entry_c/ghost.bin.gz";
  const objectStore = new FakePendingReplayObjectStore([
    { objectPath: firstPath, updatedAtMs: 100_000 },
    { objectPath: secondPath, updatedAtMs: 100_000 },
    { objectPath: thirdPath, updatedAtMs: 100_000 },
  ]);
  const dependencies = {
    ghostArtifactObjectStore: objectStore,
    staleGhostArtifactCutoffMs: 1_000,
    maxGhostArtifactDeletesPerRun: 1,
    maxGhostArtifactScansPerRun: 3,
  };

  await runReplaySubmissionCleanup({ db, nowMs, dependencies });
  await runReplaySubmissionCleanup({ db, nowMs: nowMs + 1, dependencies });
  await runReplaySubmissionCleanup({ db, nowMs: nowMs + 2, dependencies });

  assert.deepEqual(objectStore.deletedObjectPaths, [
    firstPath,
    secondPath,
    thirdPath,
  ]);
});

test("run cleanup deletes terminal run sessions past retention cutoff", async () => {
  const nowMs = 500_000;
  await seedRunSession("terminal_old_validated", "validated", nowMs - 100_000);
  await db.collection("run_sessions").doc("terminal_old_validated").set({
    terminalAtMs: nowMs - 100_000,
    updatedAtMs: nowMs - 100_000,
  }, { merge: true });

  await seedRunSession("terminal_old_expired", "expired", nowMs - 99_000);
  await seedRunSession("terminal_fresh_rejected", "rejected", nowMs - 500);
  await db.collection("run_sessions").doc("terminal_fresh_rejected").set({
    updatedAtMs: nowMs - 500,
  }, { merge: true });
  await seedRunSession("non_terminal_old_pending", "pending_validation", nowMs - 99_000);

  const result = await runReplaySubmissionCleanup({
    db,
    nowMs,
    dependencies: {
      terminalRunSessionRetentionMs: 1_000,
      maxTerminalRunSessionDeletesPerRun: 10,
      maxExpiredSessionUpdatesPerRun: 10,
    },
  });

  assert.equal(result.terminalRunSessionDeletedCount, 2);
  assert.equal(result.terminalRunSessionScannedCount, 3);
  assert.equal(
    (await db.collection("run_sessions").doc("terminal_old_validated").get()).exists,
    false,
  );
  assert.equal(
    (await db.collection("run_sessions").doc("terminal_old_expired").get()).exists,
    false,
  );
  assert.equal(
    (await db.collection("run_sessions").doc("terminal_fresh_rejected").get()).exists,
    true,
  );
  assert.equal(
    (await db.collection("run_sessions").doc("non_terminal_old_pending").get()).exists,
    true,
  );
});

test("run cleanup deletes validated_runs past retention cutoff", async () => {
  const nowMs = 700_000;
  await db.collection("validated_runs").doc("validated_old").set({
    runSessionId: "validated_old",
    uid: "uid_a",
    createdAtMs: nowMs - 50_000,
  });
  await db.collection("validated_runs").doc("validated_fresh").set({
    runSessionId: "validated_fresh",
    uid: "uid_b",
    createdAtMs: nowMs - 100,
  });

  const result = await runReplaySubmissionCleanup({
    db,
    nowMs,
    dependencies: {
      validatedRunRetentionMs: 1_000,
      maxValidatedRunDeletesPerRun: 10,
      maxExpiredSessionUpdatesPerRun: 10,
    },
  });

  assert.equal(result.validatedRunDeletedCount, 1);
  assert.equal(result.validatedRunScannedCount, 1);
  assert.equal(
    (await db.collection("validated_runs").doc("validated_old").get()).exists,
    false,
  );
  assert.equal(
    (await db.collection("validated_runs").doc("validated_fresh").get()).exists,
    true,
  );
});

test("run cleanup deletes only terminal settled reward_grants past retention cutoff", async () => {
  const nowMs = 800_000;
  await db.collection("reward_grants").doc("grant_old_validated").set({
    runSessionId: "grant_old_validated",
    uid: "uid_a",
    lifecycleState: "validated_settled",
    updatedAtMs: nowMs - 60_000,
  });
  await db.collection("reward_grants").doc("grant_old_revoked").set({
    runSessionId: "grant_old_revoked",
    uid: "uid_a",
    lifecycleState: "revoked_final",
    updatedAtMs: nowMs - 59_000,
  });
  await db.collection("reward_grants").doc("grant_old_provisional").set({
    runSessionId: "grant_old_provisional",
    uid: "uid_a",
    lifecycleState: "provisional_visible",
    updatedAtMs: nowMs - 58_000,
  });
  await db.collection("reward_grants").doc("grant_fresh_validated").set({
    runSessionId: "grant_fresh_validated",
    uid: "uid_b",
    lifecycleState: "validated_settled",
    updatedAtMs: nowMs - 100,
  });

  const result = await runReplaySubmissionCleanup({
    db,
    nowMs,
    dependencies: {
      rewardGrantRetentionMs: 1_000,
      maxRewardGrantDeletesPerRun: 10,
      maxExpiredSessionUpdatesPerRun: 10,
    },
  });

  assert.equal(result.rewardGrantDeletedCount, 2);
  assert.equal(
    (await db.collection("reward_grants").doc("grant_old_validated").get()).exists,
    false,
  );
  assert.equal(
    (await db.collection("reward_grants").doc("grant_old_revoked").get()).exists,
    false,
  );
  assert.equal(
    (await db.collection("reward_grants").doc("grant_old_provisional").get()).exists,
    true,
  );
  assert.equal(
    (await db.collection("reward_grants").doc("grant_fresh_validated").get()).exists,
    true,
  );
});

test("run cleanup revokes old orphaned grants but preserves active validation grants", async () => {
  const nowMs = 1_000_000;
  await db.collection("reward_grants").doc("orphan_missing").set({
    runSessionId: "orphan_missing",
    uid: "uid_cleanup",
    lifecycleState: "provisional_created",
    goldAmount: 12,
    updatedAtMs: 100,
  });
  await seedRunSession(
    "orphan_terminal",
    "expired",
    nowMs - 10_000,
  );
  await db.collection("reward_grants").doc("orphan_terminal").set({
    runSessionId: "orphan_terminal",
    uid: "uid_cleanup",
    lifecycleState: "provisional_visible",
    goldAmount: 13,
    updatedAtMs: 200,
  });
  await seedRunSession(
    "active_validation",
    "pending_validation",
    nowMs + 10_000,
  );
  await db.collection("reward_grants").doc("active_validation").set({
    runSessionId: "active_validation",
    uid: "uid_cleanup",
    lifecycleState: "provisional_created",
    goldAmount: 14,
    updatedAtMs: 300,
  });

  const result = await runReplaySubmissionCleanup({
    db,
    nowMs,
    dependencies: {
      orphanProvisionalGrantGraceMs: 1_000,
      maxOrphanProvisionalGrantRepairsPerRun: 10,
      maxExpiredSessionUpdatesPerRun: 10,
    },
  });

  assert.equal(result.orphanProvisionalGrantRepairedCount, 2);
  assert.equal(
    (
      await db.collection("reward_grants").doc("orphan_missing").get()
    ).get("lifecycleState"),
    "revoked_final",
  );
  assert.equal(
    (
      await db.collection("reward_grants").doc("orphan_terminal").get()
    ).get("settlementReason"),
    "terminal_run_expired",
  );
  assert.equal(
    (
      await db.collection("reward_grants").doc("active_validation").get()
    ).get("lifecycleState"),
    "provisional_created",
  );
});

type SeededRunSessionState =
  | "issued"
  | "uploading"
  | "uploaded"
  | "pending_validation"
  | "settlement_pending"
  | "validated"
  | "rejected"
  | "expired"
  | "cancelled"
  | "internal_error";

async function seedRunSession(
  runSessionId: string,
  state: SeededRunSessionState,
  expiresAtMs: number,
): Promise<void> {
  await db.collection("run_sessions").doc(runSessionId).set({
    runSessionId,
    uid: "uid_cleanup",
    state,
    expiresAtMs,
    updatedAtMs: expiresAtMs - 1000,
    createdAtMs: expiresAtMs - 2000,
  });
}

async function stateFor(runSessionId: string): Promise<string | undefined> {
  const doc = await db.collection("run_sessions").doc(runSessionId).get();
  return doc.get("state") as string | undefined;
}

class FakePendingReplayObjectStore implements PendingReplayObjectStore {
  constructor(
    objects: Array<{
      objectPath: string;
      updatedAtMs: number;
    }>,
  ) {
    this._objects = objects;
  }

  private readonly _objects: Array<{
    objectPath: string;
    updatedAtMs: number;
  }>;

  readonly deletedObjectPaths: string[] = [];

  async listPendingObjects(args: {
    prefix: string;
    maxResults: number;
    pageToken?: string;
  }): Promise<PendingReplayObjectListPage> {
    const filtered = this._objects.filter((value) =>
      value.objectPath.startsWith(args.prefix),
    );
    const start = args.pageToken ? Number.parseInt(args.pageToken, 10) : 0;
    const endExclusive = Math.min(start + args.maxResults, filtered.length);
    const objects = filtered.slice(start, endExclusive);
    const nextPageToken =
      endExclusive < filtered.length ? String(endExclusive) : undefined;
    return {
      objects,
      nextPageToken,
    };
  }

  async deleteObject(args: { objectPath: string }): Promise<void> {
    this.deletedObjectPaths.push(args.objectPath);
  }
}

class FakeGhostExposureLookup implements GhostExposureLookup {
  constructor(private readonly exposedRunSessionIds: Set<string>) {}

  readonly lookedUpRunSessionIds: string[] = [];

  async isRunSessionGhostExposed(args: {
    runSessionId: string;
  }): Promise<boolean> {
    this.lookedUpRunSessionIds.push(args.runSessionId);
    return this.exposedRunSessionIds.has(args.runSessionId);
  }
}

async function clearCollection(dbValue: Firestore, name: string): Promise<void> {
  const docs = await dbValue.collection(name).listDocuments();
  await Promise.all(docs.map((docRef) => dbValue.recursiveDelete(docRef)));
}
