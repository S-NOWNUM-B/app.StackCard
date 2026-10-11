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
  safePublicSocialMedia,
} from '../src/lib/public-document';

const publicId = 'a'.repeat(32);
const otherId = 'b'.repeat(32);
const jpeg =
  'data:image/jpeg;base64,/9j/2wBDAAYEBQYFBAYGBQYHBwYIChAKCgkJChQODwwQFxQYGBcUFhYaHSUfGhsjHBYWICwgIyYnKSopGR8tMC0oMCUoKSj/2wBDAQcHBwoIChMKChMoGhYaKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCj/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAj/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFAEBAAAAAAAAAAAAAAAAAAAAAP/EABQRAQAAAAAAAAAAAAAAAAAAAAD/2gAMAwEAAhEDEQA/AKpAB//Z';
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
function modernFixture(): Record<string, unknown> {
  const data = { ...fixture(), schemaVersion: 2, kind: 'portfolio' };
  for (const project of content(data).projects as Record<string, unknown>[]) {
    delete project.imageUrls;
    project.iconId = 'folder';
  }
  return data;
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

test('schema2 public reader renders saved section order with GitHub grouped into visible contacts', () => {
  const data = modernFixture();
  data.schemaVersion = 2;
  data.kind = 'portfolio';
  const content = data.content as Record<string, unknown>;
  content.resumeText = '';
  content.blocks = [
    'profile',
    'about',
    'location',
    'education',
    'links',
    'github',
    'featuredProjects',
    'skills',
    'experience',
  ].map((kind) => ({ kind, visible: true }));
  content.links = [
    { id: 'site', label: 'Site', url: 'https://example.com/site', kind: 'website' },
    { id: 'github', label: 'GitHub', url: 'https://github.com/example', kind: 'github' },
  ];
  const parsed = parsePublicDocument(data, publicId);
  assert.ok(parsed);
  const html = renderToStaticMarkup(
    createElement(DocumentView, {
      content: parsed.content,
      kind: 'portfolio',
      modernPortfolio: true,
    }),
  );
  const positions = ['Образование', 'Контакты', 'Проекты', 'Навыки', 'Опыт'].map((label) =>
    html.indexOf(label),
  );
  assert.ok(positions.every((position, i) => position >= 0 && (!i || position > positions[i - 1])));
  assert.equal((html.match(/href="https:\/\/github.com\/example"/g) ?? []).length, 1);
  assert.ok(html.indexOf('https://github.com/example') < html.indexOf('Проекты'));
  parsed.content.blocks = parsed.content.blocks.filter((block) => block.kind !== 'github');
  const hidden = renderToStaticMarkup(
    createElement(DocumentView, {
      content: parsed.content,
      kind: 'portfolio',
      modernPortfolio: true,
    }),
  );
  assert.ok(!hidden.includes('href="https://github.com/example"'));
});

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
  assert.equal(parsePublicDocument({ ...fixture(), schemaVersion: 3 }), null);
  assert.equal(parsePublicDocument(fixture(), otherId), null);
  assert.equal(parsePublicDocument({ ...fixture(), publishedAt: null }), null);
});
test('schema2 accepts the modern portfolio allowlist and rejects legacy fields or arbitrary icons', () => {
  const data = modernFixture();
  const project = (content(data).projects as Record<string, unknown>[])[0];
  for (const iconId of [
    'folder',
    'file-text',
    'panels-top-left',
    'home',
    'image',
    'camera',
    'user-round',
  ]) {
    project.iconId = iconId;
    const document = parsePublicDocument(data);
    assert.ok(document);
    assert.equal(document.schemaVersion, 2);
    assert.equal(document.content.projects[0].iconId, iconId);
    assert.ok(!Object.hasOwn(document.content.projects[0], 'imageUrls'));
  }
  for (const iconId of ['../private', 'https://evil.test/icon.svg', '<svg>', 'unknown', null]) {
    project.iconId = iconId;
    assert.equal(parsePublicDocument(data), null);
  }
  project.iconId = 'folder';
  project.imageUrls = [];
  assert.equal(parsePublicDocument(data), null);
  delete project.imageUrls;
  delete project.iconId;
  assert.equal(parsePublicDocument(data), null);
  assert.equal(parsePublicDocument({ ...modernFixture(), kind: 'resume' }), null);
  assert.equal(parsePublicDocument({ ...modernFixture(), attachedResumePublicId: otherId }), null);
  const resume = modernFixture();
  content(resume).resumeText = 'Legacy text';
  (content(resume).blocks as Record<string, unknown>[]).push({ kind: 'resume', visible: true });
  assert.equal(parsePublicDocument(resume), null);
});
test('legacy project images are validated then discarded while the public URL remains readable', () => {
  const data = fixture();
  (content(data).projects as Record<string, unknown>[])[0].imageUrls = [
    'https://images.unsplash.com/legacy-project',
  ];
  const document = parsePublicDocument(data, publicId);
  assert.ok(document);
  assert.equal(document.schemaVersion, 1);
  assert.equal(document.content.projects[0].iconId, 'folder');
  assert.ok(!Object.hasOwn(document.content.projects[0], 'imageUrls'));
  const html = renderToStaticMarkup(
    createElement(DocumentView, { content: document.content, kind: document.kind }),
  );
  assert.ok(!html.includes('legacy-project'));
  assert.ok(!html.includes('project-image'));
  assert.ok(html.includes('/icons/lucide/folder.svg'));
  assert.ok(html.includes('document-project-row'));
});
test('bounded canonical JPEG avatars render inline but are never social metadata images', () => {
  const data = modernFixture();
  (content(data).profile as Record<string, unknown>).avatarUrl = jpeg;
  const document = parsePublicDocument(data);
  assert.ok(document);
  assert.equal(safePublicMedia(jpeg), jpeg);
  assert.equal(safePublicSocialMedia(jpeg), null);
  const html = renderToStaticMarkup(
    createElement(DocumentView, { content: document.content, kind: document.kind }),
  );
  assert.ok(html.includes(`src="${jpeg}"`));
  assert.ok(html.includes('width="128"'));
  for (const value of [
    'data:image/svg+xml;base64,PHN2Zz4=',
    'data:image/jpeg;base64,PHN2Zz4=',
    jpeg.replace('/9j/', '/9j_'),
    `${jpeg}\n`,
    jpeg.slice(0, -4),
    jpeg.replace('base64,', 'base64, '),
    `data:image/jpeg;base64,${Buffer.alloc(256 * 1024 + 1).toString('base64')}`,
  ]) {
    assert.equal(safePublicMedia(value), null);
    (content(data).profile as Record<string, unknown>).avatarUrl = value;
    assert.equal(parsePublicDocument(data), null);
  }
});
test('REST reader preserves bounded inline JPEG strings larger than the former generic string limit', async () => {
  const data = modernFixture();
  const bytes = Buffer.alloc(256 * 1024);
  bytes.set([0xff, 0xd8, 0xff], 0);
  bytes.set([0xff, 0xd9], bytes.length - 2);
  const avatar = `data:image/jpeg;base64,${bytes.toString('base64')}`;
  (content(data).profile as Record<string, unknown>).avatarUrl = avatar;
  const document = await readPublicDocument(publicId, {
    projectId: 'demo-stackcard',
    fetch: async () => new Response(firestoreResponse(data)),
  });
  assert.ok(document);
  assert.equal(document.content.profile.avatarUrl, avatar);
  const tooLarge = Buffer.concat([bytes.subarray(0, -2), Buffer.from([0, 0xff, 0xd9])]);
  assert.equal(safePublicMedia(`data:image/jpeg;base64,${tooLarge.toString('base64')}`), null);
});
test('empty public sections omit their headings, separators and artificial profile placeholders', () => {
  const data = modernFixture();
  const c = content(data);
  c.profile = { name: '', username: '', headline: '', bio: '', locationText: '', avatarUrl: '' };
  for (const key of ['skills', 'projects', 'experience', 'education', 'links']) c[key] = [];
  const document = parsePublicDocument(data);
  assert.ok(document);
  const html = renderToStaticMarkup(
    createElement(DocumentView, { content: document.content, kind: document.kind }),
  );
  for (const omitted of [
    'document-section',
    'document-profile',
    '<h1',
    '<h2',
    '<h3',
    '<img',
    'Имя не указано',
    'Нет фото',
  ])
    assert.ok(!html.includes(omitted), omitted);
});
test('project rows retain their catalog icon and text without gallery or large metadata', () => {
  const data = modernFixture();
  const project = (content(data).projects as Record<string, unknown>[])[0];
  project.iconId = 'camera';
  project.liveUrl = 'https://example.com/live';
  const document = parsePublicDocument(data);
  assert.ok(document);
  const html = renderToStaticMarkup(
    createElement(DocumentView, { content: document.content, kind: document.kind }),
  );
  assert.ok(html.includes('/icons/lucide/camera.svg'));
  assert.ok(html.includes('href="https://example.com/live"'));
  assert.ok(html.includes('rel="noopener noreferrer nofollow"'));
  assert.ok(html.includes('href="https://github.com/example/atlas"'));
  assert.ok(!html.includes('Design'));
  assert.ok(!html.includes('technology-badges'));
  document.content.projects[0].iconId = '../unsafe' as 'folder';
  const safe = renderToStaticMarkup(
    createElement(DocumentView, { content: document.content, kind: document.kind }),
  );
  assert.ok(safe.includes('/icons/lucide/folder.svg'));
  assert.ok(!safe.includes('../unsafe'));
});
test('repository and product links render independently after the full project description', () => {
  const description = 'Полное описание проекта '.repeat(30) + '\nПоследняя строка описания';
  for (const scenario of [
    { repository: '', product: '' },
    { repository: 'https://github.com/example/atlas', product: '' },
    { repository: '', product: 'https://example.com/live' },
    { repository: 'https://github.com/example/atlas', product: 'https://example.com/live' },
  ]) {
    const document = parsePublicDocument(modernFixture());
    assert.ok(document);
    Object.assign(document.content.projects[0], {
      description,
      repositoryUrl: scenario.repository,
      liveUrl: scenario.product,
    });
    const html = renderToStaticMarkup(
      createElement(DocumentView, { content: document.content, kind: document.kind }),
    );
    const projectHtml = html.match(/<div class="document-project-row">([\s\S]*?)<\/section>/)?.[1];
    assert.ok(projectHtml);
    assert.ok(projectHtml.includes(`<h3>Atlas</h3><p>${description}</p>`));
    const count = Number(!!scenario.repository) + Number(!!scenario.product);
    assert.equal((projectHtml.match(/<a /g) ?? []).length, count);
    assert.equal(projectHtml.includes('document-project-links'), count > 0);
    assert.equal(projectHtml.includes('/icons/lucide/github.svg'), !!scenario.repository);
    assert.equal(projectHtml.includes('/icons/lucide/globe.svg'), !!scenario.product);
    for (const [href, label] of [
      [scenario.repository, 'Репозиторий'],
      [scenario.product, 'Продукт'],
    ]) {
      assert.equal(projectHtml.includes(`aria-label="${label} проекта Atlas"`), !!href);
      if (href) {
        assert.ok(projectHtml.includes(`href="${href}" target="_blank"`));
        assert.ok(projectHtml.indexOf(description) < projectHtml.indexOf(`href="${href}"`));
      }
    }
    assert.equal((projectHtml.match(/rel="noopener noreferrer nofollow"/g) ?? []).length, count);
    assert.ok(!html.includes('<a class="document-project-row"'));
  }
});
test('project renderer trims safe URLs and omits unsafe actions independently', () => {
  for (const scenario of [
    { repository: '   ', product: '', expected: [] },
    {
      repository: 'javascript:alert(1)',
      product: ' https://example.com/live ',
      expected: ['https://example.com/live'],
    },
    {
      repository: ' https://github.com/example/atlas ',
      product: 'https://user:secret@example.com',
      expected: ['https://github.com/example/atlas'],
    },
    { repository: 'javascript:alert(1)', product: '//evil.test', expected: [] },
  ]) {
    const document = parsePublicDocument(modernFixture());
    assert.ok(document);
    Object.assign(document.content.projects[0], {
      repositoryUrl: scenario.repository,
      liveUrl: scenario.product,
    });
    const html = renderToStaticMarkup(
      createElement(DocumentView, { content: document.content, kind: document.kind }),
    );
    const projectHtml = html.match(/<div class="document-project-row">([\s\S]*?)<\/section>/)?.[1];
    assert.ok(projectHtml);
    assert.deepEqual(
      [...projectHtml.matchAll(/href="([^"]+)"/g)].map((match) => match[1]),
      scenario.expected,
    );
    assert.equal(projectHtml.includes('document-project-links'), scenario.expected.length > 0);
    for (const omitted of ['javascript:', 'secret', 'evil.test'])
      assert.ok(!projectHtml.includes(omitted));
  }
});
test('modern Home opts into city before biography while existing public and legacy headers keep their order', () => {
  const document = parsePublicDocument(modernFixture());
  assert.ok(document);
  const home = renderToStaticMarkup(
    createElement(DocumentView, {
      content: document.content,
      kind: document.kind,
      modernPortfolio: true,
      preview: true,
    }),
  );
  const positions = ['<h1>Alex</h1>', '<h3>Developer</h3>', 'Алматы', 'Public biography'].map(
    (text) => home.indexOf(text),
  );
  assert.ok(
    positions.every(
      (position, index) => position >= 0 && (!index || position > positions[index - 1]),
    ),
  );
  assert.ok(home.includes('document-profile modern-profile'));
  assert.ok(home.includes('class="profile-bio"'));
  for (const data of [fixture(), modernFixture()]) {
    const existing = parsePublicDocument(data);
    assert.ok(existing);
    const html = renderToStaticMarkup(
      createElement(DocumentView, { content: existing.content, kind: existing.kind }),
    );
    assert.ok(html.indexOf('Public biography') < html.indexOf('Алматы'));
    assert.ok(!html.includes('modern-profile'));
    assert.ok(!html.includes('profile-bio'));
  }
  document.content.blocks = document.content.blocks.filter(
    (block) => block.kind !== 'location' && block.kind !== 'about',
  );
  const hidden = renderToStaticMarkup(
    createElement(DocumentView, {
      content: document.content,
      kind: document.kind,
      modernPortfolio: true,
      preview: true,
    }),
  );
  assert.ok(!hidden.includes('Алматы'));
  assert.ok(!hidden.includes('Public biography'));
  assert.ok(hidden.includes('<h1>Alex</h1>'));
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
test('both public schemas require biography and location to be cleared when their blocks are absent', () => {
  for (const makeFixture of [fixture, modernFixture]) {
    for (const [kind, field] of [
      ['about', 'bio'],
      ['location', 'locationText'],
    ] as const) {
      const data = makeFixture();
      const c = content(data);
      c.blocks = (c.blocks as { kind: string; visible: true }[]).filter(
        (block) => block.kind !== kind,
      );
      assert.equal(parsePublicDocument(data, publicId), null);
      (c.profile as Record<string, unknown>)[field] = '';
      const projected = parsePublicDocument(data, publicId);
      assert.ok(projected);
      assert.equal(projected.content.profile[field], '');
      assert.deepEqual(projected.content.blocks, c.blocks);
    }
  }
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
test('malformed IDs/config do not request any document and config failure is unavailable', async () => {
  let requests = 0;
  const fetcher: typeof fetch = async () => {
    requests++;
    return new Response('');
  };
  assert.equal(
    await readPublicDocument('../accounts', { projectId: 'demo-stackcard', fetch: fetcher }),
    null,
  );
  await assert.rejects(
    () => readPublicDocument(publicId, { projectId: '../../accounts', fetch: fetcher }),
    PublicDocumentUnavailable,
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
test('renderer escapes author text and shows saved dark content in light without mutating it', () => {
  const data = fixture();
  (content(data).profile as Record<string, unknown>).bio = '<script>alert("unsafe")</script>';
  content(data).theme = 'dark';
  const document = parsePublicDocument(data);
  assert.ok(document);
  const original = structuredClone(document.content);
  const html = renderToStaticMarkup(
    createElement(DocumentView, { content: document.content, kind: document.kind }),
  );
  assert.ok(html.includes('data-theme="light"'));
  assert.deepEqual(document.content, original);
  assert.equal(document.content.theme, 'dark');
  assert.ok(html.includes('&lt;script&gt;'));
  assert.ok(!html.includes('<script>'));
  assert.ok(html.includes('mailto:hello@example.com'));
  assert.ok(html.includes('Atlas'));
  assert.ok(html.includes('Навыки'));
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
