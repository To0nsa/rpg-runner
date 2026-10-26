import { HttpsError } from "firebase-functions/v2/https";

export const currentGameCompatVersion = "2026.10.21";


const defaultSupportedGameCompatVersions = Object.freeze([
  currentGameCompatVersion,
]);

export function resolveSupportedGameCompatVersions(
  env: NodeJS.ProcessEnv = process.env,
): ReadonlySet<string> {
  const configured = env.RUN_SUPPORTED_GAME_COMPAT_VERSIONS?.trim();
  if (!configured) {
    return new Set(defaultSupportedGameCompatVersions);
  }

  const versions = new Set(
    configured
      .split(",")
      .map((value) => value.trim())
      .filter((value) => value.length > 0),
  );
  return versions.size > 0
    ? versions
    : new Set(defaultSupportedGameCompatVersions);
}

export function assertSupportedGameCompatVersion(
  gameCompatVersion: string,
  supportedVersions: ReadonlySet<string> = resolveSupportedGameCompatVersions(),
): void {
  // The release fence wins even if an accidental additional version is present.
  // Already-issued uploads/status/settlement do not call this issuance guard.
  if (supportedVersions.has("release-paused")) {
    throw new HttpsError("unavailable", "The game is undergoing maintenance.", {
      reason: "release-maintenance",
    });
  }
  if (supportedVersions.has(gameCompatVersion)) {
    return;
  }
  // Versions use YYYY.M.D[.revision]. A candidate installed before its backend
  // cutover waits for maintenance; sending it back to the store cannot help.
  const candidate = compatibilityParts(gameCompatVersion);
  const serving = compatibilityParts(currentGameCompatVersion)!;
  const firstDifference = candidate?.findIndex((part, index) => part !== serving[index]);
  if (candidate && firstDifference !== undefined && firstDifference >= 0 &&
      candidate[firstDifference]! > serving[firstDifference]!) {
    throw new HttpsError("unavailable", "This game version is not available yet.", {
      reason: "release-maintenance",
    });
  }
  throw new HttpsError(
    "failed-precondition",
    `Unsupported gameCompatVersion ${gameCompatVersion}.`,
    { reason: "update-required", gameCompatVersion: currentGameCompatVersion },
  );
}

function compatibilityParts(version: string): number[] | null {
  if (!/^\d{4}\.\d{1,2}\.\d{1,2}(?:\.\d+)?$/.test(version)) return null;
  const parts = version.split(".").map(Number);
  if (parts.length === 3) parts.push(0);
  return parts;
}
