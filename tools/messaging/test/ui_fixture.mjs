import { loadEnvironments } from '../environments.mjs';
import { startConsole } from '../server.mjs';
import { fakeDelivery } from './fake_delivery.mjs';

// Separate test entry point: all sends stay in memory, with one lost response for retry-player.
const { server, url } = await startConsole({
  environments: await loadEnvironments(),
  port: 8767,
  deliver: fakeDelivery().deliver,
  offlineTest: true,
});
console.log(`OFFLINE TEST FIXTURE — sends stay in memory: ${url}`);
process.once('SIGINT', () => server.close());
process.once('SIGTERM', () => server.close());
