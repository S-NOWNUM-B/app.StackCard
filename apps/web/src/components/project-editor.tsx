'use client';
import { useId, useRef, useState } from 'react';
import { Button, Field, Icon, Notice, TechnologyBadges } from './ui';
import {
  uid,
  withProjectEdits,
  projectIconIds,
  projectIconLabels,
  type ProjectIconId,
  type Project,
  type WorkspaceContent,
  type PortfolioDocument,
  attachment,
} from '@/lib/model';
export const emptyProject = (): Project => ({
  id: uid(),
  iconId: 'folder',
  title: '',
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
export function IconPicker({
  value,
  onChange,
}: {
  value: ProjectIconId;
  onChange: (id: ProjectIconId) => void;
}) {
  const [open, setOpen] = useState(false);
  return (
    <div className="stack">
      <button
        type="button"
        className="avatar-trigger project-icon-trigger"
        aria-label="Иконка проекта"
        onClick={() => setOpen(!open)}
        aria-expanded={open}
      >
        <Icon name={value} size={48} />
        <span className="avatar-pencil" aria-hidden="true">
          <Icon name="pencil" size={22} />
        </span>
      </button>
      {open && (
        <div className="icon-picker" role="group" aria-label="Встроенные иконки">
          {projectIconIds.map((id) => (
            <Button
              key={id}
              variant="quiet"
              className={value === id ? 'selected' : ''}
              aria-pressed={value === id}
              onClick={() => {
                onChange(id);
                setOpen(false);
              }}
            >
              <Icon name={id} />
              <span className="icon-picker-label">{projectIconLabels[id]}</span>
            </Button>
          ))}
        </div>
      )}
    </div>
  );
}
export function appendProjectTechnology(items: string[], input: string): string[] {
  const technology = input.trim();
  if (!technology) throw new Error('Введите название.');
  if (technology.includes(',')) throw new Error('Добавляйте по одной технологии.');
  if (technology.length > 60) throw new Error('Максимум 60 символов.');
  if (items.some((item) => item.trim().toLowerCase() === technology.toLowerCase()))
    throw new Error('Технология уже добавлена.');
  if (items.length >= 20) throw new Error('Максимум 20 технологий.');
  return [...items, technology];
}
function ProjectTechnologies({
  items,
  onChange,
}: {
  items: string[];
  onChange: (items: string[]) => void;
}) {
  const dialog = useRef<HTMLDialogElement>(null),
    input = useRef<HTMLInputElement>(null),
    titleId = useId(),
    errorId = useId();
  const [name, setName] = useState(''),
    [error, setError] = useState('');
  function add() {
    try {
      onChange(appendProjectTechnology(items, name));
      setName('');
      setError('');
      dialog.current?.close();
    } catch (failure) {
      setError(failure instanceof Error ? failure.message : 'Не удалось добавить технологию.');
      input.current?.focus();
    }
  }
  return (
    <div className="stack project-technologies">
      <div className="project-technology-heading">
        <strong>Технологии</strong>
        <Button
          variant="quiet"
          className="project-technology-action"
          aria-label="Добавить технологию"
          title="Добавить технологию"
          onClick={() => {
            setError('');
            dialog.current?.showModal();
            input.current?.focus();
          }}
        >
          <Icon name="plus" />
        </Button>
      </div>
      {items.length > 0 && (
        <ul className="project-technology-list" aria-label="Технологии проекта">
          {items.map((item, index) => (
            <li className="project-technology-item" key={item + index}>
              <TechnologyBadges items={[item]} />
              <Button
                variant="quiet"
                className="project-technology-action text-danger"
                aria-label={`Удалить технологию ${item}`}
                title={`Удалить технологию ${item}`}
                onClick={() => onChange(items.filter((_, position) => position !== index))}
              >
                <svg
                  width="20"
                  height="20"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.8"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  aria-hidden="true"
                  focusable="false"
                >
                  <path d="M4 6h16M9 6V3h6v3M6 6l1 15h10l1-15M10 10v7M14 10v7" />
                </svg>
              </Button>
            </li>
          ))}
        </ul>
      )}
      <dialog
        ref={dialog}
        className="dialog project-technology-dialog"
        aria-labelledby={titleId}
        onKeyDown={(event) => {
          if (event.key !== 'Tab') return;
          const active = event.currentTarget.ownerDocument.activeElement,
            submit = event.currentTarget.querySelector<HTMLButtonElement>('button[type="submit"]');
          if (event.shiftKey && active === input.current) {
            event.preventDefault();
            submit?.focus();
          } else if (!event.shiftKey && active === submit) {
            event.preventDefault();
            input.current?.focus();
          }
        }}
      >
        <form
          className="stack"
          onSubmit={(event) => {
            event.preventDefault();
            add();
          }}
        >
          <h2 id={titleId}>Технология</h2>
          <label className="field">
            <span>Название</span>
            <input
              ref={input}
              value={name}
              autoComplete="off"
              aria-invalid={error ? true : undefined}
              aria-describedby={error ? errorId : undefined}
              onChange={(event) => {
                setName(event.target.value);
                setError('');
              }}
            />
          </label>
          {error && (
            <div id={errorId}>
              <Notice error>{error}</Notice>
            </div>
          )}
          <div className="project-technology-dialog-actions">
            <Button
              variant="quiet"
              className="project-technology-action"
              aria-label="Закрыть"
              title="Закрыть"
              onClick={() => dialog.current?.close()}
            >
              <span aria-hidden="true">×</span>
            </Button>
            <Button
              type="submit"
              className="project-technology-action"
              aria-label="Добавить технологию"
              title="Добавить технологию"
            >
              <Icon name="plus" />
            </Button>
          </div>
        </form>
      </dialog>
    </div>
  );
}
export function ProjectForm({
  project,
  onChange,
}: {
  project: Project;
  onChange: (p: Project) => void;
  onDelete?: () => void;
}) {
  const patch = (p: Partial<Project>) => onChange(withProjectEdits(project, p));
  return (
    <div className="stack editor-group">
      <IconPicker value={project.iconId ?? 'folder'} onChange={(iconId) => patch({ iconId })} />
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
      <ProjectTechnologies
        key={project.id}
        items={project.technologies}
        onChange={(technologies) => patch({ technologies })}
      />
      <Field
        label="Репозиторий"
        type="url"
        value={project.repositoryUrl}
        maxLength={2048}
        onChange={(e) => patch({ repositoryUrl: e.target.value })}
      />
      <Field
        label="Сайт проекта"
        type="url"
        value={project.liveUrl}
        maxLength={2048}
        onChange={(e) => patch({ liveUrl: e.target.value })}
      />
    </div>
  );
}
export function AttachmentsEditor({
  workspace,
  document,
  onChange,
  onIconChange,
  onProjects,
}: {
  workspace: WorkspaceContent;
  document: PortfolioDocument;
  onChange: (d: PortfolioDocument) => void;
  onIconChange: (projectId: string, iconId: ProjectIconId) => void;
  onProjects: () => void;
}) {
  const [choosing, setChoosing] = useState(false);
  const available = workspace.projects.filter(
    (p) => !document.projects.some((a) => a.projectId === p.id),
  );
  return (
    <div className="stack">
      {document.projects.map((a, i) => {
        const p = workspace.projects.find((p) => p.id === a.projectId);
        if (!p) return null;
        return (
          <div key={a.projectId} className="entry-editor stack">
            <div className="project-row">
              <Icon name={p.iconId ?? 'folder'} />
              <strong>{a.titleOverride ?? p.title}</strong>
            </div>
            <IconPicker
              value={p.iconId ?? 'folder'}
              onChange={(iconId) => onIconChange(p.id, iconId)}
            />
            <div className="row">
              <Button
                variant="quiet"
                disabled={i === 0}
                onClick={() => {
                  const items = [...document.projects];
                  [items[i - 1], items[i]] = [items[i], items[i - 1]];
                  onChange({ ...document, projects: items });
                }}
              >
                Вверх
              </Button>
              <Button
                variant="quiet"
                disabled={i === document.projects.length - 1}
                onClick={() => {
                  const items = [...document.projects];
                  [items[i + 1], items[i]] = [items[i], items[i + 1]];
                  onChange({ ...document, projects: items });
                }}
              >
                Вниз
              </Button>
              <Button
                variant="quiet"
                className="text-danger"
                onClick={() =>
                  onChange({
                    ...document,
                    projects: document.projects.filter((v) => v.projectId !== a.projectId),
                  })
                }
              >
                Убрать из портфолио
              </Button>
            </div>
          </div>
        );
      })}
      <Button variant="secondary" aria-expanded={choosing} onClick={() => setChoosing(!choosing)}>
        Добавить проект
      </Button>
      {choosing && (
        <div className="stack project-selection">
          {workspace.projects.length === 0 ? (
            <>
              <p>Проектов пока нет</p>
              <Button variant="secondary" onClick={onProjects}>
                Открыть «Проекты»
              </Button>
            </>
          ) : available.length === 0 ? (
            <p>Все проекты уже добавлены</p>
          ) : (
            available.map((p) => (
              <Button
                key={p.id}
                variant="quiet"
                className="project-row"
                onClick={() =>
                  onChange({ ...document, projects: [...document.projects, attachment(p.id)] })
                }
              >
                <Icon name={p.iconId ?? 'folder'} />
                {p.title}
              </Button>
            ))
          )}
        </div>
      )}
    </div>
  );
}
