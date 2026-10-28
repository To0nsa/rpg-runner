import { parseArgs } from 'node:util';
import { stat } from 'node:fs/promises';
import { configureAdminCredentials } from './auth.mjs';
import { loadEnvironments } from './environments.mjs';

// Native parent owns this process through its stdin pipe. Credentials never enter Flutter.
try {
  const { values } = parseArgs({ options: { fixture: { type: 'boolean', default: false } } });
  if (process.env.FIRESTORE_EMULATOR_HOST && !values.fixture) throw new Error('Clear FIRESTORE_EMULATOR_HOST before starting Admin.');
  await stat(new URL('../../../functions/lib/inbox/gifts.js', import.meta.url)).catch(() => {
    throw new Error('Build the Admin service first: corepack pnpm --dir functions build');
  });
  const account = values.fixture ? 'offline-fixture@example.com' : (await configureAdminCredentials()).account;
  const { startConsole } = await import('./server.mjs');
  const fixture = values.fixture ? await import('./test/fake_delivery.mjs') : null;
  const { inboxGiftCatalog, inboxGiftCatalogHash } = await import('../../../functions/lib/inbox/gifts.js');
  const { knownCharacterIds } = await import('../../../functions/lib/ownership/defaults.js');
  const { server, origin, token } = await startConsole({
    environments: await loadEnvironments(), operatorAccount: account, offlineTest: values.fixture,
    ...(fixture ? { deliver: fixture.fakeDelivery().deliver,
      catalog: async () => ({ enabled: true, catalogHash: inboxGiftCatalogHash,
        entries: inboxGiftCatalog, characters: knownCharacterIds, message: null }) } : {}),
  });
  process.stdout.write(`${JSON.stringify({ protocol: 1, origin, token })}\n`);
  const stop = () => server.close();
  process.stdin.resume();
  process.stdin.once('end', stop);
  process.once('SIGINT', stop);
  process.once('SIGTERM', stop);
} catch (error) {
  process.stderr.write(`${error.message}\n`);
  process.exitCode = 1;
}
