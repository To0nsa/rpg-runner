import { HttpsError } from "firebase-functions/v2/https";

import {
  type JsonObject,
  type OwnershipCommandEnvelope,
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

interface LoadCanonicalRequest {
  userId: string;
  sessionId: string;
}

interface ExecuteCommandRequest {
  command: OwnershipCommandEnvelope;
}

export function parseLoadCanonicalRequest(raw: unknown): LoadCanonicalRequest {
  const data = requireObject(raw, "request");
  return {
    userId: requireNonEmptyString(data.userId, "userId"),
    sessionId: requireNonEmptyString(data.sessionId, "sessionId"),
  };
}

export function parseExecuteCommandRequest(raw: unknown): ExecuteCommandRequest {
  const data = requireObject(raw, "request");
  const commandRaw = requireObject(data.command, "command");
  const type = requireNonEmptyString(commandRaw.type, "command.type");
  if (!isOwnershipCommandType(type)) {
    throw new HttpsError(
      "invalid-argument",
      `Unsupported command.type: ${type}`,
    );
  }
  const payloadRaw = requireObject(commandRaw.payload, "command.payload");
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
    commandId: requireNonEmptyString(commandRaw.commandId, "command.commandId"),
    payload: payloadRaw as JsonObject,
  };
  return { command };
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
