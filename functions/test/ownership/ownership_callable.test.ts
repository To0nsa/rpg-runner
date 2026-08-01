import assert from "node:assert/strict";
import { after, beforeEach, test } from "node:test";

import { deleteApp, getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, type Firestore } from "firebase-admin/firestore";

import { loadOrCreateCanonicalState } from "../../src/ownership/canonical_store.js";
import { executeOwnershipCommand } from "../../src/ownership/command_executor.js";
import { starterSelection } from "../../src/ownership/defaults.js";
import { legacyReadReconciliationEnabled } from "../../src/ownership/legacy_reward_reconciliation.js";
import { parseExecuteCommandRequest } from "../../src/ownership/validators.js";
import { backfillLegacyRewardGrantStates } from "../../src/runs/reward_grant_backfill.js";
import type {
  JsonObject,
  OwnershipCanonicalState,
  OwnershipCommandEnvelope,
} from "../../src/ownership/contracts.js";
import { defaultCanonicalProfileId } from "../../src/ownership/firestore_paths.js";
import { defaultPriceGold, storeBuckets } from "../../src/ownership/store_pricing.js";
import {
  displayNameRenameCooldownMs,
  loadOrCreatePlayerProfile,
  updatePlayerProfile,
} from "../../src/profile/store.js";
import { parseUpdatePlayerProfileRequest } from "../../src/profile/validators.js";

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
const goldRefreshCost = 50;

// Final-state tests exercise the post-migration configuration. Production
// initially overrides this to true only while inventory/apply is in progress.
process.env.LEGACY_READ_RECONCILIATION_ENABLED = "false";

const swordItemIds = [
  "plainsteel",
  "waspfang",
  "cinderedge",
  "basiliskKiss",
  "frostbrand",
  "stormneedle",
  "nullblade",
  "sunlitVow",
];

const shieldItemIds = [
  "roadguard",
  "thornbark",
  "cinderWard",
  "tideguardShell",
  "frostlockBuckler",
  "ironBastion",
  "stormAegis",
  "nullPrism",
  "warbannerGuard",
  "oathwallRelic",
];

const spellBookItemIds = [
  "apprenticePrimer",
  "bastionCodex",
  "emberGrimoire",
  "tideAlmanac",
  "hexboundLexicon",
  "galeFolio",
  "nullTestament",
  "crownOfFocus",
];

const accessoryItemIds = [
  "speedBoots",
  "goldenRing",
  "teethNecklace",
  "diamondRing",
  "ironBoots",
  "oathBeads",
  "resilienceCape",
  "strengthBelt",
];

const projectileSpellIds = [
  "iceBolt",
  "fireBolt",
  "acidBolt",
  "darkBolt",
  "earthBolt",
  "holyBolt",
  "waterBolt",
  "thunderBolt",
];

const spellAbilityIds = [
  "eloise.arcane_haste",
  "eloise.focus",
  "eloise.arcane_ward",
  "eloise.cleanse",
  "eloise.vital_surge",
  "eloise.mana_infusion",
  "eloise.second_wind",
];

const nonSpellAbilityIdsBySlot: Record<string, string[]> = {
  primary: [
    "eloise.bloodletter_slash",
    "eloise.bloodletter_cleave",
    "eloise.seeker_slash",
  ],
  secondary: ["eloise.aegis_riposte", "eloise.shield_block"],
  projectile: [
    "eloise.snap_shot",
    "eloise.quick_shot",
    "eloise.skewer_shot",
    "eloise.overcharge_shot",
  ],
  mobility: ["eloise.dash", "eloise.roll"],
  jump: ["eloise.jump", "eloise.double_jump"],
};

beforeEach(async () => {
  await Promise.all([
    clearOwnershipCollections(db),
    clearPlayerProfiles(db),
    clearDisplayNameIndex(db),
    clearCollection(db, "reward_grants"),
    clearCollection(db, "system_maintenance"),
  ]);
});

after(async () => {
  await Promise.all(getApps().map((value) => deleteApp(value)));
});

