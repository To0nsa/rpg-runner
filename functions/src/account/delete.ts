import { getAuth } from "firebase-admin/auth";
import type {
  CollectionReference,
  DocumentReference,
  Firestore,
} from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { HttpsError } from "firebase-functions/v2/https";

import { normalizeDisplayNameForPolicy } from "../profile/validators.js";

const playerProfilesCollection = "player_profiles";
const displayNameIndexCollection = "display_name_index";
const ownershipProfilesCollection = "ownership_profiles";
const runSessionsCollection = "run_sessions";
const validatedRunsCollection = "validated_runs";
const rewardGrantsCollection = "reward_grants";
const leaderboardBoardsCollection = "leaderboard_boards";
const playerBestsCollection = "player_bests";
const ghostManifestsCollection = "ghost_manifests";
const boardViewsCollection = "views";
const top10ViewDocId = "top10";

const replaySubmissionPendingPathPrefix = "replay-submissions/pending";
const replayValidatedPathPrefix = "replay-submissions/validated";
const ghostArtifactPathPrefix = "ghosts";

/**
 * Keep this list explicit until ghost storage schema is finalized.
 * These are safe to query because deletes are always scoped by UID fields.
 */
const ghostCollectionSpecs: readonly GhostCollectionSpec[] = [
  { collection: "ghost_runs", uidFields: ["uid", "userId", "ownerUid"] },
  {
    collection: "leaderboard_ghost_runs",
    uidFields: ["uid", "userId", "ownerUid"],
  },
  {
    collection: "weekly_ghost_runs",
    uidFields: ["uid", "userId", "ownerUid"],
  },
];

interface GhostCollectionSpec {
  collection: string;
  uidFields: readonly string[];
}

export interface ReplayArtifactStore {
  deleteByPrefix(args: { prefix: string }): Promise<number>;
  deleteObjectIfExists(args: { objectPath: string }): Promise<boolean>;
}

export interface AccountDeleteResult {
  status: "deleted";
  deleted: {
    profileDocs: number;
    displayNameIndexDocs: number;
    ownershipDocs: number;
    runSessionDocs: number;
    validatedRunDocs: number;
    rewardGrantDocs: number;
    ghostDocs: number;
    leaderboardPlayerBestDocs: number;
    invalidatedTop10ViewDocs: number;
    pendingReplayObjectDeletes: number;
    validatedReplayObjectDeletes: number;
    ghostArtifactObjectDeletes: number;
  };
}

interface AccountDeleteArgs {
  db: Firestore;
  uid: string;
  deleteAuthUser?: (uid: string) => Promise<void>;
  replayArtifactStore?: ReplayArtifactStore;
}

