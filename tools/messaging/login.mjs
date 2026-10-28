import { spawn } from 'node:child_process';
import { mkdir } from 'node:fs/promises';
import { parseArgs } from 'node:util';
import { configureMessagingCredentials, messagingLoginCommand } from './auth.mjs';

try {
  const { values } = parseArgs({ options: { account: { type: 'string' } } });
  const login = messagingLoginCommand(values.account);
  await mkdir(login.directory, { recursive: true, mode: 0o700 });
  console.log(`Sign in as ${values.account} for the messaging tool.\nCredentials stay in ${login.directory}.\nYour shared Google login and default application credentials are unchanged.`);
  const code = await new Promise((resolve, reject) => {
    const child = spawn(login.command, login.args, { env: login.env, stdio: 'inherit', windowsHide: true });
    child.once('error', () => reject(new Error('Could not start gcloud. Install the Google Cloud CLI and ensure it is on PATH.')));
    child.once('exit', (status) => resolve(status ?? 1));
  });
  if (code !== 0) throw new Error('Messaging sign-in did not complete. Run the same login command again.');
  const credentials = await configureMessagingCredentials();
  if (credentials.account !== values.account) throw new Error('The saved messaging account does not match the requested email. Sign in again.');
  console.log(`Messaging login saved for ${credentials.account}. Start or restart with corepack pnpm messages.`);
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
