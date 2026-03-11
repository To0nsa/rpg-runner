import { HttpsError } from "firebase-functions/v2/https";

import { requireNonEmptyString, requireObject } from "../ownership/validators.js";

interface LoadPlayerProfileRequest {
  userId: string;
  sessionId: string;
}

interface SavePlayerDisplayNameRequest {
  userId: string;
  sessionId: string;
  displayName: string;
  displayNameLastChangedAtMs: number;
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

export function parseSavePlayerDisplayNameRequest(
  raw: unknown,
): SavePlayerDisplayNameRequest {
  const data = requireObject(raw, "request");
  const displayNameRaw = requireNonEmptyString(data.displayName, "displayName");
  const displayName = displayNameRaw.trim();
  validateDisplayName(displayName);
  return {
    userId: requireNonEmptyString(data.userId, "userId"),
    sessionId: requireNonEmptyString(data.sessionId, "sessionId"),
    displayName,
    displayNameLastChangedAtMs: requireNonNegativeInteger(
      data.displayNameLastChangedAtMs,
      "displayNameLastChangedAtMs",
    ),
  };
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
