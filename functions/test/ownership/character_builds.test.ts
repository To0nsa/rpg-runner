import { parseExecuteCommandRequest } from "../../src/ownership/validators.js";
import assert from "node:assert/strict";
import { test } from "node:test";
import { applyOwnershipCommand } from "../../src/ownership/apply_command.js";
import { starterCanonicalState } from "../../src/ownership/defaults.js";
import { buildAt, characterBuilds, confirmedPlayerLevel, selectedLoadout, validBuildName } from "../../src/ownership/character_builds.js";
import type { JsonObject, OwnershipCanonicalState, OwnershipCommandType } from "../../src/ownership/contracts.js";

function atLevel(level: number) {
  const state = starterCanonicalState("main", "builds");
  let totalXp = 0;
  for (let i = 1; i < level; i++) totalXp += Math.round(100 * 1.24 ** (i - 1));
  (state.progression.playerProgress as JsonObject).totalXp = totalXp;
  assert.equal(confirmedPlayerLevel(state.progression), level);
  return state;
}
function apply(state: OwnershipCanonicalState, type: OwnershipCommandType, payload: JsonObject) {
  return applyOwnershipCommand(state, { type, payload, userId: "builds", sessionId: "session", expectedRevision: 0, commandId: "build-command" });
}
for (const [level, unlocked] of [[1, 1], [4, 1], [5, 2], [11, 2], [12, 3]]) {
  test(`level ${level} authorizes exactly ${unlocked} build slots`, () => {
    const state = atLevel(level);
    for (let index = 0; index < 3; index++) {
      const selection = structuredClone(state.selection);
      characterBuilds(selection, "bountyHunter")!.selectedBuildIndex = index;
      assert.equal(apply(state, "setSelection", { selection }).accepted, index < unlocked);
      assert.equal(selectedLoadout(selection, "bountyHunter", state.progression) !== null, index < unlocked);
      for (const [type, fields] of [
        ["setLoadout", { loadout: buildAt(state.selection, "bountyHunter", 0)!.loadout }],
        ["setProjectileSpell", { spellId: "hunterCrossbow" }],
        ["setAbilitySlot", { slot: "primary", abilityId: "bounty_hunter.quick_cut" }],
        ["equipGear", { slot: "mainWeapon", itemDomain: "weapon", itemId: "hunterBlade" }],
      ] as [OwnershipCommandType, JsonObject][]) {
        assert.equal(apply(state, type, { characterId: "bountyHunter", buildIndex: index, ...fields }).accepted, index < unlocked, type);
      }
    }
  });
}
test("whole selection cannot modify locked inactive builds", () => {
  const state = atLevel(1);
  for (const change of ["name", "loadout"]) {
    const selection = structuredClone(state.selection);
    const build = buildAt(selection, "bountyHunter", 1)!;
    if (change === "name") build.name = "Forbidden";
    else (build.loadout as JsonObject).projectileSlotSpellId = "hunterCrossbow";
    assert.equal(apply(state, "setSelection", { selection }).accepted, false);
  }
});
test("queued edits retain their build after selection changes", () => {
  const state = atLevel(12);
  const selection = structuredClone(state.selection);
  characterBuilds(selection, "bountyHunter")!.selectedBuildIndex = 2;
  const switched = apply(state, "setSelection", { selection });
  assert.equal(switched.accepted, true);
  if (!switched.accepted) return;
  const edited = apply(switched.canonicalState, "setProjectileSpell", { characterId: "bountyHunter", buildIndex: 0, spellId: "hunterShotgun" });
  assert.equal(edited.accepted, true);
  if (!edited.accepted) return;
  assert.equal((buildAt(edited.canonicalState.selection, "bountyHunter", 0)!.loadout as JsonObject).projectileSlotSpellId, "hunterShotgun");
  assert.equal(selectedLoadout(edited.canonicalState.selection, "bountyHunter", state.progression)!.projectileSlotSpellId, "hunterPistol");
  assert.equal(selectedLoadout(edited.canonicalState.selection, "eloise", state.progression)!.projectileSlotSpellId, "acidBolt");
});
test("full loadout and selection keep active equipment meta in sync", () => {
  const state = atLevel(12);
  ((state.meta.inventory as JsonObject).weapons as string[]).push("waspfang");
  const loadout = structuredClone(buildAt(state.selection, "eloise", 0)!.loadout) as JsonObject;
  loadout.mainWeaponId = "waspfang";
  const edited = apply(state, "setLoadout", { characterId: "eloise", buildIndex: 1, loadout });
  assert.equal(edited.accepted, true);
  if (!edited.accepted) return;
  assert.equal(((edited.canonicalState.meta.equippedByCharacter as JsonObject).eloise as JsonObject).mainWeaponId, "plainsteel");
  const selection = structuredClone(edited.canonicalState.selection);
  characterBuilds(selection, "eloise")!.selectedBuildIndex = 1;
  const switched = apply(edited.canonicalState, "setSelection", { selection });
  assert.equal(switched.accepted, true);
  if (switched.accepted) assert.equal(((switched.canonicalState.meta.equippedByCharacter as JsonObject).eloise as JsonObject).mainWeaponId, "waspfang");
});
test("names count graphemes and missing or invalid indices fail closed", () => {
  const emoji = String.fromCodePoint(0x1f469, 0x1f3fd, 0x200d, 0x1f680);
  assert.equal(validBuildName("  Build 3  "), "Build 3");
  for (const name of ["a".repeat(28), emoji.repeat(28)]) {
    assert.equal(validBuildName(name), name);
    const state = atLevel(12);
    const selection = structuredClone(state.selection);
    buildAt(selection, "eloise", 0)!.name = name;
    const command = { type: "setSelection", payload: { selection }, userId: "builds",
      sessionId: "session", expectedRevision: 0, commandId: "build-command" };
    const parsed = parseExecuteCommandRequest({ command }).command;
    const result = applyOwnershipCommand(state, parsed);
    assert.equal(result.accepted, true);
    if (result.accepted) assert.equal(buildAt(result.canonicalState.selection, "eloise", 0)!.name, name);
  }
  for (const name of [" ", "a".repeat(29), emoji.repeat(29)]) {
    const state = atLevel(12);
    const selection = structuredClone(state.selection);
    buildAt(selection, "eloise", 0)!.name = name;
    assert.equal(apply(state, "setSelection", { selection }).accepted, false);
  }
  for (const buildIndex of [-1, 3, 1.5, "1", null]) {
    assert.equal(apply(atLevel(30), "setProjectileSpell", { characterId: "eloise", buildIndex, spellId: "holyBolt" }).accepted, false);
  }
  assert.equal(apply(atLevel(30), "setProjectileSpell", { characterId: "eloise", spellId: "holyBolt" }).accepted, false);
});

test("complete three-build producer payload fits the bounded callable envelope", () => {
  const command = { type: "setSelection", payload: { selection: atLevel(12).selection },
    userId: "builds", sessionId: "session", expectedRevision: 0, commandId: "build-command" };
  assert.deepEqual(parseExecuteCommandRequest({ command }).command, command);
});
