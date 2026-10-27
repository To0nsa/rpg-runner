#!/usr/bin/env node

import { readFile } from "node:fs/promises";
import { execFileSync } from "node:child_process";
import { createRequire } from "node:module";
import { randomUUID } from "node:crypto";
import { Firestore } from "firebase-admin/firestore";
import { Storage } from "@google-cloud/storage";
import { pruneObsoleteLeaderboardBoards } from "../lib/boards/retention.js";
import { resolveBoardProvisioningConfig } from "../lib/boards/provisioning.js";

const args = process.argv.slice(2);
const value = (name) => args[args.indexOf(name) + 1];
const environment = args.includes("--environment") ? value("--environment") : null;
const gameCompatVersion = args.includes("--game-compat") ? value("--game-compat") : null;
if (!environment || !gameCompatVersion) throw new Error("Required: --environment dev|staging|prod --game-compat VERSION [--apply] [--immediate]");
const registry = JSON.parse(await readFile(new URL("../../tools/release/environments.json", import.meta.url), "utf8"));
const target = registry.environments[environment];
if (!target) throw new Error("Unknown environment.");
if (args.includes("--immediate") && environment !== "dev") throw new Error("Immediate pre-release pruning is restricted to dev.");
process.env.REPLAY_STORAGE_BUCKET = target.replayBucket;
const config = { ...resolveBoardProvisioningConfig(), gameCompatVersion };
if (gameCompatVersion !== resolveBoardProvisioningConfig().gameCompatVersion) {
  throw new Error("Explicit gameplay version must match this checkout's serving configuration; verify the live issuer first.");
}
// Use the same operator as gcloud; ADC can intentionally belong to a narrower
// runtime identity. Tokens remain in memory and are never written to evidence.
const { GoogleAuth, OAuth2Client } = createRequire(import.meta.resolve("firebase-admin/app"))("google-auth-library");
const { OAuth2Client: StorageOAuth2Client } = createRequire(import.meta.resolve("@google-cloud/storage"))("google-auth-library");
const accessToken = execFileSync("gcloud auth print-access-token", { encoding: "utf8", shell: true }).trim();
const authClient = new OAuth2Client();
const credentials = { access_token: accessToken, expiry_date: Date.now() + 50 * 60 * 1000 };
authClient.setCredentials(credentials);
// Storage and Firebase currently resolve different google-auth major versions;
// use each SDK's own OAuth client to preserve its request-header representation.
const storageAuthClient = new StorageOAuth2Client();
storageAuthClient.setCredentials(credentials);
const db = new Firestore({ projectId: target.projectId, auth: new GoogleAuth({ authClient }) });
const storage = new Storage({ projectId: target.projectId, authClient: storageAuthClient });
const bucket = storage.bucket(target.replayBucket);
const lock = storage.bucket(`${target.projectId}_cloudbuild`).file("_release/mutation-lock.json");
let lockGeneration;
try {
  const apply = args.includes("--apply");
  if (apply) {
    await lock.save(JSON.stringify({ action: "PruneBoards", environment, projectId: target.projectId, owner: randomUUID(), createdAt: new Date().toISOString() }),
      { resumable: false, preconditionOpts: { ifGenerationMatch: 0 } });
    [ { generation: lockGeneration } ] = await lock.getMetadata();
  }
  let afterBoardId;
  let changedInCycle = 0;
  const totals = { retiredCount: 0, deletedCount: 0, childDeleteCount: 0, objectDeleteCount: 0 };
  const candidates = new Set();
  for (let page = 0; page < 500; page += 1) {
    const result = await pruneObsoleteLeaderboardBoards({
      db, config, supportedVersions: new Set([gameCompatVersion]),
      apply, immediate: args.includes("--immediate"), maxBoards: 25,
      deleteGhostPage: async (boardId) => {
        const [files] = await bucket.getFiles({ prefix: `ghosts/${boardId}/`, maxResults: 100, autoPaginate: false });
        for (const file of files) await file.delete({ ignoreNotFound: true, ifGenerationMatch: file.metadata.generation });
        return files.length;
      },
      ...(!apply && afterBoardId ? { afterBoardId } : {}),
    });
    for (const id of result.candidates) candidates.add(id);
    for (const key of Object.keys(totals)) totals[key] += result[key];
    changedInCycle += result.retiredCount + result.deletedCount + result.childDeleteCount + result.objectDeleteCount;
    if (result.completedPage) {
      if (!apply || changedInCycle === 0) break;
      changedInCycle = 0;
    }
    afterBoardId = result.nextCursor;
    if (page === 499) throw new Error("Pruning page budget exhausted; rerun to resume.");
  }
  const remaining = await db.collection("leaderboard_boards").select("mode", "levelId", "windowId", "gameCompatVersion", "status").get();
  console.log(JSON.stringify({ projectId: target.projectId, environment, apply, gameCompatVersion, ...totals,
    candidateCount: candidates.size, candidates: [...candidates],
    remainingCount: remaining.size, remaining: remaining.docs.map((doc) => ({ boardId: doc.id, ...doc.data() })),
  }, null, 2));
} catch (error) {
  // SDK errors can contain authenticated HTTP request headers; emit only the
  // diagnostic message, never the full error/request object.
  console.error(`Board pruning failed: ${error.message}`);
  process.exitCode = 1;
} finally {
  if (lockGeneration) await lock.delete({ ifGenerationMatch: lockGeneration });
  await db.terminate();
}
