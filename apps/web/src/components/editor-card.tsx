'use client';
import { useId, useState, type ReactNode } from 'react';
import { InlineIcon } from './inline-icon';

// Единая карточка раздела редактора: заголовок, счётчик, действие «+» и сворачивание.
export function EditorCard({
  id,
  title,
  count,
  action,
  children,
}: {
  id?: string;
  title: string;
  count?: number;
  action?: ReactNode;
  children: ReactNode;
}) {
  const [open, setOpen] = useState(true),
    bodyId = useId();
  return (
    <section
      className={`editor-card${open ? '' : ' is-collapsed'}`}
      id={id}
      aria-label={title}
      data-editor-section={id}
    >
      <div className="editor-card-header">
        <h2>{title}</h2>
        {count !== undefined && count > 0 && (
          <span className="editor-card-count" aria-label={`Записей: ${count}`}>
            {count}
          </span>
        )}
        <span className="editor-card-actions">
          {action}
          <button
            type="button"
            className="button quiet editor-card-toggle"
            aria-expanded={open}
            aria-controls={bodyId}
            aria-label={open ? `Свернуть раздел «${title}»` : `Развернуть раздел «${title}»`}
            title={open ? 'Свернуть' : 'Развернуть'}
            onClick={() => setOpen((value) => !value)}
          >
            <InlineIcon name="chevron-down" size={20} />
          </button>
        </span>
      </div>
      <div className="editor-card-collapse">
        <div className="editor-card-body stack" id={bodyId} inert={!open}>
          {children}
        </div>
      </div>
    </section>
  );
}
