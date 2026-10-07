import assert from 'node:assert/strict';
import { after, before, beforeEach, test } from 'node:test';
import { readFile } from 'node:fs/promises';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteObject,
  getBytes,
  getMetadata,
  listAll,
  ref,
  updateMetadata,
  uploadBytes,
} from 'firebase/storage';

const projectId = 'demo-stackcard-test';
const imageId = '0123456789abcdef0123456789abcdef.jpg';
const path = `accounts/alice/media/${imageId}`;
const jpeg = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);
const jpegMetadata = { contentType: 'image/jpeg' };
let environment;

before(async () => {
  environment = await initializeTestEnvironment({
    projectId,
    storage: {
      host: '127.0.0.1',
      port: 9199,
      rules: await readFile(new URL('../storage.rules', import.meta.url), 'utf8'),
    },
  });
});

beforeEach(async () => {
  // clearStorage() установленного SDK удаляет только файлы корня, не вложенные prefixes.
  await environment.withSecurityRulesDisabled(async (context) => {
    async function clearPrefix(prefix) {
      const { items, prefixes } = await prefix.listAll();
      await Promise.all(items.map((item) => item.delete()));
      for (const child of prefixes) await clearPrefix(child);
    }
    await clearPrefix(context.storage().ref());
  });
});
after(async () => environment?.cleanup());

function storage(uid = 'alice') {
  return (uid === null
    ? environment.unauthenticatedContext()
    : environment.authenticatedContext(uid)).storage();
}

function upload(client, objectPath = path, bytes = jpeg, metadata = jpegMetadata) {
  return uploadBytes(ref(client, objectPath), bytes, metadata);
}

test('owner creates, reads bytes and metadata, and deletes a private JPEG', async () => {
  const alice = storage();
  await assertSucceeds(upload(alice));
  const object = ref(alice, path);
  const bytes = await assertSucceeds(getBytes(object));
  assert.deepEqual(new Uint8Array(bytes), jpeg);
  const metadata = await assertSucceeds(getMetadata(object));
  assert.equal(metadata.contentType, 'image/jpeg');
  assert.equal(metadata.size, jpeg.length);
  await assertSucceeds(deleteObject(object));
});

test('foreign UID and anonymous clients cannot create, read or delete private files', async () => {
  await upload(storage());
  for (const uid of ['bob', null]) {
    const client = storage(uid);
    const object = ref(client, path);
    await assertFails(getBytes(object));
    await assertFails(getMetadata(object));
    await assertFails(deleteObject(object));
    await assertFails(upload(client, `accounts/alice/media/${'1'.repeat(32)}.jpg`));
  }
});

test('private enumeration is denied even to the owner', async () => {
  await upload(storage());
  for (const uid of ['alice', 'bob', null]) {
    const client = storage(uid);
    for (const prefix of ['', 'accounts', 'accounts/alice', 'accounts/alice/media']) {
      await assertFails(listAll(ref(client, prefix)));
    }
  }
});

test('existing files cannot be overwritten or have metadata changed', async () => {
  const alice = storage();
  await upload(alice);
  await assertFails(upload(alice, path, new Uint8Array([1, 2, 3])));
  await assertFails(updateMetadata(ref(alice, path), { contentType: 'image/png' }));
  await assertFails(updateMetadata(ref(alice, path), {
    customMetadata: { firebaseStorageDownloadTokens: 'public-bearer-token' },
  }));
  assert.deepEqual(new Uint8Array(await getBytes(ref(alice, path))), jpeg);
});

test('replacement creates a distinct immutable file and owner may delete the old one', async () => {
  const alice = storage();
  await upload(alice);
  const replacement = `accounts/alice/media/${'2'.repeat(32)}.jpg`;
  await assertSucceeds(upload(alice, replacement));
  await assertSucceeds(deleteObject(ref(alice, path)));
  await assertSucceeds(getBytes(ref(alice, replacement)));
});

test('only non-empty JPEG uploads at or below 2 MiB are accepted', async () => {
  const alice = storage();
  for (const contentType of ['image/png', 'image/webp', 'image/gif', 'application/pdf', 'application/octet-stream']) {
    await assertFails(upload(alice, path, jpeg, { contentType }));
  }
  await assertFails(upload(alice, path, jpeg, {}));
  await assertFails(upload(alice, path, new Uint8Array()));
  await assertFails(upload(alice, path, new Uint8Array(2 * 1024 * 1024 + 1)));
  await assertSucceeds(upload(alice, path, new Uint8Array(2 * 1024 * 1024)));
});

test('private object names require exactly 32 lowercase hex characters and jpg extension', async () => {
  const alice = storage();
  for (const objectPath of [
    `accounts/alice/media/${'A'.repeat(32)}.jpg`,
    `accounts/alice/media/${'g'.repeat(32)}.jpg`,
    `accounts/alice/media/${'0'.repeat(31)}.jpg`,
    `accounts/alice/media/${'0'.repeat(33)}.jpg`,
    `accounts/alice/media/${'0'.repeat(32)}.jpeg`,
    `accounts/alice/media/${'0'.repeat(32)}.png`,
    `accounts/alice/media/${'0'.repeat(32)}Xjpg`,
    `accounts/alice/media/nested/${imageId}`,
    `accounts/alice/${imageId}`,
    `unknown/${imageId}`,
  ]) {
    await assertFails(upload(alice, objectPath));
    await environment.withSecurityRulesDisabled((context) => upload(context.storage(), objectPath));
    await assertFails(getBytes(ref(alice, objectPath)));
    await assertFails(deleteObject(ref(alice, objectPath)));
  }
});

test('public media namespace is closed for every client until explicit publication exists', async () => {
  for (const publicPath of [`publicPortfolios/alice/media/${imageId}`, `public/alice/${imageId}`]) {
    await environment.withSecurityRulesDisabled((context) => upload(context.storage(), publicPath));
    for (const uid of ['alice', 'bob', null]) {
      const client = storage(uid);
      const object = ref(client, publicPath);
      await assertFails(getBytes(object));
      await assertFails(getMetadata(object));
      await assertFails(deleteObject(object));
      await assertFails(upload(client, publicPath));
      await assertFails(listAll(ref(client, publicPath.substring(0, publicPath.lastIndexOf('/')))));
    }
  }
});
