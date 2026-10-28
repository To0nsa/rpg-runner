import { readFile } from 'node:fs/promises';

/** Read only the three registered destinations; never infer a project from credentials. */
export async function loadEnvironments() {
  const registry = JSON.parse(await readFile(new URL('../release/environments.json', import.meta.url), 'utf8'));
  if (registry.schemaVersion !== 1) throw new Error('Unsupported environment registry.');
  const environments = ['dev', 'staging', 'prod'].map((name) => {
    const projectId = registry.environments?.[name]?.projectId;
    if (typeof projectId !== 'string' || !/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(projectId)) {
      throw new Error(`Missing or invalid project for ${name}.`);
    }
    return Object.freeze({ name, projectId });
  });
  if (new Set(environments.map(({ projectId }) => projectId)).size !== 3) {
    throw new Error('Messaging environments must use separate projects.');
  }
  return Object.freeze(environments);
}
