import { CloudTasksClient } from "@google-cloud/tasks";
import {
  type DocumentSnapshot,
  FieldPath,
  type Firestore,
} from "firebase-admin/firestore";

import { enqueueBoardProjectionReconciliation } from "./projection_dispatch.js";

const maintenanceCollection = "system_maintenance";
const maintenanceDocument = "replay_projection_reconciliation";
const boardsCollection = "leaderboard_boards";
const defaultBatchSize = 4;
const maximumBatchSize = 64;
const reconciliationIntervalMs = 60 * 60 * 1000;

export const projectionReconciliationSchedule = "every 60 minutes";

export interface ProjectionReconciliationResult {
  nowMs: number;
  queriedCount: number;
  selectedCount: number;
  enqueuedCount: number;
  completedPage: boolean;
  nextCursor: string | null;
  cursorCommitted: boolean;
  schedule: typeof projectionReconciliationSchedule;
  effectiveBatchSize: number;
}

/** Task boundary used to make cursor advancement testable and all-or-nothing. */
export interface BoardProjectionReconciliationDispatcher {
  enqueue(args: { boardId: string; taskKey: string }): Promise<void>;
}

/**
 * Walks every board through a persisted cursor and enqueues a board-level
 * convergence task. Replaying a page is safe because task ids are stable for
 * the reconciliation time bucket and projection writes are conditional. The
 * default dispatcher owns one Cloud Tasks client for the whole invocation and
 * closes it even when enqueueing fails.
 */
export async function reconcileLeaderboardBoardProjections(args: {
  db: Firestore;
  nowMs?: number;
  batchSize?: number;
  dispatcher?: BoardProjectionReconciliationDispatcher;
  /** Test seam for the one invocation-scoped Cloud Tasks client. */
  createTasksClient?: () => CloudTasksClient;
}): Promise<ProjectionReconciliationResult> {
  const nowMs = args.nowMs ?? Date.now();
  const batchSize = resolveProjectionReconciliationBatchSize(args.batchSize);
  const stateRef = args.db
    .collection(maintenanceCollection)
    .doc(maintenanceDocument);
  const observedState = await stateRef.get();
  const cursor = readCursor(observedState.data()?.cursor);
  let query = args.db
    .collection(boardsCollection)
    .orderBy(FieldPath.documentId())
    .limit(batchSize + 1);
  if (cursor != null) {
    query = query.startAfter(cursor);
  }
  const page = await query.get();
  const selected = page.docs.slice(0, batchSize);
  const completedPage = page.size <= batchSize;
  const nextCursor = completedPage
    ? null
    : (selected.at(-1)?.id ?? null);

  let tasksClient: CloudTasksClient | null = null;
  try {
    const taskKey = `cycle-${Math.floor(nowMs / reconciliationIntervalMs)}`;
    if (selected.length > 0) {
      tasksClient =
        args.dispatcher == null
          ? (args.createTasksClient?.() ?? new CloudTasksClient())
          : null;
      const dispatcher =
        args.dispatcher ??
        {
          enqueue: (enqueueArgs: { boardId: string; taskKey: string }) =>
            enqueueBoardProjectionReconciliation({
              ...enqueueArgs,
              tasksClient: tasksClient!,
            }),
        };
      for (const board of selected) {
        await dispatcher.enqueue({ boardId: board.id, taskKey });
      }
    }

    const cursorCommitted = await args.db.runTransaction(
      async (transaction) => {
        const currentState = await transaction.get(stateRef);
        if (!sameSnapshotVersion(observedState, currentState)) {
          return false;
        }
        transaction.set(
          stateRef,
          {
            cursor: nextCursor,
            updatedAtMs: nowMs,
            queriedCount: page.size,
            selectedCount: selected.length,
            enqueuedCount: selected.length,
            ...(completedPage ? { completedAtMs: nowMs } : {}),
          },
          { merge: true },
        );
        return true;
      },
    );
    return {
      nowMs,
      queriedCount: page.size,
      selectedCount: selected.length,
      enqueuedCount: selected.length,
      completedPage,
      nextCursor,
      cursorCommitted,
      schedule: projectionReconciliationSchedule,
      effectiveBatchSize: batchSize,
    };
  } finally {
    await tasksClient?.close();
  }
}

/** Parses the checked-in release batch policy with a bounded incident override. */
export function parseProjectionReconciliationBatchSize(
  raw: string | undefined,
): number {
  const value = raw?.trim();
  if (!value) {
    return defaultBatchSize;
  }
  return resolveProjectionReconciliationBatchSize(Number(value));
}

function resolveProjectionReconciliationBatchSize(
  value: number | undefined,
): number {
  if (value == null || !Number.isInteger(value) || value <= 0) {
    return defaultBatchSize;
  }
  return Math.min(value, maximumBatchSize);
}

function sameSnapshotVersion(
  observed: DocumentSnapshot,
  current: DocumentSnapshot,
): boolean {
  if (observed.exists !== current.exists) {
    return false;
  }
  if (!observed.exists) {
    return true;
  }
  const observedUpdateTime = observed.updateTime;
  const currentUpdateTime = current.updateTime;
  return (
    observedUpdateTime != null &&
    currentUpdateTime != null &&
    observedUpdateTime.isEqual(currentUpdateTime)
  );
}

function readCursor(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : null;
}
