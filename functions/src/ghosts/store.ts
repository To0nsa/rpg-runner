import { HttpsError } from "firebase-functions/v2/https";
import type { Firestore } from "firebase-admin/firestore";

import type { JsonObject } from "../ownership/contracts.js";

export interface GhostManifestResult {
  boardId: string;
  entryId: string;
  runSessionId: string;
  uid: string;
  replayStorageRef: string;
  sourceReplayStorageRef: string;
  score: number;
  distanceMeters: number;
  durationSeconds: number;
  sortKey: string;
  rank: number;
  updatedAtMs: number;
}

const leaderboardBoardsCollection = "leaderboard_boards";
const ghostManifestsCollection = "ghost_manifests";

export async function loadGhostManifest(args: {
  db: Firestore;
  boardId: string;
  entryId: string;
}): Promise<GhostManifestResult> {
  const manifestRef = args.db
    .collection(leaderboardBoardsCollection)
    .doc(args.boardId)
    .collection(ghostManifestsCollection)
    .doc(args.entryId);
  const manifestSnap = await manifestRef.get();
  if (!manifestSnap.exists) {
    throw new HttpsError(
      "not-found",
      `ghost manifest ${args.boardId}/${args.entryId} was not found.`,
    );
  }
  const parsed = parseGhostManifest(manifestSnap.data() as JsonObject | undefined);
  if (!parsed) {
    throw new HttpsError(
      "failed-precondition",
      `ghost manifest ${args.boardId}/${args.entryId} is malformed.`,
    );
  }
  const state = readString(parsed.status);
  const exposed = parsed.exposed;
  if (state !== "active" || exposed !== true) {
    throw new HttpsError(
      "not-found",
      `ghost manifest ${args.boardId}/${args.entryId} is not active.`,
    );
  }
  return {
    boardId: readRequiredString(parsed.boardId, "ghostManifest.boardId"),
    entryId: readRequiredString(parsed.entryId, "ghostManifest.entryId"),
    runSessionId: readRequiredString(
      parsed.runSessionId,
      "ghostManifest.runSessionId",
    ),
    uid: readRequiredString(parsed.uid, "ghostManifest.uid"),
    replayStorageRef: readRequiredString(
      parsed.replayStorageRef,
      "ghostManifest.replayStorageRef",
    ),
    sourceReplayStorageRef: readRequiredString(
      parsed.sourceReplayStorageRef,
      "ghostManifest.sourceReplayStorageRef",
    ),
    score: readRequiredInt(parsed.score, "ghostManifest.score"),
    distanceMeters: readRequiredInt(
      parsed.distanceMeters,
      "ghostManifest.distanceMeters",
    ),
    durationSeconds: readRequiredInt(
      parsed.durationSeconds,
      "ghostManifest.durationSeconds",
    ),
    sortKey: readRequiredString(parsed.sortKey, "ghostManifest.sortKey"),
    rank: readRequiredInt(parsed.rank, "ghostManifest.rank"),
    updatedAtMs: readRequiredInt(parsed.updatedAtMs, "ghostManifest.updatedAtMs"),
  };
}

function parseGhostManifest(
  raw: JsonObject | undefined,
): Record<string, unknown> | null {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    return null;
  }
  return raw as Record<string, unknown>;
}

function readRequiredString(value: unknown, fieldName: string): string {
  const parsed = readString(value);
  if (!parsed) {
    throw new HttpsError("failed-precondition", `${fieldName} must be a string.`);
  }
  return parsed;
}

function readRequiredInt(value: unknown, fieldName: string): number {
  const parsed = readInt(value);
  if (parsed == null) {
    throw new HttpsError("failed-precondition", `${fieldName} must be an integer.`);
  }
  return parsed;
}

function readString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function readInt(value: unknown): number | null {
  if (typeof value === "number" && Number.isInteger(value)) {
    return value;
  }
  return null;
}
