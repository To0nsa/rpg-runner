import assert from "node:assert/strict";
import { after, beforeEach, test } from "node:test";

import { deleteApp, getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, type Firestore } from "firebase-admin/firestore";

import {
  ensureManagedBoardForModeLevel,
  ensureManagedLeaderboardBoards,
  type BoardProvisioningConfig,
} from "../../src/boards/provisioning.js";
import {
  resolveCompetitiveWindow,
  resolveWeeklyWindow,
} from "../../src/boards/windowing.js";

const firestoreEmulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
if (!firestoreEmulatorHost) {
  throw new Error(
    "FIRESTORE_EMULATOR_HOST is not set. Run via `firebase emulators:exec`.",
  );
}

const emulatorProjectIdBase =
  process.env.GCLOUD_PROJECT ?? "demo-rpg-runner-functions-tests";
const projectId = `${emulatorProjectIdBase}-boards`;
const appName = `board-provisioning-tests-${process.pid}-${Date.now()}`;
const app = initializeApp({ projectId }, appName);
const db = getFirestore(app);

const config: BoardProvisioningConfig = {
  competitiveLevelIds: ["field", "forest"],
  weeklyLevelId: "field",
  gameCompatVersion: "2026.03.0",
  rulesetVersion: "rules-v1",
  scoreVersion: "score-v1",
  ghostVersion: "ghost-v1",
  tickHz: 60,
  seedNamespace: "tests-board-seed",
  status: "active",
};

beforeEach(async () => {
  await clearCollection(db, "leaderboard_boards");
});

after(async () => {
  await Promise.all(getApps().map((value) => deleteApp(value)));
});

test("ensureManagedLeaderboardBoards provisions competitive all-levels and weekly featured-level", async () => {
  const nowMs = Date.UTC(2026, 2, 14, 12, 0, 0, 0);
  const result = await ensureManagedLeaderboardBoards({
    db,
    nowMs,
    config,
    includeNextWindows: true,
  });
  assert.equal(result.checkedCount, 6);
  assert.equal(result.createdCount, 6);
  assert.equal(result.existingCount, 0);
  assert.equal(result.skippedUnmanagedLevelCount, 0);

  const competitiveCurrent = resolveCompetitiveWindow(nowMs);
  const competitiveNext = resolveCompetitiveWindow(competitiveCurrent.closesAtMs + 1);
  const weeklyCurrent = resolveWeeklyWindow(nowMs);
  const weeklyNext = resolveWeeklyWindow(weeklyCurrent.closesAtMs + 1);

  await assertBoardExists({
    db,
    mode: "competitive",
    levelId: "field",
    windowId: competitiveCurrent.windowId,
  });
  await assertBoardExists({
    db,
    mode: "competitive",
    levelId: "field",
    windowId: competitiveNext.windowId,
  });
  await assertBoardExists({
    db,
    mode: "competitive",
    levelId: "forest",
    windowId: competitiveCurrent.windowId,
  });
  await assertBoardExists({
    db,
    mode: "competitive",
    levelId: "forest",
    windowId: competitiveNext.windowId,
  });
  await assertBoardExists({
    db,
    mode: "weekly",
    levelId: "field",
    windowId: weeklyCurrent.windowId,
  });
  await assertBoardExists({
    db,
    mode: "weekly",
    levelId: "field",
    windowId: weeklyNext.windowId,
  });

  const weeklyForest = await db
    .collection("leaderboard_boards")
    .where("mode", "==", "weekly")
    .where("levelId", "==", "forest")
    .get();
  assert.equal(weeklyForest.empty, true);
});

test("ensureManagedBoardForModeLevel is idempotent", async () => {
  const nowMs = Date.UTC(2026, 2, 14, 12, 0, 0, 0);
  const first = await ensureManagedBoardForModeLevel({
    db,
    mode: "competitive",
    levelId: "field",
    nowMs,
    config,
    includeNextWindows: false,
  });
  const second = await ensureManagedBoardForModeLevel({
    db,
    mode: "competitive",
    levelId: "field",
    nowMs,
    config,
    includeNextWindows: false,
  });

  assert.equal(first.createdCount, 1);
  assert.equal(first.existingCount, 0);
  assert.equal(second.createdCount, 0);
  assert.equal(second.existingCount, 1);
});

test("ensureManagedBoardForModeLevel skips unmanaged weekly level", async () => {
  const nowMs = Date.UTC(2026, 2, 14, 12, 0, 0, 0);
  const result = await ensureManagedBoardForModeLevel({
    db,
    mode: "weekly",
    levelId: "forest",
    nowMs,
    config,
    includeNextWindows: false,
  });

  assert.equal(result.checkedCount, 0);
  assert.equal(result.createdCount, 0);
  assert.equal(result.existingCount, 0);
  assert.equal(result.skippedUnmanagedLevelCount, 1);

  const docs = await db.collection("leaderboard_boards").get();
  assert.equal(docs.size, 0);
});

async function assertBoardExists(args: {
  db: Firestore;
  mode: "competitive" | "weekly";
  levelId: string;
  windowId: string;
}): Promise<void> {
  const snapshot = await args.db
    .collection("leaderboard_boards")
    .where("mode", "==", args.mode)
    .where("levelId", "==", args.levelId)
    .where("windowId", "==", args.windowId)
    .limit(1)
    .get();
  assert.equal(snapshot.empty, false);
  const doc = snapshot.docs[0]!;
  assert.equal(doc.get("status"), "active");
  assert.equal(doc.get("tickHz"), 60);
  assert.equal(doc.get("gameCompatVersion"), "2026.03.0");
  assert.equal(doc.get("boardKey.mode"), args.mode);
  assert.equal(doc.get("boardKey.levelId"), args.levelId);
  assert.equal(doc.get("boardKey.windowId"), args.windowId);
}

async function clearCollection(dbValue: Firestore, name: string): Promise<void> {
  const docs = await dbValue.collection(name).listDocuments();
  await Promise.all(docs.map((docRef) => dbValue.recursiveDelete(docRef)));
}
