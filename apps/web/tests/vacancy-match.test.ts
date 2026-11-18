import { test } from 'node:test';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import {
  attachment,
  emptyContent,
  type DocumentContent,
  type Experience,
  type PortfolioDocument,
  type Project,
} from '../src/lib/model';
import {
  applyVacancyOrder,
  buildVacancyExportContent,
  defaultVacancyDictionary,
  findVacancyTerms,
  matchVacancy,
  vacancyBlocks,
} from '../src/lib/vacancy-match';

// Сценарии перенесены из mobile test/vacancy_match_test.dart.
function project(
  id: string,
  patch: { title?: string; description?: string; technologies?: string[]; visible?: boolean } = {},
): Project {
  return {
    id,
    title: patch.title ?? 'Проект',
    description: patch.description ?? '',
    contribution: '',
    technologies: patch.technologies ?? [],
    repositoryUrl: '',
    liveUrl: '',
    featured: false,
    visible: patch.visible ?? true,
    imagePaths: [],
    source: 'manual',
    githubMetadata: null,
  };
}

function experience(id: string, patch: Partial<Experience> = {}): Experience {
  return { id, role: '', organization: 'Org', period: '2024', description: '', ...patch };
}

function content(
  patch: {
    skills?: string[];
    projects?: Project[];
    experience?: Experience[];
    headline?: string;
    blocks?: DocumentContent['blocks'];
  } = {},
): DocumentContent {
  const base = emptyContent();
  return {
    ...base,
    profile: { ...base.profile, headline: patch.headline ?? '' },
    skills: (patch.skills ?? []).map((name) => ({ id: `s-${name}`, name })),
    projects: patch.projects ?? [],
    experience: patch.experience ?? [],
    blocks: patch.blocks ?? base.blocks,
  };
}

const ids = (text: string) => new Set(findVacancyTerms(text).map((term) => term.id));
const set = (...values: string[]) => new Set(values);

test('регистр, знаки и версии не мешают', () => {
  assert.deepEqual(
    ids('Требуется: Node 20, REACT!, TypeScript.'),
    set('node', 'react', 'typescript'),
  );
});

test('синонимы сводятся к одному термину', () => {
  assert.deepEqual(ids('js, JavaScript, ECMAScript'), set('javascript'));
  assert.deepEqual(ids('k8s и Kubernetes'), set('kubernetes'));
  assert.deepEqual(ids('Postgres / PostgreSQL'), set('postgresql'));
  assert.deepEqual(ids('ts'), set('typescript'));
  assert.deepEqual(ids('Spring Boot'), set('spring'));
});

test('специальные написания: c++, c#, .net, node.js, ci/cd', () => {
  assert.deepEqual(ids('опыт c++ и C#, .NET, Node.js'), set('cpp', 'csharp', 'dotnet', 'node'));
  assert.deepEqual(ids('настройка CI/CD'), set('cicd'));
});

test('смесь RU и EN, ё и склонения роли', () => {
  assert.deepEqual(
    ids('Ищем мобильного разработчика: Флаттер, Dart, Докер'),
    set('mobile', 'flutter', 'dart', 'docker'),
  );
  assert.deepEqual(ids('Фронтенд и бэкенд'), set('frontend', 'backend'));
});

test('части слов не считаются совпадением', () => {
  assert.equal(ids('javascripty reactive typescripts').size, 0);
});

test('пустой и короткий текст без требований', () => {
  assert.equal(findVacancyTerms('').length, 0);
  assert.equal(findVacancyTerms('   \n  ').length, 0);
});

test('очень длинные слова и огромный текст не ломают разбор', () => {
  const long = 'a'.repeat(500);
  assert.deepEqual(ids(`${long} react ${long}`), set('react'));
  // Текст обрезается по лимиту: хвост за пределом не учитывается.
  assert.equal(ids('слово '.repeat(50000) + 'docker').size, 0);
  assert.deepEqual(ids('docker ' + 'слово '.repeat(50000)), set('docker'));
});

