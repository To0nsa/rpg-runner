import { randomInt, randomUUID } from "node:crypto";

import type { Firestore } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { HttpsError } from "firebase-functions/v2/https";

import { assertAccountActiveInTransaction } from "../account/deletion_guard.js";
import {
  defaultRunActiveSessionsLimit,
  readAbuseControlMode,
  readOptionalBoundedAbuseLimit,
} from "../abuse/quota.js";
import {
  ensureManagedBoardForModeLevel,
  resolveBoardProvisioningConfigForGameCompatVersion,
} from "../boards/provisioning.js";
import { loadActiveBoardManifest } from "../boards/store.js";
import { loadOrCreateCanonicalState } from "../ownership/canonical_store.js";
import { normalizeAuthorizedLoadout } from "../ownership/loadout_authorization.js";
import type { JsonObject, JsonValue } from "../ownership/contracts.js";
import { canonicalJsonString, sha256Hex } from "../ownership/hash.js";
import {
  parseRunMode,
  runModeRequiresBoard,
  type RunModeValue,
} from "./mode.js";
import { assertSupportedGameCompatVersion } from "./compatibility.js";

const runSessionsCollection = "run_sessions";
const runSessionIssuedState = "issued";
const defaultTickHz = 60;
const runSessionExpiryMs = 24 * 60 * 60 * 1000;
const activeSessionScanCap = 256;
const activeSessionStates = [
  "issued",
  "uploading",
  "uploaded",
  "pending_validation",
  "validating",
  "settlement_pending",
] as const;

interface CreateRunSessionArgs {
  db: Firestore;
  uid: string;
  clientRequestId?: string;
  mode: RunModeValue;
  levelId: string;
  gameCompatVersion: string;
  supportedGameCompatVersions?: ReadonlySet<string>;
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
  assertSupportedGameCompatVersion(
    args.gameCompatVersion,
    args.supportedGameCompatVersions,
  );
  const nowMs = args.nowMs ?? Date.now();
  const clientRequestId = args.clientRequestId ?? randomUUID();
  const createRequestHash = sha256Hex(
    canonicalJsonString({
      uid: args.uid,
      clientRequestId,
      mode: args.mode,
      levelId: args.levelId,
      gameCompatVersion: args.gameCompatVersion,
    }),
  );
  const runSessionId = runSessionIdForRequest(args.uid, clientRequestId);
  const runSessionRef = args.db
    .collection(runSessionsCollection)
    .doc(runSessionId);
  const existingTicket = await loadExistingIdempotentRun({
    db: args.db,
    uid: args.uid,
    runSessionRef,
    createRequestHash,
  });
  if (existingTicket) {
    logger.info("runSessionCreate_idempotency", {
      outcome: "replayed",
      runSessionId,
    });
    return { runTicket: existingTicket };
  }

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
  const authorizedLoadout = normalizeAuthorizedLoadout({
    loadout: snapshot.loadoutSnapshot,
    meta: canonicalState.meta,
    characterId: snapshot.playerCharacterId,
  });
  if (authorizedLoadout === null) {
    throw new HttpsError(
      "failed-precondition",
      "Canonical run loadout contains unknown or unowned content.",
    );
  }
  snapshot.loadoutSnapshot = authorizedLoadout;

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
        boardOpensAtMs: number;
        boardClosesAtMs: number;
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
      boardOpensAtMs: boardManifest.opensAtMs,
      boardClosesAtMs: boardManifest.closesAtMs,
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
      boardOpensAtMs: boardContext.boardOpensAtMs,
      boardClosesAtMs: boardContext.boardClosesAtMs,
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
    clientRequestId,
    createRequestHash,
    mode: snapshot.mode,
    runTicket,
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
  const transactionResult = await args.db.runTransaction(async (tx) => {
    await assertAccountActiveInTransaction(tx, args.db, args.uid);
    const existing = await tx.get(runSessionRef);
    if (existing.exists) {
      return {
        outcome: "replayed",
        runTicket: decodeIdempotentRunTicket(
          existing.data(),
          createRequestHash,
        ),
        activeCount: null,
        activeLimit: null,
        wouldRejectActiveLimit: false,
      } as const;
    }
    const activeLimit = readConfiguredActiveSessionLimit();
    const activeSnapshot = await tx.get(
      args.db
        .collection(runSessionsCollection)
        .where("uid", "==", args.uid)
        .where("state", "in", [...activeSessionStates])
        .limit(activeSessionScanCap),
    );
    const wouldRejectActiveLimit =
      activeLimit !== undefined && activeSnapshot.size >= activeLimit;
    if (wouldRejectActiveLimit && readAbuseControlMode() === "enforce") {
      return {
        outcome: "active_limit_rejected",
        activeCount: activeSnapshot.size,
        activeLimit: activeLimit ?? null,
        wouldRejectActiveLimit,
      } as const;
    }
    tx.create(runSessionRef, runSessionDoc);
    return {
      outcome: "created",
      runTicket,
      activeCount: activeSnapshot.size,
      activeLimit: activeLimit ?? null,
      wouldRejectActiveLimit,
    } as const;
  });
  runSessionWriteMs = Date.now() - runSessionWriteStartMs;
  logger.info("runSessionCreate_active_sessions", {
    mode: readAbuseControlMode(),
    activeCount: transactionResult.activeCount,
    activeLimit: transactionResult.activeLimit,
    wouldReject: transactionResult.wouldRejectActiveLimit,
    countCapped: transactionResult.activeCount === activeSessionScanCap,
  });
  if (transactionResult.outcome === "active_limit_rejected") {
    throw new HttpsError(
      "resource-exhausted",
      "Active run session limit exceeded.",
    );
  }
  if (transactionResult.outcome === "replayed") {
    logger.info("runSessionCreate_idempotency", {
      outcome: "concurrent_replay",
      runSessionId,
    });
    return { runTicket: transactionResult.runTicket };
  }

