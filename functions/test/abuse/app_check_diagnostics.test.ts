import assert from "node:assert/strict";
import { test } from "node:test";

import { appCheckObservation } from "../../src/abuse/app_check.js";
import { parseExecuteCommandRequest } from "../../src/ownership/validators.js";
import { parseRunSessionCreateRequest } from "../../src/runs/validators.js";
import { parseLoadPlayerProfileRequest } from "../../src/profile/validators.js";

function requestWithToken(token?: string) {
  return {
    auth: { uid: "private-user-id" },
    rawRequest: {
      get: (name: string) => name === "X-Firebase-AppCheck" ? token
        : name === "User-Agent" ? "okhttp/4.12.0" : undefined,
    },
  };
}

test("distinguishes absent, Android placeholder, malformed and rejected JWT headers", () => {
  for (const [token, failure] of [
    [undefined, "missing_token"],
    ["", "missing_token"],
    ["eyJlcnJvciI6IlVOS05PV05fRVJST1IifQ==", "android_sdk_placeholder"],
    ["eyJlcnJvciI6IlVOS05PV05fRVJST1IifQ", "android_sdk_placeholder"],
    ["private-broken-token", "malformed_token"],
    ["private.header.signature", "jwt_rejected"],
  ]) {
    const diagnostic = appCheckObservation(requestWithToken(token));
    assert.equal(diagnostic.tokenFailure, failure);
    assert.equal(diagnostic.authStatus, "authenticated");
    assert.equal(diagnostic.clientTransportHint, "okhttp");
    assert.equal(diagnostic.tokenStatus, "missing_or_invalid");
    assert.ok(diagnostic.nextAction.length > 10);
    assert.ok(!JSON.stringify(diagnostic).includes("private"));
  }
});

test("only verified SDK context establishes app identity and verification", () => {
  const data = { clientDiagnostics: {
    appId: "1:123:android:abcdef", tokenStatus: "verified",
    platform: "android", buildMode: "release", provider: "play_integrity",
  } };
  const unverified = appCheckObservation({ ...requestWithToken(), data });
  assert.equal(unverified.tokenStatus, "missing_or_invalid");
  assert.equal(unverified.appId, undefined);
  assert.equal(unverified.clientReported?.appId, "1:123:android:abcdef");
  assert.match(unverified.nextAction, /SHA-256/);
  const verified = appCheckObservation({
    ...requestWithToken(), data,
    app: { appId: "trusted-app-id", alreadyConsumed: false },
  });
  assert.equal(verified.appId, "trusted-app-id");
  assert.equal(verified.tokenFailure, "none");
  assert.equal(verified.nextAction, "none");
});

test("debug failures have actionable registration guidance without leaking arbitrary metadata", () => {
  const diagnostic = appCheckObservation({
    ...requestWithToken("private-secret"),
    data: { clientDiagnostics: {
      platform: "android", buildMode: "debug", provider: "debug",
      tokenAcquisition: "failed", failureReason: "attestation_rejected",
      token: "private-secret", message: "private-message", uid: "private-uid",
      appId: "private-invalid-app-id", extra: { secret: "private" },
    } },
  });
  assert.match(diagnostic.nextAction, /debug token/);
  assert.equal(diagnostic.clientReported?.failureReason, "attestation_rejected");
  assert.ok(!JSON.stringify(diagnostic).includes("private"));
});

test("malformed diagnostic payloads are ignored before domain validation", () => {
  for (const data of [null, [], "text", 3, { clientDiagnostics: [] },
    { clientDiagnostics: { provider: "x".repeat(100_000), platform: {} } }]) {
    const diagnostic = appCheckObservation({ data });
    assert.equal(diagnostic.clientReported, undefined);
    assert.equal(diagnostic.authStatus, "unauthenticated");
  }
});

test("network and quota evidence is not mislabeled as a registration failure", () => {
  for (const [failureReason, expected] of [
    ["network_error", /connectivity/], ["rate_limited", /backoff/],
  ] as const) {
    const diagnostic = appCheckObservation({
      data: { clientDiagnostics: { provider: "debug", failureReason } },
    });
    assert.match(diagnostic.nextAction, expected);
  }
});

test("diagnostics never enter parsed command, profile or run authority inputs", () => {
  const clientDiagnostics = {
    platform: "android", buildMode: "debug", provider: "debug",
    tokenAcquisitionScope: "startup", tokenAcquisition: "failed",
    failureReason: "attestation_rejected", appId: "1:123:android:abcdef",
  };
  const ownership = { command: {
    type: "setProjectileSpell", userId: "uid_1", sessionId: "session_1",
    expectedRevision: 0, commandId: "cmd_valid-1", payload: {},
  } };
  const profile = { userId: "uid_1", sessionId: "session_1" };
  const run = {
    ...profile, clientRequestId: "run-1", mode: "practice",
    levelId: "forest", gameCompatVersion: "2026.10.21",
  };
  assert.deepEqual(parseExecuteCommandRequest({ ...ownership, clientDiagnostics }),
    parseExecuteCommandRequest(ownership));
  assert.deepEqual(parseLoadPlayerProfileRequest({ ...profile, clientDiagnostics }),
    parseLoadPlayerProfileRequest(profile));
  assert.deepEqual(parseRunSessionCreateRequest({ ...run, clientDiagnostics }),
    parseRunSessionCreateRequest(run));
  assert.throws(() => parseRunSessionCreateRequest({
    ...run, clientDiagnostics: { token: "x".repeat(2049) },
  }), /2048/);
});
