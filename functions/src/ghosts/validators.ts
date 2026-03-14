import { requireNonEmptyString, requireObject } from "../ownership/validators.js";

export interface GhostLoadManifestRequest {
  userId: string;
  sessionId: string;
  boardId: string;
  entryId: string;
}

export function parseGhostLoadManifestRequest(
  raw: unknown,
): GhostLoadManifestRequest {
  const data = requireObject(raw, "request");
  return {
    userId: requireNonEmptyString(data.userId, "userId"),
    sessionId: requireNonEmptyString(data.sessionId, "sessionId"),
    boardId: requireNonEmptyString(data.boardId, "boardId"),
    entryId: requireNonEmptyString(data.entryId, "entryId"),
  };
}
