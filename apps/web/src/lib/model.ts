// Совместимый aggregate мобильного PortfolioContent. Private cloud writer — schema 7.
export const blockKinds = [
  'profile',
  'about',
  'skills',
  'featuredProjects',
  'experience',
  'education',
  'github',
  'links',
  'resume',
  'location',
] as const;
export type BlockKind = (typeof blockKinds)[number];
export type Profile = {
  name: string;
  username: string;
  headline: string;
  bio: string;
  locationText: string;
  avatarUrl: string;
  avatarPath: string;
  publishLocation: boolean;
};
export type Skill = { id: string; name: string };
export type Experience = {
  id: string;
  role: string;
  organization: string;
  period: string;
  description: string;
};
export type Education = {
  id: string;
  institution: string;
  qualification: string;
  period: string;
  description: string;
};
export const linkKinds = [
  'other',
  'github',
  'website',
  'linkedin',
  'email',
  'phone',
  'telegram',
] as const;
export type Contact = {
  id: string;
  label: string;
  url: string;
  kind: (typeof linkKinds)[number];
  publishAllowed: boolean;
  visible: boolean;
};
export type GitHubSource = {
  repositoryId: number;
  name: string;
  fullName: string;
  htmlUrl: string;
  description: string | null;
  language: string | null;
  stars: number;
  forks: number;
  isFork: boolean;
  archived: boolean;
  updatedAt: string;
};
export const projectIconIds = [
  'folder',
  'file-text',
  'panels-top-left',
  'home',
  'image',
  'camera',
  'user-round',
] as const;
export type ProjectIconId = (typeof projectIconIds)[number];
export const projectIconLabels: Record<ProjectIconId, string> = {
  folder: 'Папка',
  'file-text': 'Документ',
  'panels-top-left': 'Приложение',
  home: 'Дом',
  image: 'Изображение',
  camera: 'Камера',
  'user-round': 'Пользователь',
};
export type Project = {
  iconId?: ProjectIconId;
  id: string;
  title: string;
  description: string;
  contribution: string;
  technologies: string[];
  repositoryUrl: string;
  liveUrl: string;
  featured: boolean;
  visible: boolean;
  imagePaths: string[];
  updatedAt?: string;
  source: 'manual' | 'github';
  githubMetadata: {
    acceptedSource: GitHubSource;
    lastGitHubSyncAt: string | null;
    overrideFields: string[];
  } | null;
};
export type Attachment = {
  projectId: string;
  visible: boolean;
  featured: boolean;
  titleOverride: string | null;
  descriptionOverride: string | null;
  contributionOverride: string | null;
};
export type BaseData = {
  profile: Profile;
  skills: Skill[];
  experience: Experience[];
  education: Education[];
  links: Contact[];
};
export type DocumentContent = BaseData & {
  projects: Project[];
  blocks: { kind: BlockKind; visible: boolean }[];
  resumeText: string;
  theme: 'dark' | 'light';
  ignoredGitHubRepositories: { repositoryId: number; fingerprint: string }[];
};
export type PortfolioDocument = {
  id: string;
  title: string;
  kind: 'resume' | 'portfolio';
  createdAt: string;
  updatedAt: string;
  content: DocumentContent;
  projects: Attachment[];
  attachedResumeId: string | null;
  baseSnapshot?: BaseData;
};
export type WorkspaceContent = DocumentContent & {
  documents: PortfolioDocument[];
  mainPortfolioId: string | null;
  githubUsername: string;
  personalization: { status: 'notRequired' | 'inProgress' | 'completed'; step: number };
  legacyMainSnapshot?: PortfolioDocument;
};
export type DraftEnvelope = {
  schemaVersion: number;
  ownerUid: string;
  mutationId: string;
  localRevision: number;
  notes: string;
  content: WorkspaceContent | null;
  updatedAt: unknown;
};
export class ContractError extends Error {
  constructor(message = 'Данные имеют неподдерживаемый формат. Перезапись заблокирована.') {
    super(message);
  }
}
export const clone = <T>(value: T): T => structuredClone(value);
export const uid = () => crypto.randomUUID().replaceAll('-', '');
export function equal(a: unknown, b: unknown): boolean {
  if (a === b) return true;
  if (a == null || b == null || typeof a !== 'object' || typeof b !== 'object') return false;
  if (Array.isArray(a) || Array.isArray(b))
    return (
      Array.isArray(a) &&
      Array.isArray(b) &&
      a.length === b.length &&
      a.every((v, i) => equal(v, b[i]))
    );
  const left = a as Record<string, unknown>,
    right = b as Record<string, unknown>,
    fields = Object.keys(left);
  return (
    fields.length === Object.keys(right).length &&
    fields.every((field) => Object.hasOwn(right, field) && equal(left[field], right[field]))
  );
}
export function emptyContent(): WorkspaceContent {
  return {
    profile: {
      name: '',
      username: '',
      headline: '',
      bio: '',
      locationText: '',
      avatarUrl: '',
      avatarPath: '',
      publishLocation: false,
    },
    skills: [],
    projects: [],
    experience: [],
    education: [],
    links: [],
    blocks: blockKinds.map((kind) => ({ kind, visible: true })),
    resumeText: '',
    theme: 'light',
    ignoredGitHubRepositories: [],
    documents: [],
    mainPortfolioId: null,
    githubUsername: '',
    personalization: { status: 'notRequired', step: 0 },
  };
}
export function baseData(content: BaseData): BaseData {
  return clone({
    profile: content.profile,
    skills: content.skills,
    experience: content.experience,
    education: content.education,
    links: content.links,
  });
}
export function seedDocument(content: WorkspaceContent): DocumentContent {
  const {
    documents: _,
    mainPortfolioId: _main,
    githubUsername: _github,
    personalization: _personalization,
    legacyMainSnapshot: _legacy,
    ...rest
  } = clone(content);
  return { ...rest, projects: [], ignoredGitHubRepositories: [] };
}
export function createDocument(
  content: WorkspaceContent,
  kind: PortfolioDocument['kind'],
  title: string,
  now = new Date(),
): PortfolioDocument {
  if (content.documents.length >= 20)
    throw new ContractError('Можно сохранить не больше 20 документов.');
  return {
    id: uid(),
    title,
    kind,
    createdAt: now.toISOString(),
    updatedAt: now.toISOString(),
    content: { ...seedDocument(content), theme: 'light' },
    projects: [],
    attachedResumeId: null,
    baseSnapshot: baseData(content),
  };
}
export function duplicateDocument(document: PortfolioDocument): PortfolioDocument {
  const now = new Date().toISOString();
  return {
    ...clone(document),
    id: uid(),
    title: document.title.slice(0, 110) + ' — копия',
    createdAt: now,
    updatedAt: now,
  };
}
export function resolveDocument(
  workspace: WorkspaceContent,
  document: PortfolioDocument,
): DocumentContent {
  return {
    ...clone(document.content),
    projects: document.projects.map((a) => {
      const p = workspace.projects.find((p) => p.id === a.projectId);
      if (!p) throw new ContractError('Проект отсутствует в Library.');
      return {
        ...clone(p),
        title: a.titleOverride ?? p.title,
        description: a.descriptionOverride ?? p.description,
        contribution: a.contributionOverride ?? p.contribution,
        visible: a.visible,
        featured: a.featured,
      };
    }),
  };
}
export function attachment(projectId: string): Attachment {
  return {
    projectId,
    visible: true,
    featured: false,
    titleOverride: null,
    descriptionOverride: null,
    contributionOverride: null,
  };
}
export function withProjectEdits(project: Project, patch: Partial<Project>): Project {
  const next = { ...project, ...patch, updatedAt: new Date().toISOString() };
  const metadata = next.githubMetadata;
  if (!metadata) return next;
  const source = metadata.acceptedSource;
  const baseline = {
    title: source.name,
    description: source.description ?? '',
    technologies: source.language ? [source.language] : [],
    repositoryUrl: source.htmlUrl,
  };
  const overrides = new Set(metadata.overrideFields);
  for (const key of ['title', 'description', 'technologies', 'repositoryUrl'] as const)
    if (key in patch) {
      if (equal(next[key], baseline[key])) overrides.delete(key);
      else overrides.add(key);
    }
  return {
    ...next,
    githubMetadata: {
      ...metadata,
      overrideFields: ['title', 'description', 'technologies', 'repositoryUrl'].filter((key) =>
        overrides.has(key),
      ),
    },
  };
}
export function safeReturnPath(path: string | null): string {
  return path &&
    path === path.trim() &&
    /^\/workspace(?:\/[A-Za-z0-9_-]+)*(?:\?[A-Za-z0-9_=&%-]*)?(?:#(?:home|editor|github-import|base|resumes|projects|portfolios|settings|inbox(?:\/[a-f0-9]{32})?|project\/[A-Za-z0-9_-]+|document\/[A-Za-z0-9_-]+))?$/.test(
      path,
    )
    ? path
    : '/workspace';
}
export function safeHttpUrl(value: string): boolean {
  try {
    const u = new URL(value);
    return (
      value === value.trim() &&
      /^https?:\/\//.test(value) &&
      !/[\s\x00-\x1f\x7f]/.test(value) &&
      value.length <= 2048 &&
      ['http:', 'https:'].includes(u.protocol) &&
      !!u.hostname &&
      !u.username &&
      !u.password
    );
  } catch {
    return false;
  }
}
export function safeContactUrl(value: string, kind: Contact['kind']): boolean {
  if (!value || value.length > 2048 || value !== value.trim() || /[\x00-\x20\x7f]|\s/.test(value))
    return false;
  if (kind === 'email')
    return /^mailto:[A-Za-z0-9.!$&'*+/=_^`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+$/.test(
      value,
    );
  if (kind === 'phone') return /^tel:\+[0-9]{7,15}$/.test(value);
  if (kind === 'telegram') return /^https:\/\/t\.me\/[A-Za-z0-9_]{1,64}$/.test(value);
  return safeHttpUrl(value);
}
const map = (value: unknown): Record<string, unknown> => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new ContractError();
  return value as Record<string, unknown>;
};
const keys = (value: Record<string, unknown>, allowed: string[]) => {
  if (Object.keys(value).some((k) => !allowed.includes(k))) throw new ContractError();
};
const str = (value: unknown, max: number, required = false): string => {
  if (typeof value !== 'string' || value.length > max || (required && !value.trim()))
    throw new ContractError('Проверьте обязательные поля и длину текста.');
  return value;
};
const bool = (value: unknown, fallback?: boolean): boolean => {
  if (value === undefined && fallback !== undefined) return fallback;
  if (typeof value !== 'boolean') throw new ContractError();
  return value;
};
const list = (value: unknown, max = 10000): unknown[] => {
  if (!Array.isArray(value) || value.length > max) throw new ContractError();
  return value;
};
const ids = <T extends { id: string }>(items: T[]): T[] => {
  if (new Set(items.map((i) => i.id)).size !== items.length)
    throw new ContractError('Повторяющиеся ID.');
  return items;
};
const date = (value: unknown): string => {
  const s = str(value, 40, true);
  if (
    !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z$/.test(s) ||
    Number.isNaN(Date.parse(s))
  )
    throw new ContractError();
  return s;
};
const microseconds = (value: string) => {
  const fractional = /\.(\d+)Z$/.exec(value)?.[1] ?? '';
  return BigInt(Date.parse(value)) * 1000n + BigInt(fractional.padEnd(6, '0').slice(3));
};
function timestampEquals(a: unknown, b: unknown) {
  const x = a as { seconds?: number; nanoseconds?: number },
    y = b as { seconds?: number; nanoseconds?: number };
  return x?.seconds === y?.seconds && x?.nanoseconds === y?.nanoseconds;
}
const nullable = (value: unknown, max: number, required = false): string | null =>
  value == null ? null : str(value, max, required);
