import { createHash, createHmac } from 'node:crypto';

export class ContactError extends Error {
  constructor(code, httpStatus = 400) { super(code); this.code = code; this.httpStatus = httpStatus; }
}
const invalid = () => { throw new ContactError('invalid-data'); };
export const tokenHash = (token) => createHash('sha256').update(token).digest('hex');
export const validOwnerUid = (uid) => typeof uid === 'string' && uid.length > 0 && uid.length <= 128 && !/[\x00-\x1f\x7f/]/.test(uid);
export const validContactId = (id) => typeof id === 'string' && /^[a-f0-9]{32}$/.test(id);
export const isDemoFunctionsEmulator = (emulator, projectId) => emulator === true && typeof projectId === 'string' && projectId.startsWith('demo-');
const cleanText = (value, max) => {
  if (typeof value !== 'string' || value.length > max || /[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/.test(value)) invalid();
  const result = value.replace(/\r\n?/g, '\n').trim();
  if (!result) invalid();
  return result;
};
const emailPattern = /^[A-Za-z0-9.!$&'*+/=_^`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+$/;

export function normalizeContactRequest(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value) || Object.getPrototypeOf(value) !== Object.prototype) invalid();
  const fields = value.action === 'submit'
    ? ['action', 'publicId', 'requestId', 'name', 'email', 'message', 'website']
    : value.action === 'registerDevice' ? ['action', 'token', 'platform']
    : value.action === 'unregisterDevice' ? ['action', 'token'] : null;
  if (!fields || Object.keys(value).length !== fields.length || fields.some((field) => !Object.hasOwn(value, field))) invalid();
  if (value.action !== 'submit') {
    if (typeof value.token !== 'string' || value.token.length < 1 || value.token.length > 4096 || /[\s\x00-\x1f\x7f]/.test(value.token)) invalid();
    if (value.action === 'registerDevice' && !['android', 'ios'].includes(value.platform)) invalid();
    return { ...value };
  }
  if (!validContactId(value.publicId) || !validContactId(value.requestId) || value.website !== '') invalid();
  if (typeof value.name !== 'string' || /[\x00-\x1f\x7f]/.test(value.name)) invalid();
  const email = cleanText(value.email, 254).toLowerCase();
  if (!emailPattern.test(email)) invalid();
  return { action: 'submit', publicId: value.publicId, requestId: value.requestId,
    name: cleanText(value.name, 100), email, message: cleanText(value.message, 4000), website: '' };
}
export function sameContactPayload(left, right) {
  return ['publicId', 'requestId', 'name', 'email', 'message'].every((key) => left[key] === right[key]);
}
export function allowsPublicContact(document) {
  const content = document?.content;
  if (!Array.isArray(content?.blocks) || !Array.isArray(content.links)
      || !content.blocks.some((block) => block?.kind === 'links' && block.visible === true)) return false;
  return content.links.some((link) => {
    if (typeof link?.url !== 'string' || /[\s\x00-\x1f\x7f]/.test(link.url)) return false;
    if (link.kind === 'email') return link.url.startsWith('mailto:') && emailPattern.test(link.url.slice(7));
    if (link.kind === 'phone') return /^tel:\+[0-9]{7,15}$/.test(link.url);
    if (link.kind === 'telegram') return /^https:\/\/t\.me\/[A-Za-z0-9_]{1,64}$/.test(link.url);
    return false;
  });
}
export function contactQuotaWindows({ publicId, email, secret, now }) {
  if (typeof secret !== 'string' || secret.length < 32) throw new ContactError('configuration-required', 503);
  return [
    { scope: 'document-short', duration: 600000, limit: 5, identity: publicId },
    { scope: 'document-day', duration: 86400000, limit: 30, identity: publicId },
    { scope: 'sender-hour', duration: 3600000, limit: 3, identity: [publicId, email] },
  ].map(({ scope, duration, limit, identity }) => {
    const start = Math.floor(now / duration) * duration;
    return { id: createHmac('sha256', secret).update(JSON.stringify([scope, start, identity])).digest('hex'), limit,
      windowStart: start, expiresAt: start + duration + 86400000 };
  });
}
export async function verifyContactAppCheck({ token, appId, secret, appCheck, emulator = false, projectId }) {
  if (isDemoFunctionsEmulator(emulator, projectId)) return;
  if (typeof appId !== 'string' || !appId || typeof secret !== 'string' || secret.length < 32 || !appCheck)
    throw new ContactError('configuration-required', 503);
  if (typeof token !== 'string' || !token || token.length > 8192) throw new ContactError('app-check-required', 401);
  let verified;
  try { verified = await appCheck.verifyToken(token, { consume: true }); }
  catch { throw new ContactError('app-check-required', 401); }
  if (verified.appId !== appId || verified.alreadyConsumed !== false) throw new ContactError('app-check-required', 401);
}
export function genericContactNotification(ownerUid, requestId) {
  if (!validOwnerUid(ownerUid) || !validContactId(requestId)) invalid();
  return { notification: { title: 'Новое обращение', body: 'Откройте StackCard, чтобы прочитать обращение.' },
    data: { type: 'contactRequest', requestId, ownerUid } };
}
