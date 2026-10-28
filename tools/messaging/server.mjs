import { randomBytes, randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import { parseOperatorMessage, sendOperatorMessage } from '../../functions/lib/inbox/operator.js';

const assets = new Map([
  ['/', ['index.html', 'text/html; charset=utf-8']],
  ['/app.js', ['app.js', 'text/javascript; charset=utf-8']],
  ['/style.css', ['style.css', 'text/css; charset=utf-8']],
]);
// Preview lifetime is 30 minutes; drafts retain their delivery identity after expiry/restart.
const previewLifetimeMs = 30 * 60 * 1000;
const maxPreviews = 128;

class ConsoleRequestError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

function fail(status, message) {
  return new ConsoleRequestError(status, message);
}

function fields(value, allowed) {
  if (!value || typeof value !== 'object' || Array.isArray(value) ||
      Object.keys(value).some((key) => !allowed.includes(key))) {
    throw fail(400, 'Unsupported request fields.');
  }
}

async function readJson(request) {
  if (request.headers['content-type'] !== 'application/json') throw fail(415, 'Use application/json.');
  let size = 0;
  const chunks = [];
  for await (const chunk of request) {
    size += chunk.length;
    if (size > 32 * 1024) throw fail(413, 'Message request is too large.');
    chunks.push(chunk);
  }
  try { return JSON.parse(Buffer.concat(chunks).toString('utf8')); }
  catch { throw fail(400, 'Invalid JSON.'); }
}

function publicError(error) {
  if (error instanceof ConsoleRequestError) return { status: error.status, message: error.message };
  if (error.code === 7 || error.code === 'permission-denied') {
    return { status: 403, message: 'Firestore denied access to the selected project. The tool uses Application Default Credentials (ADC), which can belong to a different account than your gcloud login. Run gcloud auth application-default login with an authorized account, restart the console, then retry this same delivery.' };
  }
  if (error.code === 16 || error.code === 'unauthenticated' || error.code === 'app/invalid-credential') {
    return { status: 401, message: 'The tool could not authenticate with Application Default Credentials (ADC). Run gcloud auth application-default login with an authorized account, restart the console, then retry this same delivery.' };
  }
  const domainStatus = { 'invalid-argument': 400, 'not-found': 404,
    'already-exists': 409, 'failed-precondition': 409 }[error.code];
  if (domainStatus) return { status: domainStatus, message: error.message };
  return { status: 502, message: 'Delivery could not be confirmed. Check local operator credentials, project access and connectivity, then retry this same delivery.' };
}

/** Local privileged console. The injected delivery adapter is for offline tests only. */
export async function startConsole({ environments, port = 0, deliver = sendOperatorMessage, offlineTest = false }) {
  const token = randomBytes(32).toString('hex');
  const previews = new Map();
  let origin;
  const server = createServer({ requestTimeout: 15_000, headersTimeout: 10_000 }, async (request, response) => {
    response.setHeader('Cache-Control', 'no-store');
    response.setHeader('X-Content-Type-Options', 'nosniff');
    response.setHeader('Referrer-Policy', 'no-referrer');
    response.setHeader('Content-Security-Policy', "default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'");
    const json = (status, body) => {
      response.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
      response.end(JSON.stringify(body));
    };
    try {
      // Exact Host and Origin checks also reject DNS rebinding and cross-site form submissions.
      if (request.headers.host !== new URL(origin).host ||
          (request.headers.origin && request.headers.origin !== origin) ||
          request.headers['sec-fetch-site'] === 'cross-site') throw fail(403, 'Local access only.');
      const asset = assets.get(request.url);
      if (request.method === 'GET' && asset) {
        const body = await readFile(new URL(`./public/${asset[0]}`, import.meta.url));
        response.writeHead(200, { 'Content-Type': asset[1] });
        response.end(body);
        return;
      }
      if (request.headers.authorization !== `Bearer ${token}`) throw fail(403, 'Open the console using the URL printed by the launcher.');
      if (request.method === 'GET' && request.url === '/api/environments') {
        json(200, { environments, offlineTest });
        return;
      }
      if (request.method !== 'POST') throw fail(404, 'Unknown console endpoint.');
      const body = await readJson(request);
      if (request.url === '/api/preview') {
        fields(body, ['environment', 'message']);
        const environment = environments.find(({ name }) => name === body.environment);
        if (!environment) throw fail(400, 'Select dev, staging or prod.');
        const { uid, delivery, messageId } = parseOperatorMessage(body.message);
        const message = Object.freeze({ uid, sourceId: delivery.sourceId.slice('operator:'.length),
          title: delivery.title, body: delivery.body, goldAmount: delivery.goldAmount });
        const previewId = randomUUID();
        const preview = Object.freeze({ previewId, environment: environment.name,
          projectId: environment.projectId, messageId, ...message });
        for (const [id, entry] of previews) {
          if (!entry.pending && entry.expiresAt < Date.now()) previews.delete(id);
        }
        if (previews.size >= maxPreviews) throw fail(429, 'Too many previews. Restart the console or wait for old previews to expire.');
        previews.set(previewId, { preview, message, expiresAt: Date.now() + previewLifetimeMs });
        json(200, preview);
        return;
      }
      if (request.url === '/api/send') {
        fields(body, ['previewId']);
        const entry = previews.get(body.previewId);
        if (!entry || (!entry.pending && entry.expiresAt < Date.now())) {
          throw fail(410, 'Preview expired. Preview the same draft again before retrying.');
        }
        // Send only the server-held preview. Concurrent/repeated requests share its result.
        if (entry.receipt) {
          json(200, entry.receipt);
          return;
        }
        entry.pending ??= Promise.resolve().then(async () => {
          const messageId = await deliver(entry.preview.projectId, entry.message);
          if (messageId !== entry.preview.messageId) throw new Error('Delivery identity mismatch.');
          entry.receipt = { ...entry.preview, status: 'delivered', confirmedAt: new Date().toISOString() };
          return entry.receipt;
        }).finally(() => { entry.pending = undefined; });
        json(200, await entry.pending);
        return;
      }
      throw fail(404, 'Unknown console endpoint.');
    } catch (error) {
      const result = publicError(error);
      if (!response.destroyed) json(result.status, { error: result.message });
    }
  });
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(port, '127.0.0.1', resolve);
  });
  origin = `http://127.0.0.1:${server.address().port}`;
  return { server, origin, token, url: `${origin}/#${token}` };
}
