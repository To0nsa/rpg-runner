import { HttpsError } from "firebase-functions/v2/https";

import { assertCallablePayloadBounds } from "../abuse/payload_bounds.js";
import { rejectClientAuthorityTime } from "../authority_time.js";
import type { JsonObject } from "../ownership/contracts.js";
import {
  requireBoundedIdentifier,
  requireNonEmptyString,
  requireObject,
} from "../ownership/validators.js";
import { replayUploadMaxBytes } from "./limits.js";
import { parseRunMode, type RunModeValue } from "./mode.js";

interface RunSessionCreateRequest {
  userId: string;
  sessionId: string;
  clientRequestId: string;
  mode: RunModeValue;
  levelId: string;
  gameCompatVersion: string;
}

interface RunSessionCreateUploadGrantRequest {
  userId: string;
  sessionId: string;
  runSessionId: string;
}

interface RunSessionFinalizeUploadRequest {
  userId: string;
  sessionId: string;
  runSessionId: string;
  canonicalSha256: string;
  contentLengthBytes: number;
  contentType?: string;
  objectPath?: string;
  provisionalSummary?: JsonObject;
}

interface RunSessionLoadStatusRequest {
  userId: string;
  sessionId: string;
  runSessionId: string;
}

export function parseRunSessionCreateRequest(
  raw: unknown,
): RunSessionCreateRequest {
  assertCallablePayloadBounds(raw);
  const data = requireObject(raw, "request");
  rejectClientAuthorityTime(data);
  return {
    userId: requireNonEmptyString(data.userId, "userId"),
    sessionId: requireNonEmptyString(data.sessionId, "sessionId"),
    clientRequestId: requireBoundedIdentifier(
      data.clientRequestId,
      "clientRequestId",
      96,
    ),
    mode: parseRunMode(data.mode, "mode"),
    levelId: requireNonEmptyString(data.levelId, "levelId"),
    gameCompatVersion: requireNonEmptyString(
      data.gameCompatVersion,
      "gameCompatVersion",
    ),
  };
}

export function parseRunSessionCreateUploadGrantRequest(
  raw: unknown,
): RunSessionCreateUploadGrantRequest {
  assertCallablePayloadBounds(raw);
  const data = requireObject(raw, "request");
  rejectClientAuthorityTime(data);
  return {
    userId: requireNonEmptyString(data.userId, "userId"),
    sessionId: requireNonEmptyString(data.sessionId, "sessionId"),
    runSessionId: requireNonEmptyString(data.runSessionId, "runSessionId"),
  };
}

export function parseRunSessionFinalizeUploadRequest(
  raw: unknown,
): RunSessionFinalizeUploadRequest {
  assertCallablePayloadBounds(raw);
  const data = requireObject(raw, "request");
  rejectClientAuthorityTime(data);
  const canonicalSha256 = requireNonEmptyString(
    data.canonicalSha256,
    "canonicalSha256",
  );
  if (!/^[a-f0-9]{64}$/u.test(canonicalSha256)) {
    throw new HttpsError(
      "invalid-argument",
      "canonicalSha256 must be a lower-case 64-char SHA-256 hex string.",
    );
  }
  const contentLengthBytes = parseRequiredInteger(
    data.contentLengthBytes,
    "contentLengthBytes",
  );
  if (contentLengthBytes <= 0) {
    throw new HttpsError(
      "invalid-argument",
      "contentLengthBytes must be greater than zero.",
    );
  }
  if (contentLengthBytes > replayUploadMaxBytes) {
    throw new HttpsError(
      "invalid-argument",
      `contentLengthBytes exceeds ${replayUploadMaxBytes} bytes.`,
    );
  }
  const provisionalSummaryRaw = data.provisionalSummary;
  return {
    userId: requireNonEmptyString(data.userId, "userId"),
    sessionId: requireNonEmptyString(data.sessionId, "sessionId"),
    runSessionId: requireNonEmptyString(data.runSessionId, "runSessionId"),
    canonicalSha256,
    contentLengthBytes,
    contentType: parseOptionalString(data.contentType),
    objectPath: parseOptionalString(data.objectPath),
    provisionalSummary:
      provisionalSummaryRaw === undefined || provisionalSummaryRaw === null
        ? undefined
        : (requireObject(provisionalSummaryRaw, "provisionalSummary") as JsonObject),
  };
}

export function parseRunSessionLoadStatusRequest(
  raw: unknown,
): RunSessionLoadStatusRequest {
  assertCallablePayloadBounds(raw);
  const data = requireObject(raw, "request");
  return {
    userId: requireNonEmptyString(data.userId, "userId"),
    sessionId: requireNonEmptyString(data.sessionId, "sessionId"),
    runSessionId: requireNonEmptyString(data.runSessionId, "runSessionId"),
  };
}

function parseRequiredInteger(value: unknown, fieldName: string): number {
  if (typeof value !== "number" || !Number.isInteger(value)) {
    throw new HttpsError("invalid-argument", `${fieldName} must be an integer.`);
  }
  return value;
}

function parseOptionalString(value: unknown): string | undefined {
  if (typeof value !== "string") {
    return undefined;
  }
  const trimmed = value.trim();
  if (trimmed.length === 0) {
    return undefined;
  }
  return trimmed;
}
