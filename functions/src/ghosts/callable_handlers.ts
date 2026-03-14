import type { Firestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { HttpsError } from "firebase-functions/v2/https";

import { loadGhostManifest, type GhostManifestResult } from "./store.js";
import { parseGhostLoadManifestRequest } from "./validators.js";

interface CallableRequestAuthLike {
  uid?: string;
}

interface CallableRequestLike {
  auth?: CallableRequestAuthLike | null;
  data: unknown;
}

const defaultGhostDownloadUrlTtlMs = 15 * 60 * 1000;

export interface GhostDownloadUrlSigner {
  signDownloadUrl(args: {
    objectPath: string;
    expiresAtMs: number;
  }): Promise<string>;
}

class FirebaseStorageGhostDownloadUrlSigner implements GhostDownloadUrlSigner {
  constructor(private readonly bucketName: string) {}

  async signDownloadUrl(args: {
    objectPath: string;
    expiresAtMs: number;
  }): Promise<string> {
    const [downloadUrl] = await getStorage()
      .bucket(this.bucketName)
      .file(args.objectPath)
      .getSignedUrl({
        version: "v4",
        action: "read",
        expires: args.expiresAtMs,
      });
    return downloadUrl;
  }
}

function createDefaultGhostDownloadUrlSigner(): GhostDownloadUrlSigner {
  const bucketName = process.env.REPLAY_STORAGE_BUCKET?.trim();
  if (!bucketName) {
    throw new HttpsError(
      "failed-precondition",
      "REPLAY_STORAGE_BUCKET must be configured for ghost downloads.",
    );
  }
  return new FirebaseStorageGhostDownloadUrlSigner(bucketName);
}

export async function handleGhostLoadManifest(
  request: CallableRequestLike,
  db: Firestore,
  downloadUrlSigner: GhostDownloadUrlSigner = createDefaultGhostDownloadUrlSigner(),
): Promise<{ ghostManifest: GhostManifestResult & {
  downloadUrl: string;
  downloadUrlExpiresAtMs: number;
} }> {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { userId, boardId, entryId } = parseGhostLoadManifestRequest(request.data);
  if (userId !== uid) {
    throw new HttpsError("permission-denied", "userId does not match auth uid.");
  }
  const ghostManifest = await loadGhostManifest({
    db,
    boardId,
    entryId,
  });
  if (!ghostManifest.replayStorageRef.startsWith("ghosts/")) {
    throw new HttpsError(
      "failed-precondition",
      "ghost manifest replay path must be under ghosts/.",
    );
  }
  const downloadUrlExpiresAtMs = Date.now() + defaultGhostDownloadUrlTtlMs;
  const downloadUrl = await downloadUrlSigner.signDownloadUrl({
    objectPath: ghostManifest.replayStorageRef,
    expiresAtMs: downloadUrlExpiresAtMs,
  });
  return {
    ghostManifest: {
      ...ghostManifest,
      downloadUrl,
      downloadUrlExpiresAtMs,
    },
  };
}
