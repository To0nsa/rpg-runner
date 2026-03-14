import { HttpsError } from "firebase-functions/v2/https";
import type { DocumentSnapshot, Firestore } from "firebase-admin/firestore";

import type { JsonObject } from "../ownership/contracts.js";

const leaderboardBoardsCollection = "leaderboard_boards";
const playerBestsCollection = "player_bests";
const boardViewsCollection = "views";
const top10ViewDocId = "top10";

export interface LeaderboardBoardResult {
  boardId: string;
  topEntries: JsonObject[];
  updatedAtMs: number;
}

export interface LeaderboardMyRankResult {
  boardId: string;
  myEntry: JsonObject | null;
  rank: number | null;
  totalPlayers: number;
}

export async function loadLeaderboardBoard(args: {
  db: Firestore;
  boardId: string;
}): Promise<LeaderboardBoardResult> {
  const boardRef = args.db.collection(leaderboardBoardsCollection).doc(args.boardId);
  const boardSnap = await boardRef.get();
  if (!boardSnap.exists) {
    throw new HttpsError("not-found", `board ${args.boardId} was not found.`);
  }

  const top10ViewSnap = await boardRef
    .collection(boardViewsCollection)
    .doc(top10ViewDocId)
    .get();
  const top10FromView = decodeTop10View(top10ViewSnap, args.boardId);
  if (top10FromView) {
    return top10FromView;
  }

  const topEntriesSnap = await boardRef
    .collection(playerBestsCollection)
    .orderBy("sortKey", "asc")
    .limit(10)
    .get();
  const entries = topEntriesSnap.docs.map((doc, index) =>
    decodeLeaderboardEntry(doc.data(), doc.id, index + 1),
  );
  return {
    boardId: args.boardId,
    topEntries: entries,
    updatedAtMs: Date.now(),
  };
}

export async function loadLeaderboardMyRank(args: {
  db: Firestore;
  boardId: string;
  uid: string;
}): Promise<LeaderboardMyRankResult> {
  const boardRef = args.db.collection(leaderboardBoardsCollection).doc(args.boardId);
  const boardSnap = await boardRef.get();
  if (!boardSnap.exists) {
    throw new HttpsError("not-found", `board ${args.boardId} was not found.`);
  }

  const playerBestRef = boardRef.collection(playerBestsCollection).doc(args.uid);
  const playerBestSnap = await playerBestRef.get();
  const totalPlayersCount = await boardRef.collection(playerBestsCollection).count().get();
  const totalPlayers = Number(totalPlayersCount.data().count ?? 0);
  if (!playerBestSnap.exists) {
    return {
      boardId: args.boardId,
      myEntry: null,
      rank: null,
      totalPlayers,
    };
  }

  const parsed = decodeLeaderboardEntry(
    playerBestSnap.data(),
    playerBestSnap.id,
    undefined,
  );
  const sortKey = parsed.sortKey;
  const betterCountSnap = await boardRef
    .collection(playerBestsCollection)
    .where("sortKey", "<", sortKey)
    .count()
    .get();
  const betterCount = Number(betterCountSnap.data().count ?? 0);
  const rank = betterCount + 1;
  return {
    boardId: args.boardId,
    myEntry: {
      ...parsed,
      rank,
    },
    rank,
    totalPlayers,
  };
}

function decodeTop10View(
  snapshot: DocumentSnapshot,
  boardId: string,
): LeaderboardBoardResult | null {
  if (!snapshot.exists) {
    return null;
  }
  const dataRaw = snapshot.data();
  if (!dataRaw || typeof dataRaw !== "object") {
    return null;
  }
  const data = dataRaw as Record<string, unknown>;
  const entriesRaw = data.entries;
  if (!Array.isArray(entriesRaw)) {
    return null;
  }
  const entries: JsonObject[] = [];
  for (const item of entriesRaw) {
    if (!item || typeof item !== "object" || Array.isArray(item)) {
      continue;
    }
    const record = item as Record<string, unknown>;
    try {
      entries.push(
        decodeLeaderboardEntry(
          record,
          readString(record.entryId) ?? "",
          readInt(record.rank) ?? undefined,
        ),
      );
    } catch {
      // Skip malformed rows and keep valid rows visible.
    }
  }
  const updatedAtMs = readInt(data.updatedAtMs) ?? Date.now();
  return {
    boardId,
    topEntries: entries,
    updatedAtMs,
  };
}

function decodeLeaderboardEntry(
  raw: Record<string, unknown> | undefined,
  fallbackEntryId: string,
  rank: number | undefined,
): JsonObject {
  if (!raw || typeof raw !== "object") {
    throw new HttpsError("failed-precondition", "leaderboard entry is malformed.");
  }
  const boardId = readRequiredString(raw.boardId, "leaderboardEntry.boardId");
  const entryId =
    readString(raw.entryId)?.trim() ||
    (fallbackEntryId.trim().length > 0 ? fallbackEntryId.trim() : "");
  if (entryId.length === 0) {
    throw new HttpsError(
      "failed-precondition",
      "leaderboardEntry.entryId must be non-empty.",
    );
  }
  const out: JsonObject = {
    boardId,
    entryId,
    runSessionId: readRequiredString(
      raw.runSessionId,
      "leaderboardEntry.runSessionId",
    ),
    uid: readRequiredString(raw.uid, "leaderboardEntry.uid"),
    displayName: readRequiredString(
      raw.displayName,
      "leaderboardEntry.displayName",
    ),
    characterId: readRequiredString(
      raw.characterId,
      "leaderboardEntry.characterId",
    ),
    score: readRequiredInt(raw.score, "leaderboardEntry.score"),
    distanceMeters: readRequiredInt(
      raw.distanceMeters,
      "leaderboardEntry.distanceMeters",
    ),
    durationSeconds: readRequiredInt(
      raw.durationSeconds,
      "leaderboardEntry.durationSeconds",
    ),
    sortKey: readRequiredString(raw.sortKey, "leaderboardEntry.sortKey"),
    ghostEligible: readBool(raw.ghostEligible) ?? false,
    updatedAtMs: readRequiredInt(raw.updatedAtMs, "leaderboardEntry.updatedAtMs"),
  };
  const replayStorageRef = readString(raw.replayStorageRef);
  if (replayStorageRef != null && replayStorageRef.length > 0) {
    out.replayStorageRef = replayStorageRef;
  }
  if (rank != null && rank > 0) {
    out.rank = rank;
  }
  return out;
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

function readBool(value: unknown): boolean | null {
  if (typeof value !== "boolean") {
    return null;
  }
  return value;
}
