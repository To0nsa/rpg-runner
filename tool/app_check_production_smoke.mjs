import { execFileSync, spawn } from "node:child_process";
import {
  mkdtempSync,
  readFileSync,
  rmSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const projectId = "rpg-runner-d7add";
const hostingUrl = "https://rpg-runner-d7add.web.app/";
const callableUrl =
  "https://europe-west1-rpg-runner-d7add.cloudfunctions.net/playerProfileLoad";
const keyDisplayName = "RPG Runner Firebase App Check web";
const firebaseJsSdkVersion = "12.15.0";
const browserDebugPort = 9337;

function execGcloud(args) {
  if (process.platform === "win32") {
    return execFileSync(
      process.env.ComSpec ?? "C:\\Windows\\System32\\cmd.exe",
      ["/d", "/s", "/c", "gcloud.cmd", ...args],
      {
        encoding: "utf8",
        windowsHide: true,
      },
    );
  }
  return execFileSync("gcloud", args, {
    encoding: "utf8",
  });
}

function readWebFirebaseOptions() {
  const source = readFileSync("lib/firebase_options.dart", "utf8");
  const block = source.match(
    /static const FirebaseOptions web = FirebaseOptions\(([\s\S]*?)\n\s*\);/,
  )?.[1];
  if (!block) {
    throw new Error("Unable to find the web Firebase options.");
  }

  const readString = (name) => {
    const value = block.match(
      new RegExp(`${name}:\\s*'([^']+)'`),
    )?.[1];
    if (!value) {
      throw new Error(`Unable to find web Firebase option ${name}.`);
    }
    return value;
  };

  return {
    apiKey: readString("apiKey"),
    appId: readString("appId"),
    messagingSenderId: readString("messagingSenderId"),
    projectId: readString("projectId"),
    authDomain: readString("authDomain"),
    storageBucket: readString("storageBucket"),
  };
}

function findEdge() {
  const candidates = [
    "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe",
    "C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe",
  ];
  for (const candidate of candidates) {
    try {
      execFileSync(candidate, ["--version"], {
        stdio: "ignore",
        windowsHide: true,
      });
      return candidate;
    } catch {
      // Try the next standard installation path.
    }
  }
  throw new Error("Microsoft Edge was not found.");
}

async function readEnterpriseSiteKey(accessToken) {
  const response = await fetch(
    `https://recaptchaenterprise.googleapis.com/v1/projects/${projectId}/keys?pageSize=100`,
    {
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "x-goog-user-project": projectId,
      },
    },
  );
  if (!response.ok) {
    throw new Error(
      `Unable to list reCAPTCHA Enterprise keys: HTTP ${response.status}.`,
    );
  }
  const body = await response.json();
  const key = body.keys?.find(
    (candidate) => candidate.displayName === keyDisplayName,
  );
  const siteKey = key?.name?.split("/").at(-1);
  if (!siteKey) {
    throw new Error(`Unable to find Enterprise key "${keyDisplayName}".`);
  }
  return siteKey;
}

async function waitForBrowserTarget() {
  const deadline = Date.now() + 30_000;
  while (Date.now() < deadline) {
    try {
      const response = await fetch(
        `http://127.0.0.1:${browserDebugPort}/json`,
      );
      if (response.ok) {
        const targets = await response.json();
        const target = targets.find(
          (candidate) =>
            candidate.type === "page" &&
            candidate.url.startsWith(hostingUrl),
        );
        if (target) {
          return target;
        }
      }
    } catch {
      // Edge has not opened its debugging endpoint yet.
    }
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  throw new Error("The production page did not become available in Edge.");
}

async function evaluate(target, expression) {
  const socket = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => {
    socket.addEventListener("open", resolve, { once: true });
    socket.addEventListener(
      "error",
      () => reject(new Error("Unable to connect to the Edge debugger.")),
      { once: true },
    );
  });

  try {
    const id = 1;
    const response = new Promise((resolve, reject) => {
      const timeout = setTimeout(
        () => reject(new Error("Browser evaluation timed out.")),
        120_000,
      );
      socket.addEventListener("message", (event) => {
        const message = JSON.parse(String(event.data));
        if (message.id !== id) {
          return;
        }
        clearTimeout(timeout);
        if (message.error) {
          reject(
            new Error(`Browser evaluation failed: ${message.error.message}`),
          );
        } else {
          resolve(message.result);
        }
      });
    });

    socket.send(
      JSON.stringify({
        id,
        method: "Runtime.evaluate",
        params: {
          expression,
          awaitPromise: true,
          returnByValue: true,
        },
      }),
    );
    return await response;
  } finally {
    socket.close();
  }
}

