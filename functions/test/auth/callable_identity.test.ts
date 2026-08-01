import assert from "node:assert/strict";
import test from "node:test";

import { HttpsError } from "firebase-functions/v2/https";

import {
  requirePlayGamesCallableUser,
  requireRecentPlayGamesAuthentication,
} from "../../src/auth/callable_identity.js";

const recentAuth = {
  uid: "uid_play_games",
  token: {
    auth_time: 1_000,
    firebase: {
      identities: {
        "playgames.google.com": ["player-id"],
      },
    },
  },
};

test("requires a linked Play Games identity for app callables", () => {
  assert.equal(requirePlayGamesCallableUser(recentAuth), "uid_play_games");

  assertHttpsError(
    () => requirePlayGamesCallableUser({ uid: "uid_without_provider", token: {} }),
    "permission-denied",
  );
  assertHttpsError(() => requirePlayGamesCallableUser(undefined), "unauthenticated");
});

test("requires a recent authentication event for account deletion", () => {
  assert.equal(
    requireRecentPlayGamesAuthentication({
      auth: recentAuth,
      nowMs: 1_300_000,
    }),
    "uid_play_games",
  );

  assertHttpsError(
    () =>
      requireRecentPlayGamesAuthentication({
        auth: recentAuth,
        nowMs: 1_300_001,
      }),
    "failed-precondition",
  );
  assertHttpsError(
    () =>
      requireRecentPlayGamesAuthentication({
        auth: {
          ...recentAuth,
          token: {
            ...recentAuth.token,
            auth_time: undefined,
          },
        },
        nowMs: 1_000_000,
      }),
    "failed-precondition",
  );
});

function assertHttpsError(action: () => unknown, expectedCode: string): void {
  assert.throws(action, (error: unknown) => {
    return error instanceof HttpsError && error.code === expectedCode;
  });
}