interface AccountDeleteCounters {
  profileDocs: number;
  displayNameIndexDocs: number;
  ownershipDocs: number;
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

interface PlayerProfileDocument {
  uid?: unknown;
  displayName?: unknown;
  displayNameNormalized?: unknown;
}

interface DisplayNameIndexDocument {
  uid?: unknown;
}

interface GhostManifestDocument {
  runSessionId?: unknown;
  replayStorageRef?: unknown;
  sourceReplayStorageRef?: unknown;
}

interface GhostDeleteOutcome {
  runSessionIds: Set<string>;
  ghostArtifactObjectPaths: Set<string>;
}

export async function deleteAccountAndData(
  args: AccountDeleteArgs,
): Promise<AccountDeleteResult> {
  const counters: AccountDeleteCounters = {
    profileDocs: 0,
    displayNameIndexDocs: 0,
    ownershipDocs: 0,
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
  const deleteAuthUser = args.deleteAuthUser ?? defaultDeleteAuthUser;
  const replayArtifactStore = await runDeleteStep(
    "create replay artifact store",
    async () => args.replayArtifactStore ?? createDefaultReplayArtifactStore(),
  );

  await runDeleteStep("delete profile and display-name index", async () =>
    deletePlayerProfileAndNameIndex({
      db: args.db,
      uid: args.uid,
      counters,
    }),
  );
  await runDeleteStep("delete ownership state", async () =>
    deleteOwnershipData({
      db: args.db,
      uid: args.uid,
      counters,
    }),
  );
  const deletedRunSessionIds = await runDeleteStep("delete run sessions", async () =>
    deleteRunSessionData({
      db: args.db,
      uid: args.uid,
      counters,
    }),
  );
  const deletedValidatedRunSessionIds = await runDeleteStep(
    "delete validated runs",
    async () =>
      deleteValidatedRunData({
        db: args.db,
        uid: args.uid,
        counters,
      }),
  );
  await runDeleteStep("delete reward grants", async () =>
    deleteRewardGrantData({
      db: args.db,
      uid: args.uid,
      counters,
    }),
  );
  const ghostDeleteOutcome = await runDeleteStep("delete ghost documents", async () =>
    deleteGhostData({
      db: args.db,
      uid: args.uid,
      counters,
    }),
  );
  const affectedLeaderboardBoardIds = await runDeleteStep(
    "delete leaderboard player best entries",
    async () =>
      deleteLeaderboardPlayerBestData({
        db: args.db,
        uid: args.uid,
        counters,
      }),
  );
  await runDeleteStep("invalidate leaderboard cached views", async () =>
    invalidateTop10ViewsForAffectedBoards({
      db: args.db,
      boardIds: affectedLeaderboardBoardIds,
      counters,
    }),
  );
  await runDeleteStep("delete replay and ghost artifacts", async () =>
    deleteReplayArtifacts({
      uid: args.uid,
      runSessionIds: mergeSets(
        deletedRunSessionIds,
        deletedValidatedRunSessionIds,
        ghostDeleteOutcome.runSessionIds,
      ),
      ghostArtifactObjectPaths: ghostDeleteOutcome.ghostArtifactObjectPaths,
      replayArtifactStore,
      counters,
    }),
  );
  await runDeleteStep("delete Firebase Auth user", async () =>
    deleteAuthUserIfPresent(deleteAuthUser, args.uid),
  );

  return {
    status: "deleted",
    deleted: counters,
  };
}

async function defaultDeleteAuthUser(uid: string): Promise<void> {
  await getAuth().deleteUser(uid);
}

async function deleteAuthUserIfPresent(
  deleteAuthUser: (uid: string) => Promise<void>,
  uid: string,
): Promise<void> {
  try {
    await deleteAuthUser(uid);
  } catch (error) {
    if (isAuthUserNotFoundError(error)) {
      return;
    }
    throw error;
  }
}

function isAuthUserNotFoundError(error: unknown): boolean {
  if (!error || typeof error !== "object") {
    return false;
  }
  const code = (error as { code?: unknown }).code;
  return code === "auth/user-not-found";
}

async function deletePlayerProfileAndNameIndex(args: {
  db: Firestore;
  uid: string;
  counters: AccountDeleteCounters;
}): Promise<void> {
  const profileRef = args.db.collection(playerProfilesCollection).doc(args.uid);
  const profileSnap = await profileRef.get();
  const profileDoc = profileSnap.data() as PlayerProfileDocument | undefined;
  const claimedNormalized = readNormalizedDisplayName(profileDoc);

  if (profileSnap.exists) {
    await profileRef.delete();
    args.counters.profileDocs += 1;
  }

  const indexRefsByPath = new Map<string, DocumentReference>();
  if (claimedNormalized.length > 0) {
    const directRef = args.db
      .collection(displayNameIndexCollection)
      .doc(claimedNormalized);
    const directSnap = await directRef.get();
    if (directSnap.exists) {
      const owner = readUid(
        directSnap.data() as DisplayNameIndexDocument | undefined,
      );
      if (owner === args.uid) {
        indexRefsByPath.set(directRef.path, directRef);
      }
    }
  }

  const claimedQuery = await args.db
    .collection(displayNameIndexCollection)
    .where("uid", "==", args.uid)
    .get();
  for (const doc of claimedQuery.docs) {
    indexRefsByPath.set(doc.ref.path, doc.ref);
  }

  for (const ref of indexRefsByPath.values()) {
    await ref.delete();
    args.counters.displayNameIndexDocs += 1;
  }
}

async function deleteOwnershipData(args: {
  db: Firestore;
  uid: string;
  counters: AccountDeleteCounters;
}): Promise<void> {
  const docRefsByPath = new Map<string, DocumentReference>();
  const ownedQuery = await args.db
    .collection(ownershipProfilesCollection)
    .where("uid", "==", args.uid)
    .get();
  for (const doc of ownedQuery.docs) {
    docRefsByPath.set(doc.ref.path, doc.ref);
  }

  for (const ref of docRefsByPath.values()) {
    const snap = await ref.get();
    if (!snap.exists) {
      continue;
    }
    await args.db.recursiveDelete(ref);
    args.counters.ownershipDocs += 1;
  }
}

async function deleteGhostData(args: {
  db: Firestore;
  uid: string;
  counters: AccountDeleteCounters;
}): Promise<GhostDeleteOutcome> {
  const refsByPath = new Map<string, DocumentReference>();
  const runSessionIds = new Set<string>();
  const ghostArtifactObjectPaths = new Set<string>();

  for (const spec of ghostCollectionSpecs) {
    const collectionRef = args.db.collection(
      spec.collection,
    ) as CollectionReference;
    for (const uidField of spec.uidFields) {
      const snapshot = await collectionRef.where(uidField, "==", args.uid).get();
      for (const doc of snapshot.docs) {
        refsByPath.set(doc.ref.path, doc.ref);
      }
    }
  }

  const boardRefs = await args.db
    .collection(leaderboardBoardsCollection)
    .listDocuments();
  for (const boardRef of boardRefs) {
    const manifestQuery = await boardRef
      .collection(ghostManifestsCollection)
      .where("uid", "==", args.uid)
      .get();
    for (const doc of manifestQuery.docs) {
      const manifest = doc.data() as GhostManifestDocument | undefined;
      const runSessionId = readOptionalNonEmptyString(manifest?.runSessionId);
      if (runSessionId) {
        runSessionIds.add(runSessionId);
      }
      const replayStorageRef = readStorageObjectPath(
        manifest?.replayStorageRef,
        ghostArtifactPathPrefix,
      );
      if (replayStorageRef) {
        ghostArtifactObjectPaths.add(replayStorageRef);
      }
      const sourceReplayStorageRef = readStorageObjectPath(
        manifest?.sourceReplayStorageRef,
        replayValidatedPathPrefix,
      );
      const sourceRunSessionId = sourceReplayStorageRef
        ? extractRunSessionIdFromValidatedObjectPath(sourceReplayStorageRef)
        : null;
      if (sourceRunSessionId) {
        runSessionIds.add(sourceRunSessionId);
      }
      refsByPath.set(doc.ref.path, doc.ref);
    }
  }

  for (const ref of refsByPath.values()) {
    await args.db.recursiveDelete(ref);
    args.counters.ghostDocs += 1;
  }

  return {
    runSessionIds,
    ghostArtifactObjectPaths,
  };
}

async function deleteRunSessionData(args: {
  db: Firestore;
  uid: string;
  counters: AccountDeleteCounters;
}): Promise<Set<string>> {
  const runSessionIds = new Set<string>();
  const query = await args.db
    .collection(runSessionsCollection)
    .where("uid", "==", args.uid)
    .get();
  for (const doc of query.docs) {
    const runSessionId = doc.id.trim();
    if (runSessionId.length > 0) {
      runSessionIds.add(runSessionId);
    }
    await args.db.recursiveDelete(doc.ref);
    args.counters.runSessionDocs += 1;
  }
  return runSessionIds;
}

async function deleteValidatedRunData(args: {
  db: Firestore;
  uid: string;
  counters: AccountDeleteCounters;
}): Promise<Set<string>> {
  const runSessionIds = new Set<string>();
  const query = await args.db
    .collection(validatedRunsCollection)
    .where("uid", "==", args.uid)
    .get();
  for (const doc of query.docs) {
    const runSessionId = doc.id.trim();
    if (runSessionId.length > 0) {
      runSessionIds.add(runSessionId);
    }
    await args.db.recursiveDelete(doc.ref);
    args.counters.validatedRunDocs += 1;
  }
  return runSessionIds;
}

async function deleteRewardGrantData(args: {
  db: Firestore;
  uid: string;
  counters: AccountDeleteCounters;
}): Promise<void> {
  const query = await args.db
    .collection(rewardGrantsCollection)
    .where("uid", "==", args.uid)
    .get();
  for (const doc of query.docs) {
    await args.db.recursiveDelete(doc.ref);
    args.counters.rewardGrantDocs += 1;
  }
}

async function deleteLeaderboardPlayerBestData(args: {
  db: Firestore;
  uid: string;
  counters: AccountDeleteCounters;
}): Promise<Set<string>> {
  const boardIds = new Set<string>();
  const boardRefs = await args.db
    .collection(leaderboardBoardsCollection)
    .listDocuments();
  for (const boardRef of boardRefs) {
    const boardId = boardRef.id.trim();
    if (boardId.length === 0) {
      continue;
    }
    const refsByPath = new Map<string, DocumentReference>();
    const directRef = boardRef.collection(playerBestsCollection).doc(args.uid);
    const directSnap = await directRef.get();
    if (directSnap.exists) {
      refsByPath.set(directRef.path, directRef);
    }
    const snapshot = await boardRef
      .collection(playerBestsCollection)
      .where("uid", "==", args.uid)
      .get();
    for (const doc of snapshot.docs) {
      refsByPath.set(doc.ref.path, doc.ref);
    }
    if (refsByPath.size === 0) {
      continue;
    }
    boardIds.add(boardId);
    for (const ref of refsByPath.values()) {
      await args.db.recursiveDelete(ref);
      args.counters.leaderboardPlayerBestDocs += 1;
    }
  }
  return boardIds;
}

async function invalidateTop10ViewsForAffectedBoards(args: {
  db: Firestore;
  boardIds: Set<string>;
  counters: AccountDeleteCounters;
}): Promise<void> {
  for (const boardId of args.boardIds) {
    const top10ViewRef = args.db
      .collection(leaderboardBoardsCollection)
      .doc(boardId)
      .collection(boardViewsCollection)
      .doc(top10ViewDocId);
    const top10ViewSnap = await top10ViewRef.get();
    if (!top10ViewSnap.exists) {
      continue;
    }
    await top10ViewRef.delete();
    args.counters.invalidatedTop10ViewDocs += 1;
  }
}

async function deleteReplayArtifacts(args: {
  uid: string;
  runSessionIds: Set<string>;
  ghostArtifactObjectPaths: Set<string>;
  replayArtifactStore: ReplayArtifactStore;
  counters: AccountDeleteCounters;
}): Promise<void> {
  args.counters.pendingReplayObjectDeletes +=
    await args.replayArtifactStore.deleteByPrefix({
      prefix: buildPendingReplayPrefix(args.uid),
    });
  args.counters.validatedReplayObjectDeletes +=
    await deleteValidatedReplayArtifactsForRunSessions({
      replayArtifactStore: args.replayArtifactStore,
      runSessionIds: args.runSessionIds,
    });
  args.counters.ghostArtifactObjectDeletes +=
    await deleteGhostReplayArtifactsByPath({
      replayArtifactStore: args.replayArtifactStore,
      objectPaths: args.ghostArtifactObjectPaths,
    });
}

async function deleteValidatedReplayArtifactsForRunSessions(args: {
  replayArtifactStore: ReplayArtifactStore;
  runSessionIds: Set<string>;
}): Promise<number> {
  let deletedCount = 0;
  for (const runSessionId of args.runSessionIds) {
    const objectPath = buildValidatedReplayObjectPath(runSessionId);
    const deleted = await args.replayArtifactStore.deleteObjectIfExists({
      objectPath,
    });
    if (deleted) {
      deletedCount += 1;
    }
  }
  return deletedCount;
}

async function deleteGhostReplayArtifactsByPath(args: {
  replayArtifactStore: ReplayArtifactStore;
  objectPaths: Set<string>;
}): Promise<number> {
  let deletedCount = 0;
  for (const objectPath of args.objectPaths) {
    const deleted = await args.replayArtifactStore.deleteObjectIfExists({
      objectPath,
    });
    if (deleted) {
      deletedCount += 1;
    }
  }
  return deletedCount;
}

function buildPendingReplayPrefix(uid: string): string {
  return `${replaySubmissionPendingPathPrefix}/${uid}/`;
}

function buildValidatedReplayObjectPath(runSessionId: string): string {
  return `${replayValidatedPathPrefix}/${runSessionId}.bin.gz`;
}

function extractRunSessionIdFromValidatedObjectPath(
  objectPath: string,
): string | null {
  const validatedPrefix = `${replayValidatedPathPrefix}/`;
  if (!objectPath.startsWith(validatedPrefix)) {
    return null;
  }
  const relativePath = objectPath.slice(validatedPrefix.length).trim();
  if (relativePath.length === 0 || relativePath.includes("/")) {
    return null;
  }
  if (!relativePath.endsWith(".bin.gz")) {
    return relativePath;
  }
  const runSessionId = relativePath.slice(0, -".bin.gz".length).trim();
  return runSessionId.length > 0 ? runSessionId : null;
}

function readStorageObjectPath(value: unknown, prefix: string): string | null {
  const path = readOptionalNonEmptyString(value);
  if (!path) {
    return null;
  }
  const requiredPrefix = `${prefix}/`;
  if (!path.startsWith(requiredPrefix)) {
    return null;
  }
  return path;
}

function readOptionalNonEmptyString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

async function runDeleteStep<T>(
  step: string,
  operation: () => Promise<T>,
): Promise<T> {
  try {
    return await operation();
  } catch (error) {
    throw mapDeleteStepError({ step, error });
  }
}

function mapDeleteStepError(args: {
  step: string;
  error: unknown;
}): HttpsError {
  if (args.error instanceof HttpsError) {
    return args.error;
  }
  const code = readErrorCode(args.error);
  const message = readErrorMessage(args.error);
  const details = {
    step: args.step,
    upstreamCode: code ?? null,
  };
  if (
    code === "auth/insufficient-permission" ||
    message.includes("insufficient permission")
  ) {
    return new HttpsError(
      "permission-denied",
      `Account deletion failed during ${args.step}: backend service account is missing required Firebase Auth permissions.`,
      details,
    );
  }
  if (
    code === "auth/invalid-credential" ||
    message.includes("must initialize app with a certificate credential")
  ) {
    return new HttpsError(
      "failed-precondition",
      `Account deletion failed during ${args.step}: backend Firebase Auth credentials are not configured correctly.`,
      details,
    );
  }
  if (
    code === "failed-precondition" ||
    code === "9" ||
    message.includes("failed_precondition") ||
    message.includes("failed precondition")
  ) {
    return new HttpsError(
      "failed-precondition",
      `Account deletion failed during ${args.step}: Firestore precondition check failed. Ensure required indexes/preconditions are available, then retry.`,
      details,
    );
  }
  if (
    code === "permission-denied" ||
    code === "7" ||
    code === "insufficient-permission" ||
    message.includes("permission denied") ||
    message.includes("insufficient permission") ||
    message.includes("storage.objects.")
  ) {
    return new HttpsError(
      "permission-denied",
      `Account deletion failed during ${args.step}: backend service account is missing required permissions.`,
      details,
    );
  }
  if (
    code === "deadline-exceeded" ||
    code === "4" ||
    message.includes("deadline exceeded")
  ) {
    return new HttpsError(
      "deadline-exceeded",
      `Account deletion timed out during ${args.step}. Retry and check backend performance limits.`,
      details,
    );
  }
  if (message.includes("replay_storage_bucket")) {
    return new HttpsError(
      "failed-precondition",
      `Account deletion failed during ${args.step}: REPLAY_STORAGE_BUCKET must be configured.`,
      details,
    );
  }
  return new HttpsError(
    "internal",
    `Account deletion failed during ${args.step}.`,
    details,
  );
}

function readErrorCode(error: unknown): string | null {
  if (!error || typeof error !== "object") {
    return null;
  }
  const rawCode = (error as { code?: unknown }).code;
  if (typeof rawCode === "string") {
    return rawCode.trim().toLowerCase();
  }
  if (typeof rawCode === "number" && Number.isFinite(rawCode)) {
    return String(rawCode);
  }
  return null;
}

function readErrorMessage(error: unknown): string {
  if (!error || typeof error !== "object") {
    return "";
  }
  const rawMessage = (error as { message?: unknown }).message;
  if (typeof rawMessage !== "string") {
    return "";
  }
  return rawMessage.trim().toLowerCase();
}

function mergeSets<T>(...sets: Set<T>[]): Set<T> {
  const merged = new Set<T>();
  for (const set of sets) {
    for (const item of set) {
      merged.add(item);
    }
  }
  return merged;
}

function createDefaultReplayArtifactStore(): ReplayArtifactStore {
  const bucketName = process.env.REPLAY_STORAGE_BUCKET?.trim();
  if (!bucketName) {
    throw new Error(
      "REPLAY_STORAGE_BUCKET must be configured for account deletion replay artifact cleanup.",
    );
  }
  return new CloudStorageReplayArtifactStore(bucketName);
}

class CloudStorageReplayArtifactStore implements ReplayArtifactStore {
  constructor(private readonly bucketName: string) {}

  async deleteByPrefix(args: { prefix: string }): Promise<number> {
    const bucket = getStorage().bucket(this.bucketName);
    let deletedCount = 0;
    let pageToken: string | undefined;
    do {
      const [files, nextQuery] = await bucket.getFiles({
        autoPaginate: false,
        prefix: args.prefix,
        pageToken,
      });
      for (const file of files) {
        await file.delete({ ignoreNotFound: true });
        deletedCount += 1;
      }
      pageToken = readPageToken(nextQuery);
    } while (pageToken);
    return deletedCount;
  }

  async deleteObjectIfExists(args: { objectPath: string }): Promise<boolean> {
    const bucket = getStorage().bucket(this.bucketName);
    const file = bucket.file(args.objectPath);
    const [exists] = await file.exists();
    if (!exists) {
      return false;
    }
    await file.delete({ ignoreNotFound: true });
    return true;
  }
}

function readPageToken(value: unknown): string | undefined {
  if (!value || typeof value !== "object") {
    return undefined;
  }
  const token = (value as { pageToken?: unknown }).pageToken;
  if (typeof token !== "string" || token.trim().length === 0) {
    return undefined;
  }
  return token;
}

function readUid(doc: DisplayNameIndexDocument | undefined): string {
  if (!doc || typeof doc.uid !== "string") {
    return "";
  }
  return doc.uid;
}

function readNormalizedDisplayName(doc: PlayerProfileDocument | undefined): string {
  if (!doc) {
    return "";
  }
  if (
    typeof doc.displayNameNormalized === "string" &&
    doc.displayNameNormalized.trim().length > 0
  ) {
    return doc.displayNameNormalized.trim();
  }
  if (typeof doc.displayName !== "string" || doc.displayName.trim().length === 0) {
    return "";
  }
  return normalizeDisplayNameForPolicy(doc.displayName);
}
