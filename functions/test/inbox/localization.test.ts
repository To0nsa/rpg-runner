import assert from "node:assert/strict";
import { test } from "node:test";
import fixture from "../fixtures/localized_message.json";
import { parseOperatorMessage } from "../../src/inbox/operator.js";
import { levelUpDeliveries } from "../../src/inbox/level_rewards.js";
import { levelReachedText } from "../../src/inbox/message_text.js";
import { decodeSystemMessage } from "../../src/inbox/store.js";
import { parseMessageLocalization } from "../../src/inbox/localization.js";

test("automatic authored text matches the Dart consumer fixture", () => {
  const text = levelReachedText(2);
  assert.deepEqual(text, { title: fixture.title, body: fixture.body, localization: fixture.localization });
  assert.deepEqual(decodeSystemMessage(fixture, fixture.id, fixture.uid), fixture);
  for (const delivery of levelUpDeliveries(0, 1000000)) assert.ok(delivery.localization?.translations.fr);
});

test("operator translations normalize, sort and reject ambiguous/incomplete envelopes", () => {
  const message = { uid: "player", sourceId: "translated", title: "Hello", body: "Gift" };
  const fr = { title: " Bonjour ", body: " Ton cadeau " };
  const localization = { schemaVersion: 1, translations: { "fr-CA": fr, fr } };
  const parsed = parseOperatorMessage({ ...message, localization }).delivery.localization!;
  assert.deepEqual(Object.keys(parsed.translations), ["fr", "fr-CA"]);
  assert.equal(parsed.translations.fr.title, "Bonjour");
  for (const bad of [null, {}, { ...localization, schemaVersion: 2 },
    { ...localization, extra: true }, { schemaVersion: 1, translations: {} },
    ...["en", "FR", "fr_ca", "__proto__"].map((locale) => ({ schemaVersion: 1, translations: { [locale]: fr } })),
    { schemaVersion: 1, translations: { fr: { ...fr, body: " " } } },
    { schemaVersion: 1, translations: { fr: { ...fr, title: "x".repeat(121) } } },
    { schemaVersion: 1, translations: { fr: { ...fr, extra: "x" } } },
  ]) assert.throws(() => parseMessageLocalization(bad), { code: "invalid-argument" });
});
