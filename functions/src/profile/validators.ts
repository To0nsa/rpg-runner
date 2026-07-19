import { HttpsError } from "firebase-functions/v2/https";

import { assertCallablePayloadBounds } from "../abuse/payload_bounds.js";
import { requireNonEmptyString, requireObject } from "../ownership/validators.js";

interface LoadPlayerProfileRequest {
  userId: string;
  sessionId: string;
}

interface UpdatePlayerProfileRequest {
  userId: string;
  sessionId: string;
  displayName?: string;
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
  assertCallablePayloadBounds(raw);
  const data = requireObject(raw, "request");
  return {
    userId: requireNonEmptyString(data.userId, "userId"),
    sessionId: requireNonEmptyString(data.sessionId, "sessionId"),
  };
}

export function parseUpdatePlayerProfileRequest(
  raw: unknown,
): UpdatePlayerProfileRequest {
  assertCallablePayloadBounds(raw);
  const data = requireObject(raw, "request");
  if (Object.hasOwn(data, "displayNameLastChangedAtMs")) {
    throw new HttpsError(
      "invalid-argument",
      "displayNameLastChangedAtMs is server-controlled and must not be supplied.",
    );
  }
  const displayName = parseOptionalDisplayName(data.displayName);
  const namePromptCompleted = parseOptionalBoolean(
    data.namePromptCompleted,
    "namePromptCompleted",
  );

  const hasDisplayName = displayName !== undefined;
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
