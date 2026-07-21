#!/usr/bin/env node

import { randomBytes } from "node:crypto";
import { gzipSync } from "node:zlib";
import {
  FirestoreRest,
  StorageRest,
  assert,
  callFunction,
  canonicalSha256,
  createAnonymousAccount,
  delay,
  invokePrivateService,
  isObject,
  optionalArg,
  parseArgs,
  parsePositiveInteger,
  readFirebaseWebApiKey,
  readGcloudIdentityToken,
  readState,
  refreshAnonymousAccount,
  requireArg,
  shortHash,
  writeState,
} from "./replay_drill_support.mjs";

const args = parseArgs(process.argv.slice(2));
const command = requireArg(args, "command");
const projectId = requireArg(args, "project");
const region = optionalArg(args, "region", "europe-west1");
const bucket = requireArg(args, "bucket");
const statePath = optionalArg(
  args,
  "state-file",
  ".tmp/replay-validator-release-drill-state.json",
);
const firestore = new FirestoreRest({ projectId });
const storage = new StorageRest({ bucket });

switch (command) {
  case "prepare":
    await prepare();
    break;
  case "exercise-compatibility":
    await exerciseGroup("compatibility");
    break;
  case "exercise-resources":
    await exerciseGroup("resources");
    break;
  case "exercise-simulation":
    await exerciseGroup("simulation");
    break;
  case "grace-start":
    await graceStart();
    break;
  case "grace-finish":
    await graceFinish();
    break;
  case "inspect":
    await inspect();
    break;
  case "reset-fixtures":
    await resetFixtures();
    break;
  case "request-cleanup":
    await requestCleanup();
    break;
  case "verify-clean":
    await verifyClean();
    break;
  default:
    throw new Error(`Unsupported --command "${command}".`);
}

async function prepare() {
  let existing = null;
  try {
    existing = await readState(statePath);
  } catch {
    // A missing state file is expected.
  }
  if (existing && existing.cleanupVerifiedAt === undefined) {
    throw new Error(
      `State file ${statePath} already describes an unfinished drill.`,
    );
  }

  const apiKey = await readFirebaseWebApiKey();
  const auth = await createAnonymousAccount(apiKey);
  const sessionId = `rv-release-drill-${randomBytes(8).toString("hex")}`;
  const drillId = `rvdrill-${Date.now()}-${randomBytes(4).toString("hex")}`;
  let state = {
    schemaVersion: 1,
    projectId,
    region,
    bucket,
    drillId,
    uid: auth.localId,
    uidHash: shortHash(auth.localId),
    refreshToken: auth.refreshToken,
    sessionId,
    createdAt: new Date().toISOString(),
    phase: "account_created",
    fixtures: [],
    templateRunSessionIds: [],
  };
  await writeState(statePath, state);

  try {
    await callFunction({
      projectId,
      region,
      idToken: auth.idToken,
      functionName: "playerProfileLoad",
      data: { userId: auth.localId, sessionId },
    });
    const canonicalLoad = await callFunction({
      projectId,
      region,
      idToken: auth.idToken,
      functionName: "loadoutOwnershipLoadCanonicalState",
      data: { userId: auth.localId, sessionId },
    });
    assert(
      isObject(canonicalLoad.canonicalState),
      "Canonical ownership response was malformed.",
    );
    let canonical = canonicalLoad.canonicalState;

    const practiceTemplate = await createTicket({
      auth,
      sessionId,
      mode: "practice",
      suffix: "practice-template",
    });

    const selection = structuredClone(canonical.selection);
    selection.runMode = "competitive";
    selection.runType = "competitive";
    const selectionResult = await callFunction({
      projectId,
      region,
      idToken: auth.idToken,
      functionName: "loadoutOwnershipExecuteCommand",
      data: {
        command: {
          type: "setSelection",
          userId: auth.localId,
          sessionId,
          expectedRevision: canonical.revision,
          commandId: `${drillId}.selection`,
          payload: { selection },
        },
      },
    });
    assert(
      selectionResult.result?.rejectedReason === null,
      "Competitive selection was rejected.",
    );
    canonical = selectionResult.result.canonicalState;
    assert(isObject(canonical), "Competitive canonical state was malformed.");

    const competitiveTemplate = await createTicket({
      auth,
      sessionId,
      mode: "competitive",
      suffix: "competitive-template",
    });
    state = {
      ...state,
      phase: "templates_created",
      templateRunSessionIds: [
        practiceTemplate.runSessionId,
        competitiveTemplate.runSessionId,
      ],
      templateRunSessionHashes: [
        shortHash(practiceTemplate.runSessionId),
        shortHash(competitiveTemplate.runSessionId),
      ],
    };
    await writeState(statePath, state);

    const definitions = scenarioDefinitions({
      practiceTemplate,
      competitiveTemplate,
    });
    for (const definition of definitions) {
      const fixture = await seedFixture({
        definition,
        uid: auth.localId,
        drillId,
      });
      state.fixtures.push(fixture);
      state.phase = `seeded_${definition.name}`;
      await writeState(statePath, state);
    }
    state.phase = "prepared";
    state.preparedAt = new Date().toISOString();
    await writeState(statePath, state);
    console.log(
      JSON.stringify(
        {
          command,
          drillIdHash: shortHash(drillId),
          uidHash: state.uidHash,
          fixtureCount: state.fixtures.length,
          groups: Object.fromEntries(
            ["compatibility", "resources", "simulation", "grace"].map(
              (group) => [
                group,
                state.fixtures.filter((fixture) => fixture.group === group)
                  .length,
              ],
            ),
          ),
          stateFile: statePath,
        },
        null,
        2,
      ),
    );
  } catch (error) {
    state.phase = "prepare_failed";
    state.prepareError = safeError(error);
    await writeState(statePath, state);
    throw error;
  }
}