test('сто и больше строк разбираются целиком', () => {
  const lines = Array.from({ length: 150 }, (_, index) => `Строка ${index} требования`);
  assert.deepEqual(ids([...lines, 'Flutter'].join('\n')), set('flutter'));
});

test('версия слитно и связки через плюс разбираются', () => {
  assert.deepEqual(ids('Python3, Vue3 и Java17'), set('python', 'vue', 'java'));
  assert.deepEqual(ids('React+Redux, HTML+CSS'), set('react', 'html', 'css'));
});

test('русские формы слов и Golang', () => {
  assert.deepEqual(ids('разработка мобильных приложений'), set('mobile'));
  assert.deepEqual(ids('опыт бэкенда и работы в докере'), set('backend', 'docker'));
  assert.deepEqual(ids('Golang developer'), set('go'));
});

test('обычные слова не дают ложных требований', () => {
  assert.equal(ids('Next steps: the rest of the team will test').size, 0);
});

test('считает 5 из 8 и делит на совпавшие и недостающие', () => {
  const match = matchVacancy({
    vacancyText: 'Dart, Flutter, Firebase, Docker, Kubernetes, Postgres, Git, Linux',
    content: content({
      skills: ['Dart', 'Flutter', 'Git'],
      projects: [project('p', { technologies: ['Firebase', 'PostgreSQL'] })],
    }),
  });
  assert.equal(match.totalCount, 8);
  assert.equal(match.matchedCount, 5);
  assert.equal(match.percent, 63);
  assert.deepEqual(
    new Set(match.missingRequirements.map((item) => item.term.id)),
    set('docker', 'kubernetes', 'linux'),
  );
});

test('синоним в портфолио совпадает с вакансией', () => {
  const match = matchVacancy({
    vacancyText: 'Нужен Kubernetes и JavaScript',
    content: content({ skills: ['k8s', 'js'] }),
  });
  assert.equal(match.percent, 100);
});

test('пустое портфолио: все требования отсутствуют, без падений', () => {
  const match = matchVacancy({ vacancyText: 'React, Node 20', content: content() });
  assert.equal(match.percent, 0);
  assert.equal(match.totalCount, 2);
  assert.equal(match.projects.length, 0);
  assert.equal(match.experience.length, 0);
});

test('вакансия без известных требований: процент 0, флаг noRequirements', () => {
  const match = matchVacancy({
    vacancyText: 'Мы дружная команда и любим кофе по пятницам',
    content: content({ skills: ['Dart'] }),
  });
  assert.equal(match.noRequirements, true);
  assert.equal(match.percent, 0);
});

test('нет ни одного совпадения', () => {
  const match = matchVacancy({
    vacancyText: 'Rust и Kafka',
    content: content({ skills: ['Dart'] }),
  });
  assert.equal(match.matchedCount, 0);
  assert.equal(match.percent, 0);
});

test('Go: разные написания распознаются, навык «Go» не теряется', () => {
  assert.deepEqual(ids('Go-разработчик'), set('go'));
  assert.deepEqual(ids('Go developer в команду'), set('go'));
  assert.deepEqual(ids('Go/Golang, Docker'), set('go', 'docker'));
  for (const vacancy of ['Golang developer', 'Go-разработчик', 'Go/Golang']) {
    const match = matchVacancy({ vacancyText: vacancy, content: content({ skills: ['Go'] }) });
    assert.equal(match.percent, 100, vacancy);
  }
  const noSkill = matchVacancy({
    vacancyText: 'Go developer',
    content: content({ skills: ['Dart'] }),
  });
  assert.equal(noSkill.percent, 0);
  // Обычное слово «go» не создаёт требование даже при навыке Go.
  assert.equal(
    matchVacancy({
      vacancyText: 'We go to market fast, no stack listed here at all',
      content: content({ skills: ['Go'] }),
    }).noRequirements,
    true,
  );
});

