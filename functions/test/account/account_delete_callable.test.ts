import assert from "node:assert/strict";
import { after, beforeEach, test } from "node:test";

import { deleteApp, getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, type Firestore } from "firebase-admin/firestore";

import { deleteAccountAndData } from "../../src/account/delete.js";
import { parseAccountDeleteRequest } from "../../src/account/validators.js";
import { canonicalDocRef } from "../../src/ownership/firestore_paths.js";
import { updatePlayerProfile } from "../../src/profile/store.js";

const firestoreEmulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
if (!firestoreEmulatorHost) {
  throw new Error(
    "FIRESTORE_EMULATOR_HOST is not set. Run via `firebase emulators:exec`.",
  );
}

const emulatorProjectIdBase =
  process.env.GCLOUD_PROJECT ?? "demo-rpg-runner-functions-tests";
const projectId = `${emulatorProjectIdBase}-account`;
const appName = `account-delete-tests-${process.pid}-${Date.now()}`;
const app = initializeApp({ projectId }, appName);
const db = getFirestore(app);

beforeEach(async () => {
  await Promise.all([
    clearCollection(db, "ownership_profiles"),
    clearCollection(db, "player_profiles"),
    clearCollection(db, "display_name_index"),
    clearCollection(db, "ghost_runs"),
    clearCollection(db, "leaderboard_ghost_runs"),
    clearCollection(db, "weekly_ghost_runs"),
  ]);
});

after(async () => {
  await Promise.all(getApps().map((value) => deleteApp(value)));
});

test("parseAccountDeleteRequest validates required fields", () => {
  const parsed = parseAccountDeleteRequest({
    userId: "u1",
    sessionId: "s1",
  });
  assert.equal(parsed.userId, "u1");
  assert.equal(parsed.sessionId, "s1");
});

test("deleteAccountAndData removes UID-scoped profile, ownership, and ghost data", async () => {
  const uid = "uid_delete_target";
  const profileId = "profile_a";
  const otherUid = "uid_keep";
  const otherProfileId = "profile_other";

  await updatePlayerProfile({
    db,
    uid,
    displayName: "Delete Me",
    displayNameLastChangedAtMs: 100,
  });
  await updatePlayerProfile({
    db,
    uid: otherUid,
    displayName: "Keep Me",
    displayNameLastChangedAtMs: 101,
  });

  const targetOwnershipRef = canonicalDocRef(db, uid, profileId);
  await targetOwnershipRef.set({
    uid,
    profileId,
    revision: 1,
    selection: { selectedCharacterId: "eloise" },
    meta: { schemaVersion: 1 },
  });
  await targetOwnershipRef.collection("idempotency").doc("cmd_1").set({
    payloadHash: "abc",
    result: { rejectedReason: null },
  });

  const targetOwnershipRef2 = canonicalDocRef(db, uid, "profile_b");
  await targetOwnershipRef2.set({
    uid,
    profileId: "profile_b",
    revision: 2,
    selection: { selectedCharacterId: "nyra" },
    meta: { schemaVersion: 1 },
  });
  await targetOwnershipRef2.collection("idempotency").doc("cmd_2").set({
    payloadHash: "def",
    result: { rejectedReason: null },
  });

  const otherOwnershipRef = canonicalDocRef(db, otherUid, otherProfileId);
  await otherOwnershipRef.set({
    uid: otherUid,
    profileId: otherProfileId,
    revision: 1,
    selection: { selectedCharacterId: "eloise" },
    meta: { schemaVersion: 1 },
  });

  await db.collection("run_sessions").doc("run_target").set({
    uid,
    runSessionId: "run_target",
    state: "issued",
  });
  await db.collection("run_sessions").doc("run_other").set({
    uid: otherUid,
    runSessionId: "run_other",
    state: "issued",
  });

  await db.collection("ghost_runs").doc("g1").set({ uid, runId: "r1" });
  await db
    .collection("leaderboard_ghost_runs")
    .doc("g2")
    .set({ userId: uid, runId: "r2" });
  await db
    .collection("weekly_ghost_runs")
    .doc("g3")
    .set({ ownerUid: uid, runId: "r3" });
  await db.collection("ghost_runs").doc("g_other").set({ uid: otherUid });

  let deletedAuthUid = "";
  const result = await deleteAccountAndData({
    db,
    uid,
    deleteAuthUser: async (value) => {
      deletedAuthUid = value;
    },
  });

  assert.equal(result.status, "deleted");
  assert.equal(deletedAuthUid, uid);
  assert.equal(result.deleted.profileDocs, 1);
  assert.equal(result.deleted.displayNameIndexDocs, 1);
  assert.equal(result.deleted.ownershipDocs, 2);
  assert.equal(result.deleted.runSessionDocs, 1);
  assert.equal(result.deleted.ghostDocs, 3);

  assert.equal((await db.collection("player_profiles").doc(uid).get()).exists, false);
  assert.equal(
    (await db.collection("display_name_index").where("uid", "==", uid).get()).size,
    0,
  );
  assert.equal((await targetOwnershipRef.get()).exists, false);
  assert.equal((await targetOwnershipRef2.get()).exists, false);
  assert.equal((await db.collection("ghost_runs").doc("g1").get()).exists, false);
  assert.equal(
    (await db.collection("leaderboard_ghost_runs").doc("g2").get()).exists,
    false,
  );
  assert.equal(
    (await db.collection("weekly_ghost_runs").doc("g3").get()).exists,
    false,
  );
  assert.equal((await db.collection("run_sessions").doc("run_target").get()).exists, false);

  assert.equal((await db.collection("player_profiles").doc(otherUid).get()).exists, true);
  assert.equal((await otherOwnershipRef.get()).exists, true);
  assert.equal((await db.collection("ghost_runs").doc("g_other").get()).exists, true);
  assert.equal((await db.collection("run_sessions").doc("run_other").get()).exists, true);
});

test("deleteAccountAndData tolerates already-missing auth user", async () => {
  const uid = "uid_missing_auth";
  await db.collection("ghost_runs").doc("g1").set({ uid });

  const result = await deleteAccountAndData({
    db,
    uid,
    deleteAuthUser: async () => {
      const error = new Error("not found") as Error & { code?: string };
      error.code = "auth/user-not-found";
      throw error;
    },
  });

  assert.equal(result.status, "deleted");
  assert.equal((await db.collection("ghost_runs").doc("g1").get()).exists, false);
});

async function clearCollection(dbValue: Firestore, name: string): Promise<void> {
  const docs = await dbValue.collection(name).listDocuments();
  await Promise.all(docs.map((docRef) => dbValue.recursiveDelete(docRef)));
}
