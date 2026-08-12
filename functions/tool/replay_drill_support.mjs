import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";

export function parseArgs(values) {
  const parsed = new Map();
  for (let index = 0; index < values.length; index += 1) {
    const current = values[index];
    if (!current.startsWith("--")) {
      throw new Error(`Unexpected argument: ${current}`);
    }
    const name = current.slice(2);
    const value = values[index + 1];
    if (!value || value.startsWith("--")) {
      throw new Error(`Missing value for --${name}`);
    }
    parsed.set(name, value);
    index += 1;
  }
  return parsed;
}

export function requireArg(args, name) {
  const value = args.get(name)?.trim();
  if (!value) {
    throw new Error(`--${name} is required.`);
  }
  return value;
}

export function optionalArg(args, name, fallback) {
  return args.get(name)?.trim() || fallback;
}

export function parsePositiveInteger(value, fallback) {
  if (value === undefined) {
    return fallback;
  }
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed <= 0) {
    throw new Error(`Expected a positive integer, got "${value}".`);
  }
  return parsed;
}

export function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

export function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

export function shortHash(value) {
  return createHash("sha256").update(value).digest("hex").slice(0, 16);
}

export function canonicalJson(value) {
  if (Array.isArray(value)) {
    return `[${value.map(canonicalJson).join(",")}]`;
  }
  if (isObject(value)) {
    return `{${Object.keys(value)
      .sort()
      .map((key) => `${JSON.stringify(key)}:${canonicalJson(value[key])}`)
      .join(",")}}`;
  }
  return JSON.stringify(value);
}

export function canonicalSha256(value) {
  return createHash("sha256").update(canonicalJson(value)).digest("hex");
}

export function delay(milliseconds) {
  return new Promise((resolveDelay) => setTimeout(resolveDelay, milliseconds));
}

export async function readState(path) {
  return JSON.parse(await readFile(resolve(path), "utf8"));
}

export async function writeState(path, state) {
  const resolved = resolve(path);
  await mkdir(dirname(resolved), { recursive: true });
  await writeFile(resolved, `${JSON.stringify(state, null, 2)}\n`, {
    encoding: "utf8",
    mode: 0o600,
  });
}

export function readGcloudAccessToken() {
  return runGcloud(["auth", "print-access-token"]).trim();
}

export function readGcloudIdentityToken() {
  return runGcloud(["auth", "print-identity-token"]).trim();
}

function runGcloud(args) {
  if (process.platform === "win32") {
    const escaped = args
      .map((value) => `'${value.replaceAll("'", "''")}'`)
      .join(" ");
    return execFileSync(
      "powershell.exe",
      [
        "-NoProfile",
        "-Command",
        `& gcloud ${escaped}`,
      ],
      { encoding: "utf8", windowsHide: true },
    );
  }
  return execFileSync("gcloud", args, { encoding: "utf8" });
}

export async function readFirebaseWebApiKey() {
  const supplied = process.env.FIREBASE_WEB_API_KEY?.trim();
  if (supplied) {
    return supplied;
  }
  const source = await readFile(
    resolve("lib/firebase_options.dart"),
    "utf8",
  );
  const webStart = source.indexOf(
    "static const FirebaseOptions web = FirebaseOptions(",
  );
  const webSource =
    webStart >= 0
      ? source.slice(webStart, source.indexOf(");", webStart) + 2)
      : source;
  const match = webSource.match(/apiKey:\s*'([^']+)'/);
  if (!match) {
    throw new Error(
      "FIREBASE_WEB_API_KEY is missing and lib/firebase_options.dart has no API key.",
    );
  }
  return match[1];
}

export async function createAnonymousAccount(apiKey) {
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${encodeURIComponent(apiKey)}`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ returnSecureToken: true }),
    },
  );
  const body = await readJson(response);
  if (
    !response.ok ||
    typeof body.localId !== "string" ||
    typeof body.idToken !== "string" ||
    typeof body.refreshToken !== "string"
  ) {
    throw new Error(
      `Anonymous Firebase Auth signup failed (${response.status}): ${safeBody(body)}`,
    );
  }
  return {
    localId: body.localId,
    idToken: body.idToken,
    refreshToken: body.refreshToken,
  };
}

export async function refreshAnonymousAccount(apiKey, refreshToken) {
  const response = await fetch(
    `https://securetoken.googleapis.com/v1/token?key=${encodeURIComponent(apiKey)}`,
    {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "refresh_token",
        refresh_token: refreshToken,
      }),
    },
  );
  const body = await readJson(response);
  if (
    !response.ok ||
    typeof body.id_token !== "string" ||
    typeof body.refresh_token !== "string"
  ) {
    throw new Error(
      `Firebase Auth refresh failed (${response.status}): ${safeBody(body)}`,
    );
  }
  return {
    idToken: body.id_token,
    refreshToken: body.refresh_token,
  };
}

