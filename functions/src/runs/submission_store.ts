import { CloudTasksClient } from "@google-cloud/tasks";
import type {
  DocumentReference,
  DocumentSnapshot,
  Firestore,
  Transaction,
} from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { HttpsError } from "firebase-functions/v2/https";

import type { JsonObject } from "../ownership/contracts.js";
import { requireObject } from "../ownership/validators.js";
import {
  isRunSessionState,
  type RunSessionState,
} from "./session_state.js";

const runSessionsCollection = "run_sessions";
const validatedRunsCollection = "validated_runs";
const rewardGrantsCollection = "reward_grants";

const replayUploadMaxBytes = 8_388_608;
const uploadGrantTtlMs = 15 * 60 * 1000;
const replayUploadContentType = "application/octet-stream";
const replaySubmissionFileName = "replay.bin.gz";
const replaySubmissionPathPrefix = "replay-submissions/pending";

function isProvisionalRewardCreationEnabled(): boolean {
  return readBooleanEnv("RUN_REWARD_PROVISIONAL_CREATE_ENABLED") ?? true;
}

interface RunSessionSubmissionRecord {
  runSessionId: string;
  uid: string;
  mode?: "practice" | "competitive" | "weekly";
  boardId?: string;
  boardKey?: JsonObject;
  state: RunSessionState;
  expiresAtMs: number;
  updatedAtMs: number;
  message?: string;
  uploadLease?: UploadLeaseRecord;
  uploadedReplay?: UploadedReplayRecord;
  provisionalSummary?: JsonObject;
}

type RewardPresentationStatus = "none" | "provisional" | "final" | "revoked";

interface RewardProjectionRecord {
  status: RewardPresentationStatus;
  provisionalGold: number;
  effectiveGoldDelta: number;
  spendableGoldDelta: number;
  updatedAtMs: number;
  grantId?: string;
  message?: string;
}

interface UploadLeaseRecord {
  objectPath: string;
  contentType: string;
  maxBytes: number;
  issuedAtMs: number;
  expiresAtMs: number;
}

interface UploadedReplayRecord {
  objectPath: string;
  canonicalSha256: string;
  contentLengthBytes: number;
  contentType: string;
  storageGeneration?: string;
  finalizedAtMs: number;
}

export interface UploadGrantRecord {
  runSessionId: string;
  objectPath: string;
  uploadUrl: string;
  uploadMethod: "PUT";
  contentType: string;
  maxBytes: number;
  expiresAtMs: number;
}

interface UploadGrantIssueResult {
  uploadUrl: string;
  uploadMethod: "PUT";
}

interface ReplayObjectMetadata {
  contentLengthBytes: number;
  contentType?: string;
  generation?: string;
}

export interface ReplaySubmissionObjectStore {
  issueUploadGrant(args: {
    objectPath: string;
    contentType: string;
    expiresAtMs: number;
  }): Promise<UploadGrantIssueResult>;
  loadMetadata(args: { objectPath: string }): Promise<ReplayObjectMetadata>;
}

export interface RunValidationTaskDispatcher {
  enqueueRunValidationTask(args: { runSessionId: string }): Promise<void>;
}

export interface RunSubmissionDependencies {
  objectStore: ReplaySubmissionObjectStore;
  taskDispatcher: RunValidationTaskDispatcher;
}

interface CreateUploadGrantArgs {
  db: Firestore;
  uid: string;
  runSessionId: string;
  nowMs?: number;
  dependencies: RunSubmissionDependencies;
}

interface FinalizeUploadArgs {
  db: Firestore;
  uid: string;
  runSessionId: string;
  canonicalSha256: string;
  contentLengthBytes: number;
  contentType?: string;
  objectPath?: string;
  provisionalSummary?: JsonObject;
  nowMs?: number;
  dependencies: RunSubmissionDependencies;
}

interface LoadSubmissionStatusArgs {
  db: Firestore;
  uid: string;
  runSessionId: string;
}

export interface FinalizeUploadResult {
  submissionStatus: JsonObject;
}

export interface LoadSubmissionStatusResult {
  submissionStatus: JsonObject;
}

export function createDefaultRunSubmissionDependencies(): RunSubmissionDependencies {
  return {
    objectStore: createCloudStorageReplaySubmissionObjectStore(),
    taskDispatcher: createCloudTasksRunValidationTaskDispatcher(),
  };
}

