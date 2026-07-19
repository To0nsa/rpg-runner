#!/usr/bin/env node

import { createHash, randomBytes } from "node:crypto";
import { gzipSync } from "node:zlib";
import { access, mkdir, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";

class CallableError extends Error {
  constructor({ functionName, httpStatus, status, message }) {
    super(
      `${functionName} failed (HTTP ${httpStatus}, ${status}): ${String(message).slice(0, 500)}`,
    );
    this.name = "CallableError";
    this.functionName = functionName;
    this.httpStatus = httpStatus;
    this.status = status;
  }
}

const args = parseArgs(process.argv.slice(2));
const projectId = requireArg(args, "project");
const region = args.get("region")?.trim() || "europe-west1";
const apiKey = process.env.FIREBASE_WEB_API_KEY?.trim();
if (!apiKey) {
  throw new Error("FIREBASE_WEB_API_KEY is required.");
}
const statePath = resolve(
  args.get("state-file")?.trim() ||
    ".tmp/functions-remediation-canary-state.json",
);
const cleanupSignalPath = optionalResolvedPath(
  args.get("cleanup-signal-file"),
);
const cleanupWaitMs =
  parsePositiveInteger(args.get("cleanup-wait-seconds")) * 1000 ||
  30 * 60 * 1000;
const gameCompatVersion = "2026.03.0";
const sessionId = `canary-session-${randomBytes(8).toString("hex")}`;
const marker = `Canary${randomBytes(3).toString("hex")}`;

let auth;
let deletionRequested = false;
let state = {
  schemaVersion: 1,
  projectId,
  region,
  marker,
  createdAt: new Date().toISOString(),
  phase: "starting",
};

try {
  auth = await createAnonymousAccount();
  state = {
    ...state,
    localId: auth.localId,
    uidHash: shortHash(auth.localId),
    phase: "account_created",
  };
  await saveState();

  const report = await runCanary();
  if (cleanupSignalPath) {
    state = {
      ...state,
      phase: "awaiting_cleanup_signal",
      cleanupWaitStartedAt: new Date().toISOString(),
    };
    await saveState();
    await waitForCleanupSignal();
  }
  const deletion = await requestDeletion();
  deletionRequested = true;
  state = {
    ...state,
    phase: "deletion_requested",
    deletionRequestedAt: new Date().toISOString(),
    deletionStatus: deletion.status,
  };
  await saveState();

  console.log(
    JSON.stringify(
      {
        ...report,
        deletion: {
          requested: true,
          status: deletion.status,
          uidHash: state.uidHash,
          stateFile: statePath,
        },
      },
      null,
      2,
    ),
  );
} catch (error) {
  state = {
    ...state,
    phase: "failed",
    failedAt: new Date().toISOString(),
    errorClass: error instanceof Error ? error.name : typeof error,
    errorMessage: safeErrorMessage(error),
  };
  if (auth && !deletionRequested) {
    try {
      const deletion = await requestDeletion();
      deletionRequested = true;
      state = {
        ...state,
        phase: "failed_deletion_requested",
        deletionRequestedAt: new Date().toISOString(),
        deletionStatus: deletion.status,
      };
    } catch (deletionError) {
      state = {
        ...state,
        cleanupRequired: true,
        deletionErrorClass:
          deletionError instanceof Error ? deletionError.name : typeof deletionError,
        deletionErrorMessage: safeErrorMessage(deletionError),
      };
    }
  }
  await saveState();
  console.error(
    JSON.stringify(
      {
        canary: "failed",
        phase: state.phase,
        uidHash: state.uidHash ?? null,
        deletionRequested,
        cleanupRequired: state.cleanupRequired === true,
        error: state.errorMessage,
        stateFile: statePath,
      },
      null,
      2,
    ),
  );
  process.exitCode = 1;
}

async function runCanary() {
  const negativeChecks = {};

  const profileLoad = await callable("playerProfileLoad", {
    userId: auth.localId,
    sessionId,
  });
  assert(profileLoad.profile?.displayName === "", "Initial profile was not empty.");

  const updatedProfile = await callable("playerProfileUpdate", {
    userId: auth.localId,
    sessionId,
    displayName: marker,
    namePromptCompleted: true,
  });
  assert(
    updatedProfile.profile?.displayName === marker,
    "Initial profile name update did not persist.",
  );
  assert(
    updatedProfile.profile?.displayNameLastChangedAtMs === 0,
    "Initial-name timestamp exception was not preserved.",
  );

  await expectCallableError(
    "profile_server_time_rejection",
    "INVALID_ARGUMENT",
    () =>
      callable("playerProfileUpdate", {
        userId: auth.localId,
        sessionId,
        displayName: marker,
        displayNameLastChangedAtMs: 1,
      }),
  );
  negativeChecks.profileServerTimeRejected = true;

  await expectCallableError("uid_mismatch", "PERMISSION_DENIED", () =>
    callable("playerProfileLoad", {
      userId: `different-${auth.localId}`,
      sessionId,
    }),
  );
  negativeChecks.uidMismatchRejected = true;

  const canonicalLoad = await callable(
    "loadoutOwnershipLoadCanonicalState",
    {
      userId: auth.localId,
      sessionId,
    },
  );
  let canonical = canonicalLoad.canonicalState;
  assert(isObject(canonical), "Canonical ownership response was malformed.");

  await expectCallableError(
    "server_only_ownership_command",
    "PERMISSION_DENIED",
    () =>
      callable("loadoutOwnershipExecuteCommand", {
        command: {
          type: "awardRunGold",
          userId: auth.localId,
          sessionId,
          expectedRevision: canonical.revision,
          commandId: `canary.forbidden.${randomBytes(6).toString("hex")}`,
          payload: { runId: 1, goldEarned: 9999 },
        },
      }),
  );
  negativeChecks.serverOnlyOwnershipCommandRejected = true;

  const selection = structuredClone(canonical.selection);
  selection.runMode = "competitive";
  selection.runType = "competitive";
  const selectionResult = await callable(
    "loadoutOwnershipExecuteCommand",
    {
      command: {
        type: "setSelection",
        userId: auth.localId,
        sessionId,
        expectedRevision: canonical.revision,
        commandId: `canary.selection.${randomBytes(6).toString("hex")}`,
        payload: { selection },
      },
    },
  );
  assert(
    selectionResult.result?.rejectedReason === null,
    "Competitive selection command was rejected.",
  );
  canonical = selectionResult.result.canonicalState;

  await expectCallableError("client_authority_time", "INVALID_ARGUMENT", () =>
    callable("runSessionCreate", {
      userId: auth.localId,
      sessionId,
      clientRequestId: `canary.now.${randomBytes(6).toString("hex")}`,
      mode: "competitive",
      levelId: "field",
      gameCompatVersion,
      nowMs: 1,
    }),
  );
  negativeChecks.clientAuthorityTimeRejected = true;

  const validRequestId = `canary.valid.${randomBytes(8).toString("hex")}`;
  const validCreatePayload = {
    userId: auth.localId,
    sessionId,
    clientRequestId: validRequestId,
    mode: "competitive",
    levelId: "field",
    gameCompatVersion,
  };
  const validCreate = await callable("runSessionCreate", validCreatePayload);
  const validCreateReplay = await callable(
    "runSessionCreate",
    validCreatePayload,
  );
  const validTicket = validCreate.runTicket;
  assert(isObject(validTicket), "Valid run ticket was malformed.");
  assert(
    validCreateReplay.runTicket?.runSessionId === validTicket.runSessionId,
    "Duplicate run-create request did not return the same run session.",
  );

  const validReplay = buildReplay(validTicket, { invalidSeed: false });
  const validFinalized = await submitReplay(validTicket, validReplay);
  const validTerminal = await waitForTerminal(validTicket.runSessionId);
  assert(
    validTerminal.state === "validated" &&
      validTerminal.validatedRun?.accepted === true,
    `Valid replay did not validate: ${validTerminal.state}`,
  );
  assert(
    validTerminal.reward?.status === "final",
    "Valid replay reward did not reach final settlement.",
  );
  assert(
    ["uploaded", "pending_validation", "validating", "settlement_pending", "validated"].includes(
      validFinalized.state,
    ),
    "Finalize returned an unexpected valid-run state.",
  );

  const projection = await waitForProjection({
    boardId: validTicket.boardId,
    runSessionId: validTicket.runSessionId,
  });
  const ghost = await waitForGhost({
    boardId: validTicket.boardId,
    entryId: validTicket.runSessionId,
  });
  const ghostDownload = await fetch(ghost.downloadUrl);
  assert(ghostDownload.ok, `Ghost download failed with HTTP ${ghostDownload.status}.`);
  const ghostBytes = Buffer.from(await ghostDownload.arrayBuffer());
  assert(ghostBytes.length > 0, "Ghost download was empty.");
  assert(
    ghost.downloadUrlExpiresAtMs > Date.now() &&
      ghost.downloadUrlExpiresAtMs <= Date.now() + 16 * 60 * 1000,
    "Ghost signed download TTL was outside the expected 15-minute window.",
  );

  const invalidRequestId = `canary.invalid.${randomBytes(8).toString("hex")}`;
  const invalidCreate = await callable("runSessionCreate", {
    userId: auth.localId,
    sessionId,
    clientRequestId: invalidRequestId,
    mode: "competitive",
    levelId: "field",
    gameCompatVersion,
  });
  const invalidTicket = invalidCreate.runTicket;
  assert(isObject(invalidTicket), "Invalid-run ticket was malformed.");
  const invalidReplay = buildReplay(invalidTicket, { invalidSeed: true });
  await submitReplay(invalidTicket, invalidReplay);
  const invalidTerminal = await waitForTerminal(invalidTicket.runSessionId);
  assert(
    invalidTerminal.state === "rejected" &&
      invalidTerminal.validatedRun?.accepted === false,
    `Mismatched replay did not reject: ${invalidTerminal.state}`,
  );
  assert(
    invalidTerminal.validatedRun?.rejectionReason === "seed_mismatch",
    `Unexpected rejection reason: ${invalidTerminal.validatedRun?.rejectionReason}`,
  );
  assert(
    invalidTerminal.reward?.status === "revoked",
    "Rejected replay provisional reward was not revoked.",
  );

  const postRejectRank = await callable("leaderboardLoadMyRank", {
    userId: auth.localId,
    sessionId,
    boardId: validTicket.boardId,
  });
  assert(
    postRejectRank.myRank?.myEntry?.runSessionId === validTicket.runSessionId,
    "Rejected replay affected the accepted leaderboard best.",
  );

  state = {
    ...state,
    phase: "canary_verified",
    validRunSessionId: validTicket.runSessionId,
    validRunSessionHash: shortHash(validTicket.runSessionId),
    invalidRunSessionId: invalidTicket.runSessionId,
    invalidRunSessionHash: shortHash(invalidTicket.runSessionId),
    boardId: validTicket.boardId,
    verifiedAt: new Date().toISOString(),
  };
  await saveState();

  return {
    schemaVersion: 1,
    projectId,
    observedAt: new Date().toISOString(),
    uidHash: state.uidHash,
    appCheckTokenSupplied: false,
    negativeChecks,
    validReplay: {
      runSessionHash: state.validRunSessionHash,
      terminalState: validTerminal.state,
      accepted: validTerminal.validatedRun.accepted,
      rewardStatus: validTerminal.reward.status,
      leaderboardProjected:
        projection.myEntry?.runSessionId === validTicket.runSessionId,
      ghostManifestActive:
        ghost.runSessionId === validTicket.runSessionId &&
        ghost.replayStorageRef?.startsWith("ghosts/") === true,
      ghostDownloadBytes: ghostBytes.length,
    },
    invalidReplay: {
      runSessionHash: state.invalidRunSessionHash,
      terminalState: invalidTerminal.state,
      accepted: invalidTerminal.validatedRun.accepted,
      rejectionReason: invalidTerminal.validatedRun.rejectionReason,
      rewardStatus: invalidTerminal.reward.status,
      leaderboardUnaffected:
        postRejectRank.myRank?.myEntry?.runSessionId === validTicket.runSessionId,
    },
    idempotentRunCreate:
      validCreateReplay.runTicket.runSessionId === validTicket.runSessionId,
  };
}

async function createAnonymousAccount() {
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${encodeURIComponent(apiKey)}`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ returnSecureToken: true }),
    },
  );
  const body = await readJson(response);
  if (
    !response.ok ||
    typeof body.localId !== "string" ||
    typeof body.idToken !== "string"
  ) {
    throw new Error(
      `Anonymous Firebase Auth signup failed (${response.status}): ${safeBody(body)}`,
    );
  }
  return {
    localId: body.localId,
    idToken: body.idToken,
  };
}

async function callable(functionName, data) {
  const response = await fetch(
    `https://${region}-${projectId}.cloudfunctions.net/${functionName}`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${auth.idToken}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({ data }),
    },
  );
  const body = await readJson(response);
  if (!response.ok || isObject(body.error)) {
    throw new CallableError({
      functionName,
      httpStatus: response.status,
      status: body.error?.status ?? "UNKNOWN",
      message: body.error?.message ?? safeBody(body),
    });
  }
  if (!isObject(body.result)) {
    throw new Error(`${functionName} returned a malformed callable response.`);
  }
  return body.result;
}

