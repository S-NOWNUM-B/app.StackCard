'use client';
import { useEffect, useId, useRef, useState } from 'react';
import { Button, Field, Icon } from './ui';
import { TagEditor } from './tag-editor';
import { EditorCard } from './editor-card';
import { InlineIcon } from './inline-icon';
import { moveItem, SortableList } from './sortable-list';
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
        <IconGrid
          value={value}
          onChange={(id) => {
            onChange(id);
            setOpen(false);
          }}
        />
      )}
    </div>
  );
}
// Сетка встроенных иконок; пользовательские SVG/URL не принимаются (ADR 0005).
export function IconGrid({
  value,
  onChange,
}: {
  value: ProjectIconId;
  onChange: (id: ProjectIconId) => void;
}) {
  return (
    <div className="icon-picker" role="group" aria-label="Встроенные иконки">
      {projectIconIds.map((id) => (
        <Button
          key={id}
          variant="quiet"
          className={value === id ? 'selected' : ''}
          aria-pressed={value === id}
          onClick={() => onChange(id)}
        >
          <Icon name={id} />
          <span className="icon-picker-label">{projectIconLabels[id]}</span>
        </Button>
      ))}
    </div>
  );
}
export function appendProjectTechnology(items: string[], input: string): string[] {
  const technology = input.trim();
  if (!technology) throw new Error('Введите название');
  if (technology.includes(',')) throw new Error('Добавляйте по одной технологии');
  if (technology.length > 60) throw new Error('Максимум 60 символов');
  if (items.some((item) => item.trim().toLowerCase() === technology.toLowerCase()))
    throw new Error('Технология уже добавлена');
  if (items.length >= 20) throw new Error('Максимум 20 технологий');
  return [...items, technology];
}
// Ключи строк технологий стабильны при перестановке; legacy-дубли различаются номером.
function technologyItems(technologies: string[]) {
  const seen = new Map<string, number>();
  return technologies.map((name) => {
    const count = seen.get(name) ?? 0;
    seen.set(name, count + 1);
    return { id: `${name}\u0000${count}`, name };
  });
}
export function ProjectForm({
  project,
  onChange,
}: {
  project: Project;
  onChange: (p: Project) => void;
}) {
  const patch = (p: Partial<Project>) => onChange(withProjectEdits(project, p));
  return (
    <div className="stack project-form">
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
      <TagEditor
        key={project.id}
        heading={<strong>Технологии</strong>}
        title="Технология"
        addLabel="Добавить технологию"
        removeLabel="Удалить технологию"
        listLabel="Технологии проекта"
        items={technologyItems(project.technologies)}
        onAdd={(name) =>
          patch({ technologies: appendProjectTechnology(project.technologies, name) })
        }
        onRemove={(index) =>
          patch({ technologies: project.technologies.filter((_, position) => position !== index) })
        }
        onMove={(from, to) => patch({ technologies: moveItem(project.technologies, from, to) })}
      />
      <div className="editor-fields">
        <Field
          label="Репозиторий"
          type="url"
          inputMode="url"
          placeholder="https://github.com/…"
          value={project.repositoryUrl}
          maxLength={2048}
          onChange={(e) => patch({ repositoryUrl: e.target.value })}
        />
        <Field
          label="Сайт проекта"
          type="url"
          inputMode="url"
          placeholder="https://…"
          value={project.liveUrl}
          maxLength={2048}
          onChange={(e) => patch({ liveUrl: e.target.value })}
        />
      </div>
    </div>
  );
}
// Вложения без проекта в Library не рендерятся и не участвуют в порядке Вверх/Вниз.
function visibleAttachments(workspace: WorkspaceContent, document: PortfolioDocument) {
  return document.projects.filter((a) => workspace.projects.some((p) => p.id === a.projectId));
}
export function moveAttachment(
  workspace: WorkspaceContent,
  document: PortfolioDocument,
  projectId: string,
  offset: -1 | 1,
): PortfolioDocument['projects'] {
  const visible = visibleAttachments(workspace, document);
  const index = visible.findIndex((a) => a.projectId === projectId),
    neighbour = visible[index + offset];
  if (index < 0 || !neighbour) return document.projects;
  const items = [...document.projects],
    from = items.findIndex((a) => a.projectId === projectId),
    to = items.findIndex((a) => a.projectId === neighbour.projectId);
  [items[from], items[to]] = [items[to], items[from]];
  return items;
}
// Перестановка по видимым индексам: скрытые вложения остаются на своих местах.
export function reorderAttachment(
  workspace: WorkspaceContent,
  document: PortfolioDocument,
  from: number,
  to: number,
): PortfolioDocument['projects'] {
  const visible = visibleAttachments(workspace, document);
  const reordered = moveItem(visible, from, to);
  if (reordered === visible) return document.projects;
  let position = 0;
  return document.projects.map((a) =>
    workspace.projects.some((p) => p.id === a.projectId) ? reordered[position++] : a,
  );
}
// Выбор как в mobile: отмеченные остаются в прежнем порядке, новые добавляются по Library.
export function selectAttachments(
  workspace: WorkspaceContent,
  document: PortfolioDocument,
  selected: Set<string>,
): PortfolioDocument['projects'] {
  return [
    ...document.projects.filter(
      (a) => selected.has(a.projectId) || !workspace.projects.some((p) => p.id === a.projectId),
    ),
    ...workspace.projects
      .filter((p) => selected.has(p.id) && !document.projects.some((a) => a.projectId === p.id))
      .map((p) => attachment(p.id)),
  ];
}
export function AttachmentsEditor({
  workspace,
  document,
  onChange,
  onIconChange,
  onProjects,
  id = 'editor-section-featuredProjects',
}: {
  workspace: WorkspaceContent;
  document: PortfolioDocument;
  onChange: (d: PortfolioDocument) => void;
  onIconChange: (projectId: string, iconId: ProjectIconId) => void;
  onProjects: () => void;
  id?: string;
}) {
  const dialog = useRef<HTMLDialogElement>(null),
    titleId = useId();
  const [selection, setSelection] = useState<Set<string> | null>(null),
    [iconFor, setIconFor] = useState<string | null>(null),
    [session, setSession] = useState(0);
  const visible = visibleAttachments(workspace, document);
  useEffect(() => {
    if (selection && dialog.current && !dialog.current.open) dialog.current.showModal();
  }, [session]);
  const titleOf = (a: PortfolioDocument['projects'][number]) =>
    a.titleOverride ?? workspace.projects.find((p) => p.id === a.projectId)?.title ?? '';
  return (
    <EditorCard
      id={id}
      title="Реализованные проекты"
      count={visible.length}
      action={
        <Button
          variant="quiet"
          className="record-editor-action"
          aria-label="Добавить проект"
          title="Добавить проект"
          onClick={() => {
            setSelection(new Set(visible.map((a) => a.projectId)));
            setSession((value) => value + 1);
          }}
        >
          <Icon name="plus" />
        </Button>
      }
    >
      {visible.length > 0 ? (
        <SortableList
          className="attachment-list"
          label="Проекты портфолио"
          items={visible}
          itemKey={(a) => a.projectId}
          itemLabel={titleOf}
          onMove={(from, to) =>
            onChange({ ...document, projects: reorderAttachment(workspace, document, from, to) })
          }
          renderItem={(a) => {
            const p = workspace.projects.find((p) => p.id === a.projectId)!,
              title = titleOf(a);
            return (
              <div className="attachment-row">
                <div className="record-editor-item">
                  <Button
                    variant="quiet"
                    className="attachment-icon"
                    aria-label={`Иконка проекта ${title}`}
                    aria-expanded={iconFor === a.projectId}
                    title="Сменить иконку"
                    onClick={() => setIconFor(iconFor === a.projectId ? null : a.projectId)}
                  >
                    <Icon name={p.iconId ?? 'folder'} />
                  </Button>
                  <span className="record-editor-copy">
                    <strong>{title || 'Без названия'}</strong>
                    {p.description && <small className="muted clamp-2">{p.description}</small>}
                  </span>
                  <Button
                    variant="quiet"
                    className="record-editor-action"
                    aria-label={`Убрать из портфолио ${title}`}
                    title="Убрать из портфолио"
                    onClick={() =>
                      onChange({
                        ...document,
                        projects: document.projects.filter((v) => v.projectId !== a.projectId),
                      })
                    }
                  >
                    <InlineIcon name="x" size={20} />
                  </Button>
                </div>
                {iconFor === a.projectId && (
                  <IconGrid
                    value={p.iconId ?? 'folder'}
                    onChange={(iconId) => {
                      onIconChange(p.id, iconId);
                      setIconFor(null);
                    }}
                  />
                )}
              </div>
            );
          }}
        />
      ) : (
        <p className="editor-empty muted">
          {workspace.projects.length === 0
            ? 'В библиотеке пока нет проектов. Создайте или импортируйте их в разделе «Проекты»'
            : 'Пока пусто. Нажмите «+», чтобы выбрать проекты из библиотеки'}
        </p>
      )}
      <dialog
        ref={dialog}
        className="dialog record-editor-dialog project-selection-dialog"
        aria-labelledby={titleId}
        onClose={() => setSelection(null)}
      >
        <form
          className="stack"
          onSubmit={(event) => {
            event.preventDefault();
            if (selection)
              onChange({
                ...document,
                projects: selectAttachments(workspace, document, selection),
              });
            dialog.current?.close();
          }}
        >
          <h2 id={titleId}>Проекты портфолио</h2>
          {workspace.projects.length === 0 ? (
            <>
              <p className="muted">Проектов пока нет</p>
              <Button
                variant="secondary"
                onClick={() => {
                  dialog.current?.close();
                  onProjects();
                }}
              >
                Перейти в «Проекты»
              </Button>
            </>
          ) : (
            <div className="project-selection">
              {workspace.projects.map((p) => (
                <label className="project-row repository-choice" key={p.id}>
                  <input
                    type="checkbox"
                    checked={selection?.has(p.id) ?? false}
                    onChange={(event) =>
                      setSelection((current) => {
                        const next = new Set(current);
                        if (event.target.checked) next.add(p.id);
                        else next.delete(p.id);
                        return next;
                      })
                    }
                  />
                  <Icon name={p.iconId ?? 'folder'} />
                  <span className="project-copy">
                    <strong>{p.title || 'Без названия'}</strong>
                    {p.description && <small>{p.description}</small>}
                  </span>
                </label>
              ))}
            </div>
          )}
          <div className="dialog-actions">
            <Button variant="secondary" onClick={() => dialog.current?.close()}>
              Отмена
            </Button>
            {workspace.projects.length > 0 && <Button type="submit">Добавить выбранные</Button>}
          </div>
        </form>
      </dialog>
    </EditorCard>
  );
}