function decodeProfile(raw: unknown, version: number, owner: string): Profile {
  const p = map(raw);
  keys(p, [
    'name',
    'username',
    'headline',
    'bio',
    'locationText',
    'avatarUrl',
    ...(version >= 3 ? ['avatarPath'] : []),
    ...(version >= 6 ? ['publishLocation'] : []),
  ]);
  const username = str(p.username, 30);
  if (username && !/^[a-z0-9][a-z0-9-]{1,28}[a-z0-9]$/.test(username))
    throw new ContractError('Username: 3–30 строчных латинских символов, цифр или дефисов.');
  const avatarUrl = str(p.avatarUrl, 2048);
  if (avatarUrl && !safeHttpUrl(avatarUrl)) throw new ContractError();
  const avatarPath = str(p.avatarPath ?? '', 300);
  mediaPath(avatarPath, owner);
  return {
    name: str(p.name, 100),
    username,
    headline: str(p.headline, 160),
    bio: str(p.bio, 4000),
    locationText: str(p.locationText, 200),
    avatarUrl,
    avatarPath,
    publishLocation: bool(p.publishLocation, false),
  };
}
function mediaPath(path: string, owner: string) {
  if (
    path &&
    (!/^accounts\/[^/]+\/media\/[0-9a-f]{32}\.jpg$/.test(path) ||
      !path.startsWith(`accounts/${owner}/media/`))
  )
    throw new ContractError('Изображение принадлежит другому аккаунту.');
}
function decodeBase(raw: unknown, version: number, owner: string): BaseData {
  const x = map(raw);
  const skills = ids(
    list(x.skills).map((raw) => {
      const s = map(raw);
      keys(s, ['id', 'name']);
      return { id: str(s.id, 200, true), name: str(s.name, 60, true) };
    }),
  );
  const experience = ids(
    list(x.experience).map((raw) => {
      const e = map(raw);
      keys(e, ['id', 'role', 'organization', 'period', 'description']);
      return {
        id: str(e.id, 200, true),
        role: str(e.role, 120, true),
        organization: str(e.organization, 160, true),
        period: str(e.period, 120),
        description: str(e.description, 4000),
      };
    }),
  );
  const education = ids(
    list(x.education).map((raw) => {
      const e = map(raw);
      keys(e, ['id', 'institution', 'qualification', 'period', 'description']);
      return {
        id: str(e.id, 200, true),
        institution: str(e.institution, 160, true),
        qualification: str(e.qualification, 160, true),
        period: str(e.period, 120),
        description: str(e.description, 4000),
      };
    }),
  );
  const links = ids(
    list(x.links).map((raw) => {
      const l = map(raw);
      keys(l, [
        'id',
        'label',
        'url',
        'kind',
        ...(version >= 6 ? ['publishAllowed', 'visible'] : []),
      ]);
      const kind = str(l.kind, 20) as Contact['kind'];
      if (!(version >= 6 ? linkKinds : linkKinds.slice(0, 4)).includes(kind))
        throw new ContractError();
      const url = str(l.url, 2048, true);
      if (!safeContactUrl(url, kind)) throw new ContractError('Некорректная ссылка контакта.');
      return {
        id: str(l.id, 200, true),
        label: str(l.label, 80, true),
        url,
        kind,
        publishAllowed: bool(l.publishAllowed, false),
        visible: bool(l.visible, true),
      };
    }),
  );
  return {
    profile: decodeProfile(x.profile, version, owner),
    skills,
    experience,
    education,
    links,
  };
}
function decodeProject(raw: unknown, version: number, owner: string): Project {
  const p = map(raw);
  keys(p, [
    'id',
    'title',
    'description',
    'technologies',
    'repositoryUrl',
    'liveUrl',
    'featured',
    'visible',
    'updatedAt',
    'source',
    'githubMetadata',
    ...(version >= 3 ? ['imagePaths'] : []),
    ...(version >= 6 ? ['contribution'] : []),
    ...(version >= 7 ? ['iconId'] : []),
  ]);
  const repositoryUrl = str(p.repositoryUrl, 2048),
    liveUrl = str(p.liveUrl, 2048);
  if ((repositoryUrl && !safeHttpUrl(repositoryUrl)) || (liveUrl && !safeHttpUrl(liveUrl)))
    throw new ContractError('Некорректный URL проекта.');
  const imagePaths = list(p.imagePaths ?? [], 6).map((x) => {
    const path = str(x, 300, true);
    mediaPath(path, owner);
    return path;
  });
  const source = p.source ?? 'manual';
  if (!['manual', 'github'].includes(source as string)) throw new ContractError();
  let githubMetadata: Project['githubMetadata'] = null;
  if (p.githubMetadata != null) {
    const m = map(p.githubMetadata);
    keys(m, ['acceptedSource', 'lastGitHubSyncAt', 'overrideFields']);
    const s = map(m.acceptedSource);
    keys(s, [
      'repositoryId',
      'name',
      'fullName',
      'htmlUrl',
      'description',
      'language',
      'stars',
      'forks',
      'isFork',
      'archived',
      'updatedAt',
    ]);
    for (const n of ['repositoryId', 'stars', 'forks'])
      if (!Number.isSafeInteger(s[n]) || (s[n] as number) < (n === 'repositoryId' ? 1 : 0))
        throw new ContractError();
    const htmlUrl = str(s.htmlUrl, 2048, true);
    if (!safeHttpUrl(htmlUrl)) throw new ContractError();
    const acceptedSource: GitHubSource = {
      repositoryId: s.repositoryId as number,
      name: str(s.name, 120, true),
      fullName: str(s.fullName, 300, true),
      htmlUrl,
      description: nullable(s.description, 4000),
      language: nullable(s.language, 60),
      stars: s.stars as number,
      forks: s.forks as number,
      isFork: bool(s.isFork),
      archived: bool(s.archived),
      updatedAt: date(s.updatedAt),
    };
    const overrideFields = list(m.overrideFields, 6).map((x) => str(x, 40, true));
    if (
      overrideFields.some(
        (x) => !['title', 'description', 'technologies', 'repositoryUrl'].includes(x),
      ) ||
      new Set(overrideFields).size !== overrideFields.length
    )
      throw new ContractError();
    githubMetadata = {
      acceptedSource,
      lastGitHubSyncAt: m.lastGitHubSyncAt == null ? null : date(m.lastGitHubSyncAt),
      overrideFields,
    };
  }
  if ((source === 'manual') !== !githubMetadata) throw new ContractError();
  return {
    id: str(p.id, 200, true),
    title: str(p.title, 120, true),
    description: str(p.description, 4000),
    contribution: str(p.contribution ?? '', 4000),
    technologies: list(p.technologies, 20).map((x) => str(x, 60, true)),
    repositoryUrl,
    liveUrl,
    featured: bool(p.featured),
    visible: bool(p.visible),
    imagePaths,
    iconId: decodeIconId(p.iconId),
    ...(p.updatedAt == null ? {} : { updatedAt: date(p.updatedAt) }),
    source: source as Project['source'],
    githubMetadata,
  };
}
function decodeContent(
  raw: unknown,
  version: number,
  owner: string,
  documents: boolean,
): WorkspaceContent {
  const x = map(raw);
  keys(x, [
    'profile',
    'skills',
    'projects',
    'experience',
    'education',
    'links',
    'blocks',
    'resumeText',
    'theme',
    'ignoredGitHubRepositories',
    ...(documents && version >= 4 ? ['documents'] : []),
    ...(documents && version >= 7
      ? ['mainPortfolioId', 'githubUsername', 'personalization', 'legacyMainSnapshot']
      : []),
  ]);
  const projects = ids(list(x.projects).map((p) => decodeProject(p, version, owner)));
  const gh = projects.flatMap((p) =>
    p.githubMetadata ? [p.githubMetadata.acceptedSource.repositoryId] : [],
  );
  if (new Set(gh).size !== gh.length) throw new ContractError();
  const blocks = list(x.blocks, blockKinds.length).map((raw) => {
    const b = map(raw);
    keys(b, ['kind', 'visible']);
    if (!blockKinds.includes(b.kind as BlockKind)) throw new ContractError();
    return { kind: b.kind as BlockKind, visible: bool(b.visible) };
  });
  if (
    blocks.length !== blockKinds.length ||
    new Set(blocks.map((b) => b.kind)).size !== blockKinds.length ||
    !['dark', 'light'].includes(x.theme as string)
  )
    throw new ContractError();
  const ignoredGitHubRepositories = list(x.ignoredGitHubRepositories ?? []).map((raw) => {
    const i = map(raw);
    keys(i, ['repositoryId', 'fingerprint']);
    if (!Number.isSafeInteger(i.repositoryId) || (i.repositoryId as number) < 1)
      throw new ContractError();
    return {
      repositoryId: i.repositoryId as number,
      fingerprint: str(i.fingerprint, 200, true),
    };
  });
  if (
    new Set(ignoredGitHubRepositories.map((i) => i.repositoryId)).size !==
    ignoredGitHubRepositories.length
  )
    throw new ContractError();
  const result: WorkspaceContent = {
    ...decodeBase(x, version, owner),
    projects,
    blocks,
    resumeText: str(x.resumeText, 20000),
    theme: x.theme as 'dark' | 'light',
    ignoredGitHubRepositories,
    documents: [],
    mainPortfolioId: null,
    githubUsername: '',
    personalization: { status: 'notRequired', step: 0 },
  };
  if (documents)
    result.documents = ids(
      list(x.documents ?? [], version >= 7 ? 21 : 20).map((raw) => {
        const d = map(raw);
        keys(d, [
          'id',
          'title',
          'kind',
          'createdAt',
          'updatedAt',
          'content',
          'projects',
          'attachedResumeId',
          ...(version >= 5 ? ['baseSnapshot'] : []),
        ]);
        if (!['resume', 'portfolio'].includes(d.kind as string)) throw new ContractError();
        const {
          documents: _,
          mainPortfolioId: _main,
          githubUsername: _github,
          personalization: _personalization,
          legacyMainSnapshot: _legacy,
          ...content
        } = decodeContent(d.content, version, owner, false);
        if (content.projects.length || content.ignoredGitHubRepositories.length)
          throw new ContractError();
        const createdAt = date(d.createdAt),
          updatedAt = date(d.updatedAt);
        if (microseconds(updatedAt) < microseconds(createdAt)) throw new ContractError();
        const attachments = list(d.projects).map((raw) => {
          const a = map(raw);
          keys(a, [
            'projectId',
            'visible',
            'featured',
            ...(version >= 6
              ? ['titleOverride', 'descriptionOverride', 'contributionOverride']
              : []),
          ]);
          return {
            projectId: str(a.projectId, 200, true),
            visible: bool(a.visible),
            featured: bool(a.featured),
            titleOverride: nullable(a.titleOverride, 120, true),
            descriptionOverride: nullable(a.descriptionOverride, 4000),
            contributionOverride: nullable(a.contributionOverride, 4000),
          };
        });
        if (
          new Set(attachments.map((a) => a.projectId)).size !== attachments.length ||
          attachments.some((a) => !projects.some((p) => p.id === a.projectId))
        )
          throw new ContractError('Нарушена связь документа с Library.');
        let baseSnapshot: BaseData | undefined;
        if (d.baseSnapshot != null) {
          keys(map(d.baseSnapshot), ['profile', 'skills', 'experience', 'education', 'links']);
          baseSnapshot = decodeBase(d.baseSnapshot, version, owner);
        }
        return {
          id: str(d.id, 200, true),
          title: str(d.title, 120, true),
          kind: d.kind as PortfolioDocument['kind'],
          createdAt,
          updatedAt,
          content,
          projects: attachments,
          attachedResumeId: nullable(d.attachedResumeId, 200, true),
          ...(baseSnapshot ? { baseSnapshot } : {}),
        };
      }),
    );
  if (
    result.documents.some(
      (d) =>
        d.attachedResumeId &&
        (d.kind !== 'portfolio' ||
          !result.documents.some((r) => r.id === d.attachedResumeId && r.kind === 'resume')),
    )
  )
    throw new ContractError('Неверная связь с резюме.');
  if (documents && version >= 7) {
    if (!('mainPortfolioId' in x) || !('githubUsername' in x) || !('personalization' in x))
      throw new ContractError();
    result.mainPortfolioId = nullable(x.mainPortfolioId, 200, true);
    if (result.mainPortfolioId && !result.documents.some((d) => d.id === result.mainPortfolioId))
      throw new ContractError('Основное портфолио отсутствует.');
    result.githubUsername = str(x.githubUsername ?? '', 39);
    if (
      result.githubUsername &&
      normalizeGitHubUsername(result.githubUsername) !== result.githubUsername
    )
      throw new ContractError('Некорректный GitHub-профиль.');
    const personalization = map(x.personalization ?? { status: 'notRequired', step: 0 });
    keys(personalization, ['status', 'step']);
    if (
      !['notRequired', 'inProgress', 'completed'].includes(personalization.status as string) ||
      !Number.isInteger(personalization.step) ||
      (personalization.step as number) < 0 ||
      (personalization.step as number) > 3
    )
      throw new ContractError('Некорректный прогресс персонализации.');
    result.personalization = {
      status: personalization.status as WorkspaceContent['personalization']['status'],
      step: personalization.step as number,
    };
    if (x.legacyMainSnapshot != null) {
      const backup = map(x.legacyMainSnapshot);
      const placeholders = list(backup.projects).map((raw) => ({
        id: str(map(raw).projectId, 200, true),
        title: 'Legacy',
        description: '',
        contribution: '',
        technologies: [],
        repositoryUrl: '',
        liveUrl: '',
        featured: false,
        visible: true,
        imagePaths: [],
        iconId: 'folder',
        source: 'manual',
        githubMetadata: null,
      }));
      const restored = decodeContent(
        {
          ...x,
          mainPortfolioId: null,
          legacyMainSnapshot: null,
          projects: placeholders,
          documents: [{ ...backup, attachedResumeId: null }],
        },
        version,
        owner,
        true,
      );
      result.legacyMainSnapshot = {
        ...restored.documents[0],
        attachedResumeId: nullable(backup.attachedResumeId, 200, true),
      };
    }
  }
  return result;
}
export function decodeDraft(raw: unknown, owner: string): DraftEnvelope {
  const x = map(raw);
  keys(x, [
    'schemaVersion',
    'ownerUid',
    'mutationId',
    'localRevision',
    'notes',
    'content',
    'updatedAt',
  ]);
  const timestamp = x.updatedAt as
    { seconds?: number; nanoseconds?: number; toMillis?: () => number } | undefined;
  if (
    Object.keys(x).length !== 7 ||
    !owner ||
    owner.includes('/') ||
    x.ownerUid !== owner ||
    !Number.isSafeInteger(x.schemaVersion) ||
    (x.schemaVersion as number) < 1 ||
    (x.schemaVersion as number) > 7 ||
    !Number.isSafeInteger(x.localRevision) ||
    (x.localRevision as number) < 1 ||
    !timestamp ||
    !Number.isSafeInteger(timestamp.seconds) ||
    !Number.isSafeInteger(timestamp.nanoseconds) ||
    (timestamp.nanoseconds ?? -1) < 0 ||
    (timestamp.nanoseconds ?? 1e9) >= 1e9 ||
    typeof timestamp.toMillis !== 'function'
  )
    throw new ContractError();
  return {
    schemaVersion: x.schemaVersion as number,
    ownerUid: owner,
    mutationId: str(x.mutationId, 200, true),
    localRevision: x.localRevision as number,
    notes: str(x.notes, Number.MAX_SAFE_INTEGER),
    content:
      x.content == null ? null : decodeContent(x.content, x.schemaVersion as number, owner, true),
    updatedAt: x.updatedAt,
  };
}
export function validateWorkspace(content: WorkspaceContent, owner: string): WorkspaceContent {
  return decodeContent(content, 7, owner, true);
}
export function assertWriteBasis(current: DraftEnvelope | null, basis: DraftEnvelope | null): void {
  if (
    (current === null) !== (basis === null) ||
    (current &&
      basis &&
      (current.mutationId !== basis.mutationId ||
        current.localRevision !== basis.localRevision ||
        !timestampEquals(current.updatedAt, basis.updatedAt) ||
        !equal(current.content, basis.content) ||
        current.notes !== basis.notes))
  )
    throw new ContractError(
      'База обновлена на другом устройстве. Ваша правка сохранена в форме. Перезагрузите серверную версию перед повторным Save.',
    );
}
export type BaseChange = {
  id: string;
  label: string;
  before: unknown;
  current: unknown;
  incoming: unknown;
  localOverride: boolean;
  apply: (d: PortfolioDocument) => PortfolioDocument;
};
export function baseChanges(workspace: BaseData, document: PortfolioDocument): BaseChange[] {
  const incomingBase = baseData(workspace);
  const capturedDocument = clone(document);
  const base = capturedDocument.baseSnapshot;
  const changes: BaseChange[] = [];
  const profileLabels: Record<keyof Profile, string> = {
    name: 'Имя',
    username: 'Username',
    headline: 'Профессиональная роль',
    bio: 'О себе',
    locationText: 'Город и страна',
    avatarUrl: 'Ссылка на фото',
    avatarPath: 'Фотография',
    publishLocation: 'Публикация местоположения',
  };
  for (const key of Object.keys(incomingBase.profile) as (keyof Profile)[]) {
    if (key === 'avatarUrl' || key === 'avatarPath') continue;
    const incoming = incomingBase.profile[key],
      before = base?.profile[key],
      current = capturedDocument.content.profile[key];
    if (!equal(before, incoming))
      changes.push({
        id: 'profile.' + key,
        label: profileLabels[key],
        before,
        current,
        incoming,
        localOverride: !base || !equal(current, before),
        apply: (d) => ({
          ...d,
          content: {
            ...d.content,
            profile: { ...d.content.profile, [key]: incoming },
          },
        }),
      });
  }
  const avatar = (profile: Profile) => ({
    avatarUrl: profile.avatarUrl,
    avatarPath: profile.avatarPath,
  });
  const incomingAvatar = avatar(incomingBase.profile);
  const beforeAvatar = base ? avatar(base.profile) : undefined;
  const currentAvatar = avatar(capturedDocument.content.profile);
  if (!equal(beforeAvatar, incomingAvatar))
    changes.push({
      id: 'profile.avatarPath',
      label: profileLabels.avatarPath,
      before: beforeAvatar,
      current: currentAvatar,
      incoming: incomingAvatar,
      localOverride: !base || !equal(currentAvatar, beforeAvatar),
      apply: (d) => ({
        ...d,
        content: { ...d.content, profile: { ...d.content.profile, ...incomingAvatar } },
      }),
    });
  for (const key of ['skills', 'experience', 'education', 'links'] as const) {
    const incomingItems = incomingBase[key] as { id: string }[],
      beforeItems = (base?.[key] ?? []) as { id: string }[],
      currentItems = capturedDocument.content[key] as { id: string }[];
    for (const id of new Set([...incomingItems, ...beforeItems].map((i) => i.id))) {
      const incoming = incomingItems.find((i) => i.id === id),
        before = beforeItems.find((i) => i.id === id),
        current = currentItems.find((i) => i.id === id);
      if (equal(incoming, before)) continue;
      const item = (incoming ?? current ?? before) as Record<string, unknown> | undefined;
      const itemTitle = item?.name ?? item?.role ?? item?.institution ?? item?.label ?? '';
      const sectionTitle = {
        skills: 'Навык',
        experience: 'Опыт',
        education: 'Образование',
        links: 'Контакт',
      }[key];
      changes.push({
        id: key + '.' + id,
        label: sectionTitle + (itemTitle ? ' · ' + itemTitle : ''),
        before,
        current,
        incoming,
        localOverride: !base || !equal(before, current),
        apply: (d) => {
          const items = d.content[key].filter((i) => i.id !== id);
          const position = d.content[key].findIndex((i) => i.id === id);
          const next =
            key === 'links' && incoming && current
              ? { ...clone(incoming), visible: (current as Contact).visible }
              : clone(incoming);
          if (next) items.splice(position < 0 ? items.length : position, 0, next as never);
          return { ...d, content: { ...d.content, [key]: items } };
        },
      });
    }
  }
  return changes;
}
export function acceptBaseChanges(
  workspace: BaseData,
  document: PortfolioDocument,
  selected: Set<string>,
): PortfolioDocument {
  let next = clone(document);
  for (const change of baseChanges(workspace, document))
    if (selected.has(change.id)) next = change.apply(next);
  return {
    ...next,
    baseSnapshot: baseData(workspace),
    updatedAt: new Date().toISOString(),
  };
}

