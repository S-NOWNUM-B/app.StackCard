import { createHash, timingSafeEqual } from 'node:crypto';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import sharp from 'sharp';
import { PublicationError, permanentPublicId, projectPublicDocument, publicOrigin, validateRequest } from './projection.mjs';
import { removeAccountPushBindings } from './contact-service.mjs';

const conflict = () => { throw new PublicationError('conflict', 'State changed; reload before retry', 409); };
const stateOf = (account) => account?.lifecycleState ?? 'active';
const generationOf = (account) => account?.lifecycleGeneration ?? 0;
const timestamp = () => FieldValue.serverTimestamp();
const fingerprint = (request) => createHash('sha256').update(JSON.stringify({
  action: request.action, documentId: request.documentId ?? null,
  expectedMutationId: request.expectedMutationId ?? null,
  expectedVersion: request.expectedVersion ?? null, expectedGeneration: request.expectedGeneration,
  recoveryKeyHash: request.recoveryKey ? createHash('sha256').update(request.recoveryKey).digest('hex') : null,
})).digest('hex');

function publicationValue(data) {
  if (!data) return null;
  return {
    documentId: data.documentId, publicId: data.publicId, version: data.version,
    state: data.state, url: data.state === 'published' ? data.url : null,
    sourceMutationId: data.sourceMutationId ?? '',
  };
}

