import assert from "node:assert/strict";
import { after, beforeEach, test } from "node:test";

import { deleteApp, getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, type Firestore } from "firebase-admin/firestore";

import {
  appCheckCallableOptions,
  appCheckRolloutMode,
} from "../../src/abuse/app_check.js";
import {
  assertCallablePayloadBounds,
} from "../../src/abuse/payload_bounds.js";
import {
  cleanupExpiredAbuseQuota,
  consumeUserQuota,
  defaultAbuseQuotaConfiguration,
  defaultRunActiveSessionsLimit,
  defaultRunActiveUploadGrantsLimit,
  readAbuseControlMode,
  readOptionalBoundedAbuseLimit,
  resolveAbuseQuotaPolicy,
  type AbuseQuotaPolicy,
} from "../../src/abuse/quota.js";
import { parseExecuteCommandRequest } from "../../src/ownership/validators.js";

const firestoreEmulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
if (!firestoreEmulatorHost) {
  throw new Error(
    "FIRESTORE_EMULATOR_HOST is not set. Run via `firebase emulators:exec`.",
  );
}

const emulatorProjectIdBase =
  process.env.GCLOUD_PROJECT ?? "demo-rpg-runner-functions-tests";
const projectId = `${emulatorProjectIdBase}-abuse-controls`;
const appName = `abuse-controls-${process.pid}-${Date.now()}`;
const app = initializeApp({ projectId }, appName);
const db = getFirestore(app);

beforeEach(async () => {
  await Promise.all([
    clearCollection(db, "abuse_quota"),
    clearCollection(db, "account_deletion_requests"),
  ]);
});

after(async () => {
  await Promise.all(getApps().map((value) => deleteApp(value)));
});

test("App Check defaults to monitoring and rejects invalid rollout modes", () => {
  assert.equal(appCheckRolloutMode(undefined), "monitor");
  assert.equal(appCheckRolloutMode("monitor"), "monitor");
  assert.equal(appCheckRolloutMode("enforce"), "enforce");
  assert.deepEqual(appCheckCallableOptions("monitor"), {
    enforceAppCheck: false,
    consumeAppCheckToken: false,
  });
  assert.deepEqual(appCheckCallableOptions("enforce"), {
    enforceAppCheck: true,
    consumeAppCheckToken: false,
  });
  assert.throws(() => appCheckRolloutMode("enabled"), /APP_CHECK_ROLLOUT_MODE/);
});

test("reviewed production quota defaults resolve for every protected route", () => {
  for (const [route, expected] of Object.entries(
    defaultAbuseQuotaConfiguration,
  )) {
    const policy = resolveAbuseQuotaPolicy(
      route as AbuseQuotaPolicy["route"],
      {},
    );
    assert.equal(policy.mode, "monitor");
    assert.deepEqual(policy.windows, [
      {
        name: "burst",
        durationMs: expected.burstWindowMs,
        limit: expected.burstLimit,
      },
      {
        name: "sustained",
        durationMs: expected.sustainedWindowMs,
        limit: expected.sustainedLimit,
      },
    ]);
  }
  assert.equal(defaultRunActiveSessionsLimit, 32);
  assert.equal(defaultRunActiveUploadGrantsLimit, 8);
  assert.equal(readAbuseControlMode(undefined), "monitor");
  assert.equal(readAbuseControlMode("enforce"), "enforce");
  assert.throws(() => readAbuseControlMode("enabled"), /ABUSE_CONTROL_MODE/);
});

test("payload bounds reject oversized and deeply nested JSON", () => {
  assert.doesNotThrow(() =>
    assertCallablePayloadBounds({
      userId: "uid_1",
      command: {
        payload: {
          items: ["one", "two"],
        },
      },
    }),
  );
  assert.throws(
    () =>
      assertCallablePayloadBounds({
        value: "x".repeat(2_049),
      }),
    (error: { code?: string }) => error.code === "invalid-argument",
  );

  let nested: Record<string, unknown> = {};
  const root = nested;
  for (let depth = 0; depth < 10; depth += 1) {
    const child: Record<string, unknown> = {};
    nested.child = child;
    nested = child;
  }
  assert.throws(
    () => assertCallablePayloadBounds(root),
    (error: { code?: string }) => error.code === "invalid-argument",
  );
});

test("payload bounds reject non-JSON objects", () => {
  const nonJsonValues = [
    new Date(),
    new Map([["key", "value"]]),
    new Set([1]),
  ];
  for (const value of nonJsonValues) {
    assert.throws(
      () => assertCallablePayloadBounds({ value }),
      (error: { code?: string }) => error.code === "invalid-argument",
    );
  }
});

