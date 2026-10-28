import assert from "node:assert/strict";
import { test } from "node:test";
import { parseOperatorMessage } from "../../src/inbox/operator.js";
import { systemMessageId } from "../../src/inbox/store.js";

const input = { uid: "player", sourceId: "gift-1", title: "Title", body: "Message", goldAmount: 25 };

test("operator validation normalizes text and preserves retry identity", () => {
  const parsed = parseOperatorMessage({ ...input, title: "  Title  ", body: " Message\n " });
  assert.deepEqual(parsed, { uid: "player", messageId: systemMessageId("player", "operator:gift-1"),
    delivery: { sourceId: "operator:gift-1", title: "Title", body: "Message", goldAmount: 25 } });
  const { goldAmount, ...informationOnly } = input;
  assert.equal(parseOperatorMessage(informationOnly).delivery.goldAmount, 0);
});

test("operator input rejects unsafe identities, attachments and gold", () => {
  for (const patch of [
    { uid: "users/player" }, { uid: ".." }, { uid: "__reserved__" }, { uid: "" },
    { sourceId: " " }, { sourceId: "x".repeat(181) }, { title: "x".repeat(121) },
    { body: "x".repeat(2001) }, { goldAmount: -1 }, { goldAmount: 1.5 },
    { goldAmount: Number.MAX_SAFE_INTEGER + 1 }, { goldAmount: "25" },
    { rewards: [{ kind: "item" }] }, { projectId: "other-project" },
  ]) assert.throws(() => parseOperatorMessage({ ...input, ...patch }), { code: "invalid-argument" });
});
