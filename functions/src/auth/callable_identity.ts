import { HttpsError } from "firebase-functions/v2/https";

export const playGamesProviderId = "playgames.google.com";
export const recentAuthenticationMaxAgeMs = 5 * 60 * 1000;

interface FirebaseTokenClaimsLike {
  auth_time?: unknown;
  firebase?: {
    identities?: Record<string, unknown>;
  };
}

export interface CallableAuthLike {
  uid?: string;
  token?: FirebaseTokenClaimsLike;
}

/**
 * Returns the authenticated UID only when the Firebase account is linked to
 * Google Play Games. Linked identities are used instead of the last sign-in
 * provider so a guest upgraded in place keeps the same account authority.
 */
export function requirePlayGamesCallableUser(
  auth: CallableAuthLike | null | undefined,
): string {
  const uid = auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const identities = auth.token?.firebase?.identities;
  const playGamesIdentities = identities?.[playGamesProviderId];
  if (
    !Array.isArray(playGamesIdentities) ||
    !playGamesIdentities.some(
      (identity) => typeof identity === "string" && identity.trim().length > 0,
    )
  ) {
    throw new HttpsError(
      "permission-denied",
      "A linked Google Play Games identity is required.",
    );
  }
  return uid;
}

/**
 * Requires an authentication event within the recent-authentication window.
 * Token refreshes retain `auth_time`, so they cannot extend this window.
 */
export function requireRecentPlayGamesAuthentication(args: {
  auth: CallableAuthLike | null | undefined;
  nowMs: number;
  maximumAgeMs?: number;
}): string {
  const uid = requirePlayGamesCallableUser(args.auth);
  const maximumAgeMs = args.maximumAgeMs ?? recentAuthenticationMaxAgeMs;
  const authTimeSeconds = args.auth?.token?.auth_time;
  const authTimeMs =
    typeof authTimeSeconds === "number" && Number.isFinite(authTimeSeconds)
      ? authTimeSeconds * 1000
      : Number.NaN;
  const ageMs = args.nowMs - authTimeMs;
  if (
    !Number.isSafeInteger(authTimeMs) ||
    ageMs < 0 ||
    ageMs > maximumAgeMs
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Recent Google Play Games authentication is required.",
      { reason: "recent-auth-required" },
    );
  }
  return uid;
}
