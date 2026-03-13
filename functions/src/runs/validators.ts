import { HttpsError } from "firebase-functions/v2/https";

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

function parseOptionalNowMs(value: unknown): number | undefined {
  if (value === undefined || value === null) {
    return undefined;
  }
  if (typeof value !== "number" || !Number.isInteger(value)) {
    throw new HttpsError("invalid-argument", "nowMs must be an integer.");
  }
  return value;
}

