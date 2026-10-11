import assert from 'node:assert/strict';
import test from 'node:test';
import {
  avatarMaxBytes,
  legacyAvatarMaxBytes,
  decodeAvatarDocument,
  encodeAvatarDocument,
  FirestorePortfolioMediaRepository,
  isOwnerMediaPath,
  validateAvatarJpeg,
  validateOriginalImage,
  isSafeLegacyAvatarUrl,
  fetchLegacyAvatarFile,
  type PortfolioMediaTransport,
} from '../src/lib/portfolio-media-repository';

const jpeg = Uint8Array.from(
  Buffer.from(
    '/9j/2wBDAAYEBQYFBAYGBQYHBwYIChAKCgkJChQODwwQFxQYGBcUFhYaHSUfGhsjHBYWICwgIyYnKSopGR8tMC0oMCUoKSj/2wBDAQcHBwoIChMKChMoGhYaKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCj/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAj/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFAEBAAAAAAAAAAAAAAAAAAAAAP/EABQRAQAAAAAAAAAAAAAAAAAAAAD/2gAMAwEAAhEDEQA/AKpAB//Z',
    'base64',
  ),
);
const path = 'accounts/owner/media/0123456789abcdef0123456789abcdef.jpg';
function transport(
  initial: unknown = null,
): PortfolioMediaTransport & { records: Map<string, unknown>; calls: string[] } {
  const records = new Map<string, unknown>(),
    calls: string[] = [];
  if (initial !== null) records.set(path, initial);
  return {
    records,
    calls,
    read: async (key) => {
      calls.push(`read:${key}`);
      return records.get(key) ?? null;
    },
    create: async (key, data) => {
      calls.push(`create:${key}`);
      assert.ok(!records.has(key));
      records.set(key, data);
    },
    remove: async (key) => {
      calls.push(`delete:${key}`);
      records.delete(key);
    },
  };
}

test('avatar canonical paths validate full UID safely and reject URL/suffix/foreign UID', () => {
  assert.ok(isOwnerMediaPath(path, 'owner'));
  assert.ok(isOwnerMediaPath(path.replace('owner', 'a.\\Eb'), 'a.\\Eb'));
  for (const invalid of [
    path.replace('owner', 'other'),
    `${path}\n`,
    `${path}/child`,
    path.replace('.jpg', '.png'),
    `https://example.dev/${path}`,
  ])
    assert.equal(isOwnerMediaPath(invalid, 'owner'), false);
});

test('new avatar codec uses exact bounded canonical base64 JPEG document', () => {
  const document = encodeAvatarDocument(jpeg);
  assert.deepEqual(Object.keys(document).sort(), ['base64', 'contentType', 'schemaVersion']);
  assert.deepEqual(decodeAvatarDocument(document), jpeg);
  for (const bad of [
    { ...document, ownerUid: 'other' },
    { ...document, schemaVersion: 2 },
    { ...document, contentType: 'image/png' },
    { ...document, base64: `${document.base64}\n` },
    { ...document, base64: Buffer.alloc(avatarMaxBytes + 1).toString('base64') },
    { ...document, base64: 'PHN2Zz4=' },
  ])
    assert.throws(() => decodeAvatarDocument(bad));
});

test('JPEG prepared boundary rejects excessive dimensions and private metadata', () => {
  const enlarged = jpeg.slice();
  const marker = enlarged.findIndex((value, index) => value === 255 && enlarged[index + 1] === 192);
  assert.ok(marker > 0);
  enlarged[marker + 7] = 2;
  enlarged[marker + 8] = 1; // Width513
  assert.throws(() => validateAvatarJpeg(enlarged));
  const exif = new Uint8Array(jpeg.length + 8);
  exif.set(jpeg.subarray(0, 2));
  exif.set([255, 225, 0, 6, 69, 120, 105, 102], 2);
  exif.set(jpeg.subarray(2), 10);
  assert.throws(() => validateAvatarJpeg(exif));
  assert.doesNotThrow(() => validateOriginalImage(exif, 'image/jpeg'));
});

