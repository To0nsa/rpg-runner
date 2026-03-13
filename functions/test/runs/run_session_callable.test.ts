import assert from "node:assert/strict";
import { after, beforeEach, test } from "node:test";

import { deleteApp, getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, type Firestore } from "firebase-admin/firestore";

import { loadActiveBoardManifest } from "../../src/boards/store.js";
import { resolveCompetitiveWindow } from "../../src/boards/windowing.js";
import { loadOrCreateCanonicalState } from "../../src/ownership/canonical_store.js";
import {
  canonicalDocRef,
  defaultCanonicalProfileId,
} from "../../src/ownership/firestore_paths.js";
import { createRunSession } from "../../src/runs/store.js";

const firestoreEmulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
if (!firestoreEmulatorHost) {
  throw new Error(
    "FIRESTORE_EMULATOR_HOST is not set. Run via `firebase emulators:exec`.",
  );
}

const emulatorProjectIdBase =
  process.env.GCLOUD_PROJECT ?? "demo-rpg-runner-functions-tests";
const projectId = `${emulatorProjectIdBase}-runs`;
const appName = `run-session-tests-${process.pid}-${Date.now()}`;
const app = initializeApp({ projectId }, appName);
const db = getFirestore(app);

const uid = "uid_run_owner";

beforeEach(async () => {
  await Promise.all([
    clearCollection(db, "ownership_profiles"),
    clearCollection(db, "run_sessions"),
    clearCollection(db, "leaderboard_boards"),
  ]);
});

after(async () => {
  await Promise.all(getApps().map((value) => deleteApp(value)));
});

test("createRunSession issues boardless practice ticket from canonical selection", async () => {
  await loadOrCreateCanonicalState({ db, uid });

  const result = await createRunSession({
    db,
    uid,
    mode: "practice",
    levelId: "field",
    gameCompatVersion: "build-2026-03-12",
  });
  const ticket = result.runTicket;

  assert.equal(ticket.mode, "practice");
  assert.equal(ticket.levelId, "field");
  assert.equal(typeof ticket.runSessionId, "string");
  assert.equal(typeof ticket.seed, "number");
  assert.equal(typeof ticket.tickHz, "number");
  assert.equal(ticket.boardId, undefined);
  assert.equal(ticket.boardKey, undefined);
  assert.equal(ticket.rulesetVersion, undefined);
  assert.equal(ticket.scoreVersion, undefined);
  assert.equal(ticket.ghostVersion, undefined);

  const runSessionId = ticket.runSessionId as string;
  const persisted = await db.collection("run_sessions").doc(runSessionId).get();
  assert.equal(persisted.exists, true);
  assert.equal(persisted.get("state"), "issued");
});

test("loadActiveBoardManifest rejects disabled board for current window", async () => {
  const nowMs = Date.UTC(2026, 2, 12, 12, 0, 0, 0);
  const window = resolveCompetitiveWindow(nowMs);
  await db.collection("leaderboard_boards").doc("board_disabled").set({
    boardId: "board_disabled",
    mode: "competitive",
    levelId: "field",
    windowId: window.windowId,
    boardKey: {
      mode: "competitive",
      levelId: "field",
      windowId: window.windowId,
      rulesetVersion: "rules-v1",
      scoreVersion: "score-v1",
    },
    gameCompatVersion: "build-2026-03-12",
    ghostVersion: "ghost-v1",
    tickHz: 60,
    seed: 314159,
    opensAtMs: window.opensAtMs,
    closesAtMs: window.closesAtMs,
    status: "disabled",
  });

  await assert.rejects(
    () =>
      loadActiveBoardManifest({
        db,
        mode: "competitive",
        levelId: "field",
        gameCompatVersion: "build-2026-03-12",
        nowMs,
      }),
    (error: { code?: string; message?: string }) =>
      error.code === "failed-precondition" &&
      (error.message ?? "").includes("disabled"),
  );
});

