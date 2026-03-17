import type {
  Firestore,
  Query,
  QueryDocumentSnapshot,
} from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";

import {
  isRunSessionState,
  isTerminalRunSessionState,
  type RunSessionState,
} from "./session_state.js";

const runSessionsCollection = "run_sessions";
const validatedRunsCollection = "validated_runs";
const rewardGrantsCollection = "reward_grants";
const replaySubmissionPathPrefix = "replay-submissions/pending/";
const replayValidatedPathPrefix = "replay-submissions/validated/";

const defaultStalePendingUploadCutoffMs = 48 * 60 * 60 * 1000;
const defaultStaleValidatedArtifactCutoffMs = 15 * 24 * 60 * 60 * 1000;
const defaultTerminalRunSessionRetentionMs = 90 * 24 * 60 * 60 * 1000;
const defaultValidatedRunRetentionMs = 365 * 24 * 60 * 60 * 1000;
const defaultRewardGrantRetentionMs = 365 * 24 * 60 * 60 * 1000;
const defaultMaxExpiredSessionUpdatesPerRun = 200;
const defaultMaxPendingUploadDeletesPerRun = 200;
const defaultMaxValidatedArtifactDeletesPerRun = 200;
const defaultMaxTerminalRunSessionDeletesPerRun = 200;
const defaultMaxValidatedRunDeletesPerRun = 200;
const defaultMaxRewardGrantDeletesPerRun = 200;
const defaultRunSessionScanPageSize = 200;
const defaultFirestoreRetentionPageSize = 200;
const defaultRetentionScanMultiplier = 10;
const defaultRunSessionMaxScanCount =
  defaultMaxExpiredSessionUpdatesPerRun * 10;
const defaultRunSessionRetentionMaxScanCount =
  defaultMaxTerminalRunSessionDeletesPerRun * defaultRetentionScanMultiplier;
const defaultValidatedRunRetentionMaxScanCount =
  defaultMaxValidatedRunDeletesPerRun * defaultRetentionScanMultiplier;
const defaultRewardGrantRetentionMaxScanCount =
  defaultMaxRewardGrantDeletesPerRun * defaultRetentionScanMultiplier;
const defaultPendingObjectListPageSize = 200;

const expirableStates = new Set<RunSessionState>([
  "issued",
  "uploading",
  "uploaded",
]);

export interface PendingReplayObjectInfo {
  objectPath: string;
  updatedAtMs: number;
}

export interface PendingReplayObjectListPage {
  objects: PendingReplayObjectInfo[];
  nextPageToken?: string;
}

export interface PendingReplayObjectStore {
  listPendingObjects(args: {
    prefix: string;
    maxResults: number;
    pageToken?: string;
  }): Promise<PendingReplayObjectListPage>;
  deleteObject(args: { objectPath: string }): Promise<void>;
}

export interface RunSubmissionCleanupDependencies {
  pendingReplayObjectStore?: PendingReplayObjectStore;
  validatedReplayObjectStore?: PendingReplayObjectStore;
  ghostExposureLookup?: GhostExposureLookup;
  stalePendingUploadCutoffMs?: number;
  staleValidatedArtifactCutoffMs?: number;
  terminalRunSessionRetentionMs?: number;
  validatedRunRetentionMs?: number;
  rewardGrantRetentionMs?: number;
  maxExpiredSessionUpdatesPerRun?: number;
  maxPendingUploadDeletesPerRun?: number;
  maxValidatedArtifactDeletesPerRun?: number;
  maxTerminalRunSessionDeletesPerRun?: number;
  maxValidatedRunDeletesPerRun?: number;
  maxRewardGrantDeletesPerRun?: number;
}

