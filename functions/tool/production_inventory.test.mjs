import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import test from "node:test";

import { buildManagedBoardId, resolveBoardProvisioningConfig } from "../lib/boards/provisioning.js";
import { resolveWindowForMode } from "../lib/boards/windowing.js";
import { starterCanonicalDocument } from "../lib/ownership/defaults.js";

const nowMs = Date.parse("2026-10-27T12:00:00Z");
const project = "inventory-regression-test";
const preload = `
  const fixture = JSON.parse(process.env.INVENTORY_TEST_FIXTURE);
  globalThis.fetch = async (url, options) => {
    if (options.method !== 'POST' || !url.startsWith('https://firestore.googleapis.com/v1/projects/${project}/')) {
      throw new Error('Unexpected request; test never permits live network access.');
    }
    let result;
    if (url.endsWith(':listCollectionIds')) result = { collectionIds: Object.keys(fixture) };
    else if (url.endsWith(':runQuery')) {
      const query = JSON.parse(options.body).structuredQuery;
      result = fixture[query.from[0].collectionId] ?? [];
    } else throw new Error('Unexpected Firestore operation.');
    return { ok: true, json: async () => result };
  };
`;

function encodeFields(value) {
  return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, encodeValue(item)]));
}

function encodeValue(value) {
  if (value === null) return { nullValue: null };
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "number") return { integerValue: String(value) };
  if (typeof value === "boolean") return { booleanValue: value };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(encodeValue) } };
  return { mapValue: { fields: encodeFields(value) } };
}

function boards(env = {}, next = false) {
  const config = resolveBoardProvisioningConfig(env);
  return ["competitive", "weekly"].flatMap((mode) => {
    const current = resolveWindowForMode(mode, nowMs);
    const window = next ? resolveWindowForMode(mode, current.closesAtMs + 1) : current;
    const levels = mode === "competitive" ? config.competitiveLevelIds : [config.weeklyLevelId];
    return levels.map((levelId) => {
      const key = { mode, levelId, windowId: window.windowId,
        rulesetVersion: config.rulesetVersion, scoreVersion: config.scoreVersion };
      const boardId = buildManagedBoardId({ ...key,
        gameCompatVersion: config.gameCompatVersion, ghostVersion: config.ghostVersion });
      return { document: {
        name: `projects/${project}/databases/(default)/documents/leaderboard_boards/${boardId}`,
        fields: encodeFields({ ...key, boardId, boardKey: key,
          gameCompatVersion: config.gameCompatVersion, ghostVersion: config.ghostVersion,
          opensAtMs: window.opensAtMs, closesAtMs: window.closesAtMs, status: "active" }),
      } };
    });
  });
}

function inventory(fixture, overrides = {}, ownership = []) {
  const env = Object.fromEntries(Object.entries(process.env).filter(([name]) =>
    !/^RUN_(BOARD_|COMPETITIVE_LEVEL_IDS|WEEKLY_LEVEL_ID)/.test(name)));
  const output = execFileSync(process.execPath, [
    "--import", `data:text/javascript,${encodeURIComponent(preload)}`,
    fileURLToPath(new URL("./production_inventory.mjs", import.meta.url)),
    "--project", project, "--now-ms", String(nowMs),
  ], { encoding: "utf8", timeout: 30000,
    env: { ...env, ...overrides, GCLOUD_ACCESS_TOKEN: "test-only-no-live-access",
      INVENTORY_TEST_FIXTURE: JSON.stringify({ leaderboard_boards: fixture, ownership_profiles: ownership }) } });
  const result = JSON.parse(output);
  assert.equal(result.readOnly, true);
  assert.equal(result.projectId, project);
  return result;
}

test("current boards satisfy release readiness without future boards", () => {
  const result = inventory(boards()).boards;
  assert.equal(result.expectedCurrentCount, 3);
  assert.equal(result.missingExpectedCurrentCount, 0);
  assert.equal(result.activeNowCount, 3);
  assert.equal(result.malformedCount, 0);
});

test("a missing current board remains a release blocker", () => {
  assert.equal(inventory(boards().slice(1)).boards.missingExpectedCurrentCount, 1);
});

test("future boards cannot stand in for current boards", () => {
  const result = inventory(boards({}, true)).boards;
  assert.equal(result.upcomingCount, 3);
  assert.equal(result.missingExpectedCurrentCount, 3);
});

test("readiness follows the provisioner's configured levels", () => {
  const env = { RUN_COMPETITIVE_LEVEL_IDS: "forest", RUN_WEEKLY_LEVEL_ID: "forest" };
  const result = inventory(boards(env), env).boards;
  assert.equal(result.expectedCurrentCount, 2);
  assert.equal(result.missingExpectedCurrentCount, 0);
});

test("current saved builds use confirmed progression during ownership inspection", () => {
  const profile = starterCanonicalDocument("owner", "owner");
  const document = () => ({ document: {
    name: `projects/${project}/databases/(default)/documents/ownership_profiles/owner`,
    fields: encodeFields(profile),
  } });
  assert.equal(inventory(boards(), {}, [document()]).ownership.unauthorizedSelectionCount, 0);
  profile.selection.buildsByCharacter.eloise.selectedBuildIndex = 1;
  assert.equal(inventory(boards(), {}, [document()]).ownership.unauthorizedSelectionCount, 1);
  profile.progression.playerProgress.totalXp = 100000;
  assert.equal(inventory(boards(), {}, [document()]).ownership.unauthorizedSelectionCount, 0);
});
