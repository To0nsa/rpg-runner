import { randomInt } from "node:crypto";

import plan from "./navigation_routes.json";

export const practiceRoutePoolId = plan.poolId;

/** Release-curated routes; geometry still comes from the issued seed and Core. */
export function practiceSeedsForLevel(levelId: string): readonly number[] {
  const pools: Readonly<Record<string, readonly number[]>> = plan.practiceSeeds;
  const seeds = pools[levelId];
  if (plan.version !== 1 || !seeds || seeds.length < 2 ||
      new Set(seeds).size !== seeds.length ||
      seeds.some((seed) => !Number.isSafeInteger(seed) || seed <= 0 || seed > 0x7fffffff)) {
    throw new Error(`Invalid prepared Practice route pool for ${levelId}.`);
  }
  return seeds;
}

/** Excludes the previously issued seed, including across pool rotations. */
export function choosePracticeSeed(levelId: string, previousSeed: unknown): number {
  const candidates = practiceSeedsForLevel(levelId).filter((seed) => seed !== previousSeed);
  return candidates[randomInt(candidates.length)]!;
}