export async function createRunSessionUploadGrant(
  args: CreateUploadGrantArgs,
): Promise<{ uploadGrant: UploadGrantRecord }> {
  const nowMs = args.nowMs ?? Date.now();
  const objectPath = pendingReplayObjectPath(args.uid, args.runSessionId);
  const leaseExpiresAtMs = nowMs + uploadGrantTtlMs;
  const runSessionRef = args.db
    .collection(runSessionsCollection)
    .doc(args.runSessionId);

  await args.db.runTransaction(async (tx) => {
    const session = await loadRunSessionForUpdate(tx, runSessionRef);
    assertRunSessionOwner(session, args.uid);
    throwIfExpiredBeforeFinalize(session, nowMs, tx, runSessionRef);
    if (session.state !== "issued" && session.state !== "uploading") {
      throw new HttpsError(
        "failed-precondition",
        `runSession ${args.runSessionId} is ${session.state} and cannot issue upload grants.`,
      );
    }
    const uploadLease: UploadLeaseRecord = {
      objectPath,
      contentType: replayUploadContentType,
      maxBytes: replayUploadMaxBytes,
      issuedAtMs: nowMs,
      expiresAtMs: leaseExpiresAtMs,
    };
    tx.set(
      runSessionRef,
      {
        state: "uploading",
        updatedAtMs: nowMs,
        uploadLease,
      },
      { merge: true },
    );
  });

  const issued = await args.dependencies.objectStore.issueUploadGrant({
    objectPath,
    contentType: replayUploadContentType,
    expiresAtMs: leaseExpiresAtMs,
  });
  return {
    uploadGrant: {
      runSessionId: args.runSessionId,
      objectPath,
      uploadUrl: issued.uploadUrl,
      uploadMethod: issued.uploadMethod,
      contentType: replayUploadContentType,
      maxBytes: replayUploadMaxBytes,
      expiresAtMs: leaseExpiresAtMs,
    },
  };
}

