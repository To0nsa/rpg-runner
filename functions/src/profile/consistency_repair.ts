import {
  FieldPath,
  FieldValue,
  type Firestore,
} from "firebase-admin/firestore";

import { normalizeDisplayNameForPolicy } from "./validators.js";

interface ProfileDocument {
  displayName?: unknown;
  displayNameNormalized?: unknown;
}

interface DisplayNameIndexDocument {
  uid?: unknown;
  displayName?: unknown;
  displayNameNormalized?: unknown;
}

interface RepairCursorDocument {
  profileCursor?: unknown;
  indexCursor?: unknown;
}

export interface ProfileConsistencyRepairResult {
  profileScannedCount: number;
  indexScannedCount: number;
  missingClaimRepairedCount: number;
  orphanClaimRemovedCount: number;
  canonicalMetadataRepairedCount: number;
  conflictingClaimCount: number;
  profileCursor: string | null;
  indexCursor: string | null;
}

const playerProfilesCollection = "player_profiles";
const displayNameIndexCollection = "display_name_index";
const maintenanceCollection = "system_maintenance";
const maintenanceDocument = "profile_consistency_repair";

/**
 * Inventories and repairs profile/display-name-index agreement in bounded pages.
 *
 * A profile never takes an index entry currently owned by another UID. Orphaned
 * claims are removed by the independent index pass, after which a later profile
 * pass may claim the now-free normalized name.
 */
