import assert from "node:assert/strict";
import { after, beforeEach, test } from "node:test";

import { deleteApp, getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, type Firestore } from "firebase-admin/firestore";

import {
  handleGhostLoadManifest,
  type GhostDownloadUrlSigner,
} from "../../src/ghosts/callable_handlers.js";

const firestoreEmulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
if (!firestoreEmulatorHost) {
  throw new Error(
    "FIRESTORE_EMULATOR_HOST is not set. Run via `firebase emulators:exec`.",
  );
}

const emulatorProjectIdBase =
  process.env.GCLOUD_PROJECT ?? "demo-rpg-runner-functions-tests";
const projectId = `${emulatorProjectIdBase}-ghosts`;
const appName = `ghost-tests-${process.pid}-${Date.now()}`;
const app = initializeApp({ projectId }, appName);
const db = getFirestore(app);

beforeEach(async () => {
  await clearCollection(db, "leaderboard_boards");
});

after(async () => {
  await Promise.all(getApps().map((value) => deleteApp(value)));
});

test("handleGhostLoadManifest rejects unauthenticated requests", async () => {
  await assert.rejects(
    () =>
      handleGhostLoadManifest(
        {
          data: {
            userId: "uid_1",
            sessionId: "session_1",
            boardId: "board_1",
            entryId: "entry_1",
          },
        },
        db,
        new _RecordingGhostDownloadUrlSigner(),
      ),
    (error: { code?: string }) => error.code === "unauthenticated",
  );
});

test("handleGhostLoadManifest rejects userId/auth uid mismatch", async () => {
  await assert.rejects(
    () =>
      handleGhostLoadManifest(
        {
          auth: { uid: "uid_auth" },
          data: {
            userId: "uid_other",
            sessionId: "session_1",
            boardId: "board_1",
            entryId: "entry_1",
          },
        },
        db,
        new _RecordingGhostDownloadUrlSigner(),
      ),
    (error: { code?: string }) => error.code === "permission-denied",
  );
});

test("loads active exposed ghost manifest with signed download URL", async () => {
  await seedManifest(db, {
    boardId: "board_1",
    entryId: "entry_1",
    replayStorageRef: "ghosts/board_1/entry_1/ghost.bin.gz",
    status: "active",
    exposed: true,
  });
  const signer = new _RecordingGhostDownloadUrlSigner();

  const response = await handleGhostLoadManifest(
    {
      auth: { uid: "uid_1" },
      data: {
        userId: "uid_1",
        sessionId: "session_1",
        boardId: "board_1",
        entryId: "entry_1",
      },
    },
    db,
    signer,
  );

  assert.equal(response.ghostManifest.boardId, "board_1");
  assert.equal(response.ghostManifest.entryId, "entry_1");
  assert.equal(response.ghostManifest.runSessionId, "run_entry_1");
  assert.equal(
    response.ghostManifest.replayStorageRef,
    "ghosts/board_1/entry_1/ghost.bin.gz",
  );
  assert.equal(
    response.ghostManifest.downloadUrl,
    "https://example.test/ghosts/board_1/entry_1/ghost.bin.gz",
  );
  assert.ok(response.ghostManifest.downloadUrlExpiresAtMs > Date.now());
  assert.equal(signer.lastObjectPath, "ghosts/board_1/entry_1/ghost.bin.gz");
});

test("rejects demoted or hidden ghost manifests", async () => {
  await seedManifest(db, {
    boardId: "board_1",
    entryId: "entry_demoted",
    replayStorageRef: "ghosts/board_1/entry_demoted/ghost.bin.gz",
    status: "demoted",
    exposed: false,
  });

  await assert.rejects(
    () =>
      handleGhostLoadManifest(
        {
          auth: { uid: "uid_1" },
          data: {
            userId: "uid_1",
            sessionId: "session_1",
            boardId: "board_1",
            entryId: "entry_demoted",
          },
        },
        db,
        new _RecordingGhostDownloadUrlSigner(),
      ),
    (error: { code?: string }) => error.code === "not-found",
  );
});

test("rejects active manifest replay path outside ghosts prefix", async () => {
  await seedManifest(db, {
    boardId: "board_1",
    entryId: "entry_bad",
    replayStorageRef:
      "replay-submissions/pending/uid_1/run_entry_bad/replay.bin.gz",
    status: "active",
    exposed: true,
  });

  await assert.rejects(
    () =>
      handleGhostLoadManifest(
        {
          auth: { uid: "uid_1" },
          data: {
            userId: "uid_1",
            sessionId: "session_1",
            boardId: "board_1",
            entryId: "entry_bad",
          },
        },
        db,
        new _RecordingGhostDownloadUrlSigner(),
      ),
    (error: { code?: string }) => error.code === "failed-precondition",
  );
});

async function seedManifest(
  dbValue: Firestore,
  args: {
    boardId: string;
    entryId: string;
    replayStorageRef: string;
    status: "active" | "demoted";
    exposed: boolean;
  },
): Promise<void> {
  await dbValue.collection("leaderboard_boards").doc(args.boardId).set({
    boardId: args.boardId,
  });
  await dbValue
    .collection("leaderboard_boards")
    .doc(args.boardId)
    .collection("ghost_manifests")
    .doc(args.entryId)
    .set({
      boardId: args.boardId,
      entryId: args.entryId,
      runSessionId: `run_${args.entryId}`,
      uid: "uid_1",
      replayStorageRef: args.replayStorageRef,
      sourceReplayStorageRef:
        `replay-submissions/pending/uid_1/run_${args.entryId}/replay.bin.gz`,
      score: 1000,
      distanceMeters: 400,
      durationSeconds: 120,
      sortKey: "0000000001:0000000001:0000000120:entry_1",
      rank: 1,
      status: args.status,
      exposed: args.exposed,
      updatedAtMs: 1_700_000_000_000,
    });
}

async function clearCollection(dbValue: Firestore, name: string): Promise<void> {
  const docs = await dbValue.collection(name).listDocuments();
  await Promise.all(docs.map((docRef) => dbValue.recursiveDelete(docRef)));
}

class _RecordingGhostDownloadUrlSigner implements GhostDownloadUrlSigner {
  lastObjectPath?: string;

  async signDownloadUrl(args: {
    objectPath: string;
    expiresAtMs: number;
  }): Promise<string> {
    this.lastObjectPath = args.objectPath;
    return `https://example.test/${args.objectPath}`;
  }
}
