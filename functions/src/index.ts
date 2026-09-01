import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { setGlobalOptions } from "firebase-functions/v2";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { HttpsError, onCall, onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";

import {
  appCheckCallableOptions,
  logAppCheckObservation,
} from "./abuse/app_check.js";
import {
  cleanupExpiredAbuseQuota,
  consumeUserQuota,
} from "./abuse/quota.js";
import {
  processPendingAccountDeletions,
  requestAccountDeletion,
} from "./account/delete.js";
import { assertAccountActive } from "./account/deletion_guard.js";
import { parseAccountDeleteRequest } from "./account/validators.js";
import {
  captureAuthorityTimeMs,
  systemAuthorityClock,
} from "./authority_time.js";
import {
  requirePlayGamesCallableUser,
  requireRecentPlayGamesAuthentication,
} from "./auth/callable_identity.js";
import {
  loadOrCreatePlayerProfile,
  updatePlayerProfile,
} from "./profile/store.js";
import { repairProfileConsistency } from "./profile/consistency_repair.js";
import {
  parseLoadPlayerProfileRequest,
  parseUpdatePlayerProfileRequest,
} from "./profile/validators.js";
import { loadOrCreateCanonicalState } from "./ownership/canonical_store.js";
import { executeOwnershipCommand } from "./ownership/command_executor.js";
import { maintainOwnershipIdempotencyRetention } from "./ownership/idempotency_retention.js";
import {
  parseExecuteCommandRequest,
  parseLoadCanonicalRequest,
} from "./ownership/validators.js";
import {
  handleRunBoardsLoadActive,
  handleRunSessionCreate,
  handleRunSessionCreateUploadGrant,
  handleRunSessionFinalizeUpload,
  handleRunSessionLoadStatus,
} from "./runs/callable_handlers.js";
import { ensureManagedLeaderboardBoards } from "./boards/provisioning.js";
import { runReplaySubmissionCleanup } from "./runs/cleanup.js";
import { settleAcceptedRunSession } from "./runs/reward_settlement.js";
import { enqueueAcceptedRunProjection } from "./runs/projection_dispatch.js";
import {
  parseProjectionReconciliationBatchSize,
  projectionReconciliationSchedule,
  reconcileLeaderboardBoardProjections,
} from "./runs/projection_reconciliation.js";
import {
  dispatchImmediateSettlement,
  ImmediateSettlementDispatchRequestError,
} from "./runs/immediate_settlement_dispatch.js";
import { logSettlementMetric } from "./runs/settlement_metrics.js";
import { repairStaleRunValidations } from "./runs/validation_repair.js";
import { repairPendingSettlements } from "./runs/settlement_repair.js";
import {
  handleLeaderboardLoadActiveBoardData,
  handleLeaderboardLoadBoard,
  handleLeaderboardLoadMyRank,
} from "./leaderboards/callable_handlers.js";
import { handleGhostLoadManifest } from "./ghosts/callable_handlers.js";

if (getApps().length === 0) {
  initializeApp();
}

const defaultFunctionsRegion =
  process.env.FUNCTIONS_REGION?.trim() || "europe-west1";

setGlobalOptions({
  region: defaultFunctionsRegion,
  serviceAccount: "sa-run-control@rpg-runner-d7add.iam.gserviceaccount.com",
});

const db = getFirestore();
const userCallableAppCheckOptions = appCheckCallableOptions();

const runSessionCreateRegion =
  process.env.RUN_SESSION_CREATE_REGION?.trim() ||
  defaultFunctionsRegion;
const runSessionCreateMinInstances = readNonNegativeInt(
  process.env.RUN_SESSION_CREATE_MIN_INSTANCES,
);
const leaderboardRegion =
  process.env.LEADERBOARD_REGION?.trim() ||
  defaultFunctionsRegion;
const leaderboardMinInstances = readNonNegativeInt(
  process.env.LEADERBOARD_MIN_INSTANCES,
);
const settlementRepairBatchSize = readPositiveInt(
  process.env.RUN_SETTLEMENT_REPAIR_BATCH_SIZE,
) ?? 64;
// A run still pending 15 minutes after its durable handoff needs operator attention.
const settlementStaleThresholdMs = readPositiveInt(
  process.env.RUN_SETTLEMENT_STALE_THRESHOLD_MS,
) ?? 15 * 60 * 1000;
const validationRepairBatchSize = readPositiveInt(
  process.env.RUN_VALIDATION_REPAIR_BATCH_SIZE,
) ?? 64;
const projectionReconciliationBatchSize = parseProjectionReconciliationBatchSize(
  process.env.RUN_PROJECTION_RECONCILIATION_BATCH_SIZE,
);
const replayValidatorServiceAccount =
  process.env.REPLAY_VALIDATOR_SERVICE_ACCOUNT?.trim() ||
  "sa-replay-validator@rpg-runner-d7add.iam.gserviceaccount.com";
const profileConsistencyRepairBatchSize =
  readPositiveInt(process.env.PROFILE_CONSISTENCY_REPAIR_BATCH_SIZE) ?? 64;

export const loadoutOwnershipLoadCanonicalState = onCall(
  userCallableAppCheckOptions,
  async (request) => {
    logAppCheckObservation({
      functionName: "loadoutOwnershipLoadCanonicalState",
      request,
    });
    const uid = requirePlayGamesCallableUser(request.auth);
    const { userId } = parseLoadCanonicalRequest(request.data);
    if (userId !== uid) {
      throw new HttpsError(
        "permission-denied",
        "userId does not match auth uid.",
      );
    }
    await assertAccountActive(db, uid);
    await consumeUserQuota({
      db,
      uid,
      route: "ownership_read",
      nowMs: captureAuthorityTimeMs(systemAuthorityClock),
    });
    const canonicalState = await loadOrCreateCanonicalState({
      db,
      uid,
    });
    return { canonicalState };
  },
);

export const loadoutOwnershipExecuteCommand = onCall(
  userCallableAppCheckOptions,
  async (request) => {
    logAppCheckObservation({
      functionName: "loadoutOwnershipExecuteCommand",
      request,
    });
    const uid = requirePlayGamesCallableUser(request.auth);
    const { command } = parseExecuteCommandRequest(request.data);
    if (command.userId !== uid) {
      throw new HttpsError(
        "permission-denied",
        "userId does not match auth uid.",
      );
    }
    await assertAccountActive(db, uid);
    await consumeUserQuota({
      db,
      uid,
      route: "ownership_command",
      nowMs: captureAuthorityTimeMs(systemAuthorityClock),
    });
    const result = await executeOwnershipCommand({
      db,
      uid,
      command,
    });
    return { result };
  },
);

export const playerProfileLoad = onCall(
  userCallableAppCheckOptions,
  async (request) => {
    logAppCheckObservation({ functionName: "playerProfileLoad", request });
    const uid = requirePlayGamesCallableUser(request.auth);
    const { userId } = parseLoadPlayerProfileRequest(request.data);
    if (userId !== uid) {
      throw new HttpsError(
        "permission-denied",
        "userId does not match auth uid.",
      );
    }
    await assertAccountActive(db, uid);
    await consumeUserQuota({
      db,
      uid,
      route: "profile_read",
      nowMs: captureAuthorityTimeMs(systemAuthorityClock),
    });
    const profile = await loadOrCreatePlayerProfile({ db, uid });
    return { profile };
  },
);

export const playerProfileUpdate = onCall(
  userCallableAppCheckOptions,
  async (request) => {
    logAppCheckObservation({ functionName: "playerProfileUpdate", request });
    const uid = requirePlayGamesCallableUser(request.auth);
    const { userId, displayName, namePromptCompleted } =
      parseUpdatePlayerProfileRequest(request.data);
    if (userId !== uid) {
      throw new HttpsError(
        "permission-denied",
        "userId does not match auth uid.",
      );
    }
    await assertAccountActive(db, uid);
    const nowMs = captureAuthorityTimeMs(systemAuthorityClock);
    await consumeUserQuota({
      db,
      uid,
      route: "profile_write",
      nowMs,
    });
    const profile = await updatePlayerProfile({
      db,
      uid,
      nowMs,
      displayName,
      namePromptCompleted,
    });
    return { profile };
  },
);

export const accountDelete = onCall(
  userCallableAppCheckOptions,
  async (request) => {
    logAppCheckObservation({ functionName: "accountDelete", request });
    const nowMs = captureAuthorityTimeMs(systemAuthorityClock);
    const uid = requireRecentPlayGamesAuthentication({
      auth: request.auth,
      nowMs,
    });
    const { userId } = parseAccountDeleteRequest(request.data);
    if (userId !== uid) {
      throw new HttpsError(
        "permission-denied",
        "userId does not match auth uid.",
      );
    }
    await consumeUserQuota({
      db,
      uid,
      route: "account_delete",
      nowMs,
      allowAccountDeletionRequest: true,
    });
    const result = await requestAccountDeletion({
      db,
      uid,
      nowMs,
    });
    return { result };
  },
);

export const runBoardsLoadActive = onCall(
  userCallableAppCheckOptions,
  async (request) => {
    logAppCheckObservation({ functionName: "runBoardsLoadActive", request });
    requirePlayGamesCallableUser(request.auth);
    return handleRunBoardsLoadActive(request, db);
  },
);

export const runSessionCreate = onCall(
  {
    ...userCallableAppCheckOptions,
    region: runSessionCreateRegion,
    ...(runSessionCreateMinInstances !== undefined
      ? { minInstances: runSessionCreateMinInstances }
      : {}),
  },
  async (request) => {
    logAppCheckObservation({ functionName: "runSessionCreate", request });
    requirePlayGamesCallableUser(request.auth);
    return handleRunSessionCreate(request, db);
  },
);

export const runSessionCreateUploadGrant = onCall(
  userCallableAppCheckOptions,
  async (request) => {
    logAppCheckObservation({
      functionName: "runSessionCreateUploadGrant",
      request,
    });
    requirePlayGamesCallableUser(request.auth);
    return handleRunSessionCreateUploadGrant(request, db);
  },
);

export const runSessionFinalizeUpload = onCall(
  userCallableAppCheckOptions,
  async (request) => {
    logAppCheckObservation({
      functionName: "runSessionFinalizeUpload",
      request,
    });
    requirePlayGamesCallableUser(request.auth);
    return handleRunSessionFinalizeUpload(request, db);
  },
);

export const runSessionLoadStatus = onCall(
  userCallableAppCheckOptions,
  async (request) => {
    logAppCheckObservation({ functionName: "runSessionLoadStatus", request });
    requirePlayGamesCallableUser(request.auth);
    return handleRunSessionLoadStatus(request, db);
  },
);

export const runSettlementOnHandoff = onDocumentWritten(
  {
    document: "run_sessions/{runSessionId}",
    retry: true,
  },
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists || after.data()?.state !== "settlement_pending") {
      return;
    }
    const outcome = await settleAcceptedRunSession({
      db,
      runSessionId: event.params.runSessionId,
      deliverySource: "eventarc",
    });
    logSettlementMetric({
      event: "settlement_eventarc_delivery",
      runSessionId: event.params.runSessionId,
      outcome,
      deliverySource: "eventarc",
    });
  },
);

