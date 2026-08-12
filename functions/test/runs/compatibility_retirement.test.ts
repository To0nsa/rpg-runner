import assert from "node:assert/strict";
import test from "node:test";

import {
  assessCompatibilityRetirement,
  maximumRunTicketLifetimeMs,
  type CompatibilityRetirementSessionEvidence,
} from "../../src/runs/compatibility_retirement.js";

const cutoffAtMs = Date.UTC(2026, 7, 12, 14, 32, 29);

test("retirement remains blocked during the ticket lifetime", () => {
  const result = assessCompatibilityRetirement({
    sessions: [session("expired", cutoffAtMs - 1000)],
    observedAtMs: cutoffAtMs + maximumRunTicketLifetimeMs - 1,
    gameCompatVersion: "2026.03.0",
    issuanceCutoffAtMs: cutoffAtMs,
  });

  assert.equal(result.readyForRemoval, false);
  assert.deepEqual(result.blockers, ["ticket_lifetime_not_elapsed"]);
});

test("retirement remains blocked while a matching session is active", () => {
  const result = assessCompatibilityRetirement({
    sessions: [session("uploading", cutoffAtMs - 1000)],
    observedAtMs: cutoffAtMs + maximumRunTicketLifetimeMs,
    gameCompatVersion: "2026.03.0",
    issuanceCutoffAtMs: cutoffAtMs,
  });

  assert.equal(result.readyForRemoval, false);
  assert.equal(result.activeSessionCount, 1);
  assert.deepEqual(result.activeSessionStateCounts, { uploading: 1 });
  assert.deepEqual(result.blockers, ["active_sessions_remain"]);
});

test("post-cutoff issuance and malformed evidence fail closed", () => {
  const result = assessCompatibilityRetirement({
    sessions: [
      session("expired", cutoffAtMs + 1),
      session("validated", null),
      session("future_state", cutoffAtMs - 1),
    ],
    observedAtMs: cutoffAtMs + maximumRunTicketLifetimeMs,
    gameCompatVersion: "2026.03.0",
    issuanceCutoffAtMs: cutoffAtMs,
  });

  assert.equal(result.readyForRemoval, false);
  assert.equal(result.issuedAfterCutoffCount, 1);
  assert.equal(result.invalidIssuedAtCount, 1);
  assert.equal(result.invalidSessionStateCount, 1);
  assert.deepEqual(result.blockers, [
    "issuance_after_recorded_cutoff",
    "unassessable_issued_at_evidence",
    "unassessable_session_state_evidence",
  ]);
});

test("retirement is ready only with elapsed, inactive, pre-cutoff evidence", () => {
  const result = assessCompatibilityRetirement({
    sessions: [
      session("expired", cutoffAtMs - 2000),
      session("validated", cutoffAtMs - 1000),
      session("uploading", cutoffAtMs - 500, "2026.08.0"),
    ],
    observedAtMs: cutoffAtMs + maximumRunTicketLifetimeMs,
    gameCompatVersion: "2026.03.0",
    issuanceCutoffAtMs: cutoffAtMs,
  });

  assert.equal(result.readyForRemoval, true);
  assert.deepEqual(result.blockers, []);
  assert.equal(result.observedSessionCount, 2);
  assert.equal(result.activeSessionCount, 0);
  assert.equal(result.observedLatestIssuedAtMs, cutoffAtMs - 1000);
});

function session(
  state: string,
  issuedAtMs: number | null,
  gameCompatVersion = "2026.03.0",
): CompatibilityRetirementSessionEvidence {
  return { gameCompatVersion, state, issuedAtMs };
}
