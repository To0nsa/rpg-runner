import assert from "node:assert/strict";
import { after, beforeEach, test } from "node:test";

import { deleteApp, getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, type Firestore } from "firebase-admin/firestore";

import {
  buildManagedBoardId,
  ensureManagedBoardForModeLevel,
  ensureManagedLeaderboardBoards,
  resolveBoardProvisioningConfig,
  type BoardProvisioningConfig,
} from "../../src/boards/provisioning.js";
import { loadActiveBoardManifest } from "../../src/boards/store.js";
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
  gameCompatVersion: "2026.08.0",
  rulesetVersion: "rules-v2",
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

test("default provisioning config issues the capsule-combat ruleset", () => {
  assert.equal(resolveBoardProvisioningConfig({}).rulesetVersion, "rules-v2");
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

test("rules-v2 selection ignores a coexisting active rules-v1 board", async () => {
  const nowMs = Date.UTC(2026, 2, 14, 12, 0, 0, 0);
  const retiredConfig: BoardProvisioningConfig = {
    ...config,
    rulesetVersion: "rules-v1",
  };
  await ensureManagedBoardForModeLevel({
    db,
    mode: "competitive",
    levelId: "field",
    nowMs,
    config: retiredConfig,
    includeNextWindows: false,
  });
  await ensureManagedBoardForModeLevel({
    db,
    mode: "competitive",
    levelId: "field",
    nowMs,
    config,
    includeNextWindows: false,
  });

  const loaded = await loadActiveBoardManifest({
    db,
    mode: "competitive",
    levelId: "field",
    gameCompatVersion: config.gameCompatVersion,
    rulesetVersion: config.rulesetVersion,
    scoreVersion: config.scoreVersion,
    ghostVersion: config.ghostVersion,
    nowMs,
  });

  assert.equal(loaded.boardKey.rulesetVersion, "rules-v2");
  assert.match(loaded.boardId, /rules_v2/);
});

test("same-window boards coexist across compatibility versions", async () => {
  const nowMs = Date.UTC(2026, 2, 14, 12, 0, 0, 0);
  const drainingConfig: BoardProvisioningConfig = {
    ...config,
    gameCompatVersion: "2026.03.0",
  };

  const draining = await ensureManagedBoardForModeLevel({
    db,
    mode: "competitive",
    levelId: "field",
    nowMs,
    config: drainingConfig,
    includeNextWindows: false,
  });
  const current = await ensureManagedBoardForModeLevel({
    db,
    mode: "competitive",
    levelId: "field",
    nowMs,
    config,
    includeNextWindows: false,
  });
  const currentReplay = await ensureManagedBoardForModeLevel({
    db,
    mode: "competitive",
    levelId: "field",
    nowMs,
    config,
    includeNextWindows: false,
  });

  assert.equal(draining.createdCount, 1);
  assert.equal(current.createdCount, 1);
  assert.equal(currentReplay.existingCount, 1);

  const window = resolveCompetitiveWindow(nowMs);
  const drainingId = buildManagedBoardId({
    mode: "competitive",
    levelId: "field",
    windowId: window.windowId,
    rulesetVersion: drainingConfig.rulesetVersion,
    scoreVersion: drainingConfig.scoreVersion,
    gameCompatVersion: drainingConfig.gameCompatVersion,
    ghostVersion: drainingConfig.ghostVersion,
  });
  const currentId = buildManagedBoardId({
    mode: "competitive",
    levelId: "field",
    windowId: window.windowId,
    rulesetVersion: config.rulesetVersion,
    scoreVersion: config.scoreVersion,
    gameCompatVersion: config.gameCompatVersion,
    ghostVersion: config.ghostVersion,
  });
  assert.notEqual(currentId, drainingId);
  assert.equal(
    currentId,
    "board_competitive_2026_03_field_rules_v2_score_v1_2026_08_0_ghost_v1",
  );

  const boards = await db.collection("leaderboard_boards").get();
  assert.equal(boards.size, 2);
  assert.equal(
    (await db.collection("leaderboard_boards").doc(drainingId).get()).exists,
    true,
  );
  assert.equal(
    (await db.collection("leaderboard_boards").doc(currentId).get()).exists,
    true,
  );

  const loadedDraining = await loadActiveBoardManifest({
    db,
    mode: "competitive",
    levelId: "field",
    gameCompatVersion: drainingConfig.gameCompatVersion,
    nowMs,
  });
  const loadedCurrent = await loadActiveBoardManifest({
    db,
    mode: "competitive",
    levelId: "field",
    gameCompatVersion: config.gameCompatVersion,
    nowMs,
  });
  assert.equal(loadedDraining.boardId, drainingId);
  assert.equal(loadedCurrent.boardId, currentId);
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
  assert.equal(doc.get("gameCompatVersion"), "2026.08.0");
  assert.equal(doc.get("boardKey.mode"), args.mode);
  assert.equal(doc.get("boardKey.levelId"), args.levelId);
  assert.equal(doc.get("boardKey.windowId"), args.windowId);
}

async function clearCollection(dbValue: Firestore, name: string): Promise<void> {
  const docs = await dbValue.collection(name).listDocuments();
  await Promise.all(docs.map((docRef) => dbValue.recursiveDelete(docRef)));
}
