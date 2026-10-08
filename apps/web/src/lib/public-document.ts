export type PublicDocumentKind = 'resume' | 'portfolio';
export type PublicLinkKind =
  'other' | 'github' | 'website' | 'linkedin' | 'email' | 'phone' | 'telegram';
export interface PublicProject {
  id: string;
  title: string;
  description: string;
  contribution: string;
  technologies: string[];
  repositoryUrl: string;
  liveUrl: string;
  featured: boolean;
  visible: true;
  imageUrls: string[];
}
export interface PublicDocumentContent {
  profile: {
    name: string;
    username: string;
    headline: string;
    bio: string;
    locationText: string;
    avatarUrl: string;
  };
  skills: { id: string; name: string }[];
  projects: PublicProject[];
  experience: {
    id: string;
    role: string;
    organization: string;
    period: string;
    description: string;
  }[];
  education: {
    id: string;
    institution: string;
    qualification: string;
    period: string;
    description: string;
  }[];
  links: { id: string; label: string; url: string; kind: PublicLinkKind }[];
  blocks: { kind: string; visible: true }[];
  resumeText: string;
  theme: 'dark' | 'light';
}
export interface PublicDocument {
  schemaVersion: 1;
  publicId: string;
  version: number;
  title: string;
  kind: PublicDocumentKind;
  attachedResumePublicId: string | null;
  content: PublicDocumentContent;
  publishedAt: string;
}

export const isPublicId = (value: string) => /^[a-f0-9]{32}$/.test(value);
const blockKinds = [
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
];
const linkKinds: PublicLinkKind[] = [
  'other',
  'github',
  'website',
  'linkedin',
  'email',
  'phone',
  'telegram',
];
const mediaHosts = new Set(['avatars.githubusercontent.com', 'images.unsplash.com']);

export function safePublicHref(value: string, kind?: PublicLinkKind): string | null {
  if (!value || value.length > 2048 || /[\s\x00-\x1f\x7f]/.test(value)) return null;
  if (kind === 'email')
    return /^mailto:[A-Za-z0-9.!$&'*+/=_^`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+$/.test(
      value,
    )
      ? value
      : null;
  if (kind === 'phone') return /^tel:\+[0-9]{7,15}$/.test(value) ? value : null;
  if (kind === 'telegram' && !/^https:\/\/t\.me\/[A-Za-z0-9_]{1,64}$/.test(value)) return null;
  try {
    const url = new URL(value);
    return /^https?:\/\//.test(value) &&
      ['https:', 'http:'].includes(url.protocol) &&
      !!url.hostname &&
      !url.username &&
      !url.password
      ? value
      : null;
  } catch {
    return null;
  }
}

export function safePublicMedia(value: string, publicId?: string, version?: number): string | null {
  const match = /^publicMedia\/([a-f0-9]{32})\/([1-9][0-9]*)\/([a-f0-9]{32})\.jpg$/.exec(value);
  if (match) {
    if (
      (publicId && match[1] !== publicId) ||
      (version !== undefined && Number(match[2]) !== version)
    )
      return null;
    const bucket = process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET;
    if (!bucket || !/^[A-Za-z0-9][A-Za-z0-9.-]{1,221}$/.test(bucket)) return null;
    let origin = 'https://firebasestorage.googleapis.com';
    if (process.env.NEXT_PUBLIC_USE_EMULATORS === 'true') {
      const host = process.env.NEXT_PUBLIC_STORAGE_EMULATOR_HOST ?? '127.0.0.1';
      const port = process.env.NEXT_PUBLIC_STORAGE_EMULATOR_PORT ?? '9199';
      if (!['127.0.0.1', 'localhost'].includes(host) || !/^\d{2,5}$/.test(port)) return null;
      origin = `http://${host}:${port}`;
    }
    // Только анонимный Rules-защищённый объект; bearer/download token отсутствует.
    return `${origin}/v0/b/${encodeURIComponent(bucket)}/o/${encodeURIComponent(value)}?alt=media`;
  }
  if (!safePublicHref(value)) return null;
  const url = new URL(value);
  return url.protocol === 'https:' && mediaHosts.has(url.hostname) && !url.port ? value : null;
}