export type DocumentBaseReview = {
  ownerUid: string;
  base: BaseData;
  document: PortfolioDocument;
  savedDocument: PortfolioDocument | undefined;
  changes: BaseChange[];
};
export function createDocumentBaseReview(
  ownerUid: string,
  savedWorkspace: WorkspaceContent,
  document: PortfolioDocument,
): DocumentBaseReview {
  const capturedBase = baseData(savedWorkspace);
  const capturedDocument = clone(document);
  return {
    ownerUid,
    base: capturedBase,
    document: capturedDocument,
    savedDocument: clone(savedWorkspace.documents.find((d) => d.id === document.id)),
    changes: baseChanges(capturedBase, capturedDocument),
  };
}
export function applyDocumentBaseReview(
  review: DocumentBaseReview,
  ownerUid: string,
  savedWorkspace: WorkspaceContent,
  currentDocument: PortfolioDocument,
  selected: Set<string>,
): PortfolioDocument {
  if (
    review.ownerUid !== ownerUid ||
    !equal(review.base, baseData(savedWorkspace)) ||
    !equal(
      review.savedDocument,
      savedWorkspace.documents.find((d) => d.id === review.document.id),
    ) ||
    !equal(review.document, currentDocument)
  )
    throw new ContractError(
      'Аккаунт, сохранённая база или документ изменились. Откройте сравнение заново.',
    );
  return acceptBaseChanges(review.base, review.document, selected);
}

