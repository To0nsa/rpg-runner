import type {
  CollectionReference,
  DocumentReference,
  Firestore,
} from "firebase-admin/firestore";

const ownershipProfilesCollection = "ownership_profiles";
const idempotencyCollection = "idempotency";
export const defaultCanonicalProfileId = "main";

export function canonicalDocId(uid: string, profileId: string): string {
  return `${uid}__${profileId}`;
}

export function canonicalDocRef(
  db: Firestore,
  uid: string,
  profileId: string,
): DocumentReference {
  return db.collection(ownershipProfilesCollection).doc(canonicalDocId(uid, profileId));
}

export function idempotencyCollectionRef(
  canonicalRef: DocumentReference,
): CollectionReference {
  return canonicalRef.collection(idempotencyCollection);
}

export function idempotencyDocRef(
  canonicalRef: DocumentReference,
  commandId: string,
): DocumentReference {
  return idempotencyCollectionRef(canonicalRef).doc(commandId);
}
