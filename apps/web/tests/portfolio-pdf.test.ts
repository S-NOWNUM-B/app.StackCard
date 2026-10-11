import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { isValidElement, type ReactElement } from 'react';
import { emptyContent, seedDocument, type DocumentContent } from '../src/lib/model';
import { fetchLegacyAvatarFile, validateAvatarJpeg } from '../src/lib/portfolio-media-repository';
import {
  createPortfolioPdfDocument,
  renderPortfolioPdf,
  type PortfolioPdfAssets,
} from '../src/lib/portfolio-pdf-renderer';

const ids = ['folder', 'file-text', 'panels-top-left', 'home', 'image', 'camera', 'user-round'];
async function assets(avatar = false): Promise<PortfolioPdfAssets> {
  return {
    regularFont: resolve('public/fonts/Manrope-Regular.ttf'),
    boldFont: resolve('public/fonts/Manrope-Bold.ttf'),
    stockIconSvg: Object.fromEntries(
      await Promise.all(
        ids.map(async (id) => [id, await readFile(`public/icons/lucide/${id}.svg`, 'utf8')]),
      ),
    ),
    avatarBytes: avatar
      ? new Uint8Array(
          Buffer.from(
            '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCABAAEADASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD06iiitzEKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooA//9k=',
            'base64',
          ),
        )
      : undefined,
  };
}
function textOf(node: unknown): string {
  if (typeof node === 'string' || typeof node === 'number') return String(node);
  if (Array.isArray(node)) return node.map(textOf).join('\n');
  if (isValidElement(node))
    return textOf((node as ReactElement<{ children?: unknown }>).props.children);
  return '';
}
async function fixture(name: string, blob: Blob): Promise<void> {
  const directory = process.env.STACKCARD_PDF_FIXTURE_DIR;
  if (!directory) return;
  await mkdir(directory, { recursive: true });
  await writeFile(join(directory, name), new Uint8Array(await blob.arrayBuffer()));
}

test('PDF sections follow saved blocks and group GitHub contacts without exposing hidden links', async () => {
  const content = seedDocument(emptyContent());
  content.skills = [{ id: 'skill', name: 'SKILL_CONTENT' }];
  content.experience = [
    { id: 'work', role: 'ROLE_CONTENT', organization: 'Studio', period: '', description: '' },
  ];
  content.education = [
    {
      id: 'edu',
      institution: 'University',
      qualification: 'EDUCATION_CONTENT',
      period: '',
      description: '',
    },
  ];
  content.projects = [
    {
      id: 'project',
      title: 'PROJECT_CONTENT',
      description: '',
      contribution: '',
      technologies: [],
      repositoryUrl: '',
      liveUrl: '',
      featured: false,
      visible: true,
      source: 'manual',
      githubMetadata: null,
      imagePaths: [],
      iconId: 'folder',
    },
  ];
  content.links = [
    {
      id: 'site',
      label: 'CONTACT_CONTENT',
      url: 'https://example.com',
      kind: 'website',
      visible: true,
      publishAllowed: true,
    },
    {
      id: 'github',
      label: 'GITHUB_CONTENT',
      url: 'https://github.com/example',
      kind: 'github',
      visible: true,
      publishAllowed: true,
    },
    {
      id: 'hidden',
      label: 'HIDDEN_CONTACT',
      url: 'https://hidden.example',
      kind: 'website',
      visible: false,
      publishAllowed: true,
    },
  ];
  const loaded = await assets();
  for (const order of [
    ['education', 'featuredProjects', 'links', 'experience', 'skills'],
    ['skills', 'links', 'featuredProjects', 'education', 'experience'],
  ] as const) {
    content.blocks = [
      ...order.map((kind) => ({ kind, visible: true })),
      { kind: 'github', visible: true },
    ];
    const text = textOf(await createPortfolioPdfDocument(content, loaded));
    const marker = {
      education: 'EDUCATION_CONTENT',
      featuredProjects: 'PROJECT_CONTENT',
      links: 'CONTACT_CONTENT',
      experience: 'ROLE_CONTENT',
      skills: 'SKILL_CONTENT',
    };
    const positions = order.map((kind) => text.indexOf(marker[kind]));
    assert.ok(positions.every((p, i) => p >= 0 && (!i || p > positions[i - 1])));
    assert.ok(text.indexOf('GITHUB_CONTENT') > text.indexOf('CONTACT_CONTENT'));
    assert.ok(!text.includes('HIDDEN_CONTACT'));
  }
  content.blocks = content.blocks.filter((block) => block.kind !== 'github');
  assert.ok(!textOf(await createPortfolioPdfDocument(content, loaded)).includes('GITHUB_CONTENT'));
});

test('empty PDF is a real document with no artificial headings or placeholder identity', async () => {
  const content = seedDocument(emptyContent());
  const loaded = await assets();
  const text = textOf(await createPortfolioPdfDocument(content, loaded));
  assert.equal(text.trim(), '');
  const blob = await renderPortfolioPdf(content, loaded);
  assert.equal(blob.type, 'application/pdf');
  const source = Buffer.from(await blob.arrayBuffer()).toString('latin1');
  assert.ok(source.startsWith('%PDF-'));
  assert.equal([...source.matchAll(/\/Type\s*\/Page\b/g)].length, 1);
  assert.ok(!source.includes('/Subtype /Image'));
  await fixture('web-empty.pdf', blob);
});

