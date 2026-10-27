'use client';
import { useId, useRef, useState, type ReactNode } from 'react';
import { technologySuggestions, findTechnology } from '@/lib/technology-catalog';
import { Button, Icon, Notice } from './ui';
import { EditorCard } from './editor-card';
import { InlineIcon } from './inline-icon';
import { SortableList } from './sortable-list';
import { TechnologyChip, TechnologyIcon } from './technology-badge';

export function TagEditor({
  heading,
  card,
  title,
  addLabel,
  removeLabel,
  listLabel,
  items,
  onAdd,
  onRemove,
  onMove,
  suggest = true,
}: {
  heading?: ReactNode;
  // Карточка раздела основного редактора; без неё — компактный блок внутри формы.
  card?: { id: string; title: string };
  title: string;
  addLabel: string;
  removeLabel: string;
  listLabel: string;
  items: { id: string; name: string }[];
  onAdd: (name: string) => void;
  onRemove: (index: number) => void;
  onMove?: (from: number, to: number) => void;
  suggest?: boolean;
}) {
  const dialog = useRef<HTMLDialogElement>(null),
    input = useRef<HTMLInputElement>(null),
    titleId = useId(),
    errorId = useId();
  const [name, setName] = useState(''),
    [error, setError] = useState('');
  function add(value = name) {
    try {
      onAdd(value);
      setName('');
      setError('');
      dialog.current?.close();
    } catch (failure) {
      setName(value);
      setError(failure instanceof Error ? failure.message : 'Не удалось сохранить');
      input.current?.focus();
    }
  }
  const suggestions = suggest
    ? technologySuggestions(
        name,
        items.map((item) => item.name),
      ).filter((info) => info.title !== name.trim() || !findTechnology(name))
    : [];
  const addButton = (
    <Button
      variant="quiet"
      className="tag-editor-action"
      aria-label={addLabel}
      title={addLabel}
      onClick={() => {
        setError('');
        setName('');
        dialog.current?.showModal();
        input.current?.focus();
      }}
    >
      <Icon name="plus" />
    </Button>
  );
  const list =
    items.length > 0 ? (
      <SortableList
        className="tag-editor-list"
        label={listLabel}
        items={items}
        itemKey={(item) => item.id}
        itemLabel={(item) => item.name}
        onMove={onMove}
        renderItem={(item, index) => (
          <div className="tag-editor-item">
            <TechnologyChip label={item.name} />
            <Button
              variant="quiet"
              className="tag-editor-action"
              aria-label={`${removeLabel} ${item.name}`}
              title={`${removeLabel} ${item.name}`}
              onClick={() => onRemove(index)}
            >
              <InlineIcon name="x" size={20} />
            </Button>
          </div>
        )}
      />
    ) : card ? (
      <p className="editor-empty muted">Пока пусто. Нажмите «+», чтобы добавить</p>
    ) : null;
  const modal = (
    <dialog
      ref={dialog}
      className="dialog tag-editor-dialog"
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
        <h2 id={titleId}>{title}</h2>
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
        {suggestions.length > 0 && (
          <ul className="technology-suggestions" aria-label="Подсказки">
            {suggestions.map((info) => (
              <li key={info.title}>
                <button
                  type="button"
                  className="technology-suggestion"
                  onClick={() => add(info.title)}
                >
                  <TechnologyIcon label={info.title} />
                  {info.title}
                </button>
              </li>
            ))}
          </ul>
        )}
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
  );
  if (card)
    return (
      <EditorCard id={card.id} title={card.title} count={items.length} action={addButton}>
        {list}
        {modal}
      </EditorCard>
    );
  return (
    <div className="stack tag-editor">
      <div className="tag-editor-heading">
        {heading}
        {addButton}
      </div>
      {list}
      {modal}
    </div>
  );
}
