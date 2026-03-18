import type { Firestore } from "firebase-admin/firestore";

import { sha256Hex } from "../ownership/hash.js";
import { type BoardStatus } from "./contracts.js";
import { resolveWindowForMode, type ResolvedWindow } from "./windowing.js";

const leaderboardBoardsCollection = "leaderboard_boards";
const rankedModes = ["competitive", "weekly"] as const;
export type RankedBoardMode = (typeof rankedModes)[number];

const defaultManagedLevelIds = ["field", "forest"];
const defaultGameCompatVersion = "2026.03.0";
const defaultRulesetVersion = "rules-v1";
const defaultScoreVersion = "score-v1";
const defaultGhostVersion = "ghost-v1";
const defaultTickHz = 60;
const defaultSeedNamespace = "rpg-runner-board-seed-v1";
const defaultBoardStatus: BoardStatus = "active";

export interface BoardProvisioningConfig {
  competitiveLevelIds: string[];
  weeklyLevelId: string;
  gameCompatVersion: string;
  rulesetVersion: string;
  scoreVersion: string;
  ghostVersion: string;
  tickHz: number;
  seedNamespace: string;
  status: BoardStatus;
}

export interface BoardProvisioningResult {
  nowMs: number;
  checkedCount: number;
  createdCount: number;
  existingCount: number;
  skippedUnmanagedLevelCount: number;
}

export interface EnsureManagedLeaderboardBoardsArgs {
  db: Firestore;
  nowMs?: number;
  config?: BoardProvisioningConfig;
  includeNextWindows?: boolean;
}

export interface EnsureManagedBoardForModeLevelArgs {
  db: Firestore;
  mode: RankedBoardMode;
  levelId: string;
  nowMs?: number;
  config?: BoardProvisioningConfig;
  includeNextWindows?: boolean;
}

export function buildManagedBoardId(args: {
  mode: RankedBoardMode;
  levelId: string;
  windowId: string;
}): string {
  return buildBoardId(args);
}

export function resolveBoardProvisioningConfig(
  env: NodeJS.ProcessEnv = process.env,
): BoardProvisioningConfig {
  const competitiveLevelIds = parseLevelIds(
    env.RUN_COMPETITIVE_LEVEL_IDS ?? env.RUN_BOARD_LEVEL_IDS,
    defaultManagedLevelIds,
  );
  const weeklyLevelId = readStringOrDefault(
    env.RUN_WEEKLY_LEVEL_ID,
    competitiveLevelIds[0] ?? defaultManagedLevelIds[0]!,
  );
  return {
    competitiveLevelIds,
    weeklyLevelId,
    gameCompatVersion: readStringOrDefault(
      env.RUN_BOARD_GAME_COMPAT_VERSION,
      defaultGameCompatVersion,
    ),
    rulesetVersion: readStringOrDefault(
      env.RUN_BOARD_RULESET_VERSION,
      defaultRulesetVersion,
    ),
    scoreVersion: readStringOrDefault(
      env.RUN_BOARD_SCORE_VERSION,
      defaultScoreVersion,
    ),
    ghostVersion: readStringOrDefault(
      env.RUN_BOARD_GHOST_VERSION,
      defaultGhostVersion,
    ),
    tickHz: readPositiveIntOrDefault(env.RUN_BOARD_TICK_HZ, defaultTickHz),
    seedNamespace: readStringOrDefault(
      env.RUN_BOARD_SEED_NAMESPACE,
      defaultSeedNamespace,
    ),
    status: readBoardStatusOrDefault(env.RUN_BOARD_STATUS, defaultBoardStatus),
  };
}

export async function ensureManagedLeaderboardBoards(
  args: EnsureManagedLeaderboardBoardsArgs,
): Promise<BoardProvisioningResult> {
  const config = args.config ?? resolveBoardProvisioningConfig();
  const nowMs = args.nowMs ?? Date.now();
  const includeNextWindows = args.includeNextWindows ?? true;

  let checkedCount = 0;
  let createdCount = 0;
  let existingCount = 0;

  for (const mode of rankedModes) {
    for (const levelId of managedLevelsForMode(config, mode)) {
      const windows = windowsForMode(mode, nowMs, includeNextWindows);
      for (const window of windows) {
        checkedCount += 1;
        const created = await ensureBoardForWindow({
          db: args.db,
          mode,
          levelId,
          window,
          config,
        });
        if (created) {
          createdCount += 1;
        } else {
          existingCount += 1;
        }
      }
    }
  }

  return {
    nowMs,
    checkedCount,
    createdCount,
    existingCount,
    skippedUnmanagedLevelCount: 0,
  };
}

export async function ensureManagedBoardForModeLevel(
  args: EnsureManagedBoardForModeLevelArgs,
): Promise<BoardProvisioningResult> {
  const config = args.config ?? resolveBoardProvisioningConfig();
  const nowMs = args.nowMs ?? Date.now();
  const levelId = args.levelId.trim();
  const managedLevels = managedLevelsForMode(config, args.mode);
  if (!managedLevels.includes(levelId)) {
    return {
      nowMs,
      checkedCount: 0,
      createdCount: 0,
      existingCount: 0,
      skippedUnmanagedLevelCount: 1,
    };
  }

  const includeNextWindows = args.includeNextWindows ?? false;
  const windows = windowsForMode(args.mode, nowMs, includeNextWindows);
  let createdCount = 0;
  let existingCount = 0;
  for (const window of windows) {
    const created = await ensureBoardForWindow({
      db: args.db,
      mode: args.mode,
      levelId,
      window,
      config,
    });
    if (created) {
      createdCount += 1;
    } else {
      existingCount += 1;
    }
  }

  return {
    nowMs,
    checkedCount: windows.length,
    createdCount,
    existingCount,
    skippedUnmanagedLevelCount: 0,
  };
}

