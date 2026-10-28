import assert from 'node:assert/strict';
import { mkdtemp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { configureMessagingCredentials, messagingAuthPaths, messagingLoginCommand } from '../auth.mjs';

test('login isolates gcloud and ignores inherited identity overrides without modifying the parent', () => {
  const env = { APPDATA: join(tmpdir(), 'other-apps'), PATH: '/gcloud/bin',
    CLOUDSDK_CONFIG: '/shared/gcloud', CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT: 'another-account',
    CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE: '/shared/override.json', CLOUDSDK_CORE_PROJECT: 'another-project',
    GOOGLE_APPLICATION_CREDENTIALS: '/shared/adc.json', CLOUDSDK_PYTHON: '/python' };
  const before = { ...env };
  for (const platform of ['win32', 'linux']) {
    const login = messagingLoginCommand('operator@example.com', { env, platform, userHome: '/user' });
    assert.notEqual(login.env.CLOUDSDK_CONFIG, env.CLOUDSDK_CONFIG);
    assert.equal(login.env.CLOUDSDK_CONFIG, login.directory);
    assert.equal(login.env.CLOUDSDK_PYTHON, env.CLOUDSDK_PYTHON);
    assert.equal(login.env.PATH, env.PATH);
    assert.equal(login.env.RUNNER_MESSAGES_LOGIN_ACCOUNT, 'operator@example.com');
    for (const key of ['CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT', 'CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE',
      'CLOUDSDK_CORE_PROJECT', 'GOOGLE_APPLICATION_CREDENTIALS']) assert.equal(login.env[key], undefined);
    assert.equal(login.args.join(' ').includes('--disable-quota-project'), true);
    assert.equal(login.command, platform === 'win32' ? 'powershell.exe' : 'gcloud');
    if (platform === 'win32') assert.equal(login.args.join(' ').includes('operator@example.com'), false);
  }
  assert.deepEqual(env, before);
  for (const account of [undefined, '', '--help', 'operator@example.com; echo injected', 'a$(id)@example.com']) {
    assert.throws(() => messagingLoginCommand(account, { env, platform: 'win32' }), /explicit account email/);
  }
});

test('missing or invalid dedicated credentials fail closed; shared ADC bytes remain unchanged', async (t) => {
  const directory = await mkdtemp(join(tmpdir(), 'message-auth-'));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const sharedFile = join(directory, 'shared-adc.json');
  const shared = JSON.stringify({ type: 'authorized_user', account: 'other-app@example.com', refresh_token: 'shared-test-token' });
  await writeFile(sharedFile, shared);
  const env = { APPDATA: directory, GOOGLE_APPLICATION_CREDENTIALS: sharedFile };
  const options = { env, platform: 'win32' };
  await assert.rejects(configureMessagingCredentials(options), /needs its own login/);
  assert.equal(env.GOOGLE_APPLICATION_CREDENTIALS, sharedFile);

  const paths = messagingAuthPaths(options);
  await mkdir(paths.directory, { recursive: true });
  await writeFile(paths.credentialFile, 'null');
  await assert.rejects(configureMessagingCredentials(options), /login is incomplete/);
  await writeFile(paths.credentialFile, JSON.stringify({ type: 'service_account', private_key: 'test-private-data' }));
  await assert.rejects(configureMessagingCredentials(options), (error) => {
    assert.match(error.message, /login is incomplete/);
    assert.doesNotMatch(error.message, /test-private-data/);
    return true;
  });
  assert.equal(env.GOOGLE_APPLICATION_CREDENTIALS, sharedFile);
  await writeFile(paths.credentialFile, JSON.stringify({ type: 'authorized_user', account: 'operator@example.com',
    refresh_token: 'tool-test-token', client_id: 'test-client', client_secret: 'test-secret' }));
  const result = await configureMessagingCredentials(options);
  assert.deepEqual(result, { ...paths, account: 'operator@example.com' });
  assert.equal(env.GOOGLE_APPLICATION_CREDENTIALS, paths.credentialFile);
  assert.equal(await readFile(sharedFile, 'utf8'), shared);
});
