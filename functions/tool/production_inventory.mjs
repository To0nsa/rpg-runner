#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";

import { assessCompatibilityRetirement } from "../lib/runs/compatibility_retirement.js";

const args = parseArgs(process.argv.slice(2));
const projectId = requireArg(args, "project");
const nowMs = parsePositiveInteger(args.get("now-ms")) ?? Date.now();
const retirementArgs = parseRetirementArgs(args);
const accessToken = readAccessToken();
const firestoreRoot =
  `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(projectId)}` +
  "/databases/(default)/documents";

const [
  collectionIds,
  idempotencyDocs,
  playerBestDocs,
  ghostManifestDocs,
  viewDocs,
] = await Promise.all([
  listRootCollectionIds(),
  queryCollection("idempotency", true),
  queryCollection("player_bests", true),
  queryCollection("ghost_manifests", true),
  queryCollection("views", true),
]);

const rootEntries = await Promise.all(
  collectionIds.map(async (collectionId) => [
    collectionId,
    await queryCollection(collectionId, false),
  ]),
);
const roots = Object.fromEntries(rootEntries);

const profiles = roots.player_profiles ?? [];
const displayNameIndex = roots.display_name_index ?? [];
const ownershipProfiles = roots.ownership_profiles ?? [];
const boards = roots.leaderboard_boards ?? [];
const runSessions = roots.run_sessions ?? [];
const validatedRuns = roots.validated_runs ?? [];
const rewardGrants = roots.reward_grants ?? [];
const deletionRequests = roots.account_deletion_requests ?? [];
const abuseQuota = roots.abuse_quota ?? [];
const maintenance = roots.system_maintenance ?? [];

const ownershipByUid = new Map(
  ownershipProfiles
    .map((doc) => [asString(doc.data.uid), doc])
    .filter(([uid]) => uid !== null),
);
const runsById = new Map(runSessions.map((doc) => [doc.id, doc]));
const validatedById = new Map(validatedRuns.map((doc) => [doc.id, doc]));
const grantsById = new Map(rewardGrants.map((doc) => [doc.id, doc]));
const boardsById = new Map(boards.map((doc) => [doc.id, doc]));

const report = {
  schemaVersion: 1,
  projectId,
  observedAt: new Date(nowMs).toISOString(),
  readOnly: true,
  rootCollectionCounts: Object.fromEntries(
    collectionIds.map((collectionId) => [
      collectionId,
      roots[collectionId]?.length ?? 0,
    ]),
  ),
  profileConsistency: inventoryProfiles(profiles, displayNameIndex, nowMs),
  ownership: await inventoryOwnership(
    ownershipProfiles,
    rewardGrants,
    idempotencyDocs,
    nowMs,
  ),
  boards: await inventoryBoards(boards, nowMs),
  runs: await inventoryRuns(
    runSessions,
    validatedRuns,
    rewardGrants,
    ownershipByUid,
    boardsById,
    nowMs,
  ),
  projections: inventoryProjections({
    playerBestDocs,
    ghostManifestDocs,
    viewDocs,
    runsById,
    validatedById,
    boardsById,
  }),
  deletion: inventoryDeletion(deletionRequests, nowMs),
  abuseQuota: inventoryExpiry(abuseQuota, nowMs),
  maintenance: inventoryMaintenance(maintenance),
};
if (retirementArgs != null) {
  report.compatibilityRetirement = inventoryCompatibilityRetirement({
    runSessions,
    observedAtMs: nowMs,
    ...retirementArgs,
  });
}

console.log(JSON.stringify(report, null, 2));

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

function parsePositiveInteger(value) {
  if (value === undefined) {
    return null;
  }
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed <= 0) {
    throw new Error(`Expected a positive safe integer, got "${value}".`);
  }
  return parsed;
}

function parseRetirementArgs(parsed) {
  const gameCompatVersion = parsed.get("retiring-game-compat")?.trim();
  const issuanceCutoffAt = parsed.get("issuance-cutoff-at")?.trim();
  if (!gameCompatVersion && !issuanceCutoffAt) {
    return null;
  }
  if (!gameCompatVersion || !issuanceCutoffAt) {
    throw new Error(
      "--retiring-game-compat and --issuance-cutoff-at must be supplied together.",
    );
  }
  const issuanceCutoffAtMs = Date.parse(issuanceCutoffAt);
  if (!Number.isSafeInteger(issuanceCutoffAtMs) || issuanceCutoffAtMs <= 0) {
    throw new Error(
      `--issuance-cutoff-at must be a valid positive timestamp, got "${issuanceCutoffAt}".`,
    );
  }
  return { gameCompatVersion, issuanceCutoffAtMs };
}

function readAccessToken() {
  const supplied = process.env.GCLOUD_ACCESS_TOKEN?.trim();
  if (supplied) {
    return supplied;
  }
  const executable =
    process.platform === "win32" ? "powershell.exe" : "gcloud";
  const tokenArgs =
    process.platform === "win32"
      ? ["-NoProfile", "-Command", "gcloud auth print-access-token"]
      : ["auth", "print-access-token"];
  return execFileSync(executable, tokenArgs, {
    encoding: "utf8",
    windowsHide: true,
  }).trim();
}

