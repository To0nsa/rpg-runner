import type { Firestore, Transaction } from "firebase-admin/firestore";

import type { JsonObject, OwnershipCanonicalState } from "./contracts.js";

const rewardGrantsCollection = "reward_grants";
const rewardGrantLifecycleProvisionalCreated = "provisional_created";
const rewardGrantLifecycleProvisionalVisible = "provisional_visible";
const rewardGrantLifecycleValidatedSettled = "validated_settled";
const rewardGrantLifecycleRevocationVisible = "revocation_visible";
const rewardGrantLifecycleRevokedFinal = "revoked_final";
const maxAppliedRewardGrantIds = 512;
const rewardGrantBatchLimit = 64;
const weeklyProgressSchemaVersion = 1;

export interface RewardGrantReconcileResult {
  canonicalState: OwnershipCanonicalState;
  canonicalChanged: boolean;
  appliedGrantCount: number;
  revokedGrantCount: number;
}

export async function reconcilePendingRewardGrantsForTransaction(args: {
  db: Firestore;
  tx: Transaction;
  uid: string;
  canonicalState: OwnershipCanonicalState;
  nowMs?: number;
}): Promise<RewardGrantReconcileResult> {
  const nowMs = args.nowMs ?? Date.now();
  const rewardGrantQuery = args.db
    .collection(rewardGrantsCollection)
    .where("uid", "==", args.uid)
    .limit(rewardGrantBatchLimit);
  const rewardGrantSnapshot = await args.tx.get(rewardGrantQuery);
  if (rewardGrantSnapshot.empty) {
    return {
      canonicalState: args.canonicalState,
      canonicalChanged: false,
      appliedGrantCount: 0,
      revokedGrantCount: 0,
    };
  }

  const progression = asRecord(structuredClone(args.canonicalState.progression));
  let canonicalChanged = false;
  let gold = parseInteger(progression.gold) ?? 0;
  if (progression.gold !== gold) {
    progression.gold = gold;
    canonicalChanged = true;
  }

  const appliedRewardGrantIds = normalizeStringList(
    progression.appliedRewardGrantIds,
  );
  if (
    !Array.isArray(progression.appliedRewardGrantIds) ||
    appliedRewardGrantIds.length !== progression.appliedRewardGrantIds.length
  ) {
    progression.appliedRewardGrantIds = [...appliedRewardGrantIds];
    canonicalChanged = true;
  }
  const appliedRewardGrantIdSet = new Set(appliedRewardGrantIds);

  let appliedGrantCount = 0;
  let revokedGrantCount = 0;
  for (const rewardGrantDoc of rewardGrantSnapshot.docs) {
    const rewardGrant = rewardGrantDoc.data() as Record<string, unknown>;
    const stateResolution = resolveRewardGrantSettlementState(rewardGrant);

    if (stateResolution === "settle") {
      const grantId = rewardGrantDoc.id;
      const goldAmount = parseInteger(rewardGrant.goldAmount) ?? 0;
      if (!appliedRewardGrantIdSet.has(grantId)) {
        const nonNegativeGoldAmount = Math.max(0, goldAmount);
        const nextGold = gold + nonNegativeGoldAmount;
        if (!Number.isSafeInteger(nextGold) || nextGold < 0) {
          throw new Error(
            `reward_grants/${grantId} would overflow progression.gold.`,
          );
        }
        gold = nextGold;
        appliedRewardGrantIds.push(grantId);
        appliedRewardGrantIdSet.add(grantId);
        canonicalChanged = true;
        const weeklyChanged = applyWeeklyProgressHook({
          progression,
          rewardGrant,
          grantId,
          nowMs,
          grantedGoldAmount: nonNegativeGoldAmount,
        });
        if (weeklyChanged) {
          canonicalChanged = true;
        }
      }

      args.tx.set(
        rewardGrantDoc.ref,
        {
          lifecycleState: rewardGrantLifecycleValidatedSettled,
          appliedAtMs: nowMs,
          updatedAtMs: nowMs,
          appliedProfileId: args.canonicalState.profileId,
          appliedRevision: args.canonicalState.revision,
        },
        { merge: true },
      );
      appliedGrantCount += 1;
      continue;
    }

    if (stateResolution === "terminalize_revoked") {
      // revocation_visible → revoked_final: no gold change, just close the lifecycle.
      args.tx.set(
        rewardGrantDoc.ref,
        {
          lifecycleState: rewardGrantLifecycleRevokedFinal,
          updatedAtMs: nowMs,
          revokedFinalAtMs: nowMs,
          revokedFinalBy: "ownership_reconcile",
        },
        { merge: true },
      );
      revokedGrantCount += 1;
    }
  }

  if (appliedRewardGrantIds.length > maxAppliedRewardGrantIds) {
    appliedRewardGrantIds.splice(
      0,
      appliedRewardGrantIds.length - maxAppliedRewardGrantIds,
    );
    canonicalChanged = true;
  }

  if (!canonicalChanged) {
    return {
      canonicalState: args.canonicalState,
      canonicalChanged: false,
      appliedGrantCount,
      revokedGrantCount,
    };
  }

  progression.gold = gold;
  progression.appliedRewardGrantIds = appliedRewardGrantIds;
  return {
    canonicalState: {
      ...args.canonicalState,
      progression: progression as JsonObject,
    },
    canonicalChanged: true,
    appliedGrantCount,
    revokedGrantCount,
  };
}

