import assert from "node:assert/strict";
import { test } from "node:test";
import fixture from "../fixtures/achievement_progress.json";
import {
  applyRunAchievements, claimAchievementGold, initialAchievementProgress,
  readAchievementProgress,
} from "../../src/ownership/achievements.js";
import type { JsonObject } from "../../src/ownership/contracts.js";
import { parseExecuteCommandRequest } from "../../src/ownership/validators.js";

const nowMs = Date.UTC(2026, 9, 30, 23, 59);
function evidence(patch: Record<string, unknown> = {}) {
  return {
    accepted: true, distanceMeters: 1500, durationSeconds: 120,
    endedReason: "playerDied", playerRunStats: { schemaVersion: 1, damageDealt100: 0, damageTaken100: 1 },
    codex: { schemaVersion: 1, levelId: "forest", enemyKills: { grojib: 30 } }, ...patch,
  };
}

test("achievement payload fixture is produced by the real evaluator and claim path", () => {
  assert.deepEqual(initialAchievementProgress(), fixture.empty);
  const progression: JsonObject = { gold: 0 };
  assert.equal(applyRunAchievements({ progression, validatedRun: evidence(), nowMs }), true);
  assert.deepEqual(progression.achievements, fixture.earned);
  assert.equal(progression.gold, 0, "earning a tier does not pay gold");
  claimAchievementGold(progression, null, nowMs + 60000);
  assert.deepEqual(progression.achievements, fixture.claimed);
  assert.equal(progression.gold, 175);
});

for (const [distanceMeters, durationSeconds, completedRuns] of [
  [0, 0, 0], [10, 10, 0], [99, 29, 0], [100, 0, 1], [0, 30, 1], [100, 30, 1],
] as const) {
  for (const endedReason of ["playerDied", "fellIntoGap", "fellBehindCamera", "bossEncounterFailed", "gaveUp"]) {
    test(`achievement eligibility: ${endedReason}, ${distanceMeters} m / ${durationSeconds} s`, () => {
      const progression: JsonObject = { gold: 0 };
      assert.equal(applyRunAchievements({ progression,
        validatedRun: evidence({ distanceMeters, durationSeconds, endedReason }), nowMs }), true);
      const entries = readAchievementProgress(progression.achievements).entries;
      assert.deepEqual(entries.map((entry) => entry.value), [
        endedReason === "gaveUp" ? 0 : completedRuns,
        distanceMeters, distanceMeters, durationSeconds, 30,
      ]);
      assert.equal(entries[4].tiers[0].achievedAtMs, nowMs, "verified kills can earn Slayer on any run");
      assert.equal(progression.gold, 0, "achievement gold still requires a claim");
    });
  }
}

test("a long manual quit earns metric tiers without counting a completed run", () => {
  const progression: JsonObject = { gold: 0 };
  applyRunAchievements({ progression,
    validatedRun: evidence({ endedReason: "gaveUp", durationSeconds: 300 }), nowMs });
  const entries = readAchievementProgress(progression.achievements).entries;
  assert.deepEqual(entries.map((entry) => entry.value), [0, 1500, 1500, 300, 30]);
  assert.equal(entries[0].tiers[0].achievedAtMs, null);
  assert.ok(entries.slice(1).every((entry) => entry.tiers[0].achievedAtMs === nowMs));
  claimAchievementGold(progression, null, nowMs + 1);
  assert.equal(progression.gold, 175);
});

test("legacy evidence grants no progress, and old totals are not backfilled", () => {
  const progression: JsonObject = {
    gold: 50, enemyDefeats: { byEnemy: { grojib: 90000 } },
    playerProgress: { acceptedRuns: 1000 },
  };
  assert.equal(applyRunAchievements({ progression, validatedRun: { accepted: true }, nowMs }), false);
  applyRunAchievements({ progression, validatedRun: evidence(), nowMs });
  const entries = readAchievementProgress(progression.achievements).entries;
  assert.equal(entries[0].value, 1);
  assert.equal(entries[4].value, 30);
  assert.equal(progression.gold, 50);
});