export async function repairProfileConsistency(args: {
  db: Firestore;
  batchSize?: number;
}): Promise<ProfileConsistencyRepairResult> {
  const batchSize = args.batchSize ?? 64;
  if (!Number.isSafeInteger(batchSize) || batchSize <= 0 || batchSize > 500) {
    throw new Error("batchSize must be an integer between 1 and 500.");
  }

  const maintenanceRef = args.db
    .collection(maintenanceCollection)
    .doc(maintenanceDocument);
  const maintenanceSnap = await maintenanceRef.get();
  const maintenance =
    maintenanceSnap.data() as RepairCursorDocument | undefined;
  const currentProfileCursor = readCursor(maintenance?.profileCursor);
  const currentIndexCursor = readCursor(maintenance?.indexCursor);

  let profileQuery = args.db
    .collection(playerProfilesCollection)
    .orderBy(FieldPath.documentId())
    .limit(batchSize);
  if (currentProfileCursor) {
    profileQuery = profileQuery.startAfter(currentProfileCursor);
  }

  let indexQuery = args.db
    .collection(displayNameIndexCollection)
    .orderBy(FieldPath.documentId())
    .limit(batchSize);
  if (currentIndexCursor) {
    indexQuery = indexQuery.startAfter(currentIndexCursor);
  }

  const [profilePage, indexPage] = await Promise.all([
    profileQuery.get(),
    indexQuery.get(),
  ]);

  let missingClaimRepairedCount = 0;
  let orphanClaimRemovedCount = 0;
  let canonicalMetadataRepairedCount = 0;
  let conflictingClaimCount = 0;

  for (const profileSnap of profilePage.docs) {
    const outcome = await repairProfileClaim(args.db, profileSnap.id);
    switch (outcome) {
      case "missing_claim_repaired":
        missingClaimRepairedCount += 1;
        break;
      case "metadata_repaired":
        canonicalMetadataRepairedCount += 1;
        break;
      case "conflict":
        conflictingClaimCount += 1;
        break;
      case "consistent":
      case "unnamed":
        break;
    }
  }

  for (const indexSnap of indexPage.docs) {
    const outcome = await repairIndexClaim(args.db, indexSnap.id);
    switch (outcome) {
      case "orphan_removed":
        orphanClaimRemovedCount += 1;
        break;
      case "metadata_repaired":
        canonicalMetadataRepairedCount += 1;
        break;
      case "consistent":
        break;
    }
  }

  const profileCursor = nextCursor(profilePage.docs, batchSize);
  const indexCursor = nextCursor(indexPage.docs, batchSize);
  await maintenanceRef.set(
    {
      profileCursor,
      indexCursor,
      profileScannedCount: profilePage.size,
      indexScannedCount: indexPage.size,
      missingClaimRepairedCount,
      orphanClaimRemovedCount,
      canonicalMetadataRepairedCount,
      conflictingClaimCount,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return {
    profileScannedCount: profilePage.size,
    indexScannedCount: indexPage.size,
    missingClaimRepairedCount,
    orphanClaimRemovedCount,
    canonicalMetadataRepairedCount,
    conflictingClaimCount,
    profileCursor,
    indexCursor,
  };
}

async function repairProfileClaim(
  db: Firestore,
  uid: string,
): Promise<
  | "unnamed"
  | "consistent"
  | "missing_claim_repaired"
  | "metadata_repaired"
  | "conflict"
> {
  return db.runTransaction(async (tx) => {
    const profileRef = db.collection(playerProfilesCollection).doc(uid);
    const profileSnap = await tx.get(profileRef);
    if (!profileSnap.exists) {
      return "unnamed";
    }
    const profile = profileSnap.data() as ProfileDocument | undefined;
    const displayName = readDisplayName(profile?.displayName);
    if (!displayName) {
      return "unnamed";
    }
    const normalized = normalizeDisplayNameForPolicy(displayName);
    const indexRef = db.collection(displayNameIndexCollection).doc(normalized);
    const indexSnap = await tx.get(indexRef);
    const index = indexSnap.data() as DisplayNameIndexDocument | undefined;
    const claimedUid = readUid(index?.uid);
    if (claimedUid && claimedUid !== uid) {
      return "conflict";
    }

    const profileMetadataMatches =
      profile?.displayNameNormalized === normalized;
    const indexMetadataMatches =
      claimedUid === uid &&
      index?.displayName === displayName &&
      index?.displayNameNormalized === normalized;
    if (profileMetadataMatches && indexMetadataMatches) {
      return "consistent";
    }

    tx.set(
      profileRef,
      {
        uid,
        displayNameNormalized: normalized,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    tx.set(
      indexRef,
      {
        uid,
        displayName,
        displayNameNormalized: normalized,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return indexSnap.exists
      ? "metadata_repaired"
      : "missing_claim_repaired";
  });
}

async function repairIndexClaim(
  db: Firestore,
  normalized: string,
): Promise<"consistent" | "orphan_removed" | "metadata_repaired"> {
  return db.runTransaction(async (tx) => {
    const indexRef = db.collection(displayNameIndexCollection).doc(normalized);
    const indexSnap = await tx.get(indexRef);
    if (!indexSnap.exists) {
      return "consistent";
    }
    const index = indexSnap.data() as DisplayNameIndexDocument | undefined;
    const uid = readUid(index?.uid);
    if (!uid) {
      tx.delete(indexRef);
      return "orphan_removed";
    }

    const profileRef = db.collection(playerProfilesCollection).doc(uid);
    const profileSnap = await tx.get(profileRef);
    const profile = profileSnap.data() as ProfileDocument | undefined;
    const displayName = readDisplayName(profile?.displayName);
    const profileNormalized = displayName
      ? normalizeDisplayNameForPolicy(displayName)
      : null;
    if (!profileSnap.exists || profileNormalized !== normalized) {
      tx.delete(indexRef);
      return "orphan_removed";
    }

    const metadataMatches =
      index?.displayName === displayName &&
      index?.displayNameNormalized === normalized &&
      profile?.displayNameNormalized === normalized;
    if (metadataMatches) {
      return "consistent";
    }

    tx.set(
      profileRef,
      {
        uid,
        displayNameNormalized: normalized,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    tx.set(
      indexRef,
      {
        uid,
        displayName,
        displayNameNormalized: normalized,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return "metadata_repaired";
  });
}

function readDisplayName(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function readUid(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function readCursor(value: unknown): string | null {
  return typeof value === "string" && value.length > 0 ? value : null;
}

function nextCursor(
  docs: Array<{ id: string }>,
  batchSize: number,
): string | null {
  return docs.length === batchSize ? docs.at(-1)?.id ?? null : null;
}
