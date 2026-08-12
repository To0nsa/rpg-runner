import {
  isRunSessionState,
  isTerminalRunSessionState,
} from "./session_state.js";

export const maximumRunTicketLifetimeMs = 24 * 60 * 60 * 1000;

export interface CompatibilityRetirementSessionEvidence {
  gameCompatVersion: string | null;
  state: string | null;
  issuedAtMs: number | null;
}

export interface CompatibilityRetirementAssessment {
  gameCompatVersion: string;
  issuanceCutoffAtMs: number;
  maxTicketLifetimeMs: number;
  earliestRemovalAtMs: number;
  intervalElapsed: boolean;
  observedSessionCount: number;
  activeSessionCount: number;
  activeSessionStateCounts: Readonly<Record<string, number>>;
  invalidSessionStateCount: number;
  issuedAfterCutoffCount: number;
  invalidIssuedAtCount: number;
  observedLatestIssuedAtMs: number | null;
  readyForRemoval: boolean;
  blockers: readonly string[];
}

/**
 * Evaluates the fail-closed evidence required to retire one game version.
 *
 * This function is read-only. Callers own the production inventory and must
 * pass every observed session rather than a prefiltered subset.
 */
export function assessCompatibilityRetirement(args: {
  sessions: readonly CompatibilityRetirementSessionEvidence[];
  observedAtMs: number;
  gameCompatVersion: string;
  issuanceCutoffAtMs: number;
}): CompatibilityRetirementAssessment {
  const gameCompatVersion = args.gameCompatVersion.trim();
  if (gameCompatVersion.length === 0) {
    throw new Error("gameCompatVersion must be non-empty.");
  }
  requirePositiveSafeInteger(args.observedAtMs, "observedAtMs");
  requirePositiveSafeInteger(args.issuanceCutoffAtMs, "issuanceCutoffAtMs");

  const earliestRemovalAtMs =
    args.issuanceCutoffAtMs + maximumRunTicketLifetimeMs;
  const matchingSessions = args.sessions.filter(
    (session) => session.gameCompatVersion === gameCompatVersion,
  );
  const activeSessions = matchingSessions.filter(
    (session) =>
      isRunSessionState(session.state) &&
      !isTerminalRunSessionState(session.state),
  );
  const invalidSessionStateCount = matchingSessions.filter(
    (session) => !isRunSessionState(session.state),
  ).length;
  const activeSessionStateCounts: Record<string, number> = {};
  for (const session of activeSessions) {
    const state = session.state!;
    activeSessionStateCounts[state] =
      (activeSessionStateCounts[state] ?? 0) + 1;
  }
  const issuedAtValues = matchingSessions
    .map((session) => session.issuedAtMs)
    .filter(
      (issuedAtMs): issuedAtMs is number =>
        issuedAtMs != null &&
        Number.isSafeInteger(issuedAtMs) &&
        issuedAtMs > 0,
    );
  const issuedAfterCutoffCount = issuedAtValues.filter(
    (issuedAtMs) => issuedAtMs > args.issuanceCutoffAtMs,
  ).length;
  const intervalElapsed = args.observedAtMs >= earliestRemovalAtMs;
  const invalidIssuedAtCount = matchingSessions.length - issuedAtValues.length;
  const blockers: string[] = [];
  if (!intervalElapsed) {
    blockers.push("ticket_lifetime_not_elapsed");
  }
  if (activeSessions.length > 0) {
    blockers.push("active_sessions_remain");
  }
  if (issuedAfterCutoffCount > 0) {
    blockers.push("issuance_after_recorded_cutoff");
  }
  if (invalidIssuedAtCount > 0) {
    blockers.push("unassessable_issued_at_evidence");
  }
  if (invalidSessionStateCount > 0) {
    blockers.push("unassessable_session_state_evidence");
  }

  return {
    gameCompatVersion,
    issuanceCutoffAtMs: args.issuanceCutoffAtMs,
    maxTicketLifetimeMs: maximumRunTicketLifetimeMs,
    earliestRemovalAtMs,
    intervalElapsed,
    observedSessionCount: matchingSessions.length,
    activeSessionCount: activeSessions.length,
    activeSessionStateCounts: Object.fromEntries(
      Object.entries(activeSessionStateCounts).sort(([left], [right]) =>
        left.localeCompare(right),
      ),
    ),
    invalidSessionStateCount,
    issuedAfterCutoffCount,
    invalidIssuedAtCount,
    observedLatestIssuedAtMs:
      issuedAtValues.length === 0 ? null : Math.max(...issuedAtValues),
    readyForRemoval: blockers.length === 0,
    blockers,
  };
}

function requirePositiveSafeInteger(value: number, name: string): void {
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new Error(`${name} must be a positive safe integer.`);
  }
}
