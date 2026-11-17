// Локальная история версий основного портфолио, порт mobile portfolio_history.dart.
// Снимки лежат только в localStorage браузера по ключу владельца; в Firestore и другие
// сервисы ничего не уходит. Фото в снимок не копируется: хранится лишь флаг hasAvatar.
import {
  clone,
  emptyContent,
  equal,
  mainDocument,
  resolveDocument,
  uid,
  validateWorkspace,
  type Attachment,
  type DocumentContent,
  type PortfolioDocument,
  type WorkspaceContent,
} from './model';
import { documentPreview } from './preview';
import type { PublicDocumentContent } from './public-document';

// Сколько снимков хранится на владельца; самые старые вытесняются.
export const historyLimit = 20;
const schemaVersion = 1;

export type PortfolioSnapshot = {
  id: string;
  savedAt: string;
  hasAvatar: boolean;
  // Разрешённое содержимое документа: проекты внутри, аватар очищен.
  content: DocumentContent;
  // Порядок и флаги проектов документа для восстановления.
  attachments: Attachment[];
};

export class HistoryFailure extends Error {
  constructor(message = 'Не удалось прочитать локальную историю версий') {
    super(message);
    this.name = 'HistoryFailure';
  }
}

export const historyKey = (uidValue: string) => `stackcard.history.${uidValue}`;

// Снимок текущего main-документа; null — основного портфолио нет или оно
// ссылается на проект, которого нет в Library.
export function buildSnapshot(
  workspace: WorkspaceContent,
  at: Date,
  id: string,
): PortfolioSnapshot | null {
  const document = mainDocument(workspace);
  if (!document) return null;
  let resolved: DocumentContent;
  try {
    resolved = resolveDocument(workspace, document);
  } catch {
    return null;
  }
  const profile = resolved.profile;
  return {
    id,
    savedAt: at.toISOString(),
    hasAvatar: profile.avatarPath !== '' || profile.avatarUrl !== '',
    attachments: clone(document.projects),
    content: { ...resolved, profile: { ...profile, avatarPath: '', avatarUrl: '' } },
  };
}

const sameContent = (left: PortfolioSnapshot, right: PortfolioSnapshot) =>
  left.hasAvatar === right.hasAvatar &&
  equal(left.content, right.content) &&
  equal(left.attachments, right.attachments);

// Новейший первым. Равный последнему по содержимому не добавляется;
// сверх лимита вытесняются самые старые.
export function appendSnapshot(
  newestFirst: PortfolioSnapshot[],
  next: PortfolioSnapshot,
): PortfolioSnapshot[] {
  if (newestFirst.length > 0 && sameContent(newestFirst[0], next)) return newestFirst;
  return [next, ...newestFirst].slice(0, historyLimit);
}

export type PortfolioRestore = { document: PortfolioDocument; skippedProjects: number };

// Подставляет содержимое снимка в current; текущее фото сохраняется.
// Ничего не пишет: результат попадает только в буфер редактора.
export function restoreSnapshot({
  workspace,
  current,
  snapshot,
}: {
  workspace: WorkspaceContent;
  current: PortfolioDocument;
  snapshot: PortfolioSnapshot;
}): PortfolioRestore {
  const library = new Set(workspace.projects.map((project) => project.id));
  const attachments = snapshot.attachments.filter((item) => library.has(item.projectId));
  const avatar = current.content.profile;
  const content = clone(snapshot.content);
  return {
    skippedProjects: snapshot.attachments.length - attachments.length,
    document: {
      ...clone(current),
      content: {
        ...content,
        projects: [],
        profile: { ...content.profile, avatarPath: avatar.avatarPath, avatarUrl: avatar.avatarUrl },
      },
      projects: clone(attachments),
    },
  };
}

// Версия в том же виде, что сохранённая Главная: owner preview без картинок.
export function snapshotPreview(snapshot: PortfolioSnapshot): PublicDocumentContent {
  const document: PortfolioDocument = {
    id: snapshot.id,
    title: '',
    kind: 'portfolio',
    createdAt: snapshot.savedAt,
    updatedAt: snapshot.savedAt,
    content: { ...clone(snapshot.content), projects: [] },
    projects: clone(snapshot.attachments),
    attachedResumeId: null,
  };
  const workspace: WorkspaceContent = {
    ...emptyContent(),
    projects: clone(snapshot.content.projects),
    documents: [document],
    mainPortfolioId: document.id,
  };
  // documentPreview уже строит main-блоки и не отдаёт картинки проектов.
  return documentPreview(workspace, document);
}

export type SnapshotChange = {
  kind:
    | 'profile'
    | 'projectsAdded'
    | 'projectsRemoved'
    | 'projectsEdited'
    | 'skillsAdded'
    | 'skillsRemoved'
    | 'experience'
    | 'education'
    | 'contacts'
    | 'layout';
  count: number;
};
export type SnapshotSummary = { projects: number; skills: number; changes: SnapshotChange[] };

