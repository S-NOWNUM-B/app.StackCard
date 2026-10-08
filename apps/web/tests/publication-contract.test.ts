import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  checkPublicationResult,
  parsePublicationMutation,
  writePublicationReceipt,
  readPublicationReceipt,
  clearPublicationReceipt,
} from '../src/lib/publication-contract';
const publicId = 'a'.repeat(32);
const mutation = {
  action: 'publish',
  documentId: 'doc',
  operationId: 'op',
  expectedMutationId: 'saved',
  expectedVersion: 0,
  expectedGeneration: 0,
};
const published = {
  documentId: 'doc',
  publicId,
  version: 1,
  state: 'published',
  url: `https://stackcard.dev/d/${publicId}`,
  sourceMutationId: 'saved',
};
const completed = {
  action: 'publish',
  status: 'completed',
  operationId: 'op',
  publication: published,
  lifecycleGeneration: 1,
};
test('durable publication request roundtrips and refuses malformed receipt before replay', () => {
  assert.deepEqual(parsePublicationMutation(mutation), mutation);
  for (const invalid of [
    { ...mutation, expectedVersion: -1 },
    { ...mutation, expectedGeneration: 0.5 },
    { ...mutation, operationId: '' },
    { ...mutation, action: 'deleteAccount' },
    { ...mutation, password: 'secret' },
  ])
    assert.throws(() => parsePublicationMutation(invalid));
});
test('completed operation must prove exact ID/action/document/generation', () => {
  assert.doesNotThrow(() => checkPublicationResult(completed, mutation));
  for (const invalid of [
    { ...completed, operationId: 'other' },
    { ...completed, action: 'deleteAccount' },
    { ...completed, lifecycleGeneration: undefined },
    { ...completed, publication: { ...published, documentId: 'other' } },
  ])
    assert.throws(() => checkPublicationResult(invalid, mutation));
});
test('publication inventory requires unique identities and safe permanent URL with no credentials/query', () => {
  assert.doesNotThrow(() =>
    checkPublicationResult(
      {
        status: 'completed',
        publications: [published],
        lifecycleGeneration: 1,
      },
      { action: 'inventory' },
    ),
  );
  for (const url of [
    'javascript:alert(1)',
    `https://x/d/${publicId}?token=secret`,
    `https://a:b@x/d/${publicId}`,
    'https://x/d/other',
  ])
    assert.throws(() =>
      checkPublicationResult({ ...completed, publication: { ...published, url } }, mutation),
    );
  assert.throws(() =>
    checkPublicationResult(
      {
        status: 'completed',
        publications: [published, published],
        lifecycleGeneration: 1,
      },
      { action: 'inventory' },
    ),
  );
  assert.throws(() =>
    checkPublicationResult(
      { ...completed, publication: { ...published, state: 'unpublished' } },
      { ...mutation, action: 'unpublish' },
    ),
  );
});
test('unknown receipt never means success; pending requires action proof; deletion recovery cannot impersonate publish', () => {
  assert.doesNotThrow(() =>
    checkPublicationResult(
      { status: 'unknown', operationId: 'op' },
      { action: 'status', operationId: 'op' },
    ),
  );
  assert.doesNotThrow(() =>
    checkPublicationResult(
      {
        status: 'pending',
        action: 'publish',
        operationId: 'op',
        lifecycleGeneration: 1,
      },
      mutation,
    ),
  );
  assert.throws(() => checkPublicationResult({ status: 'pending', operationId: 'op' }, mutation));
  assert.throws(() =>
    checkPublicationResult(completed, {
      action: 'deletionStatus',
      operationId: 'op',
    }),
  );
  assert.doesNotThrow(() =>
    checkPublicationResult(
      {
        status: 'completed',
        action: 'deleteAccount',
        operationId: 'op',
        lifecycleGeneration: 2,
      },
      { action: 'deletionStatus', operationId: 'op' },
    ),
  );
});

test('lost Publish ACK remains completed when another client has already withdrawn that document', () => {
  const replay = {
    ...completed,
    publication: { ...published, state: 'unpublished', url: null, version: 2 },
    lifecycleGeneration: 2,
  };
  assert.doesNotThrow(() => checkPublicationResult(replay, mutation));
  assert.doesNotThrow(() =>
    checkPublicationResult(replay, { action: 'status', operationId: 'op' }),
  );
  assert.throws(() =>
    checkPublicationResult(
      { ...replay, action: 'deleteDocument' },
      { ...mutation, action: 'deleteDocument' },
    ),
  );
});

test('publication receipt is durable before POST and cannot overwrite or clear another operation', () => {
  const values = new Map<string, string>();
  const store = {
    getItem: (key: string) => values.get(key) ?? null,
    setItem: (key: string, value: string) => {
      values.set(key, value);
    },
    removeItem: (key: string) => {
      values.delete(key);
    },
  };
  const key = 'stackcard.publication.owner';
  const p = parsePublicationMutation(mutation);
  writePublicationReceipt(store, key, p);
  assert.deepEqual(readPublicationReceipt(store, key), p);
  assert.throws(() => writePublicationReceipt(store, key, { ...p, operationId: 'later' }));
  assert.deepEqual(clearPublicationReceipt(store, key, 'other'), p);
  assert.equal(clearPublicationReceipt(store, key, p.operationId), null);
  assert.throws(() => writePublicationReceipt({ ...store, setItem: () => {} }, key, p));
  values.set(key, '{"action":"publish"}');
  assert.throws(() => readPublicationReceipt(store, key));
});
