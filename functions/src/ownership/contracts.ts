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
  "awardRunGold",
  "purchaseStoreOffer",
  "refreshStore",
] as const;

export type OwnershipCommandType = (typeof ownershipCommandTypes)[number];

export const clientOwnershipCommandTypes = [
  "setSelection",
  "setLoadout",
  "equipGear",
  "setAbilitySlot",
  "setProjectileSpell",
  "purchaseStoreOffer",
  "refreshStore",
] as const satisfies readonly OwnershipCommandType[];

export type ClientOwnershipCommandType =
  (typeof clientOwnershipCommandTypes)[number];

export const ownershipRejectedReasons = [
  "staleRevision",
  "idempotencyKeyReuseMismatch",
  "invalidCommand",
  "forbidden",
  "unauthorized",
  "insufficientGold",
  "offerUnavailable",
  "alreadyOwned",
  "refreshLimitReached",
  "invalidRefreshMethod",
  "rewardNotVerified",
  "rewardAlreadyConsumed",
  "rewardExpired",
  "nothingToRefresh",
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
  progression: JsonObject;
}

export interface OwnershipCommandEnvelope {
  type: OwnershipCommandType;
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
  progression: JsonObject;
  createdAt?: unknown;
  updatedAt?: unknown;
}

export interface IdempotencyDocument {
  payloadHash: string;
  schemaVersion?: unknown;
  outcome?: {
    resultingRevision?: unknown;
    rejectedReason?: unknown;
  };
  /** Legacy schema retained only for the bounded compaction migration. */
  result?: OwnershipCommandResult;
  createdAt?: unknown;
  createdAtMs?: unknown;
  expiresAtMs?: unknown;
}

export function isOwnershipCommandType(
  value: string,
): value is OwnershipCommandType {
  return (ownershipCommandTypes as readonly string[]).includes(value);
}

export function isClientOwnershipCommandType(
  value: OwnershipCommandType,
): value is ClientOwnershipCommandType {
  return (clientOwnershipCommandTypes as readonly string[]).includes(value);
}

export function isOwnershipRejectedReason(
  value: string,
): value is OwnershipRejectedReason {
  return (ownershipRejectedReasons as readonly string[]).includes(value);
}
