import { randomInt, randomUUID } from "node:crypto";

import type { Firestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

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
  const canonicalState = await loadOrCreateCanonicalState({
    db: args.db,
    uid: args.uid,
  });
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

  let runTicket: JsonObject;
  if (runModeRequiresBoard(snapshot.mode)) {
    if (snapshot.mode === "practice") {
      throw new HttpsError(
        "failed-precondition",
        "Practice mode cannot require a board.",
      );
    }
    const boardManifest = await loadActiveBoardManifest({
      db: args.db,
      mode: snapshot.mode,
      levelId: snapshot.levelId,
      gameCompatVersion: args.gameCompatVersion,
      nowMs,
    });
    runTicket = {
      runSessionId,
      uid: args.uid,
      mode: snapshot.mode,
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
    state: runSessionIssuedState,
    levelId: snapshot.levelId,
    playerCharacterId: snapshot.playerCharacterId,
    loadoutDigest,
    issuedAtMs,
    expiresAtMs,
    updatedAtMs: issuedAtMs,
    createdAtMs: issuedAtMs,
    runTicket,
  };
  await args.db.collection(runSessionsCollection).doc(runSessionId).set(runSessionDoc);
  return { runTicket };
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