test('original magic and dimensions reject SVG disguise and pixel bombs before bitmap decode', () => {
  assert.doesNotThrow(() => validateOriginalImage(jpeg, 'image/jpeg'));
  assert.throws(() => validateOriginalImage(jpeg, 'image/png'));
  assert.throws(() => validateOriginalImage(new TextEncoder().encode('<svg/>'), 'image/png'));
  const png = new Uint8Array(24);
  png.set([137, 80, 78, 71, 13, 10, 26, 10]);
  const view = new DataView(png.buffer);
  view.setUint32(16, 8192);
  view.setUint32(20, 8192);
  assert.throws(() => validateOriginalImage(png, 'image/png'));
});

test('new uploads create independent Firestore docs and foreign paths never reach transport', async () => {
  const adapter = transport(),
    repository = new FirestorePortfolioMediaRepository('owner', adapter, () => true);
  const first = await repository.upload(jpeg),
    second = await repository.upload(jpeg);
  assert.ok(isOwnerMediaPath(first, 'owner'));
  assert.notEqual(first, second);
  assert.deepEqual(adapter.records.get(first), encodeAvatarDocument(jpeg));
  await assert.rejects(repository.read(path.replace('owner', 'other')));
  assert.equal(adapter.calls.length, 2);
});

test('late ACK never returns stale UID path or private bytes', async () => {
  let active = true,
    finish: (() => void) | undefined;
  const adapter = transport(encodeAvatarDocument(jpeg));
  adapter.create = async () =>
    new Promise<void>((resolve) => {
      finish = resolve;
    });
  const repository = new FirestorePortfolioMediaRepository('owner', adapter, () => active);
  const upload = repository.upload(jpeg);
  active = false;
  finish!();
  await assert.rejects(upload, /Аккаунт изменился/);
  active = true;
  let returnRead: ((value: unknown) => void) | undefined;
  adapter.read = async () =>
    new Promise((resolve) => {
      returnRead = resolve;
    });
  const read = repository.read(path);
  active = false;
  returnRead!(encodeAvatarDocument(jpeg));
  await assert.rejects(read, /Аккаунт изменился/);
});

test('only missing Firestore docs use legacy reader; malformed docs never fall back', async () => {
  const adapter = transport();
  let legacyReads = 0;
  adapter.legacyRead = async () => {
    legacyReads++;
    return jpeg;
  };
  const repository = new FirestorePortfolioMediaRepository('owner', adapter, () => true);
  assert.deepEqual(await repository.read(path), jpeg);
  adapter.records.set(path, { schemaVersion: 9 });
  await assert.rejects(repository.read(path));
  assert.equal(legacyReads, 1);
  await repository.delete(path);
  assert.equal(legacyReads, 1);
});

test('unavailable transport times out without fake success', async () => {
  const adapter = transport();
  adapter.create = async () => new Promise(() => {});
  const repository = new FirestorePortfolioMediaRepository('owner', adapter, () => true, 5);
  await assert.rejects(repository.upload(jpeg), /недоступна/);
});

test('legacy PDF URL permits public HTTP(S) sources and rejects credentials, ports, private and numeric hosts', () => {
  for (const url of [
    'https://avatars.githubusercontent.com/u/583231?v=4',
    'https://images.unsplash.com/photo-test',
    'http://images.example.com/avatar.jpg',
  ])
    assert.equal(isSafeLegacyAvatarUrl(url), true);
  for (const url of [
    'data:image/jpeg;base64,AAAA',
    'file:///avatar.jpg',
    'https://user:password@images.example.com/a',
    'https://images.example.com:443/a',
    'https://%69mages.example.com/a',
    'https://images.example.com/a#fragment',
    'https://images.example.com/a#',
    'https://images.example.com\\a',
    'http://localhost/a',
    'http://127.0.0.1/a',
    'http://0x7f000001/a',
    'http://2130706433/a',
    'http://[::1]/a',
    'http://10.0.0.1/a',
    'https://host.local/a',
    'https://host.internal/a',
    'https://host.localdomain/a',
    'https://host.home/a',
    'https://host.onion/a',
    'https://host.arpa/a',
    'https://host.c0m/a',
    `https://${'a'.repeat(64)}.com/a`,
    `https://${Array.from({ length: 4 }, () => 'a'.repeat(63)).join('.')}.com/a`,
    'https://host.invalid/a',
    'https://images.example.com/a\n',
  ])
    assert.equal(isSafeLegacyAvatarUrl(url), false, url);
});

