import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  emptyContent,
  type DocumentContent,
  type GitHubSource,
  type Project,
} from '../src/lib/model';
import { gitHubSourceFingerprint } from '../src/lib/github-fingerprint';
import {
  buildPortfolioHealth,
  healthSectionFraction,
  healthSections,
  type HealthCheckKind,
} from '../src/lib/portfolio-health';

const now = new Date('2026-11-16T12:00:00.000Z');

function project(patch: Partial<Project> = {}): Project {
  return {
    id: 'p1',
    title: 'Проект p1',
    description: 'Описание',
    contribution: '',
    technologies: ['Dart'],
    repositoryUrl: '',
    liveUrl: 'https://example.com',
    featured: false,
    visible: true,
    imagePaths: [],
    source: 'manual',
    githubMetadata: null,
    ...patch,
  };
}

function githubProject(updatedAt: string, patch: Partial<Project> = {}): Project {
  const acceptedSource: GitHubSource = {
    repositoryId: 7,
    name: 'repo',
    fullName: 'user/repo',
    htmlUrl: 'https://github.com/user/repo',
    description: null,
    language: null,
    stars: 0,
    forks: 0,
    isFork: false,
    archived: false,
    updatedAt,
  };
  return project({
    source: 'github',
    githubMetadata: { acceptedSource, lastGitHubSyncAt: null, overrideFields: [] },
    ...patch,
  });
}

function complete(): DocumentContent {
  const base = emptyContent();
  return {
    ...base,
    profile: {
      ...base.profile,
      name: 'Имя',
      headline: 'Разработчик',
      bio: 'О себе',
      avatarPath: 'a/b.jpg',
    },
    skills: [{ id: 's1', name: 'Dart' }],
    projects: [project()],
    experience: [{ id: 'e1', role: 'Dev', organization: 'Org', period: '2024', description: '' }],
    education: [
      { id: 'd1', institution: 'Uni', qualification: 'BSc', period: '2020', description: '' },
    ],
    links: [
      {
        id: 'l1',
        label: 'GitHub',
        url: 'https://github.com/example',
        kind: 'github',
        publishAllowed: true,
        visible: true,
      },
    ],
  };
}

const kinds = (content: DocumentContent, published?: boolean | null) =>
  new Set(
    buildPortfolioHealth({ content, now, published })
      .improvements.map((check) => check.kind)
      .sort(),
  );

test('пустое портфолио даёт 0 и совет на каждый раздел', () => {
  const health = buildPortfolioHealth({ content: emptyContent(), now });
  assert.equal(health.score, 0);
  assert.equal(health.isPerfect, false);
  const found = kinds(emptyContent());
  for (const kind of [
    'profileName',
    'avatar',
    'projectsAny',
    'experienceAny',
    'educationAny',
    'skillsAny',
    'contactsAny',
  ] satisfies HealthCheckKind[])
    assert.ok(found.has(kind), kind);
});

test('полное портфолио без данных о публикации даёт 100', () => {
  const health = buildPortfolioHealth({ content: complete(), now });
  assert.equal(health.score, 100);
  assert.equal(health.isPerfect, true);
  assert.equal(health.checks.filter((check) => check.section === 'publication').length, 0);
});

test('неизвестная публикация не учитывается, известная неопубликованная снижает балл', () => {
  const unpublished = buildPortfolioHealth({ content: complete(), now, published: false });
  assert.ok(unpublished.score < 100);
  assert.deepEqual([...kinds(complete(), false)], ['published']);
  assert.equal(buildPortfolioHealth({ content: complete(), now, published: true }).score, 100);
  assert.equal(buildPortfolioHealth({ content: complete(), now, published: null }).score, 100);
});

test('пробелы проектов дают советы по проекту, скрытые проекты не проверяются', () => {
  const content = complete();
  content.projects = [
    project({ description: '  ', technologies: [], liveUrl: '' }),
    project({ id: 'hidden', description: '', visible: false }),
  ];
  const tips = buildPortfolioHealth({ content, now }).improvements.filter(
    (check) => check.section === 'projects',
  );
  assert.deepEqual(tips.map((check) => check.kind).sort(), [
    'projectDescription',
    'projectLink',
    'projectTechnologies',
  ]);
  assert.ok(tips.every((check) => check.targetId === 'p1'));
});

test('одна ссылка на репозиторий считается ссылкой проекта', () => {
  const content = complete();
  content.projects = [project({ liveUrl: '', repositoryUrl: 'https://github.com/a/b' })];
  assert.equal(kinds(content).size, 0);
});

test('навык без проекта находится без учёта регистра и пробелов', () => {
  const content = complete();
  content.skills = [
    { id: 's1', name: ' dart ' },
    { id: 's2', name: 'Rust' },
  ];
  const tips = buildPortfolioHealth({ content, now }).improvements;
  assert.equal(tips.length, 1);
  assert.equal(tips[0].kind, 'skillUnused');
  assert.equal(tips[0].targetId, 's2');
});

test('без проектов навыки с проектами не сопоставляются', () => {
  const content = complete();
  content.projects = [];
  const found = kinds(content);
  assert.ok(found.has('projectsAny'));
  assert.ok(!found.has('skillUnused'));
});

test('скрытый или неразрешённый контакт не считается', () => {
  const content = complete();
  content.links = [{ ...content.links[0], visible: false }];
  assert.deepEqual([...kinds(content)], ['contactsAny']);
  content.links = [{ ...content.links[0], visible: true, publishAllowed: false }];
  assert.deepEqual([...kinds(content)], ['contactsAny']);
});

