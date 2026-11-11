import assert from "node:assert/strict";
import { after, beforeEach, test } from "node:test";
import { deleteApp, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { loadOrCreateCanonicalState } from "../../src/ownership/canonical_store.js";
import { inboxCollections, type InboxCatalogReward } from "../../src/inbox/contracts.js";
import { inboxGiftCatalogHash, inboxGiftConfigurationPath, parseInboxRewards } from "../../src/inbox/gifts.js";
import { loadOperatorGiftCatalog, parseOperatorMessage, sendOperatorMessage } from "../../src/inbox/operator.js";
import { claimInboxReward, deleteInboxMessage, issueSystemMessage, listInbox, markInboxMessageRead, systemMessageId } from "../../src/inbox/store.js";
import type { JsonObject } from "../../src/ownership/contracts.js";
import { maintainInboxRetention } from "../../src/inbox/retention.js";
import { inboxRetentionMs } from "../../src/inbox/retention_policy.js";

if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error("Use the Firestore emulator.");
const projectId = "demo-rpg-runner-gift-tests";
const app = initializeApp({ projectId }, `gifts-${process.pid}`);
const db = getFirestore(app), uid = "gift-player", nowMs = 1700000000000;
const attachments: InboxCatalogReward[] = [
  { kind: "gear", slot: "mainWeapon", itemId: "waspfang" },
  { kind: "ability", slot: "spell", itemId: "eloise.arcane_ward", characterId: "eloise" },
  { kind: "projectileSpell", slot: "projectile", itemId: "fireBolt", characterId: "eloise" },
];
const input = { uid, sourceId: "gifts", title: "Equipment", body: "Ready to claim", goldAmount: 20, attachments };
const enable = () => db.doc(inboxGiftConfigurationPath).set({ schemaVersion: 1, enabled: true, catalogHash: inboxGiftCatalogHash });
const deliver = (sourceId = "gifts") => issueSystemMessage({ db, uid, nowMs, delivery: { ...input, sourceId } });
beforeEach(async () => {
  for (const name of [...Object.values(inboxCollections), "inbox_configuration", "ownership_profiles", "player_profiles", "account_deletion_requests", "maintenance_state"]) {
    for (const doc of (await db.collection(name).get()).docs) await db.recursiveDelete(doc.ref);
  }
  await db.collection("player_profiles").doc(uid).set({ uid });
});
after(async () => { await deleteApp(app); });

test("catalog gate fails closed, does not block legacy gold, and is rechecked on send", async () => {
  assert.equal((await loadOperatorGiftCatalog(projectId)).enabled, false);
  await assert.rejects(deliver(), { code: "failed-precondition" });
  await sendOperatorMessage(projectId, { ...input, sourceId: "legacy", attachments: [] });
  assert.equal((await listInbox(db, uid)).messages[0].schemaVersion, 1);
  await enable();
  const catalog = await loadOperatorGiftCatalog(projectId);
  assert.ok(catalog.entries.length > 20);
  await db.doc(inboxGiftConfigurationPath).update({ catalogHash: "stale" });
  await assert.rejects(sendOperatorMessage(projectId, input), { code: "failed-precondition" });
  assert.equal((await loadOperatorGiftCatalog(projectId)).enabled, false);
});

test("operator gifts grant account gear and the explicit character skills atomically once", async () => {
  await enable();
  const id = await sendOperatorMessage(projectId, input);
  const before = await loadOrCreateCanonicalState({ db, uid });
  assert.equal(before.progression.gold, 0);
  assert.equal((await listInbox(db, uid)).messages[0].schemaVersion, 2);
  await db.doc(inboxGiftConfigurationPath).delete();
  // Existing promises and identical send retries survive disabling new issuance.
  assert.equal(await sendOperatorMessage(projectId, { ...input, attachments: [...attachments].reverse() }), id);
  const base = { db, uid, messageId: id, expectedRevision: 0 };
  const results = await Promise.all([claimInboxReward({ ...base, commandId: "a" }), claimInboxReward({ ...base, commandId: "b" })]);
  for (const result of results) assert.equal(result.result.rejectedReason, null);
  const state = (await claimInboxReward({ ...base, commandId: "a" })).result.canonicalState;
  assert.equal(state.progression.gold, 20);
  assert.equal(state.revision, 1);
  assert.deepEqual(state.selection, before.selection);
  assert.deepEqual(state.meta.equippedByCharacter, before.meta.equippedByCharacter);
  const inventory = state.meta.inventory as { weapons: string[] };
  assert.equal(inventory.weapons.filter((v) => v === "waspfang").length, 1);
  const ownership = state.meta.abilityOwnershipByCharacter as Record<string, { projectileSpells: string[]; abilitiesBySlot: Record<string, string[]> }>;
  assert.ok(ownership.eloise!.abilitiesBySlot.spell!.includes("eloise.arcane_ward"));
  assert.ok(ownership.eloise!.projectileSpells.includes("fireBolt"));
  assert.ok(!ownership.bountyHunter!.abilitiesBySlot.spell!.includes("eloise.arcane_ward"));
  assert.ok(!ownership.bountyHunter!.projectileSpells.includes("fireBolt"));
  assert.equal((await listInbox(db, uid)).summary.unclaimedCount, 0);
  await assert.rejects(sendOperatorMessage(projectId, { ...input, attachments: attachments.slice(1) }), { code: "already-exists" });
});

test("already-owned unlocks claim without compensation and gifts cannot expire or delete before claim", async () => {
  await enable();
  const id = await deliver();
  await markInboxMessageRead(db, uid, id, nowMs + 1);
  await assert.rejects(deleteInboxMessage({ db, uid, messageId: id }), { code: "failed-precondition" });
  await maintainInboxRetention({ db, nowMs: nowMs + inboxRetentionMs * 10 });
  assert.equal((await listInbox(db, uid)).messages.length, 1);
  await claimInboxReward({ db, uid, messageId: id, commandId: "first", expectedRevision: 0, nowMs: nowMs + 2 });
  const duplicate = await issueSystemMessage({ db, uid, nowMs, delivery: { ...input, sourceId: "owned", goldAmount: 0 } });
  const claimed = await claimInboxReward({ db, uid, messageId: duplicate, commandId: "owned", expectedRevision: 1, nowMs: nowMs + 3 });
  assert.equal(claimed.result.canonicalState.progression.gold, 20);
  assert.equal(claimed.result.canonicalState.revision, 2);
  await maintainInboxRetention({ db, nowMs: nowMs + 2 + inboxRetentionMs });
  assert.equal((await listInbox(db, uid)).messages.length, 1);
  const receipt = (await db.collection(inboxCollections.receipts).doc(id).get()).data()!;
  assert.equal(receipt.rewards.length, 4);
  assert.equal(receipt.title, undefined);
  assert.equal(await deliver(), id);
  await assert.rejects(claimInboxReward({ db, uid, messageId: id, commandId: "after-delete", expectedRevision: 2 }), { code: "not-found" });
});

test("invalid IDs, slots, characters, duplicate gifts and oversized gifts are rejected", () => {
  for (const rewards of [
    [{ ...attachments[0], itemId: "invented" }], [{ ...attachments[0], slot: "accessory" }],
    [{ ...attachments[0], characterId: "eloise" }], [{ ...attachments[1], characterId: "invented" }],
    [{ ...attachments[1], characterId: undefined }], [{ ...attachments[1], characterId: "eloiseWip" }], [attachments[0], attachments[0]],
    [{ ...attachments[0], amount: 2 }], [{ kind: "gold", amount: 0 }],
  ]) assert.throws(() => parseInboxRewards(rewards));
  assert.throws(() => parseOperatorMessage({ ...input, attachments: [{ kind: "gold", amount: 1 }] }));
});

test("retained WIP gifts claim for Éloïse, preserve retry hashes, and cannot be newly issued", async () => {
  const retired = { ...attachments[1], characterId: "eloiseWip" };
  const delivery = { ...input, sourceId: "retired-gift", attachments: [retired] };
  const id = systemMessageId(uid, delivery.sourceId);
  const rewards = [{ kind: "gold", amount: 20 }, retired];
  // This is pre-retirement persisted evidence, not a new issuance bypass.
  await db.collection(inboxCollections.messages).doc(id).set({
    schemaVersion: 2, id, uid, sourceId: delivery.sourceId,
    title: delivery.title, body: delivery.body, rewards,
    createdAtMs: nowMs, readAtMs: null, claimedAtMs: null, expiresAtMs: null,
  });
  await db.collection(inboxCollections.rewards).doc(id).set({ uid, messageId: id, rewards, claimedAtMs: null });
  await db.collection(inboxCollections.summaries).doc(uid).set({ uid, revision: 1, unreadCount: 1, unclaimedCount: 1 });
  const old = await loadOrCreateCanonicalState({ db, uid });
  old.selection.characterId = "eloiseWip";
  (old.selection.buildsByCharacter as JsonObject).eloiseWip = { builds: [] };
  (old.meta.equippedByCharacter as JsonObject).eloiseWip = { mainWeaponId: "waspfang" };
  (old.meta.abilityOwnershipByCharacter as JsonObject).eloiseWip = {
    projectileSpells: ["fireBolt"], abilitiesBySlot: { spell: ["eloise.focus"] },
  };
  const profile = db.collection("ownership_profiles").doc(`${uid}__${old.profileId}`);
  await profile.update({ selection: old.selection, meta: old.meta });
  assert.deepEqual((await listInbox(db, uid)).messages[0].rewards, rewards);
  assert.equal(await issueSystemMessage({ db, uid, nowMs, delivery }), id);
  const claim = { db, uid, messageId: id, commandId: "retired-claim", expectedRevision: 0, nowMs: nowMs + 1 };
  const result = await claimInboxReward(claim);
  const state = result.result.canonicalState;
  assert.equal(state.selection.characterId, "eloise");
  assert.equal(state.progression.gold, 20);
  const ownership = (state.meta.abilityOwnershipByCharacter as JsonObject).eloise as JsonObject;
  assert.ok(((ownership.abilitiesBySlot as JsonObject).spell as string[]).includes("eloise.arcane_ward"));
  assert.ok((ownership.projectileSpells as string[]).includes("fireBolt"));
  assert.ok(!JSON.stringify((await profile.get()).data()).includes("eloiseWip"));
  assert.deepEqual((await claimInboxReward(claim)).result.canonicalState, state);
  assert.deepEqual((await db.collection(inboxCollections.rewards).doc(id).get()).get("rewards"), rewards);
  await deleteInboxMessage({ db, uid, messageId: id, nowMs: nowMs + 2 });
  assert.equal(await issueSystemMessage({ db, uid, nowMs, delivery }), id);
  await assert.rejects(issueSystemMessage({ db, uid, nowMs, delivery: { ...delivery, title: "Changed" } }), { code: "already-exists" });
  await enable();
  await assert.rejects(issueSystemMessage({ db, uid, nowMs, delivery: { ...delivery, sourceId: "new-retired-gift" } }), { code: "invalid-argument" });
});

test("stale revision and gold overflow cannot partially grant catalog rewards", async () => {
  await enable();
  const id = await deliver();
  const state = await loadOrCreateCanonicalState({ db, uid });
  const stale = await claimInboxReward({ db, uid, messageId: id, commandId: "stale", expectedRevision: 99 });
  assert.equal(stale.result.rejectedReason, "staleRevision");
  assert.deepEqual(stale.result.canonicalState.meta, state.meta);
  await db.collection("ownership_profiles").doc(`${uid}__${state.profileId}`).update({ "progression.gold": Number.MAX_SAFE_INTEGER });
  await assert.rejects(claimInboxReward({ db, uid, messageId: id, commandId: "overflow", expectedRevision: 0 }));
  assert.deepEqual((await loadOrCreateCanonicalState({ db, uid })).meta, state.meta);
  assert.equal((await listInbox(db, uid)).messages[0].claimedAtMs, null);
});


test("Willow equipment gifts claim once and keep ranged ownership character-specific", async () => {
  await enable();
  const rewards: InboxCatalogReward[] = [
    { kind: "gear", slot: "mainWeapon", itemId: "hunterNotchknife" },
    { kind: "gear", slot: "offhandWeapon", itemId: "hunterBacktrailRig" },
    { kind: "gear", slot: "spellBook", itemId: "hunterLongtrailPack" },
    { kind: "projectileSpell", slot: "projectile", itemId: "hunterBrushgun", characterId: "bountyHunter" },
  ];
  const id = await sendOperatorMessage(projectId, { ...input, goldAmount: 0, attachments: rewards });
  const before = await loadOrCreateCanonicalState({ db, uid });
  const claim = { db, uid, messageId: id, expectedRevision: before.revision, commandId: "willow-items" };
  const result = await claimInboxReward(claim);
  assert.equal(result.result.rejectedReason, null);
  const state = result.result.canonicalState;
  assert.equal(state.revision, before.revision + 1);
  const inventory = state.meta.inventory as { weapons: string[]; spellBooks: string[] };
  for (const itemId of ["hunterNotchknife", "hunterBacktrailRig"]) {
    assert.equal(inventory.weapons.filter(v => v === itemId).length, 1);
  }
  assert.equal(inventory.spellBooks.filter(v => v === "hunterLongtrailPack").length, 1);
  const ownership = state.meta.abilityOwnershipByCharacter as Record<string, { projectileSpells: string[] }>;
  assert.ok(ownership.bountyHunter!.projectileSpells.includes("hunterBrushgun"));
  assert.ok(!ownership.eloise!.projectileSpells.includes("hunterBrushgun"));
  assert.deepEqual(state.selection, before.selection);
  assert.deepEqual((await claimInboxReward(claim)).result.canonicalState, state);
});
