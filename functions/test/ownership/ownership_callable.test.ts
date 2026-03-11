import assert from "node:assert/strict";
import { after, beforeEach, test } from "node:test";

import { deleteApp, getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, type Firestore } from "firebase-admin/firestore";

import { loadOrCreateCanonicalState } from "../../src/ownership/canonical_store.js";
import { executeOwnershipCommand } from "../../src/ownership/command_executor.js";
import type {
  OwnershipCanonicalState,
  OwnershipCommandEnvelope,
} from "../../src/ownership/contracts.js";
import { defaultCanonicalProfileId } from "../../src/ownership/firestore_paths.js";
import {
  loadOrCreatePlayerProfile,
  updatePlayerProfile,
} from "../../src/profile/store.js";

const firestoreEmulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
if (!firestoreEmulatorHost) {
  throw new Error(
    "FIRESTORE_EMULATOR_HOST is not set. Run via `firebase emulators:exec`.",
  );
}

const emulatorProjectIdBase =
  process.env.GCLOUD_PROJECT ?? "demo-rpg-runner-functions-tests";
const projectId = `${emulatorProjectIdBase}-ownership`;
const appName = `ownership-tests-${process.pid}-${Date.now()}`;
const app = initializeApp({ projectId }, appName);
const db = getFirestore(app);

const profileId = defaultCanonicalProfileId;
const uid = "uid_owner";
const sessionId = "session_1";
const maxAwardRunGold = 10_000;

beforeEach(async () => {
  await Promise.all([
    clearOwnershipCollections(db),
    clearPlayerProfiles(db),
    clearDisplayNameIndex(db),
  ]);
});

after(async () => {
  await Promise.all(getApps().map((value) => deleteApp(value)));
});

test("loadOrCreateCanonicalState creates starter canonical state", async () => {
  const canonical = await loadOrCreateCanonicalState({
    db,
    uid,
  });

  assert.equal(canonical.profileId, profileId);
  assert.equal(canonical.revision, 0);
  assert.equal(canonical.progression.gold, 0);
  assert.equal(
    loadoutFor(canonical, "eloise").projectileSlotSpellId,
    "acidBolt",
  );
});

test("accepted command increments revision and persists canonical mutation", async () => {
  const result = await executeOwnershipCommand({
    db,
    uid,
    command: setProjectileSpellCommand({
      expectedRevision: 0,
      commandId: "cmd_accept_1",
      spellId: "holyBolt",
    }),
  });

  assert.equal(result.rejectedReason, null);
  assert.equal(result.replayedFromIdempotency, false);
  assert.equal(result.newRevision, 1);
  assert.equal(
    loadoutFor(result.canonicalState, "eloise").projectileSlotSpellId,
    "holyBolt",
  );

  const persisted = await loadOrCreateCanonicalState({ db, uid });
  assert.equal(persisted.revision, 1);
  assert.equal(
    loadoutFor(persisted, "eloise").projectileSlotSpellId,
    "holyBolt",
  );
});

test("awardRunGold increments canonical progression and is idempotent", async () => {
  const command = awardRunGoldCommand({
    expectedRevision: 0,
    commandId: "cmd_award_gold",
    runId: 77,
    goldEarned: 9,
  });

  const first = await executeOwnershipCommand({ db, uid, command });
  const replay = await executeOwnershipCommand({ db, uid, command });

  assert.equal(first.rejectedReason, null);
  assert.equal(first.canonicalState.progression.gold, 9);
  assert.equal(replay.replayedFromIdempotency, true);
  assert.equal(replay.canonicalState.progression.gold, 9);

  const duplicateRun = await executeOwnershipCommand({
    db,
    uid,
    command: awardRunGoldCommand({
      expectedRevision: first.newRevision,
      commandId: "cmd_award_gold_duplicate_run",
      runId: 77,
      goldEarned: 9,
    }),
  });
  assert.equal(duplicateRun.rejectedReason, null);
  assert.equal(duplicateRun.canonicalState.progression.gold, 9);
});

test("awardRunGold rejects oversized gold payload", async () => {
  const result = await executeOwnershipCommand({
    db,
    uid,
    command: awardRunGoldCommand({
      expectedRevision: 0,
      commandId: "cmd_award_gold_oversized",
      runId: 88,
      goldEarned: maxAwardRunGold + 1,
    }),
  });

  assert.equal(result.rejectedReason, "invalidCommand");
  assert.equal(result.canonicalState.progression.gold, 0);
});