test("ownership command IDs have bounded backend-safe format", () => {
  const valid = {
    command: {
      type: "setProjectileSpell",
      userId: "uid_1",
      sessionId: "session_1",
      expectedRevision: 0,
      commandId: "cmd_valid-1:retry",
      payload: {},
    },
  };
  assert.equal(
    parseExecuteCommandRequest(valid).command.commandId,
    "cmd_valid-1:retry",
  );
  for (const commandId of ["x".repeat(97), "cmd/invalid"]) {
    assert.throws(
      () =>
        parseExecuteCommandRequest({
          command: {
            ...valid.command,
            commandId,
          },
        }),
      (error: { code?: string }) => error.code === "invalid-argument",
    );
  }
});

test("monitoring mode records usage without inventing an enforcement limit", async () => {
  const nowMs = 1_700_000_000_000;
  const decision = await consumeUserQuota({
    db,
    uid: "uid_monitor",
    route: "run_create",
    nowMs,
    policy: policy({
      route: "run_create",
      mode: "monitor",
    }),
  });

  assert.equal(decision.accepted, true);
  assert.equal(decision.wouldReject, false);
  assert.deepEqual(decision.limits, {
    burst: null,
    sustained: null,
  });
  const stored = (
    await db.collection("abuse_quota").doc("uid_monitor").get()
  ).data();
  assert.equal(stored?.expiresAtMs, nowMs + 86_400_000 + 86_400_000);
});

test("atomic concurrent quota requests cannot exceed enforcement limit", async () => {
  const quotaPolicy = policy({
    route: "ownership_command",
    mode: "enforce",
    burstLimit: 3,
    sustainedLimit: 10,
  });
  const results = await Promise.allSettled(
    Array.from({ length: 10 }, () =>
      consumeUserQuota({
        db,
        uid: "uid_concurrent",
        route: "ownership_command",
        nowMs: 1_700_000_000_000,
        policy: quotaPolicy,
      }),
    ),
  );

  assert.equal(
    results.filter((result) => result.status === "fulfilled").length,
    3,
  );
  assert.equal(
    results.filter(
      (result) =>
        result.status === "rejected" &&
        (result.reason as { code?: string }).code === "resource-exhausted",
    ).length,
    7,
  );
  const stored = (
    await db.collection("abuse_quota").doc("uid_concurrent").get()
  ).data();
  assert.equal(stored?.counters?.ownership_command_burst?.count, 10);
});

test("account deletion requests remain rate limited after their tombstone exists", async () => {
  await db.collection("account_deletion_requests").doc("uid_deleting").set({
    uid: "uid_deleting",
    state: "in_progress",
  });

  await assert.doesNotReject(() =>
    consumeUserQuota({
      db,
      uid: "uid_deleting",
      route: "account_delete",
      nowMs: 1_700_000_000_000,
      allowAccountDeletionRequest: true,
      policy: policy({
        route: "account_delete",
        mode: "enforce",
        burstLimit: 1,
        sustainedLimit: 1,
      }),
    }),
  );
  await assert.rejects(
    () =>
      consumeUserQuota({
        db,
        uid: "uid_deleting",
        route: "profile_read",
        allowAccountDeletionRequest: true,
        policy: policy({
          route: "profile_read",
          mode: "monitor",
        }),
      }),
    /Only the account_delete quota route/,
  );
});

test("reviewed run-create burst remains atomic under concurrent load", async () => {
  const quotaPolicy = resolveAbuseQuotaPolicy("run_create", {
    ABUSE_CONTROL_MODE: "enforce",
  });
  const attempts = defaultAbuseQuotaConfiguration.run_create.burstLimit * 2;
  const results: PromiseSettledResult<unknown>[] = [];
  for (let offset = 0; offset < attempts; offset += 5) {
    const wave = await Promise.allSettled(
      Array.from({ length: Math.min(5, attempts - offset) }, () =>
        consumeUserQuota({
          db,
          uid: "uid_reviewed_concurrent",
          route: "run_create",
          nowMs: 1_700_000_000_000,
          policy: quotaPolicy,
        }),
      ),
    );
    results.push(...wave);
  }

  assert.equal(
    results.filter((result) => result.status === "fulfilled").length,
    defaultAbuseQuotaConfiguration.run_create.burstLimit,
  );
  assert.equal(
    results.filter(
      (result) =>
        result.status === "rejected" &&
        (result.reason as { code?: string }).code === "resource-exhausted",
    ).length,
    defaultAbuseQuotaConfiguration.run_create.burstLimit,
  );
  const stored = (
    await db.collection("abuse_quota").doc("uid_reviewed_concurrent").get()
  ).data();
  assert.equal(stored?.counters?.run_create_burst?.count, attempts);
});

