import { HttpsError } from "firebase-functions/v2/https";

import { assertCallablePayloadBounds } from "../abuse/payload_bounds.js";
import { rejectClientAuthorityTime } from "../authority_time.js";
import { requireNonEmptyString, requireObject } from "../ownership/validators.js";
import { parseRunMode } from "../runs/mode.js";

export interface LeaderboardLoadBoardRequest {
  userId: string;
  sessionId: string;
  boardId: string;
}

export interface LeaderboardLoadMyRankRequest {
  userId: string;
  sessionId: string;
  boardId: string;
}

export interface LeaderboardLoadActiveBoardDataRequest {
  userId: string;
  sessionId: string;
  mode: "competitive" | "weekly";
  levelId: string;
  gameCompatVersion: string;
}

export function parseLeaderboardLoadBoardRequest(
  raw: unknown,
): LeaderboardLoadBoardRequest {
  assertCallablePayloadBounds(raw);
  const data = requireRequestObject(raw);
  return {
    userId: requireNonEmptyString(data.userId, "userId"),
    sessionId: requireNonEmptyString(data.sessionId, "sessionId"),
    boardId: requireNonEmptyString(data.boardId, "boardId"),
  };
}

export function parseLeaderboardLoadMyRankRequest(
  raw: unknown,
): LeaderboardLoadMyRankRequest {
  assertCallablePayloadBounds(raw);
  const data = requireRequestObject(raw);
  return {
    userId: requireNonEmptyString(data.userId, "userId"),
    sessionId: requireNonEmptyString(data.sessionId, "sessionId"),
    boardId: requireNonEmptyString(data.boardId, "boardId"),
  };
}

export function parseLeaderboardLoadActiveBoardDataRequest(
  raw: unknown,
): LeaderboardLoadActiveBoardDataRequest {
  assertCallablePayloadBounds(raw);
  const data = requireRequestObject(raw);
  rejectClientAuthorityTime(data);
  const mode = parseRunMode(data.mode, "mode");
  if (mode === "practice") {
    throw new HttpsError(
      "invalid-argument",
      "leaderboardLoadActiveBoardData supports competitive|weekly only.",
    );
  }
  return {
    userId: requireNonEmptyString(data.userId, "userId"),
    sessionId: requireNonEmptyString(data.sessionId, "sessionId"),
    mode,
    levelId: requireNonEmptyString(data.levelId, "levelId"),
    gameCompatVersion: requireNonEmptyString(
      data.gameCompatVersion,
      "gameCompatVersion",
    ),
  };
}

function requireRequestObject(raw: unknown): Record<string, unknown> {
  return requireObject(raw, "request");
}
