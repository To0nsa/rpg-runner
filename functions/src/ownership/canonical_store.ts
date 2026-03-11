import {
  FieldValue,
  type DocumentReference,
  type Firestore,
  type Transaction,
} from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

import type {
  CanonicalDocument,
  IdempotencyDocument,
  OwnershipCanonicalState,
  OwnershipCommandResult,
} from "./contracts.js";
import { starterCanonicalDocument, normalizeCanonicalState } from "./defaults.js";
import { canonicalDocRef, defaultCanonicalProfileId } from "./firestore_paths.js";

export async function loadOrCreateCanonicalState(args: {
  db: Firestore;
  uid: string;
}): Promise<OwnershipCanonicalState> {
  const { db, uid } = args;
  const resolved = await resolveCanonicalState({
    db,
    uid,
  });
  if (resolved.exists) {
    return resolved.canonical;
  }

  const starterDoc = starterCanonicalDocument(uid, resolved.canonical.profileId);
  await resolved.canonicalRef.set(canonicalWriteData(uid, {
    profileId: starterDoc.profileId,
    revision: starterDoc.revision,
    selection: starterDoc.selection,
    meta: starterDoc.meta,
    progression: starterDoc.progression,
  }));
  return canonicalStateFromDocument(starterDoc, resolved.canonical.profileId);
}

export async function resolveCanonicalStateForTransaction(args: {
  db: Firestore;
  tx: Transaction;
  uid: string;
}): Promise<ResolvedCanonicalState> {
  const querySnap = await args.tx.get(
    args.db.collection("ownership_profiles").where("uid", "==", args.uid).limit(2),
  );
  return resolveCanonicalStateFromQueryDocs({
    db: args.db,
    uid: args.uid,
    docs: querySnap.docs.map((doc) => ({
      ref: doc.ref,
      data: doc.data() as CanonicalDocument | undefined,
    })),
  });
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
      progression: doc.progression,
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
    progression: canonical.progression,
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
    progression: canonical.progression,
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

interface ResolvedCanonicalState {
  canonicalRef: DocumentReference;
  canonical: OwnershipCanonicalState;
  exists: boolean;
}

interface ResolvedCanonicalQueryDoc {
  ref: DocumentReference;
  data: CanonicalDocument | undefined;
}

async function resolveCanonicalState(args: {
  db: Firestore;
  uid: string;
}): Promise<ResolvedCanonicalState> {
  const snapshot = await args.db
    .collection("ownership_profiles")
    .where("uid", "==", args.uid)
    .limit(2)
    .get();
  return resolveCanonicalStateFromQueryDocs({
    db: args.db,
    uid: args.uid,
    docs: snapshot.docs.map((doc) => ({
      ref: doc.ref,
      data: doc.data() as CanonicalDocument | undefined,
    })),
  });
}

function resolveCanonicalStateFromQueryDocs(args: {
  db: Firestore;
  uid: string;
  docs: ResolvedCanonicalQueryDoc[];
}): ResolvedCanonicalState {
  if (args.docs.length > 1) {
    throw new HttpsError(
      "failed-precondition",
      "Multiple ownership profiles exist for this user.",
    );
  }

  const existing = args.docs[0];
  if (existing) {
    const profileId = readProfileId(existing.data);
    return {
      canonicalRef: existing.ref,
      canonical: canonicalStateFromDocument(existing.data, profileId),
      exists: true,
    };
  }

  const canonical = normalizeCanonicalState(undefined, defaultCanonicalProfileId);
  return {
    canonicalRef: canonicalDocRef(args.db, args.uid, canonical.profileId),
    canonical,
    exists: false,
  };
}

function readProfileId(doc: CanonicalDocument | undefined): string {
  if (!doc || typeof doc.profileId !== "string" || doc.profileId.trim().length === 0) {
    return defaultCanonicalProfileId;
  }
  return doc.profileId.trim();
}
