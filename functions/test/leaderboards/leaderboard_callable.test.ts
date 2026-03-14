import assert from "node:assert/strict";
import { after, beforeEach, test } from "node:test";

import { deleteApp, getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, type Firestore } from "firebase-admin/firestore";

import {
  handleLeaderboardLoadBoard,
  handleLeaderboardLoadMyRank,
} from "../../src/leaderboards/callable_handlers.js";

const firestoreEmulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
if (!firestoreEmulatorHost) {
  throw new Error(
    "FIRESTORE_EMULATOR_HOST is not set. Run via `firebase emulators:exec`.",
  );
}

const emulatorProjectIdBase =
  process.env.GCLOUD_PROJECT ?? "demo-rpg-runner-functions-tests";
const projectId = `${emulatorProjectIdBase}-leaderboards`;
const appName = `leaderboard-tests-${process.pid}-${Date.now()}`;
const app = initializeApp({ projectId }, appName);
const db = getFirestore(app);

beforeEach(async () => {
  await Promise.all([
    clearCollection(db, "leaderboard_boards"),
  ]);
});

after(async () => {
  await Promise.all(getApps().map((value) => deleteApp(value)));
});

test("handleLeaderboardLoadBoard rejects unauthenticated requests", async () => {
  await assert.rejects(
    () =>
      handleLeaderboardLoadBoard(
        {
          data: {
            userId: "uid_1",
            sessionId: "session_1",
            boardId: "board_1",
          },
        },
        db,
      ),
    (error: { code?: string }) => error.code === "unauthenticated",
  );
});

test("handleLeaderboardLoadBoard rejects userId/auth uid mismatch", async () => {
  await assert.rejects(
    () =>
      handleLeaderboardLoadBoard(
        {
          auth: { uid: "uid_auth" },
          data: {
            userId: "uid_other",
            sessionId: "session_1",
            boardId: "board_1",
          },
        },
        db,
      ),
    (error: { code?: string }) => error.code === "permission-denied",
  );
});

test("handleLeaderboardLoadMyRank rejects unauthenticated requests", async () => {
  await assert.rejects(
    () =>
      handleLeaderboardLoadMyRank(
        {
          data: {
            userId: "uid_1",
            sessionId: "session_1",
            boardId: "board_1",
          },
        },
        db,
      ),
    (error: { code?: string }) => error.code === "unauthenticated",
  );
});

test("handleLeaderboardLoadMyRank rejects userId/auth uid mismatch", async () => {
  await assert.rejects(
    () =>
      handleLeaderboardLoadMyRank(
        {
          auth: { uid: "uid_auth" },
          data: {
            userId: "uid_other",
            sessionId: "session_1",
            boardId: "board_1",
          },
        },
        db,
      ),
    (error: { code?: string }) => error.code === "permission-denied",
  );
});

test("load board returns ranked top entries from player_bests", async () => {
  await seedBoardWithEntries(db);

  const response = await handleLeaderboardLoadBoard(
    {
      auth: { uid: "uid_1" },
      data: {
        userId: "uid_1",
        sessionId: "session_1",
        boardId: "board_competitive_1",
      },
    },
    db,
  );

  const board = response.board;
  const topEntries = board.topEntries;
  assert.equal(board.boardId, "board_competitive_1");
  assert.equal(topEntries.length, 3);
  assert.equal(topEntries[0]?.uid, "uid_1");
  assert.equal(topEntries[0]?.rank, 1);
  assert.equal(topEntries[1]?.uid, "uid_2");
  assert.equal(topEntries[1]?.rank, 2);
  assert.equal(topEntries[2]?.uid, "uid_3");
  assert.equal(topEntries[2]?.rank, 3);
});

test("load my rank returns exact rank and total players", async () => {
  await seedBoardWithEntries(db);

  const response = await handleLeaderboardLoadMyRank(
    {
      auth: { uid: "uid_2" },
      data: {
        userId: "uid_2",
        sessionId: "session_1",
        boardId: "board_competitive_1",
      },
    },
    db,
  );

  const payload = response.myRank;
  const myEntry = payload.myEntry;
  assert.equal(payload.boardId, "board_competitive_1");
  assert.equal(payload.rank, 2);
  assert.equal(payload.totalPlayers, 3);
  assert.equal(myEntry?.uid, "uid_2");
  assert.equal(myEntry?.rank, 2);
});

