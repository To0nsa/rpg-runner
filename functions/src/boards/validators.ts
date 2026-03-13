import { HttpsError } from "firebase-functions/v2/https";

import { requireNonEmptyString, requireObject } from "../ownership/validators.js";
import { parseRunMode } from "../runs/mode.js";
import type { BoardStatus } from "./contracts.js";

interface LoadActiveBoardRequest {
  userId: string;
  sessionId: string;
  mode: "competitive" | "weekly";
  levelId: string;
  gameCompatVersion: string;
  nowMs?: number;
}

export function parseLoadActiveBoardRequest(raw: unknown): LoadActiveBoardRequest {
  const data = requireObject(raw, "request");
  const mode = parseRunMode(data.mode, "mode");
  if (mode === "practice") {
    throw new HttpsError(
      "invalid-argument",
      "runBoardsLoadActive supports competitive|weekly only.",
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

export function parseBoardStatusValue(value: unknown, fieldName: string): BoardStatus {
  if (typeof value !== "string") {
    throw new HttpsError("failed-precondition", `${fieldName} must be a string`);
  }
  switch (value) {
    case "scheduled":
    case "active":
    case "closed":
    case "disabled":
      return value;
    default:
      throw new HttpsError(
        "failed-precondition",
        `${fieldName} must be one of: scheduled|active|closed|disabled.`,
      );
  }
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

