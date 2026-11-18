import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  attachment,
  clone,
  emptyContent,
  mainDocument,
  migrateMainPortfolio,
  type PortfolioDocument,
  type Project,
  type WorkspaceContent,
} from '../src/lib/model';
import {
  appendSnapshot,
  buildSnapshot,
  clearHistory,
  staleHistoryOwner,
  historyKey,
  historyLimit,
  HistoryFailure,
  listHistory,
  recordHistory,
  restoreSnapshot,
  snapshotPreview,
  summarizeSnapshot,
} from '../src/lib/portfolio-history';

class MemoryStorage implements Storage {
  data = new Map<string, string>();
  writes = 0;
  failWrites = false;
  get length() {
    return this.data.size;
  }
  clear() {
    this.data.clear();
  }
  getItem(key: string) {
    return this.data.get(key) ?? null;
  }
  key(index: number) {
    return [...this.data.keys()][index] ?? null;
  }
  removeItem(key: string) {
    this.data.delete(key);
  }
  setItem(key: string, value: string) {
    if (this.failWrites) throw new DOMException('quota', 'QuotaExceededError');
    this.writes++;
    this.data.set(key, value);
  }
}

const UID = 'user-one';
const at = (minutes: number) => new Date(Date.UTC(2026, 10, 16, 10, minutes));