export async function finalizeRunSessionUpload(
  args: FinalizeUploadArgs,
): Promise<FinalizeUploadResult> {
  const nowMs = args.nowMs ?? Date.now();
  const contentType = normalizeContentType(
    args.contentType ?? replayUploadContentType,
  );
  if (args.contentLengthBytes <= 0) {
    throw new HttpsError(
      "invalid-argument",
      "contentLengthBytes must be greater than zero.",
    );
  }
  if (args.contentLengthBytes > replayUploadMaxBytes) {
    throw new HttpsError(
      "invalid-argument",
      `contentLengthBytes exceeds ${replayUploadMaxBytes} bytes.`,
    );
  }

  const objectPath =
    args.objectPath ?? pendingReplayObjectPath(args.uid, args.runSessionId);
  if (objectPath !== pendingReplayObjectPath(args.uid, args.runSessionId)) {
    throw new HttpsError(
      "failed-precondition",
      "objectPath does not match the canonical replay submission path.",
    );
  }

  const storageMetadata = await args.dependencies.objectStore.loadMetadata({
    objectPath,
  });
  if (storageMetadata.contentLengthBytes > replayUploadMaxBytes) {
    throw new HttpsError(
      "failed-precondition",
      `Uploaded replay exceeds ${replayUploadMaxBytes} bytes.`,
    );
  }
  if (storageMetadata.contentLengthBytes !== args.contentLengthBytes) {
    throw new HttpsError(
      "failed-precondition",
      "Uploaded replay size does not match finalize metadata.",
    );
  }
  const storedContentType = storageMetadata.contentType
    ? normalizeContentType(storageMetadata.contentType)
    : undefined;
  if (storedContentType && storedContentType !== contentType) {
    throw new HttpsError(
      "failed-precondition",
      "Uploaded replay contentType does not match finalize metadata.",
    );
  }

  const runSessionRef = args.db
    .collection(runSessionsCollection)
    .doc(args.runSessionId);
  const rewardGrantRef = args.db
    .collection(rewardGrantsCollection)
    .doc(args.runSessionId);

  let shouldEnqueue = false;
  await args.db.runTransaction(async (tx) => {
    const session = await loadRunSessionForUpdate(tx, runSessionRef);
    assertRunSessionOwner(session, args.uid);
    throwIfExpiredBeforeFinalize(session, nowMs, tx, runSessionRef);

    if (
      session.state !== "issued" &&
      session.state !== "uploading" &&
      session.state !== "uploaded" &&
      session.state !== "pending_validation"
    ) {
      throw new HttpsError(
        "failed-precondition",
        `runSession ${args.runSessionId} is ${session.state} and cannot be finalized.`,
      );
    }

    const nextUploadedReplay: UploadedReplayRecord = {
      objectPath,
      canonicalSha256: args.canonicalSha256,
      contentLengthBytes: args.contentLengthBytes,
      contentType,
      storageGeneration: storageMetadata.generation,
      finalizedAtMs: nowMs,
    };
    if (session.uploadedReplay) {
      assertFinalizeMetadataMatches(session.uploadedReplay, nextUploadedReplay);
    }

    const nextState: RunSessionState =
      session.state === "pending_validation" ? "pending_validation" : "uploaded";
    shouldEnqueue = nextState === "uploaded";

    const rewardGrantSnapshot = await tx.get(rewardGrantRef);

    tx.set(
      runSessionRef,
      {
        state: nextState,
        updatedAtMs: nowMs,
        uploadedReplay: nextUploadedReplay,
        provisionalSummary: args.provisionalSummary ?? null,
      },
      { merge: true },
    );

    if (!rewardGrantSnapshot.exists && isProvisionalRewardCreationEnabled()) {
      tx.set(rewardGrantRef, {
        runSessionId: args.runSessionId,
        uid: args.uid,
        ...(session.mode ? { mode: session.mode } : {}),
        ...(session.boardId ? { boardId: session.boardId } : {}),
        ...(session.boardKey ? { boardKey: session.boardKey } : {}),
        lifecycleState: "provisional_created",
        goldAmount: readProvisionalGoldAmount(args.provisionalSummary),
        createdAtMs: nowMs,
        updatedAtMs: nowMs,
        provisionalSummary: args.provisionalSummary ?? null,
        validatedRunRef: `${validatedRunsCollection}/${args.runSessionId}`,
      });
    } else {
      const rewardGrantData = rewardGrantSnapshot.data() as
        | Record<string, unknown>
        | undefined;
      const rewardUid = requireOptionalString(rewardGrantData?.uid);
      if (rewardUid && rewardUid !== args.uid) {
        throw new HttpsError(
          "failed-precondition",
          "reward grant uid does not match authenticated run owner.",
        );
      }
    }
  });

  if (shouldEnqueue) {
    try {
      await args.dependencies.taskDispatcher.enqueueRunValidationTask({
        runSessionId: args.runSessionId,
      });
    } catch (error) {
      throw toTaskEnqueueHttpsError(error);
    }

    await args.db.runTransaction(async (tx) => {
      const session = await loadRunSessionForUpdate(tx, runSessionRef);
      assertRunSessionOwner(session, args.uid);
      if (session.state === "uploaded") {
        tx.set(
          runSessionRef,
          {
            state: "pending_validation",
            updatedAtMs: nowMs,
          },
          { merge: true },
        );
      }
    });
  }

  return loadRunSessionSubmissionStatus({
    db: args.db,
    uid: args.uid,
    runSessionId: args.runSessionId,
  });
}

export async function loadRunSessionSubmissionStatus(
  args: LoadSubmissionStatusArgs,
): Promise<LoadSubmissionStatusResult> {
  const runSessionRef = args.db
    .collection(runSessionsCollection)
    .doc(args.runSessionId);
  const snapshot = await runSessionRef.get();
  const session = decodeRunSessionSnapshot(snapshot, args.runSessionId);
  assertRunSessionOwner(session, args.uid);
  let validatedRun: JsonObject | undefined;
  if (session.state === "validated" || session.state === "rejected") {
    validatedRun = await loadValidatedRun(args.db, session.runSessionId);
  }
  const rewardGrant = await loadRewardGrant(args.db, session.runSessionId);
  const reward = projectSubmissionReward({
    session,
    rewardGrant,
  });
  return {
    submissionStatus: toSubmissionStatus(session, validatedRun, reward),
  };
}

function toSubmissionStatus(
  session: RunSessionSubmissionRecord,
  validatedRun?: JsonObject,
  reward?: RewardProjectionRecord,
): JsonObject {
  const out: JsonObject = {
    runSessionId: session.runSessionId,
    state: session.state,
    updatedAtMs: session.updatedAtMs,
  };
  if (session.message) {
    out.message = session.message;
  }
  if (validatedRun) {
    out.validatedRun = validatedRun;
  }
  if (reward) {
    const rewardPayload: JsonObject = {
      status: reward.status,
      provisionalGold: reward.provisionalGold,
      effectiveGoldDelta: reward.effectiveGoldDelta,
      spendableGoldDelta: reward.spendableGoldDelta,
      updatedAtMs: reward.updatedAtMs,
    };
    if (reward.grantId) {
      rewardPayload.grantId = reward.grantId;
    }
    if (reward.message) {
      rewardPayload.message = reward.message;
    }
    out.reward = rewardPayload;
  }
  return out;
}