/**
 * Enqueues optional board projection only after the accepted run is durable.
 * Its retry contract is independent from settlement and cannot hold gold back.
 */
export const runProjectionOnAccepted = onDocumentWritten(
  {
    document: "validated_runs/{runSessionId}",
    retry: true,
  },
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists || after.data()?.accepted !== true) {
      return;
    }
    const outcome = await enqueueAcceptedRunProjection({
      db,
      runSessionId: event.params.runSessionId,
    });
    logSettlementMetric({
      event: "projection_enqueue",
      runSessionId: event.params.runSessionId,
      outcome,
    });
  },
);

/**
 * Low-latency, IAM-only delivery path for a validator settlement handoff.
 *
 * The validator can call this only after it has atomically persisted
 * settlement_pending. Eventarc and scheduled repair invoke the same
 * transaction when this request is unavailable, slow, or duplicated.
 */
export const runSettlementImmediate = onRequest(
  {
    invoker: replayValidatorServiceAccount,
  },
  async (request, response) => {
    if (request.method !== "POST") {
      response.status(405).json({ error: "method_not_allowed" });
      return;
    }
    try {
      const result = await dispatchImmediateSettlement({
        db,
        data: request.body,
      });
      logSettlementMetric({
        event: "settlement_immediate_response",
        runSessionId: result.runSessionId,
        deliverySource: "immediate",
        outcome: result.outcome,
      });
      if (result.outcome === "not_ready") {
        response.status(409).json(result);
        return;
      }
      if (result.outcome === "invariant_violation") {
        response.status(422).json(result);
        return;
      }
      response.status(200).json(result);
    } catch (error) {
      if (error instanceof ImmediateSettlementDispatchRequestError) {
        response.status(400).json({ error: "invalid_request", message: error.message });
        return;
      }
      console.error("runSettlementImmediate failed", error);
      response.status(500).json({ error: "settlement_failed" });
    }
  },
);

