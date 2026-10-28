import { readFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { join } from 'node:path';

const loginHelp = 'Run corepack pnpm messages:login --account <your-authorized-email> from the repository root.';
const accountPattern = /^[A-Za-z0-9._+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$/;

/** Per-user storage outside the repository and the shared gcloud credential directory. */
export function messagingAuthPaths({ env = process.env, platform = process.platform, userHome = homedir() } = {}) {
  const base = platform === 'win32' ? env.APPDATA : join(userHome, '.config');
  if (!base) throw new Error('APPDATA is required to locate the private messaging login.');
  const directory = join(base, 'Lothringen', 'messaging', 'gcloud');
  return { directory, credentialFile: join(directory, 'application_default_credentials.json') };
}

/** Build a child-only login environment; inherited cloud account overrides cannot select another identity. */
export function messagingLoginCommand(account, options = {}) {
  if (typeof account !== 'string' || !accountPattern.test(account)) {
    throw new Error(`An explicit account email is required. ${loginHelp}`);
  }
  const { env = process.env, platform = process.platform } = options;
  const paths = messagingAuthPaths(options);
  const childEnv = Object.fromEntries(Object.entries(env).filter(([key]) =>
    !key.toUpperCase().startsWith('CLOUDSDK_') && key.toUpperCase() !== 'GOOGLE_APPLICATION_CREDENTIALS'));
  // Preserve interpreter selection where gcloud was installed without its bundled Python.
  if (env.CLOUDSDK_PYTHON) childEnv.CLOUDSDK_PYTHON = env.CLOUDSDK_PYTHON;
  childEnv.CLOUDSDK_CONFIG = paths.directory;
  childEnv.RUNNER_MESSAGES_LOGIN_ACCOUNT = account;
  const args = ['auth', 'application-default', 'login', account, '--disable-quota-project'];
  return {
    ...paths,
    command: platform === 'win32' ? 'powershell.exe' : 'gcloud',
    // Pass the email as data: never interpolate it into a shell command.
    args: platform === 'win32' ? ['-NoProfile', '-NonInteractive', '-Command',
      '& gcloud auth application-default login $env:RUNNER_MESSAGES_LOGIN_ACCOUNT --disable-quota-project; exit $LASTEXITCODE'] : args,
    env: childEnv,
  };
}

/** Select only the console's dedicated user credentials; never fall back to the machine's ADC. */
export async function configureMessagingCredentials(options = {}) {
  const { env = process.env } = options;
  const paths = messagingAuthPaths(options);
  let credentials;
  try { credentials = JSON.parse(await readFile(paths.credentialFile, 'utf8')); }
  catch { throw new Error(`The messaging tool needs its own login. ${loginHelp}`); }
  if (credentials?.type !== 'authorized_user' || typeof credentials.account !== 'string' ||
      !accountPattern.test(credentials.account) ||
      ['refresh_token', 'client_id', 'client_secret'].some((key) => typeof credentials[key] !== 'string' || !credentials[key])) {
    throw new Error(`The messaging login is incomplete. ${loginHelp}`);
  }
  env.GOOGLE_APPLICATION_CREDENTIALS = paths.credentialFile;
  return { ...paths, account: credentials.account };
}
