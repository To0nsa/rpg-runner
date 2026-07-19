/**
 * Controls the temporary production compatibility path for pre-settlement grants.
 *
 * It deliberately defaults to enabled so deploying migration code cannot strand
 * a legacy `validated_settled` grant before the inventory/apply cutover. The
 * rollout sets it to `false` only after the finite migration has completed.
 */
export function legacyReadReconciliationEnabled(
  env: NodeJS.ProcessEnv = process.env,
): boolean {
  return env.LEGACY_READ_RECONCILIATION_ENABLED?.trim().toLowerCase() !== "false";
}
