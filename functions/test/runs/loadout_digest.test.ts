import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { test } from "node:test";

import { canonicalJsonString, sha256Hex } from "../../src/ownership/hash.js";
import type { JsonValue } from "../../src/ownership/contracts.js";
import { canonicalLoadoutJson, loadoutSha256 } from "../../src/runs/loadout_digest.js";

// The compiled test remains at functions/lib_test/test/runs; the fixture is
// deliberately shared with the Dart package instead of copied into each suite.
const fixtures = JSON.parse(readFileSync(resolve(
  __dirname, "../../../../packages/run_protocol/test/fixtures/loadout_digest_v1.json",
), "utf8")) as {
  valid: Array<{ name: string; input: Record<string, unknown>; canonicalJson: string; sha256: string }>;
  invalid: Array<{ name: string; input: Record<string, unknown> }>;
};

for (const fixture of fixtures.valid) {
  test(`shared loadout fixture: ${fixture.name}`, () => {
    assert.equal(canonicalLoadoutJson(fixture.input), fixture.canonicalJson);
    assert.equal(loadoutSha256(fixture.input), fixture.sha256);
  });
}
for (const fixture of fixtures.invalid) {
  test(`shared loadout rejection: ${fixture.name}`, () => {
    assert.throws(() => loadoutSha256(fixture.input), TypeError);
  });
}
test("authorized loadout digest is unchanged from issued tickets", () => {
  const fixture = fixtures.valid.find((value) => value.name === "authorized_loadout")!;
  assert.equal(sha256Hex(canonicalJsonString(fixture.input as JsonValue)), fixture.sha256);
});
test("loadout rejects non-JSON values and non-finite numbers", () => {
  for (const value of [NaN, Infinity, undefined, new Date(), [undefined]]) {
    assert.throws(() => loadoutSha256({ x: value }), TypeError);
  }
});
