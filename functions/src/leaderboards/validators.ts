import { HttpsError } from "firebase-functions/v2/https";

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
  nowMs?: number;
}

export function parseLeaderboardLoadBoardRequest(
  raw: unknown,
): LeaderboardLoadBoardRequest {
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
  const data = requireRequestObject(raw);
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
    nowMs: parseOptionalNowMs(data.nowMs),
  };
}

function requireRequestObject(raw: unknown): Record<string, unknown> {
  return requireObject(raw, "request");
}

function parseOptionalNowMs(value: unknown): number | undefined {
  if (value === undefined || value === null) {
    return undefined;
  }
  if (!Number.isInteger(value)) {
    throw new HttpsError("invalid-argument", "nowMs must be an integer.");
  }
  return value as number;
}
