import { randomUUID } from "node:crypto";
import { deleteApp, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import { assertCallablePayloadBounds } from "../abuse/payload_bounds.js";
import { requireObject } from "../ownership/validators.js";
import { issueSystemMessage, systemMessageId } from "./store.js";
import { boundedText, safeInteger } from "./validators.js";

/** Offline validation shared by privileged tools; never accepts reward types beyond gold. */
export function parseOperatorMessage(input: unknown) {
  assertCallablePayloadBounds(input);
  const raw = requireObject(input, "message");
  const fields = ["uid", "sourceId", "title", "body", "goldAmount"];
  if (Object.keys(raw).some((key) => !fields.includes(key))) {
    throw new HttpsError("invalid-argument", "Unknown message field.");
  }
  const uid = boundedText(raw.uid, "uid", 128);
  // Firebase UIDs need not match command-ID syntax, but must be a single document ID.
  if (uid.includes("/") || uid === "." || uid === ".." || /^__.*__$/.test(uid)) {
    throw new HttpsError("invalid-argument", "Invalid uid.");
  }
  const delivery = {
    sourceId: `operator:${boundedText(raw.sourceId, "sourceId", 180)}`,
    title: boundedText(raw.title, "title", 120),
    body: boundedText(raw.body, "body", 2000),
    goldAmount: safeInteger(raw.goldAmount ?? 0, "goldAmount"),
  };
  return { uid, delivery, messageId: systemMessageId(uid, delivery.sourceId) };
}

/** Uses local operator credentials and an explicit project; retries retain the source ID. */
export async function sendOperatorMessage(projectId: string, input: unknown): Promise<string> {
  const { uid, delivery } = parseOperatorMessage(input);
  if (!/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(projectId)) {
    throw new Error("A valid explicit project ID is required.");
  }
  const app = initializeApp({ projectId }, `inbox-operator-${randomUUID()}`);
  try {
    return await issueSystemMessage({ db: getFirestore(app), uid, delivery });
  } finally {
    await deleteApp(app);
  }
}