async function createTicket({ auth, sessionId, mode, suffix }) {
  const result = await callFunction({
    projectId,
    region,
    idToken: auth.idToken,
    functionName: "runSessionCreate",
    data: {
      userId: auth.localId,
      sessionId,
      clientRequestId: `${suffix}-${randomBytes(8).toString("hex")}`,
      mode,
      levelId: "field",
      gameCompatVersion: "2026.03.0",
    },
  });
  assert(isObject(result.runTicket), `${mode} template ticket was malformed.`);
  return result.runTicket;
}

function scenarioDefinitions({ practiceTemplate, competitiveTemplate }) {
  return [
    {
      name: "compat_current_supported",
      group: "compatibility",
      template: competitiveTemplate,
      expectedState: "settlement_pending",
      expectedReason: null,
    },
    {
      name: "compat_game_retired",
      group: "compatibility",
      template: practiceTemplate,
      mutateTicket: (ticket) => {
        ticket.gameCompatVersion = "retired-game-v0";
      },
      expectedState: "rejected",
      expectedReason: "game_compat_version_unsupported",
    },
    {
      name: "compat_ticket_identity",
      group: "compatibility",
      template: practiceTemplate,
      mutateTicket: (ticket) => {
        ticket.uid = `different-${ticket.uid}`;
      },
      expectedState: "rejected",
      expectedReason: "ticket_identity_mismatch",
    },
    {
      name: "compat_loadout_digest",
      group: "compatibility",
      template: practiceTemplate,
      mutateTicket: (ticket) => {
        ticket.loadoutDigest = "b".repeat(64);
      },
      expectedState: "rejected",
      expectedReason: "loadout_digest_mismatch",
    },
    {
      name: "compat_ruleset_retired",
      group: "compatibility",
      template: competitiveTemplate,
      mutateTicket: (ticket) => {
        ticket.rulesetVersion = "retired-rules-v0";
        ticket.boardKey.rulesetVersion = "retired-rules-v0";
      },
      expectedState: "rejected",
      expectedReason: "board_compat_version_unsupported",
    },
    {
      name: "compat_score_retired",
      group: "compatibility",
      template: competitiveTemplate,
      mutateTicket: (ticket) => {
        ticket.scoreVersion = "retired-score-v0";
        ticket.boardKey.scoreVersion = "retired-score-v0";
      },
      expectedState: "rejected",
      expectedReason: "board_compat_version_unsupported",
    },
    {
      name: "compat_ghost_retired",
      group: "compatibility",
      template: competitiveTemplate,
      mutateTicket: (ticket) => {
        ticket.ghostVersion = "retired-ghost-v0";
      },
      expectedState: "rejected",
      expectedReason: "board_compat_version_unsupported",
    },
    {
      name: "compat_board_binding",
      group: "compatibility",
      template: competitiveTemplate,
      mutateReplay: (payload) => {
        payload.boardId = `wrong-${payload.boardId}`;
      },
      expectedState: "rejected",
      expectedReason: "board_id_mismatch",
    },
    {
      name: "compat_board_window",
      group: "compatibility",
      template: competitiveTemplate,
      mutateTicket: (ticket) => {
        ticket.boardOpensAtMs = ticket.issuedAtMs + 1;
        ticket.boardClosesAtMs = ticket.expiresAtMs;
      },
      expectedState: "rejected",
      expectedReason: "ticket_board_window_mismatch",
    },
    {
      name: "resource_compressed_metadata",
      group: "resources",
      template: practiceTemplate,
      contentLengthOverride: 8 * 1024 * 1024 + 1,
      expectedState: "rejected",
      expectedReason: "replay_compressed_size_limit_exceeded",
    },
    {
      name: "resource_expanded_gzip",
      group: "resources",
      template: practiceTemplate,
      buildRawPayload: (payload) => ({
        ...payload,
        padding: "a".repeat(32 * 1024 * 1024 + 1),
        canonicalSha256: "a".repeat(64),
      }),
      expectedState: "rejected",
      expectedReason: "replay_expanded_size_limit_exceeded",
    },
    {
      name: "resource_json_depth",
      group: "resources",
      template: practiceTemplate,
      buildRawPayload: (payload) => {
        let nested = "leaf";
        for (let depth = 0; depth < 65; depth += 1) {
          nested = [nested];
        }
        return {
          ...payload,
          nested,
          canonicalSha256: "a".repeat(64),
        };
      },
      expectedState: "rejected",
      expectedReason: "replay_json_nesting_limit_exceeded",
    },
    {
      name: "resource_frame_count",
      group: "resources",
      template: practiceTemplate,
      mutateReplay: (payload) => {
        payload.totalTicks = 250001;
        payload.commandStream = Array.from(
          { length: 250001 },
          (_, index) => ({ t: index + 1 }),
        );
      },
      expectedState: "rejected",
      expectedReason: "replay_frame_limit_exceeded",
    },
    {
      name: "resource_duration",
      group: "resources",
      template: practiceTemplate,
      mutateReplay: (payload) => {
        payload.totalTicks = payload.tickHz * 21600 + 1;
      },
      expectedState: "rejected",
      expectedReason: "replay_duration_limit_exceeded",
    },
    {
      name: "resource_simulation_deadline",
      group: "simulation",
      template: practiceTemplate,
      mutateReplay: (payload) => {
        payload.totalTicks = payload.tickHz * 21600;
      },
      expectedState: "rejected",
      expectedReason: "simulation_time_limit_exceeded",
    },
    {
      name: "internal_error_grace",
      group: "grace",
      template: practiceTemplate,
      expectedState: "internal_error",
      expectedReason: "internal_error",
    },
  ];
}

