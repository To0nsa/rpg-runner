import assert from "node:assert/strict";
import test from "node:test";
import { campaignCatalog } from "../../src/campaign/generated_catalog.js";
import { applyCampaignProgress, authorizeCampaignMission, campaignCharacterUnlocked,
  type CampaignCatalog } from "../../src/campaign/progression.js";
import { starterCanonicalState, normalizeCanonicalState } from "../../src/ownership/defaults.js";
import { applyPlayerProgress, playerLevelFromTotalXp } from "../../src/ownership/player_progress.js";
import { normalizeAuthorizedSelection } from "../../src/ownership/loadout_authorization.js";
import { applyRunAchievements } from "../../src/ownership/achievements.js";
import { parseRunSessionCreateRequest } from "../../src/runs/validators.js";

const catalog: CampaignCatalog = { ...campaignCatalog, chapters: campaignCatalog.chapters.map((chapter) => ({
  ...chapter, missions: chapter.missions.map((mission) => ({ ...mission, available: true })),
})) };

test("four verified first clears grant 224 XP, double jump and Willow; repeats grant no XP", () => {
  const state = starterCanonicalState("main", "campaign-player");
  const buildsBefore = structuredClone(state.selection);
  const missions = catalog.chapters[0]!.missions;
  assert.equal(campaignCharacterUnlocked(state.progression, "bountyHunter"), false);
  assert.throws(() => authorizeCampaignMission(state.progression, missions[1]!.id, "forest", catalog));
  let runId = 0;
  const settle = (id: string, reason = "missionCompleted") => {
    const campaign = authorizeCampaignMission(state.progression, id, "forest", catalog);
    const run = { mode: "campaign", campaign, accepted: true, endedReason: reason,
      score: 1000000, tick: 200, runSessionId: `run_${++runId}`,
      playerRunStats: { schemaVersion: 1, damageDealt100: 100, damageTaken100: 0 } };
    const session = { mode: "campaign", levelId: "forest", runTicket: { campaign } };
    const result = applyCampaignProgress({ canonical: state, validatedRun: run, session, nowMs: 1000, catalog });
    applyPlayerProgress({ progression: state.progression, validatedRun: run, session, campaignXp: result.xp });
    assert.equal(applyRunAchievements({ progression: state.progression, validatedRun: run, nowMs: 1000 }), false);
    return result.xp;
  };
  assert.equal(settle(missions[0]!.id, "gaveUp"), 0);
  assert.equal(campaignCharacterUnlocked(state.progression, "bountyHunter"), false);
  for (const mission of missions) assert.equal(settle(mission.id), mission.firstClearXp);
  assert.equal((state.progression.playerProgress as { totalXp: number }).totalXp, 224);
  assert.equal(playerLevelFromTotalXp(224), 3);
  assert.equal(campaignCharacterUnlocked(state.progression, "bountyHunter"), true);
  assert.equal(settle(missions[0]!.id), 0);
  assert.equal((state.progression.playerProgress as { totalXp: number }).totalXp, 224);
  assert.deepEqual(state.selection, buildsBefore);
  const ownership = state.meta.abilityOwnershipByCharacter as Record<string, { abilitiesBySlot: { jump: string[] } }>;
  assert.deepEqual(ownership.eloise!.abilitiesBySlot.jump, ["eloise.jump", "eloise.double_jump"]);
});

test("pre-release Willow selection normalizes without erasing gear or builds", () => {
  const state = starterCanonicalState("main", "campaign-player");
  state.selection.characterId = "bountyHunter";
  const meta = structuredClone(state.meta);
  const builds = structuredClone(state.selection.buildsByCharacter);
  const normalized = normalizeCanonicalState(state, "main", "campaign-player");
  assert.equal(normalized.selection.characterId, "eloise");
  assert.deepEqual(normalized.meta, meta);
  assert.deepEqual(normalized.selection.buildsByCharacter, builds);
  assert.equal(normalizeAuthorizedSelection({ selection: state.selection,
    meta: state.meta, progression: state.progression }), null);
});

test("drafts cannot issue and campaign requests require a mission ID", () => {
  const state = starterCanonicalState("main", "campaign-player");
  const drafts: CampaignCatalog = { ...campaignCatalog, chapters: campaignCatalog.chapters.map((chapter) => ({
    ...chapter, missions: chapter.missions.map((mission) => ({ ...mission, available: false })),
  })) };
  assert.throws(() => authorizeCampaignMission(state.progression, "reporting_for_duty", "forest", drafts));
  const request = { userId: "u", sessionId: "s", clientRequestId: "request", mode: "campaign", levelId: "forest", gameCompatVersion: "2026.11.14" };
  assert.throws(() => parseRunSessionCreateRequest(request));
  assert.equal(parseRunSessionCreateRequest({ ...request, missionId: "reporting_for_duty" }).missionId, "reporting_for_duty");
  assert.throws(() => parseRunSessionCreateRequest({ ...request, mode: "practice", missionId: "reporting_for_duty" }));
});

