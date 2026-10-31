import { HttpsError } from "firebase-functions/v2/https";

// Shared boundary validation must not initialize ownership catalogs.
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
