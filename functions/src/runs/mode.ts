import { HttpsError } from "firebase-functions/v2/https";

export const runModes = ["practice", "competitive", "weekly"] as const;
export type RunModeValue = (typeof runModes)[number];

export function parseRunMode(
  value: unknown,
  fieldName: string,
): RunModeValue {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${fieldName} must be a string`);
  }
  if (!runModes.includes(value as RunModeValue)) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} must be one of: ${runModes.join("|")}.`,
    );
  }
  return value as RunModeValue;
}

export function runModeRequiresBoard(mode: RunModeValue): boolean {
  return mode !== "practice";
}