async function seedFixture({ definition, uid, drillId }) {
  const runSessionId =
    `${drillId}-${definition.name}-${randomBytes(4).toString("hex")}`.slice(
      0,
      120,
    );
  const ticket = structuredClone(definition.template);
  ticket.runSessionId = runSessionId;
  ticket.uid = uid;
  ticket.singleUseNonce = `${drillId}-${definition.name}`;
  definition.mutateTicket?.(ticket);

  let payload = {
    replayVersion: 1,
    runSessionId,
    ...(ticket.boardId ? { boardId: ticket.boardId } : {}),
    ...(ticket.boardKey ? { boardKey: structuredClone(ticket.boardKey) } : {}),
    tickHz: ticket.tickHz,
    seed: ticket.seed,
    levelId: ticket.levelId,
    playerCharacterId: ticket.playerCharacterId,
    loadoutSnapshot: structuredClone(ticket.loadoutSnapshot),
    commandEncodingVersion: 1,
    totalTicks: 1,
    commandStream: [],
  };
  definition.mutateReplay?.(payload);
  if (definition.buildRawPayload) {
    payload = definition.buildRawPayload(payload);
  } else {
    payload.canonicalSha256 = canonicalSha256(payload);
  }
  const bytes = gzipSync(Buffer.from(JSON.stringify(payload), "utf8"));
  const objectPath =
    `replay-submissions/pending/${uid}/${runSessionId}/replay.bin.gz`;
  const object = await storage.upload(objectPath, bytes, {
    contentType: "application/gzip",
  });
  const finalizedAtMs = Math.max(Date.now(), ticket.issuedAtMs + 1000);
  const uploadedReplay = {
    objectPath,
    canonicalSha256: payload.canonicalSha256,
    contentLengthBytes:
      definition.contentLengthOverride ?? bytes.length,
    contentType: "application/gzip",
    storageGeneration: object.generation,
    finalizedAtMs,
  };
  const session = {
    runSessionId,
    uid,
    mode: ticket.mode,
    state: "pending_validation",
    runTicket: ticket,
    uploadedReplay,
    validationAttempt: 0,
    createdAtMs: finalizedAtMs,
    updatedAtMs: finalizedAtMs,
    playerCharacterId: ticket.playerCharacterId,
    ...(ticket.boardId
      ? { boardId: ticket.boardId, boardKey: ticket.boardKey }
      : {}),
  };
  const reward = {
    runSessionId,
    uid,
    mode: ticket.mode,
    lifecycleState: "provisional_created",
    createdAtMs: finalizedAtMs,
    updatedAtMs: finalizedAtMs,
    ...(ticket.boardId
      ? { boardId: ticket.boardId, boardKey: ticket.boardKey }
      : {}),
  };
  await firestore.commit([
    documentWrite(`run_sessions/${runSessionId}`, session),
    documentWrite(`reward_grants/${runSessionId}`, reward),
  ]);
  return {
    scenario: definition.name,
    group: definition.group,
    runSessionId,
    runSessionHash: shortHash(runSessionId),
    objectPath,
    storageGeneration: object.generation,
    expectedState: definition.expectedState,
    expectedReason: definition.expectedReason,
  };
}

