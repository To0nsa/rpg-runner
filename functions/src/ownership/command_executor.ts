import type {
  DocumentReference,
  Firestore,
  Transaction,
} from "firebase-admin/firestore";

import { assertAccountActiveInTransaction } from "../account/deletion_guard.js";
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
import { isOwnershipRejectedReason } from "./contracts.js";
import { canonicalJsonString, sha256Hex } from "./hash.js";
import { idempotencyDocRef } from "./firestore_paths.js";
import { legacyReadReconciliationEnabled } from "./legacy_reward_reconciliation.js";
import { reconcilePendingRewardGrantsForTransaction } from "./reward_grants.js";

export async function executeOwnershipCommand(args: {
  db: Firestore;
  uid: string;
  command: OwnershipCommandEnvelope;
  nowMs?: number;
}): Promise<OwnershipCommandResult> {
  const { db, uid, command } = args;
  const nowMs = args.nowMs ?? Date.now();
  const payloadHash = ownershipIdempotencyPayloadHash(command);

  return db.runTransaction(async (tx) => {
    await assertAccountActiveInTransaction(tx, db, uid);
    const resolved = await resolveCanonicalStateForTransaction({
      db,
      tx,
      uid,
    });
    const canonicalRef = resolved.canonicalRef;
    const idempotencyRef = idempotencyDocRef(canonicalRef, command.commandId);
    const idempotencySnap = await tx.get(idempotencyRef);
    const reconciliation = legacyReadReconciliationEnabled()
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
    const canonical = reconciliation.canonicalState;
    const shouldPersistCanonicalBeforeCommand =
      !resolved.exists || reconciliation.canonicalChanged;

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
        return normalizeStoredResult(stored, canonical);
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
      tx.set(
        idempotencyRef,
        idempotencyWriteData({ payloadHash, result: rejected, nowMs }),
      );
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
      tx.set(
        idempotencyRef,
        idempotencyWriteData({ payloadHash, result: rejected, nowMs }),
      );
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
      tx.set(
        idempotencyRef,
        idempotencyWriteData({ payloadHash, result: rejected, nowMs }),
      );
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
    tx.set(
      idempotencyRef,
      idempotencyWriteData({ payloadHash, result: accepted, nowMs }),
    );
    return accepted;
  });
}

/// Computes the idempotency identity for the semantic ownership write.
///
/// `sessionId` identifies the client session that delivered a command. Firebase
/// refreshes ID tokens during a session, so retrying the same durable command
/// must not turn that transport detail into an idempotency-key mismatch.
function ownershipIdempotencyPayloadHash(
  command: OwnershipCommandEnvelope,
): string {
  const { sessionId: _sessionId, ...semanticCommand } = command;
  return sha256Hex(canonicalJsonString(semanticCommand as JsonValue));
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
  stored: IdempotencyDocument,
  fallbackCanonical: OwnershipCanonicalState,
): OwnershipCommandResult {
  const compact = compactStoredOutcome(stored);
  if (compact) {
    return {
      canonicalState: fallbackCanonical,
      newRevision: Math.max(
        compact.resultingRevision,
        fallbackCanonical.revision,
      ),
      replayedFromIdempotency: true,
      rejectedReason: compact.rejectedReason,
    };
  }
  const result = stored.result;
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

function compactStoredOutcome(stored: IdempotencyDocument): {
  resultingRevision: number;
  rejectedReason: OwnershipRejectedReason | null;
} | null {
  const outcome = stored.outcome;
  if (!outcome || typeof outcome !== "object") {
    return null;
  }
  const resultingRevision = outcome.resultingRevision;
  if (
    typeof resultingRevision !== "number" ||
    !Number.isSafeInteger(resultingRevision) ||
    resultingRevision < 0
  ) {
    return null;
  }
  const rejectedRaw = outcome.rejectedReason;
  const rejectedReason =
    rejectedRaw === null
      ? null
      : typeof rejectedRaw === "string" &&
          isOwnershipRejectedReason(rejectedRaw)
        ? rejectedRaw
        : undefined;
  if (rejectedReason === undefined) {
    return null;
  }
  return {
    resultingRevision,
    rejectedReason,
  };
}
