import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { after, before, test } from "node:test";

import {
  assertFails,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";

const firestoreEmulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
if (!firestoreEmulatorHost) {
  throw new Error(
    "FIRESTORE_EMULATOR_HOST is not set. Run via `firebase emulators:exec`.",
  );
}

const [host, portRaw] = firestoreEmulatorHost.split(":");
const port = Number(portRaw);
assert.ok(host);
assert.ok(Number.isSafeInteger(port) && port > 0);

const serverOwnedDocumentPaths = [
  "ownership_profiles/profile_1",
  "ownership_profiles/profile_1/idempotency/command_1",
  "player_profiles/uid_1",
  "display_name_index/player-one",
  "account_deletion_requests/uid_1",
  "abuse_quota/uid_1",
  "run_sessions/run_1",
  "validated_runs/run_1",
  "reward_grants/run_1",
  "leaderboard_boards/board_1",
  "leaderboard_boards/board_1/player_bests/uid_1",
  "leaderboard_boards/board_1/ghost_manifests/entry_1",
  "leaderboard_boards/board_1/views/top10",
  "system_maintenance/job_1",
] as const;

let testEnvironment: RulesTestEnvironment;

before(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId: "demo-rpg-runner-firestore-rules-tests",
    firestore: {
      host,
      port,
      rules: readFileSync(resolve(process.cwd(), "../firestore.rules"), "utf8"),
    },
  });
});

after(async () => {
  await testEnvironment.cleanup();
});

test("direct clients cannot read or write server-owned documents", async () => {
  const clients = [
    testEnvironment.unauthenticatedContext().firestore(),
    testEnvironment.authenticatedContext("uid_rules").firestore(),
  ];

  for (const client of clients) {
    for (const path of serverOwnedDocumentPaths) {
      await assertFails(client.doc(path).get());
      await assertFails(client.doc(path).set({ attempted: true }));
    }
  }
});
