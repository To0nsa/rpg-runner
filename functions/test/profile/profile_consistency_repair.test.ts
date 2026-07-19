import assert from "node:assert/strict";
import { after, beforeEach, test } from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { getFirestore, type Firestore } from "firebase-admin/firestore";

import { repairProfileConsistency } from "../../src/profile/consistency_repair.js";

const firestoreEmulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
if (!firestoreEmulatorHost) {
  throw new Error(
    "FIRESTORE_EMULATOR_HOST is not set. Run via `firebase emulators:exec`.",
  );
}

const emulatorProjectIdBase =
  process.env.GCLOUD_PROJECT ?? "demo-rpg-runner-functions-tests";
const projectId = `${emulatorProjectIdBase}-profile-consistency`;
const app = initializeApp(
  { projectId },
  `profile-consistency-tests-${process.pid}-${Date.now()}`,
);
const db = getFirestore(app);

beforeEach(async () => {
  await Promise.all([
    clearCollection(db, "player_profiles"),
    clearCollection(db, "display_name_index"),
    clearCollection(db, "system_maintenance"),
  ]);
});

after(async () => {
  await deleteApp(app);
});

test("repair creates a missing claim and canonicalizes metadata", async () => {
  await db.collection("player_profiles").doc("uid_alpha").set({
    uid: "uid_alpha",
    displayName: "Alpha Name",
    displayNameNormalized: "wrong",
  });

  const result = await repairProfileConsistency({ db, batchSize: 10 });

  assert.equal(result.missingClaimRepairedCount, 1);
  assert.equal(
    (await db.collection("display_name_index").doc("alpha name").get()).data()
      ?.uid,
    "uid_alpha",
  );
  assert.equal(
    (await db.collection("player_profiles").doc("uid_alpha").get()).data()
      ?.displayNameNormalized,
    "alpha name",
  );
});

test("repair removes an index claim whose owner profile is absent", async () => {
  await db.collection("display_name_index").doc("orphan").set({
    uid: "uid_missing",
    displayName: "Orphan",
    displayNameNormalized: "orphan",
  });

  const result = await repairProfileConsistency({ db, batchSize: 10 });

  assert.equal(result.orphanClaimRemovedCount, 1);
  assert.equal(
    (await db.collection("display_name_index").doc("orphan").get()).exists,
    false,
  );
});

test("repair never steals a valid claim from another UID", async () => {
  await db.collection("player_profiles").doc("uid_owner").set({
    uid: "uid_owner",
    displayName: "Shared Name",
    displayNameNormalized: "shared name",
  });
  await db.collection("player_profiles").doc("uid_conflict").set({
    uid: "uid_conflict",
    displayName: "shared   name",
  });
  await db.collection("display_name_index").doc("shared name").set({
    uid: "uid_owner",
    displayName: "Shared Name",
    displayNameNormalized: "shared name",
  });

  const result = await repairProfileConsistency({ db, batchSize: 10 });

  assert.equal(result.conflictingClaimCount, 1);
  assert.equal(
    (await db.collection("display_name_index").doc("shared name").get()).data()
      ?.uid,
    "uid_owner",
  );
});

test("a later sweep claims a name after its orphan entry is removed", async () => {
  await db.collection("player_profiles").doc("uid_waiting").set({
    uid: "uid_waiting",
    displayName: "Recovered",
  });
  await db.collection("display_name_index").doc("recovered").set({
    uid: "uid_missing",
    displayName: "Recovered",
    displayNameNormalized: "recovered",
  });

  const first = await repairProfileConsistency({ db, batchSize: 10 });
  assert.equal(first.conflictingClaimCount, 1);
  assert.equal(first.orphanClaimRemovedCount, 1);

  const second = await repairProfileConsistency({ db, batchSize: 10 });
  assert.equal(second.missingClaimRepairedCount, 1);
  assert.equal(
    (await db.collection("display_name_index").doc("recovered").get()).data()
      ?.uid,
    "uid_waiting",
  );
});

test("bounded repair persists and wraps independent scan cursors", async () => {
  for (const uid of ["uid_a", "uid_b", "uid_c"]) {
    await db.collection("player_profiles").doc(uid).set({
      uid,
      displayName: uid,
    });
  }

  const first = await repairProfileConsistency({ db, batchSize: 2 });
  assert.equal(first.profileScannedCount, 2);
  assert.equal(first.profileCursor, "uid_b");

  const second = await repairProfileConsistency({ db, batchSize: 2 });
  assert.equal(second.profileScannedCount, 1);
  assert.equal(second.profileCursor, null);

  const third = await repairProfileConsistency({ db, batchSize: 2 });
  assert.equal(third.profileScannedCount, 2);
  assert.equal(third.profileCursor, "uid_b");
});

async function clearCollection(
  dbValue: Firestore,
  collectionPath: string,
): Promise<void> {
  const docs = await dbValue.collection(collectionPath).listDocuments();
  await Promise.all(docs.map((doc) => doc.delete()));
}
