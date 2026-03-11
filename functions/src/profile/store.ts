import {
  FieldValue,
  type DocumentReference,
  type DocumentSnapshot,
  type Firestore,
} from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

import { normalizeDisplayNameForPolicy } from "./validators.js";

export interface PlayerProfile {
  displayName: string;
  displayNameLastChangedAtMs: number;
  namePromptCompleted: boolean;
}

interface PlayerProfileDocument {
  uid: string;
  displayName?: string;
  displayNameNormalized?: string;
  displayNameLastChangedAtMs?: number;
  namePromptCompleted?: boolean;
  createdAt?: unknown;
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

export async function loadOrCreatePlayerProfile(args: {
  db: Firestore;
  uid: string;
}): Promise<PlayerProfile> {
  const ref = playerProfileDocRef(args.db, args.uid);
  const snap = await ref.get();
  if (snap.exists) {
    return playerProfileFromDocument(
      snap.data() as PlayerProfileDocument | undefined,
    );
  }

  const profile = emptyPlayerProfile();
  await ref.set(playerProfileWriteData(args.uid, profile, { create: true }));
  return profile;
}

export async function updatePlayerProfile(args: {
  db: Firestore;
  uid: string;
  displayName?: string;
  displayNameLastChangedAtMs?: number;
  namePromptCompleted?: boolean;
}): Promise<PlayerProfile> {
  const nextDisplayName = args.displayName?.trim();
  const nextDisplayNameLastChangedAtMs = args.displayNameLastChangedAtMs;
  const nextNamePromptCompleted = args.namePromptCompleted;

  let resolvedProfile = emptyPlayerProfile();
  await args.db.runTransaction(async (tx) => {
    const profileRef = playerProfileDocRef(args.db, args.uid);
    const profileSnap = await tx.get(profileRef);
    const existingProfile = profileSnap.exists
      ? playerProfileFromDocument(
          profileSnap.data() as PlayerProfileDocument | undefined,
        )
      : emptyPlayerProfile();
    const currentDoc = profileSnap.data() as PlayerProfileDocument | undefined;

    const previousNormalized = readNormalizedDisplayName(currentDoc);
    const changingDisplayName =
      nextDisplayName !== undefined &&
      nextDisplayNameLastChangedAtMs !== undefined;

    let nextNormalized = previousNormalized;
    let indexRef: DocumentReference | null = null;
    let previousIndexRef: DocumentReference | null = null;
    let previousIndexSnap: DocumentSnapshot | null = null;

    if (changingDisplayName) {
      nextNormalized = normalizeDisplayNameForPolicy(nextDisplayName);
      indexRef = displayNameIndexDocRef(args.db, nextNormalized);
      const indexSnap = await tx.get(indexRef);
      const claimedUid = readUid(
        indexSnap.data() as DisplayNameIndexDocument | undefined,
      );
      if (claimedUid !== null && claimedUid !== args.uid) {
        throw new HttpsError("already-exists", "displayName is already taken.");
      }

      previousIndexRef =
        previousNormalized.length > 0 && previousNormalized !== nextNormalized
          ? displayNameIndexDocRef(args.db, previousNormalized)
          : null;
      previousIndexSnap = previousIndexRef ? await tx.get(previousIndexRef) : null;
    }

    resolvedProfile = {
      displayName: changingDisplayName
        ? nextDisplayName
        : existingProfile.displayName,
      displayNameLastChangedAtMs: changingDisplayName
        ? normalizeNonNegativeInteger(nextDisplayNameLastChangedAtMs)
        : existingProfile.displayNameLastChangedAtMs,
      namePromptCompleted:
        nextNamePromptCompleted ?? existingProfile.namePromptCompleted,
    };

    tx.set(
      profileRef,
      playerProfileWriteData(args.uid, resolvedProfile, {
        create: !profileSnap.exists,
        displayNameNormalized: changingDisplayName ? nextNormalized : undefined,
      }),
      { merge: true },
    );

    if (changingDisplayName && indexRef) {
      tx.set(
        indexRef,
        {
          uid: args.uid,
          displayName: resolvedProfile.displayName,
          displayNameNormalized: nextNormalized,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }

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

  return resolvedProfile;
}

function emptyPlayerProfile(): PlayerProfile {
  return {
    displayName: "",
    displayNameLastChangedAtMs: 0,
    namePromptCompleted: false,
  };
}

function playerProfileFromDocument(doc: PlayerProfileDocument | undefined): PlayerProfile {
  if (!doc) {
    return emptyPlayerProfile();
  }
  const displayName =
    typeof doc.displayName === "string" ? doc.displayName.trim() : "";
  return {
    displayName,
    displayNameLastChangedAtMs: normalizeNonNegativeInteger(
      doc.displayNameLastChangedAtMs,
    ),
    namePromptCompleted: doc.namePromptCompleted === true,
  };
}

function playerProfileWriteData(
  uid: string,
  profile: PlayerProfile,
  options: {
    create: boolean;
    displayNameNormalized?: string;
  },
): Record<string, unknown> {
  const data: Record<string, unknown> = {
    uid,
    displayName: profile.displayName,
    displayNameLastChangedAtMs: profile.displayNameLastChangedAtMs,
    namePromptCompleted: profile.namePromptCompleted,
    updatedAt: FieldValue.serverTimestamp(),
  };
  if (options.create) {
    data.createdAt = FieldValue.serverTimestamp();
  }
  const normalized =
    options.displayNameNormalized ??
    (profile.displayName.length > 0
      ? normalizeDisplayNameForPolicy(profile.displayName)
      : undefined);
  if (normalized && normalized.length > 0) {
    data.displayNameNormalized = normalized;
  }
  return data;
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