export interface RunSubmissionCleanupResult {
  nowMs: number;
  expiredSessionCount: number;
  scannedSessionCount: number;
  terminalRunSessionDeletedCount: number;
  terminalRunSessionScannedCount: number;
  terminalRunSessionRetentionMs: number;
  validatedRunDeletedCount: number;
  validatedRunScannedCount: number;
  validatedRunRetentionMs: number;
  rewardGrantDeletedCount: number;
  rewardGrantScannedCount: number;
  rewardGrantRetentionMs: number;
  stalePendingUploadDeletedCount: number;
  stalePendingUploadScannedCount: number;
  stalePendingUploadCutoffMs: number;
  pendingUploadCleanupSkipped: boolean;
  staleValidatedArtifactDeletedCount: number;
  staleValidatedArtifactScannedCount: number;
  staleValidatedArtifactCutoffMs: number;
  validatedArtifactCleanupSkipped: boolean;
}

interface RunSessionDocLike {
  state?: unknown;
  createdAtMs?: unknown;
  updatedAtMs?: unknown;
  expiresAtMs?: unknown;
  terminalAtMs?: unknown;
}

interface RewardGrantDocLike {
  state?: unknown;
  lifecycleState?: unknown;
  updatedAtMs?: unknown;
}

export interface GhostExposureLookup {
  isRunSessionGhostExposed(args: { runSessionId: string }): Promise<boolean>;
}

export function createDefaultRunSubmissionCleanupDependencies(): RunSubmissionCleanupDependencies {
  const bucketName = process.env.REPLAY_STORAGE_BUCKET?.trim();
  const sharedStore = bucketName
    ? new CloudStoragePendingReplayObjectStore(bucketName)
    : undefined;
  return {
    pendingReplayObjectStore: sharedStore,
    validatedReplayObjectStore: sharedStore,
    stalePendingUploadCutoffMs: defaultStalePendingUploadCutoffMs,
    staleValidatedArtifactCutoffMs: defaultStaleValidatedArtifactCutoffMs,
    terminalRunSessionRetentionMs: defaultTerminalRunSessionRetentionMs,
    validatedRunRetentionMs: defaultValidatedRunRetentionMs,
    rewardGrantRetentionMs: defaultRewardGrantRetentionMs,
    maxExpiredSessionUpdatesPerRun: defaultMaxExpiredSessionUpdatesPerRun,
    maxPendingUploadDeletesPerRun: defaultMaxPendingUploadDeletesPerRun,
    maxValidatedArtifactDeletesPerRun: defaultMaxValidatedArtifactDeletesPerRun,
    maxTerminalRunSessionDeletesPerRun: defaultMaxTerminalRunSessionDeletesPerRun,
    maxValidatedRunDeletesPerRun: defaultMaxValidatedRunDeletesPerRun,
    maxRewardGrantDeletesPerRun: defaultMaxRewardGrantDeletesPerRun,
  };
}

