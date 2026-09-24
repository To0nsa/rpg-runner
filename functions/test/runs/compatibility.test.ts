import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { assertSupportedGameCompatVersion, currentGameCompatVersion,
  resolveSupportedGameCompatVersions } from "../../src/runs/compatibility.js";

test("gameplay release client, board default and worker share one compatibility", () => {
  assert.equal(currentGameCompatVersion, "2026.09.6");
  assert.deepEqual([...resolveSupportedGameCompatVersions({})], [currentGameCompatVersion]);
  const client = readFileSync("../lib/ui/state/app/app_state.dart", "utf8");
  const worker = readFileSync("../services/replay_validator/lib/src/validator_worker.dart", "utf8");
  assert.ok(client.includes(`_defaultGameCompatVersion = '${currentGameCompatVersion}'`));
  assert.ok(worker.includes(`_supportedGameCompatVersions = <String>{'${currentGameCompatVersion}'}`));
  assert.throws(() => assertSupportedGameCompatVersion("2026.09.5", resolveSupportedGameCompatVersions({})));
});
