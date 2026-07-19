import { CloudTasksClient } from "@google-cloud/tasks";
import type { Firestore } from "firebase-admin/firestore";

const runSessionsCollection = "run_sessions";

/**
 * Enqueues optional board projection after a validated run is durable.
 *
 * This is intentionally separate from settlement: Cloud Tasks retries a
 * leaderboard/ghost failure without replaying validation or touching gold.
 */
export async function enqueueAcceptedRunProjection(args: {
  db: Firestore;
  runSessionId: string;
  tasksClient?: CloudTasksClient;
  config?: RunProjectionTaskConfig;
}): Promise<"enqueued" | "ignored"> {
  const session = await args.db
    .collection(runSessionsCollection)
    .doc(args.runSessionId)
    .get();
  if (!session.exists) {
    return "ignored";
  }
  const data = session.data() as Record<string, unknown>;
  if (
    (data.mode !== "competitive" && data.mode !== "weekly") ||
    typeof data.boardId !== "string" ||
    data.boardId.trim().length === 0
  ) {
    return "ignored";
  }

  const config = args.config ?? readRunProjectionTaskConfig();
  const tasksClient = args.tasksClient ?? new CloudTasksClient();
  await enqueueProjectionTask({
    tasksClient,
    config,
    taskId: `projection-${sanitizeTaskId(args.runSessionId)}`,
    payload: { runSessionId: args.runSessionId },
  });
  return "enqueued";
}

/**
 * Enqueues one idempotent board-level convergence task.
 *
 * `taskKey` identifies the reconciliation cycle, allowing a failed cursor page
 * to replay without creating duplicate tasks in the same cycle.
 */
export async function enqueueBoardProjectionReconciliation(args: {
  boardId: string;
  taskKey: string;
  tasksClient?: CloudTasksClient;
  config?: RunProjectionTaskConfig;
}): Promise<void> {
  const boardId = args.boardId.trim();
  if (boardId.length === 0) {
    throw new Error("boardId is required for projection reconciliation.");
  }
  const config = args.config ?? readRunProjectionTaskConfig();
  const tasksClient = args.tasksClient ?? new CloudTasksClient();
  await enqueueProjectionTask({
    tasksClient,
    config,
    taskId:
      `projection-reconcile-${sanitizeTaskId(boardId)}-` +
      sanitizeTaskId(args.taskKey),
    payload: { boardId },
  });
}

async function enqueueProjectionTask(args: {
  tasksClient: CloudTasksClient;
  config: RunProjectionTaskConfig;
  taskId: string;
  payload: Record<string, string>;
}): Promise<void> {
  const queuePath = args.tasksClient.queuePath(
    args.config.projectId,
    args.config.location,
    args.config.queueName,
  );
  const taskName = args.tasksClient.taskPath(
    args.config.projectId,
    args.config.location,
    args.config.queueName,
    args.taskId.slice(0, 500),
  );
  try {
    await args.tasksClient.createTask({
      parent: queuePath,
      task: {
        name: taskName,
        httpRequest: {
          httpMethod: "POST",
          url: args.config.projectionTaskUrl,
          headers: { "Content-Type": "application/json" },
          body: Buffer.from(
            JSON.stringify(args.payload),
            "utf8",
          ).toString("base64"),
          oidcToken: {
            serviceAccountEmail: args.config.taskDispatchServiceAccount,
            audience: new URL(args.config.projectionTaskUrl).origin,
          },
        },
      },
    });
  } catch (error) {
    if (isTaskAlreadyExistsError(error)) {
      return;
    }
    throw error;
  }
}

export interface RunProjectionTaskConfig {
  projectId: string;
  location: string;
  queueName: string;
  projectionTaskUrl: string;
  taskDispatchServiceAccount: string;
}

function readRunProjectionTaskConfig(): RunProjectionTaskConfig {
  const projectId =
    process.env.GCLOUD_PROJECT?.trim() ??
    process.env.GOOGLE_CLOUD_PROJECT?.trim();
  if (!projectId) {
    throw new Error("GCLOUD_PROJECT is required to enqueue projection tasks.");
  }
  const validatorUrl = resolveValidatorBaseUrl();
  return {
    projectId,
    location:
      process.env.REPLAY_VALIDATION_QUEUE_LOCATION?.trim() || "europe-west1",
    queueName:
      process.env.REPLAY_PROJECTION_QUEUE_NAME?.trim() ||
      "replay-projection",
    projectionTaskUrl: `${validatorUrl}/tasks/project`,
    taskDispatchServiceAccount:
      process.env.REPLAY_TASK_DISPATCH_SERVICE_ACCOUNT?.trim() ||
      `sa-replay-task-dispatch@${projectId}.iam.gserviceaccount.com`,
  };
}

function resolveValidatorBaseUrl(): string {
  const configuredBase = process.env.REPLAY_VALIDATOR_URL?.trim();
  if (configuredBase) {
    return configuredBase.endsWith("/")
      ? configuredBase.slice(0, -1)
      : configuredBase;
  }
  const configuredTask = process.env.REPLAY_VALIDATOR_TASK_URL?.trim();
  if (configuredTask?.endsWith("/tasks/validate")) {
    return configuredTask.slice(0, -"/tasks/validate".length);
  }
  throw new Error(
    "REPLAY_VALIDATOR_URL or a /tasks/validate REPLAY_VALIDATOR_TASK_URL is required to enqueue projection tasks.",
  );
}

function sanitizeTaskId(value: string): string {
  return value.replace(/[^a-zA-Z0-9_-]/gu, "_");
}

function isTaskAlreadyExistsError(error: unknown): boolean {
  if (!error || typeof error !== "object") {
    return false;
  }
  const maybeCode = (error as { code?: unknown }).code;
  if (maybeCode === 6 || maybeCode === "6") {
    return true;
  }
  const maybeMessage = (error as { message?: unknown }).message;
  return (
    typeof maybeMessage === "string" &&
    maybeMessage.toLowerCase().includes("already exists")
  );
}