function documentWrite(path, data) {
  return {
    update: {
      name:
        `projects/${projectId}/databases/(default)/documents/${path}`,
      fields: encodeFields(data),
    },
    currentDocument: { exists: false },
  };
}

function encodeFields(data) {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, encodeValue(value)]),
  );
}

function encodeValue(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number") {
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (typeof value === "string") return { stringValue: value };
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(encodeValue) } };
  }
  if (isObject(value)) {
    return { mapValue: { fields: encodeFields(value) } };
  }
  throw new Error(`Unsupported Firestore value: ${typeof value}`);
}

async function exerciseGroup(group) {
  const targetUrl = requireArg(args, "target-url");
  const state = await readState(statePath);
  requirePreparedState(state);
  const identityToken = readGcloudIdentityToken();
  const fixtures = state.fixtures.filter((fixture) => fixture.group === group);
  assert(fixtures.length > 0, `No fixtures exist for group ${group}.`);
  const results = [];
  for (const fixture of fixtures) {
    const response = await invokePrivateService({
      baseUrl: targetUrl,
      path: "/tasks/validate",
      data: { runSessionId: fixture.runSessionId },
      identityToken,
    });
    const session = await firestore.get(
      `run_sessions/${fixture.runSessionId}`,
    );
    const validated = await firestore.get(
      `validated_runs/${fixture.runSessionId}`,
      { missingOk: true },
    );
    const grant = await firestore.get(
      `reward_grants/${fixture.runSessionId}`,
    );
    if (fixture.expectedReason === null) {
      assert(
        response.status === 202,
        `${fixture.scenario} expected HTTP 202, got ${response.status}.`,
      );
      assert(
        ["settlement_pending", "validated"].includes(session.data.state),
        `${fixture.scenario} ended in ${session.data.state}.`,
      );
      assert(
        validated?.data.accepted === true,
        `${fixture.scenario} did not persist accepted evidence.`,
      );
      assert(
        ["settlement_pending", "validated_settled"].includes(
          grant.data.lifecycleState,
        ),
        `${fixture.scenario} grant ended in ${grant.data.lifecycleState}.`,
      );
    } else {
      assert(
        response.status === 200,
        `${fixture.scenario} expected HTTP 200, got ${response.status}.`,
      );
      assert(
        session.data.state === fixture.expectedState,
        `${fixture.scenario} ended in ${session.data.state}.`,
      );
      assert(
        validated?.data.rejectionReason === fixture.expectedReason,
        `${fixture.scenario} reason was ${validated?.data.rejectionReason}.`,
      );
      assert(
        grant.data.lifecycleState === "revoked_final",
        `${fixture.scenario} grant ended in ${grant.data.lifecycleState}.`,
      );
    }
    results.push({
      scenario: fixture.scenario,
      runSessionHash: fixture.runSessionHash,
      httpStatus: response.status,
      state: session.data.state,
      rejectionReason: validated?.data.rejectionReason ?? null,
      rewardState: grant.data.lifecycleState,
    });
  }
  state[`${group}Results`] = results;
  state[`${group}VerifiedAt`] = new Date().toISOString();
  state.phase = `${group}_verified`;
  await writeState(statePath, state);
  console.log(
    JSON.stringify(
      {
        command,
        group,
        resultCount: results.length,
        results,
      },
      null,
      2,
    ),
  );
}

