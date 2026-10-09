import assert from 'node:assert/strict';
import test, { type TestContext } from 'node:test';
import { renderToStaticMarkup } from 'react-dom/server';
import PublicDocumentPage, { generateMetadata } from '../src/app/d/[publicId]/page';
import type { PublicDocument } from '../src/lib/public-document';

const publicId = 'a'.repeat(32);
const params = () => ({ params: Promise.resolve({ publicId }) });
const origin = 'https://stackcard.example';

function fixture(): PublicDocument {
  return {
    schemaVersion: 1,
    publicId,
    version: 3,
    title: 'Selected resume',
    kind: 'resume',
    attachedResumePublicId: null,
    publishedAt: '2026-10-08T10:30:00Z',
    content: {
      profile: {
        name: 'Alex',
        username: 'alex',
        headline: 'Developer',
        bio: 'Published biography',
        locationText: '',
        avatarUrl: '',
      },
      skills: [],
      projects: [],
      experience: [],
      education: [],
      links: [],
      blocks: [
        { kind: 'profile', visible: true },
        { kind: 'about', visible: true },
      ],
      resumeText: '',
      theme: 'dark',
    },
  };
}

function firestoreValue(value: unknown): unknown {
  if (value === null) return { nullValue: null };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'number') return { integerValue: String(value) };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(firestoreValue) } };
  return {
    mapValue: {
      fields: Object.fromEntries(
        Object.entries(value as Record<string, unknown>).map(([key, item]) => [
          key,
          firestoreValue(item),
        ]),
      ),
    },
  };
}

function response(document: unknown): Response {
  const encoded = firestoreValue(document) as { mapValue: unknown };
  return Response.json(encoded.mapValue);
}

function setup(t: TestContext, fetcher: typeof fetch) {
  const keys = [
    'NEXT_PUBLIC_FIREBASE_PROJECT_ID',
    'NEXT_PUBLIC_WEB_ORIGIN',
    'NEXT_PUBLIC_USE_EMULATORS',
    'NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET',
  ] as const;
  const previous = Object.fromEntries(keys.map((key) => [key, process.env[key]]));
  t.after(() => {
    for (const key of keys) {
      if (previous[key] === undefined) delete process.env[key];
      else process.env[key] = previous[key];
    }
  });
  process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID = 'demo-stackcard';
  process.env.NEXT_PUBLIC_WEB_ORIGIN = origin;
  process.env.NEXT_PUBLIC_USE_EMULATORS = 'false';
  process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET = 'demo-stackcard.appspot.com';
  const calls: { url: string; init?: RequestInit }[] = [];
  t.mock.method(globalThis, 'fetch', async (input: RequestInfo | URL, init?: RequestInit) => {
    calls.push({ url: String(input), init });
    return fetcher(input, init);
  });
  return calls;
}

function assertPublicReads(calls: { url: string; init?: RequestInit }[]) {
  assert.ok(calls.length > 0);
  for (const { url, init } of calls) {
    assert.equal(
      url,
      `https://firestore.googleapis.com/v1/projects/demo-stackcard/databases/(default)/documents/publicDocuments/${publicId}`,
    );
    assert.equal(init?.headers, undefined);
    assert.equal(init?.credentials, 'omit');
    assert.equal(init?.cache, 'no-store');
    assert.equal(init?.redirect, 'error');
  }
}

function isNotFound(error: unknown) {
  return (
    error instanceof Error && 'digest' in error && error.digest === 'NEXT_HTTP_ERROR_FALLBACK;404'
  );
}