class InvalidPublicDocument extends Error {}
const invalid = (): never => {
  throw new InvalidPublicDocument();
};
function record(value: unknown, keys: string[]): Record<string, unknown> {
  if (
    !value ||
    typeof value !== 'object' ||
    Array.isArray(value) ||
    Object.getPrototypeOf(value) !== Object.prototype
  )
    invalid();
  const result = value as Record<string, unknown>;
  if (
    Object.keys(result).length !== keys.length ||
    keys.some((key) => !Object.hasOwn(result, key)) ||
    Object.keys(result).some((key) => !keys.includes(key))
  )
    invalid();
  return result;
}
function text(value: unknown, max: number, required = false): string {
  if (typeof value !== 'string' || value.length > max || (required && !value.trim())) invalid();
  return value as string;
}
function list(value: unknown, max = 200): unknown[] {
  if (!Array.isArray(value) || value.length > max) invalid();
  return value as unknown[];
}
function identifier(value: unknown): string {
  const result = text(value, 200, true);
  if (/[\/\x00-\x1f\x7f]/.test(result)) invalid();
  return result;
}
function unique(items: { id: string }[]) {
  if (new Set(items.map((item) => item.id)).size !== items.length) invalid();
}
function publicMedia(value: unknown, publicId: string, version: number): string {
  const result = text(value, 2048);
  if (!result) return '';
  if (result.startsWith('publicMedia/')) {
    if (!new RegExp(`^publicMedia/${publicId}/${version}/[a-f0-9]{32}\\.jpg$`).test(result))
      invalid();
  } else if (!safePublicHref(result)) invalid();
  return result;
}
function optionalUrl(value: unknown): string {
  const result = text(value, 2048);
  if (result && !safePublicHref(result)) invalid();
  return result;
}

