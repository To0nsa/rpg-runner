/** Immutable reward contents are snapshotted at delivery, not at claim time. */
export interface InboxGoldReward {
  kind: "gold";
  amount: number;
}

export interface InboxCatalogReward {
  kind: "gear" | "ability" | "projectileSpell";
  itemId: string;
  slot: string;
  /** Skills target this character permanently, independent of the selected loadout. */
  characterId?: string;
}

export type InboxReward = InboxGoldReward | InboxCatalogReward;

/** System mail is separate from future player conversations and run grants. */
export interface SystemMessage {
  schemaVersion: 1 | 2;
  id: string;
  uid: string;
  sourceId: string;
  title: string;
  body: string;
  createdAtMs: number;
  readAtMs: number | null;
  claimedAtMs: number | null;
  rewards: InboxReward[];
}

/** Whole-inbox counts and revision, updated with every visible mutation. */
export interface InboxSummary {
  revision: number;
  unreadCount: number;
  unclaimedCount: number;
}

export interface InboxCursor {
  createdAtMs: number;
  messageId: string;
}

export const inboxCollections = {
  messages: "system_messages",
  rewards: "inbox_rewards",
  summaries: "inbox_summaries",
  receipts: "inbox_receipts",
} as const;
