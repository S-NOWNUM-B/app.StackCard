import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import {
  ContactError, normalizeContactRequest, validOwnerUid, validContactId,
  allowsPublicContact, sameContactPayload, contactQuotaWindows, tokenHash, genericContactNotification,
} from './contact-contract.mjs';

const active = (account) => (account?.lifecycleState ?? 'active') === 'active';
const timestamp = () => FieldValue.serverTimestamp();
const unavailable = () => { throw new ContactError('document-unavailable', 404); };

export function createContactService({ database, secret, now = () => Date.now(), notifyAccepted }) {
  async function submit(request) {
    const quotas = contactQuotaWindows({ publicId: request.publicId, email: request.email, secret, now: now() });
    const accepted = await database.runTransaction(async (transaction) => {
      // Единственный источник ownership — private publication; public snapshot не содержит UID.
      const matches = await transaction.get(database.collectionGroup('publications').where('publicId', '==', request.publicId).limit(2));
      if (matches.size !== 1) unavailable();
      const publication = matches.docs[0], accountRef = publication.ref.parent.parent;
      if (!accountRef || accountRef.parent.id !== 'accounts' || !validOwnerUid(accountRef.id)) unavailable();
      const requestRef = accountRef.collection('contactRequests').doc(request.requestId);
      const quotaRefs = quotas.map((quota) => database.doc(`contactRateLimits/${quota.id}`));
      const [account, published, existing, ...rates] = await transaction.getAll(accountRef, database.doc(`publicDocuments/${request.publicId}`), requestRef, ...quotaRefs);
      const snapshot = published.data(), mapping = publication.data();
      if (!account.exists || !active(account.data()) || mapping.documentId !== publication.id) unavailable();
      if (existing.exists) {
        if (existing.data().schemaVersion !== 1 || existing.data().documentId !== mapping.documentId
            || !sameContactPayload(existing.data(), request)) throw new ContactError('conflict', 409);
        // Lost ACK подтверждает прежний durable write даже после withdrawal; новый submit закрыт.
        return { ownerUid: accountRef.id, result: { status: 'accepted', requestId: request.requestId } };
      }
      if (mapping.state !== 'published' || !snapshot || snapshot.schemaVersion !== 1
          || snapshot.publicId !== request.publicId || snapshot.version !== mapping.version
          || typeof snapshot.title !== 'string' || !snapshot.title.trim() || snapshot.title.length > 120
          || !allowsPublicContact(snapshot)) unavailable();
      if (rates.some((rate, index) => (rate.data()?.count ?? 0) >= quotas[index].limit)) throw new ContactError('rate-limited', 429);
      transaction.create(requestRef, {
        schemaVersion: 1, requestId: request.requestId, publicId: request.publicId,
        documentId: mapping.documentId, documentTitle: snapshot.title,
        name: request.name, email: request.email, message: request.message, createdAt: timestamp(), readAt: null,
      });
      for (let index = 0; index < quotas.length; index++) transaction.set(quotaRefs[index], {
        count: (rates[index].data()?.count ?? 0) + 1,
        windowStart: Timestamp.fromMillis(quotas[index].windowStart), expiresAt: Timestamp.fromMillis(quotas[index].expiresAt),
      });
      return { ownerUid: accountRef.id, result: { status: 'accepted', requestId: request.requestId } };
    });
    // Callback выполняется после durable commit и на lost-ACK retry; receipt ограничивает transport attempt.
    try { await notifyAccepted?.({ ownerUid: accepted.ownerUid, requestId: request.requestId }); }
    catch { /* Best effort: недоступность push не отменяет уже сохранённый Inbox. */ }
    return accepted.result;
  }
  async function register(uid, request) {
    const hash = tokenHash(request.token), accountRef = database.doc(`accounts/${uid}`);
    const bindingRef = database.doc(`pushTokenOwners/${hash}`), deviceRef = accountRef.collection('pushDevices').doc(hash);
    const stateRef = accountRef.collection('pushDeviceState').doc('current');
    return database.runTransaction(async (transaction) => {
      const [account, binding, state, devices] = await Promise.all([
        transaction.get(accountRef), transaction.get(bindingRef), transaction.get(stateRef),
        transaction.get(accountRef.collection('pushDevices').limit(11)),
      ]);
      if (!active(account.data())) throw new ContactError('account-unavailable', 409);
      const oldUid = binding.data()?.ownerUid;
      let oldState;
      if (oldUid && oldUid !== uid) {
        if (!validOwnerUid(oldUid)) throw new ContactError('unavailable', 503);
        oldState = await transaction.get(database.doc(`accounts/${oldUid}/pushDeviceState/current`));
      }
      const alreadyPresent = devices.docs.some((device) => device.id === hash);
      if (!alreadyPresent && devices.size >= 10) throw new ContactError('device-limit', 409);
      if (oldUid && oldUid !== uid) {
        transaction.delete(database.doc(`accounts/${oldUid}/pushDevices/${hash}`));
        transaction.set(oldState.ref, { revision: (oldState.data()?.revision ?? 0) + 1 });
      }
      transaction.set(deviceRef, { token: request.token, tokenHash: hash, platform: request.platform, updatedAt: timestamp() });
      transaction.set(bindingRef, { ownerUid: uid, tokenHash: hash, updatedAt: timestamp() });
      // Сериализация quota устройств и rebind, включая concurrent пустые query results.
      transaction.set(stateRef, { revision: (state.data()?.revision ?? 0) + 1 });
      return { status: 'completed' };
    });
  }
  return {
    async execute(uid, rawRequest) {
      const request = normalizeContactRequest(rawRequest);
      if (request.action === 'submit') return submit(request);
      if (!validOwnerUid(uid)) throw new ContactError('unauthenticated', 401);
      if (request.action === 'registerDevice') return register(uid, request);
      await removeDeviceBinding(database, uid, tokenHash(request.token), request.token, true);
      return { status: 'completed' };
    },
  };
}

