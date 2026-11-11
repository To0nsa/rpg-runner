import { coreCatalog } from "./core_catalog.generated.js";

export const playerEquippableProjectileIds: readonly string[] = coreCatalog
  .filter((entry) => entry.domain === "projectileSpell")
  .map((entry) => entry.itemId);

export function isPlayerEquippableProjectileId(id: string): boolean {
  return playerEquippableProjectileIds.includes(id);
}