async function expectCallableError(name, expectedStatus, operation) {
  try {
    await operation();
  } catch (error) {
    if (error instanceof CallableError && error.status === expectedStatus) {
      return;
    }
    throw new Error(
      `${name} expected ${expectedStatus}, got ${safeErrorMessage(error)}.`,
    );
  }
  throw new Error(`${name} unexpectedly succeeded.`);
}

function buildReplay(ticket, { invalidSeed }) {
  const seed =
    invalidSeed
      ? ticket.seed === 0x7fffffff
        ? ticket.seed - 1
        : ticket.seed + 1
      : ticket.seed;
  const payload = {
    replayVersion: 1,
    runSessionId: ticket.runSessionId,
    ...(ticket.boardId ? { boardId: ticket.boardId } : {}),
    ...(ticket.boardKey ? { boardKey: ticket.boardKey } : {}),
    tickHz: ticket.tickHz,
    seed,
    levelId: ticket.levelId,
    playerCharacterId: ticket.playerCharacterId,
    loadoutSnapshot: ticket.loadoutSnapshot,
    commandEncodingVersion: 1,
    totalTicks: 1,
    commandStream: [],
  };
  const canonicalSha256 = createHash("sha256")
    .update(canonicalJson(payload))
    .digest("hex");
  const bytes = gzipSync(
    Buffer.from(JSON.stringify({ ...payload, canonicalSha256 }), "utf8"),
  );
  return { canonicalSha256, bytes };
}