export async function runReplaySubmissionCleanup(args: {
  db: Firestore;
  nowMs?: number;
  dependencies?: RunSubmissionCleanupDependencies;
}): Promise<RunSubmissionCleanupResult> {
  const nowMs = args.nowMs ?? Date.now();
  const dependencies = args.dependencies ?? createDefaultRunSubmissionCleanupDependencies();
  const stalePendingUploadCutoffMs =
    dependencies.stalePendingUploadCutoffMs ?? defaultStalePendingUploadCutoffMs;
  const staleValidatedArtifactCutoffMs =
    dependencies.staleValidatedArtifactCutoffMs ??
    defaultStaleValidatedArtifactCutoffMs;
  const terminalRunSessionRetentionMs =
    dependencies.terminalRunSessionRetentionMs ??
    defaultTerminalRunSessionRetentionMs;
  const validatedRunRetentionMs =
    dependencies.validatedRunRetentionMs ?? defaultValidatedRunRetentionMs;
  const rewardGrantRetentionMs =
    dependencies.rewardGrantRetentionMs ?? defaultRewardGrantRetentionMs;
  const maxExpiredSessionUpdatesPerRun =
    dependencies.maxExpiredSessionUpdatesPerRun ??
    defaultMaxExpiredSessionUpdatesPerRun;
  const maxPendingUploadDeletesPerRun =
    dependencies.maxPendingUploadDeletesPerRun ??
    defaultMaxPendingUploadDeletesPerRun;
  const maxValidatedArtifactDeletesPerRun =
    dependencies.maxValidatedArtifactDeletesPerRun ??
    defaultMaxValidatedArtifactDeletesPerRun;
  const maxTerminalRunSessionDeletesPerRun =
    dependencies.maxTerminalRunSessionDeletesPerRun ??
    defaultMaxTerminalRunSessionDeletesPerRun;
  const maxValidatedRunDeletesPerRun =
    dependencies.maxValidatedRunDeletesPerRun ??
    defaultMaxValidatedRunDeletesPerRun;
  const maxRewardGrantDeletesPerRun =
    dependencies.maxRewardGrantDeletesPerRun ??
    defaultMaxRewardGrantDeletesPerRun;

  const expiredSessionOutcome = await expireRunSessionsPastExpiry({
    db: args.db,
    nowMs,
    maxUpdates: maxExpiredSessionUpdatesPerRun,
    maxScanCount: defaultRunSessionMaxScanCount,
    pageSize: defaultRunSessionScanPageSize,
  });

  const terminalRunSessionOutcome = await deleteTerminalRunSessionsPastRetention({
    db: args.db,
    cutoffMs: nowMs - terminalRunSessionRetentionMs,
    maxDeletes: maxTerminalRunSessionDeletesPerRun,
    maxScanCount: defaultRunSessionRetentionMaxScanCount,
    pageSize: defaultFirestoreRetentionPageSize,
  });

  const validatedRunOutcome = await deleteValidatedRunsPastRetention({
    db: args.db,
    cutoffMs: nowMs - validatedRunRetentionMs,
    maxDeletes: maxValidatedRunDeletesPerRun,
    maxScanCount: defaultValidatedRunRetentionMaxScanCount,
    pageSize: defaultFirestoreRetentionPageSize,
  });

  const rewardGrantOutcome = await deleteSettledRewardGrantsPastRetention({
    db: args.db,
    cutoffMs: nowMs - rewardGrantRetentionMs,
    maxDeletes: maxRewardGrantDeletesPerRun,
    maxScanCount: defaultRewardGrantRetentionMaxScanCount,
    pageSize: defaultFirestoreRetentionPageSize,
  });

  let stalePendingUploadDeletedCount = 0;
  let stalePendingUploadScannedCount = 0;
  const pendingCutoffMs = nowMs - stalePendingUploadCutoffMs;
  const pendingUploadCleanupSkipped = dependencies.pendingReplayObjectStore == null;
  if (dependencies.pendingReplayObjectStore) {
    const staleUploadOutcome = await deleteStalePendingUploadObjects({
      objectStore: dependencies.pendingReplayObjectStore,
      cutoffMs: pendingCutoffMs,
      maxDeletes: maxPendingUploadDeletesPerRun,
      pageSize: defaultPendingObjectListPageSize,
    });
    stalePendingUploadDeletedCount = staleUploadOutcome.deletedCount;
    stalePendingUploadScannedCount = staleUploadOutcome.scannedCount;
  }

  let staleValidatedArtifactDeletedCount = 0;
  let staleValidatedArtifactScannedCount = 0;
  const validatedCutoffMs = nowMs - staleValidatedArtifactCutoffMs;
  const validatedArtifactCleanupSkipped =
    dependencies.validatedReplayObjectStore == null;
  if (dependencies.validatedReplayObjectStore) {
    const ghostExposureLookup =
      dependencies.ghostExposureLookup ?? new FirestoreGhostExposureLookup(args.db);
    const validatedReplayOutcome = await deleteStaleValidatedReplayArtifacts({
      objectStore: dependencies.validatedReplayObjectStore,
      ghostExposureLookup,
      cutoffMs: validatedCutoffMs,
      maxDeletes: maxValidatedArtifactDeletesPerRun,
      pageSize: defaultPendingObjectListPageSize,
    });
    staleValidatedArtifactDeletedCount = validatedReplayOutcome.deletedCount;
    staleValidatedArtifactScannedCount = validatedReplayOutcome.scannedCount;
  }

  return {
    nowMs,
    expiredSessionCount: expiredSessionOutcome.expiredCount,
    scannedSessionCount: expiredSessionOutcome.scannedCount,
    terminalRunSessionDeletedCount: terminalRunSessionOutcome.deletedCount,
    terminalRunSessionScannedCount: terminalRunSessionOutcome.scannedCount,
    terminalRunSessionRetentionMs,
    validatedRunDeletedCount: validatedRunOutcome.deletedCount,
    validatedRunScannedCount: validatedRunOutcome.scannedCount,
    validatedRunRetentionMs,
    rewardGrantDeletedCount: rewardGrantOutcome.deletedCount,
    rewardGrantScannedCount: rewardGrantOutcome.scannedCount,
    rewardGrantRetentionMs,
    stalePendingUploadDeletedCount,
    stalePendingUploadScannedCount,
    stalePendingUploadCutoffMs,
    pendingUploadCleanupSkipped,
    staleValidatedArtifactDeletedCount,
    staleValidatedArtifactScannedCount,
    staleValidatedArtifactCutoffMs,
    validatedArtifactCleanupSkipped,
  };
}

