import type { Firestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

import {
  type LeaderboardBoardResult,
  type LeaderboardMyRankResult,
  loadLeaderboardBoard,
  loadLeaderboardMyRank,
} from "./store.js";
import {
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
