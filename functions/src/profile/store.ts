import { FieldValue, type Firestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

import { normalizeDisplayNameForPolicy } from "./validators.js";

export interface PlayerDisplayNameProfile {
  displayName: string;
  displayNameLastChangedAtMs: number;
}

interface PlayerProfileDocument {
  uid: string;
  displayName: string;
  displayNameNormalized?: string;
  displayNameLastChangedAtMs: number;
  updatedAt?: unknown;
}

interface DisplayNameIndexDocument {
  uid: string;
  displayName: string;
  displayNameNormalized: string;
  updatedAt?: unknown;
}

const playerProfilesCollection = "player_profiles";
const displayNameIndexCollection = "display_name_index";

export async function loadPlayerDisplayName(args: {
  db: Firestore;
  uid: string;
}): Promise<PlayerDisplayNameProfile | null> {
  const ref = playerProfileDocRef(args.db, args.uid);
  const snap = await ref.get();
  if (!snap.exists) {
    return null;
  }
  return playerDisplayNameFromDocument(
    snap.data() as PlayerProfileDocument | undefined,
  );
}

export async function savePlayerDisplayName(args: {
  db: Firestore;
  uid: string;
  displayName: string;
  displayNameLastChangedAtMs: number;
}): Promise<PlayerDisplayNameProfile> {
  const profile: PlayerDisplayNameProfile = {
    displayName: args.displayName.trim(),
    displayNameLastChangedAtMs: normalizeNonNegativeInteger(
      args.displayNameLastChangedAtMs,
    ),
  };
  const normalizedDisplayName = normalizeDisplayNameForPolicy(profile.displayName);
  const profileRef = playerProfileDocRef(args.db, args.uid);
  const indexRef = displayNameIndexDocRef(args.db, normalizedDisplayName);

  await args.db.runTransaction(async (tx) => {
    const profileSnap = await tx.get(profileRef);
    const indexSnap = await tx.get(indexRef);

    const claimedUid = readUid(indexSnap.data() as DisplayNameIndexDocument | undefined);
    if (claimedUid !== null && claimedUid !== args.uid) {
      throw new HttpsError("already-exists", "displayName is already taken.");
    }

    const previousNormalized = profileSnap.exists
      ? readNormalizedDisplayName(
          profileSnap.data() as PlayerProfileDocument | undefined,
        )
      : "";
    const previousIndexRef =
      previousNormalized.length > 0 && previousNormalized !== normalizedDisplayName
        ? displayNameIndexDocRef(args.db, previousNormalized)
        : null;
    const previousIndexSnap = previousIndexRef ? await tx.get(previousIndexRef) : null;

    tx.set(
      profileRef,
      {
        uid: args.uid,
        displayName: profile.displayName,
        displayNameNormalized: normalizedDisplayName,
        displayNameLastChangedAtMs: profile.displayNameLastChangedAtMs,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    tx.set(
      indexRef,
      {
        uid: args.uid,
        displayName: profile.displayName,
        displayNameNormalized: normalizedDisplayName,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    if (!previousIndexRef || !previousIndexSnap?.exists) {
      return;
    }
    const previousOwner = readUid(
      previousIndexSnap.data() as DisplayNameIndexDocument | undefined,
    );
    if (previousOwner === args.uid) {
      tx.delete(previousIndexRef);
    }
  });
  return profile;
}

function playerDisplayNameFromDocument(
  doc: PlayerProfileDocument | undefined,
): PlayerDisplayNameProfile | null {
  if (!doc) {
    return null;
  }
  const displayName =
    typeof doc.displayName === "string" ? doc.displayName.trim() : "";
  if (displayName.length === 0) {
    return null;
  }
  return {
    displayName,
    displayNameLastChangedAtMs: normalizeNonNegativeInteger(
      doc.displayNameLastChangedAtMs,
    ),
  };
}

function playerProfileDocRef(db: Firestore, uid: string) {
  return db.collection(playerProfilesCollection).doc(uid);
}

function displayNameIndexDocRef(db: Firestore, normalizedDisplayName: string) {
  return db.collection(displayNameIndexCollection).doc(normalizedDisplayName);
}

function readUid(doc: { uid?: unknown } | undefined): string | null {
  if (!doc || typeof doc.uid !== "string" || doc.uid.length === 0) {
    return null;
  }
  return doc.uid;
}

function readNormalizedDisplayName(doc: PlayerProfileDocument | undefined): string {
  if (!doc) {
    return "";
  }
  if (
    typeof doc.displayNameNormalized === "string" &&
    doc.displayNameNormalized.length > 0
  ) {
    return doc.displayNameNormalized;
  }
  if (typeof doc.displayName !== "string" || doc.displayName.trim().length === 0) {
    return "";
  }
  return normalizeDisplayNameForPolicy(doc.displayName);
}

function normalizeNonNegativeInteger(value: unknown): number {
  if (typeof value !== "number" || !Number.isInteger(value) || value < 0) {
    return 0;
  }
  return value;
}
