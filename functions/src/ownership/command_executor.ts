import type { Firestore } from "firebase-admin/firestore";

import { applyOwnershipCommand } from "./apply_command.js";
import {
  canonicalMergeWriteData,
  canonicalWriteData,
  idempotencyWriteData,
  resolveCanonicalStateForTransaction,
} from "./canonical_store.js";
import type {
  IdempotencyDocument,
  JsonValue,
  OwnershipCanonicalState,
  OwnershipCommandEnvelope,
  OwnershipCommandResult,
  OwnershipRejectedReason,
} from "./contracts.js";
import { canonicalJsonString, sha256Hex } from "./hash.js";
import { idempotencyDocRef } from "./firestore_paths.js";

export async function executeOwnershipCommand(args: {
  db: Firestore;
  uid: string;
  command: OwnershipCommandEnvelope;
}): Promise<OwnershipCommandResult> {
  const { db, uid, command } = args;
  const payloadHash = sha256Hex(
    canonicalJsonString(command as unknown as JsonValue),
  );

  return db.runTransaction(async (tx) => {
    const resolved = await resolveCanonicalStateForTransaction({
      db,
      tx,
      uid,
    });
    const canonicalRef = resolved.canonicalRef;
    const idempotencyRef = idempotencyDocRef(canonicalRef, command.commandId);
    const idempotencySnap = await tx.get(idempotencyRef);
    const canonical = resolved.canonical;

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
      if (!resolved.exists) {
        tx.set(canonicalRef, canonicalWriteData(uid, canonical));
      }
      tx.set(idempotencyRef, idempotencyWriteData({ payloadHash, result: rejected }));
      return rejected;
    }

    if (command.expectedRevision !== canonical.revision) {
      const rejected = rejectResult(canonical, "staleRevision");
      if (!resolved.exists) {
        tx.set(canonicalRef, canonicalWriteData(uid, canonical));
      }
      tx.set(idempotencyRef, idempotencyWriteData({ payloadHash, result: rejected }));
      return rejected;
    }

    const applyResult = applyOwnershipCommand(canonical, command);
    if (!applyResult.accepted) {
      const rejected = rejectResult(canonical, applyResult.rejectedReason);
      if (!resolved.exists) {
        tx.set(canonicalRef, canonicalWriteData(uid, canonical));
      }
      tx.set(idempotencyRef, idempotencyWriteData({ payloadHash, result: rejected }));
      return rejected;
    }

    const nextCanonical: OwnershipCanonicalState = {
      ...applyResult.canonicalState,
      profileId: canonical.profileId,
      revision: canonical.revision + 1,
    };
    const accepted: OwnershipCommandResult = {
      canonicalState: nextCanonical,
      newRevision: nextCanonical.revision,
      replayedFromIdempotency: false,
      rejectedReason: null,
    };
    if (resolved.exists) {
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
