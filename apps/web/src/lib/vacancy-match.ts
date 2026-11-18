// Подбор под вакансию: порт mobile vacancy_match.dart. Чистые функции без хранилища и сети:
// текст вакансии не покидает вызывающий код и нигде не сохраняется.
import {
  mainPortfolioSectionKinds,
  mainPortfolioSectionOrder,
  type Attachment,
  type DocumentContent,
  type MainPortfolioSectionKind,
  type PortfolioDocument,
} from './model';

// Минимальная длина текста вакансии для разбора.
export const vacancyMinimumLength = 20;
// Разбор ограничен: длиннее текст обрезается, чтобы экран не зависал.
export const vacancyMaximumLength = 20000;

// Термин словаря: технология или роль. aliases — варианты написания
// (регистр и знаки не важны), многословные задаются через пробел.
export type VacancyTerm = {
  id: string;
  label: string;
  aliases: string[];
  // Название направления (frontend, backend), а не технология.
  role?: boolean;
};
const term = (id: string, label: string, aliases: string[], role = false): VacancyTerm => ({
  id,
  label,
  aliases,
  role,
});

// Небольшой расширяемый словарь; свои термины передаются в matchVacancy.
export const defaultVacancyDictionary: VacancyTerm[] = [
  term('javascript', 'JavaScript', ['javascript', 'js', 'ecmascript']),
  term('typescript', 'TypeScript', ['typescript', 'ts']),
  term('node', 'Node.js', ['node', 'nodejs', 'node.js', 'node js']),
  term('react', 'React', ['react', 'reactjs', 'react.js', 'react js']),
  term('react native', 'React Native', ['react native']),
  term('next', 'Next.js', ['nextjs', 'next.js']),
  term('vue', 'Vue', ['vue', 'vuejs', 'vue.js', 'vue js']),
  term('angular', 'Angular', ['angular', 'angularjs']),
  term('html', 'HTML', ['html', 'html5']),
  term('css', 'CSS', ['css', 'css3']),
  term('tailwind', 'Tailwind', ['tailwind', 'tailwindcss']),
  term('flutter', 'Flutter', ['flutter', 'флаттер']),
  term('dart', 'Dart', ['dart', 'дарт']),
  term('kotlin', 'Kotlin', ['kotlin', 'котлин']),
  term('java', 'Java', ['java', 'джава']),
  term('spring', 'Spring', ['spring', 'spring boot', 'springboot']),
  term('swift', 'Swift', ['swift']),
  term('ios', 'iOS', ['ios']),
  term('android', 'Android', ['android', 'андроид']),
  term('python', 'Python', ['python', 'питон', 'питоне', 'пайтон']),
  term('django', 'Django', ['django']),
  term('fastapi', 'FastAPI', ['fastapi']),
  term('go', 'Go', [
    'golang',
    'go lang',
    'go developer',
    'go engineer',
    'go dev',
    'go разработчик',
    'go разработчика',
    'go программист',
  ]),
  term('rust', 'Rust', ['rust']),
  term('csharp', 'C#', ['c#', 'csharp']),
  term('dotnet', '.NET', ['dotnet', '.net']),
  term('cpp', 'C++', ['c++', 'cpp']),
  term('sql', 'SQL', ['sql']),
  term('postgresql', 'PostgreSQL', ['postgresql', 'postgres', 'pg']),
  term('mysql', 'MySQL', ['mysql']),
  term('mongodb', 'MongoDB', ['mongodb', 'mongo']),
  term('redis', 'Redis', ['redis']),
  term('kafka', 'Kafka', ['kafka']),
  term('graphql', 'GraphQL', ['graphql']),
  term('rest', 'REST', ['restful', 'rest api']),
  term('docker', 'Docker', ['docker', 'докер', 'докере']),
  term('kubernetes', 'Kubernetes', ['kubernetes', 'k8s', 'кубернетес']),
  term('cicd', 'CI/CD', ['ci cd', 'cicd']),
  term('terraform', 'Terraform', ['terraform']),
  term('aws', 'AWS', ['aws']),
  term('gcp', 'GCP', ['gcp', 'google cloud']),
  term('azure', 'Azure', ['azure']),
  term('firebase', 'Firebase', ['firebase']),
  term('git', 'Git', ['git']),
  term('linux', 'Linux', ['linux', 'линукс']),
  term('figma', 'Figma', ['figma', 'фигма']),
  term('jest', 'Jest', ['jest']),
  term('testing', 'Тестирование', ['jest', 'testing', 'тестирование', 'unit tests']),
  term(
    'frontend',
    'Frontend',
    ['frontend', 'front end', 'фронтенд', 'фронтенда', 'фронтэнд', 'фронт энд'],
    true,
  ),
  term(
    'backend',
    'Backend',
    ['backend', 'back end', 'бэкенд', 'бэкенда', 'бэкэнд', 'бекенд', 'бекенда', 'бэк энд'],
    true,
  ),
  term('fullstack', 'Fullstack', ['fullstack', 'full stack', 'фулстек', 'фуллстек'], true),
  term(
    'mobile',
    'Mobile',
    [
      'mobile',
      'мобильный',
      'мобильная',
      'мобильного',
      'мобильной',
      'мобильные',
      'мобильную',
      'мобильных',
      'мобильным',
      'мобильное',
    ],
    true,
  ),
  term('devops', 'DevOps', ['devops', 'девопс'], true),
];

