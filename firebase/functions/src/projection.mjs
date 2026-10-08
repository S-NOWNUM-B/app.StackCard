import { createHash } from 'node:crypto';

export class PublicationError extends Error {
  constructor(code, message = code, httpStatus = 400) {
    super(message);
    this.code = code;
    this.httpStatus = httpStatus;
  }
}

const invalid = () => { throw new PublicationError('invalid-data'); };
const own = (value, key) => Object.hasOwn(value, key);
const object = (value, allowed, required = allowed) => {
  if (!value || typeof value !== 'object' || Array.isArray(value)
      || Object.getPrototypeOf(value) !== Object.prototype
      || Object.keys(value).some((key) => !allowed.includes(key))
      || required.some((key) => !own(value, key))) invalid();
  return value;
};
const text = (value, max, required = false) => {
  if (typeof value !== 'string' || value.length > max
      || (required && !value.trim())) invalid();
  return value;
};
const boolean = (value) => { if (typeof value !== 'boolean') invalid(); return value; };
const integer = (value, min = 0) => { if (!Number.isSafeInteger(value) || value < min) invalid(); return value; };
// Приватная aggregate уже ограничена Firestore 1 MiB; общий лимит 200 не применяется.
const list = (value, max = Number.POSITIVE_INFINITY) => { if (!Array.isArray(value) || value.length > max) invalid(); return value; };
const enumeration = (value, values) => { if (!values.includes(value)) invalid(); return value; };
const date = (value) => {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3,6})?Z$/.test(value)
      || !Number.isFinite(Date.parse(value))) invalid();
  return value;
};
const id = (value) => {
  text(value, 200, true);
  if (value.includes('/') || /[\x00-\x1f]/.test(value)) invalid();
  return value;
};
const unique = (items, key = 'id') => {
  const ids = items.map((item) => id(item[key]));
  if (new Set(ids).size !== ids.length) invalid();
};

