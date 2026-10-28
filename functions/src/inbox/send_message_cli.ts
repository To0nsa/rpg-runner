import { readFile } from "node:fs/promises";
import { parseArgs } from "node:util";
import { parseOperatorMessage, sendOperatorMessage } from "./operator.js";

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
  const { uid, delivery, messageId } = parseOperatorMessage(input);
  console.log(JSON.stringify({
    mode: values.send ? "send" : "preview",
    project: values.project ?? null,
    uid,
    messageId,
    ...delivery,
  }, null, 2));
  if (values.send) {
    if (!values.project) throw new Error("Sending requires --project.");
    await sendOperatorMessage(values.project, input);
    console.log("Message delivered (or already delivered with identical contents).");
  }
}

void main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : "Unable to send message.");
  process.exitCode = 1;
});
