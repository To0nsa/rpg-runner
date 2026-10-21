import type { Firestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import { assertAccountActive } from "../account/deletion_guard.js";
import { consumeUserQuota } from "../abuse/quota.js";
import { parseInboxRequest } from "./validators.js";
import { claimInboxReward, listInbox, loadInboxSummary, markInboxMessageRead } from "./store.js";

/** Authenticated inbox surface; reward issuance is never exposed to players. */
export async function handleInboxRequest(
  request: { auth?: { uid?: string } | null; data: unknown }, db: Firestore,
  operation: "summary" | "list" | "read" | "claim",
) {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentication required.");
  const parsed = parseInboxRequest(request.data, operation);
  if (parsed.userId !== uid) throw new HttpsError("permission-denied", "userId does not match auth uid.");
  await assertAccountActive(db, uid);
  await consumeUserQuota({ db, uid, route: operation === "summary" || operation === "list" ? "inbox_read" : "inbox_write" });
  switch (operation) {
    case "summary": return { summary: await loadInboxSummary(db, uid) };
    case "list": return listInbox(db, uid, parsed.cursor);
    case "read": return markInboxMessageRead(db, uid, parsed.messageId!);
    case "claim": return claimInboxReward({ db, uid, messageId: parsed.messageId!,
      commandId: parsed.commandId!, expectedRevision: parsed.expectedRevision! });
  }
}
