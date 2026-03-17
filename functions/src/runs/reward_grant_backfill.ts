import type { Firestore } from "firebase-admin/firestore";

export interface RewardGrantBackfillOptions {
  nowMs?: number;
  maxDocs?: number;
  dryRun?: boolean;
  writeBatchSize?: number;
}

export interface RewardGrantBackfillResult {
  nowMs: number;
  scannedCount: number;
  updatedCount: number;
  mappedPendingToProvisionalCreated: number;
  mappedAppliedToValidatedSettled: number;
  mappedAppliedToRevocationVisible: number;
  skippedAlreadyLifecycleState: number;
  skippedNonLegacyState: number;
  skippedLegacyWithoutSignal: number;
}

export async function backfillLegacyRewardGrantStates(args: {
  db: Firestore;
  options?: RewardGrantBackfillOptions;
}): Promise<RewardGrantBackfillResult> {
  void args;
  throw new Error(
    "legacy reward_grant backfill has been retired; no backfill path remains.",
  );
}