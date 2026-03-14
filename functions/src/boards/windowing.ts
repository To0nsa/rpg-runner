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
  const windowId = weeklyWindowId(isoYear, isoWeek);
  return {
    windowId,
    opensAtMs,
    closesAtMs,
  };
}

export function weeklyWindowBoundsFromId(windowId: string): ResolvedWindow {
  const match = /^(\d{4})-W(\d{2})$/.exec(windowId);
  if (!match) {
    throw new HttpsError(
      "failed-precondition",
      `Weekly windowId must be YYYY-Www, got "${windowId}".`,
    );
  }

  const isoYear = Number(match[1]);
  const isoWeek = Number(match[2]);
  if (
    !Number.isInteger(isoYear) ||
    !Number.isInteger(isoWeek) ||
    isoWeek < 1 ||
    isoWeek > 53
  ) {
    throw new HttpsError(
      "failed-precondition",
      `Weekly windowId must be YYYY-Www, got "${windowId}".`,
    );
  }

  const opensAtMs = isoWeekStartMs(isoYear, isoWeek);
  const normalized = resolveWeeklyWindow(opensAtMs);
  if (normalized.windowId !== windowId) {
    throw new HttpsError(
      "failed-precondition",
      `Weekly windowId must be a valid ISO week, got "${windowId}".`,
    );
  }
  return {
    windowId,
    opensAtMs,
    closesAtMs: opensAtMs + 7 * utcDayMs,
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

function weeklyWindowId(isoYear: number, isoWeek: number): string {
  return `${isoYear}-W${String(isoWeek).padStart(2, "0")}`;
}

function isoWeekStartMs(isoYear: number, isoWeek: number): number {
  const jan4Ms = Date.UTC(isoYear, 0, 4, 0, 0, 0, 0);
  const jan4IsoDay = isoDayOfWeek(jan4Ms);
  const week1StartMs = jan4Ms - (jan4IsoDay - 1) * utcDayMs;
  return week1StartMs + (isoWeek - 1) * 7 * utcDayMs;
}
