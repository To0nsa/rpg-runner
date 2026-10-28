import { HttpsError } from "firebase-functions/v2/https";
import { assertCallablePayloadBounds } from "../abuse/payload_bounds.js";
import { requireObject } from "../ownership/validators.js";
import type { InboxCursor } from "./contracts.js";

export type InboxOperation = "summary" | "list" | "read" | "claim" | "delete";

/** Reject unknown fields so clients cannot supply sender or reward contents. */
export function parseInboxRequest(raw: unknown, operation: InboxOperation) {
  assertCallablePayloadBounds(raw);
  const data = requireObject(raw, "request");
  const allowed = ["userId", ...(operation === "list" ? ["cursor"] : []),
    ...(["read", "claim", "delete"].includes(operation) ? ["messageId"] : []),
    ...(operation === "claim" ? ["commandId", "expectedRevision"] : [])];
  if (Object.keys(data).some((key) => !allowed.includes(key))) {
    throw new HttpsError("invalid-argument", "Unsupported inbox request field.");
  }
  const userId = boundedText(data.userId, "userId", 128);
  const messageId = ["read", "claim", "delete"].includes(operation)
    ? documentId(data.messageId, "messageId") : undefined;
  let cursor: InboxCursor | undefined;
  if (operation === "list" && data.cursor != null) {
    const value = requireObject(data.cursor, "cursor");
    if (Object.keys(value).some((key) => key !== "createdAtMs" && key !== "messageId")) {
      throw new HttpsError("invalid-argument", "Invalid inbox cursor.");
    }
    cursor = { createdAtMs: safeInteger(value.createdAtMs, "createdAtMs"),
      messageId: documentId(value.messageId, "cursor.messageId") };
  }
  return { userId, messageId, cursor,
    commandId: operation === "claim" ? documentId(data.commandId, "commandId") : undefined,
    expectedRevision: operation === "claim" ? safeInteger(data.expectedRevision, "expectedRevision") : undefined };
}

export function boundedText(raw: unknown, field: string, max: number): string {
  if (typeof raw !== "string" || raw.trim().length === 0 || raw.length > max) {
    throw new HttpsError("invalid-argument", `Invalid ${field}.`);
  }
  return raw.trim();
}

export function documentId(raw: unknown, field: string): string {
  const value = boundedText(raw, field, 128);
  if (!/^[a-zA-Z0-9_-]+$/.test(value)) {
    throw new HttpsError("invalid-argument", `Invalid ${field}.`);
  }
  return value;
}

export function safeInteger(raw: unknown, field: string): number {
  if (typeof raw !== "number" || !Number.isSafeInteger(raw) || raw < 0) {
    throw new HttpsError("invalid-argument", `Invalid ${field}.`);
  }
  return raw;
}
