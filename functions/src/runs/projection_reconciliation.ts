import { CloudTasksClient } from "@google-cloud/tasks";
import {
  FieldPath,
  type Firestore,
} from "firebase-admin/firestore";

import { enqueueBoardProjectionReconciliation } from "./projection_dispatch.js";

const maintenanceCollection = "system_maintenance";
const maintenanceDocument = "replay_projection_reconciliation";
const boardsCollection = "leaderboard_boards";
const defaultBatchSize = 64;
const reconciliationIntervalMs = 15 * 60 * 1000;

export interface ProjectionReconciliationResult {
  nowMs: number;
  scannedCount: number;
  enqueuedCount: number;
  completedPage: boolean;
  nextCursor: string | null;
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
  const batchSize =
    args.batchSize != null && Number.isInteger(args.batchSize) && args.batchSize > 0
      ? args.batchSize
      : defaultBatchSize;
  const stateRef = args.db
    .collection(maintenanceCollection)
    .doc(maintenanceDocument);
  const state = await stateRef.get();
  const cursor = readCursor(state.data()?.cursor);
  let query = args.db
    .collection(boardsCollection)
    .orderBy(FieldPath.documentId())
    .limit(batchSize);
  if (cursor != null) {
    query = query.startAfter(cursor);
  }
  const page = await query.get();
  if (page.empty && cursor != null) {
    await stateRef.set(
      {
        cursor: null,
        updatedAtMs: nowMs,
        completedAtMs: nowMs,
      },
      { merge: true },
    );
    return {
      nowMs,
      scannedCount: 0,
      enqueuedCount: 0,
      completedPage: true,
      nextCursor: null,
    };
  }

  const tasksClient =
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
  try {
    const taskKey = `cycle-${Math.floor(nowMs / reconciliationIntervalMs)}`;
    for (const board of page.docs) {
      await dispatcher.enqueue({ boardId: board.id, taskKey });
    }

    const completedPage = page.size < batchSize;
    const nextCursor = completedPage
      ? null
      : (page.docs.at(-1)?.id ?? null);
    await stateRef.set(
      {
        cursor: nextCursor,
        updatedAtMs: nowMs,
        scannedCount: page.size,
        enqueuedCount: page.size,
        ...(completedPage ? { completedAtMs: nowMs } : {}),
      },
      { merge: true },
    );
    return {
      nowMs,
      scannedCount: page.size,
      enqueuedCount: page.size,
      completedPage,
      nextCursor,
    };
  } finally {
    await tasksClient?.close();
  }
}

function readCursor(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : null;
}
