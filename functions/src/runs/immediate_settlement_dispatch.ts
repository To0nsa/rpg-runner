import type { Firestore } from "firebase-admin/firestore";

import {
  settleAcceptedRunSession,
  type AcceptedRunSettlementOutcome,
} from "./reward_settlement.js";

export class ImmediateSettlementDispatchRequestError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ImmediateSettlementDispatchRequestError";
  }
}

/**
 * Invokes the canonical settlement transaction for a validator-owned handoff.
 *
 * The caller supplies only the run-session id. The transaction loads and
 * verifies all reward data from Firestore, so this dispatch path cannot award
 * a client-provided amount or create a second payout authority.
 */
export async function dispatchImmediateSettlement(args: {
  db: Firestore;
  data: unknown;
}): Promise<{
  runSessionId: string;
  outcome: AcceptedRunSettlementOutcome;
}> {
  const runSessionId = parseImmediateSettlementRunSessionId(args.data);
  const outcome = await settleAcceptedRunSession({
    db: args.db,
    runSessionId,
    deliverySource: "immediate",
  });
  return { runSessionId, outcome };
}

export function parseImmediateSettlementRunSessionId(data: unknown): string {
  if (data === null || typeof data !== "object" || Array.isArray(data)) {
    throw new ImmediateSettlementDispatchRequestError(
      "Expected a JSON object with runSessionId.",
    );
  }
  const raw = (data as Record<string, unknown>).runSessionId;
  if (typeof raw !== "string" || raw.trim().length === 0) {
    throw new ImmediateSettlementDispatchRequestError(
      "runSessionId must be a non-empty string.",
    );
  }
  return raw.trim();
}