// Строгий публичный allowlist: неизвестный/private payload никогда не рендерится.
export function parsePublicDocument(
  value: unknown,
  expectedPublicId?: string,
): PublicDocument | null {
  try {
    const d = record(value, [
      'schemaVersion',
      'publicId',
      'version',
      'title',
      'kind',
      'attachedResumePublicId',
      'content',
      'publishedAt',
    ]);
    if (
      d.schemaVersion !== 1 ||
      typeof d.publicId !== 'string' ||
      !isPublicId(d.publicId) ||
      (expectedPublicId && d.publicId !== expectedPublicId) ||
      !Number.isSafeInteger(d.version) ||
      Number(d.version) < 1 ||
      typeof d.kind !== 'string' ||
      !['resume', 'portfolio'].includes(d.kind)
    )
      invalid();
    const publicId = d.publicId as string;
    const version = d.version as number;
    if (
      d.attachedResumePublicId !== null &&
      (typeof d.attachedResumePublicId !== 'string' ||
        !isPublicId(d.attachedResumePublicId) ||
        d.kind !== 'portfolio' ||
        d.attachedResumePublicId === publicId)
    )
      invalid();
    const publishedAt = text(d.publishedAt, 40, true);
    if (
      !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?Z$/.test(publishedAt) ||
      !Number.isFinite(Date.parse(publishedAt))
    )
      invalid();
    const c = record(d.content, [
      'profile',
      'skills',
      'projects',
      'experience',
      'education',
      'links',
      'blocks',
      'resumeText',
      'theme',
    ]);
    const p = record(c.profile, [
      'name',
      'username',
      'headline',
      'bio',
      'locationText',
      'avatarUrl',
    ]);
    const profile = {
      name: text(p.name, 100),
      username: text(p.username, 30),
      headline: text(p.headline, 160),
      bio: text(p.bio, 4000),
      locationText: text(p.locationText, 200),
      avatarUrl: publicMedia(p.avatarUrl, publicId, version),
    };
    if (profile.username && !/^[a-z0-9][a-z0-9-]{1,28}[a-z0-9]$/.test(profile.username)) invalid();
    const skills = list(c.skills).map((value) => {
      const s = record(value, ['id', 'name']);
      return { id: identifier(s.id), name: text(s.name, 60, true) };
    });
    const experience = list(c.experience).map((value) => {
      const e = record(value, ['id', 'role', 'organization', 'period', 'description']);
      return {
        id: identifier(e.id),
        role: text(e.role, 120, true),
        organization: text(e.organization, 160, true),
        period: text(e.period, 120),
        description: text(e.description, 4000),
      };
    });
    const education = list(c.education).map((value) => {
      const e = record(value, ['id', 'institution', 'qualification', 'period', 'description']);
      return {
        id: identifier(e.id),
        institution: text(e.institution, 160, true),
        qualification: text(e.qualification, 160, true),
        period: text(e.period, 120),
        description: text(e.description, 4000),
      };
    });
    const links = list(c.links).map((value) => {
      const l = record(value, ['id', 'label', 'url', 'kind']);
      if (
        !linkKinds.includes(l.kind as PublicLinkKind) ||
        !safePublicHref(text(l.url, 2048, true), l.kind as PublicLinkKind)
      )
        invalid();
      return {
        id: identifier(l.id),
        label: text(l.label, 80, true),
        url: l.url as string,
        kind: l.kind as PublicLinkKind,
      };
    });
    const projects = list(c.projects).map((value) => {
      const p = record(value, [
        'id',
        'title',
        'description',
        'contribution',
        'technologies',
        'repositoryUrl',
        'liveUrl',
        'featured',
        'visible',
        'imageUrls',
      ]);
      if (p.visible !== true || typeof p.featured !== 'boolean') invalid();
      return {
        id: identifier(p.id),
        title: text(p.title, 120, true),
        description: text(p.description, 4000),
        contribution: text(p.contribution, 4000),
        technologies: list(p.technologies, 20).map((value) => text(value, 60, true)),
        repositoryUrl: optionalUrl(p.repositoryUrl),
        liveUrl: optionalUrl(p.liveUrl),
        featured: p.featured as boolean,
        visible: true as const,
        imageUrls: list(p.imageUrls, 6).map((value) => {
          const result = publicMedia(value, publicId, version);
          if (!result) invalid();
          return result;
        }),
      };
    });
    const blocks = list(c.blocks, 10).map((value) => {
      const b = record(value, ['kind', 'visible']);
      if (typeof b.kind !== 'string' || !blockKinds.includes(b.kind) || b.visible !== true)
        invalid();
      return { kind: b.kind as string, visible: true as const };
    });
    if (
      new Set(blocks.map((b) => b.kind)).size !== blocks.length ||
      typeof c.theme !== 'string' ||
      !['dark', 'light'].includes(c.theme)
    )
      invalid();
    const visible = new Set(blocks.map((block) => block.kind));
    if (
      (!visible.has('profile') &&
        (profile.name || profile.username || profile.headline || profile.avatarUrl)) ||
      (!visible.has('about') && profile.bio) ||
      (!visible.has('location') && profile.locationText) ||
      (!visible.has('skills') && skills.length) ||
      (!visible.has('experience') && experience.length) ||
      (!visible.has('education') && education.length) ||
      (!visible.has('featuredProjects') && projects.length) ||
      (!visible.has('resume') && c.resumeText) ||
      (!visible.has('resume') && d.attachedResumePublicId !== null) ||
      links.some((link) => !visible.has(link.kind === 'github' ? 'github' : 'links'))
    )
      invalid();
    for (const items of [skills, experience, education, links, projects]) unique(items);
    return {
      schemaVersion: 1,
      publicId,
      version,
      title: text(d.title, 120, true),
      kind: d.kind as PublicDocumentKind,
      attachedResumePublicId: d.attachedResumePublicId as string | null,
      publishedAt,
      content: {
        profile,
        skills,
        experience,
        education,
        links,
        projects,
        blocks,
        resumeText: text(c.resumeText, 20000),
        theme: c.theme as 'dark' | 'light',
      },
    };
  } catch (error) {
    if (error instanceof InvalidPublicDocument) return null;
    throw error;
  }
}

