import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { setGlobalOptions } from "firebase-functions/v2";
import { onDocumentCreated, onDocumentWritten } from "firebase-functions/v2/firestore";
import { HttpsError, onCall, onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onTaskDispatched } from "firebase-functions/v2/tasks";

import {
  appCheckCallableOptions,
  logAppCheckObservation,
} from "./abuse/app_check.js";
import {
  cleanupExpiredAbuseQuota,
  consumeUserQuota,
} from "./abuse/quota.js";
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
  parseLoadPlayerProfileRequest,
  parseUpdatePlayerProfileRequest,
} from "./profile/validators.js";
import {
  parseProjectionReconciliationBatchSize,
  projectionReconciliationSchedule,
} from "./runs/projection_reconciliation_policy.js";
import { logSettlementMetric } from "./runs/settlement_metrics.js";
import type { InboxOperation } from "./inbox/validators.js";
import { readDeploymentIdentity } from "./deployment_identity.js";

if (getApps().length === 0) {
  initializeApp();
}

const defaultFunctionsRegion =
  process.env.FUNCTIONS_REGION?.trim() || "europe-west1";
const deploymentIdentity = readDeploymentIdentity();

setGlobalOptions({
  region: defaultFunctionsRegion,
  serviceAccount: deploymentIdentity.runControlServiceAccount,
  minInstances: 0,
});

const db = getFirestore();
const userCallableAppCheckOptions = appCheckCallableOptions();

export const inboxLoadSummary = inboxCallable("inboxLoadSummary", "summary");
export const inboxList = inboxCallable("inboxList", "list");
export const inboxMarkRead = inboxCallable("inboxMarkRead", "read");
export const inboxClaimReward = inboxCallable("inboxClaimReward", "claim");
export const inboxDeleteMessage = inboxCallable("inboxDeleteMessage", "delete");

function inboxCallable(functionName: string, operation: InboxOperation) {
  return onCall(userCallableAppCheckOptions, async (request) => {
    logAppCheckObservation({ functionName, request });
    requirePlayGamesCallableUser(request.auth);
    const { handleInboxRequest } = await import("./inbox/callable_handlers.js");
    return handleInboxRequest(request, db, operation);
  });
}

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
  deploymentIdentity.replayValidatorServiceAccount;
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
    const { parseLoadCanonicalRequest } = await import("./ownership/validators.js");
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
    const { loadOrCreateCanonicalState } = await import("./ownership/canonical_store.js");
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
    const { parseExecuteCommandRequest } = await import("./ownership/validators.js");
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
    const { executeOwnershipCommand } = await import("./ownership/command_executor.js");
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
    const { loadOrCreatePlayerProfile } = await import("./profile/store.js");
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
    const { updatePlayerProfile } = await import("./profile/store.js");
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
    const { requestAccountDeletion } = await import("./account/delete.js");
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
    const { handleRunBoardsLoadActive } = await import("./runs/callable_handlers.js");
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
    const { handleRunSessionCreate } = await import("./runs/callable_handlers.js");
    return handleRunSessionCreate(request, db);
  },
);

export const runSubmission = onCall(
  { ...userCallableAppCheckOptions, minInstances: 0 },
  async (request) => {
    logAppCheckObservation({ functionName: "runSubmission", request });
    requirePlayGamesCallableUser(request.auth);
    const { handleRunSubmission } = await import("./runs/callable_handlers.js");
    return handleRunSubmission(request, db);
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
    const { handleRunSessionCreateUploadGrant } = await import("./runs/callable_handlers.js");
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
    const { handleRunSessionFinalizeUpload } = await import("./runs/callable_handlers.js");
    return handleRunSessionFinalizeUpload(request, db);
  },
);

