import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { setGlobalOptions } from "firebase-functions/v2";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";

import { deleteAccountAndData } from "./account/delete.js";
import { parseAccountDeleteRequest } from "./account/validators.js";
import {
  loadOrCreatePlayerProfile,
  updatePlayerProfile,
} from "./profile/store.js";
import {
  parseLoadPlayerProfileRequest,
  parseUpdatePlayerProfileRequest,
} from "./profile/validators.js";
import { loadOrCreateCanonicalState } from "./ownership/canonical_store.js";
import { executeOwnershipCommand } from "./ownership/command_executor.js";
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

export const loadoutOwnershipLoadCanonicalState = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { userId } = parseLoadCanonicalRequest(request.data);
  if (userId !== uid) {
    throw new HttpsError("permission-denied", "userId does not match auth uid.");
  }
  const canonicalState = await loadOrCreateCanonicalState({
    db,
    uid,
  });
  return { canonicalState };
});

export const loadoutOwnershipExecuteCommand = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { command } = parseExecuteCommandRequest(request.data);
  if (command.userId !== uid) {
    throw new HttpsError("permission-denied", "userId does not match auth uid.");
  }
  const result = await executeOwnershipCommand({
    db,
    uid,
    command,
  });
  return { result };
});

export const playerProfileLoad = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { userId } = parseLoadPlayerProfileRequest(request.data);
  if (userId !== uid) {
    throw new HttpsError("permission-denied", "userId does not match auth uid.");
  }
  const profile = await loadOrCreatePlayerProfile({ db, uid });
  return { profile };
});

export const playerProfileUpdate = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const {
    userId,
    displayName,
    displayNameLastChangedAtMs,
    namePromptCompleted,
  } = parseUpdatePlayerProfileRequest(request.data);
  if (userId !== uid) {
    throw new HttpsError("permission-denied", "userId does not match auth uid.");
  }
  const profile = await updatePlayerProfile({
    db,
    uid,
    displayName,
    displayNameLastChangedAtMs,
    namePromptCompleted,
  });
  return { profile };
});

export const accountDelete = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { userId } = parseAccountDeleteRequest(request.data);
  if (userId !== uid) {
    throw new HttpsError("permission-denied", "userId does not match auth uid.");
  }
  const result = await deleteAccountAndData({
    db,
    uid,
  });
  return { result };
});

export const runBoardsLoadActive = onCall(async (request) => {
  return handleRunBoardsLoadActive(request, db);
});

export const runSessionCreate = onCall(
  {
    region: runSessionCreateRegion,
    ...(runSessionCreateMinInstances !== undefined
      ? { minInstances: runSessionCreateMinInstances }
      : {}),
  },
  async (request) => {
    return handleRunSessionCreate(request, db);
  },
);

export const runSessionCreateUploadGrant = onCall(async (request) => {
  return handleRunSessionCreateUploadGrant(request, db);
});

export const runSessionFinalizeUpload = onCall(async (request) => {
  return handleRunSessionFinalizeUpload(request, db);
});

export const runSessionLoadStatus = onCall(async (request) => {
  return handleRunSessionLoadStatus(request, db);
});

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
    });
    console.log("runSettlementOnHandoff", {
      runSessionId: event.params.runSessionId,
      outcome,
    });
  },
);

export const leaderboardLoadBoard = onCall(
  {
    region: leaderboardRegion,
    ...(leaderboardMinInstances !== undefined
      ? { minInstances: leaderboardMinInstances }
      : {}),
  },
  async (request) => {
    return handleLeaderboardLoadBoard(request, db);
  },
);

export const leaderboardLoadMyRank = onCall(
  {
    region: leaderboardRegion,
    ...(leaderboardMinInstances !== undefined
      ? { minInstances: leaderboardMinInstances }
      : {}),
  },
  async (request) => {
    return handleLeaderboardLoadMyRank(request, db);
  },
);

export const leaderboardLoadActiveBoardData = onCall(
  {
    region: leaderboardRegion,
    ...(leaderboardMinInstances !== undefined
      ? { minInstances: leaderboardMinInstances }
      : {}),
  },
  async (request) => {
    return handleLeaderboardLoadActiveBoardData(request, db);
  },
);

export const ghostLoadManifest = onCall(async (request) => {
  return handleGhostLoadManifest(request, db);
});

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

export const runSettlementRepair = onSchedule(
  {
    schedule: "every 5 minutes",
    timeZone: "Etc/UTC",
  },
  async () => {
    const pendingSessions = await db
      .collection("run_sessions")
      .where("state", "==", "settlement_pending")
      .limit(settlementRepairBatchSize)
      .get();
    let settledCount = 0;
    const failures: string[] = [];
    for (const session of pendingSessions.docs) {
      try {
        const outcome = await settleAcceptedRunSession({
          db,
          runSessionId: session.id,
        });
        if (outcome === "settled") {
          settledCount += 1;
        }
      } catch (error) {
        failures.push(`${session.id}: ${String(error)}`);
      }
    }
    console.log("runSettlementRepair", {
      scannedCount: pendingSessions.size,
      settledCount,
      failureCount: failures.length,
    });
    if (failures.length > 0) {
      throw new Error(`run settlement repair failed: ${failures.join("; ")}`);
    }
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