test("mismatched mission evidence cannot grant rewards", () => {
  const state = starterCanonicalState("main", "campaign-player");
  const campaign = authorizeCampaignMission(state.progression, "reporting_for_duty", "forest", catalog);
  const before = structuredClone(state);
  assert.throws(() => applyCampaignProgress({ canonical: state, nowMs: 0, catalog,
    validatedRun: { accepted: true, campaign: { ...campaign, missionId: "holding_the_outpost" } },
    session: { mode: "campaign", levelId: "forest", runTicket: { campaign } } }));
  assert.deepEqual(state, before);
});

test("unsupported progress and incomplete evidence fail closed", () => {
  const state = starterCanonicalState("main", "campaign-player");
  const campaign = authorizeCampaignMission(state.progression, "reporting_for_duty", "forest", catalog);
  const before = structuredClone(state);
  assert.throws(() => applyCampaignProgress({ canonical: state, nowMs: 0, catalog,
    validatedRun: { accepted: true, campaign, endedReason: "missionCompleted", score: 1, tick: 20 },
    session: { mode: "campaign", levelId: "forest", runTicket: { campaign } } }));
  assert.deepEqual(state, before);
  state.progression.campaign = { schemaVersion: 2, missions: Object.fromEntries(
    catalog.chapters[0]!.missions.map((mission) => [mission.id, { cleared: true }])) };
  assert.equal(campaignCharacterUnlocked(state.progression, "bountyHunter"), false);
  assert.throws(() => authorizeCampaignMission(state.progression, "signs_in_the_grove", "forest", catalog));
});

function completeChapter(state: ReturnType<typeof starterCanonicalState>, rewards = { xp: 25, gold: 150 },
  override: Partial<CampaignCatalog["chapters"][number]> = {}) {
  const chapter = { ...catalog.chapters[0]!, rewardXp: rewards.xp, rewardGold: rewards.gold,
    rewardItems: [
      { kind: "gear" as const, slot: "mainWeapon", itemId: "cinderedge" },
      { kind: "ability" as const, slot: "jump", itemId: "eloise.double_jump", characterId: "eloise" },
      { kind: "projectileSpell" as const, slot: "projectile", itemId: "hunterBrushgun", characterId: "bountyHunter" },
    ], ...override };
  const current = { ...catalog, chapters: [chapter] };
  const last = chapter.missions.at(-1)!;
  const campaign = { missionId: last.id, contentDigest: current.contentDigest, rewardPolicyVersion: current.rewardPolicyVersion };
  return applyCampaignProgress({ canonical: state, catalog: current, nowMs: 1234,
    session: { mode: "campaign", levelId: last.levelId, runTicket: { campaign } },
    validatedRun: { accepted: true, campaign, endedReason: "missionCompleted", score: 100, tick: 50,
      runSessionId: "last", playerRunStats: { schemaVersion: 1 } } });
}
function readyForFinalMission() {
  const state = starterCanonicalState("main", "chapter-player");
  state.progression.campaign = { schemaVersion: 1, missions: Object.fromEntries(
    catalog.chapters[0]!.missions.slice(0, -1).map((m) => [m.id, { cleared: true, attempts: 1, bests: {} }])) };
  return state;
}

test("chapter rewards grant once through normal ownership, preserving loadouts and receipts", () => {
  const state = readyForFinalMission();
  const selection = structuredClone(state.selection);
  assert.equal(completeChapter(state).xp, 76 + 25);
  assert.equal(state.progression.gold, 150);
  assert.deepEqual(state.selection, selection);
  const inventory = state.meta.inventory as { weapons: string[] };
  assert.equal(inventory.weapons.filter((id) => id === "cinderedge").length, 1);
  const ownership = state.meta.abilityOwnershipByCharacter as Record<string, { projectileSpells: string[]; abilitiesBySlot: { jump: string[] } }>;
  assert.ok(ownership.bountyHunter!.projectileSpells.includes("hunterBrushgun"));
  assert.ok(!ownership.eloise!.projectileSpells.includes("hunterBrushgun"));
  assert.ok(ownership.eloise!.abilitiesBySlot.jump.includes("eloise.double_jump"));
  const receipt = structuredClone((state.progression.campaign as Record<string, unknown>).chapters);
  assert.equal(completeChapter(state, { xp: 500, gold: 999 }).xp, 0);
  assert.equal(state.progression.gold, 150);
  assert.deepEqual((state.progression.campaign as Record<string, unknown>).chapters, receipt);
  // Reordering or appending content cannot grant a stable chapter twice.
  assert.equal(completeChapter(state, undefined, { missions: [...catalog.chapters[0]!.missions].reverse() }).xp, 0);
  assert.equal(completeChapter(state, undefined, { missions: [...catalog.chapters[0]!.missions,
    { ...catalog.chapters[0]!.missions[0]!, id: "later_mission", firstClearXp: 7 }] }).xp, 7);
  assert.equal(state.progression.gold, 150);
});

