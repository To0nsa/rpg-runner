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
  assert.throws(() => authorizeCampaignMission(state.progression, "reporting_for_duty", "forest"));
  const request = { userId: "u", sessionId: "s", clientRequestId: "request", mode: "campaign", levelId: "forest", gameCompatVersion: "2026.11.11" };
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
