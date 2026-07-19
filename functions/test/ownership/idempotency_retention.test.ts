import assert from "node:assert/strict";
import { after, beforeEach, test } from "node:test";

import { deleteApp, getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, type Firestore } from "firebase-admin/firestore";

import {
  loadOrCreateCanonicalState,
  ownershipIdempotencyRetentionMs,
  ownershipIdempotencySchemaVersion,
  ownershipOfflineRetryWindowMs,
} from "../../src/ownership/canonical_store.js";
import { executeOwnershipCommand } from "../../src/ownership/command_executor.js";
import type {
  OwnershipCanonicalState,
  OwnershipCommandEnvelope,
} from "../../src/ownership/contracts.js";
import { maintainOwnershipIdempotencyRetention } from "../../src/ownership/idempotency_retention.js";

const firestoreEmulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
if (!firestoreEmulatorHost) {
  throw new Error(
    "FIRESTORE_EMULATOR_HOST is not set. Run via `firebase emulators:exec`.",
  );
}

const emulatorProjectIdBase =
  process.env.GCLOUD_PROJECT ?? "demo-rpg-runner-functions-tests";
const projectId = `${emulatorProjectIdBase}-idempotency-retention`;
const appName = `idempotency-retention-${process.pid}-${Date.now()}`;
const app = initializeApp({ projectId }, appName);
const db = getFirestore(app);
const uid = "uid_idempotency_retention";

beforeEach(async () => {
  await Promise.all([
    clearCollection(db, "ownership_profiles"),
    clearCollection(db, "maintenance_state"),
    clearCollection(db, "account_deletion_requests"),
  ]);
});

after(async () => {
  await Promise.all(getApps().map((value) => deleteApp(value)));
});

test("new idempotency records are compact and outlive offline retry", async () => {
  const nowMs = 1_700_000_000_000;
  const command = projectileCommand("cmd_compact", 0);
  const first = await executeOwnershipCommand({
    db,
    uid,
    command,
    nowMs,
  });
  const replay = await executeOwnershipCommand({
    db,
    uid,
    command,
    nowMs: nowMs + 1,
  });

  assert.equal(first.rejectedReason, null);
  assert.equal(replay.replayedFromIdempotency, true);
  assert.equal(replay.newRevision, first.newRevision);
  const canonicalRef = await canonicalDocRef(db, uid);
  const stored = (
    await canonicalRef.collection("idempotency").doc(command.commandId).get()
  ).data();
  assert.equal(stored?.schemaVersion, ownershipIdempotencySchemaVersion);
  assert.equal(stored?.result, undefined);
  assert.deepEqual(stored?.outcome, {
    resultingRevision: first.newRevision,
    rejectedReason: null,
  });
  assert.equal(
    stored?.expiresAtMs,
    nowMs + ownershipIdempotencyRetentionMs,
  );
  assert.ok(
    ownershipIdempotencyRetentionMs > ownershipOfflineRetryWindowMs,
  );
});

test("legacy full-state records are compacted by a resumable bounded scan", async () => {
  const canonical = await loadOrCreateCanonicalState({ db, uid });
  const canonicalRef = await canonicalDocRef(db, uid);
  await canonicalRef.collection("idempotency").doc("legacy_command").set({
    payloadHash: "a".repeat(64),
    result: {
      canonicalState: canonical,
      newRevision: canonical.revision,
      replayedFromIdempotency: false,
      rejectedReason: "staleRevision",
    },
  });

  const first = await maintainOwnershipIdempotencyRetention({
    db,
    nowMs: 1_000,
    batchSize: 1,
  });
  assert.equal(first.migrationScanned, 1);
  assert.equal(first.migrationCompacted, 1);
  assert.equal(first.migrationCompleted, false);
  const second = await maintainOwnershipIdempotencyRetention({
    db,
    nowMs: 1_001,
    batchSize: 1,
  });
  assert.equal(second.migrationCompleted, true);

  const compacted = (
    await canonicalRef.collection("idempotency").doc("legacy_command").get()
  ).data();
  assert.equal(compacted?.result, undefined);
  assert.equal(compacted?.schemaVersion, ownershipIdempotencySchemaVersion);
  assert.deepEqual(compacted?.outcome, {
    resultingRevision: canonical.revision,
    rejectedReason: "staleRevision",
  });
});

test("expired idempotency cleanup is bounded and keeps future records", async () => {
  const canonical = await loadOrCreateCanonicalState({ db, uid });
  const canonicalRef = await canonicalDocRef(db, uid);
  await Promise.all([
    seedCompactIdempotency(canonicalRef, "expired", canonical, 99),
    seedCompactIdempotency(canonicalRef, "future", canonical, 101),
  ]);

  const result = await maintainOwnershipIdempotencyRetention({
    db,
    nowMs: 100,
    batchSize: 10,
  });

  assert.equal(result.expiredDeleted, 1);
  assert.equal(
    (await canonicalRef.collection("idempotency").doc("expired").get()).exists,
    false,
  );
  assert.equal(
    (await canonicalRef.collection("idempotency").doc("future").get()).exists,
    true,
  );
});

function projectileCommand(
  commandId: string,
  expectedRevision: number,
): OwnershipCommandEnvelope {
  return {
    type: "setProjectileSpell",
    userId: uid,
    sessionId: "session_1",
    expectedRevision,
    commandId,
    payload: {
      characterId: "eloise",
      spellId: "holyBolt",
    },
  };
}

async function canonicalDocRef(dbValue: Firestore, uidValue: string) {
  const snapshot = await dbValue
    .collection("ownership_profiles")
    .where("uid", "==", uidValue)
    .limit(1)
    .get();
  assert.equal(snapshot.size, 1);
  return snapshot.docs[0]!.ref;
}

function seedCompactIdempotency(
  canonicalRef: FirebaseFirestore.DocumentReference,
  commandId: string,
  canonical: OwnershipCanonicalState,
  expiresAtMs: number,
): Promise<FirebaseFirestore.WriteResult> {
  return canonicalRef.collection("idempotency").doc(commandId).set({
    payloadHash: commandId.padEnd(64, "a"),
    schemaVersion: ownershipIdempotencySchemaVersion,
    outcome: {
      resultingRevision: canonical.revision,
      rejectedReason: "staleRevision",
    },
    createdAtMs: 1,
    expiresAtMs,
  });
}

async function clearCollection(dbValue: Firestore, name: string): Promise<void> {
  const docs = await dbValue.collection(name).listDocuments();
  await Promise.all(docs.map((docRef) => dbValue.recursiveDelete(docRef)));
}
