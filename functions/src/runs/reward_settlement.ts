import type { Firestore } from "firebase-admin/firestore";
import { isDeepStrictEqual } from "node:util";

import {
  canonicalMergeWriteData,
  canonicalWriteData,
  resolveCanonicalStateForTransaction,
} from "../ownership/canonical_store.js";
import { reconcilePendingRewardGrantsForTransaction } from "../ownership/reward_grants.js";

const runSessionsCollection = "run_sessions";
const validatedRunsCollection = "validated_runs";
const rewardGrantsCollection = "reward_grants";

export type AcceptedRunSettlementOutcome =
  | "settled"
  | "already_settled"
  | "not_ready";

/**
 * The only path that turns an accepted reward grant into spendable gold.
 *
 * A validator may establish the accepted run and place the session in
 * settlement_pending, but it never writes the canonical wallet or terminal
 * state. This transaction applies the grant idempotently, records the wallet
 * revision, and exposes validated together.
 */
export async function settleAcceptedRunSession(args: {
  db: Firestore;
  runSessionId: string;
  nowMs?: number;
}): Promise<AcceptedRunSettlementOutcome> {
  const nowMs = args.nowMs ?? Date.now();
  const sessionRef = args.db
    .collection(runSessionsCollection)
    .doc(args.runSessionId);
  const validatedRunRef = args.db
    .collection(validatedRunsCollection)
    .doc(args.runSessionId);
  const rewardGrantRef = args.db
    .collection(rewardGrantsCollection)
    .doc(args.runSessionId);

  return args.db.runTransaction(async (tx) => {
    const [sessionSnapshot, validatedRunSnapshot, rewardGrantSnapshot] =
      await Promise.all([
        tx.get(sessionRef),
        tx.get(validatedRunRef),
        tx.get(rewardGrantRef),
      ]);
    if (!sessionSnapshot.exists) {
      return "not_ready";
    }

    const session = sessionSnapshot.data() as Record<string, unknown>;
    const state = readRequiredString(session.state, "run session state");
    if (state === "validated") {
      return "already_settled";
    }
    if (state !== "settlement_pending") {
      return "not_ready";
    }

    const uid = readRequiredString(session.uid, "run session uid");
    assertAcceptedValidatedRun({
      runSessionId: args.runSessionId,
      uid,
      data: validatedRunSnapshot.data() as Record<string, unknown> | undefined,
      exists: validatedRunSnapshot.exists,
    });
    assertPendingRewardGrant({
      runSessionId: args.runSessionId,
      uid,
      data: rewardGrantSnapshot.data() as Record<string, unknown> | undefined,
      exists: rewardGrantSnapshot.exists,
    });
    assertMatchingSettlementContext({
      runSessionId: args.runSessionId,
      session,
      validatedRun: validatedRunSnapshot.data() as Record<string, unknown>,
      rewardGrant: rewardGrantSnapshot.data() as Record<string, unknown>,
    });

    const resolvedCanonical = await resolveCanonicalStateForTransaction({
      db: args.db,
      tx,
      uid,
    });
    const reconciled = await reconcilePendingRewardGrantsForTransaction({
      db: args.db,
      tx,
      uid,
      canonicalState: resolvedCanonical.canonical,
      nowMs,
      settlementGrantId: args.runSessionId,
    });
    if (resolvedCanonical.exists && reconciled.canonicalChanged) {
      tx.set(
        resolvedCanonical.canonicalRef,
        canonicalMergeWriteData(uid, reconciled.canonicalState),
        { merge: true },
      );
    } else if (!resolvedCanonical.exists) {
      tx.set(
        resolvedCanonical.canonicalRef,
        canonicalWriteData(uid, reconciled.canonicalState),
      );
    }
    tx.set(
      sessionRef,
      {
        state: "validated",
        updatedAtMs: nowMs,
        terminalAtMs: nowMs,
        settledAtMs: nowMs,
        settlementMessage: "Reward settled.",
        message: null,
      },
      { merge: true },
    );
    return "settled";
  });
}

