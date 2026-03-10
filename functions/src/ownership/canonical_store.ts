import { FieldValue, type Firestore } from "firebase-admin/firestore";

import type {
  CanonicalDocument,
  IdempotencyDocument,
  OwnershipCanonicalState,
  OwnershipCommandResult,
} from "./contracts.js";
import { starterCanonicalDocument, normalizeCanonicalState } from "./defaults.js";
import { canonicalDocRef } from "./firestore_paths.js";

export async function loadOrCreateCanonicalState(args: {
  db: Firestore;
  uid: string;
  profileId: string;
}): Promise<OwnershipCanonicalState> {
  const { db, uid, profileId } = args;
  const ref = canonicalDocRef(db, uid, profileId);
  const snap = await ref.get();
  if (snap.exists) {
    return canonicalStateFromDocument(
      snap.data() as CanonicalDocument | undefined,
      profileId,
    );
  }

  const starterDoc = starterCanonicalDocument(uid, profileId);
  await ref.set(canonicalWriteData(uid, {
    profileId: starterDoc.profileId,
    revision: starterDoc.revision,
    selection: starterDoc.selection,
    meta: starterDoc.meta,
  }));
  return canonicalStateFromDocument(starterDoc, profileId);
}

export function canonicalStateFromDocument(
  doc: CanonicalDocument | undefined,
  profileId: string,
): OwnershipCanonicalState {
  if (!doc) {
    return normalizeCanonicalState(undefined, profileId);
  }
  return normalizeCanonicalState(
    {
      profileId: doc.profileId,
      revision: doc.revision,
      selection: doc.selection,
      meta: doc.meta,
    },
    profileId,
  );
}

export function canonicalWriteData(
  uid: string,
  canonical: OwnershipCanonicalState,
): Record<string, unknown> {
  return {
    uid,
    profileId: canonical.profileId,
    revision: canonical.revision,
    selection: canonical.selection,
    meta: canonical.meta,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };
}

export function canonicalMergeWriteData(
  uid: string,
  canonical: OwnershipCanonicalState,
): Record<string, unknown> {
  return {
    uid,
    profileId: canonical.profileId,
    revision: canonical.revision,
    selection: canonical.selection,
    meta: canonical.meta,
    updatedAt: FieldValue.serverTimestamp(),
  };
}

export function idempotencyWriteData(args: {
  payloadHash: string;
  result: OwnershipCommandResult;
}): IdempotencyDocument {
  return {
    payloadHash: args.payloadHash,
    result: args.result,
    createdAt: FieldValue.serverTimestamp(),
  };
}
