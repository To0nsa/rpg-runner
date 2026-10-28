import type { SystemMessage } from "./contracts.js";

/** Claimed gifts and read information remain available for 30 days, in milliseconds. */
export const inboxRetentionMs = 30 * 24 * 60 * 60 * 1000;

/** Unclaimed attachments never expire, even after reading; repeated reads cannot extend retention. */
export function inboxMessageExpiry(message: SystemMessage): number | null {
  const start = message.rewards.length > 0 ? message.claimedAtMs : message.readAtMs;
  if (start === null) return null;
  const deadline = start + inboxRetentionMs;
  if (!Number.isSafeInteger(deadline)) throw new Error("Invalid inbox expiry time.");
  return deadline;
}