test('available validated legacy URL photo embeds in a real PDF without a media path', async () => {
  const content = seedDocument(emptyContent());
  content.profile.avatarUrl = 'https://avatars.githubusercontent.com/u/583231?v=4';
  const loaded = await assets(true);
  const file = await fetchLegacyAvatarFile(content.profile.avatarUrl, {
    fetcher: async () =>
      new Response(loaded.avatarBytes!.slice().buffer, {
        headers: { 'content-type': 'image/jpeg' },
      }),
  });
  const bytes = new Uint8Array(await file.arrayBuffer());
  validateAvatarJpeg(bytes);
  const blob = await renderPortfolioPdf(content, { ...loaded, avatarBytes: bytes });
  const source = Buffer.from(await blob.arrayBuffer()).toString('latin1');
  assert.ok(source.startsWith('%PDF-'));
  assert.ok(source.includes('/Subtype /Image'));
  await assert.rejects(
    renderPortfolioPdf(content, { ...loaded, avatarBytes: undefined }),
    /фотографию/,
  );
});

test('long Cyrillic PDF uses embedded font, multiple pages, URI links, avatar and all pinned icons', async () => {
  const content: DocumentContent = seedDocument(emptyContent());
  content.profile = {
    ...content.profile,
    name: 'Анна Ёлкина',
    headline: 'Разработчик приложений',
    bio: 'Сохранённое портфолио с кириллицей.',
    locationText: 'Алматы, Казахстан',
    publishLocation: true,
    avatarPath: 'accounts/test-owner/media/0123456789abcdef0123456789abcdef.jpg',
  };
  content.projects = ids.map((id) => ({
    id,
    iconId: id as 'folder',
    title: `Проект ${id}`,
    description:
      id === 'folder'
        ? 'Длинное описание проекта на русском языке: перенос текста не теряет содержание. '.repeat(
            180,
          )
        : 'Описание проекта.',
    contribution: '',
    technologies: ['Flutter', 'TypeScript'],
    liveUrl: `https://example.com/${id}`,
    repositoryUrl: `https://github.com/example/${id}`,
    featured: false,
    visible: true,
    source: 'manual',
    githubMetadata: null,
    imagePaths: ['LEGACY_PROJECT_IMAGE_MUST_NOT_EXPORT'],
  }));
  content.projects.push({
    ...content.projects[0],
    id: 'hidden',
    title: 'SECRET_PROJECT',
    visible: false,
  });
  content.links = [
    {
      id: 'site',
      label: 'Сайт',
      url: 'https://example.com/contact',
      kind: 'website',
      publishAllowed: true,
      visible: true,
    },
    {
      id: 'email',
      label: 'Почта',
      url: 'mailto:anna@example.com',
      kind: 'email',
      publishAllowed: true,
      visible: true,
    },
    {
      id: 'private',
      label: 'PRIVATE_CONTACT',
      url: 'https://secret.example.com',
      kind: 'website',
      publishAllowed: false,
      visible: true,
    },
  ];
  const loaded = await assets(true);
  const text = textOf(await createPortfolioPdfDocument(content, loaded));
  assert.ok(text.includes('Анна Ёлкина'));
  assert.ok(!text.includes('SECRET_PROJECT'));
  assert.ok(!text.includes('PRIVATE_CONTACT'));
  assert.ok(!text.includes('LEGACY_PROJECT_IMAGE_MUST_NOT_EXPORT'));
  assert.ok(!text.includes('Образование'));
  const blob = await renderPortfolioPdf(content, loaded);
  const source = Buffer.from(await blob.arrayBuffer()).toString('latin1');
  assert.ok([...source.matchAll(/\/Type\s*\/Page\b/g)].length > 1);
  assert.ok(source.includes('/ToUnicode'));
  assert.ok(source.includes('/Subtype /Image'));
  assert.ok(source.includes('https://example.com/contact'));
  assert.ok(source.includes('mailto:anna@example.com'));
  assert.ok(!source.includes('secret.example.com'));
  await fixture('web-long.pdf', blob);
});

test('missing or invalid saved photo fails instead of silently exporting incomplete PDF', async () => {
  const content = seedDocument(emptyContent());
  content.profile.avatarPath = 'accounts/test-owner/media/0123456789abcdef0123456789abcdef.jpg';
  const loaded = await assets();
  await assert.rejects(renderPortfolioPdf(content, loaded), /фотографию/i);
  await assert.rejects(
    renderPortfolioPdf(content, { ...loaded, avatarBytes: new Uint8Array([1, 2, 3]) }),
    /формат/i,
  );
});

test('legacy hidden photo and location remain outside the document output', async () => {
  const content = seedDocument(emptyContent());
  content.profile.avatarPath = 'accounts/test-owner/media/0123456789abcdef0123456789abcdef.jpg';
  content.profile.locationText = 'PRIVATE_CITY';
  content.profile.publishLocation = false;
  content.blocks = [
    { kind: 'profile', visible: false },
    { kind: 'location', visible: true },
  ];
  const loaded = await assets();
  assert.ok(!textOf(await createPortfolioPdfDocument(content, loaded)).includes('PRIVATE_CITY'));
  const blob = await renderPortfolioPdf(content, loaded);
  await fixture('web-private.pdf', blob);
});
