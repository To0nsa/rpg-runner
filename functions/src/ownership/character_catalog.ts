import { coreCatalog } from "./core_catalog.generated.js";

export { coreCharacterIds as knownCharacterIds } from "./core_catalog.generated.js";

const eligibility = new Map<string, readonly string[]>(coreCatalog.map((entry) => [
  `${entry.domain}:${entry.slot}:${entry.itemId}`, entry.characterIds,
]));

/** Equipment eligibility, independent of account-wide gear ownership.
 * Unknown characters, identities, domains and slots always fail closed. */
export function characterContentAllowed(characterId: string, domain: string, slot: string, itemId: string): boolean {
  return eligibility.get(`${domain}:${slot}:${itemId}`)?.includes(characterId) ?? false;
}
