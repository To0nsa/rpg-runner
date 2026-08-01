import type { Firestore } from "firebase-admin/firestore";
import { isDeepStrictEqual } from "node:util";

import { assertAccountActiveInTransaction } from "../account/deletion_guard.js";
import {
  canonicalMergeWriteData,
  canonicalWriteData,
  resolveCanonicalStateForTransaction,
} from "../ownership/canonical_store.js";
import {
  reconcilePendingRewardGrantsForTransaction,
  RewardGrantInvariantViolationError,
} from "../ownership/reward_grants.js";
import {
  logSettlementMetric,
  settlementErrorClass,
  type SettlementDeliverySource,
} from "./settlement_metrics.js";

const runSessionsCollection = "run_sessions";
const validatedRunsCollection = "validated_runs";
const rewardGrantsCollection = "reward_grants";

export type AcceptedRunSettlementOutcome =
  | "settled"
  | "already_settled"
  | "not_ready"
  | "invariant_violation";

/**
 * Marks malformed or contradictory persisted reward data as non-retryable.
 *
 * Delivery may be duplicated, but retrying a stable document invariant cannot
 * repair it and would hide an operator-visible incident behind trigger retries.
 */
export class SettlementInvariantViolationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "SettlementInvariantViolationError";
  }
}

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
  deliverySource?: SettlementDeliverySource;
}): Promise<AcceptedRunSettlementOutcome> {
  const nowMs = args.nowMs ?? Date.now();
  const startedAtMs = Date.now();
  const deliverySource = args.deliverySource ?? "immediate";
  let pendingAgeMs: number | undefined;
  let transactionAttempts = 0;
  const sessionRef = args.db
    .collection(runSessionsCollection)
    .doc(args.runSessionId);
  const validatedRunRef = args.db
    .collection(validatedRunsCollection)
    .doc(args.runSessionId);
  const rewardGrantRef = args.db
    .collection(rewardGrantsCollection)
    .doc(args.runSessionId);

  try {
    const outcome = await args.db.runTransaction(async (tx) => {
      transactionAttempts += 1;
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
      if (state !== "validated" && state !== "settlement_pending") {
        return "not_ready";
      }
      const uid = readRequiredString(session.uid, "run session uid");
      await assertAccountActiveInTransaction(tx, args.db, uid);
      if (state === "validated") {
        assertAcceptedValidatedRun({
          runSessionId: args.runSessionId,
          uid,
          data: validatedRunSnapshot.data() as Record<string, unknown> | undefined,
          exists: validatedRunSnapshot.exists,
        });
        assertSettledRewardGrant({
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
        assertCanonicalAppliedGrant({
          runSessionId: args.runSessionId,
          canonical: resolvedCanonical.canonical,
        });
        return "already_settled";
      }
      pendingAgeMs = durationSinceMs(session.settlementPendingAtMs, nowMs);

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
    logSettlementMetric({
      event: "settlement_transaction",
      runSessionId: args.runSessionId,
      deliverySource,
      outcome,
      durationMs: Date.now() - startedAtMs,
      pendingAgeMs,
      transactionAttempts,
    });
    return outcome;
  } catch (error) {
    if (
      error instanceof SettlementInvariantViolationError ||
      error instanceof RewardGrantInvariantViolationError
    ) {
      logSettlementMetric({
        event: "settlement_transaction",
        runSessionId: args.runSessionId,
        deliverySource,
        outcome: "invariant_violation",
        durationMs: Date.now() - startedAtMs,
        pendingAgeMs,
        transactionAttempts,
        errorClass: settlementErrorClass(error),
      });
      return "invariant_violation";
    }
    logSettlementMetric({
      event: "settlement_transaction_failure",
      runSessionId: args.runSessionId,
      deliverySource,
      durationMs: Date.now() - startedAtMs,
      transactionAttempts,
      errorClass: settlementErrorClass(error),
    });
    throw error;
  }
}

function assertAcceptedValidatedRun(args: {
  runSessionId: string;
  uid: string;
  exists: boolean;
  data: Record<string, unknown> | undefined;
}): void {
  if (!args.exists || !args.data) {
    throw new SettlementInvariantViolationError(
      `validated_runs/${args.runSessionId} is required before settlement.`,
    );
  }
  if (args.data.accepted !== true) {
    throw new SettlementInvariantViolationError(
      `validated_runs/${args.runSessionId} must be accepted before settlement.`,
    );
  }
  if (readRequiredString(args.data.uid, "validated run uid") !== args.uid) {
    throw new SettlementInvariantViolationError(
      `validated_runs/${args.runSessionId} uid does not match the run session.`,
    );
  }
  if (
    readRequiredString(args.data.runSessionId, "validated run session id") !==
    args.runSessionId
  ) {
    throw new SettlementInvariantViolationError(
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
    throw new SettlementInvariantViolationError(
      `reward_grants/${args.runSessionId} is required before settlement.`,
    );
  }
  if (args.data.lifecycleState !== "settlement_pending") {
    throw new SettlementInvariantViolationError(
      `reward_grants/${args.runSessionId} is not settlement_pending.`,
    );
  }
  if (readRequiredString(args.data.uid, "reward grant uid") !== args.uid) {
    throw new SettlementInvariantViolationError(
      `reward_grants/${args.runSessionId} uid does not match the run session.`,
    );
  }
  if (
    readRequiredString(args.data.runSessionId, "reward grant run session id") !==
    args.runSessionId
  ) {
    throw new SettlementInvariantViolationError(
      `reward_grants/${args.runSessionId} has a mismatched runSessionId.`,
    );
  }
}

function assertSettledRewardGrant(args: {
  runSessionId: string;
  uid: string;
  exists: boolean;
  data: Record<string, unknown> | undefined;
}): void {
  if (!args.exists || !args.data) {
    throw new SettlementInvariantViolationError(
      `reward_grants/${args.runSessionId} is required for a validated run.`,
    );
  }
  if (args.data.lifecycleState !== "validated_settled") {
    throw new SettlementInvariantViolationError(
      `reward_grants/${args.runSessionId} is not validated_settled for a validated run.`,
    );
  }
  if (readRequiredString(args.data.uid, "reward grant uid") !== args.uid) {
    throw new SettlementInvariantViolationError(
      `reward_grants/${args.runSessionId} uid does not match the run session.`,
    );
  }
  if (
    readRequiredString(args.data.runSessionId, "reward grant run session id") !==
    args.runSessionId
  ) {
    throw new SettlementInvariantViolationError(
      `reward_grants/${args.runSessionId} has a mismatched runSessionId.`,
    );
  }
}

function assertCanonicalAppliedGrant(args: {
  runSessionId: string;
  canonical: { progression: Record<string, unknown> };
}): void {
  const appliedRewardGrantIds = args.canonical.progression.appliedRewardGrantIds;
  if (
    !Array.isArray(appliedRewardGrantIds) ||
    !appliedRewardGrantIds.includes(args.runSessionId)
  ) {
    throw new SettlementInvariantViolationError(
      `validated run ${args.runSessionId} is missing its canonical applied reward grant id.`,
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
    throw new SettlementInvariantViolationError(
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
    throw new SettlementInvariantViolationError(
      `run ${args.runSessionId} grant gold does not match validated gold.`,
    );
  }

  const boardId = readOptionalNonEmptyString(args.session.boardId);
  const validatedBoardId = readOptionalNonEmptyString(args.validatedRun.boardId);
  const rewardBoardId = readOptionalNonEmptyString(args.rewardGrant.boardId);
  if (boardId !== validatedBoardId || boardId !== rewardBoardId) {
    throw new SettlementInvariantViolationError(
      `run ${args.runSessionId} has mismatched settlement board id context.`,
    );
  }
  if (
    !isDeepStrictEqual(args.session.boardKey, args.validatedRun.boardKey) ||
    !isDeepStrictEqual(args.session.boardKey, args.rewardGrant.boardKey)
  ) {
    throw new SettlementInvariantViolationError(
      `run ${args.runSessionId} has mismatched settlement board key context.`,
    );
  }

  const requiresBoard = mode !== "practice";
  if (requiresBoard && (boardId == null || args.session.boardKey == null)) {
    throw new SettlementInvariantViolationError(
      `run ${args.runSessionId} is board-bound but has no board context.`,
    );
  }
  if (!requiresBoard && (boardId != null || args.session.boardKey != null)) {
    throw new SettlementInvariantViolationError(
      `practice run ${args.runSessionId} must not have board context.`,
    );
  }
}

function readRequiredString(value: unknown, fieldName: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new SettlementInvariantViolationError(
      `${fieldName} must be a non-empty string.`,
    );
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
  throw new SettlementInvariantViolationError(
    `${fieldName} must be a supported run mode.`,
  );
}

function readRequiredNonNegativeInteger(value: unknown, fieldName: string): number {
  if (
    typeof value !== "number" ||
    !Number.isSafeInteger(value) ||
    value < 0
  ) {
    throw new SettlementInvariantViolationError(
      `${fieldName} must be a non-negative safe integer.`,
    );
  }
  return value;
}

function durationSinceMs(value: unknown, nowMs: number): number | undefined {
  if (
    typeof value !== "number" ||
    !Number.isSafeInteger(value) ||
    value <= 0
  ) {
    return undefined;
  }
  return Math.max(0, nowMs - value);
}