test("createRunSession binds competitive ticket to active monthly board", async () => {
  const nowMs = Date.UTC(2026, 2, 12, 12, 0, 0, 0);
  const window = resolveCompetitiveWindow(nowMs);
  const gameCompatVersion = "build-2026-03-12";

  await loadOrCreateCanonicalState({ db, uid });
  const canonicalRef = canonicalDocRef(db, uid, defaultCanonicalProfileId);
  await canonicalRef.set(
    {
      selection: {
        schemaVersion: 1,
        levelId: "field",
        runMode: "competitive",
        runType: "competitive",
        characterId: "eloise",
        buildName: "Build 1",
        loadoutsByCharacter: {
          eloise: {
            mask: 7,
            mainWeaponId: "plainsteel",
            offhandWeaponId: "roadguard",
            spellBookId: "apprenticePrimer",
            projectileSlotSpellId: "acidBolt",
            accessoryId: "strengthBelt",
            abilityPrimaryId: "eloise.seeker_slash",
            abilitySecondaryId: "eloise.shield_block",
            abilityProjectileId: "eloise.snap_shot",
            abilitySpellId: "eloise.arcane_haste",
            abilityMobilityId: "eloise.dash",
            abilityJumpId: "eloise.jump",
          },
          eloiseWip: {
            mask: 7,
            mainWeaponId: "plainsteel",
            offhandWeaponId: "roadguard",
            spellBookId: "apprenticePrimer",
            projectileSlotSpellId: "acidBolt",
            accessoryId: "strengthBelt",
            abilityPrimaryId: "eloise.seeker_slash",
            abilitySecondaryId: "eloise.shield_block",
            abilityProjectileId: "eloise.snap_shot",
            abilitySpellId: "eloise.arcane_haste",
            abilityMobilityId: "eloise.dash",
            abilityJumpId: "eloise.jump",
          },
        },
      },
    },
    { merge: true },
  );

  await db.collection("leaderboard_boards").doc("board_competitive").set({
    boardId: "board_competitive",
    mode: "competitive",
    levelId: "field",
    windowId: window.windowId,
    boardKey: {
      mode: "competitive",
      levelId: "field",
      windowId: window.windowId,
      rulesetVersion: "rules-v1",
      scoreVersion: "score-v1",
    },
    gameCompatVersion,
    ghostVersion: "ghost-v1",
    tickHz: 60,
    seed: 424242,
    opensAtMs: window.opensAtMs,
    closesAtMs: window.closesAtMs,
    status: "active",
  });

  const result = await createRunSession({
    db,
    uid,
    mode: "competitive",
    levelId: "field",
    gameCompatVersion,
    nowMs,
  });
  const ticket = result.runTicket;

  assert.equal(ticket.mode, "competitive");
  assert.equal(ticket.boardId, "board_competitive");
  assert.deepEqual(ticket.boardKey, {
    mode: "competitive",
    levelId: "field",
    windowId: window.windowId,
    rulesetVersion: "rules-v1",
    scoreVersion: "score-v1",
  });
  assert.equal(ticket.rulesetVersion, "rules-v1");
  assert.equal(ticket.scoreVersion, "score-v1");
  assert.equal(ticket.ghostVersion, "ghost-v1");
  assert.equal(ticket.gameCompatVersion, gameCompatVersion);
  assert.equal(ticket.seed, 424242);
});

test("createRunSession rejects stale level mismatch between request and canonical selection", async () => {
  await loadOrCreateCanonicalState({ db, uid });

  await assert.rejects(
    () =>
      createRunSession({
        db,
        uid,
        mode: "practice",
        levelId: "forest",
        gameCompatVersion: "build-2026-03-12",
      }),
    (error: { code?: string; message?: string }) =>
      error.code === "failed-precondition" &&
      (error.message ?? "").includes("level"),
  );
});

test("createRunSession rejects mode mismatch between request and canonical selection", async () => {
  await loadOrCreateCanonicalState({ db, uid });
  const canonicalRef = canonicalDocRef(db, uid, defaultCanonicalProfileId);
  await canonicalRef.set(
    {
      selection: {
        runMode: "competitive",
        runType: "competitive",
      },
    },
    { merge: true },
  );

  await assert.rejects(
    () =>
      createRunSession({
        db,
        uid,
        mode: "practice",
        levelId: "field",
        gameCompatVersion: "build-2026-03-12",
      }),
    (error: { code?: string; message?: string }) =>
      error.code === "failed-precondition" &&
      (error.message ?? "").includes("mode"),
  );
});

