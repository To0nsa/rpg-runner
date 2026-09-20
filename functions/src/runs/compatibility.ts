import { HttpsError } from "firebase-functions/v2/https";

export const currentGameCompatVersion = "2026.09.3";

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
  if (supportedVersions.has(gameCompatVersion)) {
    return;
  }
  throw new HttpsError(
    "failed-precondition",
    `Unsupported gameCompatVersion ${gameCompatVersion}.`,
  );
}
