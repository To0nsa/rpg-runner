import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { test } from "node:test";

test("function discovery stays synchronous, private, scale-to-zero and independent of domain initialization", () => {
  const output = execFileSync(process.execPath, ["-e", `
    const functions = require(${JSON.stringify(require.resolve("../src/index.js"))});
    const modules = Object.keys(require.cache).map(p => p.replaceAll('\\\\', '/'));
    console.log(JSON.stringify({ endpoints: Object.fromEntries(Object.entries(functions)
      .map(([name, fn]) => [name, fn.__endpoint])), modules }));
  `], { encoding: "utf8", env: { ...process.env, GCLOUD_PROJECT: "demo-registration",
    GOOGLE_CLOUD_PROJECT: "demo-registration", RUN_SESSION_CREATE_MIN_INSTANCES: "0",
    LEADERBOARD_MIN_INSTANCES: "0" } });
  const result = JSON.parse(output);
  const endpoints = result.endpoints;
  assert.equal(endpoints.runSubmission.minInstances, 0);
  assert.equal(endpoints.runSessionCreate.minInstances, 0);
  assert.deepEqual(endpoints.runPendingWork.taskQueueTrigger.invoker,
    ["sa-run-control@demo-registration.iam.gserviceaccount.com"]);
  assert.equal(endpoints.runPendingWork.taskQueueTrigger.retryConfig.maxRetrySeconds, 86400);
  assert.equal(endpoints.runPendingWork.timeoutSeconds, 120);
  assert.equal(endpoints.accountDeletionOnRequest.eventTrigger.retry, true);
  assert.equal(endpoints.runSettlementOnHandoff.eventTrigger.retry, true);
  for (const name of ["accountDeletionRepair", "runValidationRepair", "runSettlementRepair"]) {
    assert.equal(endpoints[name].scheduleTrigger.schedule, "every 60 minutes");
  }
  for (const module of ["account/delete.js", "runs/reward_settlement.js", "ownership/defaults.js",
    "inbox/store.js", "runs/submission_store.js", "leaderboards/callable_handlers.js"]) {
    assert.equal(result.modules.some((path: string) => path.endsWith(`/src/${module}`)), false, module);
  }
});

test("registered events enqueue durable recovery and propagate enqueue failures", () => {
  execFileSync(process.execPath, ["-e", `
    const assert = require('node:assert/strict');
    const pending = require(${JSON.stringify(require.resolve("../src/pending_work.js"))});
    const calls = [];
    let enqueueFails = false;
    let workResult = 'pending';
    pending.enqueuePendingWork = async args => {
      if (enqueueFails) throw new Error('enqueue down');
      calls.push(args);
    };
    pending.processPendingWork = async () => workResult;
    const f = require(${JSON.stringify(require.resolve("../src/index.js"))});
    (async () => {
      const run = { params: {runSessionId: 'run_test'}, data: {
        before: {data: () => ({state:'uploading'})},
        after: {exists:true, data: () => ({state:'uploaded'})} } };
      await f.runSettlementOnHandoff.run(run);
      assert.equal(calls[0].delaySeconds, 900);
      assert.deepEqual(calls[0].work, {kind:'run', runSessionId:'run_test'});
      await f.accountDeletionOnRequest.run({params:{uid:'owner'},data:{exists:true,
        get: name => name === 'state' ? 'requested' : 1234}});
      assert.deepEqual(calls[1].work, {kind:'account', uid:'owner'});
      enqueueFails = true;
      await assert.rejects(f.runSettlementOnHandoff.run(run), /enqueue down/);
      await assert.rejects(f.runPendingWork.run({data:{kind:'run',runSessionId:'run_test'}}),
        error => error.code === 'unavailable');
      workResult = 'complete';
      await f.runPendingWork.run({data:{kind:'run',runSessionId:'run_test'}});
    })().catch(error => { console.error(error); process.exitCode=1; });
  `], { env: { ...process.env, GCLOUD_PROJECT: "demo-registration", GOOGLE_CLOUD_PROJECT: "demo-registration" } });
});
