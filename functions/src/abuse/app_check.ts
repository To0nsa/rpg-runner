import * as logger from "firebase-functions/logger";
import type { CallableOptions } from "firebase-functions/v2/https";

export type AppCheckRolloutMode = "monitor" | "enforce";

export interface CallableAppCheckLike {
  app?: {
    appId: string;
    alreadyConsumed?: boolean;
  };
}

export function appCheckRolloutMode(
  raw: string | undefined = process.env.APP_CHECK_ROLLOUT_MODE,
): AppCheckRolloutMode {
  return raw?.trim().toLowerCase() === "enforce" ? "enforce" : "monitor";
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
  const app = args.request.app;
  logger.info("callable_app_check", {
    functionName: args.functionName,
    rolloutMode: mode,
    tokenStatus: app ? "verified" : "missing_or_invalid",
    ...(app ? { appId: app.appId } : {}),
    ...(app?.alreadyConsumed !== undefined
      ? { alreadyConsumed: app.alreadyConsumed }
      : {}),
  });
}