async function loadValidatedRun(
  db: Firestore,
  runSessionId: string,
): Promise<JsonObject | undefined> {
  const snapshot = await db.collection(validatedRunsCollection).doc(runSessionId).get();
  if (!snapshot.exists) {
    return undefined;
  }
  const data = snapshot.data();
  if (!data || typeof data !== "object") {
    return undefined;
  }
  return structuredClone(data) as JsonObject;
}

async function loadRewardGrant(
  db: Firestore,
  runSessionId: string,
): Promise<JsonObject | undefined> {
  const snapshot = await db.collection(rewardGrantsCollection).doc(runSessionId).get();
  if (!snapshot.exists) {
    return undefined;
  }
  const data = snapshot.data();
  if (!data || typeof data !== "object") {
    return undefined;
  }
  return structuredClone(data) as JsonObject;
}

function projectSubmissionReward(args: {
  session: RunSessionSubmissionRecord;
  rewardGrant?: JsonObject;
}): RewardProjectionRecord | undefined {
  const rewardGrant = args.rewardGrant;
  if (!rewardGrant) {
    return undefined;
  }

  const grantId =
    requireOptionalString(rewardGrant.runSessionId) ?? args.session.runSessionId;
  const state = requireOptionalString(rewardGrant.lifecycleState);
  const goldAmount = clampNonNegativeInt(rewardGrant.goldAmount);
  const updatedAtMs =
    integerOrNull(rewardGrant.updatedAtMs) ?? args.session.updatedAtMs;
  const message =
    requireOptionalString(rewardGrant.settlementReason) ?? args.session.message;

  if (state === "provisional_created" || state === "provisional_visible") {
    return {
      status: "provisional",
      provisionalGold: goldAmount,
      effectiveGoldDelta: 0,
      spendableGoldDelta: 0,
      updatedAtMs,
      grantId,
      message,
    };
  }
  if (state === "validated_settled") {
    return {
      status: "final",
      provisionalGold: goldAmount,
      effectiveGoldDelta: goldAmount,
      spendableGoldDelta: goldAmount,
      updatedAtMs,
      grantId,
      message,
    };
  }
  if (state === "revocation_visible" || state === "revoked_final") {
    return {
      status: "revoked",
      provisionalGold: goldAmount,
      effectiveGoldDelta: 0,
      spendableGoldDelta: 0,
      updatedAtMs,
      grantId,
      message,
    };
  }

  return undefined;
}

function readProvisionalGoldAmount(summary?: JsonObject): number {
  if (!summary) {
    return 0;
  }
  return clampNonNegativeInt(summary.goldEarned);
}

function clampNonNegativeInt(value: unknown): number {
  const parsed = integerOrNull(value) ?? 0;
  return parsed < 0 ? 0 : parsed;
}

function integerOrNull(value: unknown): number | null {
  if (typeof value === "number" && Number.isInteger(value)) {
    return value;
  }
  return null;
}

function pendingReplayObjectPath(uid: string, runSessionId: string): string {
  return `${replaySubmissionPathPrefix}/${uid}/${runSessionId}/${replaySubmissionFileName}`;
}

function assertRunSessionOwner(
  session: RunSessionSubmissionRecord,
  expectedUid: string,
): void {
  if (session.uid !== expectedUid) {
    throw new HttpsError(
      "permission-denied",
      "runSession does not belong to the authenticated user.",
    );
  }
}

function throwIfExpiredBeforeFinalize(
  session: RunSessionSubmissionRecord,
  nowMs: number,
  tx: Transaction,
  runSessionRef: DocumentReference,
): void {
  const canExpire =
    session.state === "issued" ||
    session.state === "uploading" ||
    session.state === "uploaded";
  if (!canExpire || nowMs < session.expiresAtMs) {
    return;
  }
  tx.set(
    runSessionRef,
    {
      state: "expired",
      updatedAtMs: nowMs,
      message: "Run session expired before finalize completed.",
    },
    { merge: true },
  );
  throw new HttpsError(
    "failed-precondition",
    "Run session expired before finalize.",
  );
}

