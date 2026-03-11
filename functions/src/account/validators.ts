import { requireNonEmptyString, requireObject } from "../ownership/validators.js";

export interface AccountDeleteRequest {
  userId: string;
  sessionId: string;
  profileId: string;
}

export function parseAccountDeleteRequest(raw: unknown): AccountDeleteRequest {
  const data = requireObject(raw, "request");
  return {
    userId: requireNonEmptyString(data.userId, "userId"),
    sessionId: requireNonEmptyString(data.sessionId, "sessionId"),
    profileId: requireNonEmptyString(data.profileId, "profileId"),
  };
}
