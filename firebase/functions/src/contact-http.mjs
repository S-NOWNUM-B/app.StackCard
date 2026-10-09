import { publicOrigin } from './projection.mjs';
import { ContactError, normalizeContactRequest, isDemoFunctionsEmulator, verifyContactAppCheck } from './contact-contract.mjs';
import { createContactService } from './contact-service.mjs';

export function createContactHttpHandler({ database, auth, appCheck, origin, emulator = false, projectId, appId, secret }) {
  return async (request, response) => {
    response.set('Cache-Control', 'no-store'); response.set('X-Content-Type-Options', 'nosniff');
    const demo = isDemoFunctionsEmulator(emulator, projectId), requestOrigin = request.get('origin');
    let configuredOrigin = null;
    try { configuredOrigin = publicOrigin(origin, demo); } catch { /* Missing origin не открывает CORS. */ }
    if (requestOrigin) {
      if (requestOrigin !== configuredOrigin) { response.status(403).json({ error: { code: 'origin-denied' } }); return; }
      response.set('Access-Control-Allow-Origin', configuredOrigin); response.set('Vary', 'Origin');
      response.set('Access-Control-Allow-Methods', 'POST');
      response.set('Access-Control-Allow-Headers', 'Authorization, Content-Type, X-Firebase-AppCheck');
    }
    if (request.method === 'OPTIONS') { response.status(204).end(); return; }
    if (request.method !== 'POST') { response.status(405).json({ error: { code: 'method-not-allowed' } }); return; }
    try {
      if (!request.is('application/json') || (request.rawBody?.length ?? 0) > 24576) throw new ContactError('invalid-data');
      const body = normalizeContactRequest(request.body);
      let uid = null;
      if (body.action === 'submit') {
        await verifyContactAppCheck({ token: request.get('x-firebase-appcheck'), appId, secret, appCheck, emulator, projectId });
      } else {
        const match = /^Bearer ([^\s]+)$/.exec(request.get('authorization') ?? '');
        if (!match) throw new ContactError('unauthenticated', 401);
        try { uid = (await auth.verifyIdToken(match[1], true)).uid; }
        catch { throw new ContactError('unauthenticated', 401); }
      }
      const service = createContactService({ database, secret: secret || (demo ? 'demo-contact-rate-hmac-key-not-for-production' : undefined) });
      response.status(200).json(await service.execute(uid, body));
    } catch (error) {
      if (error instanceof ContactError) response.status(error.httpStatus).json({ error: { code: error.code } });
      else response.status(503).json({ error: { code: 'unavailable' } });
    }
  };
}