export async function deleteFirebaseAccount(apiKey, idToken) {
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${encodeURIComponent(apiKey)}`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ idToken }),
    },
  );
  const body = await readJson(response);
  if (!response.ok) {
    throw new Error(
      `Firebase Auth account deletion failed (${response.status}): ${safeBody(body)}`,
    );
  }
}

export async function callFunction({
  projectId,
  region,
  idToken,
  functionName,
  data,
}) {
  const response = await fetch(
    `https://${region}-${projectId}.cloudfunctions.net/${functionName}`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${idToken}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({ data }),
    },
  );
  const body = await readJson(response);
  if (!response.ok || isObject(body.error)) {
    throw new Error(
      `${functionName} failed (HTTP ${response.status}, ` +
        `${body.error?.status ?? "UNKNOWN"}): ` +
        `${String(body.error?.message ?? safeBody(body)).slice(0, 500)}`,
    );
  }
  if (!isObject(body.result)) {
    throw new Error(`${functionName} returned a malformed callable response.`);
  }
  return body.result;
}

export class FirestoreRest {
  constructor({ projectId, accessToken = readGcloudAccessToken() }) {
    this.projectId = projectId;
    this.accessToken = accessToken;
    this.root =
      `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(projectId)}` +
      "/databases/(default)/documents";
  }

  async get(path, { missingOk = false } = {}) {
    const response = await fetch(`${this.root}/${encodeDocumentPath(path)}`, {
      headers: { authorization: `Bearer ${this.accessToken}` },
    });
    if (missingOk && response.status === 404) {
      return null;
    }
    if (!response.ok) {
      throw new Error(
        `Firestore GET ${path} failed (${response.status}): ${await response.text()}`,
      );
    }
    return decodeDocument(await response.json());
  }

  async set(path, data, { updateMask } = {}) {
    const query = new URLSearchParams();
    for (const field of updateMask ?? []) {
      query.append("updateMask.fieldPaths", field);
    }
    const suffix = query.size > 0 ? `?${query}` : "";
    const response = await fetch(
      `${this.root}/${encodeDocumentPath(path)}${suffix}`,
      {
        method: "PATCH",
        headers: {
          authorization: `Bearer ${this.accessToken}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({ fields: encodeFields(data) }),
      },
    );
    if (!response.ok) {
      throw new Error(
        `Firestore PATCH ${path} failed (${response.status}): ${await response.text()}`,
      );
    }
    return decodeDocument(await response.json());
  }

  async delete(path, { missingOk = true } = {}) {
    const response = await fetch(`${this.root}/${encodeDocumentPath(path)}`, {
      method: "DELETE",
      headers: { authorization: `Bearer ${this.accessToken}` },
    });
    if (response.ok || (missingOk && response.status === 404)) {
      return;
    }
    throw new Error(
      `Firestore DELETE ${path} failed (${response.status}): ${await response.text()}`,
    );
  }

  async commit(writes) {
    const response = await fetch(
      `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(this.projectId)}` +
        "/databases/(default)/documents:commit",
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${this.accessToken}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({ writes }),
      },
    );
    if (!response.ok) {
      throw new Error(
        `Firestore commit failed (${response.status}): ${await response.text()}`,
      );
    }
    return response.json();
  }

  async queryCollection(collectionId, { allDescendants = true } = {}) {
    const response = await fetch(`${this.root}:runQuery`, {
      method: "POST",
      headers: {
        authorization: `Bearer ${this.accessToken}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        structuredQuery: {
          from: [{ collectionId, allDescendants }],
          orderBy: [
            {
              field: { fieldPath: "__name__" },
              direction: "ASCENDING",
            },
          ],
        },
      }),
    });
    if (!response.ok) {
      throw new Error(
        `Firestore query ${collectionId} failed (${response.status}): ${await response.text()}`,
      );
    }
    return (await response.json())
      .filter((row) => row.document)
      .map((row) => decodeDocument(row.document));
  }
}

export function firestoreWrite(path, data, projectId, { exists } = {}) {
  return {
    update: {
      name:
        `projects/${projectId}/databases/(default)/documents/` +
        encodeDocumentPath(path),
      fields: encodeFields(data),
    },
    ...(exists === undefined
      ? {}
      : { currentDocument: { exists } }),
  };
}

export class StorageRest {
  constructor({
    bucket,
    accessToken = readGcloudAccessToken(),
  }) {
    this.bucket = bucket;
    this.accessToken = accessToken;
  }

