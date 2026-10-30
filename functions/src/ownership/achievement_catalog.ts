export type AchievementMetric = "runs" | "distanceMeters" | "durationSeconds" | "enemyKills";

/** Authored version-1 policy; changing persisted thresholds requires a migration. */
export const achievementDefinitions = [
  { id: "firstSteps", metric: "runs", aggregation: "total", thresholds: [1, 10, 50] },
  { id: "marathoner", metric: "distanceMeters", aggregation: "best", thresholds: [500, 1000, 2500] },
  { id: "roadWarrior", metric: "distanceMeters", aggregation: "total", thresholds: [1000, 10000, 50000] },
  { id: "stillStanding", metric: "durationSeconds", aggregation: "total", thresholds: [300, 3600, 18000] },
  { id: "slayer", metric: "enemyKills", aggregation: "total", thresholds: [25, 250, 2500] },
] as const;

// Bronze matches a level gift; Gold funds one current store unlock.
export const achievementTierGold = [25, 75, 150] as const;

// Either minimum qualifies a natural run end; manual quits never qualify.
export const achievementMinimumDistanceMeters = 10;
export const achievementMinimumDurationSeconds = 10;