export const leaderboardLoadBoard = onCall(
  {
    ...userCallableAppCheckOptions,
    region: leaderboardRegion,
    ...(leaderboardMinInstances !== undefined
      ? { minInstances: leaderboardMinInstances }
      : {}),
  },
  async (request) => {
    logAppCheckObservation({ functionName: "leaderboardLoadBoard", request });
    requirePlayGamesCallableUser(request.auth);
    return handleLeaderboardLoadBoard(request, db);
  },
);

export const leaderboardLoadMyRank = onCall(
  {
    ...userCallableAppCheckOptions,
    region: leaderboardRegion,
    ...(leaderboardMinInstances !== undefined
      ? { minInstances: leaderboardMinInstances }
      : {}),
  },
  async (request) => {
    logAppCheckObservation({ functionName: "leaderboardLoadMyRank", request });
    requirePlayGamesCallableUser(request.auth);
    return handleLeaderboardLoadMyRank(request, db);
  },
);

export const leaderboardLoadActiveBoardData = onCall(
  {
    ...userCallableAppCheckOptions,
    region: leaderboardRegion,
    ...(leaderboardMinInstances !== undefined
      ? { minInstances: leaderboardMinInstances }
      : {}),
  },
  async (request) => {
    logAppCheckObservation({
      functionName: "leaderboardLoadActiveBoardData",
      request,
    });
    requirePlayGamesCallableUser(request.auth);
    return handleLeaderboardLoadActiveBoardData(request, db);
  },
);

