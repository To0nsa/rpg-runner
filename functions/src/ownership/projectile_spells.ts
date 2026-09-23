/** Player items only. Kept in parity with Core's explicit item allowlist. */
export const playerEquippableProjectileIds = [
  "iceBolt", "fireBolt", "acidBolt", "darkBolt", "earthBolt", "holyBolt",
  "waterBolt", "thunderBolt",
] as const;

export function isPlayerEquippableProjectileId(id: string): boolean {
  return (playerEquippableProjectileIds as readonly string[]).includes(id);
}
