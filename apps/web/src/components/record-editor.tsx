'use client';
import { useEffect, useId, useRef, useState } from 'react';
import { equal } from '@/lib/model';
import { Button, Field, Icon, Notice } from './ui';

export type RecordField<T> = {
  key: Extract<keyof T, string>;
  label: string;
  maxLength: number;
  required?: boolean;
  textarea?: boolean;
};

export function saveEditorRecord<T extends { id: string }>(
  items: T[],
  previous: T | null,
  draft: T,
  fields: RecordField<T>[],
): T[] {
  for (const field of fields) {
    const value = draft[field.key];
    if (typeof value !== 'string' || value.length > field.maxLength)
      throw new Error(`«${field.label}»: максимум ${field.maxLength} символов.`);
    if (field.required && !value.trim()) throw new Error(`Заполните «${field.label}».`);
  }
  if (!previous) return [...items, draft];
  const current = items.find((item) => item.id === previous.id);
  if (!current || !equal(current, previous))
    throw new Error('Запись изменилась. Откройте её снова.');
  return items.map((item) => (item.id === previous.id ? { ...item, ...draft, id: item.id } : item));
}

export function RecordEditor<T extends { id: string }>({
  title,
  addLabel,
  editLabel,
  removeLabel,
  items,
  fields,
  create,
  summary,
  onChange,
}: {
  title: string;
  addLabel: string;
  editLabel: string;
  removeLabel: string;
  items: T[];
  fields: RecordField<T>[];
  create: () => T;
  summary: (item: T) => { title: string; detail: string };
  onChange: (items: T[]) => void;
}) {
  const dialog = useRef<HTMLDialogElement>(null),
    previous = useRef<T | null>(null),
    titleId = useId(),
    errorId = useId();
  const [draft, setDraft] = useState<T | null>(null),
    [error, setError] = useState('');
  useEffect(() => {
    const current = dialog.current;
    if (!draft || !current) return;
    if (!current.open) current.showModal();
    current.querySelector<HTMLInputElement>('input')?.focus();
  }, [draft?.id]);

  function open(item: T | null) {
    previous.current = item ? { ...item } : null;
    setError('');
    setDraft(item ? { ...item } : create());
  }
  function save() {
    if (!draft) return;
    try {
      onChange(saveEditorRecord(items, previous.current, draft, fields));
      dialog.current?.close();
    } catch (failure) {
      setError(failure instanceof Error ? failure.message : 'Не удалось сохранить.');
      dialog.current?.querySelector<HTMLInputElement>('input')?.focus();
    }
  }
  return (
    <div className="stack record-editor">
      <div className="record-editor-heading">
        <h2>{title}</h2>
        <Button
          variant="quiet"
          className="record-editor-action"
          aria-label={addLabel}
          title={addLabel}
          onClick={() => open(null)}
        >
          <Icon name="plus" />
        </Button>
      </div>
      {items.length > 0 && (
        <ul className="record-editor-list" aria-label={title}>
          {items.map((item, index) => {
            const copy = summary(item);
            return (
              <li className="record-editor-item" key={item.id}>
                <Button
                  variant="quiet"
                  className="record-editor-summary"
                  aria-label={`${editLabel} ${copy.title}`}
                  title={editLabel}
                  onClick={() => open(item)}
                >
                  <span className="record-editor-copy">
                    <strong>{copy.title}</strong>
                    {copy.detail && <small className="muted">{copy.detail}</small>}
                  </span>
                  <Icon name="pencil" size={20} />
                </Button>
                <Button
                  variant="quiet"
                  className="record-editor-action"
                  aria-label={`${removeLabel} ${copy.title}`}
                  title={`${removeLabel} ${copy.title}`}
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
                    aria-hidden="true"
                    focusable="false"
                  >
                    <path d="m6 6 12 12M18 6 6 18" />
                  </svg>
                </Button>
              </li>
            );
          })}
        </ul>
      )}
      <dialog
        ref={dialog}
        className="dialog record-editor-dialog"
        aria-labelledby={titleId}
        onClose={() => {
          previous.current = null;
          setDraft(null);
          setError('');
        }}
        onKeyDown={(event) => {
          if (event.key !== 'Tab') return;
          const first = event.currentTarget.querySelector<HTMLInputElement>('input'),
            last = event.currentTarget.querySelector<HTMLButtonElement>('button[type="submit"]'),
            active = event.currentTarget.ownerDocument.activeElement;
          if (event.shiftKey && active === first) {
            event.preventDefault();
            last?.focus();
          } else if (!event.shiftKey && active === last) {
            event.preventDefault();
            first?.focus();
          }
        }}
      >
        <form
          className="stack"
          onSubmit={(event) => {
            event.preventDefault();
            save();
          }}
        >
          <h2 id={titleId}>{previous.current ? editLabel : addLabel}</h2>
          {draft &&
            fields.map((field) => (
              <Field
                key={field.key}
                label={field.label}
                value={String(draft[field.key] ?? '')}
                maxLength={field.maxLength}
                required={field.required}
                textarea={field.textarea}
                aria-describedby={error ? errorId : undefined}
                onChange={(event) => {
                  setDraft({ ...draft, [field.key]: event.target.value });
                  setError('');
                }}
              />
            ))}
          {error && (
            <div id={errorId}>
              <Notice error>{error}</Notice>
            </div>
          )}
          <div className="record-editor-dialog-actions">
            <Button variant="secondary" onClick={() => dialog.current?.close()}>
              Отмена
            </Button>
            <Button type="submit">Сохранить</Button>
          </div>
        </form>
      </dialog>
    </div>
  );
}
