import { HttpsError } from "firebase-functions/v2/https";

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

export function requireNonEmptyString(value: unknown, fieldName: string): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${fieldName} must be a string`);
  }
  const trimmed = value.trim();
  if (trimmed.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} must be non-empty`,
    );
  }
  return trimmed;
}

export function requireBoundedIdentifier(
  value: unknown,
  fieldName: string,
  maxLength = 128,
): string {
  const identifier = requireNonEmptyString(value, fieldName);
  if (identifier.length > maxLength) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} must be at most ${maxLength} characters.`,
    );
  }
  if (!/^[a-zA-Z0-9][a-zA-Z0-9._:-]*$/u.test(identifier)) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} contains unsupported characters.`,
    );
  }
  return identifier;
}

export function requireObject(
  value: unknown,
  fieldName: string,
): Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", `${fieldName} must be an object`);
  }
  return value as Record<string, unknown>;
}

function requireInteger(value: unknown, fieldName: string): number {
  if (typeof value !== "number" || !Number.isInteger(value)) {
    throw new HttpsError("invalid-argument", `${fieldName} must be an integer`);
  }
  return value;
}
