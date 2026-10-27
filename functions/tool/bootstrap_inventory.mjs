#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

const args = process.argv.slice(2);
if (args.length !== 2 || args[0] !== "--project" ||
    !/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(args[1])) {
  throw new Error("Usage: bootstrap_inventory.mjs --project <project-id>");
}
const projectId = args[1];
// End-user Cloud SDK credentials need an explicit, matching quota project.
process.env.GOOGLE_CLOUD_QUOTA_PROJECT = projectId;
const token = execFileSync(process.platform === "win32" ? "powershell.exe" : "gcloud",
  process.platform === "win32" ? ["-NoProfile", "-Command", "gcloud auth print-access-token"] :
    ["auth", "print-access-token"], { encoding: "utf8", windowsHide: true }).trim();
const app = initializeApp({ projectId, credential: {
  getAccessToken: async () => ({ access_token: token, expires_in: 300 }),
} });
try {
  // Only existence is needed; do not persist user records or credential fields.
  const users = await getAuth(app).listUsers(1);
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:listCollectionIds`,
    { method: "POST", headers: {
      authorization: `Bearer ${token}`, "content-type": "application/json",
      "x-goog-user-project": projectId,
    }, body: JSON.stringify({ pageSize: 1 }) },
  );
  if (!response.ok) { throw new Error(`Bootstrap Firestore inventory failed (${response.status}).`); }
  const collections = await response.json();
  console.log(JSON.stringify({
    projectId, readOnly: true, observedAt: new Date().toISOString(),
    hasAuthUsers: users.users.length > 0 || Boolean(users.pageToken),
    hasFirestoreCollections: (collections.collectionIds?.length ?? 0) > 0 || Boolean(collections.nextPageToken),
  }));
} catch (error) {
  // Admin SDK errors can contain full request objects. Surface only their code.
  console.error(`Bootstrap inventory failed: ${error.code ?? error.name ?? "unknown"}`);
  process.exitCode = 1;
} finally { await deleteApp(app); }
