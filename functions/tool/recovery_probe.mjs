#!/usr/bin/env node
// A real managed-restore probe, confined to empty, named synthetic dev databases.
// It invokes the production settlement/deletion guard instead of duplicating them.
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { createRequire } from "node:module";
import { settleAcceptedRunSession } from "../lib/runs/reward_settlement.js";
import { loadOrCreateCanonicalState } from "../lib/ownership/canonical_store.js";
import { assertAccountActive } from "../lib/account/deletion_guard.js";

const [action, projectId, databaseId] = process.argv.slice(2);
if (process.argv.length !== 5 || !["seed", "verify"].includes(action) ||
    projectId !== "rpg-runner-d7add" || !/^beta-recovery-[a-z0-9-]+$/.test(databaseId)) {
  throw new Error("Usage: recovery_probe.mjs seed|verify rpg-runner-d7add beta-recovery-<id>");
}
if (process.env.FIRESTORE_EMULATOR_HOST) throw new Error("Live restore probe must not target an emulator.");
process.env.GOOGLE_CLOUD_QUOTA_PROJECT = projectId;
process.env.LEGACY_READ_RECONCILIATION_ENABLED = "false";
// Reuse the locked Admin SDK's Firestore/auth dependencies. The operator's ADC
// may belong to another account; use the explicitly authenticated Cloud SDK
// identity without copying its credential store or creating a service-account key.
const adminRequire = createRequire(import.meta.resolve("firebase-admin/firestore"));
const firestoreRequire = createRequire(adminRequire.resolve("@google-cloud/firestore"));
const transportRequire = createRequire(firestoreRequire.resolve("google-gax"));
const { Firestore } = adminRequire("@google-cloud/firestore");
const { OAuth2Client } = transportRequire("google-auth-library");
const token = execFileSync(process.platform === "win32" ? "powershell.exe" : "gcloud",
  process.platform === "win32" ? ["-NoProfile", "-Command", "gcloud auth print-access-token"] :
    ["auth", "print-access-token"], { encoding: "utf8", windowsHide: true }).trim();
const authClient = new OAuth2Client();
// This short probe cannot refresh a CLI access token. Disable eager refresh;
// obtain a fresh token for each invocation and let the server enforce expiry.
authClient.eagerRefreshThresholdMillis = 0;
authClient.setCredentials({ access_token: token, expiry_date: Date.now() + 300000 });
const db = new Firestore({ projectId, databaseId, authClient });
const uid = "synthetic-recovery-player";
const deletedUid = "synthetic-deleted-player";
const runSessionId = "synthetic-recovery-run";
try {
  if (action === "seed") {
    assert.equal((await db.listCollections()).length, 0, "Seed database must be empty");
    const nowMs = Date.now();
    const batch = db.batch();
    batch.create(db.doc(`run_sessions/${runSessionId}`), {
      runSessionId, uid, state: "settlement_pending", mode: "practice",
      expiresAtMs: nowMs + 3600000, updatedAtMs: nowMs,
    });
    batch.create(db.doc(`validated_runs/${runSessionId}`), {
      runSessionId, uid, mode: "practice", accepted: true, goldEarned: 75,
    });
    batch.create(db.doc(`reward_grants/${runSessionId}`), {
      runSessionId, uid, mode: "practice", lifecycleState: "settlement_pending",
      goldAmount: 75, createdAtMs: nowMs, updatedAtMs: nowMs,
    });
    batch.create(db.doc(`account_deletion_requests/${deletedUid}`), {
      uid: deletedUid, state: "completed", completedAtMs: nowMs,
    });
    await batch.commit();
    assert.equal(await settleAcceptedRunSession({ db, runSessionId, nowMs }), "settled");
  }
  const before = await loadOrCreateCanonicalState({ db, uid, reconcileLegacyRewards: false });
  assert.equal(before.progression.gold, 75);
  assert.equal(before.revision, 1);
  assert.deepEqual(before.progression.appliedRewardGrantIds, [runSessionId]);
  assert.equal(await settleAcceptedRunSession({ db, runSessionId }), "already_settled");
  const after = await loadOrCreateCanonicalState({ db, uid, reconcileLegacyRewards: false });
  assert.deepEqual(after, before, "Duplicate settlement after recovery must not change the wallet");
  await assert.rejects(assertAccountActive(db, deletedUid), error =>
    error.code === "failed-precondition" && error.details?.reason === "account-deletion-in-progress");
  assert.equal((await db.collection("ownership_profiles").where("uid", "==", deletedUid).get()).size, 0);
  console.log(JSON.stringify({ projectId, databaseId, action, checkedAt: new Date().toISOString(),
    gold: 75, revision: 1, duplicateSettlement: "already_settled", deletionBarrier: "enforced",
    limitation: "Synthetic named database only; Auth, objects, queues and full service recovery are not cloned." }));
} catch (error) {
  // SDK failures may embed request metadata; retain only a non-sensitive code.
  const text = String(error.details ?? error.message ?? "");
  const categories = ["refresh", "metadata", "credential", "quota", "permission", "getRequestHeaders", "getUniverseDomain", "getProjectId", "No access", "invalid_grant"]
    .filter(category => text.toLowerCase().includes(category.toLowerCase()));
  const methodFailure = text.match(/\b([a-zA-Z_][\w.]*) is not a function\b/)?.[1] ?? "";
  console.error(`Recovery probe failed: ${error.code ?? error.name ?? "unknown"}; categories=${categories.join(",")}; method=${methodFailure}`);
  process.exitCode = 1;
} finally { await db.terminate(); }