test('составной термин не дублируется коротким', () => {
  assert.deepEqual(ids('React Native разработчик'), set('react native'));
  assert.deepEqual(ids('React Native и React'), set('react native', 'react'));
  assert.deepEqual(ids('React, затем React Native'), set('react', 'react native'));
  const onlyNative = matchVacancy({
    vacancyText: 'React Native developer',
    content: content({ skills: ['React Native'] }),
  });
  assert.equal(onlyNative.totalCount, 1);
  assert.equal(onlyNative.percent, 100);
  // Навык «React Native» не закрывает отдельное требование «React».
  const both = matchVacancy({
    vacancyText: 'React Native и React',
    content: content({ skills: ['React Native'] }),
  });
  assert.equal(both.totalCount, 2);
  assert.equal(both.matchedCount, 1);
});

test('«Go backend» не прячет роль Backend', () => {
  assert.deepEqual(ids('Go backend разработчик'), set('backend'));
  assert.deepEqual(ids('Go developer, backend'), set('go', 'backend'));
});

test('«React JS» не даёт отдельного требования JavaScript', () => {
  assert.deepEqual(ids('React JS developer'), set('react'));
  assert.deepEqual(ids('Node JS и JS'), set('node', 'javascript'));
  const match = matchVacancy({
    vacancyText: 'React JS developer',
    content: content({ skills: ['React'] }),
  });
  assert.equal(match.percent, 100);
});

test('поля портфолио разбираются раздельно', () => {
  // Организация не делает технологией; граница полей не склеивает слова.
  const match = matchVacancy({
    vacancyText: 'Нужны Swift и Go developer',
    content: content({
      projects: [project('p', { title: 'Go', description: 'developer portal' })],
      experience: [experience('e', { role: 'Менеджер', organization: 'Swift Logistics' })],
    }),
  });
  assert.equal(match.matchedCount, 0);
  assert.equal(match.experience[0].score, 0);
});

test('навыки вне вакансии не меняют процент и не создают требований', () => {
  const vacancy = 'Нужны Dart и Zustand, а также Kafka';
  const bare = matchVacancy({ vacancyText: vacancy, content: content({ skills: ['Dart'] }) });
  const padded = matchVacancy({
    vacancyText: vacancy,
    content: content({ skills: ['Dart', 'Zustand', 'Figma', 'Rust', 'Agile'] }),
  });
  assert.equal(padded.totalCount, bare.totalCount);
  assert.equal(padded.matchedCount, bare.matchedCount);
  assert.equal(padded.percent, bare.percent);
  assert.deepEqual(
    padded.requirements.map((item) => item.term.id),
    ['dart', 'kafka'],
  );
});

test('роль совпадает по должности и опыту', () => {
  const byHeadline = matchVacancy({
    vacancyText: 'Frontend разработчик',
    content: content({ headline: 'Senior Frontend Engineer' }),
  });
  assert.equal(byHeadline.percent, 100);
  assert.deepEqual(byHeadline.requirements[0].evidence, ['headline']);
  const byExperience = matchVacancy({
    vacancyText: 'Нужен backend',
    content: content({ experience: [experience('e', { role: 'Backend developer' })] }),
  });
  assert.equal(byExperience.percent, 100);
});

test('проекты и опыт получают релевантность и порядок', () => {
  const match = matchVacancy({
    vacancyText: 'Flutter, Dart, Firebase',
    content: content({
      projects: [
        project('web', { technologies: ['React'] }),
        project('app', { technologies: ['Flutter', 'Dart'] }),
        project('one', { description: 'Использует Firebase' }),
      ],
      experience: [
        experience('e1', { role: 'Mobile', organization: 'A', description: 'Писал на Flutter' }),
        experience('e2', { role: 'QA', organization: 'B' }),
      ],
    }),
  });
  assert.deepEqual(match.projectOrder, ['app', 'one', 'web']);
  assert.equal(match.projects[0].score, 2);
  assert.equal(match.projects.at(-1)!.score, 0);
  assert.equal(match.experience[0].score, 1);
  assert.equal(match.experience.at(-1)!.score, 0);
});