test("legacy read reconciliation defaults on only for staged migration safety", () => {
  assert.equal(legacyReadReconciliationEnabled({}), true);
  assert.equal(
    legacyReadReconciliationEnabled({
      LEGACY_READ_RECONCILIATION_ENABLED: "false",
    }),
    false,
  );
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

test("public command parser rejects server-only ownership mutations", () => {
  for (const type of [
    "resetOwnership",
    "learnProjectileSpell",
    "learnSpellAbility",
    "unlockGear",
    "awardRunGold",
  ]) {
    assert.throws(
      () =>
        parseExecuteCommandRequest({
          command: {
            type,
            userId: uid,
            sessionId,
            expectedRevision: 0,
            commandId: `cmd_public_${type}`,
            payload: {},
          },
        }),
      (error: { code?: string; message?: string }) =>
        error.code === "permission-denied" &&
        (error.message ?? "").includes("server-only"),
    );
  }
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

test("ordinary canonical reads do not reconcile legacy reward grants", async () => {
  await db.collection("reward_grants").doc("grant_run_1").set({
    uid,
    runSessionId: "run_1",
    lifecycleState: "validated_settled",
    goldAmount: 25,
  });

  const first = await loadOrCreateCanonicalState({ db, uid });
  assert.equal(first.progression.gold, 0);

  const second = await loadOrCreateCanonicalState({ db, uid });
  assert.equal(second.progression.gold, 0);

  const rewardGrant = await db.collection("reward_grants").doc("grant_run_1").get();
  assert.equal(rewardGrant.exists, true);
  assert.equal(rewardGrant.data()?.lifecycleState, "validated_settled");
});

test("ordinary canonical reads do not terminalize legacy revocations", async () => {
  await db.collection("reward_grants").doc("grant_run_revocation").set({
    uid,
    runSessionId: "run_revocation_1",
    lifecycleState: "revocation_visible",
    goldAmount: 30,
    settlementReason: "replay_invalid",
    updatedAtMs: 1700000000000,
  });

  const canonical = await loadOrCreateCanonicalState({ db, uid });
  assert.equal(canonical.progression.gold, 0);

  const rewardGrant = await db
    .collection("reward_grants")
    .doc("grant_run_revocation")
    .get();
  assert.equal(rewardGrant.exists, true);
  assert.equal(rewardGrant.data()?.lifecycleState, "revocation_visible");
});

test("purchaseStoreOffer rejects when gold is only provisional", async () => {
  // seed a provisional grant — gold must not be spendable
  await db.collection("reward_grants").doc("grant_run_provisional_store").set({
    uid,
    runSessionId: "run_provisional_store_1",
    lifecycleState: "provisional_created",
    goldAmount: 500,
  });

  const canonical = await loadOrCreateCanonicalState({ db, uid });
  assert.equal(canonical.progression.gold, 0);

  const offer = activeStoreOffers(canonical)[0];
  assert.ok(offer);

  const purchase = await executeOwnershipCommand({
    db,
    uid,
    command: purchaseStoreOfferCommand({
      expectedRevision: canonical.revision,
      commandId: "cmd_store_purchase_provisional_insufficient",
      offerId: offer.offerId,
    }),
  });

  assert.equal(purchase.rejectedReason, "insufficientGold");
  assert.equal(purchase.canonicalState.progression.gold, 0);
});

test("legacy migration applies a settled reward exactly once", async () => {
  await db.collection("reward_grants").doc("grant_run_settled_once").set({
    uid,
    runSessionId: "grant_run_settled_once",
    lifecycleState: "validated_settled",
    goldAmount: 50,
  });

  const firstMigration = await backfillLegacyRewardGrantStates({
    db,
    options: { mode: "apply", nowMs: 1_700_000_000_000 },
  });
  assert.equal(firstMigration.repairedAppliedCount, 1);
  const first = await loadOrCreateCanonicalState({ db, uid });
  assert.equal(first.progression.gold, 50);
  assert.deepEqual(first.progression.appliedRewardGrantIds, ["grant_run_settled_once"]);

  // A completed migration page is read-only when the scheduler delivers it again.
  const secondMigration = await backfillLegacyRewardGrantStates({
    db,
    options: { mode: "apply", nowMs: 1_700_000_000_001 },
  });
  assert.equal(secondMigration.repairedAppliedCount, 0);
  const second = await loadOrCreateCanonicalState({ db, uid });
  assert.equal(second.progression.gold, 50);

  const rewardGrant = await db
    .collection("reward_grants")
    .doc("grant_run_settled_once")
    .get();
  assert.equal(rewardGrant.data()?.lifecycleState, "validated_settled");
});

test("legacy weekly migration updates weekly progression hooks", async () => {
  await db.collection("reward_grants").doc("grant_weekly_1").set({
    uid,
    runSessionId: "grant_weekly_1",
    lifecycleState: "validated_settled",
    goldAmount: 25,
    mode: "weekly",
    boardId: "board_weekly_field_w11",
    boardKey: {
      mode: "weekly",
      levelId: "field",
      windowId: "2026-W11",
      rulesetVersion: "rules-v1",
      scoreVersion: "score-v1",
    },
    createdAtMs: 1700000000123,
  });

  await backfillLegacyRewardGrantStates({
    db,
    options: { mode: "apply", nowMs: 1_700_000_000_000 },
  });
  const canonical = await loadOrCreateCanonicalState({ db, uid });
  const weekly = weeklyProgress(canonical);

  assert.equal(canonical.progression.gold, 25);
  assert.equal(weekly.schemaVersion, 1);
  assert.equal(weekly.currentWindowId, "2026-W11");
  assert.equal(weekly.currentWindowValidatedRuns, 1);
  assert.equal(weekly.currentWindowGoldEarned, 25);
  assert.equal(weekly.lifetimeValidatedRuns, 1);
  assert.equal(weekly.lifetimeGoldEarned, 25);
  assert.equal(weekly.lastWindowId, "2026-W11");
  assert.equal(weekly.lastBoardId, "board_weekly_field_w11");
  assert.equal(weekly.lastRunSessionId, "grant_weekly_1");
  assert.equal(weekly.lastRewardGrantId, "grant_weekly_1");
  assert.equal(weekly.lastValidatedAtMs, 1700000000123);

  const rewardGrant = await db.collection("reward_grants").doc("grant_weekly_1").get();
  assert.equal(rewardGrant.exists, true);
  assert.equal(rewardGrant.data()?.lifecycleState, "validated_settled");
});

test("legacy weekly migration preserves progression rollover", async () => {
  await db.collection("reward_grants").doc("grant_weekly_2").set({
    uid,
    runSessionId: "grant_weekly_2",
    lifecycleState: "validated_settled",
    goldAmount: 7,
    mode: "weekly",
    boardId: "board_weekly_field_w11",
    boardKey: {
      mode: "weekly",
      levelId: "field",
      windowId: "2026-W11",
      rulesetVersion: "rules-v1",
      scoreVersion: "score-v1",
    },
    createdAtMs: 1700000001000,
  });

  await db.collection("reward_grants").doc("grant_weekly_3").set({
    uid,
    runSessionId: "grant_weekly_3",
    lifecycleState: "validated_settled",
    goldAmount: 11,
    mode: "weekly",
    boardId: "board_weekly_field_w12",
    boardKey: {
      mode: "weekly",
      levelId: "field",
      windowId: "2026-W12",
      rulesetVersion: "rules-v1",
      scoreVersion: "score-v1",
    },
    createdAtMs: 1700000002000,
  });

  await backfillLegacyRewardGrantStates({
    db,
    options: { mode: "apply", nowMs: 1_700_000_000_000 },
  });
  const second = await loadOrCreateCanonicalState({ db, uid });
  const weekly = weeklyProgress(second);
  assert.equal(second.progression.gold, 18);
  assert.equal(weekly.currentWindowId, "2026-W12");
  assert.equal(weekly.currentWindowValidatedRuns, 1);
  assert.equal(weekly.currentWindowGoldEarned, 11);
  assert.equal(weekly.lifetimeValidatedRuns, 2);
  assert.equal(weekly.lifetimeGoldEarned, 18);
  assert.equal(weekly.lastWindowId, "2026-W12");
  assert.equal(weekly.lastBoardId, "board_weekly_field_w12");
  assert.equal(weekly.lastRunSessionId, "grant_weekly_3");
  assert.equal(weekly.lastRewardGrantId, "grant_weekly_3");
  assert.equal(weekly.lastValidatedAtMs, 1700000002000);
});

test("legacy migration advances revision before a client command applies", async () => {
  const canonical = await loadOrCreateCanonicalState({ db, uid });
  await db.collection("reward_grants").doc("grant_run_2").set({
    uid,
    runSessionId: "grant_run_2",
    lifecycleState: "validated_settled",
    goldAmount: 7,
  });

  const firstCommand = await executeOwnershipCommand({
    db,
    uid,
    command: setProjectileSpellCommand({
      expectedRevision: canonical.revision,
      commandId: "cmd_before_legacy_migration",
      spellId: "holyBolt",
    }),
  });

  assert.equal(firstCommand.rejectedReason, null);
  assert.equal(firstCommand.canonicalState.progression.gold, 0);

  await backfillLegacyRewardGrantStates({
    db,
    options: { mode: "apply", nowMs: 1_700_000_000_000 },
  });
  const settled = await loadOrCreateCanonicalState({ db, uid });
  assert.equal(settled.progression.gold, 7);
  assert.equal(settled.revision, canonical.revision + 2);

  const staleResult = await executeOwnershipCommand({
    db,
    uid,
    command: setProjectileSpellCommand({
      expectedRevision: firstCommand.newRevision,
      commandId: "cmd_after_legacy_migration_stale",
      spellId: "holyBolt",
    }),
  });
  assert.equal(staleResult.rejectedReason, "staleRevision");
  const result = await executeOwnershipCommand({
    db,
    uid,
    command: setProjectileSpellCommand({
      expectedRevision: settled.revision,
      commandId: "cmd_after_legacy_migration_refresh",
      spellId: "holyBolt",
    }),
  });
  assert.equal(result.rejectedReason, null);
  assert.equal(
    loadoutFor(result.canonicalState, "eloise").projectileSlotSpellId,
    "holyBolt",
  );

  const rewardGrant = await db.collection("reward_grants").doc("grant_run_2").get();
  assert.equal(rewardGrant.exists, true);
  assert.equal(rewardGrant.data()?.lifecycleState, "validated_settled");
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

test("idempotency replay survives a refreshed client session", async () => {
  const first = await executeOwnershipCommand({
    db,
    uid,
    command: setProjectileSpellCommand({
      expectedRevision: 0,
      commandId: "cmd_replay_refreshed_session",
      spellId: "holyBolt",
      sessionId: "session_before_refresh",
    }),
  });
  const replay = await executeOwnershipCommand({
    db,
    uid,
    command: setProjectileSpellCommand({
      expectedRevision: 0,
      commandId: "cmd_replay_refreshed_session",
      spellId: "holyBolt",
      sessionId: "session_after_refresh",
    }),
  });

  assert.equal(first.rejectedReason, null);
  assert.equal(replay.rejectedReason, null);
  assert.equal(replay.replayedFromIdempotency, true);
  assert.equal(replay.newRevision, 1);
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
  const unlocked = await executeOwnershipCommand({
    db,
    uid,
    command: {
      type: "unlockGear",
      userId: uid,
      sessionId,
      expectedRevision: 0,
      commandId: "cmd_unlock_gear_for_equip",
      payload: {
        slot: "spellBook",
        itemDomain: "spellBook",
        itemId: "bastionCodex",
      },
    },
  });
  assert.equal(unlocked.rejectedReason, null);

  const result = await executeOwnershipCommand({
    db,
    uid,
    command: {
      type: "equipGear",
      userId: uid,
      sessionId,
      expectedRevision: unlocked.newRevision,
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
  assert.equal(result.newRevision, 2);
  assert.equal(
    loadoutFor(result.canonicalState, "eloise").spellBookId,
    "bastionCodex",
  );
  assert.equal(
    equippedFor(result.canonicalState, "eloise").spellBookId,
    "bastionCodex",
  );
});

test("equipGear rejects known but unowned gear", async () => {
  const result = await executeOwnershipCommand({
    db,
    uid,
    command: {
      type: "equipGear",
      userId: uid,
      sessionId,
      expectedRevision: 0,
      commandId: "cmd_equip_unowned_gear",
      payload: {
        characterId: "eloise",
        slot: "spellBook",
        itemDomain: "spellBook",
        itemId: "bastionCodex",
      },
    },
  });

  assert.equal(result.rejectedReason, "invalidCommand");
  assert.equal(result.newRevision, 0);
  assert.equal(
    loadoutFor(result.canonicalState, "eloise").spellBookId,
    "apprenticePrimer",
  );
});

test("ability and projectile selection reject unowned content", async () => {
  const ability = await executeOwnershipCommand({
    db,
    uid,
    command: {
      type: "setAbilitySlot",
      userId: uid,
      sessionId,
      expectedRevision: 0,
      commandId: "cmd_set_unowned_ability",
      payload: {
        characterId: "eloise",
        slot: "primary",
        abilityId: "eloise.bloodletter_slash",
      },
    },
  });
  assert.equal(ability.rejectedReason, "invalidCommand");

  const projectile = await executeOwnershipCommand({
    db,
    uid,
    command: {
      type: "setProjectileSpell",
      userId: uid,
      sessionId,
      expectedRevision: 0,
      commandId: "cmd_set_unowned_projectile",
      payload: {
        characterId: "eloise",
        spellId: "fireBolt",
      },
    },
  });
  assert.equal(projectile.rejectedReason, "invalidCommand");
});

test("whole selection and loadout commands reject unowned nested content", async () => {
  const selection = starterSelection();
  const loadouts = selection.loadoutsByCharacter as Record<string, unknown>;
  const eloiseLoadout = loadouts.eloise as Record<string, unknown>;
  eloiseLoadout.spellBookId = "bastionCodex";

  const selectionResult = await executeOwnershipCommand({
    db,
    uid,
    command: {
      type: "setSelection",
      userId: uid,
      sessionId,
      expectedRevision: 0,
      commandId: "cmd_set_unowned_selection",
      payload: { selection },
    },
  });
  assert.equal(selectionResult.rejectedReason, "invalidCommand");

  const loadout = structuredClone(
    (starterSelection().loadoutsByCharacter as JsonObject).eloise,
  ) as JsonObject;
  loadout.spellBookId = "bastionCodex";
  const loadoutResult = await executeOwnershipCommand({
    db,
    uid,
    command: {
      type: "setLoadout",
      userId: uid,
      sessionId,
      expectedRevision: 0,
      commandId: "cmd_set_unowned_loadout",
      payload: {
        characterId: "eloise",
        loadout,
      },
    },
  });
  assert.equal(loadoutResult.rejectedReason, "invalidCommand");
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

test("store seeds one priced and unowned offer per bucket", async () => {
  const canonical = await loadOrCreateCanonicalState({ db, uid });
  const offers = activeStoreOffers(canonical);
  const offeredBuckets = offers.map((offer) => offer.bucket);

  assert.equal(offers.length, storeBuckets.length);
  assert.deepEqual([...offeredBuckets].sort(), [...storeBuckets].sort());
  for (const offer of offers) {
    assert.equal(offer.priceGold, defaultPriceGold);
    assert.equal(offer.offerId, `${offer.domain}:${offer.slot}:${offer.itemId}`);
    assert.equal(isOfferOwned(canonical, offer), false);
  }
});

test("purchaseStoreOffer spends gold, unlocks ownership, and backfills same bucket", async () => {
  const seeded = await loadOrCreateCanonicalState({ db, uid });
  const swordBefore = storeOfferByBucket(seeded, "sword");
  assert.ok(swordBefore);

  const withGold = await executeOwnershipCommand({
    db,
    uid,
    command: awardRunGoldCommand({
      expectedRevision: seeded.revision,
      commandId: "cmd_store_purchase_award",
      runId: 501,
      goldEarned: 500,
    }),
  });
  assert.equal(withGold.rejectedReason, null);

  const purchase = await executeOwnershipCommand({
    db,
    uid,
    command: purchaseStoreOfferCommand({
      expectedRevision: withGold.newRevision,
      commandId: "cmd_store_purchase",
      offerId: swordBefore.offerId,
    }),
  });
  assert.equal(purchase.rejectedReason, null);
  assert.equal(
    purchase.canonicalState.progression.gold,
    500 - swordBefore.priceGold,
  );
  assert.equal(isOfferOwned(purchase.canonicalState, swordBefore), true);

  const swordAfter = storeOfferByBucket(purchase.canonicalState, "sword");
  assert.ok(swordAfter);
  assert.notEqual(swordAfter.offerId, swordBefore.offerId);
  assert.equal(
    activeStoreOffers(purchase.canonicalState).some(
      (offer) => offer.offerId === swordBefore.offerId,
    ),
    false,
  );
});

test("purchaseStoreOffer replay is idempotent with no double spend", async () => {
  const seeded = await loadOrCreateCanonicalState({ db, uid });
  const offer = activeStoreOffers(seeded)[0];
  assert.ok(offer);

  const withGold = await executeOwnershipCommand({
    db,
    uid,
    command: awardRunGoldCommand({
      expectedRevision: seeded.revision,
      commandId: "cmd_store_purchase_replay_award",
      runId: 502,
      goldEarned: 500,
    }),
  });
  assert.equal(withGold.rejectedReason, null);

  const command = purchaseStoreOfferCommand({
    expectedRevision: withGold.newRevision,
    commandId: "cmd_store_purchase_replay",
    offerId: offer.offerId,
  });
  const first = await executeOwnershipCommand({ db, uid, command });
  const replay = await executeOwnershipCommand({ db, uid, command });

  assert.equal(first.rejectedReason, null);
  assert.equal(replay.replayedFromIdempotency, true);
  assert.equal(replay.newRevision, first.newRevision);
  assert.equal(
    replay.canonicalState.progression.gold,
    first.canonicalState.progression.gold,
  );
});

test("retention cleanup cannot make an applied purchase spend twice", async () => {
  const seeded = await loadOrCreateCanonicalState({ db, uid });
  const offer = activeStoreOffers(seeded)[0];
  assert.ok(offer);
  const withGold = await executeOwnershipCommand({
    db,
    uid,
    command: awardRunGoldCommand({
      expectedRevision: seeded.revision,
      commandId: "cmd_retention_purchase_award",
      runId: 5_020,
      goldEarned: 500,
    }),
  });
  const command = purchaseStoreOfferCommand({
    expectedRevision: withGold.newRevision,
    commandId: "cmd_retention_purchase",
    offerId: offer.offerId,
  });
  const first = await executeOwnershipCommand({ db, uid, command });
  const canonicalRef = await ownershipCanonicalDocRef(db, uid);
  await canonicalRef
    .collection("idempotency")
    .doc(command.commandId)
    .delete();

  const outsideRetryWindow = await executeOwnershipCommand({
    db,
    uid,
    command,
  });

  assert.equal(first.rejectedReason, null);
  assert.equal(outsideRetryWindow.rejectedReason, "staleRevision");
  assert.equal(
    outsideRetryWindow.canonicalState.progression.gold,
    first.canonicalState.progression.gold,
  );
});

test("purchaseStoreOffer rejects when gold is insufficient", async () => {
  const seeded = await loadOrCreateCanonicalState({ db, uid });
  const offer = activeStoreOffers(seeded)[0];
  assert.ok(offer);

  const purchase = await executeOwnershipCommand({
    db,
    uid,
    command: purchaseStoreOfferCommand({
      expectedRevision: seeded.revision,
      commandId: "cmd_store_purchase_insufficient",
      offerId: offer.offerId,
    }),
  });
  assert.equal(purchase.rejectedReason, "insufficientGold");
  assert.equal(purchase.newRevision, seeded.revision);
});

test("sword bucket eventually becomes sold out after all sword purchases", async () => {
  const seeded = await loadOrCreateCanonicalState({ db, uid });
  const goldBoost = swordItemIds.length * defaultPriceGold + 500;
  const withGold = await executeOwnershipCommand({
    db,
    uid,
    command: awardRunGoldCommand({
      expectedRevision: seeded.revision,
      commandId: "cmd_store_sword_sold_out_award",
      runId: 503,
      goldEarned: goldBoost,
    }),
  });
  assert.equal(withGold.rejectedReason, null);

  let canonical = withGold.canonicalState;
  let purchases = 0;
  for (;;) {
    const swordOffer = storeOfferByBucket(canonical, "sword");
    if (!swordOffer) {
      break;
    }
    const result = await executeOwnershipCommand({
      db,
      uid,
      command: purchaseStoreOfferCommand({
        expectedRevision: canonical.revision,
        commandId: `cmd_store_sword_sold_out_${purchases}`,
        offerId: swordOffer.offerId,
      }),
    });
    assert.equal(result.rejectedReason, null);
    canonical = result.canonicalState;
    purchases += 1;
    assert.ok(purchases <= swordItemIds.length);
  }

  assert.equal(purchases, swordItemIds.length - 1);
  assert.equal(storeOfferByBucket(canonical, "sword"), null);
});

test("refreshStore gold refresh rerolls offers and spends exactly 50 gold", async () => {
  const seeded = await loadOrCreateCanonicalState({ db, uid });
  const withGold = await executeOwnershipCommand({
    db,
    uid,
    command: awardRunGoldCommand({
      expectedRevision: seeded.revision,
      commandId: "cmd_store_refresh_award",
      runId: 504,
      goldEarned: 200,
    }),
  });
  assert.equal(withGold.rejectedReason, null);

  const beforeStore = storeState(withGold.canonicalState);
  const beforeOffers = storeOfferIdByBucket(withGold.canonicalState);
  const refresh = await executeOwnershipCommand({
    db,
    uid,
    command: refreshStoreCommand({
      expectedRevision: withGold.newRevision,
      commandId: "cmd_store_refresh_gold",
      method: "gold",
    }),
  });
  assert.equal(refresh.rejectedReason, null);
  assert.equal(refresh.canonicalState.progression.gold, 200 - goldRefreshCost);

  const afterStore = storeState(refresh.canonicalState);
  assert.equal(afterStore.generation, beforeStore.generation + 1);
  assert.equal(afterStore.refreshesUsedToday, beforeStore.refreshesUsedToday + 1);
  assert.equal(changedBuckets(beforeOffers, storeOfferIdByBucket(refresh.canonicalState)) > 0, true);
});

test("refreshStore replay is idempotent with no double spend", async () => {
  const seeded = await loadOrCreateCanonicalState({ db, uid });
  const withGold = await executeOwnershipCommand({
    db,
    uid,
    command: awardRunGoldCommand({
      expectedRevision: seeded.revision,
      commandId: "cmd_store_refresh_replay_award",
      runId: 505,
      goldEarned: 200,
    }),
  });
  assert.equal(withGold.rejectedReason, null);

  const command = refreshStoreCommand({
    expectedRevision: withGold.newRevision,
    commandId: "cmd_store_refresh_replay",
    method: "gold",
  });
  const first = await executeOwnershipCommand({ db, uid, command });
  const replay = await executeOwnershipCommand({ db, uid, command });

  assert.equal(first.rejectedReason, null);
  assert.equal(replay.replayedFromIdempotency, true);
  assert.equal(replay.newRevision, first.newRevision);
  assert.equal(
    replay.canonicalState.progression.gold,
    first.canonicalState.progression.gold,
  );
});

test("refreshStore rejects after three successful refreshes in one UTC day", async () => {
  const seeded = await loadOrCreateCanonicalState({ db, uid });
  const withGold = await executeOwnershipCommand({
    db,
    uid,
    command: awardRunGoldCommand({
      expectedRevision: seeded.revision,
      commandId: "cmd_store_refresh_limit_award",
      runId: 506,
      goldEarned: 500,
    }),
  });
  assert.equal(withGold.rejectedReason, null);

  let canonical = withGold.canonicalState;
  for (let index = 0; index < 3; index += 1) {
    const refreshed = await executeOwnershipCommand({
      db,
      uid,
      command: refreshStoreCommand({
        expectedRevision: canonical.revision,
        commandId: `cmd_store_refresh_limit_ok_${index}`,
        method: "gold",
      }),
    });
    assert.equal(refreshed.rejectedReason, null);
    canonical = refreshed.canonicalState;
  }

  const limitRejected = await executeOwnershipCommand({
    db,
    uid,
    command: refreshStoreCommand({
      expectedRevision: canonical.revision,
      commandId: "cmd_store_refresh_limit_reject",
      method: "gold",
    }),
  });
  assert.equal(limitRejected.rejectedReason, "refreshLimitReached");
  assert.equal(limitRejected.newRevision, canonical.revision);
  assert.equal(
    limitRejected.canonicalState.progression.gold,
    canonical.progression.gold,
  );
});

test("refreshStore rejects when no bucket can change", async () => {
  const canonical = await loadOrCreateCanonicalState({ db, uid });
  const canonicalRef = await ownershipCanonicalDocRef(db, uid);
  const progression = asRecord(structuredClone(canonical.progression));
  const store = asRecord(progression.store);
  store.activeOffers = [];
  progression.store = store;
  progression.gold = goldRefreshCost + 10;

  await canonicalRef.set(
    {
      meta: fullyOwnedMeta(canonical),
      progression,
    },
    { merge: true },
  );

  const refreshed = await executeOwnershipCommand({
    db,
    uid,
    command: refreshStoreCommand({
      expectedRevision: canonical.revision,
      commandId: "cmd_store_refresh_nothing",
      method: "gold",
    }),
  });

  assert.equal(refreshed.rejectedReason, "nothingToRefresh");
  assert.equal(refreshed.newRevision, canonical.revision);
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
    nowMs: 1700000000000,
    displayName: "HeroName",
    namePromptCompleted: true,
  });
  assert.equal(updated.displayName, "HeroName");
  assert.equal(updated.displayNameLastChangedAtMs, 0);
  assert.equal(updated.namePromptCompleted, true);

  const loaded = await loadOrCreatePlayerProfile({ db, uid });
  assert.equal(loaded.displayName, "HeroName");
  assert.equal(loaded.displayNameLastChangedAtMs, 0);
  assert.equal(loaded.namePromptCompleted, true);
});

test("updatePlayerProfile rejects duplicate normalized name across users", async () => {
  await updatePlayerProfile({
    db,
    uid: "uid_primary",
    nowMs: 100,
    displayName: "Hero Name",
  });

  await assert.rejects(
    () =>
      updatePlayerProfile({
        db,
        uid: "uid_secondary",
        nowMs: 101,
        displayName: "hero   name",
      }),
    (error: { code?: string }) => error.code === "already-exists",
  );
});

test("updatePlayerProfile rename releases prior name for another user", async () => {
  await updatePlayerProfile({
    db,
    uid: "uid_primary",
    nowMs: 100,
    displayName: "Alpha",
  });
  await updatePlayerProfile({
    db,
    uid: "uid_primary",
    nowMs: 101,
    displayName: "Beta",
  });

  const claimed = await updatePlayerProfile({
    db,
    uid: "uid_secondary",
    nowMs: 102,
    displayName: "alpha",
  });
  assert.equal(claimed.displayName, "alpha");
});

test("profile validator rejects caller-controlled rename timestamps", () => {
  for (const value of [0, 1, Number.MAX_SAFE_INTEGER]) {
    assert.throws(
      () =>
        parseUpdatePlayerProfileRequest({
          userId: uid,
          sessionId,
          displayName: "HeroName",
          displayNameLastChangedAtMs: value,
        }),
      (error: { code?: string }) => error.code === "invalid-argument",
    );
  }
});

test("updatePlayerProfile enforces cooldown at the exact boundary", async () => {
  const initial = await updatePlayerProfile({
    db,
    uid,
    nowMs: 100,
    displayName: "Alpha",
  });
  assert.equal(initial.displayNameLastChangedAtMs, 0);

  const firstRenameAtMs = 200;
  const firstRename = await updatePlayerProfile({
    db,
    uid,
    nowMs: firstRenameAtMs,
    displayName: "Beta",
  });
  assert.equal(firstRename.displayNameLastChangedAtMs, firstRenameAtMs);

  await assert.rejects(
    () =>
      updatePlayerProfile({
        db,
        uid,
        nowMs: firstRenameAtMs + displayNameRenameCooldownMs - 1,
        displayName: "Gamma",
      }),
    (error: { code?: string }) => error.code === "failed-precondition",
  );

  const exactBoundary = await updatePlayerProfile({
    db,
    uid,
    nowMs: firstRenameAtMs + displayNameRenameCooldownMs,
    displayName: "Gamma",
  });
  assert.equal(exactBoundary.displayName, "Gamma");
  assert.equal(
    exactBoundary.displayNameLastChangedAtMs,
    firstRenameAtMs + displayNameRenameCooldownMs,
  );
});

test("updatePlayerProfile repairs a legacy future cooldown on rename", async () => {
  await updatePlayerProfile({
    db,
    uid,
    nowMs: 100,
    displayName: "Alpha",
  });
  await db.collection("player_profiles").doc(uid).set(
    {
      displayNameLastChangedAtMs: 999999,
    },
    { merge: true },
  );

  const renamed = await updatePlayerProfile({
    db,
    uid,
    nowMs: 200,
    displayName: "Beta",
  });
  assert.equal(renamed.displayNameLastChangedAtMs, 200);
});

test("concurrent rename attempts allow one winner and preserve indexes", async () => {
  await updatePlayerProfile({
    db,
    uid,
    nowMs: 100,
    displayName: "Alpha",
  });

  const results = await Promise.allSettled([
    updatePlayerProfile({
      db,
      uid,
      nowMs: 200,
      displayName: "Beta",
    }),
    updatePlayerProfile({
      db,
      uid,
      nowMs: 200,
      displayName: "Gamma",
    }),
  ]);
  assert.equal(
    results.filter((result) => result.status === "fulfilled").length,
    1,
  );
  assert.equal(
    results.filter((result) => result.status === "rejected").length,
    1,
  );

  const profile = await loadOrCreatePlayerProfile({ db, uid });
  assert.ok(profile.displayName === "Beta" || profile.displayName === "Gamma");
  assert.equal(profile.displayNameLastChangedAtMs, 200);
  assert.equal(
    (
      await db
        .collection("display_name_index")
        .doc(profile.displayName.toLowerCase())
        .get()
    ).data()?.uid,
    uid,
  );
  assert.equal(
    (
      await db
        .collection("display_name_index")
        .doc(profile.displayName === "Beta" ? "gamma" : "beta")
        .get()
    ).exists,
    false,
  );
});

test("first profile load racing first update preserves name and index", async () => {
  const raceUid = "uid_profile_race";
  const [loaded, updated] = await Promise.all([
    loadOrCreatePlayerProfile({ db, uid: raceUid }),
    updatePlayerProfile({
      db,
      uid: raceUid,
      nowMs: 100,
      displayName: "Racer Name",
    }),
  ]);
  const persisted = await loadOrCreatePlayerProfile({ db, uid: raceUid });

  assert.ok(loaded.displayName === "" || loaded.displayName === "Racer Name");
  assert.equal(updated.displayName, "Racer Name");
  assert.equal(persisted.displayName, "Racer Name");
  assert.equal(
    (await db.collection("display_name_index").doc("racer name").get()).data()
      ?.uid,
    raceUid,
  );
});

test("concurrent first profile loads converge on one default document", async () => {
  const raceUid = "uid_profile_load_race";
  const profiles = await Promise.all(
    Array.from({ length: 8 }, () =>
      loadOrCreatePlayerProfile({ db, uid: raceUid }),
    ),
  );
  assert.deepEqual(
    new Set(profiles.map((profile) => JSON.stringify(profile))),
    new Set([JSON.stringify(profiles[0])]),
  );
  assert.equal((await db.collection("player_profiles").get()).size, 1);
});

function setProjectileSpellCommand(args: {
  expectedRevision: number;
  commandId: string;
  spellId: string;
  userId?: string;
  sessionId?: string;
}): OwnershipCommandEnvelope {
  return {
    type: "setProjectileSpell",
    userId: args.userId ?? uid,
    sessionId: args.sessionId ?? sessionId,
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

function purchaseStoreOfferCommand(args: {
  expectedRevision: number;
  commandId: string;
  offerId: string;
  userId?: string;
}): OwnershipCommandEnvelope {
  return {
    type: "purchaseStoreOffer",
    userId: args.userId ?? uid,
    sessionId,
    expectedRevision: args.expectedRevision,
    commandId: args.commandId,
    payload: {
      offerId: args.offerId,
    },
  };
}

function refreshStoreCommand(args: {
  expectedRevision: number;
  commandId: string;
  method: "gold" | "rewardedAd";
  userId?: string;
}): OwnershipCommandEnvelope {
  return {
    type: "refreshStore",
    userId: args.userId ?? uid,
    sessionId,
    expectedRevision: args.expectedRevision,
    commandId: args.commandId,
    payload: {
      method: args.method,
    },
  };
}

interface StoreOfferRecord {
  offerId: string;
  bucket: string;
  domain: string;
  slot: string;
  itemId: string;
  priceGold: number;
}

interface StoreStateRecord {
  generation: number;
  refreshesUsedToday: number;
}

interface WeeklyProgressRecord {
  schemaVersion: number;
  currentWindowId: string;
  currentWindowValidatedRuns: number;
  currentWindowGoldEarned: number;
  lifetimeValidatedRuns: number;
  lifetimeGoldEarned: number;
  lastWindowId: string;
  lastBoardId: string;
  lastRunSessionId: string;
  lastRewardGrantId: string;
  lastValidatedAtMs: number;
}

function weeklyProgress(canonical: OwnershipCanonicalState): WeeklyProgressRecord {
  const progression = asRecord(canonical.progression);
  const weekly = asRecord(progression.weeklyProgress);
  return {
    schemaVersion: asInteger(weekly.schemaVersion),
    currentWindowId: asNonEmptyString(weekly.currentWindowId),
    currentWindowValidatedRuns: asInteger(weekly.currentWindowValidatedRuns),
    currentWindowGoldEarned: asInteger(weekly.currentWindowGoldEarned),
    lifetimeValidatedRuns: asInteger(weekly.lifetimeValidatedRuns),
    lifetimeGoldEarned: asInteger(weekly.lifetimeGoldEarned),
    lastWindowId: asNonEmptyString(weekly.lastWindowId),
    lastBoardId: asNonEmptyString(weekly.lastBoardId),
    lastRunSessionId: asNonEmptyString(weekly.lastRunSessionId),
    lastRewardGrantId: asNonEmptyString(weekly.lastRewardGrantId),
    lastValidatedAtMs: asInteger(weekly.lastValidatedAtMs),
  };
}

function storeState(canonical: OwnershipCanonicalState): StoreStateRecord {
  const progression = asRecord(canonical.progression);
  const store = asRecord(progression.store);
  return {
    generation: asInteger(store.generation),
    refreshesUsedToday: asInteger(store.refreshesUsedToday),
  };
}

function activeStoreOffers(canonical: OwnershipCanonicalState): StoreOfferRecord[] {
  const progression = asRecord(canonical.progression);
  const store = asRecord(progression.store);
  const offersRaw = store.activeOffers;
  if (!Array.isArray(offersRaw)) {
    return [];
  }
  return offersRaw.map((value) => {
    const offer = asRecord(value);
    return {
      offerId: asNonEmptyString(offer.offerId),
      bucket: asNonEmptyString(offer.bucket),
      domain: asNonEmptyString(offer.domain),
      slot: asNonEmptyString(offer.slot),
      itemId: asNonEmptyString(offer.itemId),
      priceGold: asInteger(offer.priceGold),
    };
  });
}

function storeOfferByBucket(
  canonical: OwnershipCanonicalState,
  bucket: string,
): StoreOfferRecord | null {
  for (const offer of activeStoreOffers(canonical)) {
    if (offer.bucket === bucket) {
      return offer;
    }
  }
  return null;
}

function storeOfferIdByBucket(
  canonical: OwnershipCanonicalState,
): Map<string, string> {
  const out = new Map<string, string>();
  for (const offer of activeStoreOffers(canonical)) {
    out.set(offer.bucket, offer.offerId);
  }
  return out;
}

function changedBuckets(
  before: Map<string, string>,
  after: Map<string, string>,
): number {
  let count = 0;
  for (const [bucket, offerId] of before.entries()) {
    if (after.get(bucket) !== offerId) {
      count += 1;
    }
  }
  return count;
}

function isOfferOwned(
  canonical: OwnershipCanonicalState,
  offer: Pick<StoreOfferRecord, "domain" | "slot" | "itemId">,
): boolean {
  const meta = asRecord(canonical.meta);
  const inventory = asRecord(meta.inventory);
  if (offer.domain === "gear") {
    if (offer.slot === "mainWeapon" || offer.slot === "offhandWeapon") {
      return readStringList(inventory.weapons).includes(offer.itemId);
    }
    if (offer.slot === "spellBook") {
      return readStringList(inventory.spellBooks).includes(offer.itemId);
    }
    if (offer.slot === "accessory") {
      return readStringList(inventory.accessories).includes(offer.itemId);
    }
    return false;
  }
  const selection = asRecord(canonical.selection);
  const selectedCharacterId = asNonEmptyString(selection.characterId);
  const ownershipByCharacter = asRecord(meta.abilityOwnershipByCharacter);
  const ownership = asRecord(ownershipByCharacter[selectedCharacterId]);
  if (offer.domain === "projectileSpell") {
    return readStringList(ownership.projectileSpells).includes(offer.itemId);
  }
  if (offer.domain === "ability") {
    const abilitiesBySlot = asRecord(ownership.abilitiesBySlot);
    return readStringList(abilitiesBySlot[offer.slot]).includes(offer.itemId);
  }
  return false;
}

function fullyOwnedMeta(
  canonical: OwnershipCanonicalState,
): Record<string, unknown> {
  const meta = asRecord(structuredClone(canonical.meta));
  meta.inventory = {
    weapons: [...new Set([...swordItemIds, ...shieldItemIds])],
    spellBooks: [...spellBookItemIds],
    accessories: [...accessoryItemIds],
  };
  const ownershipByCharacter = asRecord(meta.abilityOwnershipByCharacter);
  ownershipByCharacter.eloise = {
    projectileSpells: [...projectileSpellIds],
    abilitiesBySlot: {
      primary: [...nonSpellAbilityIdsBySlot.primary],
      secondary: [...nonSpellAbilityIdsBySlot.secondary],
      projectile: [...nonSpellAbilityIdsBySlot.projectile],
      mobility: [...nonSpellAbilityIdsBySlot.mobility],
      jump: [...nonSpellAbilityIdsBySlot.jump],
      spell: [...spellAbilityIds],
    },
  };
  meta.abilityOwnershipByCharacter = ownershipByCharacter;
  return meta;
}

async function ownershipCanonicalDocRef(dbValue: Firestore, uidValue: string) {
  const snapshot = await dbValue
    .collection("ownership_profiles")
    .where("uid", "==", uidValue)
    .limit(1)
    .get();
  assert.equal(snapshot.docs.length, 1);
  return snapshot.docs[0]!.ref;
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

function asInteger(value: unknown): number {
  if (typeof value === "number" && Number.isInteger(value)) {
    return value;
  }
  throw new Error(`Expected integer value, got ${typeof value}`);
}

function asNonEmptyString(value: unknown): string {
  if (typeof value === "string" && value.trim().length > 0) {
    return value.trim();
  }
  throw new Error(`Expected non-empty string value, got ${typeof value}`);
}

function readStringList(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.filter((item): item is string => typeof item === "string");
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

async function clearCollection(dbValue: Firestore, name: string): Promise<void> {
  const docs = await dbValue.collection(name).listDocuments();
  await Promise.all(docs.map((docRef) => dbValue.recursiveDelete(docRef)));
}
