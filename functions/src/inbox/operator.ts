import { randomUUID } from "node:crypto";
import { deleteApp, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import { assertCallablePayloadBounds } from "../abuse/payload_bounds.js";
import { requireObject } from "../ownership/validators.js";
import { issueSystemMessage, systemMessageId } from "./store.js";
import { boundedText, safeInteger } from "./validators.js";
import { giftsEnabled, inboxGiftCatalog, inboxGiftCatalogHash, inboxGiftConfigurationPath, parseInboxRewards } from "./gifts.js";
import { knownCharacterIds } from "../ownership/defaults.js";
import type { InboxCatalogReward } from "./contracts.js";

/** Offline validation shared by privileged tools; accepts only existing allowlisted unlocks and gold. */
export function parseOperatorMessage(input: unknown) {
  assertCallablePayloadBounds(input);
  const raw = requireObject(input, "message");
  const fields = ["uid", "sourceId", "title", "body", "goldAmount", "attachments"];
  if (Object.keys(raw).some((key) => !fields.includes(key))) {
    throw new HttpsError("invalid-argument", "Unknown message field.");
  }
  const uid = boundedText(raw.uid, "uid", 128);
  // Firebase UIDs need not match command-ID syntax, but must be a single document ID.
  if (uid.includes("/") || uid === "." || uid === ".." || /^__.*__$/.test(uid)) {
    throw new HttpsError("invalid-argument", "Invalid uid.");
  }
  const attachments = parseInboxRewards(raw.attachments ?? []);
  if (attachments.some((reward) => reward.kind === "gold")) throw new HttpsError("invalid-argument", "Use goldAmount for gold.");
  if (attachments.length > 8) throw new HttpsError("invalid-argument", "Use at most eight item/skill gifts.");
  const delivery = {
    sourceId: `operator:${boundedText(raw.sourceId, "sourceId", 180)}`,
    title: boundedText(raw.title, "title", 120),
    body: boundedText(raw.body, "body", 2000),
    goldAmount: safeInteger(raw.goldAmount ?? 0, "goldAmount"),
    ...(attachments.length > 0 ? { attachments: attachments as InboxCatalogReward[] } : {}),
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

/** Reads an explicit environment's rollout gate; it never enables gifts or mutates data. */
export async function loadOperatorGiftCatalog(projectId: string) {
  if (!/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(projectId)) throw new Error("Invalid project ID.");
  const app = initializeApp({ projectId }, `inbox-catalog-${randomUUID()}`);
  try {
    const doc = await getFirestore(app).doc(inboxGiftConfigurationPath).get();
    const enabled = giftsEnabled(doc.data());
    return { enabled, catalogHash: inboxGiftCatalogHash, characters: [...knownCharacterIds],
      entries: enabled ? inboxGiftCatalog : [],
      message: enabled ? null : "Item and skill gifts require a compatible app/backend rollout in this environment." };
  } finally { await deleteApp(app); }
}
