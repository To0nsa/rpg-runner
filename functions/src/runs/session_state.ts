export const runSessionStates = [
  "issued",
  "uploading",
  "uploaded",
  "pending_validation",
  "validating",
  "settlement_pending",
  "validated",
  "rejected",
  "expired",
  "cancelled",
  "internal_error",
] as const;

export const defaultValidationLeaseDurationMs = 10 * 60 * 1000;
export const defaultValidationRepairStaleThresholdMs = 15 * 60 * 1000;
export const defaultValidationRepairReenqueueCooldownMs = 15 * 60 * 1000;

export type RunSessionState = (typeof runSessionStates)[number];

export function isRunSessionState(value: unknown): value is RunSessionState {
  if (typeof value !== "string") {
    return false;
  }
  return (runSessionStates as readonly string[]).includes(value);
}

export function isTerminalRunSessionState(state: RunSessionState): boolean {
  switch (state) {
    case "validated":
    case "rejected":
    case "expired":
    case "cancelled":
    case "internal_error":
      return true;
    default:
      return false;
  }
}
