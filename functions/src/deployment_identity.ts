/** Project-local runtime and private-invoker identities; never inherit dev IAM. */
export function readDeploymentIdentity(
  environment: Record<string, string | undefined> = process.env,
): {
  projectId: string;
  runControlServiceAccount: string;
  replayValidatorServiceAccount: string;
} {
  const projectId = environment.GCLOUD_PROJECT?.trim() ||
    environment.GOOGLE_CLOUD_PROJECT?.trim();
  if (!projectId || !/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(projectId)) {
    throw new Error("A valid deployment project is required in GCLOUD_PROJECT.");
  }
  if (environment.GOOGLE_CLOUD_PROJECT?.trim() &&
      environment.GOOGLE_CLOUD_PROJECT.trim() !== projectId) {
    throw new Error("Conflicting deployment project identities.");
  }
  const replayValidatorServiceAccount =
    `sa-replay-validator@${projectId}.iam.gserviceaccount.com`;
  const configuredValidator = environment.REPLAY_VALIDATOR_SERVICE_ACCOUNT?.trim();
  if (configuredValidator && configuredValidator !== replayValidatorServiceAccount) {
    throw new Error("Replay validator service account must belong to the deployment project.");
  }
  return {
    projectId,
    runControlServiceAccount: `sa-run-control@${projectId}.iam.gserviceaccount.com`,
    replayValidatorServiceAccount,
  };
}