test('равная релевантность сохраняет исходный порядок проектов', () => {
  const match = matchVacancy({
    vacancyText: 'Rust',
    content: content({ projects: [project('b'), project('a'), project('c')] }),
  });
  assert.deepEqual(match.projectOrder, ['b', 'a', 'c']);
});

test('скрытые проекты не участвуют', () => {
  const match = matchVacancy({
    vacancyText: 'Dart',
    content: content({ projects: [project('h', { technologies: ['Dart'], visible: false })] }),
  });
  assert.equal(match.projectOrder.length, 0);
});

test('порядок разделов — перестановка пяти разделов, сильные первыми', () => {
  const match = matchVacancy({
    vacancyText: 'Flutter',
    content: content({ projects: [project('p', { technologies: ['Flutter'] })] }),
  });
  assert.deepEqual(
    new Set(match.sectionOrder),
    set('links', 'skills', 'featuredProjects', 'experience', 'education'),
  );
  assert.equal(match.sectionOrder.length, 5);
  assert.equal(match.sectionOrder[0], 'featuredProjects');
});

test('порядок разделов без сигнала не сбрасывает текущий', () => {
  const blocks = (
    ['profile', 'education', 'skills', 'featuredProjects', 'experience', 'links'] as const
  ).map((kind) => ({ kind, visible: true }));
  const match = matchVacancy({ vacancyText: 'Rust', content: content({ blocks: [...blocks] }) });
  assert.equal(match.sectionOrder[0], 'education');
});

test('результат детерминирован и не меняет контент', () => {
  const source = content({ skills: ['Dart'] });
  const before = JSON.stringify(source);
  const first = matchVacancy({ vacancyText: 'Dart, Rust', content: source });
  const second = matchVacancy({ vacancyText: 'Dart, Rust', content: source });
  assert.equal(first.percent, second.percent);
  assert.deepEqual(first.sectionOrder, second.sectionOrder);
  assert.equal(JSON.stringify(source), before);
});

test('GitHub скрывается вместе с контактами, порядок применяется (экспорт)', () => {
  const source = {
    ...content({ projects: [project('a'), project('b')] }),
    blocks: (['profile', 'github', 'links', 'skills', 'featuredProjects'] as const).map((kind) => ({
      kind,
      visible: true,
    })),
  };
  const before = JSON.stringify(source);
  const result = buildVacancyExportContent(source, {
    projectOrder: ['b', 'a'],
    includedProjects: new Set(['a', 'b']),
    sectionOrder: ['featuredProjects', 'skills', 'experience', 'education', 'links'],
    includedSections: new Set(['featuredProjects', 'skills']),
  });
  assert.deepEqual(
    result.projects.map((item) => item.id),
    ['b', 'a'],
  );
  const visible = (kind: string) => result.blocks.find((block) => block.kind === kind)!.visible;
  assert.equal(visible('links'), false);
  assert.equal(visible('github'), false);
  assert.equal(visible('skills'), true);
  assert.deepEqual(
    result.blocks
      .map((block) => block.kind)
      .filter((kind) =>
        ['featuredProjects', 'skills', 'experience', 'education', 'links'].includes(kind),
      ),
    ['featuredProjects', 'skills', 'experience', 'education', 'links'],
  );
  // Исходное содержимое не изменилось.
  assert.equal(JSON.stringify(source), before);
});

