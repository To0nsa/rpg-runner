import { createHash } from "node:crypto";

import type { JsonValue } from "./contracts.js";

export function canonicalizeJson(value: JsonValue): JsonValue {
  if (Array.isArray(value)) {
    return value.map((item) => canonicalizeJson(item));
  }
  if (value !== null && typeof value === "object") {
    const sortedKeys = Object.keys(value).sort();
    const out: Record<string, JsonValue> = {};
    for (const key of sortedKeys) {
      out[key] = canonicalizeJson(value[key] as JsonValue);
    }
    return out;
  }
  return value;
}

export function canonicalJsonString(value: JsonValue): string {
  return JSON.stringify(canonicalizeJson(value));
}

export function sha256Hex(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}
