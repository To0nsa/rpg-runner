// Checks the built release app, including compiler-mode guards, in a fresh
// headless Chrome profile. Uses Node's CDP/WebSocket support without npm deps.
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { createReadStream, existsSync } from 'node:fs';
import { mkdir, mkdtemp, readFile, rm, stat } from 'node:fs/promises';
import { dirname, extname, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const build = resolve(root, process.argv[2] ?? 'build/web');
assert(existsSync(resolve(build, 'main.dart.js')), 'Build the release web app first.');
const chrome = [
  process.env.CHROME_EXECUTABLE,
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
  '/usr/bin/google-chrome', '/usr/bin/chromium', '/usr/bin/chromium-browser',
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
].find(path => path && existsSync(path));
assert(chrome, 'Chrome is required; set CHROME_EXECUTABLE to its executable.');
const tempRoot = resolve(root, '.tmp');
await mkdir(tempRoot, { recursive: true });
const profile = await mkdtemp(resolve(tempRoot, 'web-smoke-'));
const mime = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.wasm': 'application/wasm', '.json': 'application/json', '.png': 'image/png',
  '.ttf': 'font/ttf', '.otf': 'font/otf',
};
const server = createServer(async (request, response) => {
  try {
    const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    const file = resolve(build, `.${pathname === '/' ? '/index.html' : pathname}`);
    if (!file.startsWith(build + sep) || !(await stat(file)).isFile()) {
      response.writeHead(404).end();
      return;
    }
    response.writeHead(200, { 'Content-Type': mime[extname(file)] ?? 'application/octet-stream' });
    createReadStream(file).pipe(response);
  } catch {
    response.writeHead(404).end();
  }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const url = `http://127.0.0.1:${server.address().port}/`;
let browser;
let socket;
const exceptions = [];
const backendRequests = [];
const pending = new Map();
let sequence = 0;
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function until(label, check, timeout = 60000) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    assert.equal(exceptions.length, 0, `Browser exception: ${exceptions.join('\n')}`);
    assert.equal(backendRequests.length, 0, `Unexpected backend requests: ${backendRequests.join('\n')}`);
    const result = await check();
    if (result) return result;
    await delay(100);
  }
  throw new Error(`Timed out: ${label}`);
}
function command(method, params = {}) {
  const id = ++sequence;
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => { pending.delete(id); reject(new Error(`CDP timeout: ${method}`)); }, 10000);
    pending.set(id, {
      resolve: result => { clearTimeout(timer); resolve(result); },
      reject: error => { clearTimeout(timer); reject(error); },
    });
    socket.send(JSON.stringify({ id, method, params }));
  });
}
async function evaluate(expression) {
  const result = await command('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
  assert(!result.exceptionDetails, JSON.stringify(result.exceptionDetails));
  return result.result.value;
}
const textExpression = `(() => {
  const host = document.querySelector('flt-semantics-host');
  if (!host) return '';
  return [host.innerText, ...[...host.querySelectorAll('[aria-label]')]
    .map(node => node.getAttribute('aria-label'))].join('\\n');
})()`;
async function hasText(text) {
  return (await evaluate(textExpression)).includes(text);
}
async function click(label) {
  await until(`button ${label}`, () => evaluate(`(() => {
    const label = ${JSON.stringify(label)};
    const nodes = [...document.querySelectorAll('flt-semantics[role="button"]')];
    const node = nodes.find(n => n.getAttribute('aria-label') === label || n.textContent.trim() === label);
    if (!node || node.getAttribute('aria-disabled') === 'true') return false;
    node.click(); return true;
  })()`));
}

try {
  browser = spawn(chrome, [
    '--headless', '--disable-gpu', '--no-sandbox', '--no-first-run',
    '--no-default-browser-check', '--disable-search-engine-choice-screen',
    '--disable-background-timer-throttling', '--window-size=1280,720',
    '--remote-debugging-port=0', `--user-data-dir=${profile}`, 'about:blank',
  ], { windowsHide: true, stdio: 'ignore' });
  browser.on('error', error => exceptions.push(error.message));
  const port = await until('Chrome debugging port', async () => {
    try { return (await readFile(resolve(profile, 'DevToolsActivePort'), 'utf8')).split('\n')[0]; }
    catch { return null; }
  }, 30000);
  const targets = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
  socket = new WebSocket(targets.find(target => target.type === 'page').webSocketDebuggerUrl);
  socket.addEventListener('message', event => {
    const message = JSON.parse(event.data);
    if (message.id) {
      const callback = pending.get(message.id);
      pending.delete(message.id);
      if (message.error) callback?.reject(new Error(JSON.stringify(message.error)));
      else callback?.resolve(message.result);
    }
    if (message.method === 'Runtime.exceptionThrown') {
      exceptions.push(message.params.exceptionDetails.exception?.description ?? message.params.exceptionDetails.text);
    }
    if (message.method === 'Network.requestWillBeSent') {
      const requestUrl = message.params.request.url;
      if (/firebase|firestore|identitytoolkit|securetoken|cloudfunctions|\.run\.app|storage\.googleapis/i.test(requestUrl)) {
        backendRequests.push(requestUrl);
      }
    }
  });
  await new Promise((resolve, reject) => {
    socket.addEventListener('open', resolve, { once: true });
    socket.addEventListener('error', reject, { once: true });
  });
  await command('Runtime.enable');
  await command('Network.enable');
  await command('Page.enable');
  await command('Page.navigate', { url });
  await until('Flutter accessibility activation', () => evaluate(`(() => {
    const placeholder = document.querySelector('flt-semantics-placeholder');
    if (!placeholder) return false;
    placeholder.click(); return true;
  })()`));
  await until('Developer Practice hub', () => hasText('DEVELOPER MODE'));
  console.log('PASS: release web starts in the Developer Practice hub.');
  await click('Options');
  await until('Practice-only Options', () => hasText('Account features are unavailable'));
  assert.equal(await evaluate(`document.querySelectorAll('flt-semantics[role="switch"]').length`), 0);
  console.log('PASS: browser Options has no online profile switch.');
  await click('Back');
  await until('hub return', () => hasText('DEVELOPER MODE'));
  await click('PLAY');
  await until('local run readiness', () => hasText('Click or press Enter to start'), 120000);
  await command('Input.dispatchKeyEvent', { type: 'keyDown', key: 'Enter', code: 'Enter', windowsVirtualKeyCode: 13 });
  await command('Input.dispatchKeyEvent', { type: 'keyUp', key: 'Enter', code: 'Enter', windowsVirtualKeyCode: 13 });
  await until('run start', async () => !(await hasText('Click or press Enter to start')));
  await until('live simulation timer', async () => /\b00:0[1-9]\b/.test(await evaluate(textExpression)), 30000);
  await click('Exit game');
  await until('run exit confirmation', () => hasText('Want to exit?'));
  await click('Exit');
  await until('local Practice game-over', () => hasText('No rewards or leaderboard entries.'));
  assert.equal(exceptions.length, 0, exceptions.join('\n'));
  assert.equal(backendRequests.length, 0, backendRequests.join('\n'));
  console.log('PASS: release web hub, Practice-only Options, local run readiness/start/game-over; no browser exceptions or backend requests.');
} catch (error) {
  if (socket?.readyState === WebSocket.OPEN) {
    console.error('Browser semantics:', await evaluate(textExpression).catch(() => '<unavailable>'));
  }
  throw error;
} finally {
  if (socket?.readyState === WebSocket.OPEN) {
    await command('Browser.close').catch(() => {});
    socket.close();
  }
  if (browser && browser.exitCode === null) {
    await Promise.race([new Promise(resolve => browser.once('exit', resolve)), delay(3000)]);
    if (browser.exitCode === null) browser.kill();
  }
  server.closeAllConnections();
  await new Promise(resolve => server.close(resolve));
  assert.equal(dirname(resolve(profile)), tempRoot);
  await rm(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
}