async function graceStart() {
  const targetUrl = requireArg(args, "target-url");
  const graceWindowMs = parsePositiveInteger(
    args.get("grace-window-ms"),
    5000,
  );
  const state = await readState(statePath);
  requirePreparedState(state);
  const fixture = state.fixtures.find((entry) => entry.group === "grace");
  assert(fixture, "Internal-error grace fixture is missing.");
  const identityToken = readGcloudIdentityToken();
  const attempts = [];
  for (let attempt = 1; attempt <= 8; attempt += 1) {
    const response = await invokePrivateService({
      baseUrl: targetUrl,
      path: "/tasks/validate",
      data: { runSessionId: fixture.runSessionId },
      identityToken,
    });
    const session = await firestore.get(
      `run_sessions/${fixture.runSessionId}`,
    );
    assert(
      response.status === 503,
      `Internal-error attempt ${attempt} returned ${response.status}.`,
    );
    assert(
      session.data.state === "pending_validation",
      `Internal-error attempt ${attempt} left ${session.data.state}.`,
    );
    if (attempt < 8) {
      assert(
        session.data.internalErrorFirstAtMs == null,
        `Internal-error grace started early on attempt ${attempt}.`,
      );
    }
    attempts.push({
      attempt,
      httpStatus: response.status,
      validationAttempt: session.data.validationAttempt,
      hasGraceStart: Number.isSafeInteger(session.data.internalErrorFirstAtMs),
    });
  }
  const session = await firestore.get(`run_sessions/${fixture.runSessionId}`);
  const grant = await firestore.get(`reward_grants/${fixture.runSessionId}`);
  const validated = await firestore.get(
    `validated_runs/${fixture.runSessionId}`,
    { missingOk: true },
  );
  assert(
    Number.isSafeInteger(session.data.internalErrorFirstAtMs),
    "Internal-error grace start was not persisted.",
  );
  assert(
    grant.data.lifecycleState === "provisional_created",
    "Grace entry mutated the provisional grant.",
  );
  assert(validated === null, "Grace entry wrote terminal validation evidence.");
  state.graceStartAtMs = session.data.internalErrorFirstAtMs;
  state.graceWindowMs = graceWindowMs;
  state.graceStartAttempts = attempts;
  state.phase = "grace_started";
  state.graceStartedAt = new Date().toISOString();
  await writeState(statePath, state);
  console.log(
    JSON.stringify(
      {
        command,
        runSessionHash: fixture.runSessionHash,
        attempts,
        graceStartPersisted: true,
        grantPreserved: true,
      },
      null,
      2,
    ),
  );
}

