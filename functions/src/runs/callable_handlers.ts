import type { Firestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

import { loadActiveBoardManifest, toBoardManifestJson } from "../boards/store.js";
import { parseLoadActiveBoardRequest } from "../boards/validators.js";
import { createRunSession } from "./store.js";
import { parseRunSessionCreateRequest } from "./validators.js";

interface CallableRequestAuthLike {
  uid?: string;
}

interface CallableRequestLike {
  auth?: CallableRequestAuthLike | null;
  data: unknown;
}

export async function handleRunBoardsLoadActive(
  request: CallableRequestLike,
  db: Firestore,
): Promise<{ boardManifest: Record<string, unknown> }> {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { userId, mode, levelId, gameCompatVersion, nowMs } =
    parseLoadActiveBoardRequest(request.data);
  if (userId !== uid) {
    throw new HttpsError("permission-denied", "userId does not match auth uid.");
  }
  const manifest = await loadActiveBoardManifest({
    db,
    mode,
    levelId,
    gameCompatVersion,
    nowMs,
  });
  return {
    boardManifest: toBoardManifestJson(manifest),
  };
}

export async function handleRunSessionCreate(
  request: CallableRequestLike,
  db: Firestore,
): Promise<{ runTicket: Record<string, unknown> }> {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { userId, mode, levelId, gameCompatVersion, nowMs } =
    parseRunSessionCreateRequest(request.data);
  if (userId !== uid) {
    throw new HttpsError("permission-denied", "userId does not match auth uid.");
  }
  const result = await createRunSession({
    db,
    uid,
    mode,
    levelId,
    gameCompatVersion,
    nowMs,
  });
  return {
    runTicket: result.runTicket,
  };
}