test("load my rank returns null rank when player has no best", async () => {
  await seedBoardWithEntries(db);

  const response = await handleLeaderboardLoadMyRank(
    {
      auth: { uid: "uid_404" },
      data: {
        userId: "uid_404",
        sessionId: "session_1",
        boardId: "board_competitive_1",
      },
    },
    db,
  );

  const payload = response.myRank;
  assert.equal(payload.rank, null);
  assert.equal(payload.myEntry, null);
  assert.equal(payload.totalPlayers, 3);
});

test("weekly board load and my rank work through the same online API surface", async () => {
  await seedBoardWithEntries(db, {
    boardId: "board_weekly_2026_w11_field",
    mode: "weekly",
    windowId: "2026-W11",
  });

  const boardResponse = await handleLeaderboardLoadBoard(
    {
      auth: { uid: "uid_1" },
      data: {
        userId: "uid_1",
        sessionId: "session_1",
        boardId: "board_weekly_2026_w11_field",
      },
    },
    db,
  );
  assert.equal(boardResponse.board.boardId, "board_weekly_2026_w11_field");
  assert.equal(boardResponse.board.topEntries.length, 3);
  assert.equal(boardResponse.board.topEntries[0]?.rank, 1);

  const myRankResponse = await handleLeaderboardLoadMyRank(
    {
      auth: { uid: "uid_2" },
      data: {
        userId: "uid_2",
        sessionId: "session_1",
        boardId: "board_weekly_2026_w11_field",
      },
    },
    db,
  );
  assert.equal(myRankResponse.myRank.boardId, "board_weekly_2026_w11_field");
  assert.equal(myRankResponse.myRank.rank, 2);
  assert.equal(myRankResponse.myRank.totalPlayers, 3);
});

async function seedBoardWithEntries(
  dbValue: Firestore,
  args?: {
    boardId?: string;
    mode?: "competitive" | "weekly";
    windowId?: string;
  },
): Promise<void> {
  const boardId = args?.boardId ?? "board_competitive_1";
  const mode = args?.mode ?? "competitive";
  const windowId = args?.windowId ?? "2026-03";

  const boardRef = dbValue.collection("leaderboard_boards").doc(boardId);
  await boardRef.set({
    boardId,
    mode,
    levelId: "field",
    windowId,
  });
  await boardRef.collection("player_bests").doc("uid_1").set(
    leaderboardEntryDoc({
      boardId,
      uid: "uid_1",
      sortKey: "0000000001:0000000001:0000000120:entry_1",
      score: 1200,
      distanceMeters: 400,
      durationSeconds: 120,
      entryId: "entry_1",
    }),
  );
  await boardRef.collection("player_bests").doc("uid_2").set(
    leaderboardEntryDoc({
      boardId,
      uid: "uid_2",
      sortKey: "0000000002:0000000002:0000000130:entry_2",
      score: 1100,
      distanceMeters: 390,
      durationSeconds: 130,
      entryId: "entry_2",
    }),
  );
  await boardRef.collection("player_bests").doc("uid_3").set(
    leaderboardEntryDoc({
      boardId,
      uid: "uid_3",
      sortKey: "0000000003:0000000003:0000000140:entry_3",
      score: 1000,
      distanceMeters: 380,
      durationSeconds: 140,
      entryId: "entry_3",
    }),
  );
}

function leaderboardEntryDoc(args: {
  boardId: string;
  uid: string;
  sortKey: string;
  score: number;
  distanceMeters: number;
  durationSeconds: number;
  entryId: string;
}): Record<string, unknown> {
  return {
    boardId: args.boardId,
    entryId: args.entryId,
    runSessionId: `run_${args.entryId}`,
    uid: args.uid,
    displayName: args.uid,
    characterId: "eloise",
    score: args.score,
    distanceMeters: args.distanceMeters,
    durationSeconds: args.durationSeconds,
    sortKey: args.sortKey,
    ghostEligible: false,
    updatedAtMs: 1700000000000,
  };
}

async function clearCollection(dbValue: Firestore, name: string): Promise<void> {
  const docs = await dbValue.collection(name).listDocuments();
  await Promise.all(docs.map((docRef) => dbValue.recursiveDelete(docRef)));
}
