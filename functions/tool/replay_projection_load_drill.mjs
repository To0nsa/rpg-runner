#!/usr/bin/env node

import { randomBytes } from "node:crypto";
import {
  FirestoreRest,
  assert,
  firestoreWrite,
  invokePrivateService,
  optionalArg,
  parseArgs,
  parsePositiveInteger,
  readGcloudIdentityToken,
  readState,
  requireArg,
  shortHash,
  writeState,
} from "./replay_drill_support.mjs";

const args = parseArgs(process.argv.slice(2));
const command = requireArg(args, "command");
const projectId = requireArg(args, "project");
const statePath = optionalArg(
  args,
  "state-file",
  ".tmp/replay-projection-load-drill-state.json",
);
const firestore = new FirestoreRest({ projectId });

switch (command) {
  case "prepare":
    await prepare();
    break;
  case "exercise":
    await exercise();
    break;
  case "inspect":
    await inspect();
    break;
  case "cleanup":
    await cleanup();
    break;
  case "verify-clean":
    await verifyClean();
    break;
  default:
    throw new Error(`Unsupported --command "${command}".`);
}

async function prepare() {
  const playerCount = parsePositiveInteger(args.get("players"), 250);
  const hotPlayerResults = parsePositiveInteger(
    args.get("hot-player-results"),
    24,
  );
  assert(playerCount > 100, "Board load must cross the 100-document boundary.");
  assert(
    hotPlayerResults >= 10,
    "Same-player load requires at least ten competing results.",
  );
  const drillId = `rvboard-${Date.now()}-${randomBytes(4).toString("hex")}`;
  const boardId = `${drillId}-board`;
  const boardKey = {
    mode: "competitive",
    levelId: "field",
    windowId: drillId,
    rulesetVersion: "rules-v2",
    scoreVersion: "score-v1",
  };
  const nowMs = Date.now();
  const players = Array.from({ length: playerCount }, (_, index) => ({
    uid: `${drillId}-player-${String(index).padStart(4, "0")}`,
    uidHash: shortHash(
      `${drillId}-player-${String(index).padStart(4, "0")}`,
    ),
  }));
  const runs = [];
  for (let playerIndex = 0; playerIndex < players.length; playerIndex += 1) {
    const player = players[playerIndex];
    const resultCount = playerIndex === 0 ? hotPlayerResults : 1;
    for (let resultIndex = 0; resultIndex < resultCount; resultIndex += 1) {
      const runSessionId =
        `${drillId}-run-${String(playerIndex).padStart(4, "0")}-` +
        `${String(resultIndex).padStart(3, "0")}`;
      const score =
        playerIndex === 0
          ? 5000 + resultIndex * 137
          : 1000 + ((playerIndex * 7919) % 8000);
      const distanceMeters = 100 + ((playerIndex * 193 + resultIndex) % 900);
      const durationSeconds = 30 + ((playerIndex + resultIndex * 7) % 300);
      runs.push({
        runSessionId,
        runSessionHash: shortHash(runSessionId),
        uid: player.uid,
        score,
        distanceMeters,
        durationSeconds,
        sortKey: buildSortKey({
          score,
          distanceMeters,
          durationSeconds,
          entryId: runSessionId,
        }),
      });
    }
  }
  const writes = [
    firestoreWrite(
      `leaderboard_boards/${boardId}`,
      {
        boardId,
        drillId,
        status: "drill_only",
        createdAtMs: nowMs,
      },
      projectId,
      { exists: false },
    ),
    ...runs.map((run) =>
      firestoreWrite(
        `validated_runs/${run.runSessionId}`,
        {
          runSessionId: run.runSessionId,
          uid: run.uid,
          boardId,
          boardKey,
          mode: "competitive",
          accepted: true,
          score: run.score,
          distanceMeters: run.distanceMeters,
          durationSeconds: run.durationSeconds,
          tick: run.durationSeconds * 60,
          endedReason: "completed",
          goldEarned: 0,
          stats: { projectionLoadFixture: true },
          replayDigest: "c".repeat(64),
          replayStorageRef:
            `drill-unpublished/${drillId}/${run.runSessionId}.bin.gz`,
          createdAtMs: nowMs,
        },
        projectId,
        { exists: false },
      ),
    ),
  ];
  for (let offset = 0; offset < writes.length; offset += 400) {
    await firestore.commit(writes.slice(offset, offset + 400));
  }
  const expectedBestByUid = bestRunsByUid(runs);
  const expectedTop10 = [...expectedBestByUid.values()]
    .sort((left, right) => left.sortKey.localeCompare(right.sortKey))
    .slice(0, 10);
  const state = {
    schemaVersion: 1,
    projectId,
    drillId,
    drillIdHash: shortHash(drillId),
    boardId,
    boardIdHash: shortHash(boardId),
    createdAt: new Date().toISOString(),
    playerCount,
    hotPlayerResults,
    players,
    runs,
    hotUid: players[0].uid,
    hotUidHash: players[0].uidHash,
    expectedHotBestRunSessionId: expectedBestByUid.get(players[0].uid)
      .runSessionId,
    expectedTop10RunSessionIds: expectedTop10.map(
      (run) => run.runSessionId,
    ),
    phase: "prepared",
  };
  await writeState(statePath, state);
  console.log(
    JSON.stringify(
      {
        command,
        drillIdHash: state.drillIdHash,
        boardIdHash: state.boardIdHash,
        playerCount,
        runCount: runs.length,
        hotPlayerResults,
        firestorePagesCrossed: Math.ceil(playerCount / 100),
        stateFile: statePath,
      },
      null,
      2,
    ),
  );
}

