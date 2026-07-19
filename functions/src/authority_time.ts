import { HttpsError } from "firebase-functions/v2/https";

export type AuthorityClock = () => number;

export const systemAuthorityClock: AuthorityClock = () => Date.now();

export function captureAuthorityTimeMs(clock: AuthorityClock): number {
  const value = clock();
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new Error("Authority clock must return a positive safe integer.");
  }
  return value;
}

export function rejectClientAuthorityTime(
  data: Record<string, unknown>,
): void {
  if (Object.hasOwn(data, "nowMs")) {
    throw new HttpsError(
      "invalid-argument",
      "nowMs is server-controlled and must not be supplied.",
    );
  }
}
