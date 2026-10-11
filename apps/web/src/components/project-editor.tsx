'use client';
import { useState } from 'react';
import { Button, Field, Icon } from './ui';
import { TagEditor } from './tag-editor';
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
      <TagEditor
        key={project.id}
        heading={<strong>Технологии</strong>}
        title="Технология"
        addLabel="Добавить технологию"
        removeLabel="Удалить технологию"
        listLabel="Технологии проекта"
        items={project.technologies.map((name, index) => ({ id: String(index), name }))}
        onAdd={(name) =>
          patch({ technologies: appendProjectTechnology(project.technologies, name) })
        }
        onRemove={(index) =>
          patch({ technologies: project.technologies.filter((_, position) => position !== index) })
        }
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
