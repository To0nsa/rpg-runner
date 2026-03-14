import type {
  DocumentReference,
  Firestore,
  Transaction,
} from "firebase-admin/firestore";

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
import { reconcilePendingRewardGrantsForTransaction } from "./reward_grants.js";

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
    const reconciled = await reconcilePendingRewardGrantsForTransaction({
      db,
      tx,
      uid,
      canonicalState: resolved.canonical,
    });
    const canonical = reconciled.canonicalState;
    const shouldPersistCanonicalBeforeCommand =
      !resolved.exists || reconciled.canonicalChanged;

    if (idempotencySnap.exists) {
      const stored = idempotencySnap.data() as IdempotencyDocument | undefined;
      if (shouldPersistCanonicalBeforeCommand) {
        persistCanonical({
          tx,
          canonicalRef,
          uid,
          canonical,
          exists: resolved.exists,
        });
      }
      if (stored?.payloadHash === payloadHash) {
        return normalizeStoredResult(stored.result, canonical);
      }
      return rejectResult(canonical, "idempotencyKeyReuseMismatch");
    }

    // Guard against command actor spoofing. Identity authority is auth uid.
    if (command.userId !== uid) {
      const rejected = rejectResult(canonical, "forbidden");
      if (shouldPersistCanonicalBeforeCommand) {
        persistCanonical({
          tx,
          canonicalRef,
          uid,
          canonical,
          exists: resolved.exists,
        });
      }
      tx.set(idempotencyRef, idempotencyWriteData({ payloadHash, result: rejected }));
      return rejected;
    }

    if (command.expectedRevision !== canonical.revision) {
      const rejected = rejectResult(canonical, "staleRevision");
      if (shouldPersistCanonicalBeforeCommand) {
        persistCanonical({
          tx,
          canonicalRef,
          uid,
          canonical,
          exists: resolved.exists,
        });
      }
      tx.set(idempotencyRef, idempotencyWriteData({ payloadHash, result: rejected }));
      return rejected;
    }

    const applyResult = applyOwnershipCommand(canonical, command);
    if (!applyResult.accepted) {
      const rejected = rejectResult(canonical, applyResult.rejectedReason);
      if (shouldPersistCanonicalBeforeCommand) {
        persistCanonical({
          tx,
          canonicalRef,
          uid,
          canonical,
          exists: resolved.exists,
        });
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

function persistCanonical(args: {
  tx: Transaction;
  canonicalRef: DocumentReference;
  uid: string;
  canonical: OwnershipCanonicalState;
  exists: boolean;
}): void {
  if (args.exists) {
    args.tx.set(
      args.canonicalRef,
      canonicalMergeWriteData(args.uid, args.canonical),
      { merge: true },
    );
    return;
  }
  args.tx.set(args.canonicalRef, canonicalWriteData(args.uid, args.canonical));
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
  const storedCanonical = result.canonicalState;
  const canonicalState =
    storedCanonical && storedCanonical.revision > fallbackCanonical.revision
      ? storedCanonical
      : fallbackCanonical;
  return {
    canonicalState,
    newRevision:
      typeof result.newRevision === "number"
        ? Math.max(result.newRevision, canonicalState.revision)
        : canonicalState.revision,
    replayedFromIdempotency: true,
    rejectedReason: result.rejectedReason ?? null,
  };
}
