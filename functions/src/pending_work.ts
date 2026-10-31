import { createHash } from "node:crypto";
import type { Firestore } from "firebase-admin/firestore";
import type { TaskOptions } from "firebase-admin/functions";
import { isAccountDeletionInProgressError } from "./account/deletion_guard.js";
import type { AccountDeletionDependencies } from "./account/delete.js";
import type { RunValidationTaskDispatcher } from "./runs/submission_store.js";

export const pendingWorkFunction = "runPendingWork";
export const runRecoveryDelaySeconds = 15 * 60;
export type PendingWork = { kind: "run"; runSessionId: string } |
  { kind: "account"; uid: string };
export interface PendingWorkQueue {
  enqueue(data: PendingWork, options: TaskOptions): Promise<void>;
}

export function parsePendingWork(value: unknown): PendingWork {
  if (!value || typeof value !== "object") throw new Error("Invalid pending work.");
  const data = value as Record<string, unknown>;
  if (data.kind === "run" && validId(data.runSessionId, 200)) {
    return { kind: "run", runSessionId: data.runSessionId };
  }
  if (data.kind === "account" && validId(data.uid, 128)) {
    return { kind: "account", uid: data.uid };
  }
  throw new Error("Invalid pending work.");
}

/** Stable names make repeated Firestore delivery safe. Only an actual duplicate
 * is acknowledged: enqueue outages must propagate to the durable event retry. */
export async function enqueuePendingWork(args: {
  work: PendingWork;
  generation: string;
  delaySeconds?: number;
  queue?: PendingWorkQueue;
}): Promise<void> {
  const work = parsePendingWork(args.work);
  const id = createHash("sha256")
    .update(JSON.stringify([work, args.generation])).digest("hex");
  const queue = args.queue ?? (await import("firebase-admin/functions"))
    .getFunctions().taskQueue<PendingWork>(
      `locations/${process.env.FUNCTIONS_REGION?.trim() || "europe-west1"}/functions/${pendingWorkFunction}`,
    );
  try {
    await queue.enqueue(work, { id, scheduleDelaySeconds: args.delaySeconds ?? 0,
      dispatchDeadlineSeconds: 120 });
  } catch (error) {
    if ((error as { code?: unknown })?.code !== "functions/task-already-exists") throw error;
  }
}

/** Task retries retain responsibility until the durable domain state is done.
 * Bounded pages avoid holding an instance while a lease or quiet period expires. */
export async function processPendingWork(args: {
  db: Firestore;
  work: PendingWork;
  nowMs?: number;
  elapsedClock?: () => number;
  validationDispatcher?: RunValidationTaskDispatcher;
  deletionDependencies?: AccountDeletionDependencies;
}): Promise<"complete" | "pending" | "quarantined"> {
  const work = parsePendingWork(args.work);
  const nowMs = args.nowMs ?? Date.now();
  if (work.kind === "account") {
    const initial = await args.db.doc(`account_deletion_requests/${work.uid}`).get();
    if (!initial.exists || initial.get("state") === "complete") return "complete";
    const { processAccountDeletion } = await import("./account/delete.js");
    const clock = args.elapsedClock ?? (() => performance.now());
    const start = clock();
    for (let step = 0; step < 32 && clock() - start < 40_000; step += 1) {
      const result = await processAccountDeletion({ db: args.db, uid: work.uid,
        nowMs: args.nowMs ?? Date.now(), dependencies: args.deletionDependencies });
      if (result.status === "deleted") return "complete";
      if (!result.processed || !result.madeProgress || result.status === "retryable" ||
          result.stage === "quiet_wait") break;
    }
    return "pending";
  }

  const ref = args.db.doc(`run_sessions/${work.runSessionId}`);
  const session = await ref.get();
  if (!session.exists) return "complete";
  const state = session.get("state");
  if (!["uploaded", "pending_validation", "validating", "settlement_pending"].includes(state)) {
    return "complete";
  }
  const uid = session.get("uid");
  if (typeof uid !== "string" || !validId(uid, 128)) throw new Error("Invalid run owner.");
  if ((await args.db.doc(`account_deletion_requests/${uid}`).get()).exists) return "complete";
  try {
    if (state === "settlement_pending") {
      if (session.get("settlementRepairDisposition") === "quarantined") return "quarantined";
      const { settleAcceptedRunSession } = await import("./runs/reward_settlement.js");
      const result = await settleAcceptedRunSession({ db: args.db,
        runSessionId: work.runSessionId, nowMs, deliverySource: "repair" });
      if (result === "invariant_violation") {
        const { quarantineSettlementIncident } = await import("./runs/settlement_repair.js");
        await quarantineSettlementIncident({ db: args.db, runSessionId: work.runSessionId, nowMs });
        return "quarantined";
      }
      return result === "not_ready" ? "pending" : "complete";
    }
    const { repairRunValidation } = await import("./runs/validation_repair.js");
    await repairRunValidation({ db: args.db, runSessionId: work.runSessionId,
      nowMs, dispatcher: args.validationDispatcher });
    return "pending";
  } catch (error) {
    if (isAccountDeletionInProgressError(error)) return "complete";
    throw error;
  }
}

function validId(value: unknown, maxLength: number): value is string {
  return typeof value === "string" && value.length > 0 && value.length <= maxLength &&
    !value.includes("/") && value !== "." && value !== "..";
}
