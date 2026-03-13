import { HttpsError } from "firebase-functions/v2/https";

import type { RunModeValue } from "../runs/mode.js";

const utcDayMs = 24 * 60 * 60 * 1000;

export interface ResolvedWindow {
  windowId: string;
  opensAtMs: number;
  closesAtMs: number;
}

export function resolveWindowForMode(
  mode: RunModeValue,
  nowMs: number,
): ResolvedWindow {
  switch (mode) {
    case "practice":
      throw new HttpsError(
        "invalid-argument",
        "Practice mode does not use board windows.",
      );
    case "competitive":
      return resolveCompetitiveWindow(nowMs);
    case "weekly":
      return resolveWeeklyWindow(nowMs);
  }
}

export function resolveCompetitiveWindow(nowMs: number): ResolvedWindow {
  const current = new Date(nowMs);
  const year = current.getUTCFullYear();
  const monthIndex = current.getUTCMonth();
  const windowId = `${year}-${String(monthIndex + 1).padStart(2, "0")}`;
  const opensAtMs = Date.UTC(year, monthIndex, 1, 0, 0, 0, 0);
  const closesAtMs = Date.UTC(year, monthIndex + 1, 1, 0, 0, 0, 0);
  return {
    windowId,
    opensAtMs,
    closesAtMs,
  };
}

export function competitiveWindowBoundsFromId(windowId: string): ResolvedWindow {
  const match = /^(\d{4})-(\d{2})$/.exec(windowId);
  if (!match) {
    throw new HttpsError(
      "failed-precondition",
      `Competitive windowId must be YYYY-MM, got "${windowId}".`,
    );
  }
  const year = Number(match[1]);
  const month = Number(match[2]);
  if (!Number.isInteger(year) || !Number.isInteger(month) || month < 1 || month > 12) {
    throw new HttpsError(
      "failed-precondition",
      `Competitive windowId must be YYYY-MM, got "${windowId}".`,
    );
  }
  const opensAtMs = Date.UTC(year, month - 1, 1, 0, 0, 0, 0);
  const closesAtMs = Date.UTC(year, month, 1, 0, 0, 0, 0);
  return {
    windowId,
    opensAtMs,
    closesAtMs,
  };
}

export function resolveWeeklyWindow(nowMs: number): ResolvedWindow {
  const currentUtcDay = utcStartOfDay(nowMs);
  const isoDay = isoDayOfWeek(currentUtcDay);
  const opensAtMs = currentUtcDay - (isoDay - 1) * utcDayMs;
  const closesAtMs = opensAtMs + 7 * utcDayMs;
  const { isoYear, isoWeek } = isoWeekComponents(nowMs);
  const windowId = `${isoYear}-W${String(isoWeek).padStart(2, "0")}`;
  return {
    windowId,
    opensAtMs,
    closesAtMs,
  };
}

function utcStartOfDay(nowMs: number): number {
  const date = new Date(nowMs);
  return Date.UTC(
    date.getUTCFullYear(),
    date.getUTCMonth(),
    date.getUTCDate(),
    0,
    0,
    0,
    0,
  );
}

function isoDayOfWeek(dayStartMs: number): number {
  const day = new Date(dayStartMs).getUTCDay();
  return day === 0 ? 7 : day;
}

function isoWeekComponents(nowMs: number): { isoYear: number; isoWeek: number } {
  const date = new Date(nowMs);
  const utcDate = new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()),
  );
  const day = utcDate.getUTCDay() || 7;
  utcDate.setUTCDate(utcDate.getUTCDate() + 4 - day);

  const isoYear = utcDate.getUTCFullYear();
  const yearStart = new Date(Date.UTC(isoYear, 0, 1));
  const daysSinceYearStart = Math.floor(
    (utcDate.getTime() - yearStart.getTime()) / utcDayMs,
  );
  const isoWeek = Math.floor(daysSinceYearStart / 7) + 1;
  return { isoYear, isoWeek };
}

