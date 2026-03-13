import assert from "node:assert/strict";
import { after, beforeEach, test } from "node:test";

import { deleteApp, getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, type Firestore } from "firebase-admin/firestore";

import { resolveCompetitiveWindow } from "../../src/boards/windowing.js";
import {
  handleRunBoardsLoadActive,
  handleRunSessionCreate,
} from "../../src/runs/callable_handlers.js";

const firestoreEmulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
if (!firestoreEmulatorHost) {
  throw new Error(
    "FIRESTORE_EMULATOR_HOST is not set. Run via `firebase emulators:exec`.",
  );
}

const emulatorProjectIdBase =
  process.env.GCLOUD_PROJECT ?? "demo-rpg-runner-functions-tests";
const projectId = `${emulatorProjectIdBase}-run-callables`;
const appName = `run-callable-tests-${process.pid}-${Date.now()}`;
const app = initializeApp({ projectId }, appName);
const db = getFirestore(app);

const uid = "uid_run_callable_owner";

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

test("handleRunSessionCreate rejects unauthenticated requests", async () => {
  await assert.rejects(
    () => handleRunSessionCreate(callableRequest(validRunSessionPayload()), db),
    (error: { code?: string }) => error.code === "unauthenticated",
  );
});

test("handleRunSessionCreate rejects userId/auth uid mismatch", async () => {
  await assert.rejects(
    () =>
      handleRunSessionCreate(
        callableRequest(
          validRunSessionPayload({ userId: "uid_attacker" }),
          uid,
        ),
        db,
      ),
    (error: { code?: string }) => error.code === "permission-denied",
  );
});

test("handleRunBoardsLoadActive rejects unauthenticated requests", async () => {
  await assert.rejects(
    () => handleRunBoardsLoadActive(callableRequest(validBoardLoadPayload()), db),
    (error: { code?: string }) => error.code === "unauthenticated",
  );
});

test("handleRunBoardsLoadActive rejects userId/auth uid mismatch", async () => {
  await assert.rejects(
    () =>
      handleRunBoardsLoadActive(
        callableRequest(validBoardLoadPayload({ userId: "uid_attacker" }), uid),
        db,
      ),
    (error: { code?: string }) => error.code === "permission-denied",
  );
});

test("handleRunBoardsLoadActive rejects practice mode requests", async () => {
  await assert.rejects(
    () =>
      handleRunBoardsLoadActive(
        callableRequest(validBoardLoadPayload({ mode: "practice" }), uid),
        db,
      ),
    (error: { code?: string }) => error.code === "invalid-argument",
  );
});

test("handleRunBoardsLoadActive rejects game compatibility mismatch", async () => {
  const nowMs = Date.UTC(2026, 2, 12, 12, 0, 0, 0);
  const window = resolveCompetitiveWindow(nowMs);
  await db.collection("leaderboard_boards").doc("board_compat").set({
    boardId: "board_compat",
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
    gameCompatVersion: "build-2026-03-11",
    ghostVersion: "ghost-v1",
    tickHz: 60,
    seed: 1111,
    opensAtMs: window.opensAtMs,
    closesAtMs: window.closesAtMs,
    status: "active",
  });

  await assert.rejects(
    () =>
      handleRunBoardsLoadActive(
        callableRequest(
          validBoardLoadPayload({
            gameCompatVersion: "build-2026-03-12",
            nowMs,
          }),
          uid,
        ),
        db,
      ),
    (error: { code?: string; message?: string }) =>
      error.code === "failed-precondition" &&
      (error.message ?? "").includes("gameCompatVersion"),
  );
});

function callableRequest(
  data: Record<string, unknown>,
  authUid?: string,
): { auth?: { uid?: string } | null; data: unknown } {
  if (!authUid) {
    return { data };
  }
  return {
    data,
    auth: {
      uid: authUid,
    },
  };
}

function validRunSessionPayload(
  overrides: Partial<Record<string, unknown>> = {},
): Record<string, unknown> {
  return {
    userId: uid,
    sessionId: "session_1",
    mode: "practice",
    levelId: "field",
    gameCompatVersion: "build-2026-03-12",
    ...overrides,
  };
}

function validBoardLoadPayload(
  overrides: Partial<Record<string, unknown>> = {},
): Record<string, unknown> {
  return {
    userId: uid,
    sessionId: "session_1",
    mode: "competitive",
    levelId: "field",
    gameCompatVersion: "build-2026-03-12",
    ...overrides,
  };
}

async function clearCollection(dbValue: Firestore, name: string): Promise<void> {
  const docs = await dbValue.collection(name).listDocuments();
  await Promise.all(docs.map((docRef) => dbValue.recursiveDelete(docRef)));
}