  async upload(objectPath, bytes, { contentType = "application/octet-stream" } = {}) {
    const url =
      `https://storage.googleapis.com/upload/storage/v1/b/${encodeURIComponent(this.bucket)}` +
      `/o?uploadType=media&name=${encodeURIComponent(objectPath)}`;
    const response = await fetch(url, {
      method: "POST",
      headers: {
        authorization: `Bearer ${this.accessToken}`,
        "content-type": contentType,
        "content-length": String(bytes.length),
      },
      body: bytes,
    });
    if (!response.ok) {
      throw new Error(
        `Storage upload ${objectPath} failed (${response.status}): ${await response.text()}`,
      );
    }
    const body = await response.json();
    if (typeof body.generation !== "string") {
      throw new Error(`Storage upload ${objectPath} omitted generation.`);
    }
    return body;
  }

  async delete(objectPath, { generation } = {}) {
    const query = generation
      ? `?generation=${encodeURIComponent(generation)}`
      : "";
    const response = await fetch(
      `https://storage.googleapis.com/storage/v1/b/${encodeURIComponent(this.bucket)}` +
        `/o/${encodeURIComponent(objectPath)}${query}`,
      {
        method: "DELETE",
        headers: { authorization: `Bearer ${this.accessToken}` },
      },
    );
    if (response.ok || response.status === 404) {
      return;
    }
    throw new Error(
      `Storage delete ${objectPath} failed (${response.status}): ${await response.text()}`,
    );
  }

  async list(prefix) {
    const response = await fetch(
      `https://storage.googleapis.com/storage/v1/b/${encodeURIComponent(this.bucket)}` +
        `/o?prefix=${encodeURIComponent(prefix)}`,
      {
        headers: { authorization: `Bearer ${this.accessToken}` },
      },
    );
    if (!response.ok) {
      throw new Error(
        `Storage list ${prefix} failed (${response.status}): ${await response.text()}`,
      );
    }
    return (await response.json()).items ?? [];
  }
}

export async function invokePrivateService({
  baseUrl,
  path,
  data,
  identityToken,
}) {
  const response = await fetch(`${baseUrl.replace(/\/$/, "")}${path}`, {
    method: "POST",
    headers: {
      authorization: `Bearer ${identityToken}`,
      "content-type": "application/json",
    },
    body: JSON.stringify(data),
  });
  const text = await response.text();
  let body = {};
  try {
    body = text ? JSON.parse(text) : {};
  } catch {
    body = { unparsedBody: text.slice(0, 500) };
  }
  return { status: response.status, body };
}

function encodeDocumentPath(path) {
  return path
    .split("/")
    .map((segment) => encodeURIComponent(segment))
    .join("/");
}

function encodeFields(data) {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, encodeValue(value)]),
  );
}

function encodeValue(value) {
  if (value === null || value === undefined) {
    return { nullValue: null };
  }
  if (typeof value === "boolean") {
    return { booleanValue: value };
  }
  if (typeof value === "number") {
    if (!Number.isFinite(value)) {
      throw new Error("Firestore values must be finite.");
    }
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (typeof value === "string") {
    return { stringValue: value };
  }
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(encodeValue) } };
  }
  if (isObject(value)) {
    return { mapValue: { fields: encodeFields(value) } };
  }
  throw new Error(`Unsupported Firestore value type: ${typeof value}`);
}

function decodeDocument(document) {
  const segments = document.name.split("/");
  return {
    name: document.name,
    id: decodeURIComponent(segments.at(-1)),
    data: decodeFields(document.fields ?? {}),
    createTime: document.createTime ?? null,
    updateTime: document.updateTime ?? null,
  };
}

function decodeFields(fields) {
  return Object.fromEntries(
    Object.entries(fields).map(([key, value]) => [key, decodeValue(value)]),
  );
}

function decodeValue(value) {
  if ("nullValue" in value) return null;
  if ("booleanValue" in value) return value.booleanValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return value.doubleValue;
  if ("timestampValue" in value) return value.timestampValue;
  if ("stringValue" in value) return value.stringValue;
  if ("bytesValue" in value) return value.bytesValue;
  if ("referenceValue" in value) return value.referenceValue;
  if ("arrayValue" in value) {
    return (value.arrayValue.values ?? []).map(decodeValue);
  }
  if ("mapValue" in value) {
    return decodeFields(value.mapValue.fields ?? {});
  }
  return null;
}

async function readJson(response) {
  const text = await response.text();
  if (!text) {
    return {};
  }
  try {
    return JSON.parse(text);
  } catch {
    return { unparsedBody: text.slice(0, 500) };
  }
}

function safeBody(body) {
  return JSON.stringify(body).slice(0, 500);
}
