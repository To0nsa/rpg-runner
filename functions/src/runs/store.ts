import { randomInt, randomUUID } from "node:crypto";

import type { Firestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

import { ensureManagedBoardForModeLevel } from "../boards/provisioning.js";
import { loadActiveBoardManifest } from "../boards/store.js";
import { loadOrCreateCanonicalState } from "../ownership/canonical_store.js";
import type { JsonObject, JsonValue } from "../ownership/contracts.js";
import { canonicalJsonString, sha256Hex } from "../ownership/hash.js";
import {
  parseRunMode,
  runModeRequiresBoard,
  type RunModeValue,
} from "./mode.js";

const runSessionsCollection = "run_sessions";
const runSessionIssuedState = "issued";
const defaultTickHz = 60;
const runSessionExpiryMs = 24 * 60 * 60 * 1000;

interface CreateRunSessionArgs {
  db: Firestore;
  uid: string;
  mode: RunModeValue;
  levelId: string;
  gameCompatVersion: string;
  nowMs?: number;
}

interface StartSnapshot {
  mode: RunModeValue;
  levelId: string;
  playerCharacterId: string;
  loadoutSnapshot: JsonObject;
}

export interface CreateRunSessionResult {
  runTicket: JsonObject;
}

export async function createRunSession(
  args: CreateRunSessionArgs,
): Promise<CreateRunSessionResult> {
  const nowMs = args.nowMs ?? Date.now();
  const startedAtMs = Date.now();
  let canonicalLoadMs = 0;
  let boardResolveMs = 0;
  let runSessionWriteMs = 0;
  let boardEnsureAttempted = false;

  const canonicalLoadStartMs = Date.now();
  const canonicalState = await loadOrCreateCanonicalState({
    db: args.db,
    uid: args.uid,
  });
  canonicalLoadMs = Date.now() - canonicalLoadStartMs;
  const snapshot = deriveStartSnapshot(canonicalState.selection);

  if (snapshot.mode !== args.mode) {
    throw new HttpsError(
      "failed-precondition",
      "Requested mode does not match authoritative selection state.",
    );
  }
  if (snapshot.levelId !== args.levelId) {
    throw new HttpsError(
      "failed-precondition",
      "Requested level does not match authoritative selection state.",
    );
  }

  const runSessionId = randomUUID();
  const singleUseNonce = randomUUID();
  const issuedAtMs = nowMs;
  const expiresAtMs = issuedAtMs + runSessionExpiryMs;
  const loadoutDigest = sha256Hex(
    canonicalJsonString(snapshot.loadoutSnapshot as JsonValue),
  );

  let boardContext:
    | {
        boardId: string;
        boardKey: JsonObject;
        seed: number;
        tickHz: number;
        gameCompatVersion: string;
        rulesetVersion: string;
        scoreVersion: string;
        ghostVersion: string;
      }
    | undefined;
  let runTicket: JsonObject;
  if (runModeRequiresBoard(snapshot.mode)) {
    if (snapshot.mode === "practice") {
      throw new HttpsError(
        "failed-precondition",
        "Practice mode cannot require a board.",
      );
    }

    const boardResolveStartMs = Date.now();
    const boardManifest = await loadBoardManifestWithProvisioningFallback({
      db: args.db,
      mode: snapshot.mode,
      levelId: snapshot.levelId,
      gameCompatVersion: args.gameCompatVersion,
      nowMs,
      onEnsureAttempt: () => {
        boardEnsureAttempted = true;
      },
    });
    boardResolveMs = Date.now() - boardResolveStartMs;

    boardContext = {
      boardId: boardManifest.boardId,
      boardKey: {
        mode: boardManifest.boardKey.mode,
        levelId: boardManifest.boardKey.levelId,
        windowId: boardManifest.boardKey.windowId,
        rulesetVersion: boardManifest.boardKey.rulesetVersion,
        scoreVersion: boardManifest.boardKey.scoreVersion,
      },
      seed: boardManifest.seed,
      tickHz: boardManifest.tickHz,
      gameCompatVersion: boardManifest.gameCompatVersion,
      rulesetVersion: boardManifest.boardKey.rulesetVersion,
      scoreVersion: boardManifest.boardKey.scoreVersion,
      ghostVersion: boardManifest.ghostVersion,
    };

    runTicket = {
      runSessionId,
      uid: args.uid,
      mode: snapshot.mode,
      boardId: boardContext.boardId,
      boardKey: boardContext.boardKey,
      seed: boardContext.seed,
      tickHz: boardContext.tickHz,
      gameCompatVersion: boardContext.gameCompatVersion,
      rulesetVersion: boardContext.rulesetVersion,
      scoreVersion: boardContext.scoreVersion,
      ghostVersion: boardContext.ghostVersion,
      levelId: snapshot.levelId,
      playerCharacterId: snapshot.playerCharacterId,
      loadoutSnapshot: snapshot.loadoutSnapshot,
      loadoutDigest,
      issuedAtMs,
      expiresAtMs,
      singleUseNonce,
    };
  } else {
    runTicket = {
      runSessionId,
      uid: args.uid,
      mode: snapshot.mode,
      seed: randomInt(1, 0x7fffffff),
      tickHz: defaultTickHz,
      gameCompatVersion: args.gameCompatVersion,
      levelId: snapshot.levelId,
      playerCharacterId: snapshot.playerCharacterId,
      loadoutSnapshot: snapshot.loadoutSnapshot,
      loadoutDigest,
      issuedAtMs,
      expiresAtMs,
      singleUseNonce,
    };
  }

  const runSessionDoc: JsonObject = {
    runSessionId,
    uid: args.uid,
    mode: snapshot.mode,
    ...(boardContext
      ? {
          boardId: boardContext.boardId,
          boardKey: boardContext.boardKey,
        }
      : {}),
    state: runSessionIssuedState,
    levelId: snapshot.levelId,
    playerCharacterId: snapshot.playerCharacterId,
    loadoutDigest,
    issuedAtMs,
    expiresAtMs,
    updatedAtMs: issuedAtMs,
    createdAtMs: issuedAtMs,
  };

  const runSessionWriteStartMs = Date.now();
  await args.db.collection(runSessionsCollection).doc(runSessionId).set(runSessionDoc);
  runSessionWriteMs = Date.now() - runSessionWriteStartMs;

  const totalMs = Date.now() - startedAtMs;
  console.log("runSessionCreate_timing", {
    mode: snapshot.mode,
    levelId: snapshot.levelId,
    boardRequired: runModeRequiresBoard(snapshot.mode),
    boardEnsureAttempted,
    canonicalLoadMs,
    boardResolveMs,
    runSessionWriteMs,
    totalMs,
  });

  return { runTicket };
}

async function loadBoardManifestWithProvisioningFallback(args: {
  db: Firestore;
  mode: Exclude<RunModeValue, "practice">;
  levelId: string;
  gameCompatVersion: string;
  nowMs: number;
  onEnsureAttempt: () => void;
}) {
  try {
    return await loadActiveBoardManifest({
      db: args.db,
      mode: args.mode,
      levelId: args.levelId,
      gameCompatVersion: args.gameCompatVersion,
      nowMs: args.nowMs,
    });
  } catch (error) {
    if (!isMissingBoardError(error)) {
      throw error;
    }
  }

  args.onEnsureAttempt();
  await ensureManagedBoardForModeLevel({
    db: args.db,
    mode: args.mode,
    levelId: args.levelId,
    nowMs: args.nowMs,
    includeNextWindows: false,
  });

  return loadActiveBoardManifest({
    db: args.db,
    mode: args.mode,
    levelId: args.levelId,
    gameCompatVersion: args.gameCompatVersion,
    nowMs: args.nowMs,
  });
}

function isMissingBoardError(error: unknown): boolean {
  if (!(error instanceof HttpsError)) {
    return false;
  }
  if (error.code !== "failed-precondition") {
    return false;
  }
  return error.message.startsWith("No board found for ");
}

function deriveStartSnapshot(selection: JsonObject): StartSnapshot {
  const modeRaw =
    typeof selection.runMode === "string"
      ? selection.runMode
      : selection.runType;
  const mode = parseRunMode(modeRaw, "selection.runMode");
  const levelId = requireSelectionString(selection.levelId, "selection.levelId");
  const playerCharacterId = requireSelectionString(
    selection.characterId,
    "selection.characterId",
  );
  const loadoutsByCharacter = requireSelectionObject(
    selection.loadoutsByCharacter,
    "selection.loadoutsByCharacter",
  );
  const loadoutRaw = loadoutsByCharacter[playerCharacterId];
  const loadoutSnapshot = requireSelectionObject(
    loadoutRaw,
    `selection.loadoutsByCharacter.${playerCharacterId}`,
  );
  return {
    mode,
    levelId,
    playerCharacterId,
    loadoutSnapshot: structuredClone(loadoutSnapshot),
  };
}

function requireSelectionString(value: unknown, fieldName: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError(
      "failed-precondition",
      `${fieldName} is missing from canonical selection state.`,
    );
  }
  return value.trim();
}

function requireSelectionObject(value: unknown, fieldName: string): JsonObject {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpsError(
      "failed-precondition",
      `${fieldName} must be an object in canonical selection state.`,
    );
  }
  return value as JsonObject;
}
