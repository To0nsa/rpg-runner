import * as logger from "firebase-functions/logger";

/** Identifies the server delivery path that invoked canonical settlement. */
export type SettlementDeliverySource =
  | "immediate"
  | "eventarc"
  | "repair"
  | "legacy_migration";

/**
 * Emits the stable, privacy-safe fields used by the settlement log metrics.
 *
 * The run-session id is an operational correlation key; no player uid, replay
 * payload, or client-provided message is included in these events.
 */
export function logSettlementMetric(args: {
  event: string;
  runSessionId?: string;
  deliverySource?: SettlementDeliverySource;
  outcome?: string;
  durationMs?: number;
  transactionAttempts?: number;
  pendingAgeMs?: number;
  errorClass?: string;
  scannedCount?: number;
  settledCount?: number;
  invariantViolationCount?: number;
  classifiedCount?: number;
  quarantinedCount?: number;
  failureCount?: number;
  retryablePendingCount?: number;
  oldestRetryableAgeMs?: number;
  pageCursor?: string;
  noProgress?: boolean;
}): void {
  logger.info("run_settlement", {
    metricVersion: 1,
    ...args,
  });
}

/** Returns a bounded error category suitable for logs and metric labels. */
export function settlementErrorClass(error: unknown): string {
  if (error instanceof Error && error.name.trim().length > 0) {
    return error.name.trim();
  }
  return "UnknownError";
}
