import { createServer } from 'node:http';
import { pathToFileURL } from 'node:url';
import { applicationDefault, getApps, initializeApp } from 'firebase-admin/app';
import { getAppCheck } from 'firebase-admin/app-check';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { getStorage } from 'firebase-admin/storage';
import { createContactHttpHandler } from './contact-http.mjs';
import { createPublicationHttpHandler } from './publication-http.mjs';
import { publicOrigin } from './projection.mjs';

const emulatorKeys = ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST', 'FIREBASE_STORAGE_EMULATOR_HOST'];
const loopback = ['localhost', '127.0.0.1', '[::1]'];

export function readServerConfiguration(env = process.env) {
  const projectId = env.GCLOUD_PROJECT;
  if (typeof projectId !== 'string' || !/^[a-z][a-z0-9-]{4,62}[a-z0-9]$/.test(projectId)) throw new Error('configuration-required');
  const emulator = env.FUNCTIONS_EMULATOR === 'true';
  if (emulator) {
    if (!projectId.startsWith('demo-') || !env.FIRESTORE_EMULATOR_HOST || !env.FIREBASE_AUTH_EMULATOR_HOST) throw new Error('configuration-required');
    for (const key of emulatorKeys) {
      if (!env[key]) continue;
      let host;
      try { host = new URL(`http://${env[key]}`); } catch { throw new Error('configuration-required'); }
      if (!loopback.includes(host.hostname) || !host.port || host.username || host.password
          || host.pathname !== '/' || host.search || host.hash || host.host !== env[key]) throw new Error('configuration-required');
    }
  } else if (projectId.startsWith('demo-') || emulatorKeys.some((key) => env[key])) throw new Error('configuration-required');
  const origin = publicOrigin(env.PUBLIC_WEB_ORIGIN, emulator);
  const appId = env.CONTACT_APP_CHECK_APP_ID;
  const secret = env.CONTACT_RATE_HMAC_KEY;
  if (!emulator && (typeof appId !== 'string' || !appId || typeof secret !== 'string' || secret.length < 32)) throw new Error('configuration-required');
  const storageBucket = env.PUBLIC_STORAGE_BUCKET || null;
  if (storageBucket && (!emulator || !env.FIREBASE_STORAGE_EMULATOR_HOST
      || !/^[a-z0-9][a-z0-9._-]{1,220}[a-z0-9]$/.test(storageBucket))) throw new Error('configuration-required');
  const port = Number(env.BACKEND_PORT);
  if (!/^[0-9]+$/.test(env.BACKEND_PORT ?? '') || !Number.isInteger(port) || port < 1 || port > 65535) throw new Error('configuration-required');
  return { projectId, emulator, origin, appId, secret, storageBucket, port };
}

function readBody(request, limit) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let length = 0;
    let settled = false;
    const done = (value, error) => {
      if (settled) return;
      settled = true;
      request.off('data', onData); request.off('end', onEnd); request.off('error', onError); request.off('aborted', onAborted);
      request.once('error', () => {}); request.resume();
      if (error) reject(error); else resolve(value);
    };
    const onData = (chunk) => {
      length += chunk.length;
      if (length > limit) { done({ rawBody: Buffer.alloc(limit + 1), body: undefined }); return; }
      chunks.push(chunk);
    };
    const onEnd = () => {
      const rawBody = Buffer.concat(chunks, length);
      let body, invalidJson = false;
      try { body = JSON.parse(rawBody.toString('utf8')); } catch { invalidJson = true; }
      done({ rawBody, body, invalidJson });
    };
    const onError = () => done(null, new Error('unavailable'));
    const onAborted = () => onError();
    if (Number(request.headers['content-length']) > limit) {
      done({ rawBody: Buffer.alloc(limit + 1), body: undefined }); return;
    }
    request.on('data', onData); request.once('end', onEnd); request.once('error', onError); request.once('aborted', onAborted);
  });
}

function responseAdapter(response) {
  return {
    set(name, value) { response.setHeader(name, value); return this; },
    status(code) { response.statusCode = code; return this; },
    json(value) { response.setHeader('Content-Type', 'application/json; charset=utf-8'); response.end(JSON.stringify(value)); return this; },
    end() { response.end(); return this; },
  };
}

export function createBackendServer({ contactHandler, publicationHandler }) {
  return createServer({ requestTimeout: 30000, headersTimeout: 10000 }, async (request, response) => {
    const reply = responseAdapter(response);
    try {
      const path = new URL(request.url, 'http://localhost').pathname;
      if (path === '/health') {
        reply.set('Cache-Control', 'no-store');
        if (!['GET', 'HEAD'].includes(request.method)) { reply.status(405).json({ error: { code: 'method-not-allowed' } }); return; }
        if (request.method === 'HEAD') reply.status(200).end();
        else reply.status(200).json({ status: 'ok' });
        return;
      }
      const handler = path === '/contactInbox' ? contactHandler : path === '/documentPublication' ? publicationHandler : null;
      if (!handler) { reply.status(404).json({ error: { code: 'not-found' } }); return; }
      const mediaType = request.headers['content-type']?.split(';', 1)[0].trim().toLowerCase();
      const parsed = request.method === 'POST' && mediaType === 'application/json'
        ? await readBody(request, path === '/contactInbox' ? 24576 : 8192) : {};
      request.resume();
      await handler({ method: request.method, rawBody: parsed.rawBody, body: parsed.body,
        // Ошибка JSON использует общий invalid-data branch до Auth, сохраняя CORS checks.
        is(mime) { return !parsed.invalidJson && mediaType === mime; },
        get(name) { const value = request.headers[name.toLowerCase()]; return Array.isArray(value) ? value.join(', ') : value; },
      }, reply);
    } catch {
      if (!response.headersSent && !response.destroyed) reply.status(503).json({ error: { code: 'unavailable' } });
      else if (!response.writableEnded) response.end();
    }
  });
}

export async function startServer({ app, env = process.env } = {}) {
  const configuration = readServerConfiguration(env);
  const adminApp = app ?? getApps().find((candidate) => candidate.name === '[DEFAULT]') ?? initializeApp({
    projectId: configuration.projectId, credential: applicationDefault(),
    ...(configuration.storageBucket ? { storageBucket: configuration.storageBucket } : {}),
  });
  if (adminApp.options.projectId !== configuration.projectId) throw new Error('configuration-required');
  const database = getFirestore(adminApp), auth = getAuth(adminApp);
  const server = createBackendServer({
    contactHandler: createContactHttpHandler({ database, auth, appCheck: getAppCheck(adminApp),
      messaging: configuration.emulator ? undefined : getMessaging(adminApp), ...configuration }),
    publicationHandler: createPublicationHttpHandler({ database, auth,
      bucket: configuration.storageBucket ? getStorage(adminApp).bucket(configuration.storageBucket) : null,
      origin: configuration.origin, emulator: configuration.emulator }),
  });
  await new Promise((resolve, reject) => { server.once('error', reject); server.listen(configuration.port, '127.0.0.1', resolve); });
  return server;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  startServer().catch(() => { console.error('Backend configuration or startup failed'); process.exitCode = 1; });
}
