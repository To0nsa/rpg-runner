import { getAuth } from "firebase-admin/auth";
import type {
  CollectionReference,
  DocumentReference,
  Firestore,
} from "firebase-admin/firestore";

import { canonicalDocRef } from "../ownership/firestore_paths.js";
import { normalizeDisplayNameForPolicy } from "../profile/validators.js";

const playerProfilesCollection = "player_profiles";
const displayNameIndexCollection = "display_name_index";
const ownershipProfilesCollection = "ownership_profiles";

/**
 * Keep this list explicit until ghost storage schema is finalized.
 * These are safe to query because deletes are always scoped by UID fields.
 */
const ghostCollectionSpecs: readonly GhostCollectionSpec[] = [
  { collection: "ghost_runs", uidFields: ["uid", "userId", "ownerUid"] },
  {
    collection: "leaderboard_ghost_runs",
    uidFields: ["uid", "userId", "ownerUid"],
  },
  {
    collection: "weekly_ghost_runs",
    uidFields: ["uid", "userId", "ownerUid"],
  },
];

interface GhostCollectionSpec {
  collection: string;
  uidFields: readonly string[];
}

export interface AccountDeleteResult {
  status: "deleted";
  deleted: {
    profileDocs: number;
    displayNameIndexDocs: number;
    ownershipDocs: number;
    ghostDocs: number;
  };
}

interface AccountDeleteArgs {
  db: Firestore;
  uid: string;
  profileId: string;
  deleteAuthUser?: (uid: string) => Promise<void>;
}

interface AccountDeleteCounters {
  profileDocs: number;
  displayNameIndexDocs: number;
  ownershipDocs: number;
  ghostDocs: number;
}

interface PlayerProfileDocument {
  uid?: unknown;
  displayName?: unknown;
  displayNameNormalized?: unknown;
}

interface DisplayNameIndexDocument {
  uid?: unknown;
}

export async function deleteAccountAndData(
  args: AccountDeleteArgs,
): Promise<AccountDeleteResult> {
  const counters: AccountDeleteCounters = {
    profileDocs: 0,
    displayNameIndexDocs: 0,
    ownershipDocs: 0,
    ghostDocs: 0,
  };
  const deleteAuthUser = args.deleteAuthUser ?? defaultDeleteAuthUser;

  await deletePlayerProfileAndNameIndex({
    db: args.db,
    uid: args.uid,
    counters,
  });
  await deleteOwnershipData({
    db: args.db,
    uid: args.uid,
    profileId: args.profileId,
    counters,
  });
  await deleteGhostData({
    db: args.db,
    uid: args.uid,
    counters,
  });
  await deleteAuthUserIfPresent(deleteAuthUser, args.uid);

  return {
    status: "deleted",
    deleted: counters,
  };
}

async function defaultDeleteAuthUser(uid: string): Promise<void> {
  await getAuth().deleteUser(uid);
}

async function deleteAuthUserIfPresent(
  deleteAuthUser: (uid: string) => Promise<void>,
  uid: string,
): Promise<void> {
  try {
    await deleteAuthUser(uid);
  } catch (error) {
    if (isAuthUserNotFoundError(error)) {
      return;
    }
    throw error;
  }
}

function isAuthUserNotFoundError(error: unknown): boolean {
  if (!error || typeof error !== "object") {
    return false;
  }
  const code = (error as { code?: unknown }).code;
  return code === "auth/user-not-found";
}

async function deletePlayerProfileAndNameIndex(args: {
  db: Firestore;
  uid: string;
  counters: AccountDeleteCounters;
}): Promise<void> {
  const profileRef = args.db.collection(playerProfilesCollection).doc(args.uid);
  const profileSnap = await profileRef.get();
  const profileDoc = profileSnap.data() as PlayerProfileDocument | undefined;
  const claimedNormalized = readNormalizedDisplayName(profileDoc);

  if (profileSnap.exists) {
    await profileRef.delete();
    args.counters.profileDocs += 1;
  }

  const indexRefsByPath = new Map<string, DocumentReference>();
  if (claimedNormalized.length > 0) {
    const directRef = args.db
      .collection(displayNameIndexCollection)
      .doc(claimedNormalized);
    const directSnap = await directRef.get();
    if (directSnap.exists) {
      const owner = readUid(
        directSnap.data() as DisplayNameIndexDocument | undefined,
      );
      if (owner === args.uid) {
        indexRefsByPath.set(directRef.path, directRef);
      }
    }
  }

  const claimedQuery = await args.db
    .collection(displayNameIndexCollection)
    .where("uid", "==", args.uid)
    .get();
  for (const doc of claimedQuery.docs) {
    indexRefsByPath.set(doc.ref.path, doc.ref);
  }

  for (const ref of indexRefsByPath.values()) {
    await ref.delete();
    args.counters.displayNameIndexDocs += 1;
  }
}

async function deleteOwnershipData(args: {
  db: Firestore;
  uid: string;
  profileId: string;
  counters: AccountDeleteCounters;
}): Promise<void> {
  const docRefsByPath = new Map<string, DocumentReference>();
  const explicitRef = canonicalDocRef(args.db, args.uid, args.profileId);
  docRefsByPath.set(explicitRef.path, explicitRef);

  const ownedQuery = await args.db
    .collection(ownershipProfilesCollection)
    .where("uid", "==", args.uid)
    .get();
  for (const doc of ownedQuery.docs) {
    docRefsByPath.set(doc.ref.path, doc.ref);
  }

  for (const ref of docRefsByPath.values()) {
    const snap = await ref.get();
    if (!snap.exists) {
      continue;
    }
    await args.db.recursiveDelete(ref);
    args.counters.ownershipDocs += 1;
  }
}

async function deleteGhostData(args: {
  db: Firestore;
  uid: string;
  counters: AccountDeleteCounters;
}): Promise<void> {
  const refsByPath = new Map<string, DocumentReference>();

  for (const spec of ghostCollectionSpecs) {
    const collectionRef = args.db.collection(
      spec.collection,
    ) as CollectionReference;
    for (const uidField of spec.uidFields) {
      const snapshot = await collectionRef.where(uidField, "==", args.uid).get();
      for (const doc of snapshot.docs) {
        refsByPath.set(doc.ref.path, doc.ref);
      }
    }
  }

  for (const ref of refsByPath.values()) {
    await args.db.recursiveDelete(ref);
    args.counters.ghostDocs += 1;
  }
}

function readUid(doc: DisplayNameIndexDocument | undefined): string {
  if (!doc || typeof doc.uid !== "string") {
    return "";
  }
  return doc.uid;
}

function readNormalizedDisplayName(doc: PlayerProfileDocument | undefined): string {
  if (!doc) {
    return "";
  }
  if (
    typeof doc.displayNameNormalized === "string" &&
    doc.displayNameNormalized.trim().length > 0
  ) {
    return doc.displayNameNormalized.trim();
  }
  if (typeof doc.displayName !== "string" || doc.displayName.trim().length === 0) {
    return "";
  }
  return normalizeDisplayNameForPolicy(doc.displayName);
}
