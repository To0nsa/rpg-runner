import type { Firestore, Transaction } from "firebase-admin/firestore";
import type { OwnershipCanonicalState } from "../ownership/contracts.js";

export const runCompletionReceiptsCollection = "run_completion_receipts";

export function runCompletionReceiptRef(db: Firestore, uid: string, runSessionId: string) {
  return db.collection(runCompletionReceiptsCollection).doc(uid)
    .collection("runs").doc(runSessionId);
}

/** Written only in the wallet transaction. No replay, lease, or signing data. */
export function writeRunCompletionReceipt(args: {
  db: Firestore; tx: Transaction; uid: string; runSessionId: string;
  canonical: OwnershipCanonicalState; goldAmount: number; nowMs: number;
}): void {
  args.tx.set(runCompletionReceiptRef(args.db, args.uid, args.runSessionId), {
    schemaVersion: 1, uid: args.uid, runSessionId: args.runSessionId,
    canonicalState: args.canonical,
    submissionStatus: {
      runSessionId: args.runSessionId, state: "validated", updatedAtMs: args.nowMs,
      reward: {
        status: "final", grantId: args.runSessionId,
        provisionalGold: args.goldAmount, effectiveGoldDelta: args.goldAmount,
        spendableGoldDelta: args.goldAmount, updatedAtMs: args.nowMs,
      },
    },
  });
}
