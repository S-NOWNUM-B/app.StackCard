import assert from 'node:assert/strict';
import test from 'node:test';
import { readFile } from 'node:fs/promises';
import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { DocumentView } from '../src/components/document-view';
import PublicDocumentPage from '../src/app/d/[publicId]/page';
import {
  isPublicId,
  parsePublicDocument,
  publicDocumentMetadata,
  PublicDocumentUnavailable,
  readPublicDocument,
  safePublicHref,
  safePublicMedia,
} from '../src/lib/public-document';

const publicId = 'a'.repeat(32);
const otherId = 'b'.repeat(32);
function fixture(): Record<string, unknown> {
  return {
    schemaVersion: 1,
    publicId,
    version: 1,
    title: 'Selected resume',
    kind: 'resume',
    attachedResumePublicId: null,
    publishedAt: '2026-10-08T10:30:00Z',
    content: {
      profile: {
        name: 'Alex',
        username: 'alex',
        headline: 'Developer',
        bio: 'Public biography',
        locationText: 'Алматы',
        avatarUrl: '',
      },
      skills: [{ id: 'flutter', name: 'Flutter' }],
      projects: [
        {
          id: 'atlas',
          title: 'Atlas',
          description: 'A project',
          contribution: 'Design',
          technologies: ['Flutter'],
          repositoryUrl: 'https://github.com/example/atlas',
          liveUrl: '',
          featured: true,
          visible: true,
          imageUrls: [],
        },
      ],
      experience: [
        {
          id: 'work',
          role: 'Developer',
          organization: 'Studio',
          period: '2024–2026',
          description: '',
        },
      ],
      education: [
        {
          id: 'edu',
          institution: 'University',
          qualification: 'Engineering',
          period: '2023–2027',
          description: '',
        },
      ],
      links: [{ id: 'email', label: 'Email', url: 'mailto:hello@example.com', kind: 'email' }],
      blocks: [
        'profile',
        'about',
        'location',
        'skills',
        'featuredProjects',
        'experience',
        'education',
        'links',
      ].map((kind) => ({ kind, visible: true })),
      resumeText: '',
      theme: 'dark',
    },
  };
}
function content(value: Record<string, unknown>) {
  return value.content as Record<string, unknown>;
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
function firestoreResponse(value: Record<string, unknown>) {
  const encoded = firestoreValue(value) as { mapValue: { fields: Record<string, unknown> } };
  encoded.mapValue.fields.publishedAt = { timestampValue: value.publishedAt };
  return JSON.stringify({
    name: `projects/demo-stackcard/databases/(default)/documents/publicDocuments/${publicId}`,
    fields: encoded.mapValue.fields,
  });
}

test('valid projected document has the published metadata and selected content', () => {
  const document = parsePublicDocument(fixture(), publicId);
  assert.ok(document);
  assert.equal(document.content.projects[0].contribution, 'Design');
  assert.deepEqual(publicDocumentMetadata(document), {
    title: 'Alex — Резюме | StackCard',
    description: 'Developer',
  });
});
test('public IDs reject usernames, traversal, uppercase and private paths', () => {
  for (const value of [
    'alex',
    '../accounts/uid',
    'A'.repeat(32),
    'a'.repeat(31),
    `${publicId}/accounts`,
  ])
    assert.equal(isPublicId(value), false);
  assert.equal(isPublicId(publicId), true);
});
test('unknown schema, identity mismatch and absent envelope are rejected', () => {
  assert.equal(parsePublicDocument(null), null);
  assert.equal(parsePublicDocument({ ...fixture(), schemaVersion: 2 }), null);
  assert.equal(parsePublicDocument(fixture(), otherId), null);
  assert.equal(parsePublicDocument({ ...fixture(), publishedAt: null }), null);
});
test('private fields at envelope, content, profile and project boundaries are rejected', () => {
  for (const key of ['uid', 'notes', 'draft', 'ownerId', 'documentId'])
    assert.equal(parsePublicDocument({ ...fixture(), [key]: 'private' }), null);
  for (const key of ['documents', 'ignoredGitHubRepositories', 'baseSnapshot']) {
    const data = fixture();
    content(data)[key] = [];
    assert.equal(parsePublicDocument(data), null);
  }
  for (const key of ['avatarPath', 'publishLocation']) {
    const data = fixture();
    (content(data).profile as Record<string, unknown>)[key] = 'private';
    assert.equal(parsePublicDocument(data), null);
  }
  for (const key of ['imagePaths', 'githubMetadata', 'source']) {
    const data = fixture();
    (content(data).projects as Record<string, unknown>[])[0][key] = 'private';
    assert.equal(parsePublicDocument(data), null);
  }
});
test('unprojected visibility and private links are rejected', () => {
  const data = fixture();
  (content(data).projects as Record<string, unknown>[])[0].visible = false;
  assert.equal(parsePublicDocument(data), null);
  const linkData = fixture();
  (content(linkData).links as Record<string, unknown>[])[0].publishAllowed = true;
  assert.equal(parsePublicDocument(linkData), null);
  const hidden = fixture();
  content(hidden).blocks = [];
  assert.equal(parsePublicDocument(hidden), null);
});
test('invalid kind/theme types and duplicate element IDs cannot pass string coercion', () => {
  assert.equal(parsePublicDocument({ ...fixture(), kind: ['resume'] }), null);
  const data = fixture();
  content(data).theme = ['light'];
  assert.equal(parsePublicDocument(data), null);
  const duplicate = fixture();
  content(duplicate).skills = [
    { id: 'same', name: 'Dart' },
    { id: 'same', name: 'Flutter' },
  ];
  assert.equal(parsePublicDocument(duplicate), null);
});
test('unsafe hrefs, credentials and contact injection are rejected', () => {
  for (const value of [
    'javascript:alert(1)',
    'data:text/html,hi',
    '//evil.test',
    'https://user:secret@example.com',
    'https://example.com/\nattack',
    'https:example.com',
  ])
    assert.equal(safePublicHref(value), null);
  assert.equal(safePublicHref('mailto:hello@example.com?subject=attack', 'email'), null);
  assert.equal(safePublicHref('tel:+77001234567', 'phone'), 'tel:+77001234567');
  assert.equal(safePublicHref('https://t.me/alex_dev', 'telegram'), 'https://t.me/alex_dev');
  assert.equal(safePublicHref('https://evil.test/alex', 'telegram'), null);
  const data = fixture();
  (content(data).projects as Record<string, unknown>[])[0].liveUrl = 'javascript:alert(1)';
  assert.equal(parsePublicDocument(data), null);
});
test('media allows selected external hosts and rejects bearer/private paths', () => {
  assert.equal(
    safePublicMedia('https://avatars.githubusercontent.com/u/1'),
    'https://avatars.githubusercontent.com/u/1',
  );
  for (const url of [
    'https://tracking.invalid/photo.jpg',
    'http://images.unsplash.com/photo',
    'https://avatars.githubusercontent.com.evil.test/1',
    'accounts/uid/media/photo.jpg',
    'data:image/png,unsafe',
  ])
    assert.equal(safePublicMedia(url), null);
});
test('public media is constrained to the same published document/version', () => {
  const data = fixture();
  (content(data).profile as Record<string, unknown>).avatarUrl =
    `publicMedia/${otherId}/1/${'c'.repeat(32)}.jpg`;
  assert.equal(parsePublicDocument(data), null);
  (content(data).profile as Record<string, unknown>).avatarUrl =
    `publicMedia/${publicId}/2/${'c'.repeat(32)}.jpg`;
  assert.equal(parsePublicDocument(data), null);
  (content(data).profile as Record<string, unknown>).avatarUrl =
    `publicMedia/${publicId}/1/${'c'.repeat(32)}.jpg`;
  assert.ok(parsePublicDocument(data));
});
test('only portfolios can reference an independent public resume', () => {
  assert.equal(parsePublicDocument({ ...fixture(), attachedResumePublicId: otherId }), null);
  const portfolio = { ...fixture(), kind: 'portfolio', attachedResumePublicId: otherId };
  assert.equal(parsePublicDocument(portfolio), null);
  (content(portfolio).blocks as { kind: string; visible: true }[]).push({
    kind: 'resume',
    visible: true,
  });
  assert.ok(parsePublicDocument(portfolio));
  assert.equal(
    parsePublicDocument({ ...fixture(), kind: 'portfolio', attachedResumePublicId: publicId }),
    null,
  );
  assert.equal(
    parsePublicDocument({
      ...fixture(),
      kind: 'portfolio',
      attachedResumePublicId: 'private-resume-id',
    }),
    null,
  );
});
test('reader does only one anonymous no-store GET of publicDocuments', async () => {
  const calls: { url: string; init: RequestInit | undefined }[] = [];
  const fetcher: typeof fetch = async (input, init) => {
    calls.push({ url: String(input), init });
    return new Response(firestoreResponse(fixture()));
  };
  const document = await readPublicDocument(publicId, {
    projectId: 'demo-stackcard',
    fetch: fetcher,
  });
  assert.ok(document);
  assert.equal(calls.length, 1);
  assert.equal(
    calls[0].url,
    `https://firestore.googleapis.com/v1/projects/demo-stackcard/databases/(default)/documents/publicDocuments/${publicId}`,
  );
  assert.equal(calls[0].init?.cache, 'no-store');
  assert.equal(calls[0].init?.credentials, 'omit');
  assert.equal(calls[0].init?.redirect, 'error');
  assert.equal(calls[0].init?.headers, undefined);
});
test('malformed IDs/config do not request any document', async () => {
  let requests = 0;
  const fetcher: typeof fetch = async () => {
    requests++;
    return new Response('');
  };
  assert.equal(
    await readPublicDocument('../accounts', { projectId: 'demo-stackcard', fetch: fetcher }),
    null,
  );
  assert.equal(
    await readPublicDocument(publicId, { projectId: '../../accounts', fetch: fetcher }),
    null,
  );
  assert.equal(requests, 0);
});
test('missing, withdrawn and Rules denied return identical absence', async () => {
  for (const status of [403, 404])
    assert.equal(
      await readPublicDocument(publicId, {
        projectId: 'demo-stackcard',
        fetch: async () => new Response('', { status }),
      }),
      null,
    );
});
test('unknown Firestore types, invalid JSON and private snapshots fail closed', async () => {
  const payloads = [
    'bad JSON',
    JSON.stringify({ fields: { schemaVersion: { doubleValue: 1 } } }),
    firestoreResponse({ ...fixture(), notes: 'secret' }),
  ];
  for (const payload of payloads)
    assert.equal(
      await readPublicDocument(publicId, {
        projectId: 'demo-stackcard',
        fetch: async () => new Response(payload),
      }),
      null,
    );
});
test('service failure is distinct from missing and does not fall back to a cache', async () => {
  await assert.rejects(
    () =>
      readPublicDocument(publicId, {
        projectId: 'demo-stackcard',
        fetch: async () => new Response('', { status: 503 }),
      }),
    PublicDocumentUnavailable,
  );
  await assert.rejects(
    () =>
      readPublicDocument(publicId, {
        projectId: 'demo-stackcard',
        fetch: async () => {
          throw new TypeError('offline');
        },
      }),
    PublicDocumentUnavailable,
  );
});
test('emulator endpoint is limited to an explicit local origin', async () => {
  await assert.rejects(
    () =>
      readPublicDocument(publicId, {
        projectId: 'demo-stackcard',
        emulatorOrigin: 'https://evil.test',
      }),
    PublicDocumentUnavailable,
  );
  let requested = '';
  await readPublicDocument(publicId, {
    projectId: 'demo-stackcard',
    emulatorOrigin: 'http://127.0.0.1:8085',
    fetch: async (url) => {
      requested = String(url);
      return new Response('', { status: 404 });
    },
  });
  assert.ok(requested.startsWith('http://127.0.0.1:8085/v1/projects/demo-stackcard/'));
});
test('renderer escapes author text and preserves the selected theme and content', () => {
  const data = fixture();
  (content(data).profile as Record<string, unknown>).bio = '<script>alert("unsafe")</script>';
  content(data).theme = 'light';
  const document = parsePublicDocument(data);
  assert.ok(document);
  const html = renderToStaticMarkup(
    createElement(DocumentView, { content: document.content, kind: document.kind }),
  );
  assert.ok(html.includes('data-theme="light"'));
  assert.ok(html.includes('&lt;script&gt;'));
  assert.ok(!html.includes('<script>'));
  assert.ok(html.includes('mailto:hello@example.com'));
  assert.ok(html.includes('Atlas'));
  assert.ok(html.includes('Технологии'));
});
test('renderer independently rejects unsafe contacts/media and private attachments', () => {
  const document = parsePublicDocument(fixture());
  assert.ok(document);
  document.content.links[0].url = 'javascript:alert(1)';
  document.content.profile.avatarUrl = 'https://tracking.invalid/pixel';
  const html = renderToStaticMarkup(
    createElement(DocumentView, {
      content: document.content,
      kind: 'portfolio',
      attachedResumeUrl: '/accounts/secret/private',
    }),
  );
  assert.ok(!html.includes('javascript:'));
  assert.ok(!html.includes('tracking.invalid'));
  assert.ok(!html.includes('/accounts/'));
});
test('hidden blocks are excluded even in a private editor preview', () => {
  const document = parsePublicDocument(fixture());
  assert.ok(document);
  document.content.blocks = document.content.blocks.filter(
    (block) => block.kind !== 'featuredProjects' && block.kind !== 'links',
  );
  const html = renderToStaticMarkup(
    createElement(DocumentView, { content: document.content, kind: 'resume', preview: true }),
  );
  assert.ok(!html.includes('Atlas'));
  assert.ok(!html.includes('hello@example.com'));
  assert.ok(!html.includes('id="projects"'));
});
test('hidden resume block hides both resume text and an independently published attachment', () => {
  const document = parsePublicDocument(fixture());
  assert.ok(document);
  document.content.resumeText = 'Sensitive resume text';
  document.content.blocks = document.content.blocks.filter((block) => block.kind !== 'resume');
  const props = {
    content: document.content,
    kind: 'portfolio' as const,
    attachedResumeUrl: `/d/${otherId}`,
  };
  const hidden = renderToStaticMarkup(createElement(DocumentView, props));
  assert.ok(!hidden.includes('Sensitive resume text'));
  assert.ok(!hidden.includes(`/d/${otherId}`));
  document.content.blocks.push({ kind: 'resume', visible: true });
  const shown = renderToStaticMarkup(createElement(DocumentView, props));
  assert.ok(shown.includes('Sensitive resume text'));
  assert.ok(shown.includes(`href="/d/${otherId}"`));
});
test('private preview photo replaces a legacy avatar only inside the visible profile block', () => {
  const document = parsePublicDocument(fixture());
  assert.ok(document);
  document.content.profile.avatarUrl = 'https://avatars.githubusercontent.com/u/1';
  const profilePhoto = createElement('img', {
    src: '/private-preview-photo',
    alt: 'Фото владельца',
  });
  const props = { content: document.content, kind: 'resume' as const, profilePhoto, preview: true };
  const html = renderToStaticMarkup(createElement(DocumentView, props));
  assert.ok(html.includes('/private-preview-photo'));
  assert.ok(!html.includes('avatars.githubusercontent.com'));
  const publicHtml = renderToStaticMarkup(
    createElement(DocumentView, { ...props, preview: false }),
  );
  assert.ok(!publicHtml.includes('/private-preview-photo'));
  assert.ok(publicHtml.includes('avatars.githubusercontent.com'));
  document.content.blocks = document.content.blocks.filter((block) => block.kind !== 'profile');
  const hidden = renderToStaticMarkup(createElement(DocumentView, props));
  assert.ok(!hidden.includes('/private-preview-photo'));
  assert.ok(!hidden.includes('avatars.githubusercontent.com'));
});
test('real mobile aggregate and trusted backend projection agree with the public web reader', async () => {
  const fixture = JSON.parse(
    await readFile(new URL('../../../fixtures/workspace/schema6.json', import.meta.url), 'utf8'),
  );
  const backendPath = new URL('../../../firebase/functions/src/projection.mjs', import.meta.url)
    .href;
  const { projectPublicDocument } = await import(backendPath);
  for (const document of fixture.content.documents) {
    const projected = projectPublicDocument(
      fixture.content,
      document.id,
      'owner',
      publicId,
      1,
      'operation',
    ).publicDocument;
    projected.publishedAt = '2026-10-08T12:00:00Z';
    assert.ok(parsePublicDocument(projected, publicId), document.kind);
  }
});
test('public portfolio shows an attached link only while the target remains a published resume', async (t) => {
  const originalProject = process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID;
  const originalEmulator = process.env.NEXT_PUBLIC_USE_EMULATORS;
  t.after(() => {
    if (originalProject === undefined) delete process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID;
    else process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID = originalProject;
    if (originalEmulator === undefined) delete process.env.NEXT_PUBLIC_USE_EMULATORS;
    else process.env.NEXT_PUBLIC_USE_EMULATORS = originalEmulator;
  });
  process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID = 'demo-stackcard';
  process.env.NEXT_PUBLIC_USE_EMULATORS = 'false';
  const portfolio = { ...fixture(), kind: 'portfolio', attachedResumePublicId: otherId };
  (content(portfolio).blocks as { kind: string; visible: true }[]).push({
    kind: 'resume',
    visible: true,
  });
  for (const scenario of [
    { status: 200, kind: 'resume', shown: true },
    { status: 404, kind: 'resume', shown: false },
    { status: 403, kind: 'resume', shown: false },
    { status: 200, kind: 'portfolio', shown: false },
    { status: 503, kind: 'resume', shown: false },
  ]) {
    const calls: { url: string; init?: RequestInit }[] = [];
    const mock = t.mock.method(
      globalThis,
      'fetch',
      async (input: RequestInfo | URL, init?: RequestInit) => {
        const url = String(input);
        calls.push({ url, init });
        if (url.endsWith(`/publicDocuments/${publicId}`))
          return new Response(firestoreResponse(portfolio));
        assert.ok(url.endsWith(`/publicDocuments/${otherId}`));
        return scenario.status === 200
          ? new Response(
              firestoreResponse({ ...fixture(), publicId: otherId, kind: scenario.kind }),
            )
          : new Response('', { status: scenario.status });
      },
    );
    try {
      const page = await PublicDocumentPage({ params: Promise.resolve({ publicId }) });
      const html = renderToStaticMarkup(page);
      assert.equal(
        html.includes(`href="/d/${otherId}"`),
        scenario.shown,
        `${scenario.status}/${scenario.kind}`,
      );
      assert.equal(calls.length, 2);
      for (const call of calls) {
        assert.equal(call.init?.headers, undefined);
        assert.equal(call.init?.cache, 'no-store');
        assert.equal(call.init?.credentials, 'omit');
      }
    } finally {
      mock.mock.restore();
    }
  }
});
test('default public reader emulator port agrees with the canonical Firebase config', async (t) => {
  const keys = [
    'NEXT_PUBLIC_USE_EMULATORS',
    'NEXT_PUBLIC_FIRESTORE_EMULATOR_HOST',
    'NEXT_PUBLIC_FIRESTORE_EMULATOR_PORT',
  ] as const;
  const previous = Object.fromEntries(keys.map((key) => [key, process.env[key]]));
  t.after(() => {
    for (const key of keys) {
      if (previous[key] === undefined) delete process.env[key];
      else process.env[key] = previous[key];
    }
  });
  process.env.NEXT_PUBLIC_USE_EMULATORS = 'true';
  delete process.env.NEXT_PUBLIC_FIRESTORE_EMULATOR_HOST;
  delete process.env.NEXT_PUBLIC_FIRESTORE_EMULATOR_PORT;
  const config = JSON.parse(
    await readFile(new URL('../../../firebase/firebase.json', import.meta.url), 'utf8'),
  );
  let url = '';
  await readPublicDocument(publicId, {
    projectId: 'demo-stackcard',
    fetch: async (input) => {
      url = String(input);
      return new Response('', { status: 404 });
    },
  });
  assert.equal(new URL(url).port, String(config.emulators.firestore.port));
});