test('published Resume/Portfolio metadata uses the selected snapshot and permanent canonical', async (t) => {
  const document = fixture();
  const calls = setup(t, async () => response(document));
  for (const kind of ['resume', 'portfolio'] as const) {
    document.kind = kind;
    const label = kind === 'resume' ? 'Резюме' : 'Портфолио';
    const metadata = await generateMetadata(params());
    assert.deepEqual(metadata.title, { absolute: `Alex — ${label} | StackCard` });
    assert.equal(metadata.description, 'Developer');
    assert.deepEqual(metadata.alternates, { canonical: `${origin}/d/${publicId}` });
    assert.deepEqual(metadata.openGraph, {
      title: `Alex — ${label} | StackCard`,
      description: 'Developer',
      type: 'website',
      siteName: 'StackCard',
      locale: 'ru_RU',
      url: `${origin}/d/${publicId}`,
      images: [],
    });
    assert.deepEqual(metadata.twitter, {
      title: `Alex — ${label} | StackCard`,
      description: 'Developer',
      card: 'summary',
      images: [],
    });
    assert.deepEqual(metadata.robots, { index: true, follow: true });
  }
  assertPublicReads(calls);
});

test('photo metadata uses only the current published public media version', async (t) => {
  const document = fixture();
  const media = `publicMedia/${publicId}/3/${'c'.repeat(32)}.jpg`;
  document.content.profile.avatarUrl = media;
  setup(t, async () => response(document));
  const metadata = await generateMetadata(params());
  const image = `https://firebasestorage.googleapis.com/v0/b/demo-stackcard.appspot.com/o/${encodeURIComponent(media)}?alt=media`;
  assert.deepEqual((metadata.openGraph as { images: unknown }).images, [
    { url: image, alt: 'Фото Alex' },
  ]);
  assert.deepEqual((metadata.twitter as { images: unknown }).images, [image]);
  assert.ok(!JSON.stringify(metadata).includes('token='));
  const html = renderToStaticMarkup(await PublicDocumentPage(params()));
  assert.ok(html.includes(encodeURIComponent(media)));
});

test('no photo and a disallowed external photo do not create a crawler image', async (t) => {
  const document = fixture();
  setup(t, async () => response(document));
  for (const avatarUrl of ['', 'https://tracking.invalid/photo.jpg']) {
    document.content.profile.avatarUrl = avatarUrl;
    const metadata = await generateMetadata(params());
    assert.deepEqual((metadata.openGraph as { images: unknown }).images, []);
    assert.deepEqual((metadata.twitter as { images: unknown }).images, []);
    assert.ok(!JSON.stringify(metadata).includes('tracking.invalid'));
  }
});

test('hidden profile uses the published document title and visible biography', async (t) => {
  const document = fixture();
  document.content.blocks = [{ kind: 'about', visible: true }];
  document.content.profile = { ...document.content.profile, name: '', username: '', headline: '' };
  setup(t, async () => response(document));
  const metadata = await generateMetadata(params());
  assert.deepEqual(metadata.title, { absolute: 'Selected resume — Резюме | StackCard' });
  assert.equal(metadata.description, 'Published biography');
  assert.deepEqual((metadata.openGraph as { images: unknown }).images, []);
});

test('whitespace fields fall back to meaningful published metadata with a bounded description', async (t) => {
  const document = fixture();
  document.content.profile.name = '  \n ';
  document.content.profile.headline = '\t ';
  document.content.profile.bio = `  Published\n biography ${'a'.repeat(400)} `;
  setup(t, async () => response(document));
  const metadata = await generateMetadata(params());
  assert.deepEqual(metadata.title, { absolute: 'Selected resume — Резюме | StackCard' });
  assert.ok(metadata.description?.startsWith('Published biography '));
  assert.equal(metadata.description?.length, 200);
  document.content.profile.bio = '   ';
  assert.equal((await generateMetadata(params())).description, 'Selected resume');
});

test('canonical is absent unless the configured value is an exact HTTPS origin', async (t) => {
  setup(t, async () => response(fixture()));
  for (const value of [
    '',
    'not a URL',
    'http://stackcard.example',
    `${origin}/`,
    `${origin}/private`,
    `${origin}?id=private`,
    `${origin}#private`,
    'https://user:password@stackcard.example',
  ]) {
    process.env.NEXT_PUBLIC_WEB_ORIGIN = value;
    const metadata = await generateMetadata(params());
    assert.equal(metadata.alternates, undefined, value);
    assert.equal((metadata.openGraph as { url?: unknown }).url, undefined, value);
  }
});

