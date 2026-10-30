import { randomUUID } from "node:crypto";
import { performance } from "node:perf_hooks";
import * as logger from "firebase-functions/logger";

const clockId = randomUUID();
let sequence = 0;

/** Run IDs are correlation keys. Never pass identities, URLs or replay data. */
export function logRewardTiming(runSessionId: string, stage: string,
  fields: Record<string, string | number | boolean> = {}): void {
  try {
    logger.info("run_reward_timing", {
      event: "run_reward_timing", schemaVersion: 1, component: "functions",
      runSessionId, stage, clockId, sequence: ++sequence,
      utcMs: Date.now(), monoUs: Math.round(performance.now() * 1000), ...fields,
    });
  } catch {
    // Observability must never change a transaction's outcome or retry policy.
  }
}

export async function measureRewardStage<T>(runSessionId: string, stage: string,
  action: () => Promise<T>): Promise<T> {
  const span = ++sequence;
  const started = performance.now();
  logRewardTiming(runSessionId, stage, { span, outcome: "started" });
  let outcome = "failed";
  try {
    const result = await action();
    outcome = "completed";
    return result;
  } finally {
    logRewardTiming(runSessionId, stage, {
      span, outcome, durationUs: Math.round((performance.now() - started) * 1000),
    });
  }
}