async function firestoreRequest(path, body) {
  const response = await fetch(`${firestoreRoot}${path}`, {
    method: "POST",
    headers: {
      authorization: `Bearer ${accessToken}`,
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    throw new Error(
      `Firestore request failed (${response.status}): ${await response.text()}`,
    );
  }
  return response.json();
}

async function listRootCollectionIds() {
  const collectionIds = [];
  let pageToken;
  do {
    const response = await firestoreRequest(":listCollectionIds", {
      pageSize: 100,
      ...(pageToken ? { pageToken } : {}),
    });
    collectionIds.push(...(response.collectionIds ?? []));
    pageToken = response.nextPageToken;
  } while (pageToken);
  return [...new Set(collectionIds)].sort();
}

async function queryCollection(collectionId, allDescendants) {
  const rows = await firestoreRequest(":runQuery", {
    structuredQuery: {
      from: [{ collectionId, allDescendants }],
      orderBy: [
        {
          field: { fieldPath: "__name__" },
          direction: "ASCENDING",
        },
      ],
    },
  });
  return rows
    .filter((row) => row.document)
    .map((row) => decodeDocument(row.document));
}

function decodeDocument(document) {
  const segments = document.name.split("/");
  return {
    name: document.name,
    id: decodeURIComponent(segments.at(-1)),
    data: decodeFields(document.fields ?? {}),
    createTime: document.createTime ?? null,
    updateTime: document.updateTime ?? null,
  };
}

function decodeFields(fields) {
  return Object.fromEntries(
    Object.entries(fields).map(([key, value]) => [key, decodeValue(value)]),
  );
}

function decodeValue(value) {
  if ("nullValue" in value) return null;
  if ("booleanValue" in value) return value.booleanValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return Number(value.doubleValue);
  if ("timestampValue" in value) return value.timestampValue;
  if ("stringValue" in value) return value.stringValue;
  if ("bytesValue" in value) return "<bytes>";
  if ("referenceValue" in value) return value.referenceValue;
  if ("geoPointValue" in value) return value.geoPointValue;
  if ("arrayValue" in value) {
    return (value.arrayValue.values ?? []).map(decodeValue);
  }
  if ("mapValue" in value) {
    return decodeFields(value.mapValue.fields ?? {});
  }
  return null;
}

function inventoryProfiles(profiles, indexes, observedAtMs) {
  const profileByUid = new Map(profiles.map((doc) => [doc.id, doc]));
  const indexByNormalized = new Map(indexes.map((doc) => [doc.id, doc]));
  let namedProfiles = 0;
  let unnamedProfiles = 0;
  let profileUidMismatchCount = 0;
  let missingClaimCount = 0;
  let conflictingClaimCount = 0;
  let profileMetadataMismatchCount = 0;
  let futureRenameTimestampCount = 0;
  let invalidRenameTimestampCount = 0;

  for (const profile of profiles) {
    if (asString(profile.data.uid) !== profile.id) {
      profileUidMismatchCount += 1;
    }
    const displayName = asString(profile.data.displayName);
    const lastChangedAtMs = profile.data.displayNameLastChangedAtMs;
    if (
      !Number.isSafeInteger(lastChangedAtMs) ||
      lastChangedAtMs < 0
    ) {
      invalidRenameTimestampCount += 1;
    } else if (lastChangedAtMs > observedAtMs) {
      futureRenameTimestampCount += 1;
    }
    if (!displayName) {
      unnamedProfiles += 1;
      continue;
    }
    namedProfiles += 1;
    const normalized = normalizeDisplayName(displayName);
    if (profile.data.displayNameNormalized !== normalized) {
      profileMetadataMismatchCount += 1;
    }
    const claim = indexByNormalized.get(normalized);
    if (!claim) {
      missingClaimCount += 1;
    } else if (asString(claim.data.uid) !== profile.id) {
      conflictingClaimCount += 1;
    }
  }

  let orphanClaimCount = 0;
  let indexMetadataMismatchCount = 0;
  for (const index of indexes) {
    const uid = asString(index.data.uid);
    const profile = uid ? profileByUid.get(uid) : null;
    const displayName = profile ? asString(profile.data.displayName) : null;
    if (!profile || !displayName || normalizeDisplayName(displayName) !== index.id) {
      orphanClaimCount += 1;
      continue;
    }
    if (
      index.data.displayName !== displayName ||
      index.data.displayNameNormalized !== index.id
    ) {
      indexMetadataMismatchCount += 1;
    }
  }

  return {
    profileCount: profiles.length,
    indexCount: indexes.length,
    namedProfiles,
    unnamedProfiles,
    profileUidMismatchCount,
    missingClaimCount,
    conflictingClaimCount,
    orphanClaimCount,
    profileMetadataMismatchCount,
    indexMetadataMismatchCount,
    futureRenameTimestampCount,
    invalidRenameTimestampCount,
  };
}

async function inventoryOwnership(
  ownershipProfiles,
  rewardGrants,
  idempotencyDocs,
  observedAtMs,
) {
  const { normalizeAuthorizedSelection } = await import(
    new URL("../lib/ownership/loadout_authorization.js", import.meta.url)
  );
  let uidMismatchCount = 0;
  let invalidRevisionCount = 0;
  let unauthorizedSelectionCount = 0;
  let invalidGoldCount = 0;
  let legacyAwardedRunOwnerCount = 0;
  let legacyAwardedRunIdCount = 0;
  let duplicateLegacyAwardedRunIdCount = 0;
  let invalidLegacyAwardedRunIdCount = 0;
  let totalCanonicalGold = 0;

  for (const ownership of ownershipProfiles) {
    if (!asString(ownership.data.uid)) {
      uidMismatchCount += 1;
    }
    if (
      !Number.isSafeInteger(ownership.data.revision) ||
      ownership.data.revision < 0
    ) {
      invalidRevisionCount += 1;
    }
    if (
      normalizeAuthorizedSelection({
        selection: ownership.data.selection,
        meta: ownership.data.meta,
      }) === null
    ) {
      unauthorizedSelectionCount += 1;
    }
    const gold = ownership.data.progression?.gold;
    if (!Number.isSafeInteger(gold) || gold < 0) {
      invalidGoldCount += 1;
    } else {
      totalCanonicalGold += gold;
    }
    const awardedRunIds = ownership.data.progression?.awardedRunIds;
    if (!Array.isArray(awardedRunIds) || awardedRunIds.length === 0) {
      continue;
    }
    legacyAwardedRunOwnerCount += 1;
    legacyAwardedRunIdCount += awardedRunIds.length;
    const seen = new Set();
    for (const runId of awardedRunIds) {
      if (!Number.isSafeInteger(runId) || runId < 0) {
        invalidLegacyAwardedRunIdCount += 1;
        continue;
      }
      if (seen.has(runId)) {
        duplicateLegacyAwardedRunIdCount += 1;
      }
      seen.add(runId);
    }
  }

  const settledGrants = rewardGrants.filter(
    (doc) => doc.data.lifecycleState === "validated_settled",
  );
  return {
    profileCount: ownershipProfiles.length,
    uidMissingCount: uidMismatchCount,
    invalidRevisionCount,
    unauthorizedSelectionCount,
    invalidGoldCount,
    totalCanonicalGold,
    legacyAwardedRunOwnerCount,
    legacyAwardedRunIdCount,
    duplicateLegacyAwardedRunIdCount,
    invalidLegacyAwardedRunIdCount,
    settledGrantCount: settledGrants.length,
    settledGrantGoldTotal: sum(
      settledGrants.map((doc) => nonNegativeInteger(doc.data.goldAmount)),
    ),
    idempotency: {
      documentCount: idempotencyDocs.length,
      compactOutcomeCount: idempotencyDocs.filter(
        (doc) => isObject(doc.data.outcome),
      ).length,
      legacyFullResultCount: idempotencyDocs.filter(
        (doc) => isObject(doc.data.result),
      ).length,
      missingExpiryCount: idempotencyDocs.filter(
        (doc) => !Number.isSafeInteger(doc.data.expiresAtMs),
      ).length,
      expiredCount: idempotencyDocs.filter(
        (doc) =>
          Number.isSafeInteger(doc.data.expiresAtMs) &&
          doc.data.expiresAtMs <= observedAtMs,
      ).length,
    },
  };
}

async function inventoryBoards(boards, observedAtMs) {
  const {
    competitiveWindowBoundsFromId,
    resolveWindowForMode,
    weeklyWindowBoundsFromId,
  } = await import(new URL("../lib/boards/windowing.js", import.meta.url));
  const { buildManagedBoardId, resolveBoardProvisioningConfig } = await import(
    new URL("../lib/boards/provisioning.js", import.meta.url)
  );
  let malformedCount = 0;
  let idMismatchCount = 0;
  let legacyIdCount = 0;
  let keyMismatchCount = 0;
  let windowMismatchCount = 0;
  let activeNowCount = 0;
  let upcomingCount = 0;
  let expiredCount = 0;
  const gameCompatVersionCounts = countBy(
    boards,
    (board) => asString(board.data.gameCompatVersion) ?? "<missing>",
  );
  const rulesetVersionCounts = countBy(
    boards,
    (board) =>
      (isObject(board.data.boardKey) &&
        asString(board.data.boardKey.rulesetVersion)) ||
      "<missing>",
  );
  const statusCounts = countBy(
    boards,
    (board) => asString(board.data.status) ?? "<missing>",
  );
  const statusCountsByGameCompatVersion = {};
  for (const board of boards) {
    const gameCompatVersion =
      asString(board.data.gameCompatVersion) ?? "<missing>";
    const status = asString(board.data.status) ?? "<missing>";
    const counts = statusCountsByGameCompatVersion[gameCompatVersion] ?? {};
    counts[status] = (counts[status] ?? 0) + 1;
    statusCountsByGameCompatVersion[gameCompatVersion] = counts;
  }
  const activeNowGameCompatVersionCounts = {};
  const activeNowRulesetVersionCounts = {};

  for (const board of boards) {
    const mode = asString(board.data.mode);
    const levelId = asString(board.data.levelId);
    const windowId = asString(board.data.windowId);
    const opensAtMs = board.data.opensAtMs;
    const closesAtMs = board.data.closesAtMs;
    const key = board.data.boardKey;
    const rulesetVersion = isObject(key) ? asString(key.rulesetVersion) : null;
    const scoreVersion = isObject(key) ? asString(key.scoreVersion) : null;
    const gameCompatVersion = asString(board.data.gameCompatVersion);
    const ghostVersion = asString(board.data.ghostVersion);
    if (
      !["competitive", "weekly"].includes(mode) ||
      !levelId ||
      !windowId ||
      !rulesetVersion ||
      !scoreVersion ||
      !gameCompatVersion ||
      !ghostVersion ||
      !Number.isSafeInteger(opensAtMs) ||
      !Number.isSafeInteger(closesAtMs) ||
      closesAtMs <= opensAtMs
    ) {
      malformedCount += 1;
      continue;
    }
    const expectedId = buildManagedBoardId({
      mode,
      levelId,
      windowId,
      rulesetVersion,
      scoreVersion,
      gameCompatVersion,
      ghostVersion,
    });
    const legacyId = buildLegacyManagedBoardId({ mode, levelId, windowId });
    if (board.id === legacyId && board.data.boardId === legacyId) {
      legacyIdCount += 1;
    } else if (board.id !== expectedId || board.data.boardId !== expectedId) {
      idMismatchCount += 1;
    }
    if (
      !isObject(key) ||
      key.mode !== mode ||
      key.levelId !== levelId ||
      key.windowId !== windowId
    ) {
      keyMismatchCount += 1;
    }
    try {
      const expectedWindow =
        mode === "competitive"
          ? competitiveWindowBoundsFromId(windowId)
          : weeklyWindowBoundsFromId(windowId);
      if (
        opensAtMs !== expectedWindow.opensAtMs ||
        closesAtMs !== expectedWindow.closesAtMs
      ) {
        windowMismatchCount += 1;
      }
    } catch {
      windowMismatchCount += 1;
    }
    if (observedAtMs < opensAtMs) {
      upcomingCount += 1;
    } else if (observedAtMs >= closesAtMs) {
      expiredCount += 1;
    } else {
      activeNowCount += 1;
      activeNowGameCompatVersionCounts[gameCompatVersion] =
        (activeNowGameCompatVersionCounts[gameCompatVersion] ?? 0) + 1;
      activeNowRulesetVersionCounts[rulesetVersion] =
        (activeNowRulesetVersionCounts[rulesetVersion] ?? 0) + 1;
    }
  }

  const provisioningConfig = resolveBoardProvisioningConfig();
  const expectedIds = new Set();
  for (const mode of ["competitive", "weekly"]) {
    const levels = mode === "competitive" ? ["field", "forest"] : ["field"];
    const current = resolveWindowForMode(mode, observedAtMs);
    const next = resolveWindowForMode(mode, current.closesAtMs + 1);
    for (const levelId of levels) {
      for (const window of [current, next]) {
        expectedIds.add(
          buildManagedBoardId({
            mode,
            levelId,
            windowId: window.windowId,
            rulesetVersion: provisioningConfig.rulesetVersion,
            scoreVersion: provisioningConfig.scoreVersion,
            gameCompatVersion: provisioningConfig.gameCompatVersion,
            ghostVersion: provisioningConfig.ghostVersion,
          }),
        );
      }
    }
  }
  const actualIds = new Set(boards.map((doc) => doc.id));

  return {
    boardCount: boards.length,
    malformedCount,
    idMismatchCount,
    legacyIdCount,
    keyMismatchCount,
    windowMismatchCount,
    activeNowCount,
    upcomingCount,
    expiredCount,
    gameCompatVersionCounts: sortRecord(gameCompatVersionCounts),
    rulesetVersionCounts: sortRecord(rulesetVersionCounts),
    statusCounts,
    statusCountsByGameCompatVersion: Object.fromEntries(
      Object.entries(statusCountsByGameCompatVersion)
        .sort(([left], [right]) => left.localeCompare(right))
        .map(([gameCompatVersion, counts]) => [
          gameCompatVersion,
          sortRecord(counts),
        ]),
    ),
    activeNowGameCompatVersionCounts: sortRecord(
      activeNowGameCompatVersionCounts,
    ),
    activeNowRulesetVersionCounts: sortRecord(activeNowRulesetVersionCounts),
    expectedCurrentAndNextCount: expectedIds.size,
    missingExpectedCurrentOrNextCount: [...expectedIds].filter(
      (id) => !actualIds.has(id),
    ).length,
  };
}

function buildLegacyManagedBoardId({ mode, levelId, windowId }) {
  const sanitize = (value) => {
    const token = value.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "");
    return token.length === 0 ? "unknown" : token;
  };
  return `board_${mode}_${sanitize(windowId)}_${sanitize(levelId)}`;
}

async function inventoryRuns(
  runSessions,
  validatedRuns,
  rewardGrants,
  ownershipByUid,
  boardsById,
  observedAtMs,
) {
  const { normalizeAuthorizedLoadout } = await import(
    new URL("../lib/ownership/loadout_authorization.js", import.meta.url)
  );
  const validatedById = new Map(validatedRuns.map((doc) => [doc.id, doc]));
  const runById = new Map(runSessions.map((doc) => [doc.id, doc]));
  const grantById = new Map(rewardGrants.map((doc) => [doc.id, doc]));
  const stateCounts = countBy(runSessions, (doc) => asString(doc.data.state) ?? "<missing>");
  const gameCompatVersionCounts = countBy(
    runSessions,
    (doc) =>
      (isObject(doc.data.runTicket) &&
        asString(doc.data.runTicket.gameCompatVersion)) ||
      "<missing>",
  );
  const rulesetVersionCounts = countBy(
    runSessions,
    (doc) =>
      (isObject(doc.data.runTicket) &&
        asString(doc.data.runTicket.rulesetVersion)) ||
      "<boardless>",
  );
  const activeStates = new Set([
    "issued",
    "uploading",
    "uploaded",
    "pending_validation",
    "validating",
    "settlement_pending",
  ]);
  const activeSessions = runSessions.filter((doc) =>
    activeStates.has(asString(doc.data.state)),
  );
  const activeGameCompatVersionCounts = countBy(
    activeSessions,
    (doc) =>
      (isObject(doc.data.runTicket) &&
        asString(doc.data.runTicket.gameCompatVersion)) ||
      "<missing>",
  );
  const activeRulesetVersionCounts = countBy(
    activeSessions,
    (doc) =>
      (isObject(doc.data.runTicket) &&
        asString(doc.data.runTicket.rulesetVersion)) ||
      "<boardless>",
  );
  const activeExpiryByGameCompatVersion = {};
  for (const session of activeSessions) {
    const ticket = session.data.runTicket;
    const gameCompatVersion =
      (isObject(ticket) && asString(ticket.gameCompatVersion)) || "<missing>";
    const summary = activeExpiryByGameCompatVersion[gameCompatVersion] ?? {
      sessionCount: 0,
      validExpiryCount: 0,
      minExpiryAtMs: null,
      maxExpiryAtMs: null,
    };
    summary.sessionCount += 1;
    if (Number.isSafeInteger(session.data.expiresAtMs)) {
      summary.validExpiryCount += 1;
      summary.minExpiryAtMs =
        summary.minExpiryAtMs == null
          ? session.data.expiresAtMs
          : Math.min(summary.minExpiryAtMs, session.data.expiresAtMs);
      summary.maxExpiryAtMs =
        summary.maxExpiryAtMs == null
          ? session.data.expiresAtMs
          : Math.max(summary.maxExpiryAtMs, session.data.expiresAtMs);
    }
    activeExpiryByGameCompatVersion[gameCompatVersion] = summary;
  }
  const grantStateCounts = countBy(
    rewardGrants,
    (doc) => asString(doc.data.lifecycleState) ?? "<missing>",
  );
  let identityMismatchCount = 0;
  let invalidTicketTimeCount = 0;
  let futureTicketCount = 0;
  let missingBoardWindowEvidenceCount = 0;
  const missingBoardWindowEvidenceStateCounts = {};
  let missingBoardWindowCanonicalMatchCount = 0;
  let missingBoardWindowCanonicalMismatchCount = 0;
  const missingBoardWindowIssuedAtMs = [];
  let boardWindowIssuanceMismatchCount = 0;
  let expirablePastExpiryCount = 0;
  let unauthorizedTicketLoadoutCount = 0;
  let ticketLoadoutNotAssessableCount = 0;
  let terminalEvidenceMismatchCount = 0;
  const expirableStates = new Set(["issued", "uploading", "uploaded"]);

  for (const session of runSessions) {
    const ticket = session.data.runTicket;
    const uid = asString(session.data.uid);
    const state = asString(session.data.state) ?? "<missing>";
    if (
      expirableStates.has(state) &&
      Number.isSafeInteger(session.data.expiresAtMs) &&
      session.data.expiresAtMs <= observedAtMs
    ) {
      expirablePastExpiryCount += 1;
    }
    if (
      !isObject(ticket) ||
      session.data.runSessionId !== session.id ||
      ticket.runSessionId !== session.id ||
      ticket.uid !== uid
    ) {
      identityMismatchCount += 1;
      continue;
    }
    const issuedAtMs = ticket.issuedAtMs;
    const expiresAtMs = ticket.expiresAtMs;
    if (
      !Number.isSafeInteger(issuedAtMs) ||
      !Number.isSafeInteger(expiresAtMs) ||
      expiresAtMs - issuedAtMs !== 24 * 60 * 60 * 1000
    ) {
      invalidTicketTimeCount += 1;
    }
    if (Number.isSafeInteger(issuedAtMs) && issuedAtMs > observedAtMs + 5 * 60 * 1000) {
      futureTicketCount += 1;
    }
    if (ticket.mode !== "practice" && Number.isSafeInteger(issuedAtMs)) {
      if (
        !Number.isSafeInteger(ticket.boardOpensAtMs) ||
        !Number.isSafeInteger(ticket.boardClosesAtMs)
      ) {
        missingBoardWindowEvidenceCount += 1;
        missingBoardWindowEvidenceStateCounts[state] =
          (missingBoardWindowEvidenceStateCounts[state] ?? 0) + 1;
        missingBoardWindowIssuedAtMs.push(issuedAtMs);
        const boardId = asString(ticket.boardId);
        const canonicalBoard = boardId ? boardsById.get(boardId) : null;
        if (
          canonicalBoard &&
          Number.isSafeInteger(canonicalBoard.data.opensAtMs) &&
          Number.isSafeInteger(canonicalBoard.data.closesAtMs) &&
          issuedAtMs >= canonicalBoard.data.opensAtMs &&
          issuedAtMs < canonicalBoard.data.closesAtMs
        ) {
          missingBoardWindowCanonicalMatchCount += 1;
        } else {
          missingBoardWindowCanonicalMismatchCount += 1;
        }
      } else if (
        issuedAtMs < ticket.boardOpensAtMs ||
        issuedAtMs >= ticket.boardClosesAtMs
      ) {
        boardWindowIssuanceMismatchCount += 1;
      }
    }
    const ownership = uid ? ownershipByUid.get(uid) : null;
    if (!ownership) {
      ticketLoadoutNotAssessableCount += 1;
    } else if (
      normalizeAuthorizedLoadout({
        loadout: ticket.loadoutSnapshot,
        meta: ownership.data.meta,
        characterId: ticket.playerCharacterId,
      }) === null
    ) {
      unauthorizedTicketLoadoutCount += 1;
    }
    const validated = validatedById.get(session.id);
    const grant = grantById.get(session.id);
    if (
      (state === "validated" &&
        (!validated || validated.data.accepted !== true ||
          grant?.data.lifecycleState !== "validated_settled")) ||
      (state === "rejected" &&
        (!validated || validated.data.accepted !== false))
    ) {
      terminalEvidenceMismatchCount += 1;
    }
  }

  let validatedIdentityMismatchCount = 0;
  let acceptedWithoutSessionCount = 0;
  let acceptedWithRejectionReasonCount = 0;
  let rejectedWithoutReasonCount = 0;
  for (const validated of validatedRuns) {
    const session = runById.get(validated.id);
    if (
      validated.data.runSessionId !== validated.id ||
      (session && validated.data.uid !== session.data.uid)
    ) {
      validatedIdentityMismatchCount += 1;
    }
    if (validated.data.accepted === true && !session) {
      acceptedWithoutSessionCount += 1;
    }
    if (
      validated.data.accepted === true &&
      asString(validated.data.rejectionReason)
    ) {
      acceptedWithRejectionReasonCount += 1;
    }
    if (
      validated.data.accepted === false &&
      !asString(validated.data.rejectionReason)
    ) {
      rejectedWithoutReasonCount += 1;
    }
  }

  let grantWithoutSessionCount = 0;
  let grantUidMismatchCount = 0;
  let staleSettlementPendingCount = 0;
  let quarantinedSettlementCount = 0;
  for (const grant of rewardGrants) {
    const session = runById.get(grant.id);
    if (!session) {
      grantWithoutSessionCount += 1;
    } else if (grant.data.uid !== session.data.uid) {
      grantUidMismatchCount += 1;
    }
    if (
      grant.data.lifecycleState === "settlement_pending" &&
      Number.isSafeInteger(grant.data.updatedAtMs) &&
      observedAtMs - grant.data.updatedAtMs > 15 * 60 * 1000
    ) {
      staleSettlementPendingCount += 1;
    }
  }
  for (const session of runSessions) {
    if (session.data.settlementRepairDisposition === "quarantined") {
      quarantinedSettlementCount += 1;
    }
  }

  return {
    sessionCount: runSessions.length,
    sessionStateCounts: stateCounts,
    gameCompatVersionCounts: sortRecord(gameCompatVersionCounts),
    rulesetVersionCounts: sortRecord(rulesetVersionCounts),
    activeGameCompatVersionCounts: sortRecord(
      activeGameCompatVersionCounts,
    ),
    activeRulesetVersionCounts: sortRecord(activeRulesetVersionCounts),
    activeExpiryByGameCompatVersion: Object.fromEntries(
      Object.entries(activeExpiryByGameCompatVersion)
        .sort(([left], [right]) => left.localeCompare(right))
        .map(([gameCompatVersion, summary]) => [
          gameCompatVersion,
          {
            sessionCount: summary.sessionCount,
            validExpiryCount: summary.validExpiryCount,
            minExpiryAt:
              summary.minExpiryAtMs == null
                ? null
                : new Date(summary.minExpiryAtMs).toISOString(),
            maxExpiryAt:
              summary.maxExpiryAtMs == null
                ? null
                : new Date(summary.maxExpiryAtMs).toISOString(),
          },
        ]),
    ),
    identityMismatchCount,
    invalidTicketTimeCount,
    futureTicketCount,
    missingBoardWindowEvidenceCount,
    missingBoardWindowEvidenceStateCounts: Object.fromEntries(
      Object.entries(missingBoardWindowEvidenceStateCounts).sort(
        ([left], [right]) => left.localeCompare(right),
      ),
    ),
    missingBoardWindowCanonicalMatchCount,
    missingBoardWindowCanonicalMismatchCount,
    missingBoardWindowIssuedAtRange:
      missingBoardWindowIssuedAtMs.length === 0
        ? null
        : {
            min: new Date(Math.min(...missingBoardWindowIssuedAtMs)).toISOString(),
            max: new Date(Math.max(...missingBoardWindowIssuedAtMs)).toISOString(),
          },
    boardWindowIssuanceMismatchCount,
    expirablePastExpiryCount,
    unauthorizedTicketLoadoutCount,
    ticketLoadoutNotAssessableCount,
    terminalEvidenceMismatchCount,
    validatedRunCount: validatedRuns.length,
    acceptedValidatedCount: validatedRuns.filter(
      (doc) => doc.data.accepted === true,
    ).length,
    rejectedValidatedCount: validatedRuns.filter(
      (doc) => doc.data.accepted === false,
    ).length,
    validatedIdentityMismatchCount,
    acceptedWithoutSessionCount,
    acceptedWithRejectionReasonCount,
    rejectedWithoutReasonCount,
    rewardGrantCount: rewardGrants.length,
    rewardGrantStateCounts: grantStateCounts,
    grantWithoutSessionCount,
    grantUidMismatchCount,
    staleSettlementPendingCount,
    quarantinedSettlementCount,
  };
}

function inventoryCompatibilityRetirement({
  runSessions,
  observedAtMs,
  gameCompatVersion,
  issuanceCutoffAtMs,
}) {
  const assessment = assessCompatibilityRetirement({
    sessions: runSessions.map((session) => {
      const ticket = session.data.runTicket;
      const issuedAtMs = isObject(ticket) ? ticket.issuedAtMs : null;
      return {
        gameCompatVersion: isObject(ticket)
          ? asString(ticket.gameCompatVersion)
          : null,
        state: asString(session.data.state),
        issuedAtMs: Number.isSafeInteger(issuedAtMs) ? issuedAtMs : null,
      };
    }),
    observedAtMs,
    gameCompatVersion,
    issuanceCutoffAtMs,
  });
  const {
    issuanceCutoffAtMs: assessedCutoffAtMs,
    earliestRemovalAtMs,
    observedLatestIssuedAtMs,
    ...publicAssessment
  } = assessment;
  return {
    ...publicAssessment,
    issuanceCutoffAt: new Date(assessedCutoffAtMs).toISOString(),
    earliestRemovalAt: new Date(earliestRemovalAtMs).toISOString(),
    observedLatestIssuedAt:
      observedLatestIssuedAtMs == null
        ? null
        : new Date(observedLatestIssuedAtMs).toISOString(),
  };
}

function inventoryProjections({
  playerBestDocs,
  ghostManifestDocs,
  viewDocs,
  runsById,
  validatedById,
  boardsById,
}) {
  let playerBestInvalidSourceCount = 0;
  for (const best of playerBestDocs) {
    const runSessionId = asString(best.data.runSessionId);
    const validated = runSessionId ? validatedById.get(runSessionId) : null;
    const boardId = parentDocumentId(best.name, "player_bests");
    if (
      !runSessionId ||
      !validated ||
      validated.data.accepted !== true ||
      validated.data.boardId !== boardId ||
      !boardsById.has(boardId)
    ) {
      playerBestInvalidSourceCount += 1;
    }
  }

  let ghostInvalidSourceCount = 0;
  for (const ghost of ghostManifestDocs) {
    const runSessionId =
      asString(ghost.data.runSessionId) ?? asString(ghost.data.entryId);
    const validated = runSessionId ? validatedById.get(runSessionId) : null;
    const boardId = parentDocumentId(ghost.name, "ghost_manifests");
    if (
      !runSessionId ||
      !validated ||
      validated.data.accepted !== true ||
      validated.data.boardId !== boardId ||
      !runsById.has(runSessionId) ||
      !boardsById.has(boardId)
    ) {
      ghostInvalidSourceCount += 1;
    }
  }

  return {
    playerBestCount: playerBestDocs.length,
    playerBestInvalidSourceCount,
    ghostManifestCount: ghostManifestDocs.length,
    ghostInvalidSourceCount,
    boardViewCount: viewDocs.length,
  };
}

function inventoryDeletion(deletionRequests, observedAtMs) {
  const stateCounts = countBy(
    deletionRequests,
    (doc) => asString(doc.data.state) ?? "<missing>",
  );
  const stageCounts = countBy(
    deletionRequests,
    (doc) =>
      doc.data.state === "complete"
        ? "complete"
        : asString(doc.data.stage) ?? "<missing>",
  );
  const active = deletionRequests.filter((doc) => doc.data.state !== "complete");
  const completed = deletionRequests.filter((doc) => doc.data.state === "complete");
  const completedDurationsMs = completed
    .map((doc) => {
      const requestedAtMs = doc.data.requestedAtMs;
      const completedAtMs = doc.data.completedAtMs;
      return Number.isSafeInteger(requestedAtMs) &&
        Number.isSafeInteger(completedAtMs) &&
        completedAtMs >= requestedAtMs
        ? completedAtMs - requestedAtMs
        : null;
    })
    .filter((durationMs) => durationMs !== null);
  return {
    requestCount: deletionRequests.length,
    stateCounts,
    stageCounts,
    requests: deletionRequests
      .map((doc) => ({
        uidHash: shortHash(doc.id),
        state: asString(doc.data.state) ?? "<missing>",
        stage:
          doc.data.state === "complete"
            ? "complete"
            : asString(doc.data.stage) ?? "<missing>",
        pass:
          doc.data.state !== "complete" && Number.isSafeInteger(doc.data.pass)
            ? doc.data.pass
            : null,
        finalPass:
          doc.data.state === "complete" ? null : doc.data.finalPass === true,
        attemptCount:
          doc.data.state !== "complete" &&
          Number.isSafeInteger(doc.data.attemptCount)
            ? doc.data.attemptCount
            : null,
      }))
      .sort((left, right) => left.uidHash.localeCompare(right.uidHash)),
    activeCount: active.length,
    retryableCount: deletionRequests.filter(
      (doc) => doc.data.state === "retryable",
    ).length,
    finalPassCount: active.filter(
      (doc) => doc.data.finalPass === true,
    ).length,
    activeOlderThan15MinutesCount: active.filter(
      (doc) =>
        Number.isSafeInteger(doc.data.requestedAtMs) &&
        observedAtMs - doc.data.requestedAtMs > 15 * 60 * 1000,
    ).length,
    completedMissingExpiryCount: completed.filter(
      (doc) => !Number.isSafeInteger(doc.data.expiresAtMs),
    ).length,
    compactedCompletionCount: completed.filter(
      (doc) =>
        Object.keys(doc.data).sort().join(",") ===
        "completedAtMs,expiresAtMs,requestedAtMs,state",
    ).length,
    nonMinimalCompletionCount: completed.filter(
      (doc) =>
        Object.keys(doc.data).sort().join(",") !==
        "completedAtMs,expiresAtMs,requestedAtMs,state",
    ).length,
    completedDurationMsRange:
      completedDurationsMs.length === 0
        ? null
        : {
            min: Math.min(...completedDurationsMs),
            max: Math.max(...completedDurationsMs),
          },
    expiredCompletionEvidenceCount: completed.filter(
      (doc) =>
        Number.isSafeInteger(doc.data.expiresAtMs) &&
        doc.data.expiresAtMs <= observedAtMs,
    ).length,
  };
}

function inventoryExpiry(documents, observedAtMs) {
  return {
    documentCount: documents.length,
    missingExpiryCount: documents.filter(
      (doc) => !Number.isSafeInteger(doc.data.expiresAtMs),
    ).length,
    expiredCount: documents.filter(
      (doc) =>
        Number.isSafeInteger(doc.data.expiresAtMs) &&
        doc.data.expiresAtMs <= observedAtMs,
    ).length,
  };
}

function inventoryMaintenance(documents) {
  return {
    documentCount: documents.length,
    documentIds: documents.map((doc) => doc.id).sort(),
  };
}

function countBy(values, keyOf) {
  const counts = {};
  for (const value of values) {
    const key = keyOf(value);
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return Object.fromEntries(
    Object.entries(counts).sort(([left], [right]) =>
      left.localeCompare(right),
    ),
  );
}

function sortRecord(record) {
  return Object.fromEntries(
    Object.entries(record).sort(([left], [right]) => left.localeCompare(right)),
  );
}

function normalizeDisplayName(value) {
  return value.trim().replace(/\s+/g, " ").toLowerCase();
}

function parentDocumentId(name, childCollection) {
  const segments = name.split("/");
  const childIndex = segments.lastIndexOf(childCollection);
  return childIndex > 0 ? decodeURIComponent(segments[childIndex - 1]) : "";
}

function asString(value) {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : null;
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function nonNegativeInteger(value) {
  return Number.isSafeInteger(value) && value >= 0 ? value : 0;
}

function sum(values) {
  return values.reduce((total, value) => total + value, 0);
}

function shortHash(value) {
  return createHash("sha256").update(value).digest("hex").slice(0, 16);
}
