import type { Firestore } from "firebase-admin/firestore";

import { applyOwnershipCommand } from "./apply_command.js";
import {
  canonicalMergeWriteData,
  canonicalStateFromDocument,
  canonicalWriteData,
  idempotencyWriteData,
} from "./canonical_store.js";
import type {
  CanonicalDocument,
  IdempotencyDocument,
  JsonValue,
  OwnershipCanonicalState,
  OwnershipCommandEnvelope,
  OwnershipCommandResult,
  OwnershipRejectedReason,
} from "./contracts.js";
import { canonicalJsonString, sha256Hex } from "./hash.js";
import { canonicalDocRef, idempotencyDocRef } from "./firestore_paths.js";
import { starterCanonicalState } from "./defaults.js";

export async function executeOwnershipCommand(args: {
  db: Firestore;
  uid: string;
  command: OwnershipCommandEnvelope;
}): Promise<OwnershipCommandResult> {
  const { db, uid, command } = args;
  const canonicalRef = canonicalDocRef(db, uid, command.profileId);
  const idempotencyRef = idempotencyDocRef(canonicalRef, command.commandId);
  const payloadHash = sha256Hex(
    canonicalJsonString(command as unknown as JsonValue),
  );

  return db.runTransaction(async (tx) => {
    const canonicalSnap = await tx.get(canonicalRef);
    const idempotencySnap = await tx.get(idempotencyRef);
    const canonical = canonicalSnap.exists
      ? canonicalStateFromDocument(
          canonicalSnap.data() as CanonicalDocument | undefined,
          command.profileId,
        )
      : starterCanonicalState(command.profileId);

    if (idempotencySnap.exists) {
      const stored = idempotencySnap.data() as IdempotencyDocument | undefined;
      if (stored?.payloadHash === payloadHash) {
        return normalizeStoredResult(stored.result, canonical);
      }
      return rejectResult(canonical, "idempotencyKeyReuseMismatch");
    }

    // Guard against command actor spoofing. Identity authority is auth uid.
    if (command.userId !== uid) {
      const rejected = rejectResult(canonical, "forbidden");
      if (!canonicalSnap.exists) {
        tx.set(canonicalRef, canonicalWriteData(uid, canonical));
      }
      tx.set(idempotencyRef, idempotencyWriteData({ payloadHash, result: rejected }));
      return rejected;
    }

    if (command.expectedRevision !== canonical.revision) {
      const rejected = rejectResult(canonical, "staleRevision");
      if (!canonicalSnap.exists) {
        tx.set(canonicalRef, canonicalWriteData(uid, canonical));
      }
      tx.set(idempotencyRef, idempotencyWriteData({ payloadHash, result: rejected }));
      return rejected;
    }

    const applyResult = applyOwnershipCommand(canonical, command);
    if (!applyResult.accepted) {
      const rejected = rejectResult(canonical, applyResult.rejectedReason);
      if (!canonicalSnap.exists) {
        tx.set(canonicalRef, canonicalWriteData(uid, canonical));
      }
      tx.set(idempotencyRef, idempotencyWriteData({ payloadHash, result: rejected }));
      return rejected;
    }

    const nextCanonical: OwnershipCanonicalState = {
      ...applyResult.canonicalState,
      profileId: command.profileId,
      revision: canonical.revision + 1,
    };
    const accepted: OwnershipCommandResult = {
      canonicalState: nextCanonical,
      newRevision: nextCanonical.revision,
      replayedFromIdempotency: false,
      rejectedReason: null,
    };
    if (canonicalSnap.exists) {
      tx.set(canonicalRef, canonicalMergeWriteData(uid, nextCanonical), {
        merge: true,
      });
    } else {
      tx.set(canonicalRef, canonicalWriteData(uid, nextCanonical));
    }
    tx.set(idempotencyRef, idempotencyWriteData({ payloadHash, result: accepted }));
    return accepted;
  });
}

function rejectResult(
  canonical: OwnershipCanonicalState,
  reason: OwnershipRejectedReason,
): OwnershipCommandResult {
  return {
    canonicalState: canonical,
    newRevision: canonical.revision,
    replayedFromIdempotency: false,
    rejectedReason: reason,
  };
}

function normalizeStoredResult(
  result: OwnershipCommandResult | undefined,
  fallbackCanonical: OwnershipCanonicalState,
): OwnershipCommandResult {
  if (!result) {
    return {
      canonicalState: fallbackCanonical,
      newRevision: fallbackCanonical.revision,
      replayedFromIdempotency: true,
      rejectedReason: "invalidCommand",
    };
  }
  return {
    canonicalState: result.canonicalState ?? fallbackCanonical,
    newRevision:
      typeof result.newRevision === "number"
        ? result.newRevision
        : (result.canonicalState?.revision ?? fallbackCanonical.revision),
    replayedFromIdempotency: true,
    rejectedReason: result.rejectedReason ?? null,
  };
}
