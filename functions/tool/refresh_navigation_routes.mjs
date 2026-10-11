import { readFileSync, writeFileSync } from "node:fs";
import { buildDeterministicSeed, resolveBoardProvisioningConfig } from "../lib/boards/provisioning.js";

// This is an offline producer. Window IDs are explicit release inputs; no live
// board is read or modified. Build Functions before running it.
const path = new URL("../src/runs/navigation_routes.json", import.meta.url);
const plan = JSON.parse(readFileSync(path, "utf8"));
const config = resolveBoardProvisioningConfig({});
for (const route of plan.additionalRoutes) {
  route.gameCompatVersion = config.gameCompatVersion;
  route.seed = buildDeterministicSeed({
    mode: route.mode,
    levelId: route.levelId,
    windowId: route.windowId,
    rulesetVersion: config.rulesetVersion,
    scoreVersion: config.scoreVersion,
    gameCompatVersion: config.gameCompatVersion,
    seedNamespace: config.seedNamespace,
  });
}
writeFileSync(path, `${JSON.stringify(plan, null, 2)}\n`);
