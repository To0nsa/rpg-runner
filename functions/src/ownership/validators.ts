import { HttpsError } from "firebase-functions/v2/https";
import { requireNonEmptyString, requireBoundedIdentifier, requireObject } from "../validation.js";
export { requireNonEmptyString, requireBoundedIdentifier, requireObject } from "../validation.js";

import { assertCallablePayloadBounds } from "../abuse/payload_bounds.js";
import {
  type JsonObject,
  type OwnershipCommandEnvelope,
  isClientOwnershipCommandType,
  isOwnershipCommandType,
} from "./contracts.js";
import {
  knownAbilitySlots,
  knownCharacterIds,
  knownGearSlots,
  type KnownAbilitySlot,
  type KnownCharacterId,
  type KnownGearSlot,
} from "./defaults.js";
import { isStoreRefreshMethodValue } from "./store_state.js";

interface LoadCanonicalRequest {
  userId: string;
  sessionId: string;
}

interface ExecuteCommandRequest {
  command: OwnershipCommandEnvelope;
}

export function parseLoadCanonicalRequest(raw: unknown): LoadCanonicalRequest {
  assertCallablePayloadBounds(raw);
  const data = requireObject(raw, "request");
  return {
    userId: requireNonEmptyString(data.userId, "userId"),
    sessionId: requireNonEmptyString(data.sessionId, "sessionId"),
  };
}

export function parseExecuteCommandRequest(raw: unknown): ExecuteCommandRequest {
  assertCallablePayloadBounds(raw);
  const data = requireObject(raw, "request");
  const commandRaw = requireObject(data.command, "command");
  const type = requireNonEmptyString(commandRaw.type, "command.type");
  if (!isOwnershipCommandType(type)) {
    throw new HttpsError(
      "invalid-argument",
      `Unsupported command.type: ${type}`,
    );
  }
  if (!isClientOwnershipCommandType(type)) {
    throw new HttpsError(
      "permission-denied",
      `command.type is server-only: ${type}`,
    );
  }
  const payloadRaw = requireObject(commandRaw.payload, "command.payload");
  validateCommandPayload(type, payloadRaw);
  const expectedRevision = requireInteger(
    commandRaw.expectedRevision,
    "command.expectedRevision",
  );
  if (expectedRevision < 0) {
    throw new HttpsError(
      "invalid-argument",
      "command.expectedRevision must be >= 0",
    );
  }
  const command: OwnershipCommandEnvelope = {
    type,
    userId: requireNonEmptyString(commandRaw.userId, "command.userId"),
    sessionId: requireNonEmptyString(commandRaw.sessionId, "command.sessionId"),
    expectedRevision,
    commandId: requireBoundedIdentifier(
      commandRaw.commandId,
      "command.commandId",
      96,
    ),
    payload: payloadRaw as JsonObject,
  };
  return { command };
}

function validateCommandPayload(
  type: OwnershipCommandEnvelope["type"],
  payload: Record<string, unknown>,
): void {
  if (type === "claimAchievements") {
    if (Object.keys(payload).some((key) => key !== "achievementId") ||
        (payload.achievementId !== null &&
          (typeof payload.achievementId !== "string" || payload.achievementId.length > 64))) {
      throw new HttpsError("invalid-argument", "Expected only achievementId (string or null).");
    }
    return;
  }
  if (type === "purchaseStoreOffer") {
    requireNonEmptyString(payload.offerId, "command.payload.offerId");
    return;
  }
  if (type === "refreshStore") {
    const method = requireNonEmptyString(payload.method, "command.payload.method");
    if (!isStoreRefreshMethodValue(method)) {
      throw new HttpsError(
        "invalid-argument",
        `Unsupported command.payload.method: ${method}`,
      );
    }
  }
}

export function requireKnownCharacterId(
  value: unknown,
  fieldName: string,
): KnownCharacterId {
  const id = requireNonEmptyString(value, fieldName);
  if (!knownCharacterIds.includes(id as KnownCharacterId)) {
    throw new HttpsError("invalid-argument", `Unknown ${fieldName}: ${id}`);
  }
  return id as KnownCharacterId;
}

export function requireKnownAbilitySlot(
  value: unknown,
  fieldName: string,
): KnownAbilitySlot {
  const slot = requireNonEmptyString(value, fieldName);
  if (!knownAbilitySlots.includes(slot as KnownAbilitySlot)) {
    throw new HttpsError("invalid-argument", `Unknown ${fieldName}: ${slot}`);
  }
  return slot as KnownAbilitySlot;
}

export function requireKnownGearSlot(
  value: unknown,
  fieldName: string,
): KnownGearSlot {
  const slot = requireNonEmptyString(value, fieldName);
  if (!knownGearSlots.includes(slot as KnownGearSlot)) {
    throw new HttpsError("invalid-argument", `Unknown ${fieldName}: ${slot}`);
  }
  return slot as KnownGearSlot;
}


function requireInteger(value: unknown, fieldName: string): number {
  if (typeof value !== "number" || !Number.isInteger(value)) {
    throw new HttpsError("invalid-argument", `${fieldName} must be an integer`);
  }
  return value;
}