test('available legacy PDF photo streams with credentials omitted, CORS and redirects disabled', async () => {
  const url = 'https://avatars.githubusercontent.com/u/583231?v=4';
  const file = await fetchLegacyAvatarFile(url, {
    fetcher: async (input, options) => {
      assert.equal(input, url);
      assert.equal(options?.credentials, 'omit');
      assert.equal(options?.mode, 'cors');
      assert.equal(options?.redirect, 'error');
      assert.equal(options?.referrerPolicy, 'no-referrer');
      return new Response(
        new ReadableStream({
          start(controller) {
            controller.enqueue(jpeg.subarray(0, 20));
            controller.enqueue(jpeg.subarray(20));
            controller.close();
          },
        }),
        { headers: { 'content-type': 'image/jpeg; charset=binary' } },
      );
    },
  });
  assert.equal(file.type, 'image/jpeg');
  assert.deepEqual(new Uint8Array(await file.arrayBuffer()), jpeg);
});

test('legacy PDF photo rejects declared and streamed oversize data before image allocation', async () => {
  const url = 'https://images.example.com/avatar';
  await assert.rejects(
    fetchLegacyAvatarFile(url, {
      fetcher: async () =>
        new Response(jpeg.slice().buffer, {
          headers: {
            'content-type': 'image/jpeg',
            'content-length': String(legacyAvatarMaxBytes + 1),
          },
        }),
    }),
  );
  let cancelled = false;
  await assert.rejects(
    fetchLegacyAvatarFile(url, {
      fetcher: async () =>
        new Response(
          new ReadableStream({
            start(controller) {
              controller.enqueue(new Uint8Array(legacyAvatarMaxBytes));
              controller.enqueue(new Uint8Array(1));
            },
            cancel() {
              cancelled = true;
            },
          }),
          { headers: { 'content-type': 'image/jpeg' } },
        ),
    }),
  );
  assert.equal(cancelled, true);
});

test('legacy PDF photo rejects unsupported MIME, disguised SVG and HTTP failures', async () => {
  for (const response of [
    new Response(jpeg.slice().buffer, { headers: { 'content-type': 'image/svg+xml' } }),
    new Response('<svg/>', { headers: { 'content-type': 'image/png' } }),
    new Response(null, { status: 404 }),
    new Response(null, { status: 302, headers: { location: 'http://127.0.0.1/private' } }),
  ])
    await assert.rejects(
      fetchLegacyAvatarFile('https://images.example.com/avatar', { fetcher: async () => response }),
    );
});

test('legacy PDF photo refuses late responses after UID changes and unavailable network times out', async () => {
  let active = true;
  await assert.rejects(
    fetchLegacyAvatarFile('https://images.example.com/avatar', {
      active: () => active,
      fetcher: async () => {
        active = false;
        return new Response(jpeg.slice().buffer, { headers: { 'content-type': 'image/jpeg' } });
      },
    }),
    /Аккаунт изменился/,
  );
  await assert.rejects(
    fetchLegacyAvatarFile('https://images.example.com/avatar', {
      fetcher: async () => new Promise(() => {}),
      timeoutMs: 5,
    }),
    /старую фотографию/,
  );
  let contacted = false;
  await assert.rejects(
    fetchLegacyAvatarFile('http://127.0.0.1/private', {
      fetcher: async () => {
        contacted = true;
        return new Response(jpeg.slice().buffer);
      },
    }),
  );
  assert.equal(contacted, false);
});