test("resolveCompetitiveWindow rolls at UTC month boundary", () => {
  const marchLastMs = Date.UTC(2026, 2, 31, 23, 59, 59, 999);
  const aprilFirstMs = Date.UTC(2026, 3, 1, 0, 0, 0, 0);
  const marchWindow = resolveCompetitiveWindow(marchLastMs);
  const aprilWindow = resolveCompetitiveWindow(aprilFirstMs);

  assert.equal(marchWindow.windowId, "2026-03");
  assert.equal(marchWindow.opensAtMs, Date.UTC(2026, 2, 1, 0, 0, 0, 0));
  assert.equal(marchWindow.closesAtMs, Date.UTC(2026, 3, 1, 0, 0, 0, 0));

  assert.equal(aprilWindow.windowId, "2026-04");
  assert.equal(aprilWindow.opensAtMs, Date.UTC(2026, 3, 1, 0, 0, 0, 0));
  assert.equal(aprilWindow.closesAtMs, Date.UTC(2026, 4, 1, 0, 0, 0, 0));
});

test("createRunSession resolves board by month window across rollover", async () => {
  const marchLastMs = Date.UTC(2026, 2, 31, 23, 59, 59, 999);
  const aprilFirstMs = Date.UTC(2026, 3, 1, 0, 0, 0, 0);
  const gameCompatVersion = "build-2026-03-12";

  await loadOrCreateCanonicalState({ db, uid });
  const canonicalRef = canonicalDocRef(db, uid, defaultCanonicalProfileId);
  await canonicalRef.set(
    {
      selection: {
        runMode: "competitive",
        runType: "competitive",
      },
    },
    { merge: true },
  );

  const marchWindow = resolveCompetitiveWindow(marchLastMs);
  const aprilWindow = resolveCompetitiveWindow(aprilFirstMs);

  await db.collection("leaderboard_boards").doc("board_march").set({
    boardId: "board_march",
    mode: "competitive",
    levelId: "field",
    windowId: marchWindow.windowId,
    boardKey: {
      mode: "competitive",
      levelId: "field",
      windowId: marchWindow.windowId,
      rulesetVersion: "rules-v1",
      scoreVersion: "score-v1",
    },
    gameCompatVersion,
    ghostVersion: "ghost-v1",
    tickHz: 60,
    seed: 30303,
    opensAtMs: marchWindow.opensAtMs,
    closesAtMs: marchWindow.closesAtMs,
    status: "active",
  });
  await db.collection("leaderboard_boards").doc("board_april").set({
    boardId: "board_april",
    mode: "competitive",
    levelId: "field",
    windowId: aprilWindow.windowId,
    boardKey: {
      mode: "competitive",
      levelId: "field",
      windowId: aprilWindow.windowId,
      rulesetVersion: "rules-v1",
      scoreVersion: "score-v1",
    },
    gameCompatVersion,
    ghostVersion: "ghost-v1",
    tickHz: 60,
    seed: 40404,
    opensAtMs: aprilWindow.opensAtMs,
    closesAtMs: aprilWindow.closesAtMs,
    status: "active",
  });

  const marchResult = await createRunSession({
    db,
    uid,
    mode: "competitive",
    levelId: "field",
    gameCompatVersion,
    nowMs: marchLastMs,
  });
  assert.equal(marchResult.runTicket.boardId, "board_march");
  assert.equal(
    (marchResult.runTicket.boardKey as { windowId: string }).windowId,
    "2026-03",
  );

  const aprilResult = await createRunSession({
    db,
    uid,
    mode: "competitive",
    levelId: "field",
    gameCompatVersion,
    nowMs: aprilFirstMs,
  });
  assert.equal(aprilResult.runTicket.boardId, "board_april");
  assert.equal(
    (aprilResult.runTicket.boardKey as { windowId: string }).windowId,
    "2026-04",
  );
});

async function clearCollection(dbValue: Firestore, name: string): Promise<void> {
  const docs = await dbValue.collection(name).listDocuments();
  await Promise.all(docs.map((docRef) => dbValue.recursiveDelete(docRef)));
}