async function submitReplay(ticket, replay) {
  const grantResult = await callable("runSessionCreateUploadGrant", {
    userId: auth.localId,
    sessionId,
    runSessionId: ticket.runSessionId,
  });
  const grant = grantResult.uploadGrant;
  assert(isObject(grant), "Upload grant was malformed.");
  assert(
    grant.objectPath ===
      `replay-submissions/pending/${auth.localId}/${ticket.runSessionId}/replay.bin.gz`,
    "Upload grant object scope was not canonical.",
  );
  assert(
    grant.maxBytes >= replay.bytes.length,
    "Replay exceeded the signed upload limit.",
  );
  assert(
    grant.expiresAtMs > Date.now() &&
      grant.expiresAtMs <= Date.now() + 16 * 60 * 1000,
    "Signed upload TTL was outside the expected 15-minute window.",
  );

  const upload = await fetch(grant.uploadUrl, {
    method: "PUT",
    headers: {
      "content-type": grant.contentType,
      "content-length": replay.bytes.length.toString(),
    },
    body: replay.bytes,
  });
  if (!upload.ok) {
    throw new Error(
      `Replay upload failed (${upload.status}): ${(await upload.text()).slice(0, 300)}`,
    );
  }

  const finalized = await callable("runSessionFinalizeUpload", {
    userId: auth.localId,
    sessionId,
    runSessionId: ticket.runSessionId,
    canonicalSha256: replay.canonicalSha256,
    contentLengthBytes: replay.bytes.length,
    contentType: grant.contentType,
    objectPath: grant.objectPath,
    provisionalSummary: { goldEarned: 0 },
  });
  return finalized.submissionStatus;
}