async function expireRunSessionsPastExpiry(args: {
  db: Firestore;
  nowMs: number;
  maxUpdates: number;
  maxScanCount: number;
  pageSize: number;
}): Promise<{ expiredCount: number; scannedCount: number }> {
  const runSessions = args.db.collection(runSessionsCollection);
  const toExpire: QueryDocumentSnapshot[] = [];
  let scannedCount = 0;
  let cursor: QueryDocumentSnapshot | undefined;

  while (
    toExpire.length < args.maxUpdates &&
    scannedCount < args.maxScanCount
  ) {
    let query = runSessions
      .where("expiresAtMs", "<=", args.nowMs)
      .orderBy("expiresAtMs", "asc")
      .limit(args.pageSize);
    if (cursor) {
      query = query.startAfter(cursor);
    }
    const page = await query.get();
    if (page.empty) {
      break;
    }
    scannedCount += page.size;

    for (const doc of page.docs) {
      if (toExpire.length >= args.maxUpdates) {
        break;
      }
      const data = doc.data() as RunSessionDocLike;
      const state = parseRunSessionState(data.state);
      if (state && expirableStates.has(state)) {
        toExpire.push(doc);
      }
    }
    cursor = page.docs[page.docs.length - 1];
  }

  if (toExpire.length === 0) {
    return {
      expiredCount: 0,
      scannedCount,
    };
  }

  const batch = args.db.batch();
  for (const doc of toExpire) {
    batch.set(
      doc.ref,
      {
        state: "expired",
        updatedAtMs: args.nowMs,
        message: "Run session expired by cleanup job.",
      },
      { merge: true },
    );
  }
  await batch.commit();

  return {
    expiredCount: toExpire.length,
    scannedCount,
  };
}

