import { HttpsError } from "firebase-functions/v2/https";
import type {
  Firestore,
  QueryDocumentSnapshot,
} from "firebase-admin/firestore";

import type { JsonObject } from "../ownership/contracts.js";
import { resolveWindowForMode, competitiveWindowBoundsFromId } from "./windowing.js";
import type { BoardKeyRecord, BoardManifestRecord } from "./contracts.js";
import { parseBoardStatusValue } from "./validators.js";

const leaderboardBoardsCollection = "leaderboard_boards";

interface LoadActiveBoardArgs {
  db: Firestore;
  mode: "competitive" | "weekly";
  levelId: string;
  gameCompatVersion: string;
  nowMs?: number;
}

export async function loadActiveBoardManifest(
  args: LoadActiveBoardArgs,
): Promise<BoardManifestRecord> {
  const nowMs = args.nowMs ?? Date.now();
  const resolvedWindow = resolveWindowForMode(args.mode, nowMs);

  const boardSnapshot = await args.db
    .collection(leaderboardBoardsCollection)
    .where("mode", "==", args.mode)
    .where("levelId", "==", args.levelId)
    .where("windowId", "==", resolvedWindow.windowId)
    .get();
  const candidates = boardSnapshot.docs.map(decodeBoardManifestDocument);

  if (candidates.length === 0) {
    throw new HttpsError(
      "failed-precondition",
      `No board found for ${args.mode}/${args.levelId}/${resolvedWindow.windowId}.`,
    );
  }

  const disabled = candidates.find((value) => value.status === "disabled");
  if (disabled) {
    throw new HttpsError(
      "failed-precondition",
      `Board ${disabled.boardId} is disabled for this window.`,
    );
  }

  const activeBoards = candidates.filter((value) => value.status === "active");
  if (activeBoards.length === 0) {
    throw new HttpsError(
      "failed-precondition",
      `Board is not active for ${args.mode}/${args.levelId}/${resolvedWindow.windowId}.`,
    );
  }
  if (activeBoards.length > 1) {
    throw new HttpsError(
      "failed-precondition",
      `Multiple active boards found for ${args.mode}/${args.levelId}/${resolvedWindow.windowId}.`,
    );
  }

  const board = activeBoards[0]!;
  if (board.gameCompatVersion !== args.gameCompatVersion) {
    throw new HttpsError(
      "failed-precondition",
      `Board gameCompatVersion ${board.gameCompatVersion} does not match client ${args.gameCompatVersion}.`,
    );
  }
  if (nowMs < board.opensAtMs || nowMs >= board.closesAtMs) {
    throw new HttpsError(
      "failed-precondition",
      `Board ${board.boardId} is outside its active time window.`,
    );
  }
  if (board.mode === "competitive") {
    validateCompetitiveWindowBounds(board);
  }
  return board;
}

export function toBoardManifestJson(board: BoardManifestRecord): JsonObject {
  const out: JsonObject = {
    boardId: board.boardId,
    boardKey: {
      mode: board.boardKey.mode,
      levelId: board.boardKey.levelId,
      windowId: board.boardKey.windowId,
      rulesetVersion: board.boardKey.rulesetVersion,
      scoreVersion: board.boardKey.scoreVersion,
    },
    gameCompatVersion: board.gameCompatVersion,
    ghostVersion: board.ghostVersion,
    tickHz: board.tickHz,
    seed: board.seed,
    opensAtMs: board.opensAtMs,
    closesAtMs: board.closesAtMs,
    status: board.status,
  };
  if (board.minClientBuild) {
    out.minClientBuild = board.minClientBuild;
  }
  return out;
}

function decodeBoardManifestDocument(
  doc: QueryDocumentSnapshot,
): BoardManifestRecord {
  const raw = doc.data() as Record<string, unknown>;
  const mode = requireMode(raw.mode, "board.mode");
  const levelId = requireString(raw.levelId, "board.levelId");
  const windowId = requireString(raw.windowId, "board.windowId");
  const boardKey = decodeBoardKey(raw.boardKey, {
    mode,
    levelId,
    windowId,
  });
  return {
    boardId: requireOptionalString(raw.boardId) ?? doc.id,
    mode,
    levelId,
    windowId,
    boardKey,
    gameCompatVersion: requireString(
      raw.gameCompatVersion,
      "board.gameCompatVersion",
    ),
    ghostVersion: requireString(raw.ghostVersion, "board.ghostVersion"),
    tickHz: requirePositiveInteger(raw.tickHz, "board.tickHz"),
    seed: requireInteger(raw.seed, "board.seed"),
    opensAtMs: requireInteger(raw.opensAtMs, "board.opensAtMs"),
    closesAtMs: requireInteger(raw.closesAtMs, "board.closesAtMs"),
    minClientBuild: requireOptionalString(raw.minClientBuild),
    status: parseBoardStatusValue(raw.status, "board.status"),
  };
}

function decodeBoardKey(
  raw: unknown,
  expected: {
    mode: "competitive" | "weekly";
    levelId: string;
    windowId: string;
  },
): BoardKeyRecord {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    throw new HttpsError("failed-precondition", "board.boardKey must be an object");
  }
  const key = raw as Record<string, unknown>;
  const mode = requireMode(key.mode, "board.boardKey.mode");
  const levelId = requireString(key.levelId, "board.boardKey.levelId");
  const windowId = requireString(key.windowId, "board.boardKey.windowId");
  if (mode !== expected.mode || levelId !== expected.levelId || windowId !== expected.windowId) {
    throw new HttpsError(
      "failed-precondition",
      "board.boardKey does not match top-level mode/levelId/windowId.",
    );
  }
  return {
    mode,
    levelId,
    windowId,
    rulesetVersion: requireString(
      key.rulesetVersion,
      "board.boardKey.rulesetVersion",
    ),
    scoreVersion: requireString(key.scoreVersion, "board.boardKey.scoreVersion"),
  };
}

function validateCompetitiveWindowBounds(board: BoardManifestRecord): void {
  const expected = competitiveWindowBoundsFromId(board.windowId);
  if (
    board.opensAtMs !== expected.opensAtMs ||
    board.closesAtMs !== expected.closesAtMs
  ) {
    throw new HttpsError(
      "failed-precondition",
      `Competitive board ${board.boardId} does not use exact UTC month boundaries.`,
    );
  }
}

function requireString(value: unknown, fieldName: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("failed-precondition", `${fieldName} must be a string`);
  }
  return value.trim();
}

function requireOptionalString(value: unknown): string | undefined {
  if (typeof value !== "string") {
    return undefined;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

function requireInteger(value: unknown, fieldName: string): number {
  if (typeof value !== "number" || !Number.isInteger(value)) {
    throw new HttpsError("failed-precondition", `${fieldName} must be an integer`);
  }
  return value;
}

function requirePositiveInteger(value: unknown, fieldName: string): number {
  const parsed = requireInteger(value, fieldName);
  if (parsed <= 0) {
    throw new HttpsError(
      "failed-precondition",
      `${fieldName} must be greater than zero.`,
    );
  }
  return parsed;
}

function requireMode(
  value: unknown,
  fieldName: string,
): "competitive" | "weekly" {
  if (value !== "competitive" && value !== "weekly") {
    throw new HttpsError(
      "failed-precondition",
      `${fieldName} must be competitive|weekly.`,
    );
  }
  return value;
}