async function waitForTerminal(runSessionId) {
  let lastState = "<none>";
  for (let attempt = 0; attempt < 30; attempt += 1) {
    const result = await callable("runSessionLoadStatus", {
      userId: auth.localId,
      sessionId,
      runSessionId,
    });
    const status = result.submissionStatus;
    assert(isObject(status), "Submission status was malformed.");
    lastState = status.state;
    if (
      ["validated", "rejected", "expired", "cancelled", "internal_error"].includes(
        status.state,
      )
    ) {
      return status;
    }
    await delay(1500);
  }
  throw new Error(
    `Run ${shortHash(runSessionId)} did not become terminal; last state ${lastState}.`,
  );
}

async function waitForProjection({ boardId, runSessionId }) {
  for (let attempt = 0; attempt < 30; attempt += 1) {
    const result = await callable("leaderboardLoadMyRank", {
      userId: auth.localId,
      sessionId,
      boardId,
    });
    if (result.myRank?.myEntry?.runSessionId === runSessionId) {
      return result.myRank;
    }
    await delay(1500);
  }
  throw new Error(
    `Run ${shortHash(runSessionId)} did not reach the leaderboard projection.`,
  );
}

async function waitForGhost({ boardId, entryId }) {
  for (let attempt = 0; attempt < 30; attempt += 1) {
    try {
      const result = await callable("ghostLoadManifest", {
        userId: auth.localId,
        sessionId,
        boardId,
        entryId,
      });
      if (isObject(result.ghostManifest)) {
        return result.ghostManifest;
      }
    } catch (error) {
      if (!(error instanceof CallableError) || error.status !== "NOT_FOUND") {
        throw error;
      }
    }
    await delay(1500);
  }
  throw new Error(
    `Run ${shortHash(entryId)} did not reach the ghost projection.`,
  );
}

