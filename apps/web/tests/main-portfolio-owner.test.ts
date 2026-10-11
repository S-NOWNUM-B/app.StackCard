import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { Timestamp } from 'firebase/firestore';
import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import {
  clone,
  equal,
  emptyContent,
  createDocument,
  attachment,
  migrateMainPortfolio,
  mainDocument,
  validateWorkspace,
  resolveDocument,
  decodeDraft,
  normalizeGitHubUsername,
  deleteLibraryProject,
  importGitHubProjects,
  rebaseLibraryChange,
  withProjectEdits,
  advancePersonalization,
  safeReturnPath,
  type WorkspaceContent,
  type GitHubSource,
} from '../src/lib/model';
import { documentPreview } from '../src/lib/preview';
import { ContentEditor, appendPortfolioSkill } from '../src/components/content-editor';
import {
  ProjectForm,
  AttachmentsEditor,
  emptyProject,
  appendProjectTechnology,
} from '../src/components/project-editor';
import { loadGitHubPage, readGitHubCache, writeGitHubCache } from '../src/lib/github-repositories';
const fixture = JSON.parse(
  readFileSync(new URL('../../../fixtures/workspace/schema6.json', import.meta.url), 'utf8'),
);
const legacy = () =>
  decodeDraft(
    { ...clone(fixture), updatedAt: Timestamp.fromDate(new Date(fixture.updatedAt)) },
    'owner',
  ).content!;
const reload = (content: WorkspaceContent) =>
  decodeDraft(
    {
      schemaVersion: 7,
      ownerUid: 'owner',
      mutationId: 'test',
      localRevision: 1,
      notes: 'private',
      content,
      updatedAt: Timestamp.now(),
    },
    'owner',
  ).content!;
