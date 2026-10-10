import { initializeApp, getApps } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { getAppCheck } from 'firebase-admin/app-check';
import { getMessaging } from 'firebase-admin/messaging';
import { onRequest } from 'firebase-functions/v2/https';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { defineSecret } from 'firebase-functions/params';
import { createPublicationHttpHandler } from './publication-http.mjs';
import { createContactHttpHandler } from './contact-http.mjs';
import { sendContactNotification } from './contact-service.mjs';

const app = getApps().find((candidate) => candidate.name === '[DEFAULT]') ?? initializeApp();

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
  await createPublicationHttpHandler({
    database: getFirestore(), bucket: app.options.storageBucket ? getStorage(app).bucket() : null, auth: getAuth(),
    origin: process.env.PUBLIC_WEB_ORIGIN, emulator: process.env.FUNCTIONS_EMULATOR === 'true',
  })(request, response);
});
