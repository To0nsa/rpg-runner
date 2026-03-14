import { requireNonEmptyString, requireObject } from "../ownership/validators.js";

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

function requireRequestObject(raw: unknown): Record<string, unknown> {
  return requireObject(raw, "request");
}
