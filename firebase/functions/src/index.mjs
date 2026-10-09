import { initializeApp, getApps } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { getAppCheck } from 'firebase-admin/app-check';
import { getMessaging } from 'firebase-admin/messaging';
import { onRequest } from 'firebase-functions/v2/https';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { defineSecret } from 'firebase-functions/params';
import { createPublicationService } from './publication.mjs';
import { PublicationError, publicOrigin } from './projection.mjs';
import { createContactHttpHandler } from './contact-http.mjs';
import { sendContactNotification } from './contact-service.mjs';

if (!getApps().some((app) => app.name === '[DEFAULT]')) initializeApp();

const contactRateSecret = defineSecret('CONTACT_RATE_HMAC_KEY');
export const contactInbox = onRequest({
  cors: false, timeoutSeconds: 30, memory: '256MiB', maxInstances: 10,
  secrets: [contactRateSecret],
}, async (request, response) => {
  await createContactHttpHandler({
    database: getFirestore(), auth: getAuth(), appCheck: getAppCheck(),
    origin: process.env.PUBLIC_WEB_ORIGIN, emulator: process.env.FUNCTIONS_EMULATOR === 'true',
    projectId: process.env.GCLOUD_PROJECT, appId: process.env.CONTACT_APP_CHECK_APP_ID,
    secret: contactRateSecret.value(),
  })(request, response);
});

export const contactInboxNotification = onDocumentCreated({
  document: 'accounts/{ownerUid}/contactRequests/{requestId}',
  timeoutSeconds: 30, memory: '256MiB', maxInstances: 10, retry: false,
}, async (event) => {
  if (!event.data?.exists) return;
  // В demo окружении нет live transport; service sender проверяется отдельно с mock.
  if (process.env.FUNCTIONS_EMULATOR === 'true' && process.env.GCLOUD_PROJECT?.startsWith('demo-')) return;
  await sendContactNotification({ database: getFirestore(), messaging: getMessaging(),
    ownerUid: event.params.ownerUid, requestId: event.params.requestId });
});

export const documentPublication = onRequest({
  cors: false, timeoutSeconds: 120, memory: '512MiB', maxInstances: 10,
}, async (request, response) => {
  response.set('Cache-Control', 'no-store');
  response.set('X-Content-Type-Options', 'nosniff');
  const origin = request.get('origin');
  let configuredOrigin = null;
  try { configuredOrigin = publicOrigin(process.env.PUBLIC_WEB_ORIGIN, process.env.FUNCTIONS_EMULATOR === 'true'); } catch { /* Publish отдельно проверяет конфигурацию. */ }
  if (origin) {
    if (origin !== configuredOrigin) { response.status(403).json({ error: { code: 'origin-denied', message: 'Origin is unavailable' } }); return; }
    response.set('Access-Control-Allow-Origin', configuredOrigin);
    response.set('Vary', 'Origin');
    response.set('Access-Control-Allow-Methods', 'POST');
    response.set('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  }
  if (request.method === 'OPTIONS') { response.status(204).end(); return; }
  if (request.method !== 'POST') { response.status(405).json({ error: { code: 'method-not-allowed', message: 'POST required' } }); return; }
  try {
    if (!request.is('application/json') || (request.rawBody?.length ?? 0) > 8192) throw new PublicationError('invalid-data');
    const service = createPublicationService({
      database: getFirestore(), bucket: getStorage().bucket(), auth: getAuth(),
      origin: process.env.PUBLIC_WEB_ORIGIN, emulator: process.env.FUNCTIONS_EMULATOR === 'true',
    });
    if (request.body?.action === 'deletionStatus') {
      response.status(200).json(await service.execute(null, request.body));
      return;
    }
    const authorization = request.get('authorization') ?? '';
    const match = /^Bearer ([^\s]+)$/.exec(authorization);
    if (!match) throw new PublicationError('unauthenticated', 'Sign in required', 401);
    let token;
    try {
      token = await getAuth().verifyIdToken(match[1], true);
    } catch {
      // Исключение после identity deletion ограничено своим deletion receipt.
      try {
        if (request.body?.action !== 'status' || typeof request.body.operationId !== 'string'
            || request.body.operationId.includes('/') || !request.body.operationId) throw new Error();
        token = await getAuth().verifyIdToken(match[1], false);
        const [operation, account] = await Promise.all([
          getFirestore().doc(`accounts/${token.uid}/publicationOperations/${request.body.operationId}`).get(),
          getFirestore().doc(`accounts/${token.uid}`).get(),
        ]);
        if (operation.data()?.action !== 'deleteAccount'
            || account.data()?.lifecycleState !== 'deleted'
            || account.data()?.deletionOperationId !== request.body.operationId) throw new Error();
      } catch { throw new PublicationError('unauthenticated', 'Sign in required', 401); }
    }
    response.status(200).json(await service.execute(token.uid, request.body, token));
  } catch (error) {
    if (error instanceof PublicationError) response.status(error.httpStatus).json({ error: { code: error.code, message: error.message } });
    else response.status(503).json({ error: { code: 'unavailable', message: 'Outcome is unknown; resolve the same operation' } });
  }
});