test("stale revision returns staleRevision and leaves canonical unchanged", async () => {
  const accepted = await executeOwnershipCommand({
    db,
    uid,
    command: setProjectileSpellCommand({
      expectedRevision: 0,
      commandId: "cmd_stale_accept",
      spellId: "holyBolt",
    }),
  });
  assert.equal(accepted.rejectedReason, null);
  assert.equal(accepted.newRevision, 1);

  const stale = await executeOwnershipCommand({
    db,
    uid,
    command: setProjectileSpellCommand({
      expectedRevision: 0,
      commandId: "cmd_stale_reject",
      spellId: "acidBolt",
    }),
  });
  assert.equal(stale.rejectedReason, "staleRevision");
  assert.equal(stale.newRevision, 1);
  assert.equal(
    loadoutFor(stale.canonicalState, "eloise").projectileSlotSpellId,
    "holyBolt",
  );
});

test("idempotency replay returns prior result for identical command payload", async () => {
  const command = setProjectileSpellCommand({
    expectedRevision: 0,
    commandId: "cmd_replay_same",
    spellId: "holyBolt",
  });

  const first = await executeOwnershipCommand({
    db,
    uid,
    command,
  });
  const replay = await executeOwnershipCommand({
    db,
    uid,
    command,
  });

  assert.equal(first.rejectedReason, null);
  assert.equal(first.newRevision, 1);
  assert.equal(first.replayedFromIdempotency, false);
  assert.equal(replay.rejectedReason, null);
  assert.equal(replay.newRevision, 1);
  assert.equal(replay.replayedFromIdempotency, true);
});

test("idempotency mismatch rejects reused commandId with different payload", async () => {
  await executeOwnershipCommand({
    db,
    uid,
    command: setProjectileSpellCommand({
      expectedRevision: 0,
      commandId: "cmd_replay_mismatch",
      spellId: "holyBolt",
    }),
  });

  const mismatch = await executeOwnershipCommand({
    db,
    uid,
    command: setProjectileSpellCommand({
      expectedRevision: 0,
      commandId: "cmd_replay_mismatch",
      spellId: "acidBolt",
    }),
  });

  assert.equal(mismatch.rejectedReason, "idempotencyKeyReuseMismatch");
  assert.equal(mismatch.replayedFromIdempotency, false);
  assert.equal(mismatch.newRevision, 1);
});

test("command actor mismatch rejects with forbidden", async () => {
  const forbidden = await executeOwnershipCommand({
    db,
    uid,
    command: setProjectileSpellCommand({
      expectedRevision: 0,
      commandId: "cmd_forbidden",
      spellId: "holyBolt",
      userId: "uid_attacker",
    }),
  });

  assert.equal(forbidden.rejectedReason, "forbidden");
  assert.equal(forbidden.newRevision, 0);
});

test("equipGear keeps meta and selection gear in sync", async () => {
  const result = await executeOwnershipCommand({
    db,
    uid,
    command: {
      type: "equipGear",
      userId: uid,
      sessionId,
      expectedRevision: 0,
      commandId: "cmd_equip_gear",
      payload: {
        characterId: "eloise",
        slot: "spellBook",
        itemDomain: "spellBook",
        itemId: "bastionCodex",
      },
    },
  });

  assert.equal(result.rejectedReason, null);
  assert.equal(result.newRevision, 1);
  assert.equal(
    loadoutFor(result.canonicalState, "eloise").spellBookId,
    "bastionCodex",
  );
  assert.equal(
    equippedFor(result.canonicalState, "eloise").spellBookId,
    "bastionCodex",
  );
});

test("invalid character payload rejects with invalidCommand", async () => {
  const invalid = await executeOwnershipCommand({
    db,
    uid,
    command: {
      type: "setAbilitySlot",
      userId: uid,
      sessionId,
      expectedRevision: 0,
      commandId: "cmd_invalid_character",
      payload: {
        characterId: "unknownCharacter",
        slot: "spell",
        abilityId: "eloise.focus",
      },
    },
  });

  assert.equal(invalid.rejectedReason, "invalidCommand");
  assert.equal(invalid.newRevision, 0);
});

test("loadOrCreatePlayerProfile creates a default remote profile", async () => {
  const loaded = await loadOrCreatePlayerProfile({ db, uid });

  assert.equal(loaded.displayName, "");
  assert.equal(loaded.displayNameLastChangedAtMs, 0);
  assert.equal(loaded.namePromptCompleted, false);
});

