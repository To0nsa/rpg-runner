import type { MessageLocalization, MessageText } from "./localization.js";

/** Authored mail snapshots are immutable after issue. Add languages here for future deliveries. */
export function levelReachedText(level: number): MessageText & { localization: MessageLocalization } {
  return {
    title: `Level ${level} reached`,
    body: `You have reached level ${level}. Your gold reward is ready to claim.`,
    localization: { schemaVersion: 1, translations: {
      fr: { title: `Niveau ${level} atteint`, body: `Tu as atteint le niveau ${level}. Tu peux récupérer ta récompense en or.` },
    } },
  };
}