function assertAcceptedValidatedRun(args: {
  runSessionId: string;
  uid: string;
  exists: boolean;
  data: Record<string, unknown> | undefined;
}): void {
  if (!args.exists || !args.data) {
    throw new Error(
      `validated_runs/${args.runSessionId} is required before settlement.`,
    );
  }
  if (args.data.accepted !== true) {
    throw new Error(
      `validated_runs/${args.runSessionId} must be accepted before settlement.`,
    );
  }
  if (readRequiredString(args.data.uid, "validated run uid") !== args.uid) {
    throw new Error(
      `validated_runs/${args.runSessionId} uid does not match the run session.`,
    );
  }
  if (
    readRequiredString(args.data.runSessionId, "validated run session id") !==
    args.runSessionId
  ) {
    throw new Error(
      `validated_runs/${args.runSessionId} has a mismatched runSessionId.`,
    );
  }
}

function assertPendingRewardGrant(args: {
  runSessionId: string;
  uid: string;
  exists: boolean;
  data: Record<string, unknown> | undefined;
}): void {
  if (!args.exists || !args.data) {
    throw new Error(
      `reward_grants/${args.runSessionId} is required before settlement.`,
    );
  }
  if (args.data.lifecycleState !== "settlement_pending") {
    throw new Error(
      `reward_grants/${args.runSessionId} is not settlement_pending.`,
    );
  }
  if (readRequiredString(args.data.uid, "reward grant uid") !== args.uid) {
    throw new Error(
      `reward_grants/${args.runSessionId} uid does not match the run session.`,
    );
  }
  if (
    readRequiredString(args.data.runSessionId, "reward grant run session id") !==
    args.runSessionId
  ) {
    throw new Error(
      `reward_grants/${args.runSessionId} has a mismatched runSessionId.`,
    );
  }
}

function assertMatchingSettlementContext(args: {
  runSessionId: string;
  session: Record<string, unknown>;
  validatedRun: Record<string, unknown>;
  rewardGrant: Record<string, unknown>;
}): void {
  const mode = readRequiredRunMode(args.session.mode, "run session mode");
  if (
    readRequiredRunMode(args.validatedRun.mode, "validated run mode") !== mode ||
    readRequiredRunMode(args.rewardGrant.mode, "reward grant mode") !== mode
  ) {
    throw new Error(
      `run ${args.runSessionId} has mismatched settlement mode context.`,
    );
  }

  const validatedGold = readRequiredNonNegativeInteger(
    args.validatedRun.goldEarned,
    "validated run goldEarned",
  );
  if (
    readRequiredNonNegativeInteger(
      args.rewardGrant.goldAmount,
      "reward grant goldAmount",
    ) !== validatedGold
  ) {
    throw new Error(
      `run ${args.runSessionId} grant gold does not match validated gold.`,
    );
  }

  const boardId = readOptionalNonEmptyString(args.session.boardId);
  const validatedBoardId = readOptionalNonEmptyString(args.validatedRun.boardId);
  const rewardBoardId = readOptionalNonEmptyString(args.rewardGrant.boardId);
  if (boardId !== validatedBoardId || boardId !== rewardBoardId) {
    throw new Error(
      `run ${args.runSessionId} has mismatched settlement board id context.`,
    );
  }
  if (
    !isDeepStrictEqual(args.session.boardKey, args.validatedRun.boardKey) ||
    !isDeepStrictEqual(args.session.boardKey, args.rewardGrant.boardKey)
  ) {
    throw new Error(
      `run ${args.runSessionId} has mismatched settlement board key context.`,
    );
  }

  const requiresBoard = mode !== "practice";
  if (requiresBoard && (boardId == null || args.session.boardKey == null)) {
    throw new Error(
      `run ${args.runSessionId} is board-bound but has no board context.`,
    );
  }
  if (!requiresBoard && (boardId != null || args.session.boardKey != null)) {
    throw new Error(
      `practice run ${args.runSessionId} must not have board context.`,
    );
  }
}

function readRequiredString(value: unknown, fieldName: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error(`${fieldName} must be a non-empty string.`);
  }
  return value.trim();
}

function readOptionalNonEmptyString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function readRequiredRunMode(
  value: unknown,
  fieldName: string,
): "practice" | "competitive" | "weekly" {
  const mode = readRequiredString(value, fieldName);
  if (mode === "practice" || mode === "competitive" || mode === "weekly") {
    return mode;
  }
  throw new Error(`${fieldName} must be a supported run mode.`);
}

function readRequiredNonNegativeInteger(value: unknown, fieldName: string): number {
  if (
    typeof value !== "number" ||
    !Number.isSafeInteger(value) ||
    value < 0
  ) {
    throw new Error(`${fieldName} must be a non-negative safe integer.`);
  }
  return value;
}
