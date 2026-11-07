import type { JsonObject } from "./contracts.js";

/** Stable character/content identities shared by starter grants and authorization. */
export const knownCharacterIds = ["eloise", "eloiseWip", "bountyHunter"] as const;
export const hunterProjectiles = ["hunterPistol", "hunterCrossbow", "hunterShotgun"] as const;
export const hunterAbilitiesBySlot = {
  primary: ["quick_cut", "twin_cut", "threefold_cut", "lunge_slash"],
  secondary: ["blast_bomb", "shrapnel_bomb", "fire_bomb", "concussion_bomb"],
  projectile: ["snap_shot", "quick_shot", "piercing_shot", "scatter_shot", "charged_shot"],
  mobility: ["dash", "roll", "slide"],
  jump: ["jump", "double_jump"],
  spell: ["hunters_focus", "mark_quarry", "forced_march", "field_dressing", "antidote", "second_wind", "prepare_charges"],
} as const;
export const hunterGear: JsonObject = {
  mainWeaponId: "hunterBlade", offhandWeaponId: "hunterBombKit",
  spellBookId: "hunterFieldKit", accessoryId: "strengthBelt",
};
export const hunterStarterLoadout: JsonObject = {
  mask: 7, ...hunterGear, projectileSlotSpellId: "hunterPistol",
  abilityPrimaryId: "bounty_hunter.quick_cut", abilitySecondaryId: "bounty_hunter.blast_bomb",
  abilityProjectileId: "bounty_hunter.snap_shot", abilitySpellId: "bounty_hunter.hunters_focus",
  abilityMobilityId: "bounty_hunter.dash", abilityJumpId: "bounty_hunter.jump",
};
export const hunterStarterOwnership: JsonObject = {
  projectileSpells: [...hunterProjectiles],
  abilitiesBySlot: {
    primary: ["bounty_hunter.quick_cut"], secondary: ["bounty_hunter.blast_bomb"],
    projectile: ["bounty_hunter.snap_shot"], mobility: ["bounty_hunter.dash"],
    spell: ["bounty_hunter.hunters_focus", "bounty_hunter.prepare_charges"],
    jump: ["bounty_hunter.jump"],
  },
};

/** Equipment families and ability namespaces are separate from ownership. */
export function characterContentAllowed(characterId: string, domain: string, slot: string, itemId: string): boolean {
  if (!(knownCharacterIds as readonly string[]).includes(characterId)) return false;
  const hunter = characterId === "bountyHunter";
  if (domain === "ability") {
    return itemId.startsWith(hunter ? "bounty_hunter." : "eloise.") ||
      (itemId.startsWith("common.") && !itemId.startsWith("common.enemy_"));
  }
  if (domain === "projectileSpell") return hunter === (hunterProjectiles as readonly string[]).includes(itemId);
  if (domain !== "gear" || slot === "accessory") return domain === "gear";
  const expected = slot === "mainWeapon" ? "hunterBlade" :
    slot === "offhandWeapon" ? "hunterBombKit" : slot === "spellBook" ? "hunterFieldKit" : null;
  if (expected === null) return false;
  return hunter ? itemId === expected : !["hunterBlade", "hunterBombKit", "hunterFieldKit"].includes(itemId);
}
