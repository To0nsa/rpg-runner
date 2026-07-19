import { HttpsError } from "firebase-functions/v2/https";

export interface CallablePayloadBounds {
  maxSerializedBytes: number;
  maxDepth: number;
  maxStringLength: number;
  maxArrayLength: number;
  maxObjectKeys: number;
  maxObjectKeyLength: number;
  maxNodes: number;
}

export const defaultCallablePayloadBounds: Readonly<CallablePayloadBounds> = {
  maxSerializedBytes: 32 * 1024,
  maxDepth: 8,
  maxStringLength: 2_048,
  maxArrayLength: 128,
  maxObjectKeys: 64,
  maxObjectKeyLength: 128,
  maxNodes: 512,
};

export function assertCallablePayloadBounds(
  value: unknown,
  bounds: CallablePayloadBounds = defaultCallablePayloadBounds,
): void {
  validateBounds(bounds);
  const visited = new Set<object>();
  const state = { nodes: 0 };
  visitJsonValue(value, "request", 0, bounds, state, visited);

  let serialized: string;
  try {
    serialized = JSON.stringify(value);
  } catch {
    throw invalidPayload("request must be JSON-serializable.");
  }
  if (serialized === undefined) {
    throw invalidPayload("request must be a JSON value.");
  }
  const serializedBytes = Buffer.byteLength(serialized, "utf8");
  if (serializedBytes > bounds.maxSerializedBytes) {
    throw invalidPayload(
      `request exceeds ${bounds.maxSerializedBytes} serialized bytes.`,
    );
  }
}

function visitJsonValue(
  value: unknown,
  path: string,
  depth: number,
  bounds: CallablePayloadBounds,
  state: { nodes: number },
  visited: Set<object>,
): void {
  state.nodes += 1;
  if (state.nodes > bounds.maxNodes) {
    throw invalidPayload(`request exceeds ${bounds.maxNodes} JSON nodes.`);
  }
  if (depth > bounds.maxDepth) {
    throw invalidPayload(`request exceeds maximum depth ${bounds.maxDepth}.`);
  }

  if (
    value === null ||
    typeof value === "boolean" ||
    (typeof value === "number" && Number.isFinite(value))
  ) {
    return;
  }
  if (typeof value === "string") {
    if (value.length > bounds.maxStringLength) {
      throw invalidPayload(
        `${path} exceeds ${bounds.maxStringLength} characters.`,
      );
    }
    return;
  }
  if (typeof value !== "object") {
    throw invalidPayload(`${path} contains a non-JSON value.`);
  }
  if (visited.has(value)) {
    throw invalidPayload(`${path} contains a cyclic reference.`);
  }
  visited.add(value);
  try {
    if (Array.isArray(value)) {
      if (value.length > bounds.maxArrayLength) {
        throw invalidPayload(
          `${path} exceeds ${bounds.maxArrayLength} array entries.`,
        );
      }
      for (let index = 0; index < value.length; index += 1) {
        visitJsonValue(
          value[index],
          `${path}[${index}]`,
          depth + 1,
          bounds,
          state,
          visited,
        );
      }
      return;
    }

    const entries = Object.entries(value as Record<string, unknown>);
    if (entries.length > bounds.maxObjectKeys) {
      throw invalidPayload(
        `${path} exceeds ${bounds.maxObjectKeys} object fields.`,
      );
    }
    for (const [key, child] of entries) {
      if (key.length > bounds.maxObjectKeyLength) {
        throw invalidPayload(
          `${path} contains a field name longer than ` +
            `${bounds.maxObjectKeyLength} characters.`,
        );
      }
      visitJsonValue(
        child,
        `${path}.${key}`,
        depth + 1,
        bounds,
        state,
        visited,
      );
    }
  } finally {
    visited.delete(value);
  }
}

function validateBounds(bounds: CallablePayloadBounds): void {
  for (const [name, value] of Object.entries(bounds)) {
    if (!Number.isSafeInteger(value) || value <= 0) {
      throw new Error(`Callable payload bound ${name} must be a positive integer.`);
    }
  }
}

function invalidPayload(message: string): HttpsError {
  return new HttpsError("invalid-argument", message);
}
