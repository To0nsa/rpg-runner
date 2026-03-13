import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { setGlobalOptions } from "firebase-functions/v2";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { deleteAccountAndData } from "./account/delete.js";
import { parseAccountDeleteRequest } from "./account/validators.js";
import {
  loadOrCreatePlayerProfile,
  updatePlayerProfile,
} from "./profile/store.js";
import {
  parseLoadPlayerProfileRequest,
  parseUpdatePlayerProfileRequest,
} from "./profile/validators.js";
import { loadOrCreateCanonicalState } from "./ownership/canonical_store.js";
import { executeOwnershipCommand } from "./ownership/command_executor.js";
import {
  parseExecuteCommandRequest,
  parseLoadCanonicalRequest,
} from "./ownership/validators.js";
import {
  handleRunBoardsLoadActive,
  handleRunSessionCreate,
} from "./runs/callable_handlers.js";

if (getApps().length === 0) {
  initializeApp();
}

setGlobalOptions({
  serviceAccount: "sa-run-control@rpg-runner-d7add.iam.gserviceaccount.com",
});

const db = getFirestore();

export const loadoutOwnershipLoadCanonicalState = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { userId } = parseLoadCanonicalRequest(request.data);
  if (userId !== uid) {
    throw new HttpsError("permission-denied", "userId does not match auth uid.");
  }
  const canonicalState = await loadOrCreateCanonicalState({
    db,
    uid,
  });
  return { canonicalState };
});

export const loadoutOwnershipExecuteCommand = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { command } = parseExecuteCommandRequest(request.data);
  if (command.userId !== uid) {
    throw new HttpsError("permission-denied", "userId does not match auth uid.");
  }
  const result = await executeOwnershipCommand({
    db,
    uid,
    command,
  });
  return { result };
});

export const playerProfileLoad = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { userId } = parseLoadPlayerProfileRequest(request.data);
  if (userId !== uid) {
    throw new HttpsError("permission-denied", "userId does not match auth uid.");
  }
  const profile = await loadOrCreatePlayerProfile({ db, uid });
  return { profile };
});

export const playerProfileUpdate = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const {
    userId,
    displayName,
    displayNameLastChangedAtMs,
    namePromptCompleted,
  } = parseUpdatePlayerProfileRequest(request.data);
  if (userId !== uid) {
    throw new HttpsError("permission-denied", "userId does not match auth uid.");
  }
  const profile = await updatePlayerProfile({
    db,
    uid,
    displayName,
    displayNameLastChangedAtMs,
    namePromptCompleted,
  });
  return { profile };
});

export const accountDelete = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { userId } = parseAccountDeleteRequest(request.data);
  if (userId !== uid) {
    throw new HttpsError("permission-denied", "userId does not match auth uid.");
  }
  const result = await deleteAccountAndData({
    db,
    uid,
  });
  return { result };
});

export const runBoardsLoadActive = onCall(async (request) => {
  return handleRunBoardsLoadActive(request, db);
});

export const runSessionCreate = onCall(async (request) => {
  return handleRunSessionCreate(request, db);
});
