import { createHash, randomUUID } from "node:crypto";

import { getAuth } from "firebase-admin/auth";
import {
  FieldPath,
  FieldValue,
  type DocumentReference,
  type Firestore,
} from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import * as logger from "firebase-functions/logger";

import { normalizeDisplayNameForPolicy } from "../profile/validators.js";
import {
  accountDeletionRequestRef,
  accountDeletionRequestsCollection,
} from "./deletion_guard.js";

const playerProfilesCollection = "player_profiles";
const displayNameIndexCollection = "display_name_index";
const ownershipProfilesCollection = "ownership_profiles";
const abuseQuotaCollection = "abuse_quota";
const runSessionsCollection = "run_sessions";
const validatedRunsCollection = "validated_runs";
const rewardGrantsCollection = "reward_grants";
const leaderboardBoardsCollection = "leaderboard_boards";
const playerBestsCollection = "player_bests";
const ghostManifestsCollection = "ghost_manifests";
const boardViewsCollection = "views";
const top10ViewDocId = "top10";
const maintenanceCollection = "system_maintenance";
const completedTombstoneInventoryDocument =
  "account_deletion_completed_tombstone_inventory";

const replaySubmissionPendingPathPrefix = "replay-submissions/pending";
const replayValidatedPathPrefix = "replay-submissions/validated";
const ghostArtifactPathPrefix = "ghosts";

const signedUploadQuietPeriodMs = 15 * 60 * 1000;
/**
 * Maximum lifetime of compact completion evidence: 30 days in milliseconds.
 *
 * The retained document contains only terminal status and request, completion,
 * and expiry times; gameplay data and workflow diagnostics are removed.
 */
export const accountDeletionCompletionRetentionMs = 30 * 24 * 60 * 60 * 1000;
const deletionLeaseMs = 5 * 60 * 1000;

/**
 * Ordered deletion stages used by the resumable worker and isolated fault
 * drills. Production callers must not skip or reorder this sequence.
 */
export const accountDeletionStages = [
  "disable_auth",
  "profile",
  "display_name_index",
  "ownership_idempotency",
  "ownership",
  "abuse_quota",
  "run_sessions",
  "validated_runs",
  "reward_grants",
  "ghost_runs_uid",
  "ghost_runs_user_id",
  "ghost_runs_owner_uid",
  "leaderboard_ghost_runs_uid",
  "leaderboard_ghost_runs_user_id",
  "leaderboard_ghost_runs_owner_uid",
  "weekly_ghost_runs_uid",
  "weekly_ghost_runs_user_id",
  "weekly_ghost_runs_owner_uid",
  "board_ghosts",
  "board_player_bests",
  "pending_replay_artifacts",
  "quiet_wait",
  "delete_auth",
] as const;

type AccountDeletionStage = (typeof accountDeletionStages)[number];
type AccountDeletionState =
  | "requested"
  | "in_progress"
  | "retryable"
  | "complete";

export interface ReplayArtifactStore {
  deletePageByPrefix(args: {
    prefix: string;
    maxResults: number;
  }): Promise<number>;
  deleteObjectIfExists(args: { objectPath: string }): Promise<boolean>;
}

export interface AccountDeletionAuth {
  disableAndRevoke(uid: string): Promise<void>;
  deleteUser(uid: string): Promise<void>;
}

export interface AccountDeletionDependencies {
  auth?: AccountDeletionAuth;
  replayArtifactStore?: ReplayArtifactStore;
  /**
   * Runs after a stage's side effects but before its checkpoint commits.
   * Production call sites omit this; isolated drills use it to prove replay.
   */
  afterStage?: (stage: AccountDeletionStage) => Promise<void>;
}

export interface AccountDeleteResult {
  status: "requested" | "in_progress" | "retryable" | "deleted";
  requestId: string;
}

export interface AccountDeletionProcessResult extends AccountDeleteResult {
  processed: boolean;
  stage: AccountDeletionStage | "complete";
}

export interface AccountDeletionRepairResult {
  scannedCount: number;
  processedCount: number;
  retryableCount: number;
  completedRecordDeletes: number;
  retryableBacklogCount: number;
  oldestActiveAgeMs: number;
  oldestActiveStage: AccountDeletionStage | null;
  maxAttemptCount: number;
  activePageSaturated: boolean;
  completedInventoryScannedCount: number;
  completedMissingExpiryCount: number;
  expiredCompletionEvidenceCount: number;
  nonMinimalCompletionCount: number;
}

interface AccountDeletionRequestDocument {
  uid?: unknown;
  state?: unknown;
  stage?: unknown;
  pass?: unknown;
  finalPass?: unknown;
  passDeletedCount?: unknown;
  boardCursor?: unknown;
  requestedAtMs?: unknown;
  updatedAtMs?: unknown;
  completedAtMs?: unknown;
  expiresAtMs?: unknown;
  attemptCount?: unknown;
  leaseToken?: unknown;
  leaseExpiresAtMs?: unknown;
  lastErrorClass?: unknown;
  lastErrorMessage?: unknown;
  deleted?: unknown;
}

interface AccountDeletionCounters {
  profileDocs: number;
  displayNameIndexDocs: number;
  ownershipIdempotencyDocs: number;
  ownershipDocs: number;
  abuseQuotaDocs: number;
  runSessionDocs: number;
  validatedRunDocs: number;
  rewardGrantDocs: number;
  ghostDocs: number;
  leaderboardPlayerBestDocs: number;
  invalidatedTop10ViewDocs: number;
  pendingReplayObjectDeletes: number;
  validatedReplayObjectDeletes: number;
  ghostArtifactObjectDeletes: number;
}

