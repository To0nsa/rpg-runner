import type { Firestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

import { ensureManagedBoardForModeLevel } from "../boards/provisioning.js";
import { loadActiveBoardManifest, toBoardManifestJson } from "../boards/store.js";
import {
  type LeaderboardBoardResult,
  type LeaderboardBoardWithMyRankResult,
  type LeaderboardMyRankResult,
  loadLeaderboardBoard,
  loadLeaderboardBoardWithMyRank,
  loadLeaderboardMyRank,
} from "./store.js";
import {
  parseLeaderboardLoadActiveBoardDataRequest,
  parseLeaderboardLoadBoardRequest,
  parseLeaderboardLoadMyRankRequest,
} from "./validators.js";

interface CallableRequestAuthLike {
  uid?: string;
}

interface CallableRequestLike {
  auth?: CallableRequestAuthLike | null;
  data: unknown;
}

export async function handleLeaderboardLoadBoard(
  request: CallableRequestLike,
  db: Firestore,
): Promise<{ board: LeaderboardBoardResult }> {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { userId, boardId } = parseLeaderboardLoadBoardRequest(request.data);
  if (userId !== uid) {
    throw new HttpsError("permission-denied", "userId does not match auth uid.");
  }
  const board = await loadLeaderboardBoard({
    db,
    boardId,
  });
  return { board };
}

export async function handleLeaderboardLoadMyRank(
  request: CallableRequestLike,
  db: Firestore,
): Promise<{ myRank: LeaderboardMyRankResult }> {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { userId, boardId } = parseLeaderboardLoadMyRankRequest(request.data);
  if (userId !== uid) {
    throw new HttpsError("permission-denied", "userId does not match auth uid.");
  }
  const myRank = await loadLeaderboardMyRank({
    db,
    boardId,
    uid,
  });
  return { myRank };
}

export async function handleLeaderboardLoadActiveBoardData(
  request: CallableRequestLike,
  db: Firestore,
): Promise<{
  boardManifest: Record<string, unknown>;
  board: LeaderboardBoardResult;
  myRank: LeaderboardMyRankResult;
}> {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { userId, mode, levelId, gameCompatVersion, nowMs } =
    parseLeaderboardLoadActiveBoardDataRequest(request.data);
  if (userId !== uid) {
    throw new HttpsError("permission-denied", "userId does not match auth uid.");
  }
  const manifest = await loadActiveBoardManifestWithProvisioningFallback({
    db,
    mode,
    levelId,
    gameCompatVersion,
    nowMs,
  });
  const payload: LeaderboardBoardWithMyRankResult =
    await loadLeaderboardBoardWithMyRank({
      db,
      boardId: manifest.boardId,
      uid,
    });
  return {
    boardManifest: toBoardManifestJson(manifest),
    board: payload.board,
    myRank: payload.myRank,
  };
}

async function loadActiveBoardManifestWithProvisioningFallback(args: {
  db: Firestore;
  mode: "competitive" | "weekly";
  levelId: string;
  gameCompatVersion: string;
  nowMs?: number;
}) {
  try {
    return await loadActiveBoardManifest(args);
  } catch (error) {
    if (!isMissingBoardError(error)) {
      throw error;
    }
  }

  await ensureManagedBoardForModeLevel({
    db: args.db,
    mode: args.mode,
    levelId: args.levelId,
    nowMs: args.nowMs,
    includeNextWindows: false,
  });

  return loadActiveBoardManifest(args);
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
