import { parseArgs } from 'node:util';
import { loadEnvironments } from './environments.mjs';
import { configureAdminCredentials } from './auth.mjs';

try {
  const { values } = parseArgs({ options: { port: { type: 'string', default: '8766' } } });
  const port = Number(values.port);
  if (!/^\d+$/.test(values.port) || !Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error('Port must be an integer between 1 and 65535.');
  }
  if (process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error('Clear FIRESTORE_EMULATOR_HOST before launching the environment console.');
  }
  const { account } = await configureAdminCredentials();
  // Choose the credential file before loading any Firebase SDK code.
  const { startConsole } = await import('./server.mjs');
  const { server, url } = await startConsole({ environments: await loadEnvironments(), port, operatorAccount: account });
  console.log(`Messaging account: ${account} (tool-specific login)`);
  console.log(`Message console: ${url}\nOpen this private local URL in your browser. Press Ctrl+C to stop.`);
  process.once('SIGINT', () => server.close());
  process.once('SIGTERM', () => server.close());
} catch (error) {
  console.error(error.code === 'EADDRINUSE' ? 'Port is in use. Stop the existing console or select --port <number>.' : error.message);
  process.exitCode = 1;
}
