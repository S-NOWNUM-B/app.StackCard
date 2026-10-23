'use client';
import { useEffect, useRef, useState } from 'react';
import { Button, Field, Icon, Notice } from './ui';
import type { GitHubSource, Project } from '@/lib/model';
import {
  loadGitHubPage,
  readGitHubCache,
  writeGitHubCache,
  type GitHubPage,
} from '@/lib/github-repositories';
export function GitHubImporter({
  ownerUid,
  username,
  projects,
  onSettings,
  onImport,
  onBack,
}: {
  ownerUid: string;
  username: string;
  projects: Project[];
  onSettings: () => void;
  onImport: (sources: GitHubSource[]) => Promise<void>;
  onBack: () => void;
}) {
  const [pages, setPages] = useState<GitHubPage[]>([]),
    [search, setSearch] = useState(''),
    [selected, setSelected] = useState(new Set<number>()),
    [busy, setBusy] = useState(false),
    [error, setError] = useState(''),
    [failedLoad, setFailedLoad] = useState<{ page: number; replace: boolean } | null>(null),
    [cached, setCached] = useState(false);
  const controller = useRef<AbortController | null>(null),
    generation = useRef(0);
  useEffect(() => {
    setSelected(new Set());
    setPages(username ? readGitHubCache(localStorage, ownerUid, username) : []);
    setCached(true);
    if (username) void load(1, true);
    return () => {
      generation.current++;
      controller.current?.abort();
    };
  }, [ownerUid, username]);
  async function load(page: number, replace = false) {
    const token = ++generation.current;
    controller.current?.abort();
    const request = new AbortController();
    controller.current = request;
    const timeout = setTimeout(() => request.abort(), 15000);
    setBusy(true);
    setError('');
    setFailedLoad(null);
    try {
      const loaded = await loadGitHubPage(username, page, request.signal);
      if (token !== generation.current) return;
      setPages((previous) => {
        const next = replace ? [loaded] : [...previous, loaded];
        try {
          writeGitHubCache(localStorage, ownerUid, username, next);
        } catch {
          /* Кэш не заменяет durable импорт. */
        }
        return next;
      });
      setCached(false);
    } catch (e) {
      if (token === generation.current) {
        setFailedLoad({ page, replace });
        setError(e instanceof Error ? e.message : 'Не удалось загрузить GitHub.');
      }
    } finally {
      clearTimeout(timeout);
      if (token === generation.current) setBusy(false);
    }
  }
  async function importSelected() {
    setBusy(true);
    setError('');
    setFailedLoad(null);
    try {
      await onImport(repositories.filter((r) => selected.has(r.repositoryId)));
      setSelected(new Set());
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Не удалось сохранить проекты.');
    } finally {
      setBusy(false);
    }
  }
  const imported = new Set(
    projects.flatMap((p) =>
      p.githubMetadata ? [p.githubMetadata.acceptedSource.repositoryId] : [],
    ),
  );
  const repositories = Array.from(
    new Map(pages.flatMap((p) => p.repositories).map((r) => [r.repositoryId, r])).values(),
  );
  const shown = repositories.filter((r) =>
    `${r.name} ${r.description ?? ''}`.toLowerCase().includes(search.toLowerCase()),
  );
  return (
    <section className="stack">
      <Button variant="quiet" onClick={onBack} disabled={busy}>
        Назад к проектам
      </Button>
      <h1>Импортировать из GitHub</h1>
      {!username ? (
        <>
          <p className="muted">
            Добавьте GitHub-профиль в настройках, чтобы импортировать проекты.
          </p>
          <Button onClick={onSettings}>Открыть настройки</Button>
        </>
      ) : (
        <>
          <div className="row">
            <p className="muted">github.com/{username}</p>
            <Button variant="quiet" onClick={onSettings} disabled={busy}>
              Открыть настройки
            </Button>
          </div>
          <Field
            label="Поиск по названию и описанию"
            type="search"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          {cached && pages.length > 0 && <Notice>Показана доступная кешированная копия.</Notice>}
          {pages.at(-1)?.hasNext && (
            <p className="muted">
              Поиск охватывает только загруженные страницы. Загрузите остальные репозитории.
            </p>
          )}
          {shown.map((r) => (
            <label className="project-row repository-choice" key={r.repositoryId}>
              <input
                type="checkbox"
                disabled={busy || imported.has(r.repositoryId)}
                checked={imported.has(r.repositoryId) || selected.has(r.repositoryId)}
                onChange={(e) =>
                  setSelected((current) => {
                    const next = new Set(current);
                    if (e.target.checked) next.add(r.repositoryId);
                    else next.delete(r.repositoryId);
                    return next;
                  })
                }
              />
              <Icon name="folder" />
              <span className="project-copy">
                <strong>{r.name}</strong>
                {r.description && <small>{r.description}</small>}
                {imported.has(r.repositoryId) && <small className="muted">Уже импортирован</small>}
              </span>
            </label>
          ))}
          {!busy && shown.length === 0 && pages.length > 0 && (
            <p>
              {repositories.length === 0
                ? 'Репозиториев пока нет'
                : 'В загруженных репозиториях ничего не найдено'}
            </p>
          )}
          {pages.at(-1)?.hasNext && (
            <Button
              variant="secondary"
              disabled={busy || failedLoad !== null}
              onClick={() => void load(pages.length + 1)}
            >
              Загрузить ещё
            </Button>
          )}
          <Button disabled={busy || selected.size === 0} onClick={() => void importSelected()}>
            Импортировать выбранные{selected.size ? ` (${selected.size})` : ''}
          </Button>
        </>
      )}
      {busy && <Notice>Загружаем…</Notice>}
      {error && (
        <>
          <Notice error>{error}</Notice>
          {username && failedLoad && (
            <Button
              variant="secondary"
              disabled={busy}
              onClick={() => void load(failedLoad.page, failedLoad.replace)}
            >
              Повторить загрузку
            </Button>
          )}
        </>
      )}
    </section>
  );
}
