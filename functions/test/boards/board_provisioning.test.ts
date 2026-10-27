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
import { pruneObsoleteLeaderboardBoards } from "../../src/boards/retention.js";
import {
  resolveCompetitiveWindow,
  resolveWeeklyWindow,
} from "../../src/boards/windowing.js";

import { currentGameCompatVersion } from "../../src/runs/compatibility.js";

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
  gameCompatVersion: currentGameCompatVersion,

  rulesetVersion: "rules-v2",
  scoreVersion: "score-v4",
  ghostVersion: "ghost-v1",
  tickHz: 60,
  seedNamespace: "tests-board-seed",
  status: "active",
};

beforeEach(async () => {
  await clearCollection(db, "leaderboard_boards");
  await clearCollection(db, "system_maintenance");
  await clearCollection(db, "run_sessions");
});

after(async () => {
  await Promise.all(getApps().map((value) => deleteApp(value)));
});

test("default provisioning config issues current combat and distance scoring", () => {
  assert.equal(resolveBoardProvisioningConfig({}).rulesetVersion, "rules-v2");
  assert.equal(resolveBoardProvisioningConfig({}).scoreVersion, "score-v4");
});

test("default provisioning creates only three current boards and rolls windows on demand", async () => {
  const nowMs = Date.UTC(2026, 9, 27);
  const first = await ensureManagedLeaderboardBoards({ db, nowMs, config });
  assert.equal(first.createdCount, 3);
  assert.equal((await db.collection("leaderboard_boards").get()).size, 3);
  const nextMs = resolveWeeklyWindow(nowMs).closesAtMs + 1;
  const next = await ensureManagedBoardForModeLevel({ db, mode: "weekly", levelId: "field", nowMs: nextMs, config });
  assert.equal(next.createdCount, 1);
});

test("retention dry run is read-only and protects current boards and active runs", async () => {
  const nowMs = Date.UTC(2026, 9, 27);
  await ensureManagedLeaderboardBoards({ db, nowMs, config, includeNextWindows: true });
  await ensureManagedLeaderboardBoards({ db, nowMs, config: { ...config, gameCompatVersion: "old" } });
  const old = (await db.collection("leaderboard_boards").where("gameCompatVersion", "==", "old").get()).docs[0]!;
  await db.collection("run_sessions").doc("active").set({ state: "validating", runTicket: { boardId: old.id } });
  const result = await pruneObsoleteLeaderboardBoards({ db, config, nowMs, supportedVersions: new Set([config.gameCompatVersion]) });
  assert.equal(result.candidates.length, 5);
  assert.equal(result.protectedCount, 4);
  assert.equal((await db.collection("leaderboard_boards").where("status", "==", "disabled").get()).size, 0);
  assert.equal((await db.doc("system_maintenance/board_retention").get()).exists, false);
});

test("retention preserves parents across grace, bounded child pages and Storage failure", async () => {
  const nowMs = Date.UTC(2026, 9, 27);
  await ensureManagedBoardForModeLevel({ db, mode: "competitive", levelId: "field", nowMs, config: { ...config, gameCompatVersion: "old" } });
  const board = (await db.collection("leaderboard_boards").get()).docs[0]!;
  const batch = db.batch();
  for (let index = 0; index < 101; index += 1) batch.set(board.ref.collection("player_bests").doc(`p${index}`), { uid: `u${index}` });
  await batch.commit();
  const base = { db, config, nowMs, supportedVersions: new Set([config.gameCompatVersion]), apply: true };
  const retired = await pruneObsoleteLeaderboardBoards({ ...base, deleteGhostPage: async () => { throw new Error("must wait"); } });
  assert.equal(retired.retiredCount, 1);
  assert.equal(retired.childDeleteCount, 0);
  const first = await pruneObsoleteLeaderboardBoards({ ...base, immediate: true });
  assert.equal(first.childDeleteCount, 100);
  assert.equal((await board.ref.get()).get("status"), "disabled");
  const second = await pruneObsoleteLeaderboardBoards({ ...base, immediate: true });
  assert.equal(second.childDeleteCount, 1);
  await assert.rejects(pruneObsoleteLeaderboardBoards({ ...base, immediate: true, deleteGhostPage: async () => { throw new Error("storage down"); } }), /storage down/);
  assert.equal((await board.ref.get()).exists, true);
  const afterGrace = await pruneObsoleteLeaderboardBoards({ ...base, nowMs: nowMs + 24 * 60 * 60 * 1000, deleteGhostPage: async () => 0 });
  assert.equal(afterGrace.deletedCount, 1);
  assert.equal((await board.ref.get()).exists, false);
});

test("retention refuses cutover pauses and configured draining versions", async () => {
  for (const versions of [new Set(["release-paused"]), new Set([config.gameCompatVersion, "old"])]) {
    await assert.rejects(pruneObsoleteLeaderboardBoards({ db, config, supportedVersions: versions, apply: true }), /one supported/);
  }
});

test("a previously retired future window is restored only when provisioned again", async () => {
  const nowMs = Date.UTC(2026, 9, 27);
  await ensureManagedLeaderboardBoards({ db, config, nowMs, includeNextWindows: true });
  await pruneObsoleteLeaderboardBoards({ db, config, nowMs, apply: true, supportedVersions: new Set([config.gameCompatVersion]) });
  const nextMs = resolveWeeklyWindow(nowMs).closesAtMs + 1;
  await ensureManagedBoardForModeLevel({ db, mode: "weekly", levelId: "field", config, nowMs: nextMs });
  const loaded = await loadActiveBoardManifest({ db, mode: "weekly", levelId: "field", gameCompatVersion: config.gameCompatVersion, nowMs: nextMs });
  assert.equal(loaded.status, "active");
  assert.equal((await db.collection("leaderboard_boards").doc(loaded.boardId).get()).get("retiredAtMs"), undefined);
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
    gameCompatVersion: "2026.10.1",
    scoreVersion: "score-v2",
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
    `board_competitive_2026_03_field_rules_v2_score_v4_${currentGameCompatVersion.replaceAll(".", "_")}_ghost_v1`,
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
  assert.equal(doc.get("gameCompatVersion"), currentGameCompatVersion);

  assert.equal(doc.get("boardKey.mode"), args.mode);
  assert.equal(doc.get("boardKey.levelId"), args.levelId);
  assert.equal(doc.get("boardKey.windowId"), args.windowId);
}

async function clearCollection(dbValue: Firestore, name: string): Promise<void> {
  const docs = await dbValue.collection(name).listDocuments();
  await Promise.all(docs.map((docRef) => dbValue.recursiveDelete(docRef)));
}
