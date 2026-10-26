import assert from "node:assert/strict";
import test from "node:test";

import { readDeploymentIdentity } from "../src/deployment_identity.js";

for (const projectId of [
  "rpg-runner-d7add", "lothringen-long-run-staging", "lothringen-long-run-prod",
]) {
  test(`deployment identities remain inside ${projectId}`, () => {
    const identity = readDeploymentIdentity({ GCLOUD_PROJECT: projectId });
    assert.equal(identity.projectId, projectId);
    assert.equal(identity.runControlServiceAccount,
      `sa-run-control@${projectId}.iam.gserviceaccount.com`);
    assert.equal(identity.replayValidatorServiceAccount,
      `sa-replay-validator@${projectId}.iam.gserviceaccount.com`);
  });
}

test("deployment refuses missing or contradictory project configuration", () => {
  assert.throws(() => readDeploymentIdentity({}), /deployment project/);
  assert.throws(() => readDeploymentIdentity({
    GCLOUD_PROJECT: "lothringen-long-run-prod",
    GOOGLE_CLOUD_PROJECT: "rpg-runner-d7add",
  }), /Conflicting/);
  assert.throws(() => readDeploymentIdentity({
    GCLOUD_PROJECT: "lothringen-long-run-prod",
    REPLAY_VALIDATOR_SERVICE_ACCOUNT:
      "sa-replay-validator@rpg-runner-d7add.iam.gserviceaccount.com",
  }), /deployment project/);
});

test("alternate SDK project variable and matching explicit invoker are supported", () => {
  assert.equal(readDeploymentIdentity({
    GOOGLE_CLOUD_PROJECT: "lothringen-long-run-staging",
    REPLAY_VALIDATOR_SERVICE_ACCOUNT:
      "sa-replay-validator@lothringen-long-run-staging.iam.gserviceaccount.com",
  }).projectId, "lothringen-long-run-staging");
});