test("reviewed replay-byte burst permits four maximum replays and rejects five", async () => {
  const quotaPolicy = resolveAbuseQuotaPolicy("finalize_replay_bytes", {
    ABUSE_CONTROL_MODE: "enforce",
  });
  const maxReplayBytes = 8 * 1024 * 1024;
  for (let attempt = 0; attempt < 4; attempt += 1) {
    await consumeUserQuota({
      db,
      uid: "uid_reviewed_replay_bytes",
      route: "finalize_replay_bytes",
      units: maxReplayBytes,
      nowMs: 1_700_000_000_000,
      policy: quotaPolicy,
    });
  }
  await assert.rejects(
    () =>
      consumeUserQuota({
        db,
        uid: "uid_reviewed_replay_bytes",
        route: "finalize_replay_bytes",
        units: maxReplayBytes,
        nowMs: 1_700_000_000_000,
        policy: quotaPolicy,
      }),
    (error: { code?: string }) => error.code === "resource-exhausted",
  );
});

test("enforcement fails closed when any configured window lacks a limit", async () => {
  await assert.rejects(
    () =>
      consumeUserQuota({
        db,
        uid: "uid_missing_limit",
        route: "ghost_url",
        policy: policy({
          route: "ghost_url",
          mode: "enforce",
          burstLimit: 1,
        }),
      }),
    (error: { code?: string }) => error.code === "failed-precondition",
  );
});

test("malformed configured limits cannot silently weaken enforcement", async () => {
  const env = {
    ABUSE_CONTROL_MODE: "enforce",
    ABUSE_RUN_CREATE_BURST_LIMIT: "10requests",
    ABUSE_RUN_CREATE_SUSTAINED_LIMIT: "100",
    ABUSE_RUN_ACTIVE_SESSIONS_LIMIT: "256sessions",
  };
  assert.throws(
    () =>
      resolveAbuseQuotaPolicy("run_create", env),
    (error: { code?: string }) => error.code === "failed-precondition",
  );
  assert.throws(
    () =>
      readOptionalBoundedAbuseLimit({
        envName: "ABUSE_RUN_ACTIVE_SESSIONS_LIMIT",
        max: 256,
        env,
      }),
    (error: { code?: string }) => error.code === "failed-precondition",
  );
});

test("monitoring logs malformed optional limits without blocking traffic", () => {
  const actual = readOptionalBoundedAbuseLimit({
    envName: "ABUSE_RUN_ACTIVE_UPLOAD_GRANTS_LIMIT",
    max: 128,
    env: {
      ABUSE_CONTROL_MODE: "monitor",
      ABUSE_RUN_ACTIVE_UPLOAD_GRANTS_LIMIT: "129",
    },
  });
  assert.equal(actual, undefined);
  const resolved = resolveAbuseQuotaPolicy("run_create", {
    ABUSE_CONTROL_MODE: "monitor",
    ABUSE_RUN_CREATE_BURST_LIMIT: "20requests",
  });
  assert.equal(
    resolved.windows[0]?.limit,
    defaultAbuseQuotaConfiguration.run_create.burstLimit,
  );
});

test("quota retention cleanup deletes only expired bounded state", async () => {
  await Promise.all([
    db.collection("abuse_quota").doc("expired").set({
      uid: "expired",
      expiresAtMs: 99,
    }),
    db.collection("abuse_quota").doc("future").set({
      uid: "future",
      expiresAtMs: 101,
    }),
  ]);

  const result = await cleanupExpiredAbuseQuota({
    db,
    nowMs: 100,
    batchSize: 10,
  });

  assert.deepEqual(result, { scanned: 1, deleted: 1 });
  assert.equal(
    (await db.collection("abuse_quota").doc("expired").get()).exists,
    false,
  );
  assert.equal(
    (await db.collection("abuse_quota").doc("future").get()).exists,
    true,
  );
});

function policy(args: {
  route: AbuseQuotaPolicy["route"];
  mode: AbuseQuotaPolicy["mode"];
  burstLimit?: number;
  sustainedLimit?: number;
}): AbuseQuotaPolicy {
  return {
    route: args.route,
    mode: args.mode,
    windows: [
      {
        name: "burst",
        durationMs: 60_000,
        limit: args.burstLimit,
      },
      {
        name: "sustained",
        durationMs: 86_400_000,
        limit: args.sustainedLimit,
      },
    ],
  };
}

async function clearCollection(dbValue: Firestore, name: string): Promise<void> {
  const docs = await dbValue.collection(name).listDocuments();
  await Promise.all(docs.map((docRef) => dbValue.recursiveDelete(docRef)));
}