async function removeDeviceBinding(database, uid, hash, token, requireActive = false) {
  return database.runTransaction(async (transaction) => {
    const accountRef = database.doc(`accounts/${uid}`), bindingRef = database.doc(`pushTokenOwners/${hash}`);
    const deviceRef = accountRef.collection('pushDevices').doc(hash), stateRef = accountRef.collection('pushDeviceState').doc('current');
    const [account, binding, device, state] = await transaction.getAll(accountRef, bindingRef, deviceRef, stateRef);
    if (requireActive && !active(account.data())) throw new ContactError('account-unavailable', 409);
    if (device.exists && (!token || device.data().token === token)) transaction.delete(deviceRef);
    if (binding.data()?.ownerUid === uid && (!token || !device.exists || device.data().token === token)) transaction.delete(bindingRef);
    if (active(account.data())) transaction.set(stateRef, { revision: (state.data()?.revision ?? 0) + 1 });
  });
}

export async function removeAccountPushBindings(database, uid) {
  const bindings = await database.collection('pushTokenOwners').where('ownerUid', '==', uid).get();
  for (const binding of bindings.docs) await removeDeviceBinding(database, uid, binding.id, null);
}

export async function sendContactNotification({ database, messaging, ownerUid, requestId }) {
  if (!validOwnerUid(ownerUid) || !validContactId(requestId)) return;
  const accountRef = database.doc(`accounts/${ownerUid}`), receiptRef = accountRef.collection('contactNotificationReceipts').doc(requestId);
  const devices = await database.runTransaction(async (transaction) => {
    const [account, inbox, receipt, registered] = await Promise.all([
      transaction.get(accountRef), transaction.get(accountRef.collection('contactRequests').doc(requestId)),
      transaction.get(receiptRef), transaction.get(accountRef.collection('pushDevices').limit(10)),
    ]);
    if (!account.exists || !active(account.data()) || !inbox.exists || inbox.data().requestId !== requestId || receipt.exists) return [];
    const candidates = registered.docs.filter((device) => typeof device.data().token === 'string' && tokenHash(device.data().token) === device.id);
    const bindings = candidates.length ? await transaction.getAll(...candidates.map((device) => database.doc(`pushTokenOwners/${device.id}`))) : [];
    const selected = candidates.filter((device, index) => bindings[index].data()?.ownerUid === ownerUid);
    // Best effort: один transport attempt; Inbox не зависит от FCM acknowledgement.
    transaction.create(receiptRef, { status: 'attempted', attemptedAt: timestamp() });
    return selected.map((device) => ({ hash: device.id, token: device.data().token }));
  });
  if (!devices.length) return;
  // Перепроверяем lifecycle/binding непосредственно перед external send.
  const [account, ...bindings] = await database.getAll(accountRef, ...devices.map((device) => database.doc(`pushTokenOwners/${device.hash}`)));
  if (!account.exists || !active(account.data())) return;
  const current = devices.filter((device, index) => bindings[index].data()?.ownerUid === ownerUid);
  if (!current.length) return;
  let result;
  try { result = await messaging.sendEachForMulticast({ ...genericContactNotification(ownerUid, requestId), tokens: current.map((device) => device.token) }); }
  catch { return; }
  for (let index = 0; index < current.length; index++) {
    if (['messaging/registration-token-not-registered', 'messaging/invalid-registration-token'].includes(result.responses?.[index]?.error?.code))
      await removeDeviceBinding(database, ownerUid, current[index].hash, current[index].token);
  }
}
