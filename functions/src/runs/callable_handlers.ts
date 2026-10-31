import type { Firestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

import { measureRewardStage } from "./reward_timing.js";
import { runCompletionReceiptRef } from "./completion_receipt.js";
import { assertCallablePayloadBounds } from "../abuse/payload_bounds.js";
import { requireObject } from "../validation.js";
import { assertAccountActive } from "../account/deletion_guard.js";
import { consumeUserQuota } from "../abuse/quota.js";
import {
  captureAuthorityTimeMs,
  rejectClientAuthorityTime,
  systemAuthorityClock,
  type AuthorityClock,
} from "../authority_time.js";
import { loadActiveBoardManifest, toBoardManifestJson } from "../boards/store.js";
import type { JsonObject } from "../ownership/contracts.js";
import { parseLoadActiveBoardRequest } from "../boards/validators.js";
import { assertSupportedGameCompatVersion } from "./compatibility.js";
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

/** One deployed instance serves the submission stages; issuance stays isolated. */
export async function handleRunSubmission(
  request: CallableRequestLike,
  db: Firestore,
  dependencies?: RunSubmissionDependencies,
  clock: AuthorityClock = systemAuthorityClock,
): Promise<{ uploadGrant: UploadGrantRecord } | {
  submissionStatus: JsonObject; completion?: Record<string, unknown>;
}> {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  assertCallablePayloadBounds(request.data);
  const data = requireObject(request.data, "request");
  rejectClientAuthorityTime(data);
  switch (data.operation) {
    case "grant":
      return handleRunSessionCreateUploadGrant(request, db, dependencies, clock);
    case "finalize":
    case "status": {
      const result = data.operation === "finalize"
        ? await handleRunSessionFinalizeUpload(request, db, dependencies, clock)
        : await handleRunSessionLoadStatus(request, db, clock);
      if (result.submissionStatus.state !== "validated") return result;
      const receipt = await runCompletionReceiptRef(db, request.auth.uid,
        String(result.submissionStatus.runSessionId)).get();
      // Old settlements have no receipt and retain the canonical-refresh path.
      return receipt.exists ? { ...result, completion: receipt.data() } : result;
    }
    default:
      throw new HttpsError("invalid-argument", "Unknown run submission operation.");
  }
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
  assertSupportedGameCompatVersion(gameCompatVersion);
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
  const { createRunSession } = await import("./store.js");
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
  return measureRewardStage(runSessionId, "grant_handler", async () => {
    await measureRewardStage(runSessionId, "grant_account_guard", () =>
      assertAccountActive(db, uid));
    const nowMs = captureAuthorityTimeMs(clock);
    await measureRewardStage(runSessionId, "grant_quota", () => consumeUserQuota({
      db,
      uid,
      route: "upload_grant",
      nowMs,
    }));
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
  });
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
  return measureRewardStage(runSessionId, "finalize_handler", async () => {
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
  });
}

export async function handleRunSessionLoadStatus(
  request: CallableRequestLike,
  db: Firestore,
  clock: AuthorityClock = systemAuthorityClock,
): Promise<{ submissionStatus: JsonObject }> {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { userId, runSessionId } = parseRunSessionLoadStatusRequest(request.data);
  if (userId !== uid) {
    throw new HttpsError("permission-denied", "userId does not match auth uid.");
  }
  return measureRewardStage(runSessionId, "status_handler", async () => {
    await assertAccountActive(db, uid);
    await consumeUserQuota({
      db,
      uid,
      route: "run_status",
      nowMs: captureAuthorityTimeMs(clock),
    });
    const result = await loadRunSessionSubmissionStatus({
      db,
      uid,
      runSessionId,
    });
    return {
      submissionStatus: result.submissionStatus,
    };
  });
}

async function loadBoardManifestWithProvisioningFallback(args: {
  db: Firestore;
  mode: "competitive" | "weekly";
  levelId: string;
  gameCompatVersion: string;
  nowMs: number;
}) {
  const { ensureManagedBoardForModeLevel, resolveBoardProvisioningConfigForGameCompatVersion } =
    await import("../boards/provisioning.js");
  const config = resolveBoardProvisioningConfigForGameCompatVersion(
    args.gameCompatVersion,
  );
  const loadArgs = {
    ...args,
    rulesetVersion: config.rulesetVersion,
    scoreVersion: config.scoreVersion,
    ghostVersion: config.ghostVersion,
  };
  try {
    return await loadActiveBoardManifest(loadArgs);
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
    config,
    includeNextWindows: false,
  });

  return loadActiveBoardManifest(loadArgs);
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
