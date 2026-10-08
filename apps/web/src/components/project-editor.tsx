'use client';
import { useState } from 'react';
import { Button, Field, Icon, Notice, TechnologyBadges } from './ui';
import {
  uid,
  withProjectEdits,
  type Project,
  type WorkspaceContent,
  type PortfolioDocument,
  type Attachment,
  attachment,
} from '@/lib/model';
export const emptyProject = (): Project => ({
  id: uid(),
  title: 'Новый проект',
  description: '',
  contribution: '',
  technologies: [],
  repositoryUrl: '',
  liveUrl: '',
  featured: false,
  visible: true,
  imagePaths: [],
  source: 'manual',
  githubMetadata: null,
});
export function ProjectForm({
  project,
  onChange,
  onDelete,
}: {
  project: Project;
  onChange: (p: Project) => void;
  onDelete: () => void;
}) {
  const patch = (p: Partial<Project>) => onChange(withProjectEdits(project, p));
  return (
    <details className="section stack" open>
      <summary>{project.title}</summary>
      <div className="cover-slot">
        <Icon name="image" />{' '}
        {project.imagePaths.length
          ? `${project.imagePaths.length} приватных изображений`
          : 'Обложка не добавлена'}
      </div>
      <Field
        label="Название"
        value={project.title}
        maxLength={120}
        required
        onChange={(e) => patch({ title: e.target.value })}
      />
      <Field
        label="Описание"
        value={project.description}
        textarea
        maxLength={4000}
        onChange={(e) => patch({ description: e.target.value })}
      />
      <Field
        label="Мой вклад"
        value={project.contribution}
        textarea
        maxLength={4000}
        onChange={(e) => patch({ contribution: e.target.value })}
      />
      <Field
        label="Технологии через запятую"
        value={project.technologies.join(', ')}
        onChange={(e) =>
          patch({
            technologies: e.target.value
              .split(',')
              .map((s) => s.trim())
              .filter(Boolean),
          })
        }
      />
      <TechnologyBadges items={project.technologies} />
      <Field
        label="Репозиторий"
        value={project.repositoryUrl}
        type="url"
        maxLength={2048}
        onChange={(e) => patch({ repositoryUrl: e.target.value })}
      />
      <Field
        label="Сайт проекта"
        value={project.liveUrl}
        type="url"
        maxLength={2048}
        onChange={(e) => patch({ liveUrl: e.target.value })}
      />
      <label className="checkbox">
        <input
          type="checkbox"
          checked={project.visible}
          onChange={(e) => patch({ visible: e.target.checked })}
        />
        Разрешить показывать проект в документах
      </label>
      <small className="muted">
        Изменение Library действует для следующих публикаций. Уже опубликованные версии обновляются
        отдельно.
      </small>
      <Button variant="danger" onClick={onDelete}>
        Удалить из Library
      </Button>
    </details>
  );
}
export function AttachmentsEditor({
  workspace,
  document,
  onChange,
}: {
  workspace: WorkspaceContent;
  document: PortfolioDocument;
  onChange: (d: PortfolioDocument) => void;
}) {
  const patch = (id: string, p: Partial<Attachment>) =>
    onChange({
      ...document,
      projects: document.projects.map((a) => (a.projectId === id ? { ...a, ...p } : a)),
    });
  return (
    <details className="editor-section">
      <summary>Проекты в документе</summary>
      <p className="muted">
        Описание и вклад этого документа не меняют Library и соседние документы. Пустое локальное
        описание скрывает общий текст.
      </p>
      {document.projects.map((a, i) => {
        const p = workspace.projects.find((p) => p.id === a.projectId);
        return (
          <div className="stack section" key={a.projectId}>
            <h3>{p?.title}</h3>
            <label className="checkbox">
              <input
                type="checkbox"
                checked={a.visible}
                onChange={(e) => patch(a.projectId, { visible: e.target.checked })}
              />
              Показывать
            </label>
            <label className="checkbox">
              <input
                type="checkbox"
                checked={a.featured}
                onChange={(e) => patch(a.projectId, { featured: e.target.checked })}
              />
              Избранный
            </label>
            {(['title', 'description', 'contribution'] as const).map((k) => {
              const key = `${k}Override` as const;
              return (
                <div className="stack" key={k}>
                  <label className="checkbox">
                    <input
                      type="checkbox"
                      checked={a[key] !== null}
                      onChange={(e) =>
                        patch(a.projectId, {
                          [key]: e.target.checked ? (p?.[k] ?? '') : null,
                        })
                      }
                    />
                    {k === 'title'
                      ? 'Своё название'
                      : k === 'description'
                        ? 'Своё описание'
                        : 'Свой вклад'}
                  </label>
                  {a[key] !== null && (
                    <Field
                      label={
                        k === 'title'
                          ? 'Название в документе'
                          : k === 'description'
                            ? 'Описание в документе'
                            : 'Мой вклад в документе'
                      }
                      value={a[key] ?? ''}
                      textarea={k !== 'title'}
                      maxLength={k === 'title' ? 120 : 4000}
                      onChange={(e) => patch(a.projectId, { [key]: e.target.value })}
                    />
                  )}
                </div>
              );
            })}
            <div className="row">
              <Button
                variant="quiet"
                disabled={i === 0}
                onClick={() => {
                  const list = [...document.projects];
                  [list[i - 1], list[i]] = [list[i], list[i - 1]];
                  onChange({ ...document, projects: list });
                }}
              >
                Вверх
              </Button>
              <Button
                variant="quiet"
                disabled={i === document.projects.length - 1}
                onClick={() => {
                  const list = [...document.projects];
                  [list[i + 1], list[i]] = [list[i], list[i + 1]];
                  onChange({ ...document, projects: list });
                }}
              >
                Вниз
              </Button>
              <Button
                variant="danger"
                onClick={() =>
                  onChange({
                    ...document,
                    projects: document.projects.filter((x) => x.projectId !== a.projectId),
                  })
                }
              >
                Открепить
              </Button>
            </div>
          </div>
        );
      })}
      <label className="field">
        <span>Прикрепить проект из Library</span>
        <select
          value=""
          onChange={(e) => {
            if (e.target.value)
              onChange({
                ...document,
                projects: [...document.projects, attachment(e.target.value)],
              });
          }}
        >
          <option value="">Выбрать проект</option>
          {workspace.projects
            .filter((p) => !document.projects.some((a) => a.projectId === p.id))
            .map((p) => (
              <option key={p.id} value={p.id}>
                {p.title}
              </option>
            ))}
        </select>
      </label>
      {document.kind === 'portfolio' && (
        <label className="field">
          <span>Прикреплённое резюме</span>
          <select
            value={document.attachedResumeId ?? ''}
            onChange={(e) =>
              onChange({
                ...document,
                attachedResumeId: e.target.value || null,
              })
            }
          >
            <option value="">Без резюме</option>
            {workspace.documents
              .filter((d) => d.kind === 'resume')
              .map((d) => (
                <option value={d.id} key={d.id}>
                  {d.title}
                </option>
              ))}
          </select>
        </label>
      )}
    </details>
  );
}
export function GitHubImporter({
  workspace,
  onAdd,
}: {
  workspace: WorkspaceContent;
  onAdd: (p: Project) => void;
}) {
  const [url, setUrl] = useState(''),
    [candidate, setCandidate] = useState<Project | null>(null),
    [busy, setBusy] = useState(false),
    [message, setMessage] = useState('');
  async function inspect() {
    setBusy(true);
    setMessage('');
    setCandidate(null);
    try {
      const match = /^https:\/\/github\.com\/([A-Za-z0-9_.-]+)\/([A-Za-z0-9_.-]+)\/?$/.exec(url);
      if (!match)
        throw new Error('Укажите URL публичного репозитория github.com/owner/repository.');
      const response = await fetch(
        `https://api.github.com/repos/${encodeURIComponent(match[1])}/${encodeURIComponent(match[2])}`,
        {
          headers: { Accept: 'application/vnd.github+json' },
          signal: AbortSignal.timeout(15000),
        },
      );
      if (!response.ok)
        throw new Error(
          response.status === 403
            ? 'GitHub ограничил запросы. Повторите позднее.'
            : 'Репозиторий не найден или недоступен.',
        );
      const s = await response.json();
      if (
        !Number.isSafeInteger(s.id) ||
        s.id < 1 ||
        typeof s.name !== 'string' ||
        typeof s.html_url !== 'string' ||
        typeof s.updated_at !== 'string'
      )
        throw new Error('Ответ GitHub некорректен.');
      if (workspace.projects.some((p) => p.githubMetadata?.acceptedSource.repositoryId === s.id))
        throw new Error('Этот репозиторий уже есть в Library.');
      setCandidate({
        ...emptyProject(),
        title: s.name,
        description: s.description ?? '',
        technologies: s.language ? [s.language] : [],
        repositoryUrl: s.html_url,
        source: 'github',
        githubMetadata: {
          acceptedSource: {
            repositoryId: s.id,
            name: s.name,
            fullName: s.full_name,
            htmlUrl: s.html_url,
            description: s.description,
            language: s.language,
            stars: s.stargazers_count,
            forks: s.forks_count,
            isFork: s.fork,
            archived: s.archived,
            updatedAt: new Date(s.updated_at).toISOString(),
          },
          lastGitHubSyncAt: new Date().toISOString(),
          overrideFields: [],
        },
      });
    } catch (e) {
      setMessage(e instanceof Error ? e.message : 'Не удалось загрузить репозиторий.');
    } finally {
      setBusy(false);
    }
  }
  return (
    <details className="editor-section">
      <summary>Импорт из GitHub</summary>
      <Field
        label="Публичный репозиторий"
        value={url}
        type="url"
        onChange={(e) => setUrl(e.target.value)}
      />
      <Button variant="secondary" disabled={busy} onClick={() => void inspect()}>
        {busy ? 'Загружаем…' : 'Просмотреть источник'}
      </Button>
      {message && <Notice error>{message}</Notice>}
      {candidate && (
        <div className="stack section">
          <h3>{candidate.title}</h3>
          <p>{candidate.description}</p>
          <TechnologyBadges items={candidate.technologies} />
          <p className="muted">
            Добавление изменит только рабочую Library. Сохранение и публикация отдельные.
          </p>
          <Button
            onClick={() => {
              onAdd(candidate);
              setCandidate(null);
              setMessage('Добавлено в рабочую Library. Сохраните изменения.');
            }}
          >
            Добавить в Library
          </Button>
        </div>
      )}
    </details>
  );
}