async function loadRunSessionForUpdate(
  tx: Transaction,
  runSessionRef: DocumentReference,
): Promise<RunSessionSubmissionRecord> {
  const snapshot = await tx.get(runSessionRef);
  return decodeRunSessionSnapshot(snapshot, runSessionRef.id);
}

function decodeRunSessionSnapshot(
  snapshot: DocumentSnapshot,
  runSessionId: string,
): RunSessionSubmissionRecord {
  if (!snapshot.exists) {
    throw new HttpsError(
      "not-found",
      `runSession ${runSessionId} was not found.`,
    );
  }
  const dataRaw = snapshot.data();
  if (!dataRaw || typeof dataRaw !== "object") {
    throw new HttpsError(
      "failed-precondition",
      `runSession ${runSessionId} has malformed payload.`,
    );
  }
  const data = dataRaw as Record<string, unknown>;
  const state = data.state;
  if (!isRunSessionState(state)) {
    throw new HttpsError(
      "failed-precondition",
      `runSession ${runSessionId} has unknown state ${String(state)}.`,
    );
  }
  const uid = requireString(data.uid, "runSession.uid");
  const expiresAtMs = requireInteger(data.expiresAtMs, "runSession.expiresAtMs");
  const updatedAtMs = requireInteger(data.updatedAtMs, "runSession.updatedAtMs");
  const message = requireOptionalString(data.message);
  const mode = decodeOptionalRunMode(data.mode);
  const ticketRewardContext = decodeRunTicketRewardContext(data.runTicket);

  return {
    runSessionId: requireOptionalString(data.runSessionId) ?? runSessionId,
    uid,
    mode,
    boardId: ticketRewardContext.boardId,
    boardKey: ticketRewardContext.boardKey,
    state,
    expiresAtMs,
    updatedAtMs,
    message,
    uploadLease: decodeOptionalUploadLease(data.uploadLease),
    uploadedReplay: decodeOptionalUploadedReplay(data.uploadedReplay),
    provisionalSummary: decodeOptionalJsonObject(data.provisionalSummary),
  };
}

function decodeOptionalJsonObject(value: unknown): JsonObject | undefined {
  if (value === null || value === undefined) {
    return undefined;
  }
  if (typeof value !== "object" || Array.isArray(value)) {
    return undefined;
  }
  return structuredClone(value as Record<string, unknown>) as JsonObject;
}

function decodeOptionalUploadLease(value: unknown): UploadLeaseRecord | undefined {
  if (value === undefined || value === null) {
    return undefined;
  }
  const object = requireObject(value, "runSession.uploadLease");
  return {
    objectPath: requireString(object.objectPath, "runSession.uploadLease.objectPath"),
    contentType: requireString(
      object.contentType,
      "runSession.uploadLease.contentType",
    ),
    maxBytes: requireInteger(object.maxBytes, "runSession.uploadLease.maxBytes"),
    issuedAtMs: requireInteger(
      object.issuedAtMs,
      "runSession.uploadLease.issuedAtMs",
    ),
    expiresAtMs: requireInteger(
      object.expiresAtMs,
      "runSession.uploadLease.expiresAtMs",
    ),
  };
}

function decodeOptionalUploadedReplay(
  value: unknown,
): UploadedReplayRecord | undefined {
  if (value === undefined || value === null) {
    return undefined;
  }
  const object = requireObject(value, "runSession.uploadedReplay");
  const canonicalSha256 = requireString(
    object.canonicalSha256,
    "runSession.uploadedReplay.canonicalSha256",
  );
  if (!/^[a-f0-9]{64}$/u.test(canonicalSha256)) {
    throw new HttpsError(
      "failed-precondition",
      "runSession.uploadedReplay.canonicalSha256 must be lower-case SHA-256 hex.",
    );
  }
  return {
    objectPath: requireString(
      object.objectPath,
      "runSession.uploadedReplay.objectPath",
    ),
    canonicalSha256,
    contentLengthBytes: requireInteger(
      object.contentLengthBytes,
      "runSession.uploadedReplay.contentLengthBytes",
    ),
    contentType: requireString(
      object.contentType,
      "runSession.uploadedReplay.contentType",
    ),
    storageGeneration: requireOptionalString(object.storageGeneration),
    finalizedAtMs: requireInteger(
      object.finalizedAtMs,
      "runSession.uploadedReplay.finalizedAtMs",
    ),
  };
}