// Краткая сводка: числа и что изменилось относительно previous.
export function summarizeSnapshot(
  snapshot: PortfolioSnapshot,
  previous?: PortfolioSnapshot | null,
): SnapshotSummary {
  const now = snapshot.content;
  const before = previous?.content;
  const changes: SnapshotChange[] = [];
  if (before) {
    const flag = (kind: SnapshotChange['kind']) => changes.push({ kind, count: 0 });
    const counted = (kind: SnapshotChange['kind'], count: number) => {
      if (count > 0) changes.push({ kind, count });
    };
    if (!equal(before.profile, now.profile)) flag('profile');
    const oldProjects = new Map(before.projects.map((p) => [p.id, p]));
    const newProjects = new Map(now.projects.map((p) => [p.id, p]));
    counted('projectsAdded', [...newProjects.keys()].filter((id) => !oldProjects.has(id)).length);
    counted('projectsRemoved', [...oldProjects.keys()].filter((id) => !newProjects.has(id)).length);
    counted(
      'projectsEdited',
      [...newProjects].filter(([id, p]) => oldProjects.has(id) && !equal(oldProjects.get(id), p))
        .length,
    );
    const oldSkills = new Set(before.skills.map((s) => s.name));
    const newSkills = new Set(now.skills.map((s) => s.name));
    counted('skillsAdded', [...newSkills].filter((name) => !oldSkills.has(name)).length);
    counted('skillsRemoved', [...oldSkills].filter((name) => !newSkills.has(name)).length);
    if (!equal(before.experience, now.experience)) flag('experience');
    if (!equal(before.education, now.education)) flag('education');
    if (!equal(before.links, now.links)) flag('contacts');
    if (changes.length === 0 && !equal(before.blocks, now.blocks)) flag('layout');
  }
  return { projects: now.projects.length, skills: now.skills.length, changes };
}

// ---- Хранилище (localStorage, ключ владельца) ----

function decodeEntry(raw: unknown, owner: string): PortfolioSnapshot {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) throw new HistoryFailure();
  const entry = raw as Record<string, unknown>;
  if (
    typeof entry.id !== 'string' ||
    entry.id === '' ||
    entry.id.length > 100 ||
    typeof entry.savedAt !== 'string' ||
    Number.isNaN(Date.parse(entry.savedAt)) ||
    typeof entry.hasAvatar !== 'boolean' ||
    !Array.isArray(entry.attachments)
  )
    throw new HistoryFailure();
  const attachments = entry.attachments.map((item): Attachment => {
    const a = item as Record<string, unknown> | null;
    const text = (value: unknown) => value === null || typeof value === 'string';
    if (
      typeof a !== 'object' ||
      a === null ||
      typeof a.projectId !== 'string' ||
      typeof a.visible !== 'boolean' ||
      typeof a.featured !== 'boolean' ||
      !text(a.titleOverride) ||
      !text(a.descriptionOverride) ||
      !text(a.contributionOverride)
    )
      throw new HistoryFailure();
    return {
      projectId: a.projectId,
      visible: a.visible,
      featured: a.featured,
      titleOverride: a.titleOverride as string | null,
      descriptionOverride: a.descriptionOverride as string | null,
      contributionOverride: a.contributionOverride as string | null,
    };
  });
  // Содержимое проверяется тем же строгим декодером, что и облачный документ.
  const decoded = validateWorkspace(
    {
      ...(entry.content as DocumentContent),
      documents: [],
      mainPortfolioId: null,
      githubUsername: '',
      personalization: { status: 'notRequired', step: 0 },
    },
    owner,
  );
  const {
    documents: _documents,
    mainPortfolioId: _main,
    githubUsername: _github,
    personalization: _personalization,
    legacyMainSnapshot: _legacy,
    ...content
  } = decoded;
  return {
    id: entry.id,
    savedAt: entry.savedAt,
    hasAvatar: entry.hasAvatar,
    attachments,
    content,
  };
}

// Чтение не пишет: повреждённые и неподдерживаемые записи не переписываются.
export function listHistory(storage: Storage, owner: string): PortfolioSnapshot[] {
  try {
    const raw = storage.getItem(historyKey(owner));
    if (raw === null) return [];
    const parsed: unknown = JSON.parse(raw);
    if (
      typeof parsed !== 'object' ||
      parsed === null ||
      (parsed as { schemaVersion?: unknown }).schemaVersion !== schemaVersion ||
      !Array.isArray((parsed as { entries?: unknown }).entries)
    )
      throw new HistoryFailure();
    const items = (parsed as { entries: unknown[] }).entries.map((entry) =>
      decodeEntry(entry, owner),
    );
    if (items.length > historyLimit || new Set(items.map((item) => item.id)).size !== items.length)
      throw new HistoryFailure();
    return items;
  } catch {
    throw new HistoryFailure();
  }
}

// Сохраняет снимок main-документа. Повреждённая история заменяется новой, а не блокирует Save;
// ошибка записи (квота, запрет хранилища) приходит как HistoryFailure, прежняя история остаётся.
export function recordHistory(
  storage: Storage,
  owner: string,
  workspace: WorkspaceContent,
  at: Date,
  id = `${at.getTime()}-${uid().slice(0, 8)}`,
): void {
  const snapshot = buildSnapshot(workspace, at, id);
  if (!snapshot) return;
  let existing: PortfolioSnapshot[];
  try {
    existing = listHistory(storage, owner);
  } catch {
    existing = [];
  }
  const next = appendSnapshot(existing, snapshot);
  if (next === existing) return;
  try {
    storage.setItem(historyKey(owner), JSON.stringify({ schemaVersion, entries: next }));
  } catch {
    throw new HistoryFailure('Не удалось сохранить версию на этом устройстве');
  }
}

// Удаляет все снимки владельца; недоступное хранилище не считается ошибкой выхода.
export function clearHistory(storage: Storage, owner: string): void {
  try {
    storage.removeItem(historyKey(owner));
  } catch {
    // Хранилище недоступно — снимков в нём всё равно нет.
  }
}

// UID, чьи снимки нужно удалить после смены auth-состояния: вход потерян (выход в другой
// вкладке, отзыв сессии) или сменился аккаунт. Без прежнего UID или без перемен — null.
export function staleHistoryOwner(previous: string | null, current: string | null): string | null {
  return previous && previous !== current ? previous : null;
}

// localStorage может отсутствовать или бросать (приватный режим, запрет сайта).
export function browserHistoryStorage(): Storage | null {
  try {
    return typeof localStorage === 'undefined' ? null : localStorage;
  } catch {
    return null;
  }
}
