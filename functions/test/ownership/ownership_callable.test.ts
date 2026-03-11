import assert from "node:assert/strict";
import { after, beforeEach, test } from "node:test";

import { deleteApp, getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, type Firestore } from "firebase-admin/firestore";

import { loadOrCreateCanonicalState } from "../../src/ownership/canonical_store.js";
import { executeOwnershipCommand } from "../../src/ownership/command_executor.js";
import {
  loadPlayerDisplayName,
  savePlayerDisplayName,
} from "../../src/profile/store.js";
import type {
  JsonObject,
  OwnershipCanonicalState,
  OwnershipCommandEnvelope,
} from "../../src/ownership/contracts.js";

const firestoreEmulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
if (!firestoreEmulatorHost) {
  throw new Error(
    "FIRESTORE_EMULATOR_HOST is not set. Run via `firebase emulators:exec`.",
  );
}

const projectId = process.env.GCLOUD_PROJECT ?? "demo-rpg-runner-functions-tests";
const appName = `ownership-tests-${process.pid}-${Date.now()}`;
const app = initializeApp({ projectId }, appName);
const db = getFirestore(app);

const profileId = "profile_ownership_test";
const uid = "uid_owner";
const sessionId = "session_1";

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
    profileId,
  });

  assert.equal(canonical.profileId, profileId);
  assert.equal(canonical.revision, 0);
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

  const persisted = await loadOrCreateCanonicalState({ db, uid, profileId });
  assert.equal(persisted.revision, 1);
  assert.equal(
    loadoutFor(persisted, "eloise").projectileSlotSpellId,
    "holyBolt",
  );
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
      profileId,
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
      profileId,
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

test("savePlayerDisplayName persists and loadPlayerDisplayName returns profile", async () => {
  const saved = await savePlayerDisplayName({
    db,
    uid,
    displayName: "HeroName",
    displayNameLastChangedAtMs: 1700000000000,
  });
  assert.equal(saved.displayName, "HeroName");
  assert.equal(saved.displayNameLastChangedAtMs, 1700000000000);

  const loaded = await loadPlayerDisplayName({ db, uid });
  assert.notEqual(loaded, null);
  assert.equal(loaded?.displayName, "HeroName");
  assert.equal(loaded?.displayNameLastChangedAtMs, 1700000000000);
});

test("loadPlayerDisplayName returns null when profile is missing", async () => {
  const loaded = await loadPlayerDisplayName({ db, uid: "uid_missing_profile" });
  assert.equal(loaded, null);
});

test("savePlayerDisplayName rejects duplicate normalized name across users", async () => {
  await savePlayerDisplayName({
    db,
    uid: "uid_primary",
    displayName: "Hero Name",
    displayNameLastChangedAtMs: 100,
  });

  await assert.rejects(
    () =>
      savePlayerDisplayName({
        db,
        uid: "uid_secondary",
        displayName: "hero   name",
        displayNameLastChangedAtMs: 101,
      }),
    (error: { code?: string }) => error.code === "already-exists",
  );
});

test("savePlayerDisplayName rename releases prior name for another user", async () => {
  await savePlayerDisplayName({
    db,
    uid: "uid_primary",
    displayName: "Alpha",
    displayNameLastChangedAtMs: 100,
  });
  await savePlayerDisplayName({
    db,
    uid: "uid_primary",
    displayName: "Beta",
    displayNameLastChangedAtMs: 101,
  });

  const claimed = await savePlayerDisplayName({
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
    profileId,
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
