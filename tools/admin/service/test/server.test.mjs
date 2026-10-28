import assert from 'node:assert/strict';
import { request } from 'node:http';
import { test } from 'node:test';
import { startConsole } from '../server.mjs';
import { loadEnvironments } from '../environments.mjs';
import { parseOperatorMessage } from '../../../../functions/lib/inbox/operator.js';

const message = { uid: 'test-player', sourceId: 'test-delivery', title: 'Hello', body: 'Your gift', goldAmount: 25 };

test('offline service cannot fall through to real catalog reads or real delivery', async (t) => {
  const environments = await loadEnvironments();
  await assert.rejects(startConsole({ environments, offlineTest: true }), /fixture delivery/);
  const local = await startConsole({ environments, offlineTest: true, deliver: async () => 'unused' });
  t.after(() => new Promise((resolve) => { local.server.close(resolve); local.server.closeAllConnections(); }));
  const response = await fetch(local.origin + '/api/catalog', { method: 'POST',
    headers: { Authorization: `Bearer ${local.token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ environment: 'dev' }) });
  assert.equal(response.status, 200);
  assert.equal((await response.json()).enabled, false);
});

async function fixture(t, deliver, catalog) {
  const console = await startConsole({ environments: await loadEnvironments(), deliver, catalog });
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

test('credential errors explain tool login recovery without leaking provider details and retain retry identity', async (t) => {
  for (const [code, expectedStatus] of [[7, 403], ['permission-denied', 403], [16, 401], ['unauthenticated', 401], ['app/invalid-credential', 401]]) {
    const sends = [];
    const f = await fixture(t, async (projectId, input) => {
      sends.push({ projectId, input });
      if (sends.length === 1) throw Object.assign(new Error('private provider credential details'), { code, status: 502 });
      return parseOperatorMessage(input).messageId;
    });
    const { body: preview } = await f.call('/api/preview', { environment: 'dev', message });
    const failure = await f.call('/api/send', { previewId: preview.previewId });
    assert.equal(failure.status, expectedStatus);
    assert.match(failure.body.error, /corepack pnpm admin:login --account/);
    assert.doesNotMatch(failure.body.error, /gcloud auth application-default login/);
    assert.doesNotMatch(failure.body.error, /private provider/);
    assert.equal((await f.call('/api/send', { previewId: preview.previewId })).status, 200);
    assert.deepEqual(sends[0], sends[1]);
  }
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


test('catalog is bound to a registered project and does not send or enable gifts', async (t) => {
  const reads = [];
  const f = await fixture(t, () => { throw new Error('Unexpected send'); }, async (projectId) => {
    reads.push(projectId); return { enabled: false, entries: [], characters: ['eloise'] };
  });
  const environments = (await f.call('/api/environments')).body.environments;
  const result = await f.call('/api/catalog', { environment: 'staging' });
  assert.equal(result.status, 200);
  assert.equal(result.body.projectId, environments[1].projectId);
  assert.deepEqual(reads, [environments[1].projectId]);
  assert.equal(result.body.enabled, false);
  assert.equal((await f.call('/api/catalog', { environment: 'dev', projectId: 'arbitrary' })).status, 400);
});

test('typed gift previews freeze nested attachments and reject caller edits on send', async (t) => {
  const attachment = { kind: 'ability', slot: 'spell', itemId: 'eloise.arcane_ward', characterId: 'eloiseWip' };
  const f = await fixture(t, async (projectId, input) => {
    assert.ok(Object.isFrozen(input.attachments));
    assert.ok(Object.isFrozen(input.attachments[0]));
    assert.deepEqual(input.attachments, [attachment]);
    return parseOperatorMessage(input).messageId;
  });
  const { body: preview } = await f.call('/api/preview', { environment: 'dev', message: { ...message, attachments: [attachment] } });
  assert.deepEqual(preview.attachments, [attachment]);
  assert.equal((await f.call('/api/send', { previewId: preview.previewId, attachments: [] })).status, 400);
  const sent = await f.call('/api/send', { previewId: preview.previewId });
  assert.equal(sent.status, 200);
  assert.deepEqual(sent.body.attachments, [attachment]);
});