function decodeOptionalRunMode(
  value: unknown,
): "practice" | "competitive" | "weekly" | undefined {
  if (value !== "practice" && value !== "competitive" && value !== "weekly") {
    return undefined;
  }
  return value;
}

function decodeRunTicketRewardContext(value: unknown): {
  boardId?: string;
  boardKey?: JsonObject;
} {
  const ticket = decodeOptionalJsonObject(value);
  if (!ticket) {
    return {};
  }

  const boardId = requireOptionalString(ticket.boardId);
  const boardKey = decodeOptionalJsonObject(ticket.boardKey);
  return {
    boardId,
    boardKey,
  };
}

function assertFinalizeMetadataMatches(
  existing: UploadedReplayRecord,
  next: UploadedReplayRecord,
): void {
  if (
    existing.objectPath !== next.objectPath ||
    existing.canonicalSha256 !== next.canonicalSha256 ||
    existing.contentLengthBytes !== next.contentLengthBytes ||
    normalizeContentType(existing.contentType) !== normalizeContentType(next.contentType)
  ) {
    throw new HttpsError(
      "already-exists",
      "runSession was already finalized with different replay metadata.",
    );
  }
}

function requireString(value: unknown, fieldName: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("failed-precondition", `${fieldName} must be a string.`);
  }
  return value.trim();
}