async function deleteTerminalRunSessionsPastRetention(args: {
  db: Firestore;
  cutoffMs: number;
  maxDeletes: number;
  maxScanCount: number;
  pageSize: number;
}): Promise<{ deletedCount: number; scannedCount: number }> {
  if (args.maxDeletes <= 0 || args.maxScanCount <= 0) {
    return { deletedCount: 0, scannedCount: 0 };
  }

  const runSessions = args.db.collection(runSessionsCollection);
  const toDelete: QueryDocumentSnapshot[] = [];
  let scannedCount = 0;
  let cursor: QueryDocumentSnapshot | undefined;

  while (
    toDelete.length < args.maxDeletes &&
    scannedCount < args.maxScanCount
  ) {
    let query = runSessions
      .where("updatedAtMs", "<=", args.cutoffMs)
      .orderBy("updatedAtMs", "asc")
      .limit(args.pageSize);
    if (cursor) {
      query = query.startAfter(cursor);
    }
    const page = await query.get();
    if (page.empty) {
      break;
    }
    scannedCount += page.size;

    for (const doc of page.docs) {
      if (toDelete.length >= args.maxDeletes) {
        break;
      }
      const data = doc.data() as RunSessionDocLike;
      const state = parseRunSessionState(data.state);
      if (!state || !isTerminalRunSessionState(state)) {
        continue;
      }
      const terminalTimestampMs = resolveRunSessionTerminalTimestampMs(data);
      if (terminalTimestampMs == null || terminalTimestampMs > args.cutoffMs) {
        continue;
      }
      toDelete.push(doc);
    }
    cursor = page.docs[page.docs.length - 1];
  }

  let deletedCount = 0;
  for (const doc of toDelete) {
    await args.db.recursiveDelete(doc.ref);
    deletedCount += 1;
  }
  return {
    deletedCount,
    scannedCount,
  };
}

async function deleteValidatedRunsPastRetention(args: {
  db: Firestore;
  cutoffMs: number;
  maxDeletes: number;
  maxScanCount: number;
  pageSize: number;
}): Promise<{ deletedCount: number; scannedCount: number }> {
  if (args.maxDeletes <= 0 || args.maxScanCount <= 0) {
    return { deletedCount: 0, scannedCount: 0 };
  }

  const validatedRuns = args.db.collection(validatedRunsCollection);
  const toDelete: QueryDocumentSnapshot[] = [];
  let scannedCount = 0;
  let cursor: QueryDocumentSnapshot | undefined;

  while (
    toDelete.length < args.maxDeletes &&
    scannedCount < args.maxScanCount
  ) {
    let query = validatedRuns
      .where("createdAtMs", "<=", args.cutoffMs)
      .orderBy("createdAtMs", "asc")
      .limit(args.pageSize);
    if (cursor) {
      query = query.startAfter(cursor);
    }
    const page = await query.get();
    if (page.empty) {
      break;
    }
    scannedCount += page.size;
    for (const doc of page.docs) {
      if (toDelete.length >= args.maxDeletes) {
        break;
      }
      toDelete.push(doc);
    }
    cursor = page.docs[page.docs.length - 1];
  }

  let deletedCount = 0;
  for (const doc of toDelete) {
    await args.db.recursiveDelete(doc.ref);
    deletedCount += 1;
  }
  return {
    deletedCount,
    scannedCount,
  };
}

async function deleteSettledRewardGrantsPastRetention(args: {
  db: Firestore;
  cutoffMs: number;
  maxDeletes: number;
  maxScanCount: number;
  pageSize: number;
}): Promise<{ deletedCount: number; scannedCount: number }> {
  if (args.maxDeletes <= 0 || args.maxScanCount <= 0) {
    return { deletedCount: 0, scannedCount: 0 };
  }

  const rewardGrants = args.db.collection(rewardGrantsCollection);
  const toDelete: QueryDocumentSnapshot[] = [];
  let scannedCount = 0;
  let cursor: QueryDocumentSnapshot | undefined;

  while (
    toDelete.length < args.maxDeletes &&
    scannedCount < args.maxScanCount
  ) {
    let query = rewardGrants
      .where("updatedAtMs", "<=", args.cutoffMs)
      .orderBy("updatedAtMs", "asc")
      .limit(args.pageSize);
    if (cursor) {
      query = query.startAfter(cursor);
    }
    const page = await query.get();
    if (page.empty) {
      break;
    }
    scannedCount += page.size;

    for (const doc of page.docs) {
      if (toDelete.length >= args.maxDeletes) {
        break;
      }
      const data = doc.data() as RewardGrantDocLike;
      if (!isRewardGrantDeletionEligible(data)) {
        continue;
      }
      toDelete.push(doc);
    }
    cursor = page.docs[page.docs.length - 1];
  }

  let deletedCount = 0;
  for (const doc of toDelete) {
    await args.db.recursiveDelete(doc.ref);
    deletedCount += 1;
  }
  return {
    deletedCount,
    scannedCount,
  };
}

