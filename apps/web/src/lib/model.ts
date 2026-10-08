// Совместимый aggregate мобильного PortfolioContent. Private cloud writer — schema 6.
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
export type Project = {
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
export const equal = (a: unknown, b: unknown) => JSON.stringify(a) === JSON.stringify(b);
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
    theme: 'dark',
    ignoredGitHubRepositories: [],
    documents: [],
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
  const { documents: _, ...rest } = clone(content);
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
    content: seedDocument(content),
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
  return path && /^\/workspace(?:\/[A-Za-z0-9_-]+)*(?:\?[A-Za-z0-9_=&%-]*)?$/.test(path)
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
  };
  if (documents)
    result.documents = ids(
      list(x.documents ?? [], 20).map((raw) => {
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
        const { documents: _, ...content } = decodeContent(d.content, version, owner, false);
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
    (x.schemaVersion as number) > 6 ||
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
  return decodeContent(content, 6, owner, true);
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
export function baseChanges(
  workspace: WorkspaceContent,
  document: PortfolioDocument,
): BaseChange[] {
  const base = document.baseSnapshot;
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
  for (const key of Object.keys(workspace.profile) as (keyof Profile)[]) {
    const incoming = workspace.profile[key],
      before = base?.profile[key],
      current = document.content.profile[key];
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
  for (const key of ['skills', 'experience', 'education', 'links'] as const) {
    const incomingItems = workspace[key] as { id: string }[],
      beforeItems = (base?.[key] ?? []) as { id: string }[],
      currentItems = document.content[key] as { id: string }[];
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
  workspace: WorkspaceContent,
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