test('missing and withdrawn public documents have identical noindex metadata and 404 pages', async (t) => {
  let status = 403;
  const calls = setup(t, async () => new Response('', { status }));
  const missing = await generateMetadata(params());
  assert.deepEqual(missing.robots, { index: false, follow: false });
  assert.equal(missing.alternates, undefined);
  assert.equal(missing.openGraph, undefined);
  assert.equal(missing.twitter, undefined);
  await assert.rejects(() => PublicDocumentPage(params()), isNotFound);
  status = 404;
  assert.deepEqual(await generateMetadata(params()), missing);
  await assert.rejects(() => PublicDocumentPage(params()), isNotFound);
  assertPublicReads(calls);
});

test('malformed public IDs do not make metadata or page look up any account', async (t) => {
  const calls = setup(t, async () => {
    throw new Error('Invalid IDs must never be requested');
  });
  for (const publicId of ['alice', 'A'.repeat(32), '../accounts/owner', 'a'.repeat(31)]) {
    const props = { params: Promise.resolve({ publicId }) };
    assert.deepEqual((await generateMetadata(props)).robots, { index: false, follow: false });
    await assert.rejects(() => PublicDocumentPage(props), isNotFound);
  }
  assert.equal(calls.length, 0);
});

test('private fields and foreign or stale media fail closed before metadata and page rendering', async (t) => {
  let payload: unknown = fixture();
  const calls = setup(t, async () => response(payload));
  const badMedia = [
    'accounts/owner/media/private.jpg',
    `publicMedia/${'b'.repeat(32)}/3/${'c'.repeat(32)}.jpg`,
    `publicMedia/${publicId}/2/${'c'.repeat(32)}.jpg`,
  ];
  const documents: unknown[] = [
    { ...fixture(), notes: 'private notes' },
    { ...fixture(), ownerUid: 'private owner' },
    ...badMedia.map((avatarUrl) => {
      const document = fixture();
      document.content.profile.avatarUrl = avatarUrl;
      return document;
    }),
  ];
  for (payload of documents) {
    const metadata = await generateMetadata(params());
    assert.deepEqual(metadata.robots, { index: false, follow: false });
    assert.equal(metadata.openGraph, undefined);
    await assert.rejects(() => PublicDocumentPage(params()), isNotFound);
    assert.ok(!JSON.stringify(metadata).includes('private'));
  }
  assertPublicReads(calls);
});

test('service failures produce noindex retry state without a stale snapshot or private fallback', async (t) => {
  let offline = false;
  const calls = setup(t, async () => {
    if (offline) throw new TypeError('offline');
    return new Response('', { status: 503 });
  });
  for (offline of [false, true]) {
    const metadata = await generateMetadata(params());
    assert.deepEqual(metadata.title, { absolute: 'Документ временно недоступен | StackCard' });
    assert.deepEqual(metadata.robots, { index: false, follow: false });
    assert.equal(metadata.alternates, undefined);
    assert.equal(metadata.openGraph, undefined);
    const html = renderToStaticMarkup(await PublicDocumentPage(params()));
    assert.ok(html.includes('Не удалось загрузить документ'));
    assert.ok(html.includes(`href="/d/${publicId}"`));
    assert.ok(!html.includes('Published biography'));
  }
  assertPublicReads(calls);
});

test('missing or invalid Firebase config shows unavailable instead of pretending the document is missing', async (t) => {
  const calls = setup(t, async () => {
    throw new Error('Invalid configuration must never be requested');
  });
  for (const projectId of ['', '../../accounts']) {
    process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID = projectId;
    const metadata = await generateMetadata(params());
    assert.deepEqual(metadata.title, { absolute: 'Документ временно недоступен | StackCard' });
    assert.deepEqual(metadata.robots, { index: false, follow: false });
    const html = renderToStaticMarkup(await PublicDocumentPage(params()));
    assert.ok(html.includes('Не удалось загрузить документ'));
    assert.ok(!html.includes('Ссылка не найдена'));
  }
  assert.equal(calls.length, 0);
});