function project(id: string, patch: Partial<Project> = {}): Project {
  return {
    id,
    title: `Проект ${id}`,
    description: 'Описание',
    contribution: '',
    technologies: ['TypeScript'],
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

// Основное портфолио с одним проектом, фото и навыком.
function workspace(name = 'Имя'): WorkspaceContent {
  const base = migrateMainPortfolio(emptyContent(), null);
  base.projects = [project('p1')];
  const main = mainDocument(base)!;
  main.projects = [attachment('p1')];
  main.content = {
    ...main.content,
    profile: {
      ...main.content.profile,
      name,
      avatarPath: `accounts/${UID}/media/avatar.jpg`,
      avatarUrl: 'https://example.com/photo.png',
    },
    skills: [{ id: 's1', name: 'TypeScript' }],
  };
  return base;
}

const main = (content: WorkspaceContent): PortfolioDocument => mainDocument(content)!;

test('снимок разворачивает проекты и не копирует фото', () => {
  const snapshot = buildSnapshot(workspace(), at(0), 'a1')!;
  assert.equal(snapshot.hasAvatar, true);
  assert.equal(snapshot.content.profile.avatarPath, '');
  assert.equal(snapshot.content.profile.avatarUrl, '');
  assert.deepEqual(
    snapshot.content.projects.map((item) => item.id),
    ['p1'],
  );
  assert.equal(snapshot.savedAt, at(0).toISOString());
});

test('без основного документа или с пропавшим проектом снимка нет', () => {
  assert.equal(buildSnapshot(emptyContent(), at(0), 'a1'), null);
  const broken = workspace();
  broken.projects = [];
  assert.equal(buildSnapshot(broken, at(0), 'a1'), null);
});

test('одинаковый подряд снимок не добавляется, новейший первым', () => {
  const first = buildSnapshot(workspace(), at(0), 'a1')!;
  const same = buildSnapshot(workspace(), at(1), 'a2')!;
  const other = buildSnapshot(workspace('Другое имя'), at(2), 'a3')!;
  const list = appendSnapshot([first], same);
  assert.deepEqual(
    list.map((item) => item.id),
    ['a1'],
  );
  assert.deepEqual(
    appendSnapshot(list, other).map((item) => item.id),
    ['a3', 'a1'],
  );
});

test('лимит 20: самые старые вытесняются', () => {
  let list: ReturnType<typeof appendSnapshot> = [];
  for (let index = 0; index < historyLimit + 5; index++)
    list = appendSnapshot(list, buildSnapshot(workspace(`Имя ${index}`), at(index), `id${index}`)!);
  assert.equal(historyLimit, 20);
  assert.equal(list.length, 20);
  assert.equal(list[0].id, `id${historyLimit + 4}`);
  assert.equal(list.at(-1)!.id, 'id5');
});

test('запись и чтение через хранилище, фото в нём нет', () => {
  const storage = new MemoryStorage();
  recordHistory(storage, UID, workspace(), at(0), 'a1');
  recordHistory(storage, UID, workspace('Другое имя'), at(1), 'a2');
  const items = listHistory(storage, UID);
  assert.deepEqual(
    items.map((item) => item.id),
    ['a2', 'a1'],
  );
  const raw = storage.getItem(historyKey(UID))!;
  assert.ok(!raw.includes('avatar.jpg'));
  assert.ok(!raw.includes('photo.png'));
  assert.equal(items[1].hasAvatar, true);
});

test('в хранилище не больше 20 записей, повторное чтение ничего не пишет', () => {
  const storage = new MemoryStorage();
  for (let index = 0; index < 25; index++)
    recordHistory(storage, UID, workspace(`Имя ${index}`), at(index), `id${index}`);
  assert.equal(listHistory(storage, UID).length, 20);
  const writes = storage.writes;
  listHistory(storage, UID);
  assert.equal(storage.writes, writes);
});

test('история разных UID и гостя не смешивается', () => {
  const storage = new MemoryStorage();
  recordHistory(storage, 'user-a', workspace('A'), at(0), 'a1');
  recordHistory(storage, 'user-b', workspace('B'), at(0), 'b1');
  assert.deepEqual(
    listHistory(storage, 'user-a').map((item) => item.content.profile.name),
    ['A'],
  );
  assert.deepEqual(
    listHistory(storage, 'user-b').map((item) => item.content.profile.name),
    ['B'],
  );
  assert.notEqual(historyKey('user-a'), historyKey('user-b'));
  assert.deepEqual(listHistory(storage, 'user-c'), []);
});

test('очистка удаляет историю только одного UID', () => {
  const storage = new MemoryStorage();
  recordHistory(storage, 'user-a', workspace('A'), at(0), 'a1');
  recordHistory(storage, 'user-b', workspace('B'), at(0), 'b1');
  clearHistory(storage, 'user-a');
  assert.equal(storage.getItem(historyKey('user-a')), null);
  assert.equal(listHistory(storage, 'user-b').length, 1);
  clearHistory(storage, 'user-a');
});

test('повреждённое хранилище даёт HistoryFailure, а запись заменяет его новой историей', () => {
  for (const raw of [
    'не json',
    '[]',
    '{"schemaVersion":99,"entries":[]}',
    '{"schemaVersion":1,"entries":"x"}',
    '{"schemaVersion":1,"entries":[{"id":"x"}]}',
    '{"schemaVersion":1,"entries":[null]}',
  ]) {
    const storage = new MemoryStorage();
    storage.setItem(historyKey(UID), raw);
    assert.throws(() => listHistory(storage, UID), HistoryFailure, raw);
  }
  const storage = new MemoryStorage();
  storage.setItem(historyKey(UID), 'не json');
  recordHistory(storage, UID, workspace(), at(0), 'a1');
  assert.deepEqual(
    listHistory(storage, UID).map((item) => item.id),
    ['a1'],
  );
});

test('запись с испорченным содержимым не читается и не ломает кабинет', () => {
  const storage = new MemoryStorage();
  recordHistory(storage, UID, workspace(), at(0), 'a1');
  const parsed = JSON.parse(storage.getItem(historyKey(UID))!);
  delete parsed.entries[0].content.profile;
  storage.setItem(historyKey(UID), JSON.stringify(parsed));
  assert.throws(() => listHistory(storage, UID), HistoryFailure);
});

test('переполненное хранилище даёт HistoryFailure и не теряет прежнюю историю', () => {
  const storage = new MemoryStorage();
  recordHistory(storage, UID, workspace(), at(0), 'a1');
  storage.failWrites = true;
  assert.throws(() => recordHistory(storage, UID, workspace('Новое'), at(1), 'a2'), HistoryFailure);
  storage.failWrites = false;
  assert.deepEqual(
    listHistory(storage, UID).map((item) => item.id),
    ['a1'],
  );
});

test('рабочее пространство без основного документа ничего не записывает', () => {
  const storage = new MemoryStorage();
  recordHistory(storage, UID, emptyContent(), at(0), 'a1');
  assert.equal(storage.writes, 0);
  assert.deepEqual(listHistory(storage, UID), []);
});

test('восстановление оставляет текущее фото и пропускает удалённые проекты', () => {
  const saved = workspace('Старое имя');
  saved.projects.push(project('p2'));
  main(saved).projects.push(attachment('p2'));
  const snapshot = buildSnapshot(saved, at(0), 'a1')!;

  const current = workspace('Новое имя');
  current.projects = [project('p1')]; // p2 в библиотеке уже нет
  main(current).content.profile.avatarPath = `accounts/${UID}/media/current.jpg`;
  main(current).content.profile.avatarUrl = '';
  const before = clone(current);

  const result = restoreSnapshot({ workspace: current, current: main(current), snapshot });
  assert.equal(result.skippedProjects, 1);
  assert.equal(result.document.content.profile.name, 'Старое имя');
  assert.equal(result.document.content.profile.avatarPath, `accounts/${UID}/media/current.jpg`);
  assert.equal(result.document.content.profile.avatarUrl, '');
  assert.deepEqual(
    result.document.projects.map((item) => item.projectId),
    ['p1'],
  );
  assert.deepEqual(result.document.content.projects, []);
  assert.equal(result.document.id, main(current).id);
  assert.deepEqual(current, before);
});

test('просмотр версии строится как сохранённая Главная без фото профиля', () => {
  const snapshot = buildSnapshot(workspace(), at(0), 'a1')!;
  const preview = snapshotPreview(snapshot);
  assert.equal(preview.profile.name, 'Имя');
  assert.deepEqual(
    preview.projects.map((item) => item.id),
    ['p1'],
  );
  assert.equal(preview.profile.avatarUrl, '');
});

test('сводка называет, что изменилось относительно предыдущей версии', () => {
  const first = buildSnapshot(workspace(), at(0), 'a1')!;
  assert.deepEqual(summarizeSnapshot(first).changes, []);
  assert.equal(summarizeSnapshot(first).projects, 1);
  assert.equal(summarizeSnapshot(first).skills, 1);

  const changed = workspace('Другое имя');
  changed.projects.push(project('p2'));
  main(changed).projects.push(attachment('p2'));
  main(changed).content.skills.push({ id: 's2', name: 'Rust' });
  main(changed).content.experience.push({
    id: 'e1',
    role: 'Dev',
    organization: 'Org',
    period: '',
    description: '',
  });
  const second = buildSnapshot(changed, at(1), 'a2')!;
  const summary = summarizeSnapshot(second, first);
  assert.deepEqual(summary.changes, [
    { kind: 'profile', count: 0 },
    { kind: 'projectsAdded', count: 1 },
    { kind: 'skillsAdded', count: 1 },
    { kind: 'experience', count: 0 },
  ]);
  assert.equal(summary.projects, 2);
});

test('при потере или смене сессии чистится история прежнего UID', () => {
  // выход в другой вкладке: был user-a, стало null
  assert.equal(staleHistoryOwner('user-a', null), 'user-a');
  // смена аккаунта без промежуточного состояния
  assert.equal(staleHistoryOwner('user-a', 'user-b'), 'user-a');
  // тот же аккаунт, первый вход, нет прежнего
  assert.equal(staleHistoryOwner('user-a', 'user-a'), null);
  assert.equal(staleHistoryOwner(null, 'user-a'), null);
  assert.equal(staleHistoryOwner(null, null), null);
});