test("best distance uses a maximum; totals add; earned dates survive later runs and claims", () => {
  const progression: JsonObject = { gold: 0 };
  applyRunAchievements({ progression, validatedRun: evidence(), nowMs });
  applyRunAchievements({ progression,
    validatedRun: evidence({ distanceMeters: 500, durationSeconds: 180 }), nowMs: nowMs + 1 });
  const entries = readAchievementProgress(progression.achievements).entries;
  assert.equal(entries[1].value, 1500);
  assert.equal(entries[2].value, 2000);
  assert.equal(entries[3].value, 300);
  assert.equal(entries[1].tiers[1].achievedAtMs, nowMs);
  assert.equal(entries[3].tiers[0].achievedAtMs, nowMs + 1);
  claimAchievementGold(progression, "marathoner", nowMs + 10);
  assert.equal(progression.gold, 100);
  claimAchievementGold(progression, "marathoner", nowMs + 20);
  assert.equal(progression.gold, 100);
  assert.equal(readAchievementProgress(progression.achievements).entries[1].tiers[0].achievedAtMs, nowMs);
  const before = structuredClone(readAchievementProgress(progression.achievements));
  applyRunAchievements({ progression,
    validatedRun: evidence({ distanceMeters: 1, durationSeconds: 1, endedReason: "gaveUp" }), nowMs: nowMs + 30 });
  const after = readAchievementProgress(progression.achievements);
  assert.deepEqual(after.entries[0], before.entries[0], "a quit preserves previously completed runs");
  assert.deepEqual(after.entries[1], before.entries[1], "a shorter quit preserves best distance and receipts");
  assert.equal(after.entries[2].value, 2001);
  assert.equal(after.entries[3].value, 301);
  assert.equal(after.entries[4].value, 90);
});

test("snapshotted rewards survive tuning; final tiers remain claimable", () => {
  const progression: JsonObject = { gold: 0 };
  applyRunAchievements({ progression,
    validatedRun: evidence({ distanceMeters: 50000, durationSeconds: 18000,
      codex: { schemaVersion: 1, enemyKills: { grojib: 2500 } } }), nowMs });
  const progress = readAchievementProgress(progression.achievements);
  progress.entries[1].tiers[0].goldAmount = 26;
  progression.achievements = progress;
  assert.equal(claimAchievementGold(progression, "marathoner", nowMs + 1), true);
  assert.equal(progression.gold, 251);
  assert.equal(claimAchievementGold(progression, "unknown", nowMs), false);
});

test("malformed evidence, corrupt receipts and overflow fail without a partial grant", () => {
  for (const patch of [{ distanceMeters: -1 }, { durationSeconds: 1.5 },
    { endedReason: "unknown" }, { accepted: false },
    { codex: { schemaVersion: 1, enemyKills: { grojib: -1 } } },
    { endedReason: "gaveUp", codex: { schemaVersion: 1, enemyKills: { grojib: -1 } } }]) {
    assert.throws(() => applyRunAchievements({ progression: { gold: 0 },
      validatedRun: evidence(patch), nowMs }));
  }
  const corrupt = initialAchievementProgress();
  corrupt.entries[0].tiers[0].claimedAtMs = nowMs;
  assert.throws(() => readAchievementProgress(corrupt));
  const progression: JsonObject = { gold: Number.MAX_SAFE_INTEGER };
  applyRunAchievements({ progression, validatedRun: evidence(), nowMs });
  const before = structuredClone(progression);
  assert.throws(() => claimAchievementGold(progression, null, nowMs));
  assert.deepEqual(progression, before);
});

test("claim wire accepts only an achievement selector, never client amounts or timestamps", () => {
  const command = { type: "claimAchievements", userId: "u", sessionId: "s",
    commandId: "claim-test", expectedRevision: 0, payload: { achievementId: null } };
  assert.equal(parseExecuteCommandRequest({ command }).command.type, "claimAchievements");
  for (const payload of [{}, { achievementId: 1 }, { achievementId: null, goldAmount: 999 },
    { achievementId: "firstSteps", achievedAtMs: nowMs }]) {
    assert.throws(() => parseExecuteCommandRequest({ command: { ...command, payload } }));
  }
});