async function exercise() {
  const targetUrl = requireArg(args, "target-url");
  const concurrency = parsePositiveInteger(args.get("concurrency"), 25);
  const state = await readState(statePath);
  assert(state.phase === "prepared", `Unexpected state phase ${state.phase}.`);
  const identityToken = readGcloudIdentityToken();
  const hotRuns = state.runs.filter((run) => run.uid === state.hotUid);
  const work = deterministicShuffle([
    ...state.runs,
    ...hotRuns,
    ...hotRuns,
  ]);
  let retryResponses = 0;
  let completed = 0;
  await runPool(work, concurrency, async (run) => {
    for (let attempt = 1; attempt <= 12; attempt += 1) {
      const response = await invokePrivateService({
        baseUrl: targetUrl,
        path: "/tasks/project",
        data: { runSessionId: run.runSessionId },
        identityToken,
      });
      if (response.status === 200) {
        completed += 1;
        return;
      }
      assert(
        response.status === 503,
        `Projection ${run.runSessionHash} returned ${response.status}.`,
      );
      retryResponses += 1;
      await new Promise((resolve) => setTimeout(resolve, attempt * 100));
    }
    throw new Error(`Projection ${run.runSessionHash} did not converge.`);
  });

  const reconcileResponses = await Promise.all(
    Array.from({ length: 8 }, async () => {
      for (let attempt = 1; attempt <= 12; attempt += 1) {
        const response = await invokePrivateService({
          baseUrl: targetUrl,
          path: "/tasks/project",
          data: { boardId: state.boardId },
          identityToken,
        });
        if (response.status === 200) return response.status;
        assert(
          response.status === 503,
          `Board reconciliation returned ${response.status}.`,
        );
        retryResponses += 1;
        await new Promise((resolve) => setTimeout(resolve, attempt * 100));
      }
      throw new Error("Board reconciliation did not converge.");
    }),
  );

  const worstHot = [...hotRuns].sort((left, right) =>
    right.sortKey.localeCompare(left.sortKey),
  )[0];
  const staleResponse = await invokePrivateService({
    baseUrl: targetUrl,
    path: "/tasks/project",
    data: { runSessionId: worstHot.runSessionId },
    identityToken,
  });
  assert(
    staleResponse.status === 200,
    `Stale hot-player delivery returned ${staleResponse.status}.`,
  );
  const finalReconcile = await invokePrivateService({
    baseUrl: targetUrl,
    path: "/tasks/project",
    data: { boardId: state.boardId },
    identityToken,
  });
  assert(
    finalReconcile.status === 200,
    `Final reconciliation returned ${finalReconcile.status}.`,
  );

  const verification = await verifyProjectionState(state);
  state.phase = "verified";
  state.verifiedAt = new Date().toISOString();
  state.results = {
    requestedDeliveries: work.length,
    completedDeliveries: completed,
    retryResponses,
    reconcileResponses,
    staleDeliveryPreservedBest: true,
    ...verification,
  };
  await writeState(statePath, state);
  console.log(
    JSON.stringify(
      {
        command,
        boardIdHash: state.boardIdHash,
        ...state.results,
      },
      null,
      2,
    ),
  );
}

async function verifyProjectionState(state) {
  const [playerBests, views, ghostManifests] = await Promise.all([
    firestore.queryCollection("player_bests"),
    firestore.queryCollection("views"),
    firestore.queryCollection("ghost_manifests"),
  ]);
  const boardBests = playerBests.filter(
    (document) => document.data.boardId === state.boardId,
  );
  assert(
    boardBests.length === state.playerCount,
    `Expected ${state.playerCount} player bests, found ${boardBests.length}.`,
  );
  const hotBest = boardBests.find(
    (document) => document.data.uid === state.hotUid,
  );
  assert(hotBest, "Hot-player best is missing.");
  assert(
    hotBest.data.runSessionId === state.expectedHotBestRunSessionId,
    "Hot-player best regressed under out-of-order delivery.",
  );
  const view = views.find(
    (document) =>
      document.data.boardId === state.boardId && document.id === "top10",
  );
  assert(view, "Top-10 materialized view is missing.");
  const actualTop10 = (view.data.entries ?? []).map(
    (entry) => entry.runSessionId,
  );
  assert(
    JSON.stringify(actualTop10) ===
      JSON.stringify(state.expectedTop10RunSessionIds),
    "Top-10 materialized view does not match canonical player-best truth.",
  );
  const boardGhosts = ghostManifests.filter(
    (document) => document.data.boardId === state.boardId,
  );
  assert(
    boardGhosts.length === 0,
    "Generation-less load fixtures unexpectedly published ghosts.",
  );
  return {
    playerBestCount: boardBests.length,
    top10Count: actualTop10.length,
    top10Exact: true,
    hotPlayerBestMonotonic: true,
    ghostManifestCount: 0,
  };
}