function isRewardGrantDeletionEligible(data: RewardGrantDocLike): boolean {
  const lifecycleState = optionalTrimmedString(data.lifecycleState);
  return lifecycleState === "validated_settled" || lifecycleState === "revoked_final";
}

function optionalTrimmedString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

async function deleteStalePendingUploadObjects(args: {
  objectStore: PendingReplayObjectStore;
  cutoffMs: number;
  maxDeletes: number;
  pageSize: number;
}): Promise<{ deletedCount: number; scannedCount: number }> {
  let deletedCount = 0;
  let scannedCount = 0;
  let pageToken: string | undefined;

  while (deletedCount < args.maxDeletes) {
    const maxResults = Math.min(
      args.pageSize,
      args.maxDeletes - deletedCount,
    );
    const page = await args.objectStore.listPendingObjects({
      prefix: replaySubmissionPathPrefix,
      maxResults,
      pageToken,
    });

    if (page.objects.length === 0) {
      if (!page.nextPageToken) {
        break;
      }
      pageToken = page.nextPageToken;
      continue;
    }

    for (const objectInfo of page.objects) {
      scannedCount += 1;
      if (objectInfo.updatedAtMs > args.cutoffMs) {
        continue;
      }
      await args.objectStore.deleteObject({ objectPath: objectInfo.objectPath });
      deletedCount += 1;
      if (deletedCount >= args.maxDeletes) {
        break;
      }
    }

    if (!page.nextPageToken) {
      break;
    }
    pageToken = page.nextPageToken;
  }

  return { deletedCount, scannedCount };
}

async function deleteStaleValidatedReplayArtifacts(args: {
  objectStore: PendingReplayObjectStore;
  ghostExposureLookup: GhostExposureLookup;
  cutoffMs: number;
  maxDeletes: number;
  pageSize: number;
}): Promise<{ deletedCount: number; scannedCount: number }> {
  let deletedCount = 0;
  let scannedCount = 0;
  let pageToken: string | undefined;

  while (deletedCount < args.maxDeletes) {
    const maxResults = Math.min(
      args.pageSize,
      args.maxDeletes - deletedCount,
    );
    const page = await args.objectStore.listPendingObjects({
      prefix: replayValidatedPathPrefix,
      maxResults,
      pageToken,
    });

    if (page.objects.length === 0) {
      if (!page.nextPageToken) {
        break;
      }
      pageToken = page.nextPageToken;
      continue;
    }

    for (const objectInfo of page.objects) {
      scannedCount += 1;
      if (objectInfo.updatedAtMs > args.cutoffMs) {
        continue;
      }
      const runSessionId = extractRunSessionIdFromValidatedObjectPath(
        objectInfo.objectPath,
      );
      if (!runSessionId) {
        continue;
      }
      const ghostExposed = await args.ghostExposureLookup.isRunSessionGhostExposed({
        runSessionId,
      });
      if (ghostExposed) {
        continue;
      }
      await args.objectStore.deleteObject({ objectPath: objectInfo.objectPath });
      deletedCount += 1;
      if (deletedCount >= args.maxDeletes) {
        break;
      }
    }

    if (!page.nextPageToken) {
      break;
    }
    pageToken = page.nextPageToken;
  }

  return { deletedCount, scannedCount };
}