function url(value, required = false) {
  text(value, 2048, required);
  if (!value && !required) return value;
  if (/[\s\x00-\x1f\x7f]/.test(value) || value !== value.trim()) invalid();
  let parsed;
  try { parsed = new URL(value); } catch { invalid(); }
  if (!['https:', 'http:'].includes(parsed.protocol) || !parsed.hostname
      || parsed.username || parsed.password || !/^https?:\/\//.test(value)) invalid();
  return value;
}

function contactUrl(value, kind) {
  text(value, 2048, true);
  if (value !== value.trim() || /[\x00-\x20\x7f]/.test(value)) invalid();
  if (kind === 'email') {
    if (!/^mailto:[A-Za-z0-9.!$&'*+/=_^`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+$/.test(value)) invalid();
  } else if (kind === 'phone') {
    if (!/^tel:\+[0-9]{7,15}$/.test(value)) invalid();
  } else if (kind === 'telegram') {
    if (!/^https:\/\/t\.me\/[A-Za-z0-9_]{1,64}$/.test(value)) invalid();
  } else url(value, true);
  return value;
}

function mediaPath(value, uid) {
  text(value, 1024);
  if (!value) return value;
  const parts = value.split('/');
  if (parts.length !== 4 || parts[0] !== 'accounts' || parts[1] !== uid
      || parts[2] !== 'media' || !/^[a-f0-9]{32}\.jpg$/.test(parts[3])) invalid();
  return value;
}

const profileKeys = ['name', 'username', 'headline', 'bio', 'locationText', 'avatarUrl', 'avatarPath', 'publishLocation'];
function profile(value, uid) {
  object(value, profileKeys, profileKeys.slice(0, 6));
  text(value.name, 100); text(value.username, 30);
  if (value.username && !/^[a-z0-9][a-z0-9-]{1,28}[a-z0-9]$/.test(value.username)) invalid();
  text(value.headline, 160); text(value.bio, 4000); text(value.locationText, 200);
  url(value.avatarUrl); mediaPath(value.avatarPath ?? '', uid);
  if (own(value, 'publishLocation')) boolean(value.publishLocation);
}

function sections(value, uid) {
  profile(value.profile, uid);
  for (const skill of list(value.skills)) { object(skill, ['id', 'name']); id(skill.id); text(skill.name, 60, true); }
  unique(value.skills);
  for (const item of list(value.experience)) {
    object(item, ['id', 'role', 'organization', 'period', 'description']);
    id(item.id); text(item.role, 120, true); text(item.organization, 160, true);
    text(item.period, 120); text(item.description, 4000);
  }
  unique(value.experience);
  for (const item of list(value.education)) {
    object(item, ['id', 'institution', 'qualification', 'period', 'description']);
    id(item.id); text(item.institution, 160, true); text(item.qualification, 160, true);
    text(item.period, 120); text(item.description, 4000);
  }
  unique(value.education);
  for (const link of list(value.links)) {
    object(link, ['id', 'label', 'url', 'kind', 'visible', 'publishAllowed'], ['id', 'label', 'url', 'kind']);
    id(link.id); text(link.label, 80, true);
    enumeration(link.kind, ['other', 'github', 'website', 'linkedin', 'email', 'phone', 'telegram']);
    contactUrl(link.url, link.kind);
    if (own(link, 'visible')) boolean(link.visible);
    if (own(link, 'publishAllowed')) boolean(link.publishAllowed);
  }
  unique(value.links);
}

const blockKinds = ['profile', 'about', 'skills', 'featuredProjects', 'experience', 'education', 'github', 'links', 'resume', 'location'];
function blocks(value) {
  for (const block of list(value, 10)) {
    object(block, ['kind', 'visible']); enumeration(block.kind, blockKinds); boolean(block.visible);
  }
  if (new Set(value.map((block) => block.kind)).size !== value.length) invalid();
}

function metadata(value) {
  object(value, ['acceptedSource', 'lastGitHubSyncAt', 'overrideFields']);
  const source = object(value.acceptedSource, ['repositoryId', 'name', 'fullName', 'htmlUrl', 'description', 'language', 'stars', 'forks', 'isFork', 'archived', 'updatedAt']);
  integer(source.repositoryId, 1); text(source.name, 120, true); text(source.fullName, 250, true); url(source.htmlUrl, true);
  if (source.description !== null) text(source.description, 4000);
  if (source.language !== null) text(source.language, 60);
  integer(source.stars); integer(source.forks); boolean(source.isFork); boolean(source.archived); date(source.updatedAt);
  if (value.lastGitHubSyncAt !== null) date(value.lastGitHubSyncAt);
  const fields = list(value.overrideFields, 4);
  for (const field of fields) enumeration(field, ['title', 'description', 'technologies', 'repositoryUrl']);
  if (new Set(fields).size !== fields.length) invalid();
}

function project(value, uid) {
  const keys = ['id', 'title', 'description', 'contribution', 'technologies', 'repositoryUrl', 'liveUrl', 'featured', 'visible', 'imagePaths', 'updatedAt', 'source', 'githubMetadata'];
  object(value, keys, ['id', 'title', 'description', 'technologies', 'repositoryUrl', 'liveUrl', 'featured', 'visible']);
  id(value.id); text(value.title, 120, true); text(value.description, 4000); text(value.contribution ?? '', 4000);
  for (const technology of list(value.technologies, 20)) text(technology, 60, true);
  url(value.repositoryUrl); url(value.liveUrl); boolean(value.featured); boolean(value.visible);
  for (const path of list(value.imagePaths ?? [], 6)) { if (!path) invalid(); mediaPath(path, uid); }
  if (value.updatedAt !== undefined && value.updatedAt !== null) date(value.updatedAt);
  enumeration(value.source ?? 'manual', ['manual', 'github']);
  if (value.githubMetadata !== undefined && value.githubMetadata !== null) metadata(value.githubMetadata);
  if ((value.source ?? 'manual') === 'manual' && value.githubMetadata != null) invalid();
  if (value.source === 'github' && value.githubMetadata == null) invalid();
}

const contentKeys = ['profile', 'skills', 'projects', 'experience', 'education', 'links', 'blocks', 'resumeText', 'theme', 'ignoredGitHubRepositories', 'documents'];
function content(value, uid, workspace = false) {
  object(value, workspace ? contentKeys : contentKeys.filter((key) => key !== 'documents'), contentKeys.slice(0, 9));
  sections(value, uid); blocks(value.blocks); text(value.resumeText, 20000); enumeration(value.theme, ['dark', 'light']);
  for (const item of list(value.projects)) project(item, uid);
  unique(value.projects);
  const ignored = list(value.ignoredGitHubRepositories ?? []);
  for (const item of ignored) { object(item, ['repositoryId', 'fingerprint']); integer(item.repositoryId, 1); text(item.fingerprint, 200, true); }
  if (!workspace && (value.projects.length || ignored.length)) invalid();
}

export function validateWorkspace(value, uid) {
  content(value, uid, true);
  const documents = list(value.documents ?? [], 20);
  const projectIds = new Set(value.projects.map((item) => item.id));
  for (const document of documents) {
    object(document, ['id', 'title', 'kind', 'createdAt', 'updatedAt', 'content', 'projects', 'attachedResumeId', 'baseSnapshot'], ['id', 'title', 'kind', 'createdAt', 'updatedAt', 'content', 'projects', 'attachedResumeId']);
    id(document.id); text(document.title, 120, true); enumeration(document.kind, ['resume', 'portfolio']);
    date(document.createdAt); date(document.updatedAt);
    if (Date.parse(document.updatedAt) < Date.parse(document.createdAt)) invalid();
    content(document.content, uid);
    if (own(document, 'baseSnapshot')) {
      object(document.baseSnapshot, ['profile', 'skills', 'experience', 'education', 'links']); sections(document.baseSnapshot, uid);
    }
    for (const attachment of list(document.projects)) {
      object(attachment, ['projectId', 'visible', 'featured', 'titleOverride', 'descriptionOverride', 'contributionOverride'], ['projectId', 'visible', 'featured']);
      id(attachment.projectId); boolean(attachment.visible); boolean(attachment.featured);
      if (!projectIds.has(attachment.projectId)) invalid();
      for (const [key, max] of [['titleOverride', 120], ['descriptionOverride', 4000], ['contributionOverride', 4000]]) {
        if (attachment[key] !== undefined && attachment[key] !== null) text(attachment[key], max, key === 'titleOverride');
      }
    }
    unique(document.projects, 'projectId');
    if (document.attachedResumeId !== null) id(document.attachedResumeId);
    if (document.kind === 'resume' && document.attachedResumeId !== null) invalid();
  }
  unique(documents);
  for (const document of documents) {
    if (document.attachedResumeId !== null && !documents.some((candidate) => candidate.id === document.attachedResumeId && candidate.kind === 'resume')) invalid();
  }
  return value;
}

export function permanentPublicId(uid, documentId) {
  return createHash('sha256').update(`${uid}\0${documentId}`).digest('hex').slice(0, 32);
}

export function publicOrigin(value, emulator = false) {
  let origin;
  try { origin = new URL(value); } catch { throw new PublicationError('configuration-required', 'Public web origin is not configured', 412); }
  const local = ['localhost', '127.0.0.1', '[::1]'].includes(origin.hostname);
  if (origin.origin !== value || origin.username || origin.password || (origin.protocol !== 'https:' && !(emulator && local && origin.protocol === 'http:'))) {
    throw new PublicationError('configuration-required', 'Public web origin is invalid', 412);
  }
  return origin.origin;
}

export function projectPublicDocument(workspace, documentId, uid, publicId, version, operationId) {
  validateWorkspace(workspace, uid);
  const document = workspace.documents.find((item) => item.id === documentId);
  if (!document) throw new PublicationError('deleted', 'Document is unavailable', 409);
  const snapshot = document.content;
  const visible = (kind) => snapshot.blocks.some((block) => block.kind === kind && block.visible);
  const media = [];
  const publicMedia = (source) => {
    if (!source) return '';
    const digest = createHash('sha256').update(`${operationId}\0${source}`).digest('hex').slice(0, 32);
    const destination = `publicMedia/${publicId}/${version}/${digest}.jpg`;
    if (!media.some((entry) => entry.source === source)) media.push({ source, destination });
    return destination;
  };
  const p = snapshot.profile;
  const projectedProfile = {
    name: visible('profile') ? p.name : '', username: visible('profile') ? p.username : '',
    headline: visible('profile') ? p.headline : '', bio: visible('about') ? p.bio : '',
    locationText: visible('location') && workspace.profile.publishLocation === true && p.publishLocation === true ? p.locationText : '',
    avatarUrl: visible('profile') ? publicMedia(p.avatarPath) || publicExternalAvatar(p.avatarUrl) : '',
  };
  const library = new Map(workspace.projects.map((item) => [item.id, item]));
  const projects = visible('featuredProjects') ? document.projects.flatMap((attachment) => {
    const original = library.get(attachment.projectId);
    if (!attachment.visible || !original.visible) return [];
    return [{
      id: original.id, title: attachment.titleOverride ?? original.title,
      description: attachment.descriptionOverride ?? original.description,
      contribution: attachment.contributionOverride ?? original.contribution ?? '',
      technologies: [...original.technologies], repositoryUrl: original.repositoryUrl,
      liveUrl: original.liveUrl, featured: attachment.featured, visible: true,
      imageUrls: (original.imagePaths ?? []).map(publicMedia),
    }];
  }) : [];
  const allowedContacts = new Set(workspace.links.filter((link) => link.publishAllowed === true && link.visible !== false).map((link) => link.id));
  const links = snapshot.links.filter((link) => allowedContacts.has(link.id) && link.publishAllowed === true && link.visible !== false
    && visible(link.kind === 'github' ? 'github' : 'links')).map(({ id, label, url, kind }) => ({ id, label, url, kind }));
  const result = {
    // Private relation plan проходит те же visibility правила, что и public content.
    attachedResumeId: visible('resume') ? document.attachedResumeId : null, media,
    publicDocument: {
      schemaVersion: 1, publicId, version, title: document.title, kind: document.kind,
      attachedResumePublicId: null,
      content: {
        profile: projectedProfile, projects,
        skills: visible('skills') ? snapshot.skills.map(({ id, name }) => ({ id, name })) : [],
        experience: visible('experience') ? snapshot.experience.map(({ id, role, organization, period, description }) => ({ id, role, organization, period, description })) : [],
        education: visible('education') ? snapshot.education.map(({ id, institution, qualification, period, description }) => ({ id, institution, qualification, period, description })) : [],
        links, blocks: snapshot.blocks.filter((block) => block.visible).map(({ kind }) => ({ kind, visible: true })),
        resumeText: visible('resume') ? snapshot.resumeText : '', theme: snapshot.theme,
      },
    },
  };
  // Public reader ограничивает каждую опубликованную коллекцию 200 элементами.
  // Проверка после privacy projection не отказывает из-за большой приватной базы.
  for (const key of ['skills', 'projects', 'experience', 'education', 'links']) {
    list(result.publicDocument.content[key], 200);
  }
  return result;
}

export function validateRequest(value) {
  object(value, ['action', 'documentId', 'operationId', 'expectedMutationId', 'expectedVersion', 'expectedGeneration', 'ownerUid', 'recoveryKey', 'retry'], ['action']);
  enumeration(value.action, ['inventory', 'status', 'publish', 'unpublish', 'deleteDocument', 'deleteAccount', 'deletionStatus']);
  if (value.action === 'inventory') { if (Object.keys(value).length !== 1) invalid(); return value; }
  id(value.operationId);
  if (value.action === 'status') { if (Object.keys(value).length !== 2) invalid(); return value; }
  if (value.action === 'deletionStatus') {
    object(value, ['action', 'ownerUid', 'operationId', 'recoveryKey', 'retry'], ['action', 'ownerUid', 'operationId', 'recoveryKey']);
    id(value.ownerUid);
    if (typeof value.recoveryKey !== 'string' || value.recoveryKey.length !== 64 || !/^[0-9a-f]{64}$/.test(value.recoveryKey)) invalid();
    if (value.retry !== undefined) boolean(value.retry);
    return value;
  }
  if (value.ownerUid !== undefined || value.retry !== undefined) invalid();
  integer(value.expectedGeneration);
  if (value.action !== 'deleteAccount') {
    if (value.recoveryKey !== undefined) invalid();
    id(value.documentId); integer(value.expectedVersion);
    if (value.action === 'publish') id(value.expectedMutationId);
    else if (value.expectedMutationId !== undefined) id(value.expectedMutationId);
  } else {
    if (value.documentId !== undefined || value.expectedVersion !== undefined || value.expectedMutationId !== undefined
        || typeof value.recoveryKey !== 'string' || value.recoveryKey.length !== 64 || !/^[0-9a-f]{64}$/.test(value.recoveryKey)) invalid();
  }
  return value;
}

function publicExternalAvatar(value) {
  if (!value) return '';
  const parsed = new URL(value);
  return parsed.protocol === 'https:' && !parsed.port
    && ['avatars.githubusercontent.com', 'images.unsplash.com'].includes(parsed.hostname) ? value : '';
}