function buildExpression(firebaseOptions, siteKey) {
  return `
    (async () => {
      try {
        const firebaseApp = await import(
          "https://www.gstatic.com/firebasejs/${firebaseJsSdkVersion}/firebase-app.js"
        );
        const firebaseAppCheck = await import(
          "https://www.gstatic.com/firebasejs/${firebaseJsSdkVersion}/firebase-app-check.js"
        );
        const app = firebaseApp.initializeApp(
          ${JSON.stringify(firebaseOptions)},
          "production-attestation-smoke-" + Date.now()
        );
        const appCheck = firebaseAppCheck.initializeAppCheck(app, {
          provider: new firebaseAppCheck.ReCaptchaEnterpriseProvider(
            ${JSON.stringify(siteKey)}
          ),
          isTokenAutoRefreshEnabled: false
        });
        const tokenResult = await firebaseAppCheck.getToken(appCheck, true);
        const callableResponse = await fetch(
          ${JSON.stringify(callableUrl)},
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "X-Firebase-AppCheck": tokenResult.token
            },
            body: JSON.stringify({
              data: { userId: "production-attestation-smoke" }
            })
          }
        );
        const callableBody = await callableResponse.text();
        return {
          ok: true,
          hostname: location.hostname,
          tokenPresent: tokenResult.token.length > 0,
          tokenLength: tokenResult.token.length,
          callableStatus: callableResponse.status,
          callableUnauthenticated:
            callableBody.includes("UNAUTHENTICATED") ||
            callableBody.includes("unauthenticated")
        };
      } catch (error) {
        return {
          ok: false,
          hostname: location.hostname,
          errorName: error?.name ?? "Error",
          errorMessage: String(error?.message ?? error)
        };
      }
    })()
  `;
}

const profileDirectory = mkdtempSync(
  join(tmpdir(), "rpg-runner-app-check-"),
);
let browser;

try {
  const accessToken = execGcloud(["auth", "print-access-token"]).trim();
  if (!accessToken) {
    throw new Error("Unable to obtain a Google Cloud access token.");
  }

  const [siteKey, firebaseOptions] = await Promise.all([
    readEnterpriseSiteKey(accessToken),
    Promise.resolve(readWebFirebaseOptions()),
  ]);
  const edge = findEdge();
  browser = spawn(
    edge,
    [
      "--headless=new",
      "--disable-gpu",
      "--no-first-run",
      "--no-default-browser-check",
      `--remote-debugging-port=${browserDebugPort}`,
      `--user-data-dir=${profileDirectory}`,
      `${hostingUrl}?app-check-smoke=20260719`,
    ],
    {
      stdio: "ignore",
      windowsHide: true,
    },
  );

  const target = await waitForBrowserTarget();
  await new Promise((resolve) => setTimeout(resolve, 15_000));
  const response = await evaluate(
    target,
    buildExpression(firebaseOptions, siteKey),
  );
  if (response.exceptionDetails) {
    throw new Error("The production browser expression threw an exception.");
  }
  const result = response.result?.value;
  if (!result?.ok || !result.tokenPresent) {
    throw new Error(
      `App Check token exchange failed: ${result?.errorName ?? "Error"}: ${
        result?.errorMessage ?? "unknown failure"
      }`,
    );
  }

  console.log(
    JSON.stringify(
      {
        productionOrigin: result.hostname,
        tokenExchangeSucceeded: true,
        tokenLength: result.tokenLength,
        callableHttpStatus: result.callableStatus,
        callableReachedAuthGate: result.callableUnauthenticated,
        tokenPrinted: false,
        siteKeyPrinted: false,
      },
      null,
      2,
    ),
  );
} finally {
  if (browser && browser.exitCode === null) {
    browser.kill();
    await new Promise((resolve) => browser.once("exit", resolve));
  }
  rmSync(profileDirectory, { recursive: true, force: true });
}
