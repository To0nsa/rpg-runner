import {
  FieldValue,
  type DocumentReference,
  type Firestore,
  type Transaction,
} from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

import { assertAccountActiveInTransaction } from "../account/deletion_guard.js";
import type {
  CanonicalDocument,
  IdempotencyDocument,
  OwnershipCanonicalState,
  OwnershipCommandResult,
} from "./contracts.js";
import { normalizeCanonicalState } from "./defaults.js";
import { canonicalDocRef, defaultCanonicalProfileId } from "./firestore_paths.js";
import { legacyReadReconciliationEnabled } from "./legacy_reward_reconciliation.js";
import { reconcilePendingRewardGrantsForTransaction } from "./reward_grants.js";

export async function loadOrCreateCanonicalState(args: {
  db: Firestore;
  uid: string;
  /** Overrides the temporary production migration compatibility path in tests. */
  reconcileLegacyRewards?: boolean;
}): Promise<OwnershipCanonicalState> {
  const { db, uid } = args;
  return db.runTransaction(async (tx) => {
    await assertAccountActiveInTransaction(tx, db, uid);
    const resolved = await resolveCanonicalStateForTransaction({
      db,
      tx,
      uid,
    });
    const reconciliation =
      args.reconcileLegacyRewards ?? legacyReadReconciliationEnabled()
        ? await reconcilePendingRewardGrantsForTransaction({
            db,
            tx,
            uid,
            canonicalState: resolved.canonical,
          })
        : {
            canonicalState: resolved.canonical,
            canonicalChanged: false,
          };
    if (!resolved.exists || reconciliation.canonicalChanged) {
      if (resolved.exists) {
        tx.set(
          resolved.canonicalRef,
          canonicalMergeWriteData(uid, reconciliation.canonicalState),
          { merge: true },
        );
      } else {
        tx.set(
          resolved.canonicalRef,
          canonicalWriteData(uid, reconciliation.canonicalState),
        );
      }
    }
    return reconciliation.canonicalState;
  });
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
  uid: string,
): OwnershipCanonicalState {
  if (!doc) {
    return normalizeCanonicalState(undefined, profileId, uid);
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
    uid,
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
  nowMs: number;
}): IdempotencyDocument {
  return {
    payloadHash: args.payloadHash,
    schemaVersion: ownershipIdempotencySchemaVersion,
    outcome: {
      resultingRevision: args.result.newRevision,
      rejectedReason: args.result.rejectedReason,
    },
    createdAt: FieldValue.serverTimestamp(),
    createdAtMs: args.nowMs,
    expiresAtMs: args.nowMs + ownershipIdempotencyRetentionMs,
  };
}

export const ownershipOfflineRetryWindowMs = 7 * 24 * 60 * 60 * 1000;
export const ownershipIdempotencyRetentionMs = 14 * 24 * 60 * 60 * 1000;
export const ownershipIdempotencySchemaVersion = 2;

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
      canonical: canonicalStateFromDocument(existing.data, profileId, args.uid),
      exists: true,
    };
  }

  const canonical = normalizeCanonicalState(
    undefined,
    defaultCanonicalProfileId,
    args.uid,
  );
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