test("incomplete chapter grants no completion rewards; invalid rewards and overflow fail before mutations", () => {
  const incomplete = starterCanonicalState("main", "chapter-player");
  assert.equal(completeChapter(incomplete).xp, 76);
  assert.equal(incomplete.progression.gold, 0);
  for (const override of [
    { rewardXp: -1 }, { rewardGold: 1000001 },
    { rewardItems: [{ kind: "gear" as const, slot: "mainWeapon", itemId: "invented" }] },
    { rewardItems: [{ kind: "ability" as const, slot: "jump", itemId: "eloise.double_jump", characterId: "bountyHunter" }] },
  ]) {
    const state = readyForFinalMission();
    const before = structuredClone(state);
    assert.throws(() => completeChapter(state, undefined, override));
    assert.deepEqual(state, before);
  }
  const state = readyForFinalMission();
  state.progression.gold = Number.MAX_SAFE_INTEGER;
  const before = structuredClone(state);
  assert.throws(() => completeChapter(state));
  assert.deepEqual(state, before);
});

function settleMission(state: ReturnType<typeof starterCanonicalState>, override: Partial<CampaignCatalog["chapters"][number]["missions"][number]> = {}, reason = "missionCompleted") {
  const mission = { ...catalog.chapters[0]!.missions[0]!, firstClearXp: 75, firstClearGold: 90,
    firstClearItems: [
      { kind: "gear" as const, slot: "mainWeapon", itemId: "cinderedge" },
      { kind: "ability" as const, slot: "jump", itemId: "eloise.double_jump", characterId: "eloise" },
      { kind: "projectileSpell" as const, slot: "projectile", itemId: "hunterBrushgun", characterId: "bountyHunter" },
    ], ...override };
  const current = { ...catalog, chapters: [{ ...catalog.chapters[0]!, missions: [mission], rewardXp: 10, rewardGold: 20 }] };
  const campaign = authorizeCampaignMission(state.progression, mission.id, mission.levelId, current);
  return applyCampaignProgress({ canonical: state, catalog: current, nowMs: 1234,
    session: { mode: "campaign", levelId: mission.levelId, runTicket: { campaign } },
    validatedRun: { accepted: true, campaign, endedReason: reason, score: 100, tick: 50,
      runSessionId: "mission_reward", playerRunStats: { schemaVersion: 1 } } });
}

test("mission rewards and chapter rewards grant atomically once, with explicit skill recipients", () => {
  const state = starterCanonicalState("main", "mission-player");
  const selection = structuredClone(state.selection);
  assert.equal(settleMission(state, {}, "gaveUp").xp, 0);
  assert.equal(state.progression.gold, 0);
  assert.equal(settleMission(state).xp, 85);
  assert.equal(state.progression.gold, 110);
  assert.deepEqual(state.selection, selection);
  const inventory = state.meta.inventory as { weapons: string[] };
  assert.equal(inventory.weapons.filter((id) => id === "cinderedge").length, 1);
  const ownership = state.meta.abilityOwnershipByCharacter as Record<string, { projectileSpells: string[]; abilitiesBySlot: { jump: string[] } }>;
  assert.ok(ownership.eloise!.abilitiesBySlot.jump.includes("eloise.double_jump"));
  assert.ok(ownership.bountyHunter!.projectileSpells.includes("hunterBrushgun"));
  assert.ok(!ownership.eloise!.projectileSpells.includes("hunterBrushgun"));
  const receipt = structuredClone((state.progression.campaign as Record<string, Record<string, unknown>>).missions);
  assert.equal(settleMission(state, { firstClearXp: 500, firstClearGold: 999 }).xp, 0);
  assert.equal(state.progression.gold, 110);
  const missions = (state.progression.campaign as Record<string, Record<string, unknown>>).missions;
  const id = catalog.chapters[0]!.missions[0]!.id;
  assert.deepEqual((missions![id] as Record<string, unknown>).rewards, (receipt![id] as Record<string, unknown>).rewards);
});

test("invalid mission rewards and combined wallet overflow fail before mutations", () => {
  const gear = { kind: "gear" as const, slot: "mainWeapon", itemId: "cinderedge" };
  for (const override of [
    { firstClearXp: 100001 }, { firstClearGold: -1 }, { firstClearGold: 1000001 },
    { firstClearItems: [gear, gear] }, { firstClearItems: Array(9).fill(gear) },
    { firstClearItems: [{ ...gear, itemId: "invented" }] },
    { firstClearItems: [{ kind: "ability" as const, slot: "jump", itemId: "eloise.double_jump", characterId: "bountyHunter" }] },
  ]) {
    const state = starterCanonicalState("main", "mission-player");
    const before = structuredClone(state);
    assert.throws(() => settleMission(state, override));
    assert.deepEqual(state, before);
  }
  const state = starterCanonicalState("main", "mission-player");
  state.progression.gold = Number.MAX_SAFE_INTEGER - 100;
  const before = structuredClone(state);
  assert.throws(() => settleMission(state));
  assert.deepEqual(state, before);
});