async function inspect() {
  const state = await readState(statePath);
  let verification = null;
  try {
    verification = await verifyProjectionState(state);
  } catch (error) {
    verification = { converged: false, message: safeError(error) };
  }
  console.log(
    JSON.stringify(
      {
        command,
        boardIdHash: state.boardIdHash,
        phase: state.phase,
        verification,
      },
      null,
      2,
    ),
  );
}

async function cleanup() {
  const state = await readState(statePath);
  const deletePaths = [
    ...state.runs.map((run) => `validated_runs/${run.runSessionId}`),
    ...state.players.map(
      (player) =>
        `leaderboard_boards/${state.boardId}/player_bests/${player.uid}`,
    ),
    `leaderboard_boards/${state.boardId}/views/top10`,
  ];
  const manifests = (await firestore.queryCollection("ghost_manifests"))
    .filter((document) => document.data.boardId === state.boardId)
    .map(
      (document) =>
        `leaderboard_boards/${state.boardId}/ghost_manifests/${document.id}`,
    );
  deletePaths.push(...manifests);
  for (let offset = 0; offset < deletePaths.length; offset += 400) {
    await firestore.commit(
      deletePaths.slice(offset, offset + 400).map((path) => ({
        delete:
          `projects/${projectId}/databases/(default)/documents/${path}`,
      })),
    );
  }
  await firestore.delete(`leaderboard_boards/${state.boardId}`);
  state.phase = "cleanup_requested";
  state.cleanupAt = new Date().toISOString();
  await writeState(statePath, state);
  console.log(
    JSON.stringify(
      {
        command,
        boardIdHash: state.boardIdHash,
        deletedDocumentCount: deletePaths.length + 1,
      },
      null,
      2,
    ),
  );
}

async function verifyClean() {
  const state = await readState(statePath);
  const [validatedRuns, playerBests, views, ghostManifests] =
    await Promise.all([
      firestore.queryCollection("validated_runs"),
      firestore.queryCollection("player_bests"),
      firestore.queryCollection("views"),
      firestore.queryCollection("ghost_manifests"),
    ]);
  const runIds = new Set(state.runs.map((run) => run.runSessionId));
  const residualCount =
    validatedRuns.filter((document) => runIds.has(document.id)).length +
    playerBests.filter((document) => document.data.boardId === state.boardId)
      .length +
    views.filter((document) => document.data.boardId === state.boardId).length +
    ghostManifests.filter(
      (document) => document.data.boardId === state.boardId,
    ).length +
    ((await firestore.get(`leaderboard_boards/${state.boardId}`, {
      missingOk: true,
    }))
      ? 1
      : 0);
  assert(residualCount === 0, `Board drill has ${residualCount} residual docs.`);
  state.phase = "cleanup_verified";
  state.cleanupVerifiedAt = new Date().toISOString();
  await writeState(statePath, state);
  console.log(
    JSON.stringify(
      {
        command,
        boardIdHash: state.boardIdHash,
        residualCount: 0,
        verifiedAt: state.cleanupVerifiedAt,
      },
      null,
      2,
    ),
  );
}

function bestRunsByUid(runs) {
  const out = new Map();
  for (const run of runs) {
    const current = out.get(run.uid);
    if (!current || run.sortKey.localeCompare(current.sortKey) < 0) {
      out.set(run.uid, run);
    }
  }
  return out;
}

function buildSortKey({ score, distanceMeters, durationSeconds, entryId }) {
  const maximum = 9999999999;
  const clamp = (value) => Math.max(0, Math.min(maximum, value));
  const pad = (value) => String(value).padStart(10, "0");
  return (
    `${pad(maximum - clamp(score))}:` +
    `${pad(maximum - clamp(distanceMeters))}:` +
    `${pad(clamp(durationSeconds))}:${entryId}`
  );
}

function deterministicShuffle(values) {
  const out = [...values];
  let state = 0x6d2b79f5;
  const random = () => {
    state |= 0;
    state = (state + 0x6d2b79f5) | 0;
    let value = Math.imul(state ^ (state >>> 15), 1 | state);
    value = (value + Math.imul(value ^ (value >>> 7), 61 | value)) ^ value;
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  };
  for (let index = out.length - 1; index > 0; index -= 1) {
    const selected = Math.floor(random() * (index + 1));
    [out[index], out[selected]] = [out[selected], out[index]];
  }
  return out;
}

async function runPool(values, concurrency, operation) {
  let index = 0;
  const workers = Array.from(
    { length: Math.min(concurrency, values.length) },
    async () => {
      while (true) {
        const currentIndex = index;
        index += 1;
        if (currentIndex >= values.length) return;
        await operation(values[currentIndex]);
      }
    },
  );
  await Promise.all(workers);
}

function safeError(error) {
  return (error instanceof Error ? error.message : String(error)).slice(0, 700);
}