async function graceFinish() {
  const targetUrl = requireArg(args, "target-url");
  const state = await readState(statePath);
  requirePreparedState(state);
  assert(
    Number.isSafeInteger(state.graceStartAtMs) &&
      Number.isSafeInteger(state.graceWindowMs),
    "Run grace-start before grace-finish.",
  );
  const fixture = state.fixtures.find((entry) => entry.group === "grace");
  const deadline = state.graceStartAtMs + state.graceWindowMs;
  if (Date.now() <= deadline) {
    await delay(deadline - Date.now() + 750);
  }
  const identityToken = readGcloudIdentityToken();
  const response = await invokePrivateService({
    baseUrl: targetUrl,
    path: "/tasks/validate",
    data: { runSessionId: fixture.runSessionId },
    identityToken,
  });
  const session = await firestore.get(`run_sessions/${fixture.runSessionId}`);
  const grant = await firestore.get(`reward_grants/${fixture.runSessionId}`);
  const validated = await firestore.get(
    `validated_runs/${fixture.runSessionId}`,
    { missingOk: true },
  );
  assert(response.status === 200, `Grace finish returned ${response.status}.`);
  assert(
    session.data.state === "internal_error",
    `Grace finish left session ${session.data.state}.`,
  );
  assert(
    session.data.internalErrorFirstAtMs === state.graceStartAtMs,
    "Grace start changed across the service restart/repository round trip.",
  );
  assert(
    grant.data.lifecycleState === "revoked_final" &&
      grant.data.settlementReason === "internal_error",
    "Internal-error terminalization did not revoke the grant.",
  );
  assert(validated === null, "Internal-error terminalization wrote run evidence.");
  state.graceFinishResult = {
    runSessionHash: fixture.runSessionHash,
    httpStatus: response.status,
    state: session.data.state,
    validationAttempt: session.data.validationAttempt,
    graceStartUnchanged: true,
    rewardState: grant.data.lifecycleState,
  };
  state.graceVerifiedAt = new Date().toISOString();
  state.phase = "grace_verified";
  await writeState(statePath, state);
  console.log(JSON.stringify({ command, ...state.graceFinishResult }, null, 2));
}

async function inspect() {
  const state = await readState(statePath);
  const counts = {};
  for (const fixture of state.fixtures ?? []) {
    const session = await firestore.get(
      `run_sessions/${fixture.runSessionId}`,
      { missingOk: true },
    );
    const current = session?.data.state ?? "missing";
    counts[current] = (counts[current] ?? 0) + 1;
  }
  const objects = state.uid
    ? await storage.list(`replay-submissions/pending/${state.uid}/`)
    : [];
  console.log(
    JSON.stringify(
      {
        command,
        uidHash: state.uidHash,
        phase: state.phase,
        fixtureCount: state.fixtures?.length ?? 0,
        sessionStateCounts: counts,
        pendingObjectCount: objects.length,
        cleanupRequestedAt: state.cleanupRequestedAt ?? null,
        cleanupVerifiedAt: state.cleanupVerifiedAt ?? null,
      },
      null,
      2,
    ),
  );
}

