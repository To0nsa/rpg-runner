import assert from "node:assert/strict";
import { test } from "node:test";
import { choosePracticeSeed, practiceSeedsForLevel } from "../../src/runs/practice_routes.js";
import { buildDeterministicSeed } from "../../src/boards/provisioning.js";
import { currentGameCompatVersion } from "../../src/runs/compatibility.js";
import plan from "../../src/runs/navigation_routes.json";

test("prepared Practice pools are distinct and never immediately repeat", () => {
  for (const level of Object.keys(plan.practiceSeeds)) {
    const seeds = practiceSeedsForLevel(level);
    assert.equal(seeds.length, 16);
    for (const previous of seeds) {
      for (let i = 0; i < 20; i++) {
        const next = choosePracticeSeed(level, previous);
        assert.ok(seeds.includes(next));
        assert.notEqual(next, previous);
      }
    }
  }
  assert.throws(() => practiceSeedsForLevel("unknown"));
});

test("prepared ranked routes retain the production board seed algorithm", () => {
  for (const route of plan.additionalRoutes as Array<{
    levelId: string; seed: number; mode: "competitive" | "weekly";
    windowId: string; gameCompatVersion: string;
  }>) {
    assert.equal(route.gameCompatVersion, currentGameCompatVersion);
    assert.equal(route.seed, buildDeterministicSeed({
      ...route, rulesetVersion: "rules-v2", scoreVersion: "score-v4",
      seedNamespace: "rpg-runner-board-seed-v1",
    }));
  }
});
