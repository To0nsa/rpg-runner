import type { Firestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

import { loadActiveBoardManifest, toBoardManifestJson } from "../boards/store.js";
import type { JsonObject } from "../ownership/contracts.js";
import { parseLoadActiveBoardRequest } from "../boards/validators.js";
import { createRunSession } from "./store.js";
import {
  createDefaultRunSubmissionDependencies,
  createRunSessionUploadGrant,
  finalizeRunSessionUpload,
  loadRunSessionSubmissionStatus,
  type UploadGrantRecord,
  type RunSubmissionDependencies,
} from "./submission_store.js";
import {
  parseRunSessionCreateRequest,
  parseRunSessionCreateUploadGrantRequest,
  parseRunSessionFinalizeUploadRequest,
  parseRunSessionLoadStatusRequest,
} from "./validators.js";

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

export async function handleRunSessionCreateUploadGrant(
  request: CallableRequestLike,
  db: Firestore,
  dependencies: RunSubmissionDependencies = createDefaultRunSubmissionDependencies(),
): Promise<{ uploadGrant: UploadGrantRecord }> {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { userId, runSessionId, nowMs } =
    parseRunSessionCreateUploadGrantRequest(request.data);
  if (userId !== uid) {
    throw new HttpsError("permission-denied", "userId does not match auth uid.");
  }
  const result = await createRunSessionUploadGrant({
    db,
    uid,
    runSessionId,
    nowMs,
    dependencies,
  });
  return {
    uploadGrant: result.uploadGrant,
  };
}

export async function handleRunSessionFinalizeUpload(
  request: CallableRequestLike,
  db: Firestore,
  dependencies: RunSubmissionDependencies = createDefaultRunSubmissionDependencies(),
): Promise<{ submissionStatus: JsonObject }> {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const {
    userId,
    runSessionId,
    canonicalSha256,
    contentLengthBytes,
    contentType,
    objectPath,
    provisionalSummary,
    nowMs,
  } = parseRunSessionFinalizeUploadRequest(request.data);
  if (userId !== uid) {
    throw new HttpsError("permission-denied", "userId does not match auth uid.");
  }
  const result = await finalizeRunSessionUpload({
    db,
    uid,
    runSessionId,
    canonicalSha256,
    contentLengthBytes,
    contentType,
    objectPath,
    provisionalSummary,
    nowMs,
    dependencies,
  });
  return {
    submissionStatus: result.submissionStatus,
  };
}

export async function handleRunSessionLoadStatus(
  request: CallableRequestLike,
  db: Firestore,
): Promise<{ submissionStatus: JsonObject }> {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { userId, runSessionId } = parseRunSessionLoadStatusRequest(request.data);
  if (userId !== uid) {
    throw new HttpsError("permission-denied", "userId does not match auth uid.");
  }
  const result = await loadRunSessionSubmissionStatus({
    db,
    uid,
    runSessionId,
  });
  return {
    submissionStatus: result.submissionStatus,
  };
}