interface AcquiredDeletion {
  uid: string;
  state: Exclude<AccountDeletionState, "complete">;
  stage: AccountDeletionStage;
  pass: number;
  finalPass: boolean;
  passDeletedCount: number;
  boardCursor: string | null;
  requestedAtMs: number;
  attemptCount: number;
  deleted: AccountDeletionCounters;
  leaseToken: string;
}

interface StageOutcome {
  stage: AccountDeletionStage;
  pass?: number;
  finalPass?: boolean;
  passDeletedCount?: number;
  boardCursor?: string | null;
  counters?: Partial<AccountDeletionCounters>;
  completed?: boolean;
}

interface FlatGhostStage {
  collection: string;
  uidField: "uid" | "userId" | "ownerUid";
}

const flatGhostStages: Partial<
  Record<AccountDeletionStage, FlatGhostStage>
> = {
  ghost_runs_uid: { collection: "ghost_runs", uidField: "uid" },
  ghost_runs_user_id: { collection: "ghost_runs", uidField: "userId" },
  ghost_runs_owner_uid: { collection: "ghost_runs", uidField: "ownerUid" },
  leaderboard_ghost_runs_uid: {
    collection: "leaderboard_ghost_runs",
    uidField: "uid",
  },
  leaderboard_ghost_runs_user_id: {
    collection: "leaderboard_ghost_runs",
    uidField: "userId",
  },
  leaderboard_ghost_runs_owner_uid: {
    collection: "leaderboard_ghost_runs",
    uidField: "ownerUid",
  },
  weekly_ghost_runs_uid: {
    collection: "weekly_ghost_runs",
    uidField: "uid",
  },
  weekly_ghost_runs_user_id: {
    collection: "weekly_ghost_runs",
    uidField: "userId",
  },
  weekly_ghost_runs_owner_uid: {
    collection: "weekly_ghost_runs",
    uidField: "ownerUid",
  },
};