async function resetFixtures() {
  const state = await readState(statePath);
  requirePreparedState(state);
  const requestedGroup = optionalArg(args, "group", "all");
  const supportedGroups = new Set([
    "all",
    "compatibility",
    "resources",
    "simulation",
    "grace",
  ]);
  assert(
    supportedGroups.has(requestedGroup),
    `Unsupported --group "${requestedGroup}".`,
  );
  const selectedFixtures = state.fixtures.filter(
    (fixture) => requestedGroup === "all" || fixture.group === requestedGroup,
  );
  assert(
    selectedFixtures.length > 0,
    `No fixtures matched --group "${requestedGroup}".`,
  );
  const fixtureDocuments = await Promise.all(
    selectedFixtures.map(async (fixture) => ({
      fixture,
      sessionDocument: await firestore.get(
        `run_sessions/${fixture.runSessionId}`,
      ),
      grantDocument: await firestore.get(
        `reward_grants/${fixture.runSessionId}`,
      ),
    })),
  );
  const nowMs = Date.now();
  for (const { fixture, sessionDocument } of fixtureDocuments) {
    assert(
      sessionDocument.data.runTicket.expiresAtMs > nowMs,
      `${fixture.name} has an expired ticket; clean these fixtures and prepare a fresh set.`,
    );
  }
  let resetCount = 0;
  for (const { fixture, sessionDocument, grantDocument } of fixtureDocuments) {
    const session = structuredClone(sessionDocument.data);
    const grant = structuredClone(grantDocument.data);
    const updatedAtMs = Date.now();
    session.state = "pending_validation";
    session.validationAttempt = 0;
    session.updatedAtMs = updatedAtMs;
    session.uploadedReplay.finalizedAtMs = Math.max(
      updatedAtMs,
      session.runTicket.issuedAtMs + 1000,
    );
    for (const field of [
      "terminalAtMs",
      "settlementPendingAtMs",
      "settlementRepairDisposition",
      "settlementRepairClassifiedAtMs",
      "settlementRepairAttempts",
      "message",
      "validationLeaseToken",
      "validationLeaseExpiresAtMs",
      "validationStartedAtMs",
      "validationNextAttemptAtMs",
      "internalErrorFirstAtMs",
    ]) {
      delete session[field];
    }
    grant.lifecycleState = "provisional_created";
    grant.updatedAtMs = updatedAtMs;
    for (const field of [
      "revokedAtMs",
      "revokedFinalAtMs",
      "settlementPendingAtMs",
      "settlementReason",
      "validatedRunRef",
      "lastTransitionBy",
      "revokedFinalBy",
      "goldAmount",
    ]) {
      delete grant[field];
    }
    await firestore.set(`run_sessions/${fixture.runSessionId}`, session);
    await firestore.set(`reward_grants/${fixture.runSessionId}`, grant);
    await firestore.delete(`validated_runs/${fixture.runSessionId}`);
    resetCount += 1;
  }
  const resultFields = {
    compatibility: ["compatibilityResults", "compatibilityVerifiedAt"],
    resources: ["resourcesResults", "resourcesVerifiedAt"],
    simulation: ["simulationResults", "simulationVerifiedAt"],
    grace: [
      "graceStartAtMs",
      "graceWindowMs",
      "graceStartAttempts",
      "graceStartedAt",
      "graceFinishResult",
      "graceVerifiedAt",
    ],
  };
  const clearedGroups =
    requestedGroup === "all"
      ? Object.keys(resultFields)
      : [requestedGroup];
  for (const field of clearedGroups.flatMap((group) => resultFields[group])) {
    delete state[field];
  }
  state.phase = requestedGroup === "all" ? "prepared" : `${requestedGroup}_reset`;
  state.fixturesResetAt = new Date().toISOString();
  await writeState(statePath, state);
  console.log(
    JSON.stringify(
      {
        command,
        group: requestedGroup,
        resetCount,
        phase: state.phase,
        exactStateFileRequired: true,
      },
      null,
      2,
    ),
  );
}

