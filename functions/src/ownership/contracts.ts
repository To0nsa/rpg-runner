export const ownershipCommandTypes = [
  "setSelection",
  "resetOwnership",
  "setLoadout",
  "equipGear",
  "setAbilitySlot",
  "setProjectileSpell",
  "learnProjectileSpell",
  "learnSpellAbility",
  "unlockGear",
] as const;

export type OwnershipCommandType = (typeof ownershipCommandTypes)[number];

export const ownershipRejectedReasons = [
  "staleRevision",
  "idempotencyKeyReuseMismatch",
  "invalidCommand",
  "forbidden",
  "unauthorized",
] as const;

export type OwnershipRejectedReason = (typeof ownershipRejectedReasons)[number];

export type JsonPrimitive = string | number | boolean | null;
export type JsonValue = JsonPrimitive | JsonObject | JsonValue[];
export interface JsonObject {
  [key: string]: JsonValue;
}

export interface OwnershipCanonicalState {
  profileId: string;
  revision: number;
  selection: JsonObject;
  meta: JsonObject;
}

export interface OwnershipCommandEnvelope {
  type: OwnershipCommandType;
  profileId: string;
  userId: string;
  sessionId: string;
  expectedRevision: number;
  commandId: string;
  payload: JsonObject;
}

export interface OwnershipCommandResult {
  canonicalState: OwnershipCanonicalState;
  newRevision: number;
  replayedFromIdempotency: boolean;
  rejectedReason: OwnershipRejectedReason | null;
}

export interface CanonicalDocument {
  uid: string;
  profileId: string;
  revision: number;
  selection: JsonObject;
  meta: JsonObject;
  createdAt?: unknown;
  updatedAt?: unknown;
}

export interface IdempotencyDocument {
  payloadHash: string;
  result: OwnershipCommandResult;
  createdAt?: unknown;
}

export function isOwnershipCommandType(
  value: string,
): value is OwnershipCommandType {
  return (ownershipCommandTypes as readonly string[]).includes(value);
}

export function isOwnershipRejectedReason(
  value: string,
): value is OwnershipRejectedReason {
  return (ownershipRejectedReasons as readonly string[]).includes(value);
}