function requireOptionalString(value: unknown): string | undefined {
  if (typeof value !== "string") {
    return undefined;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

function requireInteger(value: unknown, fieldName: string): number {
  if (typeof value !== "number" || !Number.isInteger(value)) {
    throw new HttpsError("failed-precondition", `${fieldName} must be an integer.`);
  }
  return value;
}

function normalizeContentType(value: string): string {
  return value.split(";")[0]!.trim().toLowerCase();
}

class CloudStorageReplaySubmissionObjectStore
  implements ReplaySubmissionObjectStore
{
  constructor(private readonly bucketName: string) {}

  async issueUploadGrant(args: {
    objectPath: string;
    contentType: string;
    expiresAtMs: number;
  }): Promise<UploadGrantIssueResult> {
    const bucket = getStorage().bucket(this.bucketName);
    const file = bucket.file(args.objectPath);
    const [uploadUrl] = await file.getSignedUrl({
      version: "v4",
      action: "write",
      expires: args.expiresAtMs,
      contentType: args.contentType,
    });
    return {
      uploadUrl,
      uploadMethod: "PUT",
    };
  }

  async loadMetadata(args: { objectPath: string }): Promise<ReplayObjectMetadata> {
    const bucket = getStorage().bucket(this.bucketName);
    const file = bucket.file(args.objectPath);
    try {
      const [metadata] = await file.getMetadata();
      const contentLengthBytes = Number.parseInt(String(metadata.size ?? ""), 10);
      if (!Number.isFinite(contentLengthBytes) || contentLengthBytes <= 0) {
        throw new HttpsError(
          "failed-precondition",
          "Uploaded replay metadata did not contain a valid size.",
        );
      }
      return {
        contentLengthBytes,
        contentType: toOptionalString(metadata.contentType),
        generation: toOptionalString(metadata.generation),
      };
    } catch (error) {
      if (isStorageNotFoundError(error)) {
        throw new HttpsError(
          "failed-precondition",
          "Uploaded replay blob not found at canonical object path.",
        );
      }
      throw error;
    }
  }
}

class CloudTasksRunValidationTaskDispatcher
  implements RunValidationTaskDispatcher
{
  constructor(
    private readonly config: {
      projectId: string;
      location: string;
      queueName: string;
      validatorTaskUrl: string;
    },
    private readonly tasksClient: CloudTasksClient = new CloudTasksClient(),
  ) {}

  async enqueueRunValidationTask(args: { runSessionId: string }): Promise<void> {
    const queuePath = this.tasksClient.queuePath(
      this.config.projectId,
      this.config.location,
      this.config.queueName,
    );
    const taskName = this.tasksClient.taskPath(
      this.config.projectId,
      this.config.location,
      this.config.queueName,
      `run-${sanitizeTaskId(args.runSessionId)}`,
    );
    try {
      await this.tasksClient.createTask({
        parent: queuePath,
        task: {
          name: taskName,
          httpRequest: {
            httpMethod: "POST",
            url: this.config.validatorTaskUrl,
            headers: {
              "Content-Type": "application/json",
            },
            body: Buffer.from(
              JSON.stringify({ runSessionId: args.runSessionId }),
              "utf8",
            ).toString("base64"),
          },
        },
      });
    } catch (error) {
      if (isTaskAlreadyExistsError(error)) {
        return;
      }
      throw error;
    }
  }
}

function sanitizeTaskId(value: string): string {
  return value.replace(/[^a-zA-Z0-9_-]/gu, "_");
}

function createCloudStorageReplaySubmissionObjectStore(): ReplaySubmissionObjectStore {
  const bucketName = requireEnv(
    "REPLAY_STORAGE_BUCKET",
    "REPLAY_STORAGE_BUCKET must be configured for replay submissions.",
  );
  return new CloudStorageReplaySubmissionObjectStore(bucketName);
}

function createCloudTasksRunValidationTaskDispatcher(): RunValidationTaskDispatcher {
  const projectId =
    process.env.GCLOUD_PROJECT?.trim() ??
    process.env.GOOGLE_CLOUD_PROJECT?.trim();
  if (!projectId) {
    throw new HttpsError(
      "failed-precondition",
      "GCLOUD_PROJECT is required to enqueue replay validation tasks.",
    );
  }
  const location = process.env.REPLAY_VALIDATION_QUEUE_LOCATION?.trim() || "europe-west1";
  const queueName = process.env.REPLAY_VALIDATION_QUEUE_NAME?.trim() || "replay-validation";
  const validatorTaskUrl = resolveValidatorTaskUrl();
  return new CloudTasksRunValidationTaskDispatcher({
    projectId,
    location,
    queueName,
    validatorTaskUrl,
  });
}

function resolveValidatorTaskUrl(): string {
  const explicitTaskUrl = process.env.REPLAY_VALIDATOR_TASK_URL?.trim();
  if (explicitTaskUrl) {
    return explicitTaskUrl;
  }
  const baseUrl = process.env.REPLAY_VALIDATOR_URL?.trim();
  if (baseUrl) {
    const trimmed = baseUrl.endsWith("/") ? baseUrl.slice(0, -1) : baseUrl;
    return `${trimmed}/tasks/validate`;
  }
  throw new HttpsError(
    "failed-precondition",
    "REPLAY_VALIDATOR_TASK_URL or REPLAY_VALIDATOR_URL must be configured.",
  );
}

function requireEnv(name: string, message: string): string {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new HttpsError("failed-precondition", message);
  }
  return value;
}

function readBooleanEnv(name: string): boolean | undefined {
  const raw = process.env[name];
  if (raw == null) {
    return undefined;
  }
  const normalized = raw.trim().toLowerCase();
  if (
    normalized === "1" ||
    normalized === "true" ||
    normalized === "yes" ||
    normalized === "on"
  ) {
    return true;
  }
  if (
    normalized === "0" ||
    normalized === "false" ||
    normalized === "no" ||
    normalized === "off"
  ) {
    return false;
  }
  return undefined;
}

function toOptionalString(value: unknown): string | undefined {
  if (value === undefined || value === null) {
    return undefined;
  }
  const parsed = String(value).trim();
  return parsed.length > 0 ? parsed : undefined;
}

function isStorageNotFoundError(error: unknown): boolean {
  if (!error || typeof error !== "object") {
    return false;
  }
  const maybeCode = (error as { code?: unknown }).code;
  if (maybeCode === 404) {
    return true;
  }
  const maybeMessage = (error as { message?: unknown }).message;
  return typeof maybeMessage === "string" && maybeMessage.includes("No such object");
}

function isTaskAlreadyExistsError(error: unknown): boolean {
  if (!error || typeof error !== "object") {
    return false;
  }
  const maybeCode = (error as { code?: unknown }).code;
  if (maybeCode === 6 || maybeCode === "6") {
    return true;
  }
  const maybeMessage = (error as { message?: unknown }).message;
  return (
    typeof maybeMessage === "string" &&
    maybeMessage.toLowerCase().includes("already exists")
  );
}

function toTaskEnqueueHttpsError(error: unknown): HttpsError {
  if (error instanceof HttpsError) {
    return error;
  }
  const message =
    error && typeof error === "object" && "message" in error
      ? String((error as { message?: unknown }).message)
      : String(error);
  return new HttpsError(
    "unavailable",
    `Failed to enqueue replay validation task: ${message}`,
  );
}