// Где требование найдено в портфолио.
export type VacancyEvidence = 'skill' | 'project' | 'experience' | 'headline';

export type VacancyRequirement = {
  term: VacancyTerm;
  matched: boolean;
  evidence: VacancyEvidence[];
};
export type VacancyProjectScore = {
  projectId: string;
  title: string;
  // Подписи требований, найденных в проекте.
  matched: string[];
  score: number;
};
export type VacancyExperienceScore = {
  experienceId: string;
  role: string;
  matched: string[];
  score: number;
};
export type VacancyMatch = {
  requirements: VacancyRequirement[];
  // По убыванию релевантности; при равенстве сохраняется исходный порядок.
  projects: VacancyProjectScore[];
  experience: VacancyExperienceScore[];
  // Предложенный порядок id проектов и разделов; ничего не применяет само.
  projectOrder: string[];
  sectionOrder: MainPortfolioSectionKind[];
  totalCount: number;
  matchedCount: number;
  matchedRequirements: VacancyRequirement[];
  missingRequirements: VacancyRequirement[];
  // Вакансия не содержит известных требований.
  noRequirements: boolean;
  // Целый процент совпавших требований; 0 без требований.
  percent: number;
};

const wordPattern = /\.?[\p{L}\p{N}][\p{L}\p{N}+#.]*/gu;
const plusSuffix = /^\p{L}+\+{1,2}$/u;
const trailingDots = /\.+$/;
const versionSuffix = /(?<=\p{L})\d+(\.\d+)*$/gu;

// Токены текста: нижний регистр, слова с «+», «#», «.», без хвостовых точек.
export function tokenizeVacancyText(text: string): string[] {
  const cut = text.length > vacancyMaximumLength ? text.slice(0, vacancyMaximumLength) : text;
  const normalized = cut.toLowerCase().replaceAll('ё', 'е');
  const tokens: string[] = [];
  for (const match of normalized.matchAll(wordPattern)) {
    const word = match[0].replace(trailingDots, '');
    if (word === '' || word.length > 40) continue;
    tokens.push(word);
    // «react+redux»: части связки; «c++» остаётся целым словом.
    if (word.includes('+') && !plusSuffix.test(word))
      tokens.push(...word.split('+').filter((part) => part !== ''));
    // «python3», «vue3»: ещё и слово без хвостовых цифр версии.
    const bare = word.replace(versionSuffix, '');
    if (bare !== word && bare !== '') tokens.push(bare);
  }
  return tokens;
}

type Range = [number, number];

// Вхождения алиасов термина как диапазоны токенов [начало, конец).
function ranges(item: VacancyTerm, tokens: string[]): Range[] {
  const found: Range[] = [];
  for (const alias of item.aliases) {
    const phrase = tokenizeVacancyText(alias);
    if (phrase.length === 0) continue;
    for (let start = 0; start + phrase.length <= tokens.length; start++)
      if (phrase.every((word, index) => tokens[start + index] === word))
        found.push([start, start + phrase.length]);
  }
  return found;
}

// Id терминов в tokens. Вхождение, целиком лежащее внутри более длинного
// вхождения другого термина («react» в «react native»), не считается:
// короткий термин учитывается, только если встречается сам по себе.
function termIds(terms: Iterable<VacancyTerm>, tokens: string[]): Set<string> {
  const all = new Map<string, Range[]>();
  for (const item of terms) all.set(item.id, ranges(item, tokens));
  const ids = new Set<string>();
  for (const [id, own] of all) {
    const standalone = own.some(
      (range) =>
        ![...all].some(
          ([otherId, others]) =>
            otherId !== id &&
            others.some(
              (outer) =>
                outer[0] <= range[0] &&
                range[1] <= outer[1] &&
                outer[1] - outer[0] > range[1] - range[0],
            ),
        ),
    );
    if (standalone) ids.add(id);
  }
  return ids;
}

// Термины, найденные в тексте.
export function findVacancyTerms(
  text: string,
  dictionary: VacancyTerm[] = defaultVacancyDictionary,
): VacancyTerm[] {
  const ids = termIds(dictionary, tokenizeVacancyText(text));
  return dictionary.filter((item) => ids.has(item.id));
}

// Сопоставляет вакансию с основным портфолио. Требование — термин словаря, найденный в тексте
// вакансии; совпало, если он есть в навыках, технологиях и описании проектов, опыте или должности.
// Свои навыки не создают требований: иначе совпавшие навыки попадали бы в знаменатель,
// а недостающие нет, и процент завышался бы.
export function matchVacancy({
  vacancyText,
  content,
  dictionary = defaultVacancyDictionary,
}: {
  vacancyText: string;
  content: DocumentContent;
  dictionary?: VacancyTerm[];
}): VacancyMatch {
  const required = findVacancyTerms(vacancyText, dictionary);
  const requiredIds = new Set(required.map((item) => item.id));

  // Поля разбираются по отдельности: граница полей не склеивает слова
  // («Go» + «Developer portal») и не делает технологией название компании.
  const labelsInAll = (fields: string[]): string[] => {
    const hits = new Set<string>();
    for (const field of fields)
      for (const id of termIds(dictionary, tokenizeVacancyText(field))) hits.add(id);
    return required.filter((item) => hits.has(item.id)).map((item) => item.id);
  };
  const labelsIn = (text: string) => labelsInAll([text]);

  // Название навыка или технологии, совпавшее с id/подписью термина, считается его написанием
  // («Go» для термина go); только для коротких названий, не для свободного текста.
  const labelsInName = (name: string): string[] => {
    const tokens = tokenizeVacancyText(name);
    const key = tokens.join(' ');
    const ids = termIds(dictionary, tokens);
    for (const item of dictionary)
      if (key === item.id || key === tokenizeVacancyText(item.label).join(' ')) ids.add(item.id);
    return [...ids].filter((id) => requiredIds.has(id));
  };

  const skillIds = new Set(content.skills.flatMap((skill) => labelsInName(skill.name)));
  const headlineIds = new Set(labelsIn(content.profile.headline));
  const projects = content.projects.filter((project) => project.visible);
  const projectHits = new Map<string, Set<string>>();
  for (const project of projects)
    projectHits.set(
      project.id,
      new Set([
        ...project.technologies.flatMap(labelsInName),
        ...labelsInAll([project.title, project.description]),
      ]),
    );
  const experienceHits = new Map<string, Set<string>>();
  for (const item of content.experience)
    experienceHits.set(item.id, new Set(labelsInAll([item.role, item.description])));
  const labelOf = (id: string) => required.find((item) => item.id === id)!.label;
  const anyProject = (id: string) => [...projectHits.values()].some((hits) => hits.has(id));
  const anyExperience = (id: string) => [...experienceHits.values()].some((hits) => hits.has(id));

  const requirements: VacancyRequirement[] = required.map((item) => {
    const evidence: VacancyEvidence[] = [];
    if (!item.role && skillIds.has(item.id)) evidence.push('skill');
    if (!item.role && anyProject(item.id)) evidence.push('project');
    if (anyExperience(item.id)) evidence.push('experience');
    if (headlineIds.has(item.id)) evidence.push('headline');
    return { term: item, matched: evidence.length > 0, evidence };
  });

  const projectScores: VacancyProjectScore[] = projects.map((project) => {
    const matched = [...projectHits.get(project.id)!].map(labelOf);
    return { projectId: project.id, title: project.title, matched, score: matched.length };
  });
  // Сортировка по убыванию; при равенстве — исходный порядок.
  const sortedProjects = projectScores
    .map((item, index) => ({ item, index }))
    .sort((a, b) => b.item.score - a.item.score || a.index - b.index)
    .map(({ item }) => item);
  const experienceScores: VacancyExperienceScore[] = content.experience.map((item) => {
    const matched = [...experienceHits.get(item.id)!].map(labelOf);
    return { experienceId: item.id, role: item.role, matched, score: matched.length };
  });

  // Разделы по числу совпавших требований; остальные — в прежнем порядке.
  const union = (sets: Map<string, Set<string>>) =>
    new Set([...sets.values()].flatMap((hits) => [...hits])).size;
  const weight: Partial<Record<MainPortfolioSectionKind, number>> = {
    skills: skillIds.size,
    featuredProjects: union(projectHits),
    experience: union(experienceHits),
  };
  const current = mainPortfolioSectionOrder(content);
  const sectionOrder = current
    .map((kind, index) => ({ kind, index }))
    .sort((a, b) => (weight[b.kind] ?? 0) - (weight[a.kind] ?? 0) || a.index - b.index)
    .map(({ kind }) => kind);

  const matchedRequirements = requirements.filter((item) => item.matched);
  const missingRequirements = requirements.filter((item) => !item.matched);
  return {
    requirements,
    projects: sortedProjects,
    experience: experienceScores,
    projectOrder: sortedProjects.map((item) => item.projectId),
    sectionOrder,
    totalCount: requirements.length,
    matchedCount: matchedRequirements.length,
    matchedRequirements,
    missingRequirements,
    noRequirements: requirements.length === 0,
    percent:
      requirements.length === 0
        ? 0
        : Math.round((100 * matchedRequirements.length) / requirements.length),
  };
}

type Blocks = DocumentContent['blocks'];

// Блоки с разделами в order; не входящие в included скрываются.
// Остальные блоки (профиль, о себе, место) остаются как были.
export function vacancyBlocks(
  blocks: Blocks,
  {
    order,
    included,
  }: { order: MainPortfolioSectionKind[]; included?: Set<MainPortfolioSectionKind> },
): Blocks {
  const sections = new Set<string>(mainPortfolioSectionKinds);
  const section = (kind: MainPortfolioSectionKind): Blocks[number] => ({
    kind,
    visible:
      (blocks.find((block) => block.kind === kind)?.visible ?? true) &&
      (!included || included.has(kind)),
  });
  const linksVisible = !included || included.has('links');
  return [
    // GitHub-контакт — часть контактов и скрывается вместе с ними.
    ...blocks.flatMap((block): Blocks =>
      block.kind === 'github'
        ? [{ ...block, visible: block.visible && linksVisible }]
        : sections.has(block.kind)
          ? []
          : [block],
    ),
    ...[
      ...order.filter((kind) => sections.has(kind)),
      ...mainPortfolioSectionKinds.filter((kind) => !order.includes(kind)),
    ].map(section),
  ];
}

// Содержимое для PDF под вакансию: выбранные проекты и разделы в предложенном порядке.
// Исходное сохранённое портфолио не меняется.
export function buildVacancyExportContent(
  saved: DocumentContent,
  options: {
    projectOrder: string[];
    includedProjects: Set<string>;
    sectionOrder: MainPortfolioSectionKind[];
    includedSections: Set<MainPortfolioSectionKind>;
  },
): DocumentContent {
  const byId = new Map(saved.projects.map((project) => [project.id, project]));
  const ordered = [
    ...options.projectOrder.flatMap((id) =>
      options.includedProjects.has(id) && byId.has(id) ? [byId.get(id)!] : [],
    ),
    ...saved.projects.filter(
      (project) =>
        options.includedProjects.has(project.id) && !options.projectOrder.includes(project.id),
    ),
  ];
  return {
    ...structuredClone(saved),
    projects: structuredClone(ordered),
    blocks: vacancyBlocks(saved.blocks, {
      order: options.sectionOrder,
      included: options.includedSections,
    }),
  };
}

export type VacancyOrder = { projects: string[]; sections: MainPortfolioSectionKind[] };

// Порядок подбора для буфера редактора: вложения проектов по order.projects (прочие в прежнем
// порядке после них) и порядок разделов. Возвращает копию, ничего не сохраняет.
export function applyVacancyOrder(
  document: PortfolioDocument,
  order: VacancyOrder,
): PortfolioDocument {
  const position = new Map(order.projects.map((id, index) => [id, index]));
  const rank = (item: Attachment) => position.get(item.projectId) ?? order.projects.length;
  const projects = document.projects
    .map((item, index) => ({ item, index }))
    .sort((a, b) => rank(a.item) - rank(b.item) || a.index - b.index)
    .map(({ item }) => structuredClone(item));
  return {
    ...structuredClone(document),
    projects,
    content: {
      ...structuredClone(document.content),
      blocks: vacancyBlocks(document.content.blocks, { order: order.sections }),
    },
  };
}