export function createPublicationService({ database, bucket, auth, origin, emulator = false, now = () => Date.now() }) {
  const accountRef = (uid) => database.doc(`accounts/${uid}`);
  const draftRef = (uid) => accountRef(uid).collection('drafts').doc('current');
  const publicationRef = (uid, documentId) => accountRef(uid).collection('publications').doc(documentId);
  const operationRef = (uid, operationId) => accountRef(uid).collection('publicationOperations').doc(operationId);
  const publicRef = (publicId) => database.doc(`publicDocuments/${publicId}`);
  const requireStorage = () => {
    if (!bucket) throw new PublicationError('storage-unavailable', 'Media storage and cleanup are unavailable', 503);
  };

  function validDraft(draft, uid) {
    const fields = ['schemaVersion', 'ownerUid', 'mutationId', 'localRevision', 'notes', 'content', 'updatedAt'];
    if (!draft || Object.keys(draft).length !== fields.length || Object.keys(draft).some((key) => !fields.includes(key))
        || ![4, 5, 6].includes(draft.schemaVersion) || draft.ownerUid !== uid
        || typeof draft.mutationId !== 'string' || !draft.mutationId || draft.mutationId.length > 200
        || !Number.isSafeInteger(draft.localRevision) || draft.localRevision < 1
        || typeof draft.notes !== 'string' || !(draft.updatedAt instanceof Timestamp)) {
      throw new PublicationError('invalid-data');
    }
  }

  async function operationResult(uid, operationId, operation) {
    if (!operation) return { status: 'unknown', operationId };
    if (operation.status === 'failed') {
      throw new PublicationError(operation.errorCode, 'Operation was rejected', operation.errorStatus);
    }
    const result = {
      action: operation.action, status: operation.status, operationId,
      lifecycleGeneration: operation.result?.lifecycleGeneration ?? operation.expectedGeneration,
    };
    if (operation.documentId) {
      // Исторический ACK не выдаёт отозванный URL за действующую публикацию.
      const current = await publicationRef(uid, operation.documentId).get();
      result.publication = publicationValue(current.data());
    }
    return result;
  }

  async function inventory(uid) {
    const [account, publications] = await Promise.all([
      accountRef(uid).get(), accountRef(uid).collection('publications').get(),
    ]);
    return {
      status: 'completed', lifecycleGeneration: generationOf(account.data()),
      publications: publications.docs.map((document) => publicationValue(document.data())),
    };
  }

  async function prepare(uid, request) {
    return database.runTransaction(async (transaction) => {
      const [accountSnapshot, operationSnapshot, publicationSnapshot, draftSnapshot] = await Promise.all([
        transaction.get(accountRef(uid)), transaction.get(operationRef(uid, request.operationId)),
        transaction.get(publicationRef(uid, request.documentId)),
        transaction.get(draftRef(uid)),
      ]);
      const account = accountSnapshot.data();
      const operation = operationSnapshot.data();
      const publication = publicationSnapshot.data();
      const draft = draftSnapshot.data();
      const digest = fingerprint(request);
      if (operation) {
        if (operation.fingerprint !== digest) conflict();
        if (operation.cleanupPaths?.length || (operation.status === 'pending'
            && (operation.media?.length || publication?.mediaPaths?.length))) requireStorage();
        return { operation, existing: true };
      }
      if (stateOf(account) !== 'active') throw new PublicationError('account-deleting', 'Account is unavailable', 409);
      if (generationOf(account) !== request.expectedGeneration || (publication?.version ?? 0) !== request.expectedVersion) conflict();
      if (publication?.state === 'deleted' || (account?.deletedDocumentIds ?? []).includes(request.documentId)) {
        throw new PublicationError('deleted', 'Document is unavailable', 409);
      }
      const version = (publication?.version ?? 0) + 1;
      const publicId = publication?.publicId ?? permanentPublicId(uid, request.documentId);
      let projection = null;
      if (request.action === 'publish') {
        const baseOrigin = publicOrigin(origin, emulator);
        if (!draft || draft.ownerUid !== uid || draft.mutationId !== request.expectedMutationId) conflict();
        validDraft(draft, uid);
        projection = projectPublicDocument(draft.content, request.documentId, uid, publicId, version, request.operationId);
        if (projection.attachedResumeId) {
          const resume = await transaction.get(publicationRef(uid, projection.attachedResumeId));
          if (resume.data()?.state === 'published') projection.publicDocument.attachedResumePublicId = resume.data().publicId;
        }
        projection.url = `${baseOrigin}/d/${publicId}`;
      } else if (request.action === 'deleteDocument') {
        if (!draft || draft.ownerUid !== uid || !Array.isArray(draft.content?.documents)
            || !draft.content.documents.some((item) => item.id === request.documentId)) {
          throw new PublicationError('deleted', 'Document is unavailable', 409);
        }
        if ((account?.deletedDocumentIds ?? []).length >= 1000) {
          throw new PublicationError('resource-exhausted', 'Document deletion limit reached', 409);
        }
      }
      // Без bucket не создаём journal, который потребует copy или cleanup.
      if (projection?.media.length || publication?.mediaPaths?.length) requireStorage();
      const pending = {
        action: request.action, documentId: request.documentId, operationId: request.operationId,
        fingerprint: digest, status: 'pending', expectedGeneration: request.expectedGeneration,
        expectedVersion: request.expectedVersion, expectedMutationId: request.expectedMutationId ?? null,
        version, publicId, createdAt: timestamp(),
        // Только owner может читать журнал; raw draft/notes сюда не копируются.
        media: projection?.media ?? [], publicDocument: projection?.publicDocument ?? null,
        url: projection?.url ?? null,
      };
      transaction.create(operationRef(uid, request.operationId), pending);
      return { operation: pending, existing: false };
    });
  }

  async function copyMedia(operation) {
    if (operation.media.length) requireStorage();
    for (const item of operation.media) {
      const source = bucket.file(item.source);
      const [metadata] = await source.getMetadata();
      if (metadata.contentType !== 'image/jpeg' || Number(metadata.size) <= 0 || Number(metadata.size) > 2 * 1024 * 1024) {
        throw new PublicationError('invalid-media', 'Photo is unavailable', 400);
      }
      const [bytes] = await source.download({ validation: 'crc32c' });
      if (bytes.length > 2 * 1024 * 1024 || bytes[0] !== 0xff || bytes[1] !== 0xd8) {
        throw new PublicationError('invalid-media', 'Photo is unavailable', 400);
      }
      let cleaned;
      try {
        // Sharp по умолчанию удаляет EXIF/GPS; публичная копия не наследует tokens.
        cleaned = await sharp(bytes, { limitInputPixels: 24_000_000, failOn: 'error' })
          .rotate().resize({ width: 1600, height: 1600, fit: 'inside', withoutEnlargement: true })
          .jpeg({ quality: 85 }).toBuffer();
      } catch { throw new PublicationError('invalid-media', 'Photo is unavailable', 400); }
      if (cleaned.length > 2 * 1024 * 1024) throw new PublicationError('invalid-media');
      try {
        await bucket.file(item.destination).save(cleaned, {
          resumable: false, preconditionOpts: { ifGenerationMatch: 0 },
          metadata: { contentType: 'image/jpeg', cacheControl: 'private, no-store, max-age=0', metadata: {} },
        });
      } catch (error) { if (Number(error.code) !== 412) throw error; }
    }
  }

  async function enterCopyLease(uid, request) {
    await database.runTransaction(async (transaction) => {
      const [operation, account] = await Promise.all([
        transaction.get(operationRef(uid, request.operationId)), transaction.get(accountRef(uid)),
      ]);
      if (stateOf(account.data()) !== 'active' || operation.data()?.status !== 'pending') conflict();
      transaction.update(operation.ref, {
        copyLeaseCount: (operation.data().copyLeaseCount ?? 0) + 1,
        // Handler runtime ограничен 120s; cleanup ждёт завершения или lease expiry.
        copyLeaseUntil: now() + 180_000,
      });
    });
  }

  async function leaveCopyLease(uid, request) {
    await database.runTransaction(async (transaction) => {
      const operation = await transaction.get(operationRef(uid, request.operationId));
      if (!operation.exists) return;
      const count = Math.max(0, (operation.data().copyLeaseCount ?? 1) - 1);
      transaction.update(operation.ref, { copyLeaseCount: count, copyLeaseUntil: count ? operation.data().copyLeaseUntil : 0 });
    });
  }

  async function cleanupPaths(paths) {
    if (paths.length) requireStorage();
    const failures = [];
    for (const path of paths) {
      try { await bucket.file(path).delete({ ignoreNotFound: true }); } catch { failures.push(path); }
    }
    return failures;
  }

  async function finish(uid, request, operation) {
    return database.runTransaction(async (transaction) => {
      const [accountSnapshot, operationSnapshot, publicationSnapshot, draftSnapshot] = await Promise.all([
        transaction.get(accountRef(uid)), transaction.get(operationRef(uid, request.operationId)),
        transaction.get(publicationRef(uid, request.documentId)), transaction.get(draftRef(uid)),
      ]);
      const account = accountSnapshot.data();
      const storedOperation = operationSnapshot.data();
      const previous = publicationSnapshot.data();
      const draft = draftSnapshot.data();
      if (storedOperation?.status === 'completed') return storedOperation;
      if (!storedOperation || storedOperation.fingerprint !== fingerprint(request)) conflict();
      if (storedOperation.status !== 'pending') throw new PublicationError(storedOperation.errorCode ?? 'conflict', 'Operation was rejected', storedOperation.errorStatus ?? 409);
      if (stateOf(account) !== 'active' || generationOf(account) !== request.expectedGeneration
          || (previous?.version ?? 0) !== request.expectedVersion) conflict();
      if ((account?.deletedDocumentIds ?? []).includes(request.documentId) || previous?.state === 'deleted') {
        throw new PublicationError('deleted', 'Document is unavailable', 409);
      }
      if (request.action === 'publish' && draft?.mutationId !== request.expectedMutationId) conflict();
      if (request.action === 'deleteDocument' && !draft?.content?.documents?.some((item) => item.id === request.documentId)) conflict();
      const nextGeneration = generationOf(account) + 1;
      const next = {
        documentId: request.documentId, publicId: operation.publicId, version: operation.version,
        state: request.action === 'publish' ? 'published' : request.action === 'deleteDocument' ? 'deleted' : 'unpublished',
        url: request.action === 'publish' ? operation.url : null,
        sourceMutationId: request.action === 'publish' ? request.expectedMutationId : previous?.sourceMutationId ?? '',
        mediaPaths: request.action === 'publish' ? operation.media.map((item) => item.destination) : [],
        updatedAt: timestamp(),
      };
      if (request.action === 'publish') {
        transaction.set(publicRef(operation.publicId), { ...operation.publicDocument, publishedAt: timestamp() });
      } else transaction.delete(publicRef(operation.publicId));
      const deletedIds = account?.deletedDocumentIds ?? [];
      transaction.set(accountRef(uid), {
        ownerUid: uid, lifecycleState: 'active', lifecycleGeneration: nextGeneration,
        deletedDocumentIds: request.action === 'deleteDocument' ? [...deletedIds, request.documentId] : deletedIds,
        updatedAt: timestamp(),
      }, { merge: true });
      if (request.action === 'deleteDocument') {
        transaction.set(draftRef(uid), {
          ...draft, mutationId: `delete-${request.operationId}`, localRevision: draft.localRevision + 1,
          content: {
            ...draft.content,
            documents: draft.content.documents.filter((item) => item.id !== request.documentId)
              .map((item) => item.attachedResumeId === request.documentId ? { ...item, attachedResumeId: null } : item),
          }, updatedAt: timestamp(),
        });
      }
      transaction.set(publicationRef(uid, request.documentId), next);
      const completed = {
        ...storedOperation, status: 'completed', completedAt: timestamp(),
        publicDocument: null, media: [], cleanupPaths: previous?.mediaPaths ?? [],
        result: { lifecycleGeneration: nextGeneration },
      };
      transaction.set(operationRef(uid, request.operationId), completed);
      return completed;
    });
  }

  async function mutate(uid, request) {
    const { operation } = await prepare(uid, request);
    if (operation.status !== 'pending') {
      if (operation.status === 'completed' && operation.cleanupPaths?.length) {
        await operationRef(uid, request.operationId).update({ cleanupPaths: await cleanupPaths(operation.cleanupPaths) });
      }
      return operationResult(uid, request.operationId, operation);
    }
    let copyLeaseEntered = false;
    try {
      if (request.action === 'publish') {
        await enterCopyLease(uid, request);
        copyLeaseEntered = true;
        await copyMedia(operation);
      }
      const completed = await finish(uid, request, operation);
      const remaining = await cleanupPaths(completed.cleanupPaths ?? []);
      await operationRef(uid, request.operationId).update({ cleanupPaths: remaining });
      return operationResult(uid, request.operationId, completed);
    } catch (error) {
      if (error instanceof PublicationError) {
        // Claim failure ДО cleanup: другой handler того же op мог уже publish.
        const claim = await database.runTransaction(async (transaction) => {
          const current = await transaction.get(operationRef(uid, request.operationId));
          if (current.data()?.status === 'completed') return { completed: current.data() };
          if (current.data()?.status === 'pending') transaction.update(operationRef(uid, request.operationId), {
            status: 'failed', errorCode: error.code, errorStatus: error.httpStatus,
            publicDocument: null, media: [], cleanupPaths: operation.media.map((item) => item.destination),
          });
          return { cleanup: current.exists };
        });
        if (claim.completed) return operationResult(uid, request.operationId, claim.completed);
        if (claim.cleanup) {
          const remaining = await cleanupPaths(operation.media.map((item) => item.destination));
          await operationRef(uid, request.operationId).update({ cleanupPaths: remaining });
        }
      }
      throw error;
    } finally {
      if (copyLeaseEntered) await leaveCopyLease(uid, request);
    }
  }

  async function deleteAccount(uid, request, token) {
    if (!Number.isInteger(token.auth_time) || now() / 1000 - token.auth_time > 300 || token.auth_time > now() / 1000 + 60) {
      throw new PublicationError('reauthentication-required', 'Sign in again before deleting account', 412);
    }
    // Private/orphan objects нельзя подтвердить без Storage: не ставим lock и не удаляем identity.
    requireStorage();
    const prepared = await database.runTransaction(async (transaction) => {
      const [accountSnapshot, operationSnapshot, publications] = await Promise.all([
        transaction.get(accountRef(uid)), transaction.get(operationRef(uid, request.operationId)),
        transaction.get(accountRef(uid).collection('publications').where('state', '==', 'published')),
      ]);
      const account = accountSnapshot.data();
      const operation = operationSnapshot.data();
      if (operation) {
        if (operation.fingerprint !== fingerprint(request) || operation.action !== 'deleteAccount') conflict();
        return operation;
      }
      if (stateOf(account) !== 'active' || generationOf(account) !== request.expectedGeneration) conflict();
      let legacy = null;
      if (account?.username) legacy = await transaction.get(database.doc(`publicPortfolios/${account.username}`));
      const nextGeneration = generationOf(account) + 1;
      for (const publication of publications.docs) {
        transaction.delete(publicRef(publication.data().publicId));
        transaction.update(publication.ref, { state: 'deleted', url: null, version: publication.data().version + 1, mediaPaths: [], updatedAt: timestamp() });
      }
      if (legacy?.data()?.ownerUid === uid) {
        transaction.delete(legacy.ref);
        transaction.delete(database.doc(`usernames/${account.username}`));
      }
      transaction.set(accountRef(uid), {
        ownerUid: uid, lifecycleState: 'deleting', lifecycleGeneration: nextGeneration,
        deletionOperationId: request.operationId, updatedAt: timestamp(),
      }, { merge: true });
      const pending = {
        action: 'deleteAccount', operationId: request.operationId, fingerprint: fingerprint(request),
        status: 'pending', expectedGeneration: request.expectedGeneration,
        recoveryKeyHash: createHash('sha256').update(request.recoveryKey).digest('hex'),
        result: { lifecycleGeneration: nextGeneration }, createdAt: timestamp(),
      };
      transaction.create(operationRef(uid, request.operationId), pending);
      return pending;
    });
    if (prepared.status === 'completed') return operationResult(uid, request.operationId, prepared);
    return cleanupAccount(uid, request.operationId, prepared);
  }

  async function cleanupAccount(uid, operationId, prepared) {
    requireStorage();
    try {
      // Account lock уже запрещает SDK writes; withdrawal подтверждён прежде cleanup.
      const [publications, operations] = await Promise.all([
        accountRef(uid).collection('publications').get(), accountRef(uid).collection('publicationOperations').get(),
      ]);
      // Pending first Publish тоже имеет public media, даже без private mapping.
      // Не объявляем cleanup completed пока live handler ещё может копировать bytes.
      if (operations.docs.some((operation) => (operation.data().copyLeaseCount ?? 0) > 0 && operation.data().copyLeaseUntil > now())) {
        return { action: 'deleteAccount', status: 'pending', operationId, lifecycleGeneration: prepared.result.lifecycleGeneration };
      }
      const publicIds = new Set(operations.docs.flatMap((operation) => operation.data().publicId ? [operation.data().publicId] : []));
      for (const publication of publications.docs) {
        publicIds.add(publication.data().publicId);
      }
      for (const publicId of publicIds) await bucket.deleteFiles({ prefix: `publicMedia/${publicId}/`, force: true });
      await bucket.deleteFiles({ prefix: `accounts/${uid}/`, force: true });
      await removeAccountPushBindings(database, uid);
      for (const collection of await accountRef(uid).listCollections()) {
        if (collection.id === 'publicationOperations') {
          const operations = await collection.get();
          for (const operation of operations.docs) {
            if (operation.id !== operationId) await operation.ref.delete();
          }
        } else await database.recursiveDelete(collection);
      }
      // Минимальный receipt/lock остаётся для lost-response recovery, без owner content.
      await accountRef(uid).set({
        ownerUid: uid, lifecycleState: 'deleted', lifecycleGeneration: prepared.result.lifecycleGeneration,
        deletionOperationId: operationId, updatedAt: timestamp(),
      });
      try { await auth.deleteUser(uid); } catch (error) { if (error.code !== 'auth/user-not-found') throw error; }
      await operationRef(uid, operationId).update({ status: 'completed', completedAt: timestamp() });
      return { action: 'deleteAccount', status: 'completed', operationId, lifecycleGeneration: prepared.result.lifecycleGeneration };
    } catch {
      return { action: 'deleteAccount', status: 'pending', operationId, lifecycleGeneration: prepared.result.lifecycleGeneration };
    }
  }

  async function deletionStatus(request) {
    const [operationSnapshot, accountSnapshot] = await Promise.all([
      operationRef(request.ownerUid, request.operationId).get(), accountRef(request.ownerUid).get(),
    ]);
    const operation = operationSnapshot.data();
    const account = accountSnapshot.data();
    const claimedHash = createHash('sha256').update(request.recoveryKey).digest();
    const expectedHash = /^[0-9a-f]{64}$/.test(operation?.recoveryKeyHash ?? '')
      ? Buffer.from(operation.recoveryKeyHash, 'hex') : Buffer.alloc(32);
    const matches = timingSafeEqual(claimedHash, expectedHash);
    if (!matches || operation?.action !== 'deleteAccount' || account?.deletionOperationId !== request.operationId) {
      return { action: 'deleteAccount', status: 'unknown', operationId: request.operationId };
    }
    if (operation.status === 'pending' && request.retry === true) return cleanupAccount(request.ownerUid, request.operationId, operation);
    if (operation.status === 'pending' && account.lifecycleState === 'deleted') {
      try { await auth.getUser(request.ownerUid); } catch (error) {
        if (error.code === 'auth/user-not-found') {
          await operationSnapshot.ref.update({ status: 'completed', completedAt: timestamp() });
          operation.status = 'completed';
        }
      }
    }
    return operationResult(request.ownerUid, request.operationId, operation);
  }

  return {
    async execute(uid, rawRequest, token = {}) {
      const request = validateRequest(rawRequest);
      if (request.action === 'deletionStatus') return deletionStatus(request);
      if (typeof uid !== 'string' || !uid || uid.includes('/')) throw new PublicationError('unauthenticated', 'Sign in required', 401);
      if (request.action === 'inventory') return inventory(uid);
      if (request.action === 'status') {
        const operation = (await operationRef(uid, request.operationId).get()).data();
        // Lost response после Auth delete: подписанный, ещё действующий token
        // позволяет подтвердить только собственный минимальный deletion receipt.
        if (operation?.action === 'deleteAccount' && operation.status === 'pending') {
          const account = (await accountRef(uid).get()).data();
          if (account?.lifecycleState === 'deleted' && account.deletionOperationId === request.operationId) {
            try { await auth.getUser(uid); } catch (error) {
              if (error.code === 'auth/user-not-found') {
                await operationRef(uid, request.operationId).update({ status: 'completed', completedAt: timestamp() });
                operation.status = 'completed';
              }
            }
          }
        }
        return operationResult(uid, request.operationId, operation);
      }
      if (request.action === 'deleteAccount') return deleteAccount(uid, request, token);
      return mutate(uid, request);
    },
  };
}
