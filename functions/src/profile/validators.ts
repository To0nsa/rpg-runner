import { HttpsError } from "firebase-functions/v2/https";

import { requireNonEmptyString, requireObject } from "../ownership/validators.js";

interface LoadPlayerProfileRequest {
  userId: string;
  sessionId: string;
}

interface UpdatePlayerProfileRequest {
  userId: string;
  sessionId: string;
  displayName?: string;
  displayNameLastChangedAtMs?: number;
  namePromptCompleted?: boolean;
}

const minDisplayNameLength = 3;
const maxDisplayNameLength = 16;
const displayNameAllowedPattern = /^[a-zA-Z0-9 _-]+$/;
const reservedDisplayNames = new Set<string>([
  "admin",
  "moderator",
  "mod",
  "support",
  "staff",
  "developer",
  "dev",
  "system",
]);
const bannedDisplayNameSubstrings = [
  "fuck",
  "shit",
  "bitch",
  "asshole",
  "cunt",
  "nazi",
];

export function parseLoadPlayerProfileRequest(
  raw: unknown,
): LoadPlayerProfileRequest {
  const data = requireObject(raw, "request");
  return {
    userId: requireNonEmptyString(data.userId, "userId"),
    sessionId: requireNonEmptyString(data.sessionId, "sessionId"),
  };
}

export function parseUpdatePlayerProfileRequest(
  raw: unknown,
): UpdatePlayerProfileRequest {
  const data = requireObject(raw, "request");
  const displayName = parseOptionalDisplayName(data.displayName);
  const displayNameLastChangedAtMs = parseOptionalNonNegativeInteger(
    data.displayNameLastChangedAtMs,
    "displayNameLastChangedAtMs",
  );
  const namePromptCompleted = parseOptionalBoolean(
    data.namePromptCompleted,
    "namePromptCompleted",
  );

  const hasDisplayName = displayName !== undefined;
  const hasDisplayNameTimestamp = displayNameLastChangedAtMs !== undefined;
  if (hasDisplayName != hasDisplayNameTimestamp) {
    throw new HttpsError(
      "invalid-argument",
      "displayName and displayNameLastChangedAtMs must be supplied together.",
    );
  }
  if (!hasDisplayName && namePromptCompleted === undefined) {
    throw new HttpsError(
      "invalid-argument",
      "At least one profile field must be updated.",
    );
  }

  return {
    userId: requireNonEmptyString(data.userId, "userId"),
    sessionId: requireNonEmptyString(data.sessionId, "sessionId"),
    displayName,
    displayNameLastChangedAtMs,
    namePromptCompleted,
  };
}

function parseOptionalDisplayName(value: unknown): string | undefined {
  if (value === undefined || value === null) {
    return undefined;
  }
  const displayName = requireNonEmptyString(value, "displayName").trim();
  validateDisplayName(displayName);
  return displayName;
}

function parseOptionalNonNegativeInteger(
  value: unknown,
  fieldName: string,
): number | undefined {
  if (value === undefined || value === null) {
    return undefined;
  }
  return requireNonNegativeInteger(value, fieldName);
}

function parseOptionalBoolean(
  value: unknown,
  fieldName: string,
): boolean | undefined {
  if (value === undefined || value === null) {
    return undefined;
  }
  if (typeof value !== "boolean") {
    throw new HttpsError("invalid-argument", `${fieldName} must be a boolean`);
  }
  return value;
}

function validateDisplayName(name: string): void {
  if (name.length < minDisplayNameLength) {
    throw new HttpsError(
      "invalid-argument",
      `displayName must be at least ${minDisplayNameLength} characters.`,
    );
  }
  if (name.length > maxDisplayNameLength) {
    throw new HttpsError(
      "invalid-argument",
      `displayName must be at most ${maxDisplayNameLength} characters.`,
    );
  }
  if (!displayNameAllowedPattern.test(name)) {
    throw new HttpsError(
      "invalid-argument",
      'displayName contains unsupported characters. Only letters, numbers, spaces, "_" and "-" are allowed.',
    );
  }

  const normalized = normalizeDisplayNameForPolicy(name);
  if (reservedDisplayNames.has(normalized)) {
    throw new HttpsError("invalid-argument", "displayName is reserved.");
  }
  for (const banned of bannedDisplayNameSubstrings) {
    if (normalized.includes(banned)) {
      throw new HttpsError("invalid-argument", "displayName is not allowed.");
    }
  }
}

export function normalizeDisplayNameForPolicy(value: string): string {
  return value.trim().replace(/\s+/g, " ").toLowerCase();
}

function requireNonNegativeInteger(value: unknown, fieldName: string): number {
  if (typeof value !== "number" || !Number.isInteger(value) || value < 0) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} must be a non-negative integer`,
    );
  }
  return value;
}