function asRecord(value: unknown): Record<string, unknown> {
  if (value !== null && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return {};
}

function asNullableRecord(value: unknown): Record<string, unknown> | null {
  if (value !== null && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return null;
}

function parseInteger(value: unknown): number | null {
  if (typeof value === "number" && Number.isInteger(value)) {
    return value;
  }
  return null;
}

function normalizeStringList(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  const out: string[] = [];
  for (const item of value) {
    if (typeof item === "string" && item.trim().length > 0) {
      out.push(item.trim());
    }
  }
  return out;
}

function applyWeeklyProgressHook(args: {
  progression: Record<string, unknown>;
  rewardGrant: Record<string, unknown>;
  grantId: string;
  nowMs: number;
  grantedGoldAmount: number;
}): boolean {
  const mode = readMode(args.rewardGrant.mode);
  if (mode !== "weekly") {
    return false;
  }

  const weekly = ensureWeeklyProgressObject(args.progression);
  const windowId = readWeeklyWindowId(args.rewardGrant);
  const runSessionId = readOptionalNonEmptyString(args.rewardGrant.runSessionId);
  const boardId = readOptionalNonEmptyString(args.rewardGrant.boardId);
  const validatedAtMs =
    parseInteger(args.rewardGrant.createdAtMs) ??
    parseInteger(args.rewardGrant.updatedAtMs) ??
    args.nowMs;

  let changed = false;
  changed = ensureWeeklyProgressInteger(weekly, "schemaVersion", 1) || changed;
  changed =
    ensureWeeklyProgressInteger(
      weekly,
      "lifetimeValidatedRuns",
      0,
    ) || changed;
  changed =
    ensureWeeklyProgressInteger(
      weekly,
      "lifetimeGoldEarned",
      0,
    ) || changed;
  changed =
    ensureWeeklyProgressInteger(
      weekly,
      "currentWindowValidatedRuns",
      0,
    ) || changed;
  changed =
    ensureWeeklyProgressInteger(
      weekly,
      "currentWindowGoldEarned",
      0,
    ) || changed;

  weekly.schemaVersion = weeklyProgressSchemaVersion;
  changed = true;

  const currentWindowId = readOptionalNonEmptyString(weekly.currentWindowId);
  if (windowId != null && currentWindowId !== windowId) {
    weekly.currentWindowId = windowId;
    weekly.currentWindowValidatedRuns = 0;
    weekly.currentWindowGoldEarned = 0;
  }

  const nextLifetimeValidatedRuns =
    (parseInteger(weekly.lifetimeValidatedRuns) ?? 0) + 1;
  if (!Number.isSafeInteger(nextLifetimeValidatedRuns) || nextLifetimeValidatedRuns < 0) {
    throw new Error(
      `reward_grants/${args.grantId} would overflow weekly lifetimeValidatedRuns.`,
    );
  }
  weekly.lifetimeValidatedRuns = nextLifetimeValidatedRuns;

  const nextLifetimeGold =
    (parseInteger(weekly.lifetimeGoldEarned) ?? 0) + args.grantedGoldAmount;
  if (!Number.isSafeInteger(nextLifetimeGold) || nextLifetimeGold < 0) {
    throw new Error(
      `reward_grants/${args.grantId} would overflow weekly lifetimeGoldEarned.`,
    );
  }
  weekly.lifetimeGoldEarned = nextLifetimeGold;

  const nextCurrentWindowValidatedRuns =
    (parseInteger(weekly.currentWindowValidatedRuns) ?? 0) + 1;
  if (
    !Number.isSafeInteger(nextCurrentWindowValidatedRuns) ||
    nextCurrentWindowValidatedRuns < 0
  ) {
    throw new Error(
      `reward_grants/${args.grantId} would overflow weekly currentWindowValidatedRuns.`,
    );
  }
  weekly.currentWindowValidatedRuns = nextCurrentWindowValidatedRuns;

  const nextCurrentWindowGold =
    (parseInteger(weekly.currentWindowGoldEarned) ?? 0) + args.grantedGoldAmount;
  if (!Number.isSafeInteger(nextCurrentWindowGold) || nextCurrentWindowGold < 0) {
    throw new Error(
      `reward_grants/${args.grantId} would overflow weekly currentWindowGoldEarned.`,
    );
  }
  weekly.currentWindowGoldEarned = nextCurrentWindowGold;

  weekly.lastValidatedAtMs = validatedAtMs;
  if (windowId != null) {
    weekly.lastWindowId = windowId;
  }
  if (boardId != null) {
    weekly.lastBoardId = boardId;
  }
  weekly.lastRewardGrantId = args.grantId;
  if (runSessionId != null) {
    weekly.lastRunSessionId = runSessionId;
  }

  return changed;
}

function ensureWeeklyProgressObject(
  progression: Record<string, unknown>,
): Record<string, unknown> {
  const candidate = asNullableRecord(progression.weeklyProgress);
  if (candidate !== null) {
    return candidate;
  }
  const created: Record<string, unknown> = {
    schemaVersion: weeklyProgressSchemaVersion,
    currentWindowValidatedRuns: 0,
    currentWindowGoldEarned: 0,
    lifetimeValidatedRuns: 0,
    lifetimeGoldEarned: 0,
  };
  progression.weeklyProgress = created;
  return created;
}

function ensureWeeklyProgressInteger(
  weeklyProgress: Record<string, unknown>,
  key: string,
  fallback: number,
): boolean {
  const existing = parseInteger(weeklyProgress[key]);
  const normalized = existing ?? fallback;
  if (weeklyProgress[key] !== normalized) {
    weeklyProgress[key] = normalized;
    return true;
  }
  return false;
}

function readMode(value: unknown): "practice" | "competitive" | "weekly" | null {
  if (value !== "practice" && value !== "competitive" && value !== "weekly") {
    return null;
  }
  return value;
}

function readWeeklyWindowId(rewardGrant: Record<string, unknown>): string | null {
  const boardKey = asNullableRecord(rewardGrant.boardKey);
  if (boardKey !== null) {
    const fromBoardKey = readOptionalNonEmptyString(boardKey.windowId);
    if (fromBoardKey !== null) {
      return fromBoardKey;
    }
  }
  return readOptionalNonEmptyString(rewardGrant.windowId);
}

function readOptionalNonEmptyString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function resolveRewardGrantSettlementState(
  rewardGrant: Record<string, unknown>,
): "settle" | "terminalize_revoked" | "skip" {
  const lifecycleState = readOptionalNonEmptyString(rewardGrant.lifecycleState);
  if (lifecycleState == null) {
    return "skip";
  }

  if (lifecycleState === rewardGrantLifecycleValidatedSettled) {
    return "settle";
  }

  if (lifecycleState === rewardGrantLifecycleRevocationVisible) {
    return "terminalize_revoked";
  }

  if (
    lifecycleState === rewardGrantLifecycleProvisionalCreated ||
    lifecycleState === rewardGrantLifecycleProvisionalVisible ||
    lifecycleState === rewardGrantLifecycleRevokedFinal
  ) {
    return "skip";
  }

  return "skip";
}