async function requestDeletion() {
  const response = await callable("accountDelete", {
    userId: auth.localId,
    sessionId,
  });
  assert(isObject(response.result), "Account deletion response was malformed.");
  assert(
    ["requested", "in_progress", "retryable", "deleted"].includes(
      response.result.status,
    ),
    `Unexpected account deletion status: ${response.result.status}`,
  );
  return response.result;
}

async function saveState() {
  await mkdir(dirname(statePath), { recursive: true });
  await writeFile(statePath, `${JSON.stringify(state, null, 2)}\n`, {
    encoding: "utf8",
    mode: 0o600,
  });
}

async function waitForCleanupSignal() {
  const deadlineMs = Date.now() + cleanupWaitMs;
  while (Date.now() < deadlineMs) {
    try {
      await access(cleanupSignalPath);
      state = {
        ...state,
        phase: "cleanup_signal_received",
        cleanupSignalReceivedAt: new Date().toISOString(),
      };
      await saveState();
      return;
    } catch {
      await delay(1000);
    }
  }
  throw new Error("Timed out waiting for the cleanup signal.");
}

async function readJson(response) {
  const text = await response.text();
  if (!text) {
    return {};
  }
  try {
    return JSON.parse(text);
  } catch {
    return { unparsedBody: text.slice(0, 500) };
  }
}

function canonicalJson(value) {
  if (Array.isArray(value)) {
    return `[${value.map(canonicalJson).join(",")}]`;
  }
  if (isObject(value)) {
    return `{${Object.keys(value)
      .sort()
      .map((key) => `${JSON.stringify(key)}:${canonicalJson(value[key])}`)
      .join(",")}}`;
  }
  return JSON.stringify(value);
}

function parseArgs(values) {
  const parsed = new Map();
  for (let index = 0; index < values.length; index += 1) {
    const current = values[index];
    if (!current.startsWith("--")) {
      throw new Error(`Unexpected argument: ${current}`);
    }
    const name = current.slice(2);
    const value = values[index + 1];
    if (!value || value.startsWith("--")) {
      throw new Error(`Missing value for --${name}`);
    }
    parsed.set(name, value);
    index += 1;
  }
  return parsed;
}

function requireArg(parsed, name) {
  const value = parsed.get(name)?.trim();
  if (!value) {
    throw new Error(`--${name} is required.`);
  }
  return value;
}

function optionalResolvedPath(value) {
  const trimmed = value?.trim();
  return trimmed ? resolve(trimmed) : null;
}

function parsePositiveInteger(value) {
  if (value === undefined) {
    return 0;
  }
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed <= 0) {
    throw new Error(`Expected a positive integer, got "${value}".`);
  }
  return parsed;
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function shortHash(value) {
  return createHash("sha256").update(value).digest("hex").slice(0, 16);
}

function delay(milliseconds) {
  return new Promise((resolveDelay) => setTimeout(resolveDelay, milliseconds));
}

function safeBody(body) {
  return JSON.stringify(body).slice(0, 500);
}

function safeErrorMessage(error) {
  return (error instanceof Error ? error.message : String(error)).slice(0, 700);
}
