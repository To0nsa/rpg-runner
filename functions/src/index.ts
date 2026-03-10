import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { loadOrCreateCanonicalState } from "./ownership/canonical_store.js";
import { executeOwnershipCommand } from "./ownership/command_executor.js";
import {
  parseExecuteCommandRequest,
  parseLoadCanonicalRequest,
} from "./ownership/validators.js";

if (getApps().length === 0) {
  initializeApp();
}

const db = getFirestore();

export const loadoutOwnershipLoadCanonicalState = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { profileId } = parseLoadCanonicalRequest(request.data);
  const canonicalState = await loadOrCreateCanonicalState({
    db,
    uid,
    profileId,
  });
  return { canonicalState };
});

export const loadoutOwnershipExecuteCommand = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { command } = parseExecuteCommandRequest(request.data);
  if (command.profileId.trim().length === 0) {
    throw new HttpsError("invalid-argument", "profileId must be non-empty.");
  }
  const result = await executeOwnershipCommand({
    db,
    uid,
    command,
  });
  return { result };
});
