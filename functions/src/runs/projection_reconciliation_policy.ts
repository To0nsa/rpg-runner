// Registration-time policy stays independent of queue clients and domain workers.
const defaultBatchSize = 4;
const maximumBatchSize = 64;
export const projectionReconciliationSchedule = "every 60 minutes";

/** Parses the checked-in release batch policy with a bounded incident override. */
export function parseProjectionReconciliationBatchSize(
  raw: string | undefined,
): number {
  const value = raw?.trim();
  if (!value) {
    return defaultBatchSize;
  }
  return resolveProjectionReconciliationBatchSize(Number(value));
}

export function resolveProjectionReconciliationBatchSize(
  value: number | undefined,
): number {
  if (value == null || !Number.isInteger(value) || value <= 0) {
    return defaultBatchSize;
  }
  return Math.min(value, maximumBatchSize);
}
