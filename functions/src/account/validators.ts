import { assertCallablePayloadBounds } from "../abuse/payload_bounds.js";
import { requireNonEmptyString, requireObject } from "../ownership/validators.js";

export interface AccountDeleteRequest {
  userId: string;
  sessionId: string;
}

export function parseAccountDeleteRequest(raw: unknown): AccountDeleteRequest {
  assertCallablePayloadBounds(raw);
  const data = requireObject(raw, "request");
  return {
    userId: requireNonEmptyString(data.userId, "userId"),
    sessionId: requireNonEmptyString(data.sessionId, "sessionId"),
  };
}
