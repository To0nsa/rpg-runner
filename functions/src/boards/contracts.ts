import type { RunModeValue } from "../runs/mode.js";

export const boardStatuses = [
  "scheduled",
  "active",
  "closed",
  "disabled",
] as const;
export type BoardStatus = (typeof boardStatuses)[number];

export interface BoardKeyRecord {
  mode: Exclude<RunModeValue, "practice">;
  levelId: string;
  windowId: string;
  rulesetVersion: string;
  scoreVersion: string;
}

export interface BoardManifestRecord {
  boardId: string;
  mode: Exclude<RunModeValue, "practice">;
  levelId: string;
  windowId: string;
  boardKey: BoardKeyRecord;
  gameCompatVersion: string;
  ghostVersion: string;
  tickHz: number;
  seed: number;
  opensAtMs: number;
  closesAtMs: number;
  minClientBuild?: string;
  status: BoardStatus;
}