test('экспорт: невыбранные проекты исключаются, неупомянутые идут после порядка', () => {
  const result = buildVacancyExportContent(
    content({ projects: [project('a'), project('b'), project('c')] }),
    {
      projectOrder: ['c'],
      includedProjects: new Set(['a', 'c']),
      sectionOrder: ['skills'],
      includedSections: new Set(['skills']),
    },
  );
  assert.deepEqual(
    result.projects.map((item) => item.id),
    ['c', 'a'],
  );
  // Недостающие разделы добираются в каноническом порядке
  assert.equal(vacancyBlocks([], { order: ['skills'] }).length, 5);
});

test('применение порядка: проекты и разделы только в копии документа', () => {
  const document: PortfolioDocument = {
    id: 'main',
    title: 'Портфолио',
    kind: 'portfolio',
    createdAt: '2026-01-01T00:00:00.000Z',
    updatedAt: '2026-01-01T00:00:00.000Z',
    content: content(),
    projects: ['x', 'y', 'z', 'hidden'].map((id) => attachment(id)),
    attachedResumeId: null,
  };
  const before = JSON.stringify(document);
  const next = applyVacancyOrder(document, {
    projects: ['z', 'x'],
    sections: ['experience', 'skills', 'featuredProjects', 'education', 'links'],
  });
  // z и x по порядку подбора, остальные в прежнем порядке после них
  assert.deepEqual(
    next.projects.map((item) => item.projectId),
    ['z', 'x', 'y', 'hidden'],
  );
  assert.deepEqual(
    next.content.blocks
      .map((block) => block.kind)
      .filter((kind) =>
        ['experience', 'skills', 'featuredProjects', 'education', 'links'].includes(kind),
      ),
    ['experience', 'skills', 'featuredProjects', 'education', 'links'],
  );
  assert.equal(JSON.stringify(document), before);
});

// Паритет словаря с mobile: порядок терминов, подписи, алиасы и признак роли читаются прямо
// из Dart-файла, поэтому любая правка словаря на одной стороне ломает тест на другой.
function mobileDictionary() {
  const source = readFileSync(
    new URL('../../mobile/lib/features/portfolio_draft/domain/vacancy_match.dart', import.meta.url),
    'utf8',
  );
  const start = source.indexOf('const defaultVacancyDictionary');
  const body = source.slice(start, source.indexOf('/// Где требование найдено', start));
  return [
    ...body.matchAll(
      /VacancyTerm\(\s*'([^']*)',\s*'([^']*)',\s*\[([\s\S]*?)\](,\s*role:\s*true)?\s*,?\s*\)/g,
    ),
  ].map((match) => ({
    id: match[1],
    label: match[2],
    // Повтор алиаса в Dart («мобильная» дважды) ничего не меняет
    aliases: [...new Set([...match[3].matchAll(/'([^']*)'/g)].map((alias) => alias[1]))],
    role: Boolean(match[4]),
  }));
}

test('словарь web совпадает со словарём mobile: термины, порядок, алиасы, роли', () => {
  const mobile = mobileDictionary();
  assert.ok(mobile.length > 40, 'словарь mobile не разобран');
  const web = defaultVacancyDictionary.map((item) => ({
    id: item.id,
    label: item.label,
    aliases: [...new Set(item.aliases)],
    role: Boolean(item.role),
  }));
  assert.deepEqual(web, mobile);
});

test('«Jest» даёт два требования: Jest и Тестирование, как в mobile', () => {
  const found = findVacancyTerms('Опыт с Jest');
  assert.deepEqual(
    found.map((item) => item.id),
    ['jest', 'testing'],
  );
  const match = matchVacancy({
    vacancyText: 'Опыт с Jest',
    content: content({ skills: ['Jest'] }),
  });
  assert.equal(match.totalCount, 2);
  // Навык «Jest» — алиас обоих терминов, поэтому закрывает оба требования
  assert.equal(match.matchedCount, 2);
  assert.equal(match.percent, 100);
  const none = matchVacancy({ vacancyText: 'Опыт с Jest', content: content({ skills: ['Rust'] }) });
  assert.equal(none.totalCount, 2);
  assert.equal(none.matchedCount, 0);
});