test("updatePlayerProfile persists name and onboarding flag", async () => {
  const updated = await updatePlayerProfile({
    db,
    uid,
    displayName: "HeroName",
    displayNameLastChangedAtMs: 1700000000000,
    namePromptCompleted: true,
  });
  assert.equal(updated.displayName, "HeroName");
  assert.equal(updated.displayNameLastChangedAtMs, 1700000000000);
  assert.equal(updated.namePromptCompleted, true);

  const loaded = await loadOrCreatePlayerProfile({ db, uid });
  assert.equal(loaded.displayName, "HeroName");
  assert.equal(loaded.displayNameLastChangedAtMs, 1700000000000);
  assert.equal(loaded.namePromptCompleted, true);
});

test("updatePlayerProfile rejects duplicate normalized name across users", async () => {
  await updatePlayerProfile({
    db,
    uid: "uid_primary",
    displayName: "Hero Name",
    displayNameLastChangedAtMs: 100,
  });

  await assert.rejects(
    () =>
      updatePlayerProfile({
        db,
        uid: "uid_secondary",
        displayName: "hero   name",
        displayNameLastChangedAtMs: 101,
      }),
    (error: { code?: string }) => error.code === "already-exists",
  );
});

test("updatePlayerProfile rename releases prior name for another user", async () => {
  await updatePlayerProfile({
    db,
    uid: "uid_primary",
    displayName: "Alpha",
    displayNameLastChangedAtMs: 100,
  });
  await updatePlayerProfile({
    db,
    uid: "uid_primary",
    displayName: "Beta",
    displayNameLastChangedAtMs: 101,
  });

  const claimed = await updatePlayerProfile({
    db,
    uid: "uid_secondary",
    displayName: "alpha",
    displayNameLastChangedAtMs: 102,
  });
  assert.equal(claimed.displayName, "alpha");
});

function setProjectileSpellCommand(args: {
  expectedRevision: number;
  commandId: string;
  spellId: string;
  userId?: string;
}): OwnershipCommandEnvelope {
  return {
    type: "setProjectileSpell",
    userId: args.userId ?? uid,
    sessionId,
    expectedRevision: args.expectedRevision,
    commandId: args.commandId,
    payload: {
      characterId: "eloise",
      spellId: args.spellId,
    },
  };
}

function awardRunGoldCommand(args: {
  expectedRevision: number;
  commandId: string;
  runId: number;
  goldEarned: number;
  userId?: string;
}): OwnershipCommandEnvelope {
  return {
    type: "awardRunGold",
    userId: args.userId ?? uid,
    sessionId,
    expectedRevision: args.expectedRevision,
    commandId: args.commandId,
    payload: {
      runId: args.runId,
      goldEarned: args.goldEarned,
    },
  };
}

function loadoutFor(
  canonical: OwnershipCanonicalState,
  characterId: string,
): Record<string, unknown> {
  const selection = asRecord(canonical.selection);
  const loadoutsByCharacter = asRecord(selection.loadoutsByCharacter);
  return asRecord(loadoutsByCharacter[characterId]);
}

function equippedFor(
  canonical: OwnershipCanonicalState,
  characterId: string,
): Record<string, unknown> {
  const meta = asRecord(canonical.meta);
  const equippedByCharacter = asRecord(meta.equippedByCharacter);
  return asRecord(equippedByCharacter[characterId]);
}

function asRecord(value: unknown): Record<string, unknown> {
  if (value !== null && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  throw new Error(`Expected record value, got ${typeof value}`);
}

async function clearOwnershipCollections(dbValue: Firestore): Promise<void> {
  const docs = await dbValue.collection("ownership_profiles").listDocuments();
  await Promise.all(docs.map((docRef) => dbValue.recursiveDelete(docRef)));
}

async function clearPlayerProfiles(dbValue: Firestore): Promise<void> {
  const docs = await dbValue.collection("player_profiles").listDocuments();
  await Promise.all(docs.map((docRef) => dbValue.recursiveDelete(docRef)));
}

async function clearDisplayNameIndex(dbValue: Firestore): Promise<void> {
  const docs = await dbValue.collection("display_name_index").listDocuments();
  await Promise.all(docs.map((docRef) => dbValue.recursiveDelete(docRef)));
}
