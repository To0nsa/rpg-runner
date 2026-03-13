import { HttpsError } from "firebase-functions/v2/https";

import type { JsonObject } from "../ownership/contracts.js";
import { requireNonEmptyString, requireObject } from "../ownership/validators.js";
import { parseRunMode, type RunModeValue } from "./mode.js";

interface RunSessionCreateRequest {
  userId: string;
  sessionId: string;
  mode: RunModeValue;
  levelId: string;
  gameCompatVersion: string;
  nowMs?: number;
}

interface RunSessionCreateUploadGrantRequest {
  userId: string;
  sessionId: string;
  runSessionId: string;
  nowMs?: number;
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
  nowMs?: number;
}

interface RunSessionLoadStatusRequest {
  userId: string;
  sessionId: string;
  runSessionId: string;
}

export function parseRunSessionCreateRequest(
  raw: unknown,
): RunSessionCreateRequest {
  const data = requireObject(raw, "request");
  return {
    userId: requireNonEmptyString(data.userId, "userId"),
    sessionId: requireNonEmptyString(data.sessionId, "sessionId"),
    mode: parseRunMode(data.mode, "mode"),
    levelId: requireNonEmptyString(data.levelId, "levelId"),
    gameCompatVersion: requireNonEmptyString(
      data.gameCompatVersion,
      "gameCompatVersion",
    ),
    nowMs: parseOptionalNowMs(data.nowMs),
  };
}

export function parseRunSessionCreateUploadGrantRequest(
  raw: unknown,
): RunSessionCreateUploadGrantRequest {
  const data = requireObject(raw, "request");
  return {
    userId: requireNonEmptyString(data.userId, "userId"),
    sessionId: requireNonEmptyString(data.sessionId, "sessionId"),
    runSessionId: requireNonEmptyString(data.runSessionId, "runSessionId"),
    nowMs: parseOptionalNowMs(data.nowMs),
  };
}

export function parseRunSessionFinalizeUploadRequest(
  raw: unknown,
): RunSessionFinalizeUploadRequest {
  const data = requireObject(raw, "request");
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
    nowMs: parseOptionalNowMs(data.nowMs),
  };
}

export function parseRunSessionLoadStatusRequest(
  raw: unknown,
): RunSessionLoadStatusRequest {
  const data = requireObject(raw, "request");
  return {
    userId: requireNonEmptyString(data.userId, "userId"),
    sessionId: requireNonEmptyString(data.sessionId, "sessionId"),
    runSessionId: requireNonEmptyString(data.runSessionId, "runSessionId"),
  };
}

function parseOptionalNowMs(value: unknown): number | undefined {
  if (value === undefined || value === null) {
    return undefined;
  }
  if (typeof value !== "number" || !Number.isInteger(value)) {
    throw new HttpsError("invalid-argument", "nowMs must be an integer.");
  }
  return value;
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
