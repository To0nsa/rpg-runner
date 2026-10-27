import { playerLevelFromTotalXp } from "../ownership/player_progress.js";
import type { SystemMessageDelivery } from "./store.js";

/** Gold per newly crossed level; modest placeholder until individual milestones are authored. */
export const levelRewardGold = 25;

/** Only this settlement's crossings qualify. Loading an account never backfills gifts. */
export function levelUpDeliveries(previousXp: number, nextXp: number): SystemMessageDelivery[] {
  const deliveries: SystemMessageDelivery[] = [];
  const previousLevel = playerLevelFromTotalXp(previousXp);
  const nextLevel = playerLevelFromTotalXp(nextXp);
  for (let level = previousLevel + 1; level <= nextLevel; level += 1) {
    deliveries.push({ sourceId: `level:${level}`, title: `Level ${level} reached`,
      body: `You have reached level ${level}. Your gold reward is ready to claim.`, goldAmount: levelRewardGold });
  }
  return deliveries;
}
