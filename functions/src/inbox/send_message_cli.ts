import { readFile } from "node:fs/promises";
import { parseArgs } from "node:util";
import { deleteApp, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { assertCallablePayloadBounds } from "../abuse/payload_bounds.js";
import { boundedText, safeInteger } from "./validators.js";
import { requireObject } from "../ownership/validators.js";
import { issueSystemMessage, systemMessageId } from "./store.js";

// Preview is offline. Sending requires both an explicit project and --send.
async function main(): Promise<void> {
  const { values } = parseArgs({
    options: {
      project: { type: "string" },
      file: { type: "string" },
      send: { type: "boolean", default: false },
    },
  });
  if (!values.file) {
    throw new Error("Use --file message.json [--project PROJECT --send].");
  }
  const input: unknown = JSON.parse(await readFile(values.file, "utf8"));
  assertCallablePayloadBounds(input);
  const raw = requireObject(input, "message");
  const fields = ["uid", "sourceId", "title", "body", "goldAmount"];
  if (Object.keys(raw).some((key) => !fields.includes(key))) {
    throw new Error("Unknown message field.");
  }
  const uid = boundedText(raw.uid, "uid", 128);
  const delivery = {
    sourceId: `operator:${boundedText(raw.sourceId, "sourceId", 180)}`,
    title: boundedText(raw.title, "title", 120),
    body: boundedText(raw.body, "body", 2000),
    goldAmount: safeInteger(raw.goldAmount ?? 0, "goldAmount"),
  };
  console.log(JSON.stringify({
    mode: values.send ? "send" : "preview",
    project: values.project ?? null,
    uid,
    messageId: systemMessageId(uid, delivery.sourceId),
    ...delivery,
  }, null, 2));
  if (values.send) {
    if (!values.project) throw new Error("Sending requires --project.");
    const app = initializeApp({ projectId: values.project });
    try {
      await issueSystemMessage({ db: getFirestore(app), uid, delivery });
      console.log("Message delivered (or already delivered with identical contents).");
    } finally {
      await deleteApp(app);
    }
  }
}

void main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : "Unable to send message.");
  process.exitCode = 1;
});
