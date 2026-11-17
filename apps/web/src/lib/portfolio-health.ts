// Здоровье портфолио: чистая оценка 0–100, порт mobile portfolio_health.dart.
// Только читает контент; пороги давности проектов совпадают с mobile Suggestions.
import { gitHubSourceFingerprint } from './github-fingerprint';
import type { DocumentContent, Project } from './model';

// Вес раздела задаёт важность совета; порядок ключей — порядок показа.
export const healthSections = {
  profile: { weight: 20, title: 'Профиль' },
  avatar: { weight: 5, title: 'Фото' },
  projects: { weight: 25, title: 'Проекты' },
  experience: { weight: 10, title: 'Опыт' },
  education: { weight: 5, title: 'Образование' },
  skills: { weight: 15, title: 'Навыки' },
  contacts: { weight: 10, title: 'Контакты' },
  publication: { weight: 10, title: 'Публикация' },
} as const;
export type HealthSection = keyof typeof healthSections;

export type HealthCheckKind =
  | 'profileName'
  | 'profileHeadline'
  | 'profileBio'
  | 'avatar'
  | 'projectsAny'
  | 'projectDescription'
  | 'projectTechnologies'
  | 'projectLink'
  | 'projectInactive'
  | 'experienceAny'
  | 'educationAny'
  | 'skillsAny'
  | 'skillUnused'
  | 'contactsAny'
  | 'published';

export type HealthCheck = {
  section: HealthSection;
  kind: HealthCheckKind;
  ok: boolean;
  // Проект или навык, к которому относится совет.
  targetId?: string;
  targetTitle?: string;
};
export type PortfolioHealth = {
  score: number;
  checks: HealthCheck[];
  improvements: HealthCheck[];
  isPerfect: boolean;
};

// Давность проекта из mobile PortfolioSuggestionThresholds.inactiveProjectAge.
export const inactiveProjectDays = 180;
const day = 24 * 60 * 60 * 1000;

export const healthCheckId = (check: HealthCheck) => `${check.kind}:${check.targetId ?? ''}`;

// Совет о давности: источник GitHub принят, валиден, не игнорируется и старше порога.
function isInactive(project: Project, content: DocumentContent, now: Date): boolean {
  const source = project.source === 'github' ? project.githubMetadata?.acceptedSource : undefined;
  if (!source || source.repositoryId < 1 || source.stars < 0 || source.forks < 0) return false;
  const updated = Date.parse(source.updatedAt);
  if (Number.isNaN(updated)) return false;
  // Игнор действует только пока источник не изменился: пара repositoryId и отпечаток, как в mobile.
  const fingerprint = gitHubSourceFingerprint(source);
  if (
    content.ignoredGitHubRepositories.some(
      (item) => item.repositoryId === source.repositoryId && item.fingerprint === fingerprint,
    )
  )
    return false;
  return now.getTime() - updated >= inactiveProjectDays * day;
}

const filled = (value: string) => value.trim() !== '';

// published: null/undefined — статус неизвестен, раздел публикации не учитывается.
export function buildPortfolioHealth({
  content,
  now,
  published,
}: {
  content: DocumentContent;
  now: Date;
  published?: boolean | null;
}): PortfolioHealth {
  const checks: HealthCheck[] = [];
  const add = (
    section: HealthSection,
    kind: HealthCheckKind,
    ok: boolean,
    target?: { id: string; title: string },
  ) =>
    checks.push({
      section,
      kind,
      ok,
      ...(target ? { targetId: target.id, targetTitle: target.title } : {}),
    });

  const profile = content.profile;
  add('profile', 'profileName', filled(profile.name));
  add('profile', 'profileHeadline', filled(profile.headline));
  add('profile', 'profileBio', filled(profile.bio));
  add('avatar', 'avatar', filled(profile.avatarPath) || filled(profile.avatarUrl));

  const projects = content.projects.filter((project) => project.visible);
  add('projects', 'projectsAny', projects.length > 0);
  for (const project of projects) {
    const target = { id: project.id, title: project.title };
    add('projects', 'projectDescription', filled(project.description), target);
    add('projects', 'projectTechnologies', project.technologies.some(filled), target);
    add(
      'projects',
      'projectLink',
      filled(project.liveUrl) || filled(project.repositoryUrl),
      target,
    );
    if (isInactive(project, content, now)) add('projects', 'projectInactive', false, target);
  }

  add('experience', 'experienceAny', content.experience.length > 0);
  add('education', 'educationAny', content.education.length > 0);

  add('skills', 'skillsAny', content.skills.length > 0);
  const used = new Set(
    projects.flatMap((project) =>
      project.technologies.map((technology) => technology.trim().toLowerCase()),
    ),
  );
  // Навыки без проектов не проверяются: советовать нечего связывать.
  if (projects.length > 0)
    for (const skill of content.skills)
      add('skills', 'skillUnused', used.has(skill.name.trim().toLowerCase()), {
        id: skill.id,
        title: skill.name,
      });

  add(
    'contacts',
    'contactsAny',
    content.links.some((link) => link.visible && link.publishAllowed),
  );
  if (published !== null && published !== undefined) add('publication', 'published', published);

  let weighted = 0;
  let total = 0;
  for (const [name, { weight }] of Object.entries(healthSections)) {
    const items = checks.filter((check) => check.section === name);
    if (items.length === 0) continue;
    total += weight;
    weighted += (weight * items.filter((check) => check.ok).length) / items.length;
  }
  let score = total === 0 ? 0 : Math.round((100 * weighted) / total);
  // 100 только когда не осталось ни одного совета.
  if (score === 100 && checks.some((check) => !check.ok)) score = 99;

  checks.sort((left, right) => {
    if (left.ok !== right.ok) return left.ok ? 1 : -1;
    const bySection = healthSections[right.section].weight - healthSections[left.section].weight;
    if (bySection !== 0) return bySection;
    const a = healthCheckId(left);
    const b = healthCheckId(right);
    return a < b ? -1 : a > b ? 1 : 0;
  });
  const improvements = checks.filter((check) => !check.ok);
  return { score, checks, improvements, isPerfect: score === 100 && improvements.length === 0 };
}

// Доля выполненных проверок раздела; null, если проверок нет.
export function healthSectionFraction(health: PortfolioHealth, section: HealthSection) {
  const items = health.checks.filter((check) => check.section === section);
  return items.length === 0 ? null : items.filter((check) => check.ok).length / items.length;
}

// Текст совета; название проекта или навыка подставляется в кавычках.
export function healthTip(check: HealthCheck): string {
  const target = `«${check.targetTitle ?? ''}»`;
  const tips: Record<HealthCheckKind, string> = {
    profileName: 'Укажите имя',
    profileHeadline: 'Добавьте должность',
    profileBio: 'Расскажите о себе',
    avatar: 'Добавьте фото профиля',
    projectsAny: 'Добавьте хотя бы один проект',
    projectDescription: `У проекта ${target} нет описания`,
    projectTechnologies: `У проекта ${target} не указаны технологии`,
    projectLink: `У проекта ${target} нет ссылки`,
    projectInactive: `Проект ${target} давно не обновлялся`,
    experienceAny: 'Добавьте опыт работы',
    educationAny: 'Добавьте образование',
    skillsAny: 'Добавьте навыки',
    skillUnused: `Навык ${target} не использован ни в одном проекте`,
    contactsAny: 'Добавьте контакт для связи',
    published: 'Портфолио ещё не опубликовано',
  };
  return tips[check.kind];
}
