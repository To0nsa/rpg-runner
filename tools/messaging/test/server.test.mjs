import assert from 'node:assert/strict';
import { request } from 'node:http';
import { test } from 'node:test';
import { startConsole } from '../server.mjs';
import { loadEnvironments } from '../environments.mjs';
import { parseOperatorMessage } from '../../../functions/lib/inbox/operator.js';

const message = { uid: 'test-player', sourceId: 'test-delivery', title: 'Hello', body: 'Your gift', goldAmount: 25 };

async function fixture(t, deliver) {
  const console = await startConsole({ environments: await loadEnvironments(), deliver });
  t.after(() => new Promise((resolve) => { console.server.close(resolve); console.server.closeAllConnections(); }));
  const call = async (path, body, headers = {}) => {
    const response = await fetch(console.origin + path, {
      method: body === undefined ? 'GET' : 'POST',
      headers: { Authorization: `Bearer ${console.token}`, 'Content-Type': 'application/json', ...headers },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    return { status: response.status, body: await response.json() };
  };
  return { ...console, call };
}

test('registry isolates all three projects and preview is offline', async (t) => {
  const f = await fixture(t, () => { throw new Error('Preview attempted a send'); });
  const environments = (await f.call('/api/environments')).body.environments;
  assert.deepEqual(environments.map((e) => e.name), ['dev', 'staging', 'prod']);
  assert.equal(new Set(environments.map((e) => e.projectId)).size, 3);
  for (const e of environments) {
    const preview = await f.call('/api/preview', { environment: e.name, message });
    assert.equal(preview.status, 200);
    assert.equal(preview.body.projectId, e.projectId);
    assert.equal(preview.body.goldAmount, 25);
  }
});

test('send uses the immutable preview and coalesces concurrent retries', async (t) => {
  const sends = [];
  const f = await fixture(t, async (projectId, input) => {
    sends.push({ projectId, input });
    await new Promise((resolve) => setTimeout(resolve, 20));
    return parseOperatorMessage(input).messageId;
  });
  const { body: preview } = await f.call('/api/preview', { environment: 'staging', message });
  const [a, b] = await Promise.all([f.call('/api/send', { previewId: preview.previewId }), f.call('/api/send', { previewId: preview.previewId })]);
  assert.equal(a.status, 200);
  assert.deepEqual(a, b);
  assert.deepEqual(sends, [{ projectId: preview.projectId, input: message }]);
  assert.equal((await f.call('/api/send', { previewId: preview.previewId, environment: 'prod' })).status, 400);
  assert.equal((await f.call('/api/send', { previewId: preview.previewId, message: { ...message, goldAmount: 999 } })).status, 400);
  assert.equal((await f.call('/api/send', { previewId: 'unreviewed' })).status, 410);
});

test('uncertain delivery can retry with exactly the same project and identity', async (t) => {
  const sends = [];
  const f = await fixture(t, async (projectId, input) => {
    sends.push({ projectId, input });
    if (sends.length === 1) throw new Error('credential secrets must not reach browser');
    return parseOperatorMessage(input).messageId;
  });
  const { body: preview } = await f.call('/api/preview', { environment: 'prod', message });
  const first = await f.call('/api/send', { previewId: preview.previewId });
  assert.equal(first.status, 502);
  assert.doesNotMatch(first.body.error, /secrets/);
  assert.equal((await f.call('/api/send', { previewId: preview.previewId })).status, 200);
  assert.deepEqual(sends[0], sends[1]);
});

test('invalid messages and unregistered destinations never send', async (t) => {
  const f = await fixture(t, () => { throw new Error('Unexpected delivery'); });
  for (const body of [
    { message }, { environment: 'production', message },
    { environment: 'dev', projectId: 'arbitrary-project', message },
    { environment: 'dev', message: { ...message, goldAmount: -1 } },
    { environment: 'dev', message: { ...message, rewards: ['item'] } },
    { environment: 'dev', message: { ...message, uid: 'a/b/c' } },
  ]) assert.equal((await f.call('/api/preview', body)).status, 400);
  const info = await f.call('/api/preview', { environment: 'dev', message: { ...message, goldAmount: 0 } });
  assert.equal(info.body.goldAmount, 0);
  const large = await f.call('/api/preview', { environment: 'dev', message: { ...message, body: 'a'.repeat(33 * 1024) } });
  assert.equal(large.status, 413);
});

test('local API rejects unauthenticated, cross-origin and rebound requests', async (t) => {
  const f = await fixture(t, () => { throw new Error('Unexpected delivery'); });
  assert.equal((await f.call('/api/environments', undefined, { Authorization: '' })).status, 403);
  assert.equal((await f.call('/api/environments', undefined, { Origin: 'https://evil.example' })).status, 403);
  assert.equal((await f.call('/api/environments', undefined, { 'Sec-Fetch-Site': 'cross-site' })).status, 403);
  const status = await new Promise((resolve, reject) => {
    const req = request(f.origin + '/api/environments', { headers: { Host: 'evil.example', Authorization: `Bearer ${f.token}` } }, (res) => {
      res.resume(); resolve(res.statusCode);
    });
    req.on('error', reject); req.end();
  });
  assert.equal(status, 403);
  const html = await fetch(f.origin);
  assert.match(html.headers.get('content-security-policy'), /frame-ancestors 'none'/);
  assert.doesNotMatch(await html.text(), new RegExp(f.token));
});
