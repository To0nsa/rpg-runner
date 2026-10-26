import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { HttpsError } from "firebase-functions/v2/https";
import { assertSupportedGameCompatVersion, currentGameCompatVersion,
  resolveSupportedGameCompatVersions } from "../../src/runs/compatibility.js";

test("release pause rejects every new client, including a mistakenly allowed version", () => {
  for (const client of [currentGameCompatVersion, "2026.10.20", "2026.10.22"]) {
    assert.throws(() => assertSupportedGameCompatVersion(client,
      new Set(["release-paused", currentGameCompatVersion])), (error: unknown) => {
      assert.ok(error instanceof HttpsError);
      assert.equal(error.code, "unavailable");
      assert.deepEqual(error.details, { reason: "release-maintenance" });
      return true;
    });
  }
});

test("newer candidates wait for cutover; obsolete or unknown clients require an update", () => {
  for (const client of ["2026.10.22", "2026.10.21.1", "2026.11.1", "2027.1.1"]) {
    assert.throws(() => assertSupportedGameCompatVersion(client), (error: unknown) => {
      assert.ok(error instanceof HttpsError);
      assert.equal(error.code, "unavailable");
      assert.deepEqual(error.details, { reason: "release-maintenance" });
      return true;
    });
  }
  for (const client of ["2026.10.20", "2026.9.30", "unknown"]) {
    assert.throws(() => assertSupportedGameCompatVersion(client), (error: unknown) => {
      assert.ok(error instanceof HttpsError);
      assert.equal(error.code, "failed-precondition");
      assert.deepEqual(error.details, {
        reason: "update-required", gameCompatVersion: currentGameCompatVersion,
      });
      return true;
    });
  }
  assert.doesNotThrow(() => assertSupportedGameCompatVersion(currentGameCompatVersion));
});

test("gameplay release client, board default and worker share one compatibility", () => {
  assert.equal(currentGameCompatVersion, "2026.10.21");
  assert.throws(() => assertSupportedGameCompatVersion("2026.10.11.1", resolveSupportedGameCompatVersions({})));

  assert.deepEqual([...resolveSupportedGameCompatVersions({})], [currentGameCompatVersion]);
  const client = readFileSync("../lib/ui/state/app/app_state.dart", "utf8");
  const worker = readFileSync("../services/replay_validator/lib/src/validator_worker.dart", "utf8");
  assert.ok(client.includes(`_defaultGameCompatVersion = '${currentGameCompatVersion}'`));
  assert.ok(worker.replace(/\s+/g, "").includes(`_supportedGameCompatVersions=<String>{'${currentGameCompatVersion}',}`));
  assert.throws(() => assertSupportedGameCompatVersion("2026.09.6", resolveSupportedGameCompatVersions({})));
  assert.throws(() => assertSupportedGameCompatVersion("2026.09.7", resolveSupportedGameCompatVersions({})));
  assert.throws(() => assertSupportedGameCompatVersion("2026.09.9", resolveSupportedGameCompatVersions({})));
  assert.throws(() => assertSupportedGameCompatVersion("2026.09.10", resolveSupportedGameCompatVersions({})));
  assert.throws(() => assertSupportedGameCompatVersion("2026.10.1", resolveSupportedGameCompatVersions({})));
  assert.throws(() => assertSupportedGameCompatVersion("2026.10.2", resolveSupportedGameCompatVersions({})));
  assert.throws(() => assertSupportedGameCompatVersion("2026.10.3", resolveSupportedGameCompatVersions({})));
  assert.throws(() => assertSupportedGameCompatVersion("2026.10.4", resolveSupportedGameCompatVersions({})));

  assert.throws(() => assertSupportedGameCompatVersion("2026.10.5", resolveSupportedGameCompatVersions({})));

  assert.throws(() => assertSupportedGameCompatVersion("2026.10.6", resolveSupportedGameCompatVersions({})));
  assert.throws(() => assertSupportedGameCompatVersion("2026.10.7", resolveSupportedGameCompatVersions({})));
  assert.throws(() => assertSupportedGameCompatVersion("2026.10.8", resolveSupportedGameCompatVersions({})));
  assert.throws(() => assertSupportedGameCompatVersion("2026.10.9", resolveSupportedGameCompatVersions({})));
  assert.throws(() => assertSupportedGameCompatVersion("2026.10.10", resolveSupportedGameCompatVersions({})));
  assert.throws(() => assertSupportedGameCompatVersion("2026.10.16", resolveSupportedGameCompatVersions({})));

  assert.throws(() => assertSupportedGameCompatVersion("2026.10.17", resolveSupportedGameCompatVersions({})));

  const provisioning = readFileSync("src/boards/provisioning.ts", "utf8");
  assert.ok(provisioning.includes('defaultScoreVersion = "score-v4"'));
  assert.ok(worker.includes("_supportedScoreVersions = <String>{'score-v4'}"));
});