function extractRunSessionIdFromValidatedObjectPath(
  objectPath: string,
): string | undefined {
  if (!objectPath.startsWith(replayValidatedPathPrefix)) {
    return undefined;
  }
  const relative = objectPath.slice(replayValidatedPathPrefix.length).trim();
  if (relative.length === 0 || relative.includes("/")) {
    return undefined;
  }
  const suffixIndex = relative.indexOf(".bin.gz");
  const runSessionId = suffixIndex === -1
    ? relative
    : relative.slice(0, suffixIndex);
  if (runSessionId.trim().length === 0) {
    return undefined;
  }
  return runSessionId.trim();
}

function resolveRunSessionTerminalTimestampMs(
  doc: RunSessionDocLike,
): number | undefined {
  return (
    parseInteger(doc.terminalAtMs) ??
    parseInteger(doc.updatedAtMs) ??
    parseInteger(doc.expiresAtMs) ??
    parseInteger(doc.createdAtMs)
  );
}

function parseInteger(value: unknown): number | undefined {
  if (typeof value !== "number" || !Number.isInteger(value)) {
    return undefined;
  }
  return value;
}

function parseRunSessionState(value: unknown): RunSessionState | undefined {
  if (!isRunSessionState(value)) {
    return undefined;
  }
  return value;
}

class FirestoreGhostExposureLookup implements GhostExposureLookup {
  constructor(private readonly db: Firestore) {}

  async isRunSessionGhostExposed(args: {
    runSessionId: string;
  }): Promise<boolean> {
    let query: Query = this.db.collectionGroup("ghost_manifests");
    query = query.where("runSessionId", "==", args.runSessionId);
    query = query.where("status", "==", "active");
    query = query.where("exposed", "==", true);
    const snapshot = await query.limit(1).get();
    return !snapshot.empty;
  }
}

class CloudStoragePendingReplayObjectStore implements PendingReplayObjectStore {
  constructor(private readonly bucketName: string) {}

  async listPendingObjects(args: {
    prefix: string;
    maxResults: number;
    pageToken?: string;
  }): Promise<PendingReplayObjectListPage> {
    const bucket = getStorage().bucket(this.bucketName);
    const [files, nextQuery] = await bucket.getFiles({
      prefix: args.prefix,
      autoPaginate: false,
      maxResults: args.maxResults,
      pageToken: args.pageToken,
    });

    const objects: PendingReplayObjectInfo[] = [];
    for (const file of files) {
      const updatedAtMs = await readFileUpdatedAtMs(file);
      if (updatedAtMs == null) {
        continue;
      }
      objects.push({
        objectPath: file.name,
        updatedAtMs,
      });
    }

    const nextPageToken = readPageToken(nextQuery);
    return {
      objects,
      nextPageToken,
    };
  }

  async deleteObject(args: { objectPath: string }): Promise<void> {
    const bucket = getStorage().bucket(this.bucketName);
    await bucket.file(args.objectPath).delete({ ignoreNotFound: true });
  }
}

async function readFileUpdatedAtMs(file: {
  getMetadata(): Promise<[{
    updated?: unknown;
    timeCreated?: unknown;
  }, ...unknown[]]>;
}): Promise<number | undefined> {
  try {
    const [metadata] = await file.getMetadata();
    return parseTimestampMs(metadata.updated) ?? parseTimestampMs(metadata.timeCreated);
  } catch {
    return undefined;
  }
}

function parseTimestampMs(value: unknown): number | undefined {
  if (typeof value !== "string") {
    return undefined;
  }
  const parsed = Date.parse(value);
  if (!Number.isFinite(parsed)) {
    return undefined;
  }
  return parsed;
}

function readPageToken(value: unknown): string | undefined {
  if (!value || typeof value !== "object") {
    return undefined;
  }
  const maybeToken = (value as { pageToken?: unknown }).pageToken;
  if (typeof maybeToken !== "string" || maybeToken.trim().length === 0) {
    return undefined;
  }
  return maybeToken;
}