test('аватар засчитывается по пути или по URL', () => {
  const content = complete();
  content.profile = { ...content.profile, avatarPath: '', avatarUrl: 'https://example.com/a.png' };
  assert.equal(kinds(content).size, 0);
  content.profile = { ...content.profile, avatarUrl: '  ' };
  assert.deepEqual([...kinds(content)], ['avatar']);
});

test('давно не обновлявшийся GitHub-проект: порог 180 дней', () => {
  const content = complete();
  // ровно 180 дней — уже давно, 179 дней — ещё нет
  content.projects = [githubProject('2026-05-20T12:00:00.000Z')];
  assert.deepEqual([...kinds(content)], ['projectInactive']);
  content.projects = [githubProject('2026-05-21T12:00:00.000Z')];
  assert.equal(kinds(content).size, 0);
});

test('отпечаток источника совпадает со значением mobile', () => {
  // Эталон из mobile portfolio_github_sync_test.dart (DateTime.utc(2026, 10, 4)).
  const source: GitHubSource = {
    repositoryId: 42,
    name: 'stackcard',
    fullName: 'snownumb/stackcard',
    htmlUrl: 'https://github.com/snownumb/stackcard',
    description: 'Source description',
    language: 'Dart',
    stars: 12,
    forks: 3,
    isFork: false,
    archived: false,
    updatedAt: '2026-10-04T00:00:00.000Z',
  };
  assert.equal(gitHubSourceFingerprint(source), 'v1:7ae35202f179c4e8');
  // Время без миллисекунд нормализуется к виду Dart toIso8601String
  assert.equal(
    gitHubSourceFingerprint({ ...source, updatedAt: '2026-10-04T00:00:00Z' }),
    'v1:7ae35202f179c4e8',
  );
  assert.notEqual(gitHubSourceFingerprint({ ...source, stars: 13 }), 'v1:7ae35202f179c4e8');
  assert.notEqual(gitHubSourceFingerprint({ ...source, description: null }), 'v1:7ae35202f179c4e8');
});

test('игнор действует по паре repositoryId и отпечатка, как в mobile', () => {
  const content = complete();
  const old = githubProject('2025-01-01T00:00:00.000Z');
  content.projects = [old];
  assert.deepEqual([...kinds(content)], ['projectInactive']);
  const fingerprint = gitHubSourceFingerprint(old.githubMetadata!.acceptedSource);
  content.ignoredGitHubRepositories = [{ repositoryId: 7, fingerprint }];
  assert.equal(kinds(content).size, 0);
  // Источник изменился после игнора: отпечаток другой, совет возвращается
  content.ignoredGitHubRepositories = [{ repositoryId: 7, fingerprint: 'v1:0000000000000000' }];
  assert.deepEqual([...kinds(content)], ['projectInactive']);
  // Игнор другого репозитория не влияет
  content.ignoredGitHubRepositories = [{ repositoryId: 8, fingerprint }];
  assert.deepEqual([...kinds(content)], ['projectInactive']);
});

test('некорректный источник и дата из будущего не дают совет о давности', () => {
  const content = complete();
  content.projects = [githubProject('не дата')];
  assert.equal(kinds(content).size, 0);
  content.projects = [githubProject('2027-01-01T00:00:00.000Z')];
  assert.equal(kinds(content).size, 0);
});

test('ручной проект не получает совет о давности', () => {
  const content = complete();
  content.projects = [project({ updatedAt: '2020-01-01T00:00:00.000Z' })];
  assert.equal(kinds(content).size, 0);
});

test('советы идут по убыванию веса раздела, балл в пределах 0–100', () => {
  const health = buildPortfolioHealth({ content: emptyContent(), now, published: false });
  const weights = health.improvements.map((check) => healthSections[check.section].weight);
  assert.deepEqual(
    weights,
    [...weights].sort((a, b) => b - a),
  );
  assert.ok(health.score >= 0 && health.score <= 100);
});

test('балл 100 только без единого совета, иначе не больше 99', () => {
  const content = complete();
  // 1 из 7+ проверок разделов не пройдена: раздел весом 5 теряет часть, но не весь вклад
  content.profile = { ...content.profile, avatarPath: '' };
  const health = buildPortfolioHealth({ content, now });
  assert.equal(health.isPerfect, false);
  assert.ok(health.score <= 99);
  // много проверок в одном разделе: округление не должно давать 100 при замечании
  const many = complete();
  many.projects = Array.from({ length: 40 }, (_, index) =>
    project({
      id: `p${index}`,
      description: index === 0 ? '' : 'Описание',
      technologies: ['Dart'],
    }),
  );
  const manyHealth = buildPortfolioHealth({ content: many, now });
  assert.equal(manyHealth.improvements.length, 1);
  assert.equal(manyHealth.score, 99);
});

test('доля раздела считается по его проверкам, пустой раздел даёт null', () => {
  const content = complete();
  content.profile = { ...content.profile, bio: '' };
  const health = buildPortfolioHealth({ content, now });
  assert.equal(healthSectionFraction(health, 'profile'), 2 / 3);
  assert.equal(healthSectionFraction(health, 'publication'), null);
});

test('оценка детерминирована и не меняет контент', () => {
  const content = complete();
  const before = JSON.stringify(content);
  const first = buildPortfolioHealth({ content, now, published: true });
  const second = buildPortfolioHealth({ content, now, published: true });
  assert.deepEqual(first, second);
  assert.equal(JSON.stringify(content), before);
});
