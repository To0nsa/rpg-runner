// Uses the repository's Node/CDP headless-test pattern with a fresh browser profile.
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { startConsole } from '../server.mjs';
import { loadEnvironments } from '../environments.mjs';
import { fakeDelivery } from './fake_delivery.mjs';

const chrome = [process.env.CHROME_EXECUTABLE,
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
  '/usr/bin/google-chrome', '/usr/bin/chromium',
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
].find((path) => path && existsSync(path));
assert(chrome, 'Chrome is required; set CHROME_EXECUTABLE.');
const output = resolve(dirname(fileURLToPath(import.meta.url)), '../../../../build/admin-browser-smoke');
await mkdir(output, { recursive: true });
const profile = await mkdtemp(resolve(output, 'chrome-'));
const fake = fakeDelivery();
const consoleServer = await startConsole({ environments: await loadEnvironments(), deliver: fake.deliver,
  offlineTest: true, operatorAccount: 'test-operator@example.com' });
const errors = [];
const pending = new Map();
let browser;
let socket;
let sequence = 0;
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
async function until(label, check) {
  const deadline = Date.now() + 30_000;
  while (Date.now() < deadline) {
    assert.deepEqual(errors, [], `Browser error during ${label}`);
    if (await check()) return;
    await delay(100);
  }
  throw new Error(`Timed out: ${label}`);
}
function command(method, params = {}) {
  const id = ++sequence;
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => { pending.delete(id); reject(new Error(`CDP timeout: ${method}`)); }, 10_000);
    pending.set(id, { resolve: (value) => { clearTimeout(timer); resolve(value); },
      reject: (error) => { clearTimeout(timer); reject(error); } });
    socket.send(JSON.stringify({ id, method, params }));
  });
}
async function evaluate(expression) {
  const result = await command('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
  assert(!result.exceptionDetails, JSON.stringify(result.exceptionDetails));
  return result.result.value;
}
async function fill(id, value) {
  await evaluate(`(() => { const field = document.getElementById(${JSON.stringify(id)}); field.value = ${JSON.stringify(value)}; field.dispatchEvent(new Event('input', { bubbles: true })); })()`);
}
const click = (id) => evaluate(`document.getElementById(${JSON.stringify(id)}).click()`);
const status = () => evaluate(`document.getElementById('status').textContent`);

try {
  browser = spawn(chrome, ['--headless=new', '--no-first-run', '--no-default-browser-check',
    '--remote-debugging-port=0', `--user-data-dir=${profile}`, '--window-size=1280,1100', 'about:blank'],
  { windowsHide: true, stdio: 'ignore' });
  browser.on('error', (error) => errors.push(error.message));
  let port;
  await until('Chrome startup', async () => {
    try { port = (await readFile(resolve(profile, 'DevToolsActivePort'), 'utf8')).split('\n')[0]; return true; }
    catch { return false; }
  });
  const targets = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
  socket = new WebSocket(targets.find((target) => target.type === 'page').webSocketDebuggerUrl);
  socket.addEventListener('message', ({ data }) => {
    const event = JSON.parse(data);
    if (event.id) {
      const handler = pending.get(event.id);
      pending.delete(event.id);
      if (event.error) handler?.reject(new Error(JSON.stringify(event.error)));
      else handler?.resolve(event.result);
    }
    if (event.method === 'Runtime.exceptionThrown') errors.push(event.params.exceptionDetails.text);
    if (event.method === 'Page.javascriptDialogOpening') {
      command('Page.handleJavaScriptDialog', { accept: true }).catch((error) => errors.push(error.message));
    }
    if (event.method === 'Network.requestWillBeSent' && /^https?:/.test(event.params.request.url) &&
        !event.params.request.url.startsWith(consoleServer.origin + '/')) errors.push('Unexpected external request');
  });
  await new Promise((resolve, reject) => {
    socket.addEventListener('open', resolve, { once: true });
    socket.addEventListener('error', reject, { once: true });
  });
  await command('Runtime.enable');
  await command('Page.enable');
  await command('Network.enable');
  await command('Page.navigate', { url: consoleServer.url });
  await until('composer ready', async () => (await status()).includes('Choose an environment'));
  assert.equal(await evaluate(`document.getElementById('environment').value`), '');
  assert.equal(await evaluate(`document.getElementById('test-banner').hidden`), false);
  assert.equal(await evaluate(`document.getElementById('operator-account').textContent`), 'Messaging account: test-operator@example.com');
  assert.equal(await evaluate(`document.getElementById('operator-account').hidden`), false);
  await fill('environment', 'dev');
  await fill('uid', 'retry-player');
  await fill('title', '<script>alert(1)</script>');
  await fill('body', 'Thanks for playing.\nHere is your gold.');
  await fill('gold', '25');
  await click('preview-button');
  await until('preview', () => evaluate(`!document.getElementById('preview').hidden`));
  assert.equal(fake.delivered.size, 0);
  assert.equal(await evaluate(`document.getElementById('preview-title').textContent`), '<script>alert(1)</script>');
  assert.equal(await evaluate(`document.getElementById('preview-title').children.length`), 0);
  await fill('environment', 'prod');
  assert.equal(await evaluate(`document.getElementById('preview').hidden`), true);
  await click('preview-button');
  await until('production preview', () => evaluate(`document.getElementById('send-button').textContent === 'Send to production'`));
  await writeFile(resolve(output, 'preview.png'), Buffer.from((await command('Page.captureScreenshot', { format: 'png' })).data, 'base64'));
  await click('send-button');
  await until('uncertain response', async () => (await status()).includes('could not be confirmed'));
  assert.equal(fake.delivered.size, 1);
  assert.equal(await evaluate(`document.getElementById('fields').disabled`), true);
  const sourceId = await evaluate(`document.getElementById('source-id').textContent`);
  await command('Page.reload');
  await until('draft recovery', async () => (await status()).includes('Previous send attempted'));
  assert.equal(await evaluate(`document.getElementById('source-id').textContent`), sourceId);
  await click('preview-button');
  await until('retry preview', () => evaluate(`!document.getElementById('send-button').disabled`));
  await click('send-button');
  await until('confirmation', async () => (await status()).includes('Delivery confirmed'));
  assert.equal(fake.delivered.size, 1);
  assert.match([...fake.delivered.keys()][0], /^lothringen-long-run-prod:/);
  await command('Browser.setDownloadBehavior', { behavior: 'allow', downloadPath: output });
  const savedDraftPath = resolve(output, 'message-draft.json');
  await rm(savedDraftPath, { force: true });
  await click('export-button');
  await until('draft download', async () => {
    try { return JSON.parse(await readFile(savedDraftPath, 'utf8')).message.sourceId === sourceId; }
    catch { return false; }
  });
  // A failed local write must not replace the draft while leaving its old preview active.
  await evaluate(`window.originalSetItem = Storage.prototype.setItem; Storage.prototype.setItem = () => { throw new Error('Storage full'); };`);
  await click('new-button');
  await until('storage failure', async () => (await status()).includes('Unable to save'));
  assert.equal(await evaluate(`document.getElementById('source-id').textContent`), sourceId);
  await evaluate('Storage.prototype.setItem = window.originalSetItem');
  await click('new-button');
  await until('new draft', async () => (await status()).includes('New draft'));
  assert.notEqual(await evaluate(`document.getElementById('source-id').textContent`), sourceId);
  const { root } = await command('DOM.getDocument');
  const { nodeId } = await command('DOM.querySelector', { nodeId: root.nodeId, selector: '#import-file' });
  await command('DOM.setFileInputFiles', { nodeId, files: [savedDraftPath] });
  await until('restored draft', async () => (await status()).includes('Draft restored'));
  assert.equal(await evaluate(`document.getElementById('source-id').textContent`), sourceId);
  await click('preview-button');
  await until('restored preview', () => evaluate(`!document.getElementById('send-button').disabled`));
  await click('send-button');
  await until('restored confirmation', async () => (await status()).includes('Delivery confirmed'));
  assert.equal(fake.delivered.size, 1);
  const giftDraftPath = resolve(output, 'admin-gift-draft.json');
  const giftDraft = JSON.parse(await readFile(savedDraftPath, 'utf8'));
  giftDraft.message.attachments = [{ kind: 'gear', slot: 'mainWeapon', itemId: 'waspfang' }];
  await writeFile(giftDraftPath, JSON.stringify(giftDraft));
  await command('DOM.setFileInputFiles', { nodeId, files: [giftDraftPath] });
  await until('gift draft refusal', async () => (await status()).includes('Flutter Admin'));
  assert.equal(await evaluate(`document.getElementById('source-id').textContent`), sourceId);
  assert.equal(fake.delivered.size, 1);
  await command('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 1, mobile: true });
  assert.equal(await evaluate('document.documentElement.scrollWidth <= window.innerWidth'), true);
  await writeFile(resolve(output, 'mobile.png'), Buffer.from((await command('Page.captureScreenshot', { format: 'png', captureBeyondViewport: true })).data, 'base64'));
  assert.deepEqual(errors, []);
  await click('new-button');
  await fill('environment', 'staging');
  await fill('uid', 'missing-player');
  await fill('title', 'Information');
  await fill('body', 'Message without gold.');
  await click('preview-button');
  await until('information preview', () => evaluate(`!document.getElementById('send-button').disabled`));
  assert.equal(await evaluate(`document.getElementById('preview-gold').textContent`), 'Message only · no gold');
  await click('send-button');
  await until('missing player', async () => (await status()).includes('Player account not found'));
  assert.equal(fake.delivered.size, 1);
  assert.deepEqual(errors, []);
  console.log('PASS: environment selection, offline preview, escaped text, preview invalidation, production review, lost-response recovery, reload/retry, draft export/import, native gift draft refusal, storage failure, message-only preview, missing player, one delivery, mobile layout; no external browser requests.');
} finally {
  if (socket?.readyState === WebSocket.OPEN) {
    await command('Browser.close').catch(() => {});
    socket.close();
  }
  if (browser && browser.exitCode === null) {
    await Promise.race([new Promise((resolve) => browser.once('exit', resolve)), delay(3000)]);
    if (browser.exitCode === null) browser.kill();
  }
  consoleServer.server.closeAllConnections();
  await new Promise((resolve) => consoleServer.server.close(resolve));
  assert.equal(dirname(resolve(profile)), output);
  await rm(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
}