export async function requestAccountDeletion(args: {
  db: Firestore;
  uid: string;
  nowMs?: number;
  pageSize?: number;
  dependencies?: AccountDeletionDependencies;
}): Promise<AccountDeleteResult> {
  const nowMs = args.nowMs ?? Date.now();
  requirePositiveSafeInteger(nowMs, "nowMs");
  const ref = accountDeletionRequestRef(args.db, args.uid);
  await args.db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    if (snapshot.exists) {
      return;
    }
    tx.create(ref, {
      uid: args.uid,
      state: "requested",
      stage: "disable_auth",
      pass: 1,
      finalPass: false,
      passDeletedCount: 0,
      boardCursor: null,
      requestedAtMs: nowMs,
      updatedAtMs: nowMs,
      attemptCount: 0,
      deleted: emptyCounters(),
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  const processed = await processAccountDeletion({
    db: args.db,
    uid: args.uid,
    nowMs,
    pageSize: args.pageSize,
    dependencies: args.dependencies,
  });
  return {
    status: processed.status,
    requestId: processed.requestId,
  };
}

export async function processAccountDeletion(args: {
  db: Firestore;
  uid: string;
  nowMs?: number;
  pageSize?: number;
  dependencies?: AccountDeletionDependencies;
}): Promise<AccountDeletionProcessResult> {
  const nowMs = args.nowMs ?? Date.now();
  const pageSize = args.pageSize ?? 100;
  requirePositiveSafeInteger(nowMs, "nowMs");
  if (!Number.isSafeInteger(pageSize) || pageSize <= 0 || pageSize > 500) {
    throw new Error("pageSize must be an integer between 1 and 500.");
  }

  const acquired = await acquireDeletionLease({
    db: args.db,
    uid: args.uid,
    nowMs,
  });
  if (!acquired) {
    const current = await loadDeletionResult(args.db, args.uid);
    return {
      ...current.result,
      processed: false,
      stage: current.stage,
    };
  }

  try {
    const outcome = await executeStage({
      db: args.db,
      deletion: acquired,
      nowMs,
      pageSize,
      dependencies: args.dependencies,
    });
    await args.dependencies?.afterStage?.(acquired.stage);
    await commitStageOutcome({
      db: args.db,
      deletion: acquired,
      outcome,
      nowMs,
    });
  } catch (error) {
    await recordRetryableFailure({
      db: args.db,
      deletion: acquired,
      nowMs,
      error,
    });
  }

  const current = await loadDeletionResult(args.db, args.uid);
  return {
    ...current.result,
    processed: true,
    stage: current.stage,
  };
}

export async function processPendingAccountDeletions(args: {
  db: Firestore;
  nowMs?: number;
  maxRequests?: number;
  pageSize?: number;
  dependencies?: AccountDeletionDependencies;
}): Promise<AccountDeletionRepairResult> {
  const nowMs = args.nowMs ?? Date.now();
  const maxRequests = args.maxRequests ?? 10;
  requirePositiveSafeInteger(nowMs, "nowMs");
  if (
    !Number.isSafeInteger(maxRequests) ||
    maxRequests <= 0 ||
    maxRequests > 100
  ) {
    throw new Error("maxRequests must be an integer between 1 and 100.");
  }

  const completedInventory = await inspectCompletedTombstones({
    db: args.db,
    nowMs,
    pageSize: maxRequests,
  });

  const expired = await args.db
    .collection(accountDeletionRequestsCollection)
    .where("expiresAtMs", "<=", nowMs)
    .limit(maxRequests)
    .get();
  let completedRecordDeletes = 0;
  for (const doc of expired.docs) {
    const data = doc.data() as AccountDeletionRequestDocument | undefined;
    if (data?.state === "complete") {
      await doc.ref.delete();
      completedRecordDeletes += 1;
    }
  }

  const pending = await args.db
    .collection(accountDeletionRequestsCollection)
    .where("state", "in", ["requested", "in_progress", "retryable"])
    .orderBy("requestedAtMs")
    .limit(maxRequests + 1)
    .get();
  const active = pending.docs.slice(0, maxRequests);
  const activeDocuments = active.map(
    (doc) => doc.data() as AccountDeletionRequestDocument,
  );
  const oldest = activeDocuments[0];
  const oldestRequestedAtMs = readPositiveInteger(
    oldest?.requestedAtMs,
    nowMs,
  );
  const oldestActiveAgeMs =
    activeDocuments.length === 0
      ? 0
      : Math.max(0, nowMs - oldestRequestedAtMs);
  const oldestActiveStage =
    activeDocuments.length === 0 ? null : readStage(oldest?.stage);
  const maxAttemptCount = activeDocuments.reduce(
    (highest, document) =>
      Math.max(highest, readNonNegativeInteger(document.attemptCount)),
    0,
  );
  const retryableBacklogCount = activeDocuments.filter(
    (document) => document.state === "retryable",
  ).length;

  let processedCount = 0;
  let retryableCount = 0;
  for (const doc of active) {
    const result = await processAccountDeletion({
      db: args.db,
      uid: doc.id,
      nowMs,
      pageSize: args.pageSize,
      dependencies: args.dependencies,
    });
    if (result.processed) {
      processedCount += 1;
    }
    if (result.status === "retryable") {
      retryableCount += 1;
    }
  }
  return {
    scannedCount: active.length,
    processedCount,
    retryableCount,
    completedRecordDeletes,
    retryableBacklogCount,
    oldestActiveAgeMs,
    oldestActiveStage,
    maxAttemptCount,
    activePageSaturated: pending.size > maxRequests,
    completedInventoryScannedCount: completedInventory.scannedCount,
    completedMissingExpiryCount: completedInventory.missingExpiryCount,
    expiredCompletionEvidenceCount: completedInventory.expiredEvidenceCount,
    nonMinimalCompletionCount: completedInventory.nonMinimalCount,
  };
}

interface CompletedTombstoneInventoryResult {
  scannedCount: number;
  missingExpiryCount: number;
  expiredEvidenceCount: number;
  nonMinimalCount: number;
}

async function inspectCompletedTombstones(args: {
  db: Firestore;
  nowMs: number;
  pageSize: number;
}): Promise<CompletedTombstoneInventoryResult> {
  const maintenanceRef = args.db
    .collection(maintenanceCollection)
    .doc(completedTombstoneInventoryDocument);
  const maintenance = await maintenanceRef.get();
  const cursor = readOptionalString(maintenance.get("completedCursor"));
  let query = args.db
    .collection(accountDeletionRequestsCollection)
    .where("state", "==", "complete")
    .orderBy(FieldPath.documentId())
    .limit(args.pageSize);
  if (cursor !== null) {
    query = query.startAfter(cursor);
  }
  const page = await query.get();
  const expectedKeys = new Set([
    "state",
    "requestedAtMs",
    "completedAtMs",
    "expiresAtMs",
  ]);
  let missingExpiryCount = 0;
  let expiredEvidenceCount = 0;
  let nonMinimalCount = 0;
  for (const document of page.docs) {
    const data = document.data() as AccountDeletionRequestDocument;
    const expiresAtMs = data.expiresAtMs;
    if (
      typeof expiresAtMs !== "number" ||
      !Number.isSafeInteger(expiresAtMs) ||
      expiresAtMs <= 0
    ) {
      missingExpiryCount += 1;
    } else if (expiresAtMs <= args.nowMs) {
      expiredEvidenceCount += 1;
    }
    if (Object.keys(data).some((key) => !expectedKeys.has(key))) {
      nonMinimalCount += 1;
    }
  }
  const nextCursor =
    page.size === args.pageSize ? page.docs.at(-1)?.id ?? null : null;
  await maintenanceRef.set(
    {
      completedCursor: nextCursor,
      completedInventoryUpdatedAtMs: args.nowMs,
      completedInventoryPage: {
        scannedCount: page.size,
        missingExpiryCount,
        expiredEvidenceCount,
        nonMinimalCount,
      },
    },
    { merge: true },
  );
  if (
    missingExpiryCount > 0 ||
    expiredEvidenceCount > 0 ||
    nonMinimalCount > 0
  ) {
    logger.error("accountDeletionCompletedTombstoneIntegrity", {
      scannedCount: page.size,
      missingExpiryCount,
      expiredEvidenceCount,
      nonMinimalCount,
    });
  }
  return {
    scannedCount: page.size,
    missingExpiryCount,
    expiredEvidenceCount,
    nonMinimalCount,
  };
}

async function acquireDeletionLease(args: {
  db: Firestore;
  uid: string;
  nowMs: number;
}): Promise<AcquiredDeletion | null> {
  const ref = accountDeletionRequestRef(args.db, args.uid);
  return args.db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    if (!snapshot.exists) {
      throw new Error(`Account deletion request ${args.uid} does not exist.`);
    }
    const document =
      snapshot.data() as AccountDeletionRequestDocument | undefined;
    const state = readState(document?.state);
    if (state === "complete") {
      return null;
    }
    const existingLeaseToken = readOptionalString(document?.leaseToken);
    const existingLeaseExpiresAtMs = readNonNegativeInteger(
      document?.leaseExpiresAtMs,
    );
    if (
      existingLeaseToken &&
      existingLeaseExpiresAtMs > args.nowMs
    ) {
      return null;
    }

    const leaseToken = randomUUID();
    const attemptCount = readNonNegativeInteger(document?.attemptCount) + 1;
    tx.set(
      ref,
      {
        state: "in_progress",
        attemptCount,
        leaseToken,
        leaseExpiresAtMs: args.nowMs + deletionLeaseMs,
        updatedAtMs: args.nowMs,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return {
      uid: args.uid,
      state,
      stage: readStage(document?.stage),
      pass: Math.max(1, readNonNegativeInteger(document?.pass)),
      finalPass: document?.finalPass === true,
      passDeletedCount: readNonNegativeInteger(document?.passDeletedCount),
      boardCursor: readOptionalString(document?.boardCursor),
      requestedAtMs: readPositiveInteger(document?.requestedAtMs, args.nowMs),
      attemptCount,
      deleted: readCounters(document?.deleted),
      leaseToken,
    };
  });
}

async function executeStage(args: {
  db: Firestore;
  deletion: AcquiredDeletion;
  nowMs: number;
  pageSize: number;
  dependencies?: AccountDeletionDependencies;
}): Promise<StageOutcome> {
  const { stage } = args.deletion;
  const flatGhost = flatGhostStages[stage];
  if (flatGhost) {
    const deleted = await deleteQueryPage({
      db: args.db,
      collection: flatGhost.collection,
      uidField: flatGhost.uidField,
      uid: args.deletion.uid,
      pageSize: args.pageSize,
      beforeDelete: async (doc) =>
        deleteGhostArtifactsFromDocument(
          doc.data() as Record<string, unknown>,
          resolveReplayArtifactStore(args.dependencies),
        ),
    });
    return repeatedQueryOutcome({
      currentStage: stage,
      deletedCount: deleted.documentCount,
      counters: {
        ghostDocs: deleted.documentCount,
        ghostArtifactObjectDeletes: deleted.ghostArtifactObjectDeletes,
        validatedReplayObjectDeletes:
          deleted.validatedReplayObjectDeletes,
      },
    });
  }

  switch (stage) {
    case "disable_auth":
      await resolveDeletionAuth(args.dependencies).disableAndRevoke(
        args.deletion.uid,
      );
      return { stage: "profile" };
    case "profile":
      return deleteProfile(args.db, args.deletion.uid);
    case "display_name_index":
      return deleteSimpleUidPage({
        ...args,
        collection: displayNameIndexCollection,
        counter: "displayNameIndexDocs",
      });
    case "ownership_idempotency":
      return deleteNestedPage({
        ...args,
        parentCollection: ownershipProfilesCollection,
        childCollection: "idempotency",
        counter: "ownershipIdempotencyDocs",
      });
    case "ownership":
      return deleteSimpleUidPage({
        ...args,
        collection: ownershipProfilesCollection,
        counter: "ownershipDocs",
      });
    case "abuse_quota":
      return deleteSimpleUidPage({
        ...args,
        collection: abuseQuotaCollection,
        counter: "abuseQuotaDocs",
      });
    case "run_sessions":
      return deleteRunDocumentPage({
        ...args,
        collection: runSessionsCollection,
        counter: "runSessionDocs",
      });
    case "validated_runs":
      return deleteRunDocumentPage({
        ...args,
        collection: validatedRunsCollection,
        counter: "validatedRunDocs",
      });
    case "reward_grants":
      return deleteSimpleUidPage({
        ...args,
        collection: rewardGrantsCollection,
        counter: "rewardGrantDocs",
      });
    case "board_ghosts":
      return deleteBoardGhostPage(args);
    case "board_player_bests":
      return deleteBoardPlayerBestPage(args);
    case "pending_replay_artifacts":
      return deletePendingReplayArtifactPage(args);
    case "quiet_wait":
      if (
        args.nowMs <
        args.deletion.requestedAtMs + signedUploadQuietPeriodMs
      ) {
        return { stage: "quiet_wait" };
      }
      return {
        stage: "profile",
        pass: args.deletion.pass + 1,
        finalPass: true,
        passDeletedCount: 0,
        boardCursor: null,
      };
    case "delete_auth":
      await resolveDeletionAuth(args.dependencies).deleteUser(
        args.deletion.uid,
      );
      return { stage: "delete_auth", completed: true };
  }
  throw new Error(`Unsupported account deletion stage: ${stage}`);
}

async function deleteProfile(
  db: Firestore,
  uid: string,
): Promise<StageOutcome> {
  const ref = db.collection(playerProfilesCollection).doc(uid);
  const snapshot = await ref.get();
  if (!snapshot.exists) {
    return { stage: "display_name_index" };
  }
  const document = snapshot.data() as Record<string, unknown>;
  const normalized = readNormalizedDisplayName(document);
  let indexDeleted = 0;
  if (normalized) {
    const indexRef = db
      .collection(displayNameIndexCollection)
      .doc(normalized);
    const indexSnapshot = await indexRef.get();
    if (indexSnapshot.data()?.uid === uid) {
      await indexRef.delete();
      indexDeleted = 1;
    }
  }
  await ref.delete();
  return {
    stage: "profile",
    counters: {
      profileDocs: 1,
      displayNameIndexDocs: indexDeleted,
    },
  };
}

async function deleteSimpleUidPage(args: {
  db: Firestore;
  deletion: AcquiredDeletion;
  pageSize: number;
  collection: string;
  counter: keyof AccountDeletionCounters;
}): Promise<StageOutcome> {
  const deleted = await deleteQueryPage({
    db: args.db,
    collection: args.collection,
    uidField: "uid",
    uid: args.deletion.uid,
    pageSize: args.pageSize,
  });
  return repeatedQueryOutcome({
    currentStage: args.deletion.stage,
    deletedCount: deleted.documentCount,
    counters: { [args.counter]: deleted.documentCount },
  });
}

async function deleteRunDocumentPage(args: {
  db: Firestore;
  deletion: AcquiredDeletion;
  pageSize: number;
  dependencies?: AccountDeletionDependencies;
  collection: string;
  counter: "runSessionDocs" | "validatedRunDocs";
}): Promise<StageOutcome> {
  const replayArtifactStore = resolveReplayArtifactStore(args.dependencies);
  const deleted = await deleteQueryPage({
    db: args.db,
    collection: args.collection,
    uidField: "uid",
    uid: args.deletion.uid,
    pageSize: args.pageSize,
    beforeDelete: async (doc) => {
      const deletedArtifact =
        await replayArtifactStore.deleteObjectIfExists({
          objectPath: buildValidatedReplayObjectPath(doc.id),
        });
      return {
        validatedReplayObjectDeletes: deletedArtifact ? 1 : 0,
      };
    },
  });
  return repeatedQueryOutcome({
    currentStage: args.deletion.stage,
    deletedCount: deleted.documentCount,
    counters: {
      [args.counter]: deleted.documentCount,
      validatedReplayObjectDeletes:
        deleted.validatedReplayObjectDeletes,
    },
  });
}

async function deleteNestedPage(args: {
  db: Firestore;
  deletion: AcquiredDeletion;
  pageSize: number;
  parentCollection: string;
  childCollection: string;
  counter: keyof AccountDeletionCounters;
}): Promise<StageOutcome> {
  const parent = await nextOwnedParent({
    db: args.db,
    collection: args.parentCollection,
    uid: args.deletion.uid,
    after: args.deletion.boardCursor,
  });
  if (!parent) {
    return {
      stage: nextStage(args.deletion.stage),
      boardCursor: null,
    };
  }
  const children = await parent
    .collection(args.childCollection)
    .orderBy(FieldPath.documentId())
    .limit(args.pageSize)
    .get();
  if (children.empty) {
    return {
      stage: args.deletion.stage,
      boardCursor: parent.id,
    };
  }
  await Promise.all(children.docs.map((doc) => doc.ref.delete()));
  return {
    stage: args.deletion.stage,
    boardCursor: args.deletion.boardCursor,
    counters: { [args.counter]: children.size },
  };
}

async function deleteBoardGhostPage(args: {
  db: Firestore;
  deletion: AcquiredDeletion;
  pageSize: number;
  dependencies?: AccountDeletionDependencies;
}): Promise<StageOutcome> {
  const board = await nextBoard(args.db, args.deletion.boardCursor);
  if (!board) {
    return { stage: "board_player_bests", boardCursor: null };
  }
  const manifests = await board
    .collection(ghostManifestsCollection)
    .where("uid", "==", args.deletion.uid)
    .limit(args.pageSize)
    .get();
  if (manifests.empty) {
    return { stage: "board_ghosts", boardCursor: board.id };
  }
  const store = resolveReplayArtifactStore(args.dependencies);
  let ghostArtifactObjectDeletes = 0;
  let validatedReplayObjectDeletes = 0;
  for (const manifest of manifests.docs) {
    const artifactDeletes = await deleteGhostArtifactsFromDocument(
      manifest.data(),
      store,
    );
    ghostArtifactObjectDeletes +=
      artifactDeletes.ghostArtifactObjectDeletes ?? 0;
    validatedReplayObjectDeletes +=
      artifactDeletes.validatedReplayObjectDeletes ?? 0;
    await manifest.ref.delete();
  }
  return {
    stage: "board_ghosts",
    boardCursor: args.deletion.boardCursor,
    counters: {
      ghostDocs: manifests.size,
      ghostArtifactObjectDeletes,
      validatedReplayObjectDeletes,
    },
  };
}

async function deleteBoardPlayerBestPage(args: {
  db: Firestore;
  deletion: AcquiredDeletion;
  pageSize: number;
}): Promise<StageOutcome> {
  const board = await nextBoard(args.db, args.deletion.boardCursor);
  if (!board) {
    return { stage: "pending_replay_artifacts", boardCursor: null };
  }
  const refs = new Map<string, DocumentReference>();
  const directRef = board
    .collection(playerBestsCollection)
    .doc(args.deletion.uid);
  const direct = await directRef.get();
  if (direct.exists) {
    refs.set(directRef.path, directRef);
  }
  const query = await board
    .collection(playerBestsCollection)
    .where("uid", "==", args.deletion.uid)
    .limit(args.pageSize)
    .get();
  for (const doc of query.docs) {
    refs.set(doc.ref.path, doc.ref);
  }
  if (refs.size === 0) {
    return { stage: "board_player_bests", boardCursor: board.id };
  }
  await Promise.all([...refs.values()].map((ref) => ref.delete()));
  const top10Ref = board.collection(boardViewsCollection).doc(top10ViewDocId);
  const top10 = await top10Ref.get();
  if (top10.exists) {
    await top10Ref.delete();
  }
  return {
    stage: "board_player_bests",
    boardCursor: args.deletion.boardCursor,
    counters: {
      leaderboardPlayerBestDocs: refs.size,
      invalidatedTop10ViewDocs: top10.exists ? 1 : 0,
    },
  };
}

async function deletePendingReplayArtifactPage(args: {
  deletion: AcquiredDeletion;
  pageSize: number;
  dependencies?: AccountDeletionDependencies;
}): Promise<StageOutcome> {
  const deleted = await resolveReplayArtifactStore(
    args.dependencies,
  ).deletePageByPrefix({
    prefix: `${replaySubmissionPendingPathPrefix}/${args.deletion.uid}/`,
    maxResults: args.pageSize,
  });
  if (deleted > 0) {
    return {
      stage: "pending_replay_artifacts",
      counters: { pendingReplayObjectDeletes: deleted },
    };
  }

  if (!args.deletion.finalPass) {
    if (args.deletion.passDeletedCount > 0) {
      return {
        stage: "profile",
        pass: args.deletion.pass + 1,
        passDeletedCount: 0,
        boardCursor: null,
      };
    }
    return { stage: "quiet_wait" };
  }
  if (args.deletion.passDeletedCount > 0) {
    return {
      stage: "profile",
      pass: args.deletion.pass + 1,
      finalPass: true,
      passDeletedCount: 0,
      boardCursor: null,
    };
  }
  return { stage: "delete_auth" };
}

async function deleteQueryPage(args: {
  db: Firestore;
  collection: string;
  uidField: string;
  uid: string;
  pageSize: number;
  beforeDelete?: (
    doc: FirebaseFirestore.QueryDocumentSnapshot,
  ) => Promise<Partial<AccountDeletionCounters> | void>;
}): Promise<{
  documentCount: number;
  ghostArtifactObjectDeletes: number;
  validatedReplayObjectDeletes: number;
}> {
  const snapshot = await args.db
    .collection(args.collection)
    .where(args.uidField, "==", args.uid)
    .orderBy(FieldPath.documentId())
    .limit(args.pageSize)
    .get();
  let ghostArtifactObjectDeletes = 0;
  let validatedReplayObjectDeletes = 0;
  for (const doc of snapshot.docs) {
    const before = await args.beforeDelete?.(doc);
    ghostArtifactObjectDeletes +=
      before?.ghostArtifactObjectDeletes ?? 0;
    validatedReplayObjectDeletes +=
      before?.validatedReplayObjectDeletes ?? 0;
    await doc.ref.delete();
  }
  return {
    documentCount: snapshot.size,
    ghostArtifactObjectDeletes,
    validatedReplayObjectDeletes,
  };
}

async function deleteGhostArtifactsFromDocument(
  document: Record<string, unknown>,
  store: ReplayArtifactStore,
): Promise<Partial<AccountDeletionCounters>> {
  let ghostArtifactObjectDeletes = 0;
  let validatedReplayObjectDeletes = 0;
  const ghostPath = readStoragePath(
    document.replayStorageRef,
    ghostArtifactPathPrefix,
  );
  if (
    ghostPath &&
    (await store.deleteObjectIfExists({ objectPath: ghostPath }))
  ) {
    ghostArtifactObjectDeletes += 1;
  }
  const runSessionId =
    readOptionalString(document.runSessionId) ??
    extractRunSessionIdFromValidatedObjectPath(
      readStoragePath(
        document.sourceReplayStorageRef,
        replayValidatedPathPrefix,
      ),
    );
  if (
    runSessionId &&
    (await store.deleteObjectIfExists({
      objectPath: buildValidatedReplayObjectPath(runSessionId),
    }))
  ) {
    validatedReplayObjectDeletes += 1;
  }
  return {
    ghostArtifactObjectDeletes,
    validatedReplayObjectDeletes,
  };
}

function repeatedQueryOutcome(args: {
  currentStage: AccountDeletionStage;
  deletedCount: number;
  counters: Partial<AccountDeletionCounters>;
}): StageOutcome {
  return {
    stage:
      args.deletedCount > 0
        ? args.currentStage
        : nextStage(args.currentStage),
    counters: args.counters,
  };
}

async function nextOwnedParent(args: {
  db: Firestore;
  collection: string;
  uid: string;
  after: string | null;
}): Promise<DocumentReference | null> {
  let query = args.db
    .collection(args.collection)
    .where("uid", "==", args.uid)
    .orderBy(FieldPath.documentId())
    .limit(1);
  if (args.after) {
    query = query.startAfter(args.after);
  }
  const snapshot = await query.get();
  return snapshot.docs[0]?.ref ?? null;
}

async function nextBoard(
  db: Firestore,
  after: string | null,
): Promise<DocumentReference | null> {
  let query = db
    .collection(leaderboardBoardsCollection)
    .orderBy(FieldPath.documentId())
    .limit(1);
  if (after) {
    query = query.startAfter(after);
  }
  const snapshot = await query.get();
  return snapshot.docs[0]?.ref ?? null;
}

async function commitStageOutcome(args: {
  db: Firestore;
  deletion: AcquiredDeletion;
  outcome: StageOutcome;
  nowMs: number;
}): Promise<void> {
  const ref = accountDeletionRequestRef(args.db, args.deletion.uid);
  await args.db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    const document =
      snapshot.data() as AccountDeletionRequestDocument | undefined;
    if (document?.leaseToken !== args.deletion.leaseToken) {
      return;
    }
    const counters = mergeCounters(
      readCounters(document.deleted),
      args.outcome.counters,
    );
    const deletedThisStage = sumCounters(args.outcome.counters);
    const passDeletedCount =
      args.outcome.passDeletedCount ??
      readNonNegativeInteger(document.passDeletedCount) +
        deletedThisStage;
    if (args.outcome.completed) {
      tx.set(
        ref,
        {
          state: "complete",
          requestedAtMs: args.deletion.requestedAtMs,
          completedAtMs: args.nowMs,
          expiresAtMs:
            args.nowMs + accountDeletionCompletionRetentionMs,
        },
      );
      return;
    }
    const write: Record<string, unknown> = {
      state: "in_progress",
      stage: args.outcome.stage,
      pass: args.outcome.pass ?? args.deletion.pass,
      finalPass: args.outcome.finalPass ?? args.deletion.finalPass,
      passDeletedCount,
      boardCursor:
        args.outcome.boardCursor === undefined
          ? args.deletion.boardCursor
          : args.outcome.boardCursor,
      deleted: counters,
      leaseToken: FieldValue.delete(),
      leaseExpiresAtMs: FieldValue.delete(),
      lastErrorClass: FieldValue.delete(),
      lastErrorMessage: FieldValue.delete(),
      updatedAtMs: args.nowMs,
      updatedAt: FieldValue.serverTimestamp(),
    };
    tx.set(ref, write, { merge: true });
  });
}