async function requestCleanup() {
  const state = await readState(statePath);
  assert(state.uid && state.refreshToken, "Cleanup credentials are unavailable.");
  const apiKey = await readFirebaseWebApiKey();
  const refreshed = await refreshAnonymousAccount(apiKey, state.refreshToken);
  const response = await callFunction({
    projectId,
    region,
    idToken: refreshed.idToken,
    functionName: "accountDelete",
    data: { userId: state.uid, sessionId: state.sessionId },
  });
  assert(isObject(response.result), "Account deletion response was malformed.");
  state.refreshToken = null;
  state.cleanupRequestedAt = new Date().toISOString();
  state.cleanupRequestStatus = response.result.status;
  state.phase = "cleanup_requested";
  await writeState(statePath, state);
  console.log(
    JSON.stringify(
      {
        command,
        uidHash: state.uidHash,
        status: response.result.status,
        credentialScrubbed: true,
      },
      null,
      2,
    ),
  );
}

async function verifyClean() {
  const state = await readState(statePath);
  assert(state.uid, "Drill UID is unavailable.");
  const deletion = await firestore.get(
    `account_deletion_requests/${state.uid}`,
    { missingOk: true },
  );
  const residual = [];
  for (const runSessionId of [
    ...(state.templateRunSessionIds ?? []),
    ...(state.fixtures ?? []).map((fixture) => fixture.runSessionId),
  ]) {
    for (const collection of [
      "run_sessions",
      "validated_runs",
      "reward_grants",
    ]) {
      if (
        await firestore.get(`${collection}/${runSessionId}`, {
          missingOk: true,
        })
      ) {
        residual.push(`${collection}/${shortHash(runSessionId)}`);
      }
    }
  }
  for (const collection of [
    "player_profiles",
    "ownership_profiles",
    "abuse_quota",
  ]) {
    if (
      await firestore.get(`${collection}/${state.uid}`, { missingOk: true })
    ) {
      residual.push(`${collection}/${state.uidHash}`);
    }
  }
  const [
    playerBests,
    ghostManifests,
    idempotency,
  ] = await Promise.all([
    firestore.queryCollection("player_bests"),
    firestore.queryCollection("ghost_manifests"),
    firestore.queryCollection("idempotency"),
  ]);
  residual.push(
    ...playerBests
      .filter((doc) => doc.data.uid === state.uid)
      .map(() => `player_best/${state.uidHash}`),
    ...ghostManifests
      .filter((doc) => doc.data.uid === state.uid)
      .map(() => `ghost_manifest/${state.uidHash}`),
    ...idempotency
      .filter((doc) => doc.data.uid === state.uid)
      .map(() => `idempotency/${state.uidHash}`),
  );
  const pendingObjects = await storage.list(
    `replay-submissions/pending/${state.uid}/`,
  );
  const validatedObjects = await storage.list(
    `replay-submissions/validated/${state.uid}/`,
  );
  residual.push(
    ...pendingObjects.map(() => `pending_object/${state.uidHash}`),
    ...validatedObjects.map(() => `validated_object/${state.uidHash}`),
  );
  assert(
    deletion?.data.state === "complete",
    `Deletion state is ${deletion?.data.state ?? "missing"}.`,
  );
  assert(residual.length === 0, `Residual drill data: ${residual.join(", ")}`);
  state.cleanupVerifiedAt = new Date().toISOString();
  state.phase = "cleanup_verified";
  await writeState(statePath, state);
  console.log(
    JSON.stringify(
      {
        command,
        uidHash: state.uidHash,
        deletionState: deletion.data.state,
        residualCount: 0,
        verifiedAt: state.cleanupVerifiedAt,
      },
      null,
      2,
    ),
  );
}

function requirePreparedState(state) {
  assert(
    Array.isArray(state.fixtures) && state.fixtures.length > 0,
    "Prepared fixture state is unavailable.",
  );
}

function safeError(error) {
  return (error instanceof Error ? error.message : String(error)).slice(0, 800);
}