function windowsForMode(
  mode: RankedBoardMode,
  nowMs: number,
  includeNextWindow: boolean,
): ResolvedWindow[] {
  const current = resolveWindowForMode(mode, nowMs);
  if (!includeNextWindow) {
    return [current];
  }
  const next = resolveWindowForMode(mode, current.closesAtMs + 1);
  if (next.windowId === current.windowId) {
    return [current];
  }
  return [current, next];
}

function managedLevelsForMode(
  config: BoardProvisioningConfig,
  mode: RankedBoardMode,
): string[] {
  return mode === "competitive"
    ? config.competitiveLevelIds
    : [config.weeklyLevelId];
}

async function ensureBoardForWindow(args: {
  db: Firestore;
  mode: RankedBoardMode;
  levelId: string;
  window: ResolvedWindow;
  config: BoardProvisioningConfig;
}): Promise<boolean> {
  const existingSnapshot = await args.db
    .collection(leaderboardBoardsCollection)
    .where("mode", "==", args.mode)
    .where("levelId", "==", args.levelId)
    .where("windowId", "==", args.window.windowId)
    .limit(1)
    .get();
  if (!existingSnapshot.empty) {
    return false;
  }

  const boardId = buildBoardId({
    mode: args.mode,
    levelId: args.levelId,
    windowId: args.window.windowId,
  });
  const boardDoc = {
    boardId,
    mode: args.mode,
    levelId: args.levelId,
    windowId: args.window.windowId,
    boardKey: {
      mode: args.mode,
      levelId: args.levelId,
      windowId: args.window.windowId,
      rulesetVersion: args.config.rulesetVersion,
      scoreVersion: args.config.scoreVersion,
    },
    gameCompatVersion: args.config.gameCompatVersion,
    ghostVersion: args.config.ghostVersion,
    tickHz: args.config.tickHz,
    seed: buildDeterministicSeed({
      mode: args.mode,
      levelId: args.levelId,
      windowId: args.window.windowId,
      rulesetVersion: args.config.rulesetVersion,
      scoreVersion: args.config.scoreVersion,
      gameCompatVersion: args.config.gameCompatVersion,
      seedNamespace: args.config.seedNamespace,
    }),
    opensAtMs: args.window.opensAtMs,
    closesAtMs: args.window.closesAtMs,
    status: args.config.status,
  };
  try {
    await args.db.collection(leaderboardBoardsCollection).doc(boardId).create(boardDoc);
    return true;
  } catch (error) {
    if (isAlreadyExistsError(error)) {
      return false;
    }
    throw error;
  }
}

function buildDeterministicSeed(args: {
  mode: RankedBoardMode;
  levelId: string;
  windowId: string;
  rulesetVersion: string;
  scoreVersion: string;
  gameCompatVersion: string;
  seedNamespace: string;
}): number {
  const digest = sha256Hex(
    [
      args.seedNamespace,
      args.mode,
      args.levelId,
      args.windowId,
      args.rulesetVersion,
      args.scoreVersion,
      args.gameCompatVersion,
    ].join("|"),
  );
  const parsed = Number.parseInt(digest.slice(0, 8), 16);
  const positive = parsed & 0x7fffffff;
  return positive === 0 ? 1 : positive;
}

function buildBoardId(args: {
  mode: RankedBoardMode;
  levelId: string;
  windowId: string;
}): string {
  const windowToken = sanitizeIdPart(args.windowId.toLowerCase());
  const levelToken = sanitizeIdPart(args.levelId.toLowerCase());
  return `board_${args.mode}_${windowToken}_${levelToken}`;
}

function sanitizeIdPart(value: string): string {
  const sanitized = value.replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "");
  return sanitized.length === 0 ? "unknown" : sanitized;
}

function parseLevelIds(raw: string | undefined, fallback: string[]): string[] {
  const source = raw?.trim();
  if (!source) {
    return fallback.slice();
  }
  const seen = new Set<string>();
  for (const part of source.split(",")) {
    const trimmed = part.trim();
    if (!trimmed) {
      continue;
    }
    seen.add(trimmed);
  }
  if (seen.size === 0) {
    return fallback.slice();
  }
  return [...seen];
}

function readStringOrDefault(raw: string | undefined, fallback: string): string {
  const trimmed = raw?.trim();
  return trimmed && trimmed.length > 0 ? trimmed : fallback;
}

function readPositiveIntOrDefault(raw: string | undefined, fallback: number): number {
  const trimmed = raw?.trim();
  if (!trimmed) {
    return fallback;
  }
  const parsed = Number.parseInt(trimmed, 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return fallback;
  }
  return parsed;
}

function readBoardStatusOrDefault(
  raw: string | undefined,
  fallback: BoardStatus,
): BoardStatus {
  const trimmed = raw?.trim();
  if (!trimmed) {
    return fallback;
  }
  switch (trimmed) {
    case "scheduled":
    case "active":
    case "closed":
    case "disabled":
      return trimmed;
    default:
      return fallback;
  }
}

function isAlreadyExistsError(error: unknown): boolean {
  if (!error || typeof error !== "object") {
    return false;
  }
  const maybeCode = (error as { code?: unknown }).code;
  return maybeCode === 6 || maybeCode === "already-exists";
}