export const runSessionLoadStatus = onCall(
  userCallableAppCheckOptions,
  async (request) => {
    logAppCheckObservation({ functionName: "runSessionLoadStatus", request });
    requirePlayGamesCallableUser(request.auth);
    const { handleRunSessionLoadStatus } = await import("./runs/callable_handlers.js");
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
    if (!after?.exists) return;
    const state = after.data()?.state;
    if (["uploaded", "pending_validation"].includes(state) &&
        event.data?.before.data()?.state !== state) {
      const { enqueuePendingWork, runRecoveryDelaySeconds } = await import("./pending_work.js");
      await enqueuePendingWork({ work: { kind: "run", runSessionId: event.params.runSessionId },
        generation: "initial", delaySeconds: runRecoveryDelaySeconds });
    }
    if (state !== "settlement_pending") {
      return;
    }
    const { settleAcceptedRunSession } = await import("./runs/reward_settlement.js");
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

export const accountDeletionOnRequest = onDocumentCreated(
  { document: "account_deletion_requests/{uid}", retry: true },
  async (event) => {
    if (!event.data?.exists || event.data.get("state") === "complete") return;
    const { enqueuePendingWork } = await import("./pending_work.js");
    await enqueuePendingWork({ work: { kind: "account", uid: event.params.uid },
      generation: `initial-${event.data.get("requestedAtMs")}` });
  },
);

/** IAM-only, request-billed continuation; no timers or work after response. */
export const runPendingWork = onTaskDispatched(
  { invoker: deploymentIdentity.runControlServiceAccount,
    timeoutSeconds: 120, maxInstances: 5,
    retryConfig: { maxAttempts: 1000, maxRetrySeconds: 86400,
      minBackoffSeconds: 30, maxBackoffSeconds: 60, maxDoublings: 1 },
    rateLimits: { maxConcurrentDispatches: 5, maxDispatchesPerSecond: 5 } },
  async (request) => {
    const { parsePendingWork, processPendingWork } = await import("./pending_work.js");
    const work = parsePendingWork(request.data);
    const result = await processPendingWork({ db, work });
    logger.info("pending_work", { kind: work.kind, outcome: result,
      ...(work.kind === "run" ? { runSessionId: work.runSessionId } : {}) });
    if (result === "pending") throw new HttpsError("unavailable", "Durable work remains pending.");
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
    const { enqueueAcceptedRunProjection } = await import("./runs/projection_dispatch.js");
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
    const { dispatchImmediateSettlement, ImmediateSettlementDispatchRequestError } = await import("./runs/immediate_settlement_dispatch.js");
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
    const { handleLeaderboardLoadBoard } = await import("./leaderboards/callable_handlers.js");
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
    const { handleLeaderboardLoadMyRank } = await import("./leaderboards/callable_handlers.js");
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
    const { handleLeaderboardLoadActiveBoardData } = await import("./leaderboards/callable_handlers.js");
    return handleLeaderboardLoadActiveBoardData(request, db);
  },
);

export const ghostLoadManifest = onCall(
  userCallableAppCheckOptions,
  async (request) => {
    logAppCheckObservation({ functionName: "ghostLoadManifest", request });
    requirePlayGamesCallableUser(request.auth);
    const { handleGhostLoadManifest } = await import("./ghosts/callable_handlers.js");
    return handleGhostLoadManifest(request, db);
  },
);

export const runSubmissionCleanup = onSchedule(
  {
    schedule: "every 60 minutes",
    timeZone: "Etc/UTC",
  },
  async () => {
    const { runReplaySubmissionCleanup } = await import("./runs/cleanup.js");
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
    const { repairProfileConsistency } = await import("./profile/consistency_repair.js");
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
    const { maintainOwnershipIdempotencyRetention } = await import("./ownership/idempotency_retention.js");
    const result = await maintainOwnershipIdempotencyRetention({ db });
    console.log("ownershipIdempotencyRetentionCleanup", result);
  },
);

export const inboxRetentionCleanup = onSchedule(
  { schedule: "every 60 minutes", timeZone: "Etc/UTC", timeoutSeconds: 540, maxInstances: 1 },
  async () => {
    const { maintainInboxRetention } = await import("./inbox/retention.js");
    const result = await maintainInboxRetention({ db });
    logger.info("inboxRetentionCleanup", result);
  },
);

export const accountDeletionRepair = onSchedule(
  {
    schedule: "every 60 minutes",
    timeZone: "Etc/UTC",
  },
  async () => {
    const { enqueuePendingWork } = await import("./pending_work.js");
    const { processPendingAccountDeletions } = await import("./account/delete.js");
    const result = await processPendingAccountDeletions({ db,
      onPending: (uid) => enqueuePendingWork({ work: { kind: "account", uid },
        generation: `repair-${Math.floor(Date.now() / 3600000)}` }) });
    logger.info("accountDeletionRepair", result);
    if (result.continuationFailureCount > 0) {
      throw new Error("Account deletion continuation enqueue failed; safety scan still progressed.");
    }
  },
);

export const runSettlementRepair = onSchedule(
  {
    schedule: "every 60 minutes",
    timeZone: "Etc/UTC",
  },
  async () => {
    const { repairPendingSettlements } = await import("./runs/settlement_repair.js");
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
    schedule: "every 60 minutes",
    timeZone: "Etc/UTC",
  },
  async () => {
    const { repairStaleRunValidations } = await import("./runs/validation_repair.js");
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
    const { reconcileLeaderboardBoardProjections } = await import("./runs/projection_reconciliation.js");
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
    const { pruneObsoleteLeaderboardBoards } = await import("./boards/retention.js");
    const { ensureManagedLeaderboardBoards } = await import("./boards/provisioning.js");
    const result = await ensureManagedLeaderboardBoards({ db });
    console.log("leaderboardBoardMaintenance", result);
    const retention = await pruneObsoleteLeaderboardBoards({ db, apply: true });
    logger.info("leaderboardBoardRetention", retention);
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