function decodeIconId(value: unknown): ProjectIconId {
  if (value == null) return 'folder';
  if (!projectIconIds.includes(value as ProjectIconId))
    throw new ContractError('Выберите встроенную иконку проекта.');
  return value as ProjectIconId;
}
export function normalizeGitHubUsername(value: string): string {
  let name = value.trim();
  const url = /^https:\/\/(?:www\.)?github\.com\/([^/?#]+)\/?$/i.exec(name);
  if (url) name = url[1];
  if (!name) return '';
  if (!/^[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,37}[a-zA-Z0-9])?$/.test(name) || name.includes('--'))
    throw new ContractError('Введите username или ссылку https://github.com/username.');
  return name.toLowerCase();
}
export function mainDocument(workspace: WorkspaceContent): PortfolioDocument | undefined {
  return workspace.documents.find((d) => d.id === workspace.mainPortfolioId);
}
export const mainPortfolioSectionKinds = [
  'links',
  'skills',
  'featuredProjects',
  'experience',
  'education',
] as const;
export type MainPortfolioSectionKind = (typeof mainPortfolioSectionKinds)[number];

export function mainPortfolioSectionOrder(
  content: Pick<DocumentContent, 'blocks'>,
): MainPortfolioSectionKind[] {
  const kinds = content.blocks.map((block) => block.kind);
  if (
    kinds.length === blockKinds.length &&
    kinds.every((kind, index) => kind === blockKinds[index])
  )
    return [...mainPortfolioSectionKinds];
  return [
    ...new Set([
      ...kinds.filter((kind): kind is MainPortfolioSectionKind =>
        mainPortfolioSectionKinds.includes(kind as MainPortfolioSectionKind),
      ),
      ...mainPortfolioSectionKinds,
    ]),
  ];
}

export function mainPortfolioBlocks(
  content: Pick<DocumentContent, 'blocks'>,
): DocumentContent['blocks'] {
  return [
    { kind: 'profile', visible: true },
    { kind: 'about', visible: true },
    { kind: 'location', visible: true },
    ...mainPortfolioSectionOrder(content).flatMap((kind): DocumentContent['blocks'] => [
      { kind, visible: true },
      ...(kind === 'links' ? [{ kind: 'github' as const, visible: true }] : []),
    ]),
    { kind: 'resume', visible: false },
  ];
}

export function migrateMainPortfolio(
  workspace: WorkspaceContent,
  selectedId: string | null,
  now = new Date(),
): WorkspaceContent {
  if (workspace.mainPortfolioId) throw new ContractError('Основное портфолио уже выбрано.');
  const source = selectedId ? workspace.documents.find((d) => d.id === selectedId) : undefined;
  if (selectedId && !source) throw new ContractError('Документ для переноса отсутствует.');
  const original =
    source ?? createDocument({ ...workspace, documents: [] }, 'portfolio', 'Портфолио', now);
  const candidate = clone(original);
  const input = source?.content ?? seedDocument(workspace);
  const visible = (kind: BlockKind) => input.blocks.some((b) => b.kind === kind && b.visible);
  const profile = clone(input.profile);
  if (!visible('profile')) {
    profile.name = '';
    profile.headline = '';
    profile.avatarUrl = '';
    profile.avatarPath = '';
  }
  if (!visible('about')) profile.bio = '';
  if (!(visible('location') && workspace.profile.publishLocation && profile.publishLocation))
    profile.locationText = '';
  profile.publishLocation = true;
  const selectedContacts = input.links.filter(
    (l) =>
      l.visible &&
      l.publishAllowed &&
      visible(l.kind === 'github' ? 'github' : 'links') &&
      workspace.links.some((b) => b.id === l.id && b.visible && b.publishAllowed),
  );
  candidate.content = {
    ...clone(input),
    profile,
    skills: visible('skills') ? clone(input.skills) : [],
    experience: visible('experience') ? clone(input.experience) : [],
    education: visible('education') ? clone(input.education) : [],
    links: clone(selectedContacts),
    blocks: mainPortfolioBlocks(input),
    projects: [],
    ignoredGitHubRepositories: [],
  };
  candidate.projects = visible('featuredProjects')
    ? clone(
        source?.projects.filter(
          (a) => a.visible && workspace.projects.some((p) => p.id === a.projectId && p.visible),
        ) ?? workspace.projects.filter((p) => p.visible).map((p) => attachment(p.id)),
      )
    : [];
  candidate.updatedAt = now.toISOString();
  candidate.attachedResumeId = null;
  return {
    ...clone(workspace),
    mainPortfolioId: candidate.id,
    ...(source
      ? { legacyMainSnapshot: clone(source) }
      : workspace.documents.length ||
          workspace.projects.length ||
          workspace.profile.name ||
          workspace.profile.bio ||
          workspace.links.length ||
          workspace.skills.length ||
          workspace.experience.length ||
          workspace.education.length
        ? {
            legacyMainSnapshot: {
              ...clone(original),
              id: 'legacy-base',
              title: 'Прежняя общая база',
              content: seedDocument(workspace),
              projects: workspace.projects.map((p) => attachment(p.id)),
            },
          }
        : {}),
    documents: source
      ? workspace.documents.map((d) => (d.id === source.id ? candidate : clone(d)))
      : [...clone(workspace.documents), candidate],
  };
}
export function deleteLibraryProject(
  workspace: WorkspaceContent,
  projectId: string,
): WorkspaceContent {
  return {
    ...workspace,
    projects: workspace.projects.filter((p) => p.id !== projectId),
    documents: workspace.documents.map((d) => ({
      ...d,
      projects: d.projects.filter((a) => a.projectId !== projectId),
    })),
  };
}
export function importGitHubProjects(
  workspace: WorkspaceContent,
  sources: GitHubSource[],
): WorkspaceContent {
  const existing = new Set(
    workspace.projects.flatMap((p) =>
      p.githubMetadata ? [p.githubMetadata.acceptedSource.repositoryId] : [],
    ),
  );
  const imported: Project[] = [];
  for (const source of sources) {
    if (existing.has(source.repositoryId)) continue;
    existing.add(source.repositoryId);
    imported.push({
      id: uid(),
      iconId: 'folder',
      title: source.name,
      description: source.description ?? '',
      contribution: '',
      technologies: source.language ? [source.language] : [],
      repositoryUrl: source.htmlUrl,
      liveUrl: '',
      featured: false,
      visible: true,
      imagePaths: [],
      source: 'github',
      githubMetadata: {
        acceptedSource: clone(source),
        lastGitHubSyncAt: new Date().toISOString(),
        overrideFields: [],
      },
    });
  }
  return { ...workspace, projects: [...workspace.projects, ...imported] };
}
export function rebaseLibraryChange(
  saved: WorkspaceContent,
  previous: WorkspaceContent,
  working: WorkspaceContent,
): WorkspaceContent {
  // Scoped операция сохраняет Library, оставляя соседний несохранённый ввод.
  const removed = new Set(
    previous.projects
      .filter((p) => !saved.projects.some((next) => next.id === p.id))
      .map((p) => p.id),
  );
  return {
    ...working,
    githubUsername:
      working.githubUsername === previous.githubUsername
        ? saved.githubUsername
        : working.githubUsername,
    projects: [
      ...working.projects.filter((p) => !removed.has(p.id)),
      ...saved.projects.filter(
        (p) =>
          !previous.projects.some((old) => old.id === p.id) &&
          !working.projects.some((current) => current.id === p.id),
      ),
    ],
    documents: working.documents.map((d) => ({
      ...d,
      projects: d.projects.filter((a) => !removed.has(a.projectId)),
    })),
  };
}

export function advancePersonalization(
  workspace: WorkspaceContent,
  action: 'next' | 'skip' | 'back',
): WorkspaceContent {
  if (workspace.personalization.status !== 'inProgress') return clone(workspace);
  const current = workspace.personalization.step;
  return {
    ...workspace,
    personalization: {
      status: current === 3 && action !== 'back' ? 'completed' : 'inProgress',
      step: action === 'back' ? Math.max(0, current - 1) : Math.min(3, current + 1),
    },
  };
}