function decodeFirestoreValue(value: unknown, depth = 0): unknown {
  if (depth > 12 || !value || typeof value !== 'object' || Array.isArray(value)) invalid();
  const entry = value as Record<string, unknown>;
  if (Object.keys(entry).length !== 1) invalid();
  if ('stringValue' in entry) return text(entry.stringValue, 100000);
  if ('timestampValue' in entry) return text(entry.timestampValue, 40);
  if ('integerValue' in entry) {
    if (
      typeof entry.integerValue !== 'string' ||
      !/^-?\d+$/.test(entry.integerValue) ||
      !Number.isSafeInteger(Number(entry.integerValue))
    )
      invalid();
    return Number(entry.integerValue);
  }
  if ('booleanValue' in entry) {
    if (typeof entry.booleanValue !== 'boolean') invalid();
    return entry.booleanValue;
  }
  if ('nullValue' in entry && entry.nullValue === null) return null;
  if ('arrayValue' in entry) {
    const a = entry.arrayValue as { values?: unknown };
    if (
      !a ||
      typeof a !== 'object' ||
      Array.isArray(a) ||
      Object.keys(a).some((key) => key !== 'values')
    )
      invalid();
    return list(a.values ?? [], 500).map((item) => decodeFirestoreValue(item, depth + 1));
  }
  if ('mapValue' in entry) {
    const m = entry.mapValue as { fields?: unknown };
    if (
      !m ||
      typeof m !== 'object' ||
      Array.isArray(m) ||
      Object.keys(m).some((key) => key !== 'fields')
    )
      invalid();
    const fields = m.fields ?? {};
    if (!fields || typeof fields !== 'object' || Array.isArray(fields)) invalid();
    return Object.fromEntries(
      Object.entries(fields).map(([key, item]) => [key, decodeFirestoreValue(item, depth + 1)]),
    );
  }
  invalid();
}

export class PublicDocumentUnavailable extends Error {}
export interface PublicReaderOptions {
  projectId?: string;
  fetch?: typeof fetch;
  emulatorOrigin?: string;
}
export async function readPublicDocument(
  publicId: string,
  options: PublicReaderOptions = {},
): Promise<PublicDocument | null> {
  if (!isPublicId(publicId)) return null;
  const projectId = options.projectId ?? process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID;
  if (!projectId || !/^[a-z][a-z0-9-]{4,62}$/.test(projectId)) return null;
  let origin = 'https://firestore.googleapis.com';
  const emulator =
    options.emulatorOrigin ??
    (process.env.NEXT_PUBLIC_USE_EMULATORS === 'true'
      ? `http://${process.env.NEXT_PUBLIC_FIRESTORE_EMULATOR_HOST ?? '127.0.0.1'}:${process.env.NEXT_PUBLIC_FIRESTORE_EMULATOR_PORT ?? '8085'}`
      : undefined);
  if (emulator) {
    let url: URL;
    try {
      url = new URL(emulator);
    } catch {
      throw new PublicDocumentUnavailable();
    }
    if (
      !['127.0.0.1', 'localhost'].includes(url.hostname) ||
      url.protocol !== 'http:' ||
      url.origin !== emulator
    )
      throw new PublicDocumentUnavailable();
    origin = emulator;
  }
  const endpoint = `${origin}/v1/projects/${projectId}/databases/(default)/documents/publicDocuments/${publicId}`;
  try {
    const response = await (options.fetch ?? fetch)(endpoint, {
      cache: 'no-store',
      credentials: 'omit',
      redirect: 'error',
      signal: AbortSignal.timeout(8000),
    });
    if ([403, 404].includes(response.status)) return null;
    if (!response.ok) throw new PublicDocumentUnavailable();
    const body = await response.text();
    if (body.length > 2_000_000) return null;
    let document: unknown;
    try {
      document = JSON.parse(body);
    } catch {
      return null;
    }
    if (!document || typeof document !== 'object' || Array.isArray(document)) return null;
    const fields = (document as { fields?: unknown }).fields;
    let decoded: unknown;
    try {
      decoded = decodeFirestoreValue({ mapValue: { fields } });
    } catch (error) {
      if (error instanceof InvalidPublicDocument) return null;
      throw error;
    }
    return parsePublicDocument(decoded, publicId);
  } catch (error) {
    if (error instanceof PublicDocumentUnavailable) throw error;
    throw new PublicDocumentUnavailable('Публичный документ временно недоступен.');
  }
}

export function publicDocumentMetadata(document: PublicDocument) {
  const label = document.kind === 'resume' ? 'Резюме' : 'Портфолио';
  return {
    title: `${document.content.profile.name || document.title} — ${label} | StackCard`,
    description: (
      document.content.profile.headline ||
      document.content.profile.bio ||
      document.title
    ).slice(0, 200),
  };
}
