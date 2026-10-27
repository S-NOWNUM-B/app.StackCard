'use client';
import { useEffect, useId, useRef, useState } from 'react';
import { equal } from '@/lib/model';
import { Button, Field, Icon, Notice } from './ui';
import { EditorCard } from './editor-card';
import { InlineIcon } from './inline-icon';
import { SortableList } from './sortable-list';

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
      throw new Error(`«${field.label}»: максимум ${field.maxLength} символов`);
    if (field.required && !value.trim()) throw new Error(`Заполните «${field.label}»`);
  }
  if (!previous) return [...items, draft];
  const current = items.find((item) => item.id === previous.id);
  if (!current || !equal(current, previous))
    throw new Error('Запись изменилась. Откройте её снова');
  return items.map((item) => (item.id === previous.id ? { ...item, ...draft, id: item.id } : item));
}

export function RecordEditor<T extends { id: string }>({
  id,
  title,
  addLabel,
  editLabel,
  removeLabel,
  items,
  fields,
  create,
  summary,
  onChange,
  onMove,
}: {
  id?: string;
  title: string;
  addLabel: string;
  editLabel: string;
  removeLabel: string;
  items: T[];
  fields: RecordField<T>[];
  create: () => T;
  summary: (item: T) => { title: string; detail: string };
  onChange: (items: T[]) => void;
  onMove?: (from: number, to: number) => void;
}) {
  const dialog = useRef<HTMLDialogElement>(null),
    previous = useRef<T | null>(null),
    titleId = useId(),
    errorId = useId();
  const [draft, setDraft] = useState<T | null>(null),
    [error, setError] = useState(''),
    [session, setSession] = useState(0);
  useEffect(() => {
    const current = dialog.current;
    if (!draft || !current) return;
    if (!current.open) current.showModal();
    current.querySelector<HTMLInputElement>('input')?.focus();
  }, [session]);

  function open(item: T | null) {
    // Состояние диалога задаётся только при открытии: асинхронный close event не сбрасывает новое.
    previous.current = item ? { ...item } : null;
    setSession((value) => value + 1);
    setError('');
    setDraft(item ? { ...item } : create());
  }
  function save() {
    if (!draft) return;
    try {
      onChange(saveEditorRecord(items, previous.current, draft, fields));
      dialog.current?.close();
    } catch (failure) {
      setError(failure instanceof Error ? failure.message : 'Не удалось сохранить');
      dialog.current?.querySelector<HTMLInputElement>('input')?.focus();
    }
  }
  return (
    <EditorCard
      id={id}
      title={title}
      count={items.length}
      action={
        <Button
          variant="quiet"
          className="record-editor-action"
          aria-label={addLabel}
          title={addLabel}
          onClick={() => open(null)}
        >
          <Icon name="plus" />
        </Button>
      }
    >
      {items.length > 0 ? (
        <SortableList
          className="record-editor-list"
          label={title}
          items={items}
          itemKey={(item) => item.id}
          itemLabel={(item) => summary(item).title}
          onMove={onMove}
          renderItem={(item, index) => {
            const copy = summary(item);
            return (
              <div className="record-editor-item">
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
                  <InlineIcon name="x" size={20} />
                </Button>
              </div>
            );
          }}
        />
      ) : (
        <p className="editor-empty muted">Пока пусто. Нажмите «+», чтобы добавить</p>
      )}
      <dialog
        ref={dialog}
        className="dialog record-editor-dialog"
        aria-labelledby={titleId}
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
          <div className="dialog-actions">
            <Button variant="secondary" onClick={() => dialog.current?.close()}>
              Отмена
            </Button>
            <Button type="submit">Сохранить</Button>
          </div>
        </form>
      </dialog>
    </EditorCard>
  );
}