test('saved project acknowledgement ignores decoder key order and detects actual newer edits', () => {
  const working = migrateMainPortfolio(emptyContent(), null);
  working.projects = [
    withProjectEdits(emptyProject(), { title: 'Новый проект', iconId: 'camera' }),
  ];
  const saved = validateWorkspace(working, 'owner');
  assert.equal(equal(working, saved), true);
  const newer = clone(working);
  newer.projects[0].description = 'Правка после Save';
  assert.equal(equal(newer, saved), false);
  assert.equal(equal(['first', 'second'], ['second', 'first']), false);
});
const source: GitHubSource = {
  repositoryId: 42,
  name: 'Repository',
  fullName: 'owner/Repository',
  htmlUrl: 'https://github.com/owner/Repository',
  description: 'Описание',
  language: 'Dart',
  stars: 1,
  forks: 0,
  isFork: false,
  archived: false,
  updatedAt: '2026-10-10T00:00:00.000Z',
};
test('explicit selected migration preserves ID, private kind and exact legacy copy without mixing another document', () => {
  const w = legacy(),
    original = clone(w.documents[0]);
  w.documents[1].content.profile.bio = 'Do not merge';
  w.profile.publishLocation = false;
  const next = migrateMainPortfolio(w, original.id);
  assert.equal(next.mainPortfolioId, original.id);
  assert.equal(mainDocument(next)?.kind, original.kind);
  assert.deepEqual(next.legacyMainSnapshot, original);
  assert.equal(mainDocument(next)?.content.profile.locationText, '');
  assert.equal(mainDocument(next)?.content.profile.bio, original.content.profile.bio);
  assert.equal(mainDocument(next)?.content.links.length, 0);
  assert.deepEqual(
    mainDocument(next)?.content.blocks.map((block) => block.kind),
    [
      'profile',
      'about',
      'location',
      'featuredProjects',
      'skills',
      'experience',
      'education',
      'links',
      'github',
      'resume',
    ],
  );
  assert.equal(
    mainDocument(next)?.content.blocks.find((block) => block.kind === 'resume')?.visible,
    false,
  );
  assert.deepEqual(next.documents[1], w.documents[1]);
  assert.equal(w.mainPortfolioId, null);
  assert.deepEqual(reload(next), validateWorkspace(next, 'owner'));
});
test('twenty legacy documents survive creation of a modern main with a separate exact base archive', () => {
  const w = legacy();
  w.documents = Array.from({ length: 20 }, (_, i) => ({
    ...clone(w.documents[0]),
    id: `old-${i}`,
    attachedResumeId: null,
  }));
  const next = migrateMainPortfolio(w, null);
  assert.equal(next.documents.length, 21);
  assert.equal(next.legacyMainSnapshot?.id, 'legacy-base');
  assert.equal(next.legacyMainSnapshot?.content.profile.locationText, 'Almaty');
  assert.equal(reload(next).documents.length, 21);
});
test('legacy migration preserves all project privacy gates while modern explicit attachment uses its own visibility', () => {
  for (let mask = 0; mask < 8; mask++) {
    const workspace = legacy();
    workspace.projects[0].visible = Boolean(mask & 1);
    const original = workspace.documents[0];
    original.projects[0].visible = Boolean(mask & 2);
    original.content.blocks = original.content.blocks.map((block) =>
      block.kind === 'featuredProjects' ? { ...block, visible: Boolean(mask & 4) } : block,
    );
    const archive = clone(original);
    const migrated = reload(migrateMainPortfolio(workspace, original.id));
    const main = mainDocument(migrated)!;
    const expected = mask === 7 ? 1 : 0;
    assert.equal(main.projects.length, expected, `legacy gates ${mask}`);
    assert.equal(resolveDocument(migrated, main).projects.length, expected);
    assert.equal(documentPreview(migrated, main).projects.length, expected);
    assert.deepEqual(migrated.legacyMainSnapshot, archive);
    assert.equal(migrated.projects[0].visible, workspace.projects[0].visible);
  }
  const workspace = legacy();
  workspace.projects[0].visible = false;
  assert.equal(documentPreview(workspace, workspace.documents[0]).projects.length, 0);
  const migrated = migrateMainPortfolio(workspace, workspace.documents[0].id);
  const main = mainDocument(migrated)!;
  assert.equal(main.projects.length, 0);
  // Только последующее осознанное добавление снимает старое ограничение библиотеки.
  main.projects = [attachment(workspace.projects[0].id)];
  assert.equal(resolveDocument(migrated, main).projects[0].visible, true);
  assert.equal(documentPreview(migrated, main).projects.length, 1);
  main.projects[0].visible = false;
  assert.equal(documentPreview(migrated, main).projects.length, 0);
});
test('project deletion removes library and document relations while retaining archive references for recovery', () => {
  const migrated = migrateMainPortfolio(legacy(), fixture.content.documents[0].id),
    backup = clone(migrated.legacyMainSnapshot);
  const deleted = deleteLibraryProject(migrated, 'project');
  assert.equal(deleted.projects.length, 0);
  assert.ok(deleted.documents.every((d) => d.projects.length === 0));
  assert.deepEqual(deleted.legacyMainSnapshot, backup);
  assert.deepEqual(reload(deleted).legacyMainSnapshot, backup);
});
test('empty optional portfolio saves and all personal sections stay empty in modern output', () => {
  const workspace = migrateMainPortfolio(emptyContent(), null);
  assert.doesNotThrow(() => validateWorkspace(workspace, 'owner'));
  const p = documentPreview(workspace, mainDocument(workspace)!);
  assert.equal(p.profile.name, '');
  assert.equal(p.profile.headline, '');
  assert.equal(p.profile.avatarUrl, '');
  for (const key of ['skills', 'projects', 'experience', 'education', 'links'] as const)
    assert.equal(p[key].length, 0);
  const invalid = clone(workspace);
  mainDocument(invalid)!.content.links = [
    {
      id: 'bad',
      label: 'site',
      url: 'javascript:alert(1)',
      kind: 'website',
      publishAllowed: true,
      visible: true,
    },
  ];
  assert.throws(() => validateWorkspace(invalid, 'owner'));
});
test('saved Home remains independent of unsaved editor and explicitly added modern contacts/location bypass legacy privacy only', () => {
  const saved = migrateMainPortfolio(legacy(), fixture.content.documents[0].id),
    before = clone(documentPreview(saved, mainDocument(saved)!));
  const working = clone(saved);
  working.profile.publishLocation = false;
  working.links = [];
  mainDocument(working)!.content.profile.name = 'Unsaved';
  mainDocument(working)!.content.profile.locationText = 'Almaty / Kazakhstan';
  mainDocument(working)!.content.links = [
    {
      id: 'manual-contact',
      label: 'Почта',
      url: 'mailto:owner@example.com',
      kind: 'email',
      publishAllowed: true,
      visible: true,
    },
  ];
  const after = documentPreview(working, mainDocument(working)!);
  assert.equal(after.profile.name, 'Unsaved');
  assert.equal(after.profile.locationText, 'Almaty / Kazakhstan');
  assert.equal(after.links.length, 1);
  assert.deepEqual(documentPreview(saved, mainDocument(saved)!), before);
});
test('icon stable IDs reject SVG/URL input and survive GitHub edits and durable batch dedup', () => {
  const w = emptyContent(),
    imported = importGitHubProjects(w, [source, source]);
  assert.equal(imported.projects.length, 1);
  const edited = withProjectEdits(imported.projects[0], { title: 'My title', iconId: 'camera' });
  imported.projects = [edited];
  const repeated = importGitHubProjects(imported, [{ ...source, name: 'Remote changed' }]);
  assert.equal(repeated.projects.length, 1);
  assert.equal(repeated.projects[0].title, 'My title');
  assert.equal(repeated.projects[0].iconId, 'camera');
  assert.equal(reload(repeated).projects[0].iconId, 'camera');
  const malformed = clone(repeated);
  malformed.projects[0].iconId = 'https://evil.example/icon.svg' as never;
  assert.throws(() => validateWorkspace(malformed, 'owner'));
});
test('individual technology additions preserve raw entries and enforce model limits without CSV parsing', () => {
  const existing = [' Dart ', 'legacy, technology'];
  const added = appendProjectTechnology(existing, '  TypeScript  ');
  assert.deepEqual(added, [' Dart ', 'legacy, technology', 'TypeScript']);
  assert.deepEqual(existing, [' Dart ', 'legacy, technology']);
  assert.deepEqual(appendProjectTechnology([], 'React'), ['React']);
  for (const value of ['', '   ', '\n\t'])
    assert.throws(() => appendProjectTechnology([], value), /Введите название/);
  assert.throws(() => appendProjectTechnology([], 'React, TypeScript'), /по одной/);
  for (const value of ['DART', '  dart  '])
    assert.throws(() => appendProjectTechnology(existing, value), /уже добавлена/);
  assert.equal(appendProjectTechnology([], 'x'.repeat(60))[0].length, 60);
  assert.equal(appendProjectTechnology([], '🛠'.repeat(30))[0].length, 60);
  for (const value of ['x'.repeat(61), '🛠'.repeat(31)])
    assert.throws(() => appendProjectTechnology([], value), /60 символов/);
  const nineteen = Array.from({ length: 19 }, (_, i) => `Technology ${i}`);
  assert.equal(appendProjectTechnology(nineteen, 'Last').length, 20);
  assert.throws(() => appendProjectTechnology([...nineteen, 'Last'], 'Extra'), /20 технологий/);
});
test('technology editor renders accessible individual removal controls and an optional empty list', () => {
  const project = {
    ...emptyProject(),
    technologies: ['React', 'legacy, technology', 'x'.repeat(60)],
  };
  const html = renderToStaticMarkup(createElement(ProjectForm, { project, onChange: () => {} }));
  assert.ok(!html.includes('Технологии через запятую'));
  assert.ok(html.includes('aria-label="Технологии проекта"'));
  assert.equal((html.match(/aria-label="Удалить технологию /g) ?? []).length, 3);
  assert.ok(html.includes('legacy, technology'));
  assert.ok(html.includes('x'.repeat(60)));
  assert.ok(html.includes('technology/react.svg'));
  assert.ok(html.includes('<dialog'));
  assert.ok(html.includes('aria-label="Добавить технологию"'));
  const empty = renderToStaticMarkup(
    createElement(ProjectForm, { project: emptyProject(), onChange: () => {} }),
  );
  assert.ok(!empty.includes('aria-label="Удалить технологию '));
  assert.ok(!empty.includes('Технологии проекта'));
});
test('skill additions preserve raw names and IDs, accept one complete name and do not inherit the technology count limit', () => {
  const existing = [
    { id: 'raw-dart', name: ' Dart ' },
    { id: 'legacy-name', name: 'Планирование, коммуникация' },
  ];
  const added = appendPortfolioSkill(existing, '  Kotlin  ');
  assert.equal(added[0], existing[0]);
  assert.equal(added[1], existing[1]);
  assert.deepEqual(added.slice(0, 2), existing);
  assert.equal(added[2].name, 'Kotlin');
  assert.ok(added[2].id && !existing.some((item) => item.id === added[2].id));
  assert.equal(appendPortfolioSkill([], 'Коммуникация, презентации').length, 1);
  for (const value of ['', '  ', '\n\t'])
    assert.throws(() => appendPortfolioSkill(existing, value), /Введите название/);
  for (const value of ['DART', ' dart '])
    assert.throws(() => appendPortfolioSkill(existing, value), /уже добавлен/);
  assert.equal(appendPortfolioSkill([], 'x'.repeat(60))[0].name.length, 60);
  assert.equal(appendPortfolioSkill([], '🛠'.repeat(30))[0].name.length, 60);
  for (const value of ['x'.repeat(61), '🛠'.repeat(31)])
    assert.throws(() => appendPortfolioSkill([], value), /60 символов/);
  const many = Array.from({ length: 25 }, (_, i) => ({ id: `skill-${i}`, name: `Skill ${i}` }));
  const next = appendPortfolioSkill(many, 'More than twenty');
  assert.equal(next.length, 26);
  const workspace = migrateMainPortfolio(emptyContent(), null);
  mainDocument(workspace)!.content.skills = next;
  assert.deepEqual(reload(workspace).documents[0].content.skills, next);
});
test('owner skill tags share the technology dialog and editor sections follow the requested order', () => {
  const workspace = migrateMainPortfolio(emptyContent(), null);
  const content = mainDocument(workspace)!.content;
  content.skills = [
    { id: 'known', name: 'React' },
    { id: 'raw', name: 'Планирование, коммуникация' },
    { id: 'long', name: 'x'.repeat(60) },
  ];
  const html = renderToStaticMarkup(
    createElement(ContentEditor, {
      content,
      onChange: () => {},
      projects: createElement('div', {}, 'Project attachments'),
    }),
  );
  const headings = [
    'Контакты и ссылки',
    'Навыки',
    'Реализованные проекты',
    'Опыт работы',
    'Образование',
  ].map((label) => html.indexOf(`<h2>${label}</h2>`));
  assert.ok(
    headings.every(
      (position, index) => position >= 0 && (!index || position > headings[index - 1]),
    ),
  );
  assert.ok(html.includes('aria-label="Добавить навык"'));
  assert.ok(html.includes('aria-label="Навыки портфолио"'));
  assert.equal((html.match(/aria-label="Удалить навык /g) ?? []).length, 3);
  assert.ok(html.includes('Планирование, коммуникация'));
  assert.ok(html.includes('x'.repeat(60)));
  assert.ok(html.includes('technology/react.svg'));
  assert.ok(html.includes('dialog tag-editor-dialog'));
  assert.ok(html.includes('Отмена'));
  assert.ok(html.includes('Сохранить'));
  assert.ok(!html.includes('Навык 1'));
  assert.ok(!html.includes('value="React"'));
  assert.deepEqual(content.skills[1], { id: 'raw', name: 'Планирование, коммуникация' });
});
test('scoped import keeps adjacent unsaved portfolio input and existing project manual overrides', () => {
  const previous = migrateMainPortfolio(emptyContent(), null),
    working = clone(previous);
  mainDocument(working)!.content.profile.bio = 'Unsaved description';
  const saved = importGitHubProjects(previous, [source]);
  const rebased = rebaseLibraryChange(saved, previous, working);
  assert.equal(mainDocument(rebased)!.content.profile.bio, 'Unsaved description');
  assert.equal(mainDocument(saved)!.content.profile.bio, '');
  assert.equal(rebased.projects.length, 1);
  assert.equal(mainDocument(rebased)!.projects.length, 0);
});
test('confirmed scoped GitHub change updates an unchanged working source and retains newer source edits', () => {
  const previous = migrateMainPortfolio(emptyContent(), null);
  previous.githubUsername = 'old-source';
  const working = clone(previous);
  mainDocument(working)!.content.profile.bio = 'Unsaved description';
  const saved = { ...clone(previous), githubUsername: 'saved-source' };
  const confirmed = rebaseLibraryChange(saved, previous, working);
  assert.equal(confirmed.githubUsername, 'saved-source');
  assert.equal(mainDocument(confirmed)!.content.profile.bio, 'Unsaved description');
  working.githubUsername = 'newer-source';
  assert.equal(rebaseLibraryChange(saved, previous, working).githubUsername, 'newer-source');
});
test('all sixteen skip/next combinations persist and finish once; back and restart retain progress without inferring from values', () => {
  for (let mask = 0; mask < 16; mask++) {
    let w = migrateMainPortfolio(emptyContent(), null);
    w.personalization = { status: 'inProgress', step: 0 };
    for (let step = 0; step < 4; step++) {
      assert.equal(w.personalization.step, step);
      w = reload(advancePersonalization(w, mask & (1 << step) ? 'skip' : 'next'));
    }
    assert.equal(w.personalization.status, 'completed');
    assert.equal(mainDocument(w)!.content.profile.name, '');
    assert.deepEqual(advancePersonalization(w, 'next'), w);
  }
  let w = migrateMainPortfolio(emptyContent(), null);
  w.personalization = { status: 'inProgress', step: 2 };
  mainDocument(w)!.content.profile.name = 'Saved name';
  w = reload(advancePersonalization(w, 'back'));
  assert.equal(w.personalization.step, 1);
  assert.equal(mainDocument(w)!.content.profile.name, 'Saved name');
});
test('GitHub identity normalization stays separate from portfolio username and rejects repository and arbitrary URLs', () => {
  assert.equal(normalizeGitHubUsername('https://github.com/SNOW-NUMB/'), 'snow-numb');
  assert.equal(normalizeGitHubUsername('SNOWNUMB'), 'snownumb');
  assert.equal(normalizeGitHubUsername(''), '');
  for (const value of [
    'https://github.com/user/repo',
    'https://evil.example/user',
    'user--name',
    'https://github.com/user?x=1',
  ])
    assert.throws(() => normalizeGitHubUsername(value));
  assert.equal(safeReturnPath('/workspace#editor'), '/workspace#editor');
  assert.equal(safeReturnPath('/workspace#github-import'), '/workspace#github-import');
});
test('actual owner editor renders optional personal inputs, shared groups and no legacy geography/image/CSS controls', () => {
  const w = migrateMainPortfolio(emptyContent(), null);
  const html = renderToStaticMarkup(
    createElement(ContentEditor, { content: mainDocument(w)!.content, onChange: () => {} }),
  );
  for (const text of [
    'Имя',
    'Контакты и ссылки',
    'Навыки',
    'Опыт',
    'Образование',
    'Город / страна',
  ])
    assert.ok(html.includes(text));
  for (const text of [
    'avatarUrl',
    'URL фотографии',
    'Разрешить публикацию местоположения',
    'Username',
    'Оформление',
    'Резюме',
  ])
    assert.ok(!html.includes(text));
  assert.ok(!/required=""/.test(html));
  const pick = renderToStaticMarkup(
    createElement(AttachmentsEditor, {
      workspace: w,
      document: mainDocument(w)!,
      onChange: () => {},
      onIconChange: () => {},
      onProjects: () => {},
    }),
  );
  assert.ok(pick.includes('Добавить проект'));
  const project = renderToStaticMarkup(
    createElement(ProjectForm, { project: emptyProject(), onChange: () => {} }),
  );
  assert.ok(!project.includes('Обложка'));
  assert.ok(!project.includes('type="file"'));
});
test('real paginated GitHub request keeps query page, validates sources and exposes more pages', async () => {
  let requested = '';
  const raw = {
    id: source.repositoryId,
    name: source.name,
    full_name: source.fullName,
    html_url: source.htmlUrl,
    description: source.description,
    language: source.language,
    stargazers_count: source.stars,
    forks_count: source.forks,
    fork: source.isFork,
    archived: source.archived,
    updated_at: source.updatedAt,
  };
  const page = await loadGitHubPage('owner', 2, new AbortController().signal, (async (url) => {
    requested = String(url);
    return new Response(JSON.stringify([raw]), {
      headers: { link: '<https://api.github.com/users/owner/repos?page=3>; rel="next"' },
    });
  }) as typeof fetch);
  assert.ok(requested.includes('page=2'));
  assert.ok(requested.includes('per_page=100'));
  assert.equal(page.hasNext, true);
  assert.deepEqual(page.repositories, [source]);
  await assert.rejects(
    () =>
      loadGitHubPage(
        'owner',
        1,
        new AbortController().signal,
        (async () => new Response('', { status: 403 })) as typeof fetch,
      ),
    /ограничил/,
  );
  await assert.rejects(() =>
    loadGitHubPage(
      'owner',
      1,
      new AbortController().signal,
      (async () =>
        new Response(
          JSON.stringify([{ ...raw, html_url: 'javascript:alert(1)' }]),
        )) as typeof fetch,
    ),
  );
});
test('cached repositories are UID/profile scoped and corrupted copies are safely ignored', () => {
  const values = new Map<string, string>(),
    storage = {
      getItem: (k: string) => values.get(k) ?? null,
      setItem: (k: string, v: string) => {
        values.set(k, v);
      },
    };
  const pages = [{ page: 1, repositories: [source], hasNext: true }];
  writeGitHubCache(storage, 'owner', 'user', pages);
  assert.deepEqual(readGitHubCache(storage, 'owner', 'user'), pages);
  assert.deepEqual(readGitHubCache(storage, 'foreign', 'user'), []);
  assert.deepEqual(readGitHubCache(storage, 'owner', 'other'), []);
  values.set(
    Array.from(values.keys())[0],
    JSON.stringify({ version: 1, owner: 'foreign', username: 'user', pages }),
  );
  assert.deepEqual(readGitHubCache(storage, 'owner', 'user'), []);
});