  const totalMs = Date.now() - startedAtMs;
  logger.info("runSessionCreate_timing", {
    mode: snapshot.mode,
    levelId: snapshot.levelId,
    boardRequired: runModeRequiresBoard(snapshot.mode),
    boardEnsureAttempted,
    canonicalLoadMs,
    boardResolveMs,
    runSessionWriteMs,
    totalMs,
  });

  return { runTicket: transactionResult.runTicket };
}

async function loadExistingIdempotentRun(args: {
  db: Firestore;
  uid: string;
  runSessionRef: FirebaseFirestore.DocumentReference;
  createRequestHash: string;
}): Promise<JsonObject | null> {
  return args.db.runTransaction(async (tx) => {
    await assertAccountActiveInTransaction(tx, args.db, args.uid);
    const snapshot = await tx.get(args.runSessionRef);
    if (!snapshot.exists) {
      return null;
    }
    return decodeIdempotentRunTicket(
      snapshot.data(),
      args.createRequestHash,
    );
  });
}

function decodeIdempotentRunTicket(
  data: FirebaseFirestore.DocumentData | undefined,
  expectedRequestHash: string,
): JsonObject {
  if (data?.createRequestHash !== expectedRequestHash) {
    throw new HttpsError(
      "already-exists",
      "clientRequestId was already used with different run parameters.",
    );
  }
  const runTicket = data.runTicket;
  if (!runTicket || typeof runTicket !== "object" || Array.isArray(runTicket)) {
    throw new HttpsError(
      "failed-precondition",
      "Idempotent run-session record has a malformed run ticket.",
    );
  }
  return structuredClone(runTicket) as JsonObject;
}

function runSessionIdForRequest(uid: string, clientRequestId: string): string {
  return `run_${sha256Hex(`${uid}:${clientRequestId}`).slice(0, 40)}`;
}

function readConfiguredActiveSessionLimit(): number | undefined {
  return (
    readOptionalBoundedAbuseLimit({
      envName: "ABUSE_RUN_ACTIVE_SESSIONS_LIMIT",
      max: activeSessionScanCap,
    }) ?? defaultRunActiveSessionsLimit
  );
}

async function loadBoardManifestWithProvisioningFallback(args: {
  db: Firestore;
  mode: Exclude<RunModeValue, "practice">;
  levelId: string;
  gameCompatVersion: string;
  nowMs: number;
  onEnsureAttempt: () => void;
}) {
  const config = resolveBoardProvisioningConfigForGameCompatVersion(
    args.gameCompatVersion,
  );
  const loadArgs = {
    db: args.db,
    mode: args.mode,
    levelId: args.levelId,
    gameCompatVersion: args.gameCompatVersion,
    rulesetVersion: config.rulesetVersion,
    scoreVersion: config.scoreVersion,
    ghostVersion: config.ghostVersion,
    nowMs: args.nowMs,
  };
  try {
    return await loadActiveBoardManifest(loadArgs);
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
    config,
    includeNextWindows: false,
  });

  return loadActiveBoardManifest(loadArgs);
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
