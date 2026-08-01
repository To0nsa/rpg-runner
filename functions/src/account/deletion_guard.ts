import type {
  Firestore,
  Transaction,
} from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

export const accountDeletionRequestsCollection =
  "account_deletion_requests";

export async function assertAccountActive(
  db: Firestore,
  uid: string,
): Promise<void> {
  const snapshot = await accountDeletionRequestRef(db, uid).get();
  if (snapshot.exists) {
    throwAccountDeletionInProgress();
  }
}

export async function assertAccountActiveInTransaction(
  tx: Transaction,
  db: Firestore,
  uid: string,
): Promise<void> {
  const snapshot = await tx.get(accountDeletionRequestRef(db, uid));
  if (snapshot.exists) {
    throwAccountDeletionInProgress();
  }
}

export function accountDeletionRequestRef(db: Firestore, uid: string) {
  return db.collection(accountDeletionRequestsCollection).doc(uid);
}

/** Returns whether a worker failure is the expected deletion write barrier. */
export function isAccountDeletionInProgressError(error: unknown): boolean {
  if (!(error instanceof HttpsError) || error.code !== "failed-precondition") {
    return false;
  }
  const details = error.details;
  return (
    details !== null &&
    typeof details === "object" &&
    (details as { reason?: unknown }).reason === "account-deletion-in-progress"
  );
}

function throwAccountDeletionInProgress(): never {
  throw new HttpsError(
    "failed-precondition",
    "Account deletion has been requested; account data access is disabled.",
    { reason: "account-deletion-in-progress" },
  );
}
