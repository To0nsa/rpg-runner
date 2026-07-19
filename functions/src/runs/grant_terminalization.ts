import type {
  DocumentReference,
  DocumentSnapshot,
  Transaction,
} from "firebase-admin/firestore";

const provisionalGrantStates = new Set([
  "provisional_created",
  "provisional_visible",
]);

/** Writes the terminal expiry and matching provisional-grant revocation. */
export function writeExpiredRunSessionTransition(args: {
  tx: Transaction;
  runSessionRef: DocumentReference;
  rewardGrantRef: DocumentReference;
  rewardGrantSnapshot: DocumentSnapshot;
  nowMs: number;
  message: string;
}): void {
  args.tx.set(
    args.runSessionRef,
    {
      state: "expired",
      updatedAtMs: args.nowMs,
      terminalAtMs: args.nowMs,
      expiredAtMs: args.nowMs,
      message: args.message,
      validationNextAttemptAtMs: null,
    },
    { merge: true },
  );

  if (!args.rewardGrantSnapshot.exists) {
    return;
  }
  const lifecycleState = args.rewardGrantSnapshot.get("lifecycleState");
  if (
    typeof lifecycleState !== "string" ||
    !provisionalGrantStates.has(lifecycleState)
  ) {
    return;
  }
  args.tx.set(
    args.rewardGrantRef,
    {
      lifecycleState: "revoked_final",
      settlementReason: "run_session_expired",
      revokedAtMs: args.nowMs,
      updatedAtMs: args.nowMs,
    },
    { merge: true },
  );
}
