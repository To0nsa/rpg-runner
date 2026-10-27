import { FieldPath, type DocumentData, type Firestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";

import { maximumRunTicketLifetimeMs } from "../runs/compatibility_retirement.js";
import { resolveSupportedGameCompatVersions } from "../runs/compatibility.js";
import { isTerminalRunSessionState, runSessionStates } from "../runs/session_state.js";
import { resolveBoardProvisioningConfig, type BoardProvisioningConfig } from "./provisioning.js";
import { resolveWindowForMode } from "./windowing.js";

const childCollections = ["ghost_manifests", "player_bests", "views"];
const activeStates = runSessionStates.filter((state) => !isTerminalRunSessionState(state));
const maintenancePath = "system_maintenance/board_retention";

export interface BoardRetentionResult {
  scannedCount: number;
  retiredCount: number;
  deletedCount: number;
  childDeleteCount: number;
  objectDeleteCount: number;
  protectedCount: number;
  candidates: string[];
  completedPage: boolean;
  nextCursor: string | null;
}

/** Current-only pre-release policy. Retired parents fence projection writes and
 * remain discoverable until every bounded child/object page has been removed. */
export async function pruneObsoleteLeaderboardBoards(args: {
  db: Firestore;
  config?: BoardProvisioningConfig;
  supportedVersions?: ReadonlySet<string>;
  nowMs?: number;
  apply?: boolean;
  /** Only for an explicitly authorized pre-release purge after active-run checks. */
  immediate?: boolean;
  maxBoards?: number;
  afterBoardId?: string;
  deleteGhostPage?: (boardId: string) => Promise<number>;
}): Promise<BoardRetentionResult> {
  const nowMs = args.nowMs ?? Date.now();
  const config = args.config ?? resolveBoardProvisioningConfig();
  const supported = args.supportedVersions ?? resolveSupportedGameCompatVersions();
  const maxBoards = args.maxBoards ?? 10;
  if (!Number.isSafeInteger(maxBoards) || maxBoards < 1 || maxBoards > 100) {
    throw new Error("maxBoards must be an integer between 1 and 100.");
  }
  // A cutover pause or a draining compatibility set is not authorization to
  // retire its boards. Retry maintenance after the normal single-version fence.
  if (supported.size !== 1 || !supported.has(config.gameCompatVersion)) {
    throw new Error("Board retention requires one supported serving gameplay version.");
  }
  const stateRef = args.db.doc(maintenancePath);
  const state = await stateRef.get();
  const cursor = args.afterBoardId ?? (args.apply ? state.get("cursor") : null);
  let query = args.db.collection("leaderboard_boards").orderBy(FieldPath.documentId()).limit(maxBoards + 1);
  if (typeof cursor === "string") query = query.startAfter(cursor);
  const page = await query.get();
  const selected = page.docs.slice(0, maxBoards);
  const result: BoardRetentionResult = {
    scannedCount: selected.length, retiredCount: 0, deletedCount: 0,
    childDeleteCount: 0, objectDeleteCount: 0, protectedCount: 0,
    candidates: [], completedPage: page.size <= maxBoards,
    nextCursor: page.size <= maxBoards ? null : selected.at(-1)!.id,
  };
  // Single-field query avoids an index rollout. Saturation protects every
  // board rather than interpreting a truncated active-run inventory as empty.
  const activeRuns = await args.db.collection("run_sessions")
    .where("state", "in", activeStates).select("boardId", "runTicket.boardId").limit(1001).get();
  if (activeRuns.size > 1000) throw new Error("Active run inventory is saturated; board retention deferred.");
  const activeBoardIds = new Set(activeRuns.docs.flatMap((doc) =>
    [doc.get("boardId"), doc.get("runTicket.boardId")].filter((id): id is string => typeof id === "string")));
  for (const board of selected) {
    const data = board.data();
    if (keepBoard(data, config, nowMs) || activeBoardIds.has(board.id)) {
      result.protectedCount += 1;
      continue;
    }
    // Unknown authored fixtures must be explicitly repaired, never swept.
    if (!isManagedBoard(data)) {
      result.protectedCount += 1;
      continue;
    }
    result.candidates.push(board.id);
    if (!args.apply) continue;
    const retirementAtMs = await args.db.runTransaction(async (tx) => {
      const latest = await tx.get(board.ref);
      if (!latest.exists || keepBoard(latest.data()!, config, args.nowMs ?? Date.now())) return null;
      const retiredAt = latest.get("retiredAtMs");
      if (typeof retiredAt === "number" && Number.isSafeInteger(retiredAt)) return retiredAt;
      tx.update(board.ref, { status: "disabled", retiredAtMs: nowMs });
      result.retiredCount += 1;
      return nowMs;
    });
    if (retirementAtMs == null || (!args.immediate && nowMs - retirementAtMs < maximumRunTicketLifetimeMs)) continue;
    // The grace interval lets issued tickets/old worker attempts drain. Active
    // runs remain protected even after the interval. Canonical runs and rewards
    // are retained; only disposable board projections and ghost copies expire.
    const removedChildren = await args.db.runTransaction(async (tx) => {
      const latest = await tx.get(board.ref);
      if (!latest.exists || latest.get("status") !== "disabled" ||
          latest.get("retiredAtMs") !== retirementAtMs ||
          keepBoard(latest.data()!, config, args.nowMs ?? Date.now())) return null;
      for (const collection of childCollections) {
        const children = await tx.get(board.ref.collection(collection).limit(100));
        if (children.empty) continue;
        for (const child of children.docs) tx.delete(child.ref);
        return children.size;
      }
      return 0;
    });
    if (removedChildren === null) continue;
    result.childDeleteCount += removedChildren;
    if (removedChildren > 0) continue;
    const deletedObjects = await (args.deleteGhostPage ?? deleteGhostPage)(board.id);
    result.objectDeleteCount += deletedObjects;
    if (deletedObjects > 0) continue;
    const collections = await board.ref.listCollections();
    if (collections.some((collection) => !childCollections.includes(collection.id))) {
      throw new Error(`Unknown child collection on retired board ${board.id}.`);
    }
    const deleted = await args.db.runTransaction(async (tx) => {
      const latest = await tx.get(board.ref);
      if (!latest.exists || latest.get("status") !== "disabled" ||
          latest.get("retiredAtMs") !== retirementAtMs ||
          keepBoard(latest.data()!, config, args.nowMs ?? Date.now())) return false;
      tx.delete(board.ref);
      return true;
    });
    if (deleted) result.deletedCount += 1;
  }
  if (args.apply) {
    await args.db.runTransaction(async (tx) => {
      const latest = await tx.get(stateRef);
      if (latest.exists !== state.exists ||
          (latest.exists && !latest.updateTime!.isEqual(state.updateTime!))) return;
      tx.set(stateRef, {
        cursor: result.nextCursor,
        updatedAtMs: nowMs,
      });
    });
  }
  return result;
}

function isManagedBoard(data: DocumentData): boolean {
  return (data.mode === "competitive" || data.mode === "weekly") &&
    typeof data.levelId === "string" && typeof data.gameCompatVersion === "string" &&
    typeof data.windowId === "string" && typeof data.closesAtMs === "number";
}

function keepBoard(data: DocumentData, config: BoardProvisioningConfig, nowMs: number): boolean {
  if (!isManagedBoard(data)) return false;
  const levels = data.mode === "competitive" ? config.competitiveLevelIds : [config.weeklyLevelId];
  return levels.includes(data.levelId) && data.gameCompatVersion === config.gameCompatVersion &&
    data.boardKey?.rulesetVersion === config.rulesetVersion && data.boardKey?.scoreVersion === config.scoreVersion &&
    data.ghostVersion === config.ghostVersion && data.windowId === resolveWindowForMode(data.mode, nowMs).windowId;
}

async function deleteGhostPage(boardId: string): Promise<number> {
  const bucket = getStorage().bucket(process.env.REPLAY_STORAGE_BUCKET);
  const [files] = await bucket.getFiles({ prefix: `ghosts/${boardId}/`, maxResults: 100, autoPaginate: false });
  for (const file of files) {
    await file.delete({ ignoreNotFound: true, ifGenerationMatch: file.metadata.generation });
  }
  return files.length;
}
