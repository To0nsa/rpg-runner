import type { Firestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

import { assertAccountActive } from "../account/deletion_guard.js";
import { consumeUserQuota } from "../abuse/quota.js";
import {
  captureAuthorityTimeMs,
  systemAuthorityClock,
  type AuthorityClock,
} from "../authority_time.js";
import { ensureManagedBoardForModeLevel } from "../boards/provisioning.js";
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
  clock: AuthorityClock = systemAuthorityClock,
): Promise<{ boardManifest: Record<string, unknown> }> {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { userId, mode, levelId, gameCompatVersion } =
    parseLoadActiveBoardRequest(request.data);
  if (userId !== uid) {
    throw new HttpsError("permission-denied", "userId does not match auth uid.");
  }
  await assertAccountActive(db, uid);
  const nowMs = captureAuthorityTimeMs(clock);
  await consumeUserQuota({
    db,
    uid,
    route: "leaderboard_read",
    nowMs,
  });
  const manifest = await loadBoardManifestWithProvisioningFallback({
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
  clock: AuthorityClock = systemAuthorityClock,
): Promise<{ runTicket: Record<string, unknown> }> {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { userId, clientRequestId, mode, levelId, gameCompatVersion } =
    parseRunSessionCreateRequest(request.data);
  if (userId !== uid) {
    throw new HttpsError("permission-denied", "userId does not match auth uid.");
  }
  await assertAccountActive(db, uid);
  const nowMs = captureAuthorityTimeMs(clock);
  await consumeUserQuota({
    db,
    uid,
    route: "run_create",
    nowMs,
  });
  const result = await createRunSession({
    db,
    uid,
    clientRequestId,
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
  dependencies?: RunSubmissionDependencies,
  clock: AuthorityClock = systemAuthorityClock,
): Promise<{ uploadGrant: UploadGrantRecord }> {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { userId, runSessionId } =
    parseRunSessionCreateUploadGrantRequest(request.data);
  if (userId !== uid) {
    throw new HttpsError("permission-denied", "userId does not match auth uid.");
  }
  await assertAccountActive(db, uid);
  const nowMs = captureAuthorityTimeMs(clock);
  await consumeUserQuota({
    db,
    uid,
    route: "upload_grant",
    nowMs,
  });
  const result = await createRunSessionUploadGrant({
    db,
    uid,
    runSessionId,
    nowMs,
    dependencies: dependencies ?? createDefaultRunSubmissionDependencies(),
  });
  return {
    uploadGrant: result.uploadGrant,
  };
}

export async function handleRunSessionFinalizeUpload(
  request: CallableRequestLike,
  db: Firestore,
  dependencies?: RunSubmissionDependencies,
  clock: AuthorityClock = systemAuthorityClock,
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
  } = parseRunSessionFinalizeUploadRequest(request.data);
  if (userId !== uid) {
    throw new HttpsError("permission-denied", "userId does not match auth uid.");
  }
  await assertAccountActive(db, uid);
  const nowMs = captureAuthorityTimeMs(clock);
  await consumeUserQuota({
    db,
    uid,
    route: "finalize_replay_bytes",
    units: contentLengthBytes,
    nowMs,
  });
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
    dependencies: dependencies ?? createDefaultRunSubmissionDependencies(),
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
  await assertAccountActive(db, uid);
  const result = await loadRunSessionSubmissionStatus({
    db,
    uid,
    runSessionId,
  });
  return {
    submissionStatus: result.submissionStatus,
  };
}

async function loadBoardManifestWithProvisioningFallback(args: {
  db: Firestore;
  mode: "competitive" | "weekly";
  levelId: string;
  gameCompatVersion: string;
  nowMs: number;
}) {
  try {
    return await loadActiveBoardManifest(args);
  } catch (error) {
    if (!isMissingBoardError(error)) {
      throw error;
    }
  }

  await ensureManagedBoardForModeLevel({
    db: args.db,
    mode: args.mode,
    levelId: args.levelId,
    nowMs: args.nowMs,
    includeNextWindows: false,
  });

  return loadActiveBoardManifest(args);
}

function isMissingBoardError(error: unknown): boolean {
  if (!(error instanceof HttpsError)) {
    return false;
  }
  if (error.code !== "failed-precondition") {
    return false;
  }
  return error.message.startsWith("No board found for ");
}
