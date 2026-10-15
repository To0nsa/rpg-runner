import * as logger from "firebase-functions/logger";
import type { CallableOptions } from "firebase-functions/v2/https";

export type AppCheckRolloutMode = "monitor" | "enforce";

export interface CallableAppCheckLike {
  auth?: { uid: string };
  data?: unknown;
  rawRequest?: { get(name: string): string | undefined };
  app?: {
    appId: string;
    alreadyConsumed?: boolean;
  };
}

export function appCheckRolloutMode(
  raw: string | undefined = process.env.APP_CHECK_ROLLOUT_MODE,
): AppCheckRolloutMode {
  const value = raw?.trim().toLowerCase();
  if (!value || value === "monitor") {
    return "monitor";
  }
  if (value === "enforce") {
    return "enforce";
  }
  throw new Error(
    "APP_CHECK_ROLLOUT_MODE must be either 'monitor' or 'enforce'.",
  );
}

export function appCheckCallableOptions(
  mode: AppCheckRolloutMode = appCheckRolloutMode(),
): Pick<CallableOptions, "enforceAppCheck" | "consumeAppCheckToken"> {
  return {
    enforceAppCheck: mode === "enforce",
    // Standard callable tokens are intentionally not consumed. Replay
    // protection requires limited-use client tokens and is a separate rollout.
    consumeAppCheckToken: false,
  };
}

export function logAppCheckObservation(args: {
  functionName: string;
  request: CallableAppCheckLike;
  mode?: AppCheckRolloutMode;
}): void {
  const mode = args.mode ?? appCheckRolloutMode();
  const observation = appCheckObservation(args.request);
  const write = args.request.app ? logger.info : logger.warn;
  write("callable_app_check", {
    functionName: args.functionName,
    rolloutMode: mode,
    appCheckAllowsRequest: mode === "monitor" || !!args.request.app,
    ...observation,
  });
}

/** Bounded diagnostics only: header shapes and client claims never authorize a request. */
export function appCheckObservation(request: CallableAppCheckLike) {
  const app = request.app;
  const header = request.rawRequest?.get("X-Firebase-AppCheck");
  const tokenFailure = app ? "none" : classifyUnverifiedHeader(header);
  const clientReported = clientDiagnostics(request.data);
  const userAgent = request.rawRequest?.get("User-Agent") ?? "";
  return {
    tokenStatus: app ? "verified" : "missing_or_invalid",
    tokenFailure,
    authStatus: request.auth ? "authenticated" : "unauthenticated",
    clientTransportHint: userAgent.startsWith("okhttp/") ? "okhttp"
      : userAgent.startsWith("Dart/") ? "dart"
        : userAgent.startsWith("Mozilla/") ? "browser" : "unknown",
    nextAction: nextDiagnosticAction(tokenFailure, clientReported),
    ...(clientReported ? { clientReported } : {}),
    ...(app ? { appId: app.appId } : {}),
    ...(app?.alreadyConsumed !== undefined
      ? { alreadyConsumed: app.alreadyConsumed }
      : {}),
  };
}

function classifyUnverifiedHeader(header: string | undefined) {
  if (!header) return "missing_token";
  // Firebase Android DefaultAppCheckTokenResult emits this sentinel on failure.
  // Do not decode or log arbitrary unverified token contents.
  if (header === "eyJlcnJvciI6IlVOS05PV05fRVJST1IifQ==" ||
      header === "eyJlcnJvciI6IlVOS05PV05fRVJST1IifQ") {
    return "android_sdk_placeholder";
  }
  return /^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(header)
    ? "jwt_rejected" : "malformed_token";
}

function nextDiagnosticAction(
  failure: string,
  client: Record<string, string> | undefined,
): string {
  if (failure === "none") return "none";
  if (failure === "jwt_rejected") {
    return "Correlate the Firebase verification warning in this trace for expiry, audience or signature failure.";
  }
  if (client?.failureReason === "network_error") {
    return "Check device connectivity to Firebase App Check.";
  }
  if (client?.failureReason === "rate_limited") {
    return "Inspect App Check quota and SDK backoff; do not force-refresh in a loop.";
  }
  if (client?.provider === "debug") {
    return "Register this installation's debug token under the matching Firebase app; reinstall or cleared app data can change it.";
  }
  if (client?.provider === "play_integrity") {
    return "Check signing SHA-256, Play Integrity project linkage, distribution requirements and device verdict; inspect client token-acquisition diagnostics.";
  }
  if (failure === "missing_token") {
    return "Check App Check activation and provider configuration before the first callable.";
  }
  return "Inspect client token-acquisition diagnostics; Android SDK placeholders mean no attestation token was obtained. Check debug registration or release Play Integrity. More specific provider evidence is unavailable on the server.";
}

function clientDiagnostics(data: unknown): Record<string, string> | undefined {
  if (!data || typeof data !== "object" || Array.isArray(data)) return;
  const raw = (data as Record<string, unknown>).clientDiagnostics;
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return;
  const source = raw as Record<string, unknown>;
  const result: Record<string, string> = {};
  const enums: Record<string, readonly string[]> = {
    platform: ["android", "iOS", "macOS", "windows", "linux", "fuchsia", "web"],
    buildMode: ["debug", "profile", "release"],
    provider: ["debug", "play_integrity", "app_attest_device_check", "recaptcha_enterprise", "unsupported"],
    tokenAcquisition: ["not_attempted", "available", "failed", "timeout", "empty", "skipped"],
    tokenAcquisitionScope: ["startup"],
    failureReason: ["none", "attestation_rejected", "rate_limited", "network_error", "provider_missing", "unknown_error", "timeout", "empty_token"],
  };
  for (const [key, allowed] of Object.entries(enums)) {
    if (typeof source[key] === "string" && allowed.includes(source[key])) {
      result[key] = source[key];
    }
  }
  // Never copy arbitrary SDK messages, headers, JWT claims, UID or request data.
  if (typeof source.appId === "string" && source.appId.length <= 128 &&
      /^1:[0-9]+:(android|ios|web):[a-f0-9]+$/.test(source.appId)) {
    result.appId = source.appId;
  }
  return Object.keys(result).length ? result : undefined;
}
