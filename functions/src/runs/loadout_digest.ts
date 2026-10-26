import { createHash } from "node:crypto";

/**
 * Matches run_protocol's LoadoutDigest: safe integer numbers, well-formed
 * Unicode, UTF-16 key order and preserved array order. Replay-v1 bytes and
 * ownership command idempotency use their own existing encodings.
 */
export function canonicalLoadoutJson(value: Record<string, unknown>): string {
  return encode(value);
}

export function loadoutSha256(value: Record<string, unknown>): string {
  return createHash("sha256").update(canonicalLoadoutJson(value)).digest("hex");
}

function encode(value: unknown): string {
  if (Array.isArray(value)) {
    return `[${Array.from(value, encode).join(",")}]`;
  }
  if (value !== null && typeof value === "object") {
    const prototype = Object.getPrototypeOf(value);
    if (prototype !== Object.prototype && prototype !== null) {
      throw new TypeError("Loadout JSON requires plain objects.");
    }
    const object = value as Record<string, unknown>;
    // Emit keys directly: JSON.stringify(object) would reorder numeric keys.
    return `{${Object.keys(object).sort().map(
      (key) => `${encodeString(key)}:${encode(object[key])}`,
    ).join(",")}}`;
  }
  if (typeof value === "number") {
    if (!Number.isSafeInteger(value)) {
      throw new TypeError("Loadout JSON numbers must be safe integers.");
    }
    return String(value);
  }
  if (typeof value === "string") return encodeString(value);
  if (value === null || typeof value === "boolean") return JSON.stringify(value);
  throw new TypeError("Unsupported loadout JSON value.");
}

function encodeString(value: string): string {
  if (/[\uD800-\uDFFF]/u.test(value)) {
    throw new TypeError("Loadout JSON requires well-formed Unicode.");
  }
  return JSON.stringify(value);
}