export const ghostLoadManifest = onCall(
  userCallableAppCheckOptions,
  async (request) => {
    logAppCheckObservation({ functionName: "ghostLoadManifest", request });
    requirePlayGamesCallableUser(request.auth);
    return handleGhostLoadManifest(request, db);
  },
);

export const runSubmissionCleanup = onSchedule(
  {
    schedule: "every 60 minutes",
    timeZone: "Etc/UTC",
  },
  async () => {
    const result = await runReplaySubmissionCleanup({ db });
    console.log("runSubmissionCleanup", result);
  },
);

export const playerProfileConsistencyRepair = onSchedule(
  {
    schedule: "every 60 minutes",
    timeZone: "Etc/UTC",
  },
  async () => {
    const result = await repairProfileConsistency({
      db,
      batchSize: profileConsistencyRepairBatchSize,
    });
    console.log("playerProfileConsistencyRepair", result);
  },
);

export const abuseQuotaRetentionCleanup = onSchedule(
  {
    schedule: "every 60 minutes",
    timeZone: "Etc/UTC",
  },
  async () => {
    const result = await cleanupExpiredAbuseQuota({ db });
    logger.info("abuseQuotaRetentionCleanup", result);
  },
);

export const ownershipIdempotencyRetentionCleanup = onSchedule(
  {
    schedule: "every 60 minutes",
    timeZone: "Etc/UTC",
  },
  async () => {
    const result = await maintainOwnershipIdempotencyRetention({ db });
    console.log("ownershipIdempotencyRetentionCleanup", result);
  },
);

export const accountDeletionRepair = onSchedule(
  {
    schedule: "every 15 minutes",
    timeZone: "Etc/UTC",
  },
  async () => {
    const result = await processPendingAccountDeletions({ db });
    logger.info("accountDeletionRepair", result);
  },
);

export const runSettlementRepair = onSchedule(
  {
    schedule: "every 15 minutes",
    timeZone: "Etc/UTC",
  },
  async () => {
    const result = await repairPendingSettlements({
      db,
      options: {
        batchSize: settlementRepairBatchSize,
        staleThresholdMs: settlementStaleThresholdMs,
      },
    });
    console.log("runSettlementRepair", result);
    if (result.failureCount > 0) {
      throw new Error(
        `run settlement repair had ${result.failureCount} infrastructure failures`,
      );
    }
  },
);

/**
 * Reclaims expired validation leases and requeues orphaned pending work.
 *
 * Queue retries remain the ordinary delivery authority. This bounded repair
 * scan handles process death, task exhaustion, and lost-task edge cases.
 */
export const runValidationRepair = onSchedule(
  {
    schedule: "every 15 minutes",
    timeZone: "Etc/UTC",
  },
  async () => {
    const result = await repairStaleRunValidations({
      db,
      options: {
        batchSize: validationRepairBatchSize,
      },
    });
    console.log("runValidationRepair", result);
    if (result.failureCount > 0) {
      throw new Error(
        `run validation repair had ${result.failureCount} enqueue failures`,
      );
    }
  },
);

/**
 * Rebuilds board projections from player-best truth even when no new score is
 * submitted. The persisted cursor bounds each invocation while eventually
 * visiting active, closed, and empty boards.
 */
export const runProjectionReconciliation = onSchedule(
  {
    schedule: projectionReconciliationSchedule,
    timeZone: "Etc/UTC",
    memory: "512MiB",
  },
  async () => {
    const result = await reconcileLeaderboardBoardProjections({
      db,
      batchSize: projectionReconciliationBatchSize,
    });
    logger.info("runProjectionReconciliation", result);
  },
);

export const leaderboardBoardMaintenance = onSchedule(
  {
    schedule: "every 60 minutes",
    timeZone: "Etc/UTC",
  },
  async () => {
    const result = await ensureManagedLeaderboardBoards({ db });
    console.log("leaderboardBoardMaintenance", result);
  },
);

function readNonNegativeInt(raw: string | undefined): number | undefined {
  const value = raw?.trim();
  if (!value) {
    return undefined;
  }
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed) || parsed < 0) {
    return undefined;
  }
  return parsed;
}

function readPositiveInt(raw: string | undefined): number | undefined {
  const parsed = readNonNegativeInt(raw);
  return parsed !== undefined && parsed > 0 ? parsed : undefined;
}