async function recordRetryableFailure(args: {
  db: Firestore;
  deletion: AcquiredDeletion;
  nowMs: number;
  error: unknown;
}): Promise<void> {
  const ref = accountDeletionRequestRef(args.db, args.deletion.uid);
  await args.db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    if (snapshot.data()?.leaseToken !== args.deletion.leaseToken) {
      return;
    }
    tx.set(
      ref,
      {
        state: "retryable",
        leaseToken: FieldValue.delete(),
        leaseExpiresAtMs: FieldValue.delete(),
        lastErrorClass: errorClass(args.error),
        lastErrorMessage: safeErrorMessage(args.error),
        updatedAtMs: args.nowMs,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
  logger.write({
    severity: "ERROR",
    message: "accountDeletionRetryable",
    uidHash: hashUid(args.deletion.uid),
    stage: args.deletion.stage,
    attemptCount: args.deletion.attemptCount,
    errorClass: errorClass(args.error),
  });
}

async function loadDeletionResult(
  db: Firestore,
  uid: string,
): Promise<{
  result: AccountDeleteResult;
  stage: AccountDeletionStage | "complete";
}> {
  const snapshot = await accountDeletionRequestRef(db, uid).get();
  if (!snapshot.exists) {
    throw new Error(`Account deletion request ${uid} does not exist.`);
  }
  const document =
    snapshot.data() as AccountDeletionRequestDocument | undefined;
  const state = readState(document?.state);
  return {
    result: {
      status:
        state === "complete"
          ? "deleted"
          : state === "retryable"
            ? "retryable"
            : state === "requested"
              ? "requested"
              : "in_progress",
      requestId: uid,
    },
    stage: state === "complete" ? "complete" : readStage(document?.stage),
  };
}

function resolveDeletionAuth(
  dependencies: AccountDeletionDependencies | undefined,
): AccountDeletionAuth {
  return dependencies?.auth ?? firebaseAccountDeletionAuth;
}

function resolveReplayArtifactStore(
  dependencies: AccountDeletionDependencies | undefined,
): ReplayArtifactStore {
  if (dependencies?.replayArtifactStore) {
    return dependencies.replayArtifactStore;
  }
  const bucketName = process.env.REPLAY_STORAGE_BUCKET?.trim();
  if (!bucketName) {
    throw new Error(
      "REPLAY_STORAGE_BUCKET must be configured for account deletion.",
    );
  }
  return new CloudStorageReplayArtifactStore(bucketName);
}

const firebaseAccountDeletionAuth: AccountDeletionAuth = {
  async disableAndRevoke(uid: string): Promise<void> {
    try {
      await getAuth().updateUser(uid, { disabled: true });
      await getAuth().revokeRefreshTokens(uid);
    } catch (error) {
      if (!isAuthUserNotFoundError(error)) {
        throw error;
      }
    }
  },
  async deleteUser(uid: string): Promise<void> {
    try {
      await getAuth().deleteUser(uid);
    } catch (error) {
      if (!isAuthUserNotFoundError(error)) {
        throw error;
      }
    }
  },
};

class CloudStorageReplayArtifactStore implements ReplayArtifactStore {
  constructor(private readonly bucketName: string) {}

  async deletePageByPrefix(args: {
    prefix: string;
    maxResults: number;
  }): Promise<number> {
    const [files] = await getStorage().bucket(this.bucketName).getFiles({
      autoPaginate: false,
      prefix: args.prefix,
      maxResults: args.maxResults,
    });
    await Promise.all(
      files.map((file) => file.delete({ ignoreNotFound: true })),
    );
    return files.length;
  }

  async deleteObjectIfExists(args: {
    objectPath: string;
  }): Promise<boolean> {
    const file = getStorage().bucket(this.bucketName).file(args.objectPath);
    const [exists] = await file.exists();
    if (!exists) {
      return false;
    }
    await file.delete({ ignoreNotFound: true });
    return true;
  }
}

function nextStage(stage: AccountDeletionStage): AccountDeletionStage {
  const index = accountDeletionStages.indexOf(stage);
  return accountDeletionStages[index + 1] ?? "delete_auth";
}

function emptyCounters(): AccountDeletionCounters {
  return {
    profileDocs: 0,
    displayNameIndexDocs: 0,
    ownershipIdempotencyDocs: 0,
    ownershipDocs: 0,
    abuseQuotaDocs: 0,
    runSessionDocs: 0,
    validatedRunDocs: 0,
    rewardGrantDocs: 0,
    ghostDocs: 0,
    leaderboardPlayerBestDocs: 0,
    invalidatedTop10ViewDocs: 0,
    pendingReplayObjectDeletes: 0,
    validatedReplayObjectDeletes: 0,
    ghostArtifactObjectDeletes: 0,
  };
}

function readCounters(value: unknown): AccountDeletionCounters {
  const object =
    value && typeof value === "object"
      ? (value as Record<string, unknown>)
      : {};
  const counters = emptyCounters();
  for (const key of Object.keys(counters) as Array<
    keyof AccountDeletionCounters
  >) {
    counters[key] = readNonNegativeInteger(object[key]);
  }
  return counters;
}

function mergeCounters(
  current: AccountDeletionCounters,
  increments: Partial<AccountDeletionCounters> | undefined,
): AccountDeletionCounters {
  const merged = { ...current };
  if (!increments) {
    return merged;
  }
  for (const [key, value] of Object.entries(increments)) {
    const counter = key as keyof AccountDeletionCounters;
    merged[counter] += value ?? 0;
  }
  return merged;
}

function sumCounters(
  counters: Partial<AccountDeletionCounters> | undefined,
): number {
  return Object.values(counters ?? {}).reduce(
    (sum, value) => sum + (value ?? 0),
    0,
  );
}

function readState(value: unknown): AccountDeletionState {
  return value === "requested" ||
    value === "in_progress" ||
    value === "retryable" ||
    value === "complete"
    ? value
    : "requested";
}

function readStage(value: unknown): AccountDeletionStage {
  return typeof value === "string" &&
    accountDeletionStages.includes(value as AccountDeletionStage)
    ? (value as AccountDeletionStage)
    : "disable_auth";
}

function readOptionalString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function readNonNegativeInteger(value: unknown): number {
  return Number.isSafeInteger(value) && (value as number) >= 0
    ? (value as number)
    : 0;
}

function readPositiveInteger(value: unknown, fallback: number): number {
  const parsed = readNonNegativeInteger(value);
  return parsed > 0 ? parsed : fallback;
}

function requirePositiveSafeInteger(value: number, field: string): void {
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new Error(`${field} must be a positive safe integer.`);
  }
}

function readNormalizedDisplayName(
  document: Record<string, unknown>,
): string | null {
  const stored = readOptionalString(document.displayNameNormalized);
  if (stored) {
    return stored;
  }
  const displayName = readOptionalString(document.displayName);
  return displayName ? normalizeDisplayNameForPolicy(displayName) : null;
}

function buildValidatedReplayObjectPath(runSessionId: string): string {
  return `${replayValidatedPathPrefix}/${runSessionId}.bin.gz`;
}

function readStoragePath(value: unknown, prefix: string): string | null {
  const path = readOptionalString(value);
  return path?.startsWith(`${prefix}/`) ? path : null;
}

function extractRunSessionIdFromValidatedObjectPath(
  objectPath: string | null,
): string | null {
  if (!objectPath) {
    return null;
  }
  const prefix = `${replayValidatedPathPrefix}/`;
  const relative = objectPath.slice(prefix.length);
  if (!objectPath.startsWith(prefix) || relative.includes("/")) {
    return null;
  }
  return relative.endsWith(".bin.gz")
    ? readOptionalString(relative.slice(0, -".bin.gz".length))
    : readOptionalString(relative);
}

function isAuthUserNotFoundError(error: unknown): boolean {
  return (
    !!error &&
    typeof error === "object" &&
    (error as { code?: unknown }).code === "auth/user-not-found"
  );
}

function errorClass(error: unknown): string {
  return error instanceof Error ? error.name : typeof error;
}

function safeErrorMessage(error: unknown): string {
  const message = error instanceof Error ? error.message : String(error);
  return message.slice(0, 512);
}

function hashUid(uid: string): string {
  return createHash("sha256").update(uid).digest("hex").slice(0, 16);
}
